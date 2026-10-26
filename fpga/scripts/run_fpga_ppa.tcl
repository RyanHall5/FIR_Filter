# Runs the FPGA power/performance/area sweep and stores the results for MATLAB.
#
# AI note: written by Claude (Anthropic) at the author's request.
#
# Usage (no other input needed):
#   vivado -mode batch -source fpga/scripts/run_fpga_ppa.tcl
# Run it from anywhere; every path is relative to this script. To change what is swept,
# edit the three lists under "Sweep settings" (architectures, variants, clock periods).
#
# What it does, for every architecture x variant x clock period:
#   1. builds a scratch Vivado project for the architecture's top module, out of context
#      (no I/O buffers, so the numbers are the filter itself, not the SPI/board wrapper)
#   2. synthesizes and implements it (through route_design) at that clock period
#   3. writes the reports and a summary.csv into
#        matlab/data/ppa_reports/fpga/<architecture>/<variant>_<period>ns/
#   4. appends one row to matlab/data/ppa_reports/fpga/fpga_ppa_summary.csv (all runs)
#   5. deletes the scratch project (the reports and post_route.dcp are kept)
#
# Variants: "dsp" lets Vivado use the DSP48 blocks for the multiplier; "nodsp" forces the
# multiplier into fabric LUTs (-max_dsp 0), which separates the hard-block advantage from
# the architecture itself and is the fairer comparison with ASIC.
#
# Power here is Vivado's vectorless estimate (default switching activity), recorded in the
# summary as power_method = vectorless. If you later write a SAIF file to
#   matlab/data/ppa_reports/activity/<architecture>.saif
# the script reads it and records power_method = saif instead.
#
# Resume: a run that finished leaves a summary.csv in its folder. Running the script again
# skips those and retries only the failed or missing runs (set rerun_all 1 to redo them all).
# Errors are also appended to matlab/data/ppa_reports/fpga/failed_runs.log.
#
# Notes: timing is checked against a clock named clk on the top module's clk port; I/O
# paths are not constrained (out of context). Add "fpga/vivado_ppa/" and "*.dcp" to .gitignore.

set script_dir [file dirname [file normalize [info script]]]
set fpga_dir   [file normalize [file join $script_dir ..]]
set repo_dir   [file normalize [file join $fpga_dir ..]]
set rtl_dir    [file join $fpga_dir rtl]
set vec_dir    [file join $repo_dir matlab data vectors]
set ppa_dir    [file join $repo_dir matlab data ppa_reports]
set out_root   [file join $ppa_dir fpga]
set scratch    [file join $fpga_dir vivado_ppa]
set part       xc7a35tcpg236-1

#====================================================
# Sweep settings (edit these)
#====================================================
# architecture name -> top module and the RTL files it needs (in fpga/rtl).
# Add the semi-parallel and fully parallel designs here when they exist.
set archs [dict create \
    serial_mac [dict create top FIR_Core_MAC files {FIR_Core_MAC.v coef_rom.v sample_buffer.v}] ]
set variants {dsp nodsp}
set periods  {10.0 8.0 6.0 5.0}      ;# target clock periods in ns
set jobs     4                        ;# parallel jobs for synthesis and implementation
set keep_projects 0                   ;# 1 keeps the scratch projects
set rerun_all     0                   ;# 0 skips runs that already have a summary.csv (so a second
                                      ;# run only retries the ones that failed); 1 redoes everything

#====================================================
# Helpers
#====================================================

# First capture group of a regexp in text, or NA
proc grab {pattern text} {
    if {[regexp -- $pattern $text -> v]} { return $v }
    return NA
}

proc git_commit {repo_dir} {
    if {[catch {exec git -C $repo_dir rev-parse --short HEAD} c]} { return NA }
    return $c
}

