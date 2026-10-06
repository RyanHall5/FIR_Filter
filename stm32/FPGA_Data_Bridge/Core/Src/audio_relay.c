/* ============================================================
 * audio_relay.c  (bring-up build, DEBUG-INSTRUMENTED)
 *
 * Double-buffered relay: laptop (UART) <-> STM32 <-> FPGA (SPI)
 *
 *   OUT pair (bufOut_A / bufOut_B):
 *     UART RX (laptop -> STM32) fills one buffer while the other is being
 *     sent to the FPGA on MOSI.
 *   IN pair (bufIn_A / bufIn_B):
 *     SPI MISO (FPGA -> STM32) fills one buffer while the other is being
 *     sent to the laptop by UART TX.
 *
 * DEBUG OUTPUT
 *   USART2 is the DATA link to MATLAB, so we must NOT printf over it (it
 *   would corrupt the stream). Instead:
 *     - ISRs push small records into a ring buffer (cheap, never blocks).
 *     - AudioRelay_Report(), called from the main loop, prints them plus a
 *       once-per-second status line through ITM/SWV (SWO pin, via ST-LINK).
 *     - Everything is also visible in Live Expressions: audioRelayStats
 *       (now with lastUartErr / lastSpiErr / lastSpiSR / lastIrq) and relayLog.
 *
 * Hook-up in main.c:
 *   USER CODE BEGIN PFP:   void AudioRelay_Init(void);
 *                          void AudioRelay_Report(void);
 *   USER CODE BEGIN 2:     AudioRelay_Init();
 *   USER CODE BEGIN 3 (inside while(1)):   AudioRelay_Report();
 * ============================================================ */

#include "main.h"
#include <stdint.h>
#include <string.h>
#include <stdio.h>
#include <stdarg.h>

#ifndef FPGA_CS_Pin
#define FPGA_CS_GPIO_Port GPIOB
#define FPGA_CS_Pin       GPIO_PIN_6
#endif

/* ---------- Bring-up switches (change per stage, rebuild, reflash) ----------
 *  Stage 1  UART RX only:          SPI 0  UART_TX 0  RAMP 1  LOOPBACK 0
 *  Stage 2  SPI loopback (jumper): SPI 1  UART_TX 0  RAMP 1  LOOPBACK 1
 *  Stage 3  Full loop   (jumper):  SPI 1  UART_TX 1  RAMP 1  LOOPBACK 1
 *  Stage 4  Real FPGA:             SPI 1  UART_TX 1  RAMP 0  LOOPBACK 0
 */
#define RELAY_ENABLE_SPI      1
#define RELAY_ENABLE_UART_TX  1
#define RELAY_RAMP_CHECK      1   /* verify incoming samples are 0,1,2,... (test_stm32.m) */
#define RELAY_LOOPBACK_CHECK  1   /* verify MISO data == MOSI data (MOSI jumpered to MISO) */

#define RELAY_DEBUG_PRINT     1   /* 1 = event log + ITM printf, 0 = compile all of it out */

#define BUFFER_SAMPLES 512
#define BUFFER_BYTES   (BUFFER_SAMPLES * sizeof(int16_t))
#define SPI_FRAMES     BUFFER_SAMPLES    /* 16-bit SPI: one frame per sample */

extern UART_HandleTypeDef huart2;          /* laptop link */
extern SPI_HandleTypeDef  hspi1;           /* FPGA link   */
extern DMA_HandleTypeDef  hdma_usart2_rx;  /* for NDTR progress readout */

/* Buffers are non-static on purpose so they show up in the debugger. */
int16_t bufOut_A[BUFFER_SAMPLES];
int16_t bufOut_B[BUFFER_SAMPLES];
int16_t bufIn_A[BUFFER_SAMPLES];
int16_t bufIn_B[BUFFER_SAMPLES];
static int16_t bufDump[BUFFER_SAMPLES];   /* sink for frames dropped on overrun */

static int16_t *const outBuf[2] = { bufOut_A, bufOut_B };
static int16_t *const inBuf[2]  = { bufIn_A,  bufIn_B  };

/* --- OUT pair state --- */
static volatile uint8_t outReady[2];   /* 1 = full, waiting for SPI */
static uint8_t rxIdx;                  /* out buffer UART RX is filling */
static volatile uint8_t rxDumping;     /* 1 = current RX frame goes to bufDump */
static uint8_t spiOutIdx;              /* next out buffer SPI will send */
static uint8_t spiCurOut;              /* out buffer of the SPI transaction in flight */

