export TOP_MODULE = neosd
APP_SVERILOG = neosd_cmd_reg.sv \
	neosd_top.sv

export FLOW_HOME=/home/jpfau/Dokumente/orfs/flow

####################################################################################################
# Generated variables
####################################################################################################
export OBJDIR=build
HDLDIR=src/hdl
export SYN_SVERILOG_PATHS=$(addprefix $(HDLDIR)/,$(APP_SVERILOG))
QUIET_FLAG=
ifeq ($(strip $(VERBOSE)),)
	QUIET_FLAG=-q
endif

####################################################################################################
# Rules
####################################################################################################
.PHONY: test

test:
	cd test && make

synth: $(OBJDIR)/gowin.syn.json $(OBJDIR)/ihp.syn.json summary

summary:
	@echo
	@echo ========================== FPGA Summary ==========================
	@echo
	@cat $(OBJDIR)/gowin.syn.stat
	@echo
	@echo ========================== IHP Summary ==========================
	@echo
	@cat $(OBJDIR)/ihp.syn.stat

clean:
	rm -rf $(OBJDIR)

$(OBJDIR)/gowin.syn.json: $(SYN_SVERILOG_PATHS) | $(OBJDIR)
	yosys -p "read_verilog -sv $(SYN_SVERILOG_PATHS); synth_gowin -noflatten -top $(TOP_MODULE) -json $@; tee -o $(OBJDIR)/gowin.syn.stat stat" $(QUIET_FLAG) -l $(OBJDIR)/gowin.syn.log

$(OBJDIR)/ihp.syn.json: $(SYN_SVERILOG_PATHS) | $(OBJDIR)
	yosys syn_ihp.tcl $(QUIET_FLAG) -l $(OBJDIR)/ihp.syn.log

$(OBJDIR):
	mkdir -p $(OBJDIR)