# One synthesis + implementation run; returns after writing its reports and summary row
proc run_one {arch top files variant period} {
    global fpga_dir repo_dir rtl_dir vec_dir ppa_dir out_root scratch part jobs keep_projects rerun_all

    set tag    [format "%s_%sns" $variant $period]
    set rundir [file join $out_root $arch $tag]
    set proj   [file join $scratch ${arch}_$tag]
    if {!$rerun_all && [file exists [file join $rundir summary.csv]]} {
        puts "\n===== skipping $arch / $variant / ${period} ns (already done) ====="
        return
    }
    file mkdir $rundir

    puts "\n===== PPA run: $arch / $variant / ${period} ns ====="

    create_project -force ppa $proj -part $part
    set_property target_language Verilog [current_project]

    foreach f $files { add_files -fileset sources_1 [file join $rtl_dir $f] }
    # coefficient hex files read by coef_rom ($readmemh), marked as data files
    foreach hexf [lsort [glob -directory $vec_dir coef_ch*.hex]] {
        add_files -fileset sources_1 $hexf
        set_property file_type {Data Files} [get_files $hexf]
    }
    set_property top $top [get_filesets sources_1]

    # Constraint: a single clock on the clk port at the target period
    set xdc [file join $rundir clk.xdc]          ;# kept with the results, so the constraint is on record
    set fh [open $xdc w]
    puts $fh "create_clock -name clk -period $period \[get_ports clk\]"
    close $fh
    add_files -fileset constrs_1 $xdc

    set opts "-mode out_of_context"
    if {$variant eq "nodsp"} { append opts " -max_dsp 0" }
    set_property -name {STEPS.SYNTH_DESIGN.ARGS.MORE OPTIONS} -value $opts -objects [get_runs synth_1]

    launch_runs synth_1 -jobs $jobs
    wait_on_run synth_1
    if {[get_property PROGRESS [get_runs synth_1]] ne "100%"} { error "synthesis failed for $arch $tag" }

    launch_runs impl_1 -to_step route_design -jobs $jobs
    wait_on_run impl_1
    if {[get_property PROGRESS [get_runs impl_1]] ne "100%"} { error "implementation failed for $arch $tag" }
    open_run impl_1

    # ---- optional switching activity from simulation ----
    set saif [file join $ppa_dir activity ${arch}.saif]
    set power_method vectorless
    if {[file exists $saif]} {
        if {![catch {read_saif $saif}]} { set power_method saif }
    }

    # ---- reports (kept as text for MATLAB and for the poster) ----
    report_utilization              -file [file join $rundir utilization.rpt]
    report_utilization -hierarchical -file [file join $rundir utilization_hier.rpt]
    report_timing_summary           -file [file join $rundir timing_summary.rpt]
    report_power                    -file [file join $rundir power.rpt]
    write_checkpoint -force [file join $rundir post_route.dcp]

    # ---- key numbers ----
    set util  [report_utilization -return_string]
    set pwr   [report_power -return_string]

    set luts  [grab {\|\s*(?:Slice|CLB) LUTs\*?\s*\|\s*(\d+)} $util]
    set lutm  [grab {\|\s*LUT as Memory\s*\|\s*(\d+)} $util]
    set ffs   [grab {\|\s*(?:Slice|CLB) Registers\s*\|\s*(\d+)} $util]
    set dsps  [grab {\|\s*DSPs\s*\|\s*(\d+)} $util]
    set bram  [grab {\|\s*Block RAM Tile\s*\|\s*([\d.]+)} $util]

    set wns NA
    set whs NA
    set sp [get_timing_paths -max_paths 1 -setup]
    if {[llength $sp]} { set wns [get_property SLACK $sp] }
    set hp [get_timing_paths -max_paths 1 -hold]
    if {[llength $hp]} { set whs [get_property SLACK $hp] }

    set fmax NA
    set met  NA
    if {$wns ne "NA"} {
        set fmax [format "%.1f" [expr {1000.0 / ($period - $wns)}]]
        set met  [expr {$wns >= 0 ? "yes" : "no"}]
    }

    set dyn   [grab {Dynamic \(W\)\s*\|\s*([\d.]+)} $pwr]
    set stat  [grab {Device Static \(W\)\s*\|\s*([\d.]+)} $pwr]
    set total [grab {Total On-Chip Power \(W\)\s*\|\s*([\d.]+)} $pwr]

    set header "architecture,variant,period_ns,wns_ns,whs_ns,timing_met,fmax_mhz,luts,lut_as_memory,ffs,dsps,bram_tiles,dynamic_w,static_w,total_w,power_method,part,vivado,commit,date"
    set row [join [list $arch $variant $period $wns $whs $met $fmax $luts $lutm $ffs $dsps $bram \
                        $dyn $stat $total $power_method $part [version -short] [git_commit $repo_dir] \
                        [clock format [clock seconds] -format "%Y-%m-%d %H:%M:%S"]] ,]

    # per-run summary
    set fh [open [file join $rundir summary.csv] w]
    puts $fh $header
    puts $fh $row
    close $fh

    # master table: one row per run (header written once)
    set master [file join $out_root fpga_ppa_summary.csv]
    set new [expr {![file exists $master]}]
    set fh [open $master a]
    if {$new} { puts $fh $header }
    puts $fh $row
    close $fh

    puts "  WNS $wns ns, fmax $fmax MHz, LUTs $luts, FFs $ffs, DSPs $dsps, BRAM $bram, dynamic $dyn W ($power_method)"

    close_project
    if {!$keep_projects} { file delete -force $proj }
}

#====================================================
# Run the sweep
#====================================================
file mkdir $out_root
file mkdir $scratch
set failed {}
dict for {arch spec} $archs {
    set top   [dict get $spec top]
    set files [dict get $spec files]
    foreach variant $variants {
        foreach period $periods {
            if {[catch {run_one $arch $top $files $variant $period} err]} {
                puts "ERROR in $arch $variant ${period} ns: $err"
                set lf [open [file join $out_root failed_runs.log] a]
                puts $lf "[clock format [clock seconds] -format {%Y-%m-%d %H:%M:%S}]  $arch $variant ${period} ns: $err"
                close $lf
                lappend failed "$arch/$variant/${period}ns"
                catch {close_project}
            }
        }
    }
}

puts "\n===== FPGA PPA sweep finished ====="
puts "Results: $out_root"
puts "Master table: [file join $out_root fpga_ppa_summary.csv]"
if {[llength $failed]} { puts "FAILED runs: $failed" } else { puts "All runs completed." }