/* --- IN pair state --- */
static volatile uint8_t inReady[2];    /* 1 = full, waiting for / under UART TX */
static uint8_t spiInIdx;               /* next in buffer SPI will fill */
static uint8_t spiCurIn;               /* in buffer of the SPI transaction in flight */
static uint8_t txIdx;                  /* next in buffer UART TX will send */

static volatile uint8_t spiBusy;
static volatile uint8_t uartTxBusy;

#if RELAY_RAMP_CHECK
static uint16_t rampNext;              /* expected next ramp value, 0..32767 */
#endif

/* --- Diagnostics: add audioRelayStats to Live Expressions --- */
typedef struct {
    volatile uint32_t rxFrames;        /* out buffers completed from laptop */
    volatile uint32_t spiFrames;       /* SPI transactions completed */
    volatile uint32_t txFrames;        /* in buffers sent to laptop */
    volatile uint32_t rxOverrun;       /* frames DROPPED because SPI had not freed a buffer */
    volatile uint32_t spiStalls;       /* SPI had no out data ready. Normal: SPI is faster than UART */
    volatile uint32_t inBlocked;       /* SPI could not start: in buffer still waiting on UART TX */
    volatile uint32_t txBusyHits;      /* UART TX start refused by HAL */
    volatile uint32_t uartErrors;
    volatile uint32_t spiErrors;
    volatile uint32_t rxArmFail;       /* HAL refused to start UART RX DMA */
    volatile uint32_t rampErrors;      /* samples that broke the 0,1,2,... pattern */
    volatile uint32_t loopChecked;
    volatile uint32_t loopMismatch;    /* SPI frames where MISO != MOSI */
    /* --- added for debugging --- */
    volatile uint32_t lastUartErr;     /* huart->ErrorCode at the last UART error (PE=1 NE=2 FE=4 ORE=8 DMA=0x10) */
    volatile uint32_t lastSpiErr;      /* hspi->ErrorCode at the last SPI error (MODF=1 CRC=2 OVR=4 FRE=8 DMA=0x10 FLAG=0x20 ABORT=0x40) */
    volatile uint32_t lastSpiSR;       /* SPI1->SR when the SPI error callback ran */
    volatile uint32_t lastIrq;         /* IPSR the SPI error callback ran from: IRQn = lastIrq - 16 */
    volatile uint32_t logDropped;      /* event-log entries lost because the ring was full */
} AudioRelayStats;

volatile AudioRelayStats audioRelayStats;

/* ============================================================
 * Event log (ISR -> main loop). Single producer side (all ISRs run at
 * the same priority so they never preempt each other), single consumer
 * (main loop). Free-running head/tail counters, size must be power of 2.
 * ============================================================ */
typedef enum {
    EV_NONE = 0,
    EV_RX_FRAME,        /* a=rxFrames  b=first sample  c=NDTR         (first 4 frames only) */
    EV_RX_OVERRUN,      /* a=rxFrames  b=rxIdx */
    EV_RX_ARM_FAIL,     /* a=HAL status b=RxState c=ErrorCode */
    EV_UART_ERR,        /* a=ErrorCode b=NDTR c=IPSR */
    EV_UART_ABORT_CPLT, /* a=rxFrames */
    EV_SPI_ERR,         /* a=ErrorCode b=SR c=IPSR | State<<8 */
    EV_SPI_ABORT_CPLT,  /* a=ErrorCode */
    EV_SPI_START,       /* a=spiFrames  (first 4 only) */
    EV_SPI_DONE,        /* a=spiFrames  (first 4 only) */
    EV_TX_START,        /* a=txFrames   (first 4 only) */
    EV_TX_DONE,         /* a=txFrames   (first 4 only) */
    EV_TX_BUSY,         /* a=HAL status */
    EV_RAMP_ERR,        /* a=expected b=got c=(index<<16)|frame (first break per frame) */
    EV_COUNT
} RelayEvent;

#if RELAY_DEBUG_PRINT

typedef struct {
    uint32_t tick;
    uint32_t ev;
    uint32_t a, b, c;
} RelayLogEntry;

