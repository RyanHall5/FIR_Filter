#!/usr/bin/env python3
"""
run_asic_ppa.py -- clock-period sweep of one or more designs through LibreLane (Sky130)
and collect the key PPA numbers into one CSV, the ASIC counterpart of run_fpga_ppa.tcl.

AI note: written by Claude (Anthropic) for Ryan Hall's FIR_Filter project.
NOT yet run against a real LibreLane install - check the first run's output and
the metric names (see METRICS below) against your run's final/metrics.json.

Usage (from the repo root, in the shell where `librelane` works):
    python asic/scripts/run_asic_ppa.py --design lanes1 --periods 40
    python asic/scripts/run_asic_ppa.py --design lanes1 lanes2 lanes4 --periods 40 25
    python asic/scripts/run_asic_ppa.py --collect-only           # just rebuild the CSV

For each design and period it copies asic/<design>/config.json with CLOCK_PERIOD
changed, runs LibreLane with run tag <design>_<period>ns, and skips runs already done.
After each run it records the git commit in runs/<tag>/ppa_meta.json. Results:
    asic/<design>/runs/<tag>/                    full LibreLane run
    matlab/data/ppa_reports/asic/asic_ppa_summary.csv   (every design, every finished run)

The CSV is rebuilt from ALL design folders under asic/ each time, so running one
design never drops another design's rows.
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

def git_commit():
    try:
        return subprocess.run(["git", "-C", str(REPO), "rev-parse", "--short", "HEAD"],
                              capture_output=True, text=True, check=True).stdout.strip()
    except Exception:
        return "NA"

def all_designs():
    """Every asic/<name>/ folder that has a config.json (serial_mac, lanes1, ...)."""
    return sorted(d.name for d in (REPO / "asic").iterdir()
                  if d.is_dir() and (d / "config.json").exists())

def lanes_of(design):
    if design == "serial_mac":
        return 1
    if design.startswith("lanes") and design[5:].isdigit():
        return int(design[5:])
    return "NA"

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
    commit = git_commit()
    cmd = ["librelane", str(cfg), "--run-tag", tag,
           "--design-dir", str(REPO / f"asic/{design}")] + extra
    r = subprocess.run(cmd, cwd=REPO / f"asic/{design}")
    cfg.unlink(missing_ok=True)
    run_dir = REPO / f"asic/{design}/runs/{tag}"
    if run_dir.exists():
        (run_dir / "ppa_meta.json").write_text(json.dumps(
            {"commit": commit, "period_ns": float(period), "design": design}, indent=2))
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

def rows_for(design):
    rows = []
    for p in finished_periods(design):
        tag = f"{design}_{p}ns"
        mp = metrics_path(design, tag)
        if not mp.exists():
            continue
        m = json.loads(mp.read_text())
        row = {"architecture": design, "lanes": lanes_of(design), "period_ns": p}
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
        meta = mp.parents[1] / "ppa_meta.json"
        row["commit"] = json.loads(meta.read_text()).get("commit", "NA") if meta.exists() else "NA"
        row["date"] = datetime.datetime.fromtimestamp(mp.stat().st_mtime).strftime("%Y-%m-%d %H:%M:%S")
        rows.append(row)
        missing = [c for c in METRICS if row[c] == "NA"]
        if missing:
            print(f"   note: {tag} has no value for {missing} - check key names in {mp}")
    return rows

def collect():
    """Rebuild the summary CSV from every design's finished runs."""
    rows = []
    for d in all_designs():
        rows += rows_for(d)
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
    ap.add_argument("--design", nargs="+", default=["serial_mac"],
                    help="one or more design folders under asic/ (e.g. lanes1 lanes4)")
    ap.add_argument("--periods", nargs="+", default=["40", "30", "25", "20"])
    ap.add_argument("--collect-only", action="store_true")
    ap.add_argument("extra", nargs="*", help="extra args passed to librelane (after --)")
    a = ap.parse_args()
    if not a.collect_only:
        for d in a.design:
            if not (REPO / f"asic/{d}/config.json").exists():
                sys.exit(f"no asic/{d}/config.json (known designs: {', '.join(all_designs())})")
        for d in a.design:
            for p in a.periods:
                run_one(d, p, a.extra)
    collect()   # every finished run of every design on disk

if __name__ == "__main__":
    sys.exit(main())
