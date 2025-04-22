# Import yosys commands
yosys -import

# PDK setup
set pdk_platform_dir $::env(FLOW_HOME)/platforms/ihp-sg13g2
set pdk_scripts_dir $::env(FLOW_HOME)/scripts
set pdk_stdcell_lib $pdk_platform_dir/lib/sg13g2_stdcell_typ_1p20V_25C.lib
set pdk_dont_use_cells {sg13g2_lgcp_1 sg13g2_sighold sg13g2_slgcp_1 sg13g2_dfrbp_2}
set pdk_latch_map $pdk_platform_dir/cells_latch.v
set pdk_tiehi_cell_port {sg13g2_tiehi L_HI}
set pdk_tielo_cell_port {sg13g2_tielo L_LO}

# Read app sources
read_verilog -defer -sv {*}$::env(SYN_SVERILOG_PATHS)
# Read stdcells
read_liberty -overwrite -setattr liberty_cell -lib $pdk_stdcell_lib

hierarchy -check -top $::env(TOP_MODULE)
# Synthesize, don't flatten
synth -run :fine
# Remove non-synthesizeable stuff
chformal -remove
delete t:\$print
# Optimize
opt -purge
# Technology mapping
techmap
techmap -map $pdk_latch_map
# Map D FFs to stdcell library
set dont_use_args ""
foreach cell $pdk_dont_use_cells {
  lappend dont_use_args -dont_use $cell
}
dfflibmap -liberty $pdk_stdcell_lib {*}$dont_use_args
opt
# ABC optimization
abc -script $pdk_scripts_dir/abc_area.script -liberty $pdk_stdcell_lib {*}$dont_use_args
# Set undefined values to 0
setundef -zero
# Remove unused stuff
opt_clean -purge
# Technology mapping for constant 1/0
hilomap -singleton \
        -hicell {*}$pdk_tiehi_cell_port \
        -locell {*}$pdk_tielo_cell_port
# Write out design
json -o $::env(OBJDIR)/ihp.syn.json
# Reports
tee -o $::env(OBJDIR)/ihp.syn.check check
tee -o $::env(OBJDIR)/ihp.syn.stat stat -liberty $pdk_stdcell_lib
# Check that we mapped everything to std cells
check -assert -mapped