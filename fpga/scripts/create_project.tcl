# Rebuilds the Vivado project from the sources in this repo.
#
# AI note: updated by Claude (Anthropic) at the author's request, to add FIR_Core_MAC
# and the FIR core simulation set. The structure and original sets were written by the author.
#
# Usage (Vivado Tcl console, or batch):
#   cd <repo>/fpga
#   source scripts/create_project.tcl
#   vivado -mode batch -source scripts/create_project.tcl     (batch)
#
# Creates fpga/vivado/FIR_Filter.xpr (gitignored). Edit sources in fpga/rtl, fpga/tb,
# fpga/constraints; the project only references them, so changes go straight to git.
# After adding or renaming a source file, add it here too so the next rebuild picks it up.
#
# Simulation sets (pick one with the current_fileset line near the end, or in the GUI):
#   sim_1             spi_slave          needs no data files
#   sim_coef_rom      coef_rom           reads coef_ch1/2/3.hex
#   sim_sample_buffer sample_buffer      needs no data files
#   sim_fir_core      FIR_Core_MAC       reads coef_ch*.hex plus every in_*.hex / exp_*.hex vector

set script_dir [file dirname [file normalize [info script]]]
set fpga_dir   [file normalize [file join $script_dir ..]]
set proj_dir   [file join $fpga_dir vivado]
set vec_dir    [file normalize [file join $fpga_dir .. matlab data vectors]]

# Golden vectors written by MATLAB (fail early if they are missing)
set coef_files [lsort [glob -nocomplain -directory $vec_dir coef_ch*.hex]]
set in_files   [lsort [glob -nocomplain -directory $vec_dir in_*.hex]]
set exp_files  [lsort [glob -nocomplain -directory $vec_dir exp_*.hex]]
if {[llength $coef_files] != 3 || [llength $in_files] == 0 || [llength $exp_files] == 0} {
    error "Golden vectors not found in $vec_dir (need coef_ch1/2/3.hex, in_*.hex, exp_*.hex). Run the MATLAB stages first."
}

create_project -force FIR_Filter $proj_dir -part xc7a35tcpg236-1
# Basys 3 board files are optional; the part above is enough to build.
catch { set_property board_part digilentinc.com:basys3:part0:1.2 [current_project] }
set_property target_language Verilog [current_project]

# Design sources (RTL + the coefficient hex files the ROM reads)
add_files -fileset sources_1 [list \
    [file join $fpga_dir rtl top.v] \
    [file join $fpga_dir rtl spi_slave.v] \
    [file join $fpga_dir rtl FIR_Core_MAC.v] \
    [file join $fpga_dir rtl coef_rom.v] \
    [file join $fpga_dir rtl sample_buffer.v] ]
add_files -fileset sources_1 $coef_files
set_property top top [get_filesets sources_1]

# Vivado doesn't recognize .hex, so mark the coefficient files as data files
foreach f $coef_files {
    set_property file_type {Data Files} [get_files $f]
}

# Constraints
add_files -fileset constrs_1 [file join $fpga_dir constraints basys3.xdc]

# Simulation set 1: spi_slave
add_files -fileset sim_1 [file join $fpga_dir tb spi_slave_tb.v]
set_property top spi_slave_tb [get_filesets sim_1]
set_property top_lib xil_defaultlib [get_filesets sim_1]

# Simulation set 2: coef_rom (its own set so the tops don't fight)
# The coefficient hex files come from sources_1 as data files.
create_fileset -simset sim_coef_rom
add_files -fileset sim_coef_rom [file join $fpga_dir tb coef_rom_tb.v]
set_property top coef_rom_tb [get_filesets sim_coef_rom]
set_property top_lib xil_defaultlib [get_filesets sim_coef_rom]

# Simulation set 3: sample_buffer (no hex files needed; it ends itself with $finish, use Run All)
create_fileset -simset sim_sample_buffer
add_files -fileset sim_sample_buffer [file join $fpga_dir tb sample_buffer_tb.v]
set_property top sample_buffer_tb [get_filesets sim_sample_buffer]
set_property top_lib xil_defaultlib [get_filesets sim_sample_buffer]

# Simulation set 4: FIR_Core_MAC
# The testbench streams each in_*.hex through the core on every channel and compares the
# output against the matching exp_*.hex ($readmemh by file name, so the vectors must be
# data files in this set). The coefficient hex files come from sources_1.
# It ends itself with $finish after about 36 ms of simulated time, so run with -all.
create_fileset -simset sim_fir_core
add_files -fileset sim_fir_core [file join $fpga_dir tb FIR_Core_Mac_tb.v]
add_files -fileset sim_fir_core $in_files
add_files -fileset sim_fir_core $exp_files
foreach f [concat $in_files $exp_files] {
    set_property file_type {Data Files} [get_files -of_objects [get_filesets sim_fir_core] $f]
}
set_property top FIR_Core_MAC_tb [get_filesets sim_fir_core]
set_property top_lib xil_defaultlib [get_filesets sim_fir_core]
set_property -name {xsim.simulate.runtime} -value {-all} -objects [get_filesets sim_fir_core]

# Which set "Run Simulation" uses (change this line to switch)
current_fileset -simset [get_filesets sim_fir_core]

update_compile_order -fileset sources_1
puts "Project created in $proj_dir"
puts "Golden vectors: $vec_dir ([llength $in_files] inputs, [llength $exp_files] expected outputs)"