#define LOG_SIZE 64u                       /* power of 2 */
RelayLogEntry relayLog[LOG_SIZE];          /* non-static: inspect in the debugger */
static volatile uint32_t logHead;          /* written by ISRs */
static volatile uint32_t logTail;          /* written by main loop */

static void LogEvent(uint32_t ev, uint32_t a, uint32_t b, uint32_t c)
{
    uint32_t h = logHead;
    if ((uint32_t)(h - logTail) >= LOG_SIZE) {
        audioRelayStats.logDropped++;
        return;
    }
    RelayLogEntry *e = &relayLog[h & (LOG_SIZE - 1u)];
    e->tick = HAL_GetTick();
    e->ev = ev;
    e->a = a;
    e->b = b;
    e->c = c;
    logHead = h + 1u;
}

#else
static inline void LogEvent(uint32_t ev, uint32_t a, uint32_t b, uint32_t c)
{ (void)ev; (void)a; (void)b; (void)c; }
#endif

/* ------------------------------------------------------------ */
static inline void FpgaCsLow(void)
{
#ifdef FPGA_CS_Pin
    HAL_GPIO_WritePin(FPGA_CS_GPIO_Port, FPGA_CS_Pin, GPIO_PIN_RESET);
#endif
}

static inline void FpgaCsHigh(void)
{
#ifdef FPGA_CS_Pin
    HAL_GPIO_WritePin(FPGA_CS_GPIO_Port, FPGA_CS_Pin, GPIO_PIN_SET);
#endif
}

#if RELAY_RAMP_CHECK
static void CheckRamp(const int16_t *buf)
{
    uint8_t logged = 0;
    for (uint32_t i = 0; i < BUFFER_SAMPLES; i++) {
        if ((uint16_t)buf[i] != rampNext) {
            audioRelayStats.rampErrors++;
            if (!logged) {
                logged = 1;
                LogEvent(EV_RAMP_ERR, rampNext, (uint16_t)buf[i],
                         (i << 16) | (audioRelayStats.rxFrames & 0xFFFFu));
            }
            rampNext = (uint16_t)buf[i];          /* resync */
        }
        rampNext = (rampNext + 1) & 0x7FFF;
    }
}
#else
static inline void CheckRamp(const int16_t *buf) { (void)buf; }
#endif

#if RELAY_LOOPBACK_CHECK
typedef struct {
    uint32_t n;               /* number of mismatching frames seen so far */
    uint32_t badFrame[200];    /* spiFrames number of mismatching frames (1-based) */
    uint32_t firstIdx[200];    /* index of the first differing word in that frame */
    uint16_t sent[200];        /* word that was sent at that index */
    uint16_t got[200];         /* word that came back at that index */
    uint32_t wordsBad[200];    /* how many of the 512 words differed in that frame */
} LoopDiag;
volatile LoopDiag loopDiag;   /* add to Live Expressions */

static void CheckLoopback(const int16_t *out, const int16_t *in)
{
    audioRelayStats.loopChecked++;

    uint32_t bad = 0, first = 0;
    for (uint32_t i = 0; i < BUFFER_SAMPLES; i++) {
        if (out[i] != in[i]) {
            if (bad == 0) first = i;
            bad++;
        }
    }
    if (bad) {
        audioRelayStats.loopMismatch++;
        uint32_t n = loopDiag.n;
        if (n < 200) {
            loopDiag.badFrame[n] = audioRelayStats.spiFrames;
            loopDiag.firstIdx[n] = first;
            loopDiag.sent[n]     = (uint16_t)out[first];
            loopDiag.got[n]      = (uint16_t)in[first];
            loopDiag.wordsBad[n] = bad;
        }
        loopDiag.n = n + 1;
    }
}
#else
static inline void CheckLoopback(const int16_t *out, const int16_t *in) { (void)out; (void)in; }
#endif

/* Arm UART RX into the right destination (real buffer, or dump on overrun). */
static void RxArm(void)
{
    uint8_t *dst = rxDumping ? (uint8_t *)bufDump : (uint8_t *)outBuf[rxIdx];
    HAL_StatusTypeDef st = HAL_UART_Receive_DMA(&huart2, dst, BUFFER_BYTES);
    if (st != HAL_OK) {
        audioRelayStats.rxArmFail++;
        LogEvent(EV_RX_ARM_FAIL, (uint32_t)st, huart2.RxState, huart2.ErrorCode);
    }
}

