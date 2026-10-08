# Rebuilds the Vivado project from the sources in this repo.
#
# Usage (Vivado Tcl console, or batch):
#   cd <repo>/fpga
#   source scripts/create_project.tcl
#   vivado -mode batch -source scripts/create_project.tcl     (batch)
#
# Creates fpga/vivado/FIR_Filter.xpr (gitignored). Edit sources in fpga/rtl, fpga/tb,
# fpga/constraints; the project only references them, so changes go straight to git.
# After adding or renaming a source file, add it here too so the next rebuild picks it up.

set script_dir [file dirname [file normalize [info script]]]
set fpga_dir   [file normalize [file join $script_dir ..]]
set proj_dir   [file join $fpga_dir vivado]
set vec_dir    [file normalize [file join $fpga_dir .. matlab data vectors]]

create_project -force FIR_Filter $proj_dir -part xc7a35tcpg236-1
# Basys 3 board files are optional; the part above is enough to build.
catch { set_property board_part digilentinc.com:basys3:part0:1.2 [current_project] }
set_property target_language Verilog [current_project]

# Design sources (RTL + the coefficient hex files the ROM reads)
add_files -fileset sources_1 [list \
    [file join $fpga_dir rtl top.v] \
    [file join $fpga_dir rtl spi_slave.v] \
    [file join $fpga_dir rtl coef_rom.v] \
    [file join $vec_dir coef_ch1.hex] \
    [file join $vec_dir coef_ch2.hex] \
    [file join $vec_dir coef_ch3.hex] ]
set_property top top [get_filesets sources_1]

# Vivado doesn't recognize .hex, so mark the coefficient files as data files
foreach ch {1 2 3} {
    set_property file_type {Data Files} [get_files [file join $vec_dir coef_ch$ch.hex]]
}

# Constraints
add_files -fileset constrs_1 [file join $fpga_dir constraints basys3.xdc]

# Simulation set 1: spi_slave
add_files -fileset sim_1 [file join $fpga_dir tb spi_slave_tb.v]
set_property top spi_slave_tb [get_filesets sim_1]
set_property top_lib xil_defaultlib [get_filesets sim_1]

# Simulation set 2: coef_rom (its own set so the tops don't fight)
create_fileset -simset sim_coef_rom
add_files -fileset sim_coef_rom [file join $fpga_dir tb coef_rom_tb.v]
set_property top coef_rom_tb [get_filesets sim_coef_rom]
set_property top_lib xil_defaultlib [get_filesets sim_coef_rom]

# Later: create_fileset -simset sim_fir_core, add tb_fir_core.v plus the in_*/exp_* hex
# files from $vec_dir to that set only (and mark them Data Files the same way).

# Which set "Run Simulation" uses (change this line to switch)
current_fileset -simset [get_filesets sim_coef_rom]

update_compile_order -fileset sources_1
puts "Project created in $proj_dir"
puts "Golden vectors: $vec_dir"
