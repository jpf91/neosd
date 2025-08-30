# Makefile
# See https://docs.cocotb.org/en/stable/quickstart.html for more info

# defaults
SIM ?= icarus
TOPLEVEL_LANG ?= verilog
SRC_DIR = $(PWD)/../rtl
PROJECT_SOURCES = \
    neosd_clken.v \
    neosd_cmd_reg.sv \
	neosd_cmd_fsm.sv \
	neosd_clk.sv \
	neosd_dat_crc.sv \
	neosd_dat_reg.sv \
	neosd_dat_block.sv \
	neosd_dat_fsm.sv \
	neosd_top.sv \

# RTL simulation:
SIM_BUILD = sim_build/rtl
VERILOG_SOURCES += $(addprefix $(SRC_DIR)/,$(PROJECT_SOURCES))

# Allow sharing configuration between design and testbench via `include`:
COMPILE_ARGS 		+= -I$(SRC_DIR)

# Include the testbench sources:
VERILOG_SOURCES += $(PWD)/tb.v
VERILOG_SOURCES += $(PWD)/tb_crc.v
VERILOG_SOURCES += $(PWD)/tb_dat_block.v
TOPLEVEL = tb

# MODULE is the basename of the Python test file
MODULE = test

# include cocotb's make rules to take care of the simulator setup
include $(shell cocotb-config --makefiles)/Makefile.sim