/* Start an SPI transaction if idle, an out buffer is full, and the in
 * buffer it will fill is free. */
static void TrySpiStart(void)
{
#if RELAY_ENABLE_SPI
    if (spiBusy) return;

    if (!outReady[spiOutIdx]) {
        audioRelayStats.spiStalls++;
        return;
    }
    if (inReady[spiInIdx]) {
        audioRelayStats.inBlocked++;
        return;
    }

    spiCurOut = spiOutIdx;
    spiCurIn  = spiInIdx;

    outReady[spiCurOut] = 0;           /* out buffer now owned by SPI */
    spiBusy = 1;

    FpgaCsLow();
    if (HAL_SPI_TransmitReceive_DMA(&hspi1,
                                    (uint8_t *)outBuf[spiCurOut],
                                    (uint8_t *)inBuf[spiCurIn],
                                    SPI_FRAMES) != HAL_OK) {
        FpgaCsHigh();
        spiBusy = 0;
        outReady[spiCurOut] = 1;
        audioRelayStats.spiErrors++;
        return;
    }

    if (audioRelayStats.spiFrames < 4) LogEvent(EV_SPI_START, audioRelayStats.spiFrames, 0, 0);

    spiOutIdx ^= 1;
    spiInIdx  ^= 1;
#endif
}

/* Start UART TX of the next in buffer if one is full and TX is idle. */
static void TryUartTxStart(void)
{
#if RELAY_ENABLE_UART_TX
    if (uartTxBusy || !inReady[txIdx]) return;

    uartTxBusy = 1;
    HAL_StatusTypeDef st = HAL_UART_Transmit_DMA(&huart2, (uint8_t *)inBuf[txIdx], BUFFER_BYTES);
    if (st != HAL_OK) {
        uartTxBusy = 0;                /* stays inReady; retried on the next event */
        audioRelayStats.txBusyHits++;
        LogEvent(EV_TX_BUSY, (uint32_t)st, 0, 0);
    } else if (audioRelayStats.txFrames < 4) {
        LogEvent(EV_TX_START, audioRelayStats.txFrames, 0, 0);
    }
#endif
}

/* ------------------------------------------------------------ */
void AudioRelay_Init(void)
{
    memset(bufOut_A, 0, sizeof bufOut_A);
    memset(bufOut_B, 0, sizeof bufOut_B);
    memset(bufIn_A,  0, sizeof bufIn_A);
    memset(bufIn_B,  0, sizeof bufIn_B);

    outReady[0] = outReady[1] = 0;
    inReady[0]  = inReady[1]  = 0;
    rxIdx = spiOutIdx = spiCurOut = 0;
    spiInIdx = spiCurIn = txIdx = 0;
    spiBusy = uartTxBusy = 0;
    rxDumping = 0;
#if RELAY_RAMP_CHECK
    rampNext = 0;
#endif

    FpgaCsHigh();
    RxArm();    /* first SPI transaction starts from the RX callback once a buffer fills */
}

/* ------------------------------------------------------------
 * UART RX complete: laptop -> STM32
 * ------------------------------------------------------------ */
void HAL_UART_RxCpltCallback(UART_HandleTypeDef *huart)
{
    if (huart->Instance != huart2.Instance) return;

    if (rxDumping) {
        rxDumping = 0;                 /* dropped frame; rxIdx unchanged */
    } else {
        audioRelayStats.rxFrames++;
        if (audioRelayStats.rxFrames <= 4) {
            LogEvent(EV_RX_FRAME, audioRelayStats.rxFrames,
                     (uint16_t)outBuf[rxIdx][0], hdma_usart2_rx.Instance->NDTR);
        }
        CheckRamp(outBuf[rxIdx]);
#if RELAY_ENABLE_SPI
        outReady[rxIdx] = 1;           /* hand to SPI */
#endif
        rxIdx ^= 1;
    }

    /* If the next buffer is still unconsumed or is being read by SPI right
     * now, do NOT write into it (that would tear the SPI transmission).
     * Receive this frame into bufDump instead and drop it. The UART stream
     * stays aligned; the newest frame is the one lost. */
    if (outReady[rxIdx] || (spiBusy && spiCurOut == rxIdx)) {
        rxDumping = 1;
        audioRelayStats.rxOverrun++;
        LogEvent(EV_RX_OVERRUN, audioRelayStats.rxFrames, rxIdx, 0);
    }

    RxArm();
    TrySpiStart();
}

