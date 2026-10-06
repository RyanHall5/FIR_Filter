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

# Design sources
add_files -fileset sources_1 [list \
    [file join $fpga_dir rtl top.v] \
    [file join $fpga_dir rtl spi_slave.v] ]
set_property top top [get_filesets sources_1]

# Constraints
add_files -fileset constrs_1 [file join $fpga_dir constraints basys3.xdc]

# Simulation sources
add_files -fileset sim_1 [file join $fpga_dir tb spi_slave_tb.v]
set_property top spi_slave_tb [get_filesets sim_1]
set_property top_lib xil_defaultlib [get_filesets sim_1]

# Golden-model vectors live in ../matlab/data/vectors (path from fpga/: ../matlab/data/vectors).
# Testbenches that use $readmemh should reference that location.

update_compile_order -fileset sources_1
puts "Project created in $proj_dir"
puts "Golden vectors: $vec_dir"
