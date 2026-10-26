#!/usr/bin/env python3
"""
run_asic_ppa.py -- clock-period sweep of one design through LibreLane (Sky130) and
collect the key PPA numbers into one CSV, the ASIC counterpart of run_fpga_ppa.tcl.

AI note: written by Claude (Anthropic) for Ryan Hall's FIR_Filter project.
NOT yet run against a real LibreLane install - check the first run's output and
the metric names (see METRICS below) against your run's final/metrics.json.

Usage (from the repo root, in the shell where `librelane` works):
    python asic/scripts/run_asic_ppa.py                          # serial_mac, default periods
    python asic/scripts/run_asic_ppa.py --design serial_mac --periods 20 15 12 10
    python asic/scripts/run_asic_ppa.py --collect-only           # just rebuild the CSV

For each period it copies asic/<design>/config.json with CLOCK_PERIOD changed, runs
LibreLane with run tag <design>_<period>ns, and skips periods already done. Results:
    asic/<design>/runs/<tag>/                    full LibreLane run
    matlab/data/ppa_reports/asic/asic_ppa_summary.csv
"""
import argparse, csv, json, subprocess, sys, datetime
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
OUT_CSV = REPO / "matlab/data/ppa_reports/asic/asic_ppa_summary.csv"

# column -> candidate keys in final/metrics.json (first one found is used)
METRICS = {
    "setup_ws_ns":    ["timing__setup__ws"],
    "setup_tns_ns":   ["timing__setup__tns"],
    "hold_ws_ns":     ["timing__hold__ws"],
    "setup_viol":     ["timing__setup_vio__count"],
    "hold_viol":      ["timing__hold_vio__count"],
    # design__instance__area also counts filler cells (about 45% of it), so use the stdcell value
    # (logic + flops + repair buffers + tap cells). Class rows break it down for the poster.
    "cell_area_um2":  ["design__instance__area__stdcell"],
    "seq_area_um2":   ["design__instance__area__class:sequential_cell"],
    "comb_area_um2":  ["design__instance__area__class:multi_input_combinational_cell"],
    "repair_buf_area_um2": ["design__instance__area__class:timing_repair_buffer"],
    "clock_tree_area_um2": ["design__instance__area__class:clock_buffer"],
    "tap_area_um2":   ["design__instance__area__class:tap_cell"],
    "fill_area_um2":  ["design__instance__area__class:fill_cell"],
    "core_area_um2":  ["design__core__area"],
    "instances":      ["design__instance__count", "design__instance__count__stdcell"],
    "flops":          ["design__instance__count__class:sequential_cell"],
    "die_area_um2":   ["design__die__area"],
    "util_pct":       ["design__instance__utilization"],
    "power_total_w":  ["power__total"],
    "power_internal_w": ["power__internal__total"],
    "power_switching_w": ["power__switching__total"],
    "power_leakage_w": ["power__leakage__total"],
    "drc_errors":     ["route__drc_errors", "magic__drc_error__count"],
    "lvs_errors":     ["design__lvs_error__count"],
    "antenna_viol":   ["antenna__violating__nets"],
}

def metrics_path(design, tag):
    return REPO / f"asic/{design}/runs/{tag}/final/metrics.json"

def run_one(design, period, extra):
    tag = f"{design}_{period}ns"
    if metrics_path(design, tag).exists():
        print(f"== skipping {tag} (already done)")
        return tag
    base = json.loads((REPO / f"asic/{design}/config.json").read_text())
    base["CLOCK_PERIOD"] = float(period)
    cfg = REPO / f"asic/{design}/config_{period}ns.json"
    cfg.write_text(json.dumps(base, indent=2))
    print(f"== LibreLane: {tag}")
    cmd = ["librelane", str(cfg), "--run-tag", tag,
           "--design-dir", str(REPO / f"asic/{design}")] + extra
    r = subprocess.run(cmd, cwd=REPO / f"asic/{design}")
    cfg.unlink(missing_ok=True)
    if r.returncode != 0:
        print(f"!! {tag} failed (exit {r.returncode}); see asic/{design}/runs/{tag}/")
    return tag

def finished_periods(design):
    """Periods of every finished run on disk, largest first."""
    found = []
    for mp in (REPO / f"asic/{design}/runs").glob(f"{design}_*ns/final/metrics.json"):
        tag = mp.parents[1].name
        try:
            found.append(float(tag[len(design) + 1:-2]))
        except ValueError:
            pass
    return [f"{p:g}" for p in sorted(found, reverse=True)]

def collect(design, periods=None):
    rows = []
    for p in (periods or finished_periods(design)):
        tag = f"{design}_{p}ns"
        mp = metrics_path(design, tag)
        if not mp.exists():
            continue
        m = json.loads(mp.read_text())
        row = {"architecture": design, "period_ns": p}
        wns = None
        for col, keys in METRICS.items():
            val = next((m[k] for k in keys if k in m), "NA")
            row[col] = val
        try:
            wns = float(row["setup_ws_ns"])
            row["timing_met"] = "yes" if wns >= 0 and not float(row["setup_viol"] or 0) else "no"
            row["fmax_mhz"] = f"{1000.0 / (float(p) - wns):.1f}"
        except (TypeError, ValueError):
            row["timing_met"] = row["fmax_mhz"] = "NA"
        row["power_method"] = "default_activity"
        row["date"] = datetime.datetime.fromtimestamp(mp.stat().st_mtime).strftime("%Y-%m-%d %H:%M:%S")
        rows.append(row)
        missing = [c for c in METRICS if row[c] == "NA"]
        if missing:
            print(f"   note: {tag} has no value for {missing} - check key names in {mp}")
    if not rows:
        print("no finished runs to collect")
        return
    OUT_CSV.parent.mkdir(parents=True, exist_ok=True)
    cols = list(rows[0].keys())
    with open(OUT_CSV, "w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=cols)
        w.writeheader()
        w.writerows(rows)
    print(f"wrote {OUT_CSV} ({len(rows)} rows)")

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--design", default="serial_mac")
    ap.add_argument("--periods", nargs="+", default=["30", "25", "20", "15"])
    ap.add_argument("--collect-only", action="store_true")
    ap.add_argument("extra", nargs="*", help="extra args passed to librelane (after --)")
    a = ap.parse_args()
    if not a.collect_only:
        for p in a.periods:
            run_one(a.design, p, a.extra)
    collect(a.design)   # every finished run on disk, not just this invocation's periods

if __name__ == "__main__":
    sys.exit(main())