/* ------------------------------------------------------------
 * SPI full-duplex complete: STM32 <-> FPGA
 * ------------------------------------------------------------ */
void HAL_SPI_TxRxCpltCallback(SPI_HandleTypeDef *hspi)
{
    if (hspi->Instance != hspi1.Instance) return;

    FpgaCsHigh();
    audioRelayStats.spiFrames++;
    if (audioRelayStats.spiFrames <= 4) LogEvent(EV_SPI_DONE, audioRelayStats.spiFrames, 0, 0);

    CheckLoopback(outBuf[spiCurOut], inBuf[spiCurIn]);

#if RELAY_ENABLE_UART_TX
    inReady[spiCurIn] = 1;             /* hand to UART TX */
#endif
    spiBusy = 0;

    TryUartTxStart();
    TrySpiStart();
}

/* ------------------------------------------------------------
 * UART TX complete: STM32 -> laptop
 * ------------------------------------------------------------ */
void HAL_UART_TxCpltCallback(UART_HandleTypeDef *huart)
{
    if (huart->Instance != huart2.Instance) return;

    audioRelayStats.txFrames++;
    if (audioRelayStats.txFrames <= 4) LogEvent(EV_TX_DONE, audioRelayStats.txFrames, 0, 0);

    inReady[txIdx] = 0;
    txIdx ^= 1;
    uartTxBusy = 0;

    TryUartTxStart();
    TrySpiStart();                     /* an in buffer was just freed */
}

/* ------------------------------------------------------------
 * Error handling: count and recover. Note a UART error can drop bytes,
 * and the stream has no framing, so after one the data stays misaligned
 * until you reset both sides.
 * ------------------------------------------------------------ */
void HAL_UART_ErrorCallback(UART_HandleTypeDef *huart)
{
    if (huart->Instance != huart2.Instance) return;

    audioRelayStats.uartErrors++;
    audioRelayStats.lastUartErr = huart->ErrorCode;
    LogEvent(EV_UART_ERR, huart->ErrorCode, hdma_usart2_rx.Instance->NDTR, __get_IPSR());

    HAL_UART_AbortReceive_IT(&huart2);     /* AbortReceiveCplt callback re-arms RX */

#if RELAY_ENABLE_UART_TX
    if (uartTxBusy && huart->gState == HAL_UART_STATE_READY) {
        uartTxBusy = 0;
        TryUartTxStart();
    }
#endif
}

void HAL_UART_AbortReceiveCpltCallback(UART_HandleTypeDef *huart)
{
    if (huart->Instance != huart2.Instance) return;
    LogEvent(EV_UART_ABORT_CPLT, audioRelayStats.rxFrames, 0, 0);
    RxArm();
}

void HAL_SPI_ErrorCallback(SPI_HandleTypeDef *hspi)
{
    if (hspi->Instance != hspi1.Instance) return;

    uint32_t sr  = SPI1->SR;
    uint32_t irq = __get_IPSR();

    audioRelayStats.spiErrors++;
    audioRelayStats.lastSpiErr = hspi->ErrorCode;
    audioRelayStats.lastSpiSR  = sr;
    audioRelayStats.lastIrq    = irq;
    LogEvent(EV_SPI_ERR, hspi->ErrorCode, sr, (irq & 0xFFu) | ((uint32_t)hspi->State << 8));

    FpgaCsHigh();
    HAL_SPI_Abort_IT(&hspi1);          /* AbortCplt callback clears busy */
}

void HAL_SPI_AbortCpltCallback(SPI_HandleTypeDef *hspi)
{
    if (hspi->Instance != hspi1.Instance) return;

    LogEvent(EV_SPI_ABORT_CPLT, hspi->ErrorCode, 0, 0);

    /* Failed frame is dropped: out buffer stays consumed, in buffer stays free. */
    spiBusy = 0;
    TrySpiStart();
}

/* ============================================================
 * AudioRelay_Report()  -- call from the main loop (NOT from an ISR).
 *   - drains the event log to ITM
 *   - prints one status line per second
 *   - prints a config line every 10 seconds (so you can attach SWV late)
 * ============================================================ */
#if RELAY_DEBUG_PRINT

