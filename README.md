# FIR_Filter

Reconfigurable FIR channel-select filter: a three-song composite (channels at 8 / 22 / 36 kHz,
fs = 96 kHz) is streamed from MATLAB to an STM32, which relays it over SPI to a Basys 3 FPGA that
implements the FIR. The same RTL is later compared as FPGA vs ASIC (LibreLane) for PPA.

```
MATLAB ──UART 2.25 Mbaud──▶ STM32 Nucleo-F446RE ──SPI──▶ Basys 3 (Artix-7) FIR
   │                                                          ▲
   └── golden-model hex vectors (matlab/data/vectors) ────────┘  used by Verilog testbenches
```

| Folder | What | Open with |
|---|---|---|
| `matlab/` | design, quantization, golden model, streaming and analysis scripts | MATLAB: open `matlab/FIR_Filter.prj` (see `matlab/README.md`) |
| `stm32/FPGA_Data_Bridge/` | CubeMX/HAL project: UART in, double-buffered DMA, SPI out (`Core/Src/audio_relay.c`) | STM32CubeIDE: File → Import → Existing Projects into Workspace → select `stm32/FPGA_Data_Bridge` |
| `fpga/` | Verilog (`rtl/`), testbenches (`tb/`), Basys 3 constraints (`constraints/`) | Vivado: Tcl console → `cd <repo>/fpga` then `source scripts/create_project.tcl` |

## STM32 notes
- Tested with STM32CubeIDE 1.19 and STM32Cube_FW_F4 V1.28.3. `Drivers/` is committed so the project builds right after import; `Debug/` is not (CubeIDE regenerates it).
- Change pins/peripherals in `FPGA Data Bridge.ioc`; keep your own code inside the `USER CODE` blocks. `audio_relay.c` is plain user code.
- Pins: SPI SCK PA5, MISO PA6, MOSI PA7, CS PB6 (to Basys 3 Pmod JA1-JA4).

## FPGA notes
- Part `xc7a35tcpg236-1` (Basys 3), tested with Vivado 2026.1. The Vivado project is generated into `fpga/vivado/` (gitignored); sources stay in `fpga/rtl`, `fpga/tb`, `fpga/constraints`, so edits show up directly in git.
- When you add a new source file, add it to `fpga/scripts/create_project.tcl` so the next rebuild includes it.
- Golden vectors from MATLAB are in `matlab/data/vectors/` (from `fpga/` that is `../matlab/data/vectors/`). Re-run MATLAB stage 04 to regenerate them and commit the result.

## Workflow
Each tool owns its folder; nothing outside `matlab/` depends on MATLAB being installed. Generated build output (Debug/, Vivado runs, bitstreams) is gitignored.
