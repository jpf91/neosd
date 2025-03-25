import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles

from cocotbext.wishbone.driver import WishboneMaster
from cocotbext.wishbone.driver import WBOp

@cocotb.test()
async def test_project(dut):
    dut._log.info("Start")

    # Set the clock to 100 MHz
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # FIXME: reg[3:0] wb_sel_i, wirewb_err_o
    wbs = WishboneMaster(dut, "", dut.clk,
        width=32,
        timeout=10,
        signals_dict={"cyc":  "wb_cyc_i",
                    "stb":  "wb_stb_i",
                    "we":   "wb_we_i",
                    "adr":  "wb_adr_i",
                    "datwr":"wb_dat_i",
                    "datrd":"wb_dat_o",
                    "ack":  "wb_ack_o" })

    # Reset
    dut._log.info("Reset")
    dut.rstn.value = 0
    await ClockCycles(dut.clk, 3)
    dut.rstn.value = 1

    await wbs.send_cycle([WBOp(0x0, 0b000010), WBOp(0x0, 0b000000), WBOp(0x0, 0b000001), WBOp(0x0)])
    await ClockCycles(dut.clk, 3)

    # CMDArg 0x10, IDX=0b110101 COMMIT
    await wbs.send_cycle([WBOp(0x10, 42), WBOp(0x14, 0b1101010000000000001)])
    await ClockCycles(dut.clk, 100)