static void dbg_printf(const char *fmt, ...)
{
    char line[200];
    va_list ap;
    va_start(ap, fmt);
    int n = vsnprintf(line, sizeof line, fmt, ap);
    va_end(ap);
    if (n < 0) return;
    if (n > (int)sizeof line - 1) n = (int)sizeof line - 1;
    for (int i = 0; i < n; i++) {
        ITM_SendChar((uint32_t)(uint8_t)line[i]);   /* no-op if SWV/ITM is not enabled */
    }
}

static void DecodeUartErr(uint32_t e, char *o, size_t n)
{
    o[0] = '\0';
    if (e == 0)                   strncat(o, "none", n - strlen(o) - 1);
    if (e & HAL_UART_ERROR_PE)    strncat(o, "PE ",  n - strlen(o) - 1);
    if (e & HAL_UART_ERROR_NE)    strncat(o, "NE ",  n - strlen(o) - 1);
    if (e & HAL_UART_ERROR_FE)    strncat(o, "FE ",  n - strlen(o) - 1);
    if (e & HAL_UART_ERROR_ORE)   strncat(o, "ORE ", n - strlen(o) - 1);
    if (e & HAL_UART_ERROR_DMA)   strncat(o, "DMA ", n - strlen(o) - 1);
}

static void DecodeSpiErr(uint32_t e, char *o, size_t n)
{
    o[0] = '\0';
    if (e == 0)                   strncat(o, "none",  n - strlen(o) - 1);
    if (e & HAL_SPI_ERROR_MODF)   strncat(o, "MODF ", n - strlen(o) - 1);
    if (e & HAL_SPI_ERROR_CRC)    strncat(o, "CRC ",  n - strlen(o) - 1);
    if (e & HAL_SPI_ERROR_OVR)    strncat(o, "OVR ",  n - strlen(o) - 1);
    if (e & HAL_SPI_ERROR_FRE)    strncat(o, "FRE ",  n - strlen(o) - 1);
    if (e & HAL_SPI_ERROR_DMA)    strncat(o, "DMA ",  n - strlen(o) - 1);
    if (e & HAL_SPI_ERROR_FLAG)   strncat(o, "FLAG ", n - strlen(o) - 1);
    if (e & HAL_SPI_ERROR_ABORT)  strncat(o, "ABORT ",n - strlen(o) - 1);
}

static void PrintEvent(const RelayLogEntry *e)
{
    char names[48];
    unsigned long t = (unsigned long)e->tick;

    switch (e->ev) {
    case EV_RX_FRAME:
        dbg_printf("[%8lu] RX frame #%lu done, first sample=%lu, DMA NDTR=%lu\r\n",
                   t, (unsigned long)e->a, (unsigned long)e->b, (unsigned long)e->c);
        break;
    case EV_RX_OVERRUN:
        dbg_printf("[%8lu] RX OVERRUN: dropping frame (rxFrames=%lu, rxIdx=%lu)\r\n",
                   t, (unsigned long)e->a, (unsigned long)e->b);
        break;
    case EV_RX_ARM_FAIL:
        dbg_printf("[%8lu] RX ARM FAILED: HAL status=%lu RxState=0x%02lX ErrorCode=0x%lX\r\n",
                   t, (unsigned long)e->a, (unsigned long)e->b, (unsigned long)e->c);
        break;
    case EV_UART_ERR:
        DecodeUartErr(e->a, names, sizeof names);
        dbg_printf("[%8lu] UART ERROR: code=0x%lX (%s) DMA NDTR=%lu irq=%lu\r\n",
                   t, (unsigned long)e->a, names, (unsigned long)e->b,
                   (unsigned long)(e->c - 16u));
        break;
    case EV_UART_ABORT_CPLT:
        dbg_printf("[%8lu] UART RX abort complete, re-arming (rxFrames=%lu)\r\n",
                   t, (unsigned long)e->a);
        break;
    case EV_SPI_ERR:
        DecodeSpiErr(e->a, names, sizeof names);
        dbg_printf("[%8lu] SPI ERROR: code=0x%lX (%s) SR=0x%lX called-from IRQn=%lu hspi.State=0x%02lX\r\n",
                   t, (unsigned long)e->a, names, (unsigned long)e->b,
                   (unsigned long)((e->c & 0xFFu) - 16u), (unsigned long)(e->c >> 8));
        break;
    case EV_SPI_ABORT_CPLT:
        DecodeSpiErr(e->a, names, sizeof names);
        dbg_printf("[%8lu] SPI abort complete, ErrorCode=0x%lX (%s)\r\n",
                   t, (unsigned long)e->a, names);
        break;
    case EV_SPI_START:
        dbg_printf("[%8lu] SPI transfer started (spiFrames=%lu)\r\n", t, (unsigned long)e->a);
        break;
    case EV_SPI_DONE:
        dbg_printf("[%8lu] SPI transfer done (spiFrames=%lu)\r\n", t, (unsigned long)e->a);
        break;
    case EV_TX_START:
        dbg_printf("[%8lu] UART TX started (txFrames=%lu)\r\n", t, (unsigned long)e->a);
        break;
    case EV_TX_DONE:
        dbg_printf("[%8lu] UART TX done (txFrames=%lu)\r\n", t, (unsigned long)e->a);
        break;
    case EV_TX_BUSY:
        dbg_printf("[%8lu] UART TX start refused, HAL status=%lu\r\n", t, (unsigned long)e->a);
        break;
    case EV_RAMP_ERR:
        dbg_printf("[%8lu] RAMP BREAK in frame %lu at sample index %lu: expected %lu, got %lu\r\n",
                   t, (unsigned long)(e->c & 0xFFFFu), (unsigned long)(e->c >> 16),
                   (unsigned long)e->a, (unsigned long)e->b);
        break;
    default:
        dbg_printf("[%8lu] event %lu a=%lu b=%lu c=%lu\r\n", t, (unsigned long)e->ev,
                   (unsigned long)e->a, (unsigned long)e->b, (unsigned long)e->c);
        break;
    }
}

void AudioRelay_Report(void)
{
    static uint32_t lastTick;
    static uint32_t lastRx;
    static uint32_t lines;

    /* 1) drain the event log */
    while (logTail != logHead) {
        RelayLogEntry e = relayLog[logTail & (LOG_SIZE - 1u)];
        logTail++;
        PrintEvent(&e);
    }

    /* 2) once per second: status line */
    uint32_t now = HAL_GetTick();
    uint32_t dt  = now - lastTick;
    if (dt < 1000u) return;

    uint32_t rx    = audioRelayStats.rxFrames;
    uint32_t perS  = (dt > 0u) ? ((rx - lastRx) * 1000u / dt) : 0u;
    lastTick = now;
    lastRx   = rx;
    lines++;

    dbg_printf("[%8lu] rx=%lu (+%lu/s; real-time=187) ramp=%lu uartErr=%lu spiErr=%lu armFail=%lu "
               "overrun=%lu | huart2 g=0x%02lX rx=0x%02lX | RX NDTR=%lu\r\n",
               (unsigned long)now,
               (unsigned long)rx, (unsigned long)perS,
               (unsigned long)audioRelayStats.rampErrors,
               (unsigned long)audioRelayStats.uartErrors,
               (unsigned long)audioRelayStats.spiErrors,
               (unsigned long)audioRelayStats.rxArmFail,
               (unsigned long)audioRelayStats.rxOverrun,
               (unsigned long)huart2.gState, (unsigned long)huart2.RxState,
               (unsigned long)hdma_usart2_rx.Instance->NDTR);

    /* 3) every 10 s (and at the 3rd second): configuration snapshot */
    if ((lines % 10u) == 3u) {
        dbg_printf("[%8lu] CFG: SPI=%d UART_TX=%d RAMP=%d LOOP=%d | huart2 baud=%lu | SYSCLK=%lu PCLK1=%lu | "
                   "SPI1 CR1=0x%04lX CR2=0x%02lX SR=0x%02lX\r\n",
                   (unsigned long)now,
                   RELAY_ENABLE_SPI, RELAY_ENABLE_UART_TX, RELAY_RAMP_CHECK, RELAY_LOOPBACK_CHECK,
                   (unsigned long)huart2.Init.BaudRate,
                   (unsigned long)SystemCoreClock, (unsigned long)HAL_RCC_GetPCLK1Freq(),
                   (unsigned long)SPI1->CR1, (unsigned long)SPI1->CR2, (unsigned long)SPI1->SR);
    }
}

#else
void AudioRelay_Report(void) { }
#endif
