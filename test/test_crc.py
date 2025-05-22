import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles

@cocotb.test()
async def test_project(dut):
    dut._log.info("Start")

    # Set the clock to 100 MHz
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Reset
    dut._log.info("Reset")
    dut.rstn.value = 0
    await ClockCycles(dut.clk, 3)
    dut.rstn.value = 1


    # Generate CRC. Data = 0xFF
    dut.data_s_i.value = 1
    dut.shift_s.value = 1
    dut.output_s.value = 0
    for i in range(512*8):
        dut.clkstrb.value = 1
        await ClockCycles(dut.clk, 1)
        dut.clkstrb.value = 0
        await ClockCycles(dut.clk, 3)

    dut.output_s.value = 1
    for i in range(16):
        dut.clkstrb.value = 1
        await ClockCycles(dut.clk, 1)
        dut.clkstrb.value = 0
        await ClockCycles(dut.clk, 3)

    # Reset
    dut.output_s.value = 0
    dut._log.info("Reset")
    dut.rstn.value = 0
    await ClockCycles(dut.clk, 3)
    dut.rstn.value = 1

    # Validate CRC. Should be 0 at end
    dut.data_s_i.value = 1
    dut.shift_s.value = 1
    for i in range(512*8):
        dut.clkstrb.value = 1
        await ClockCycles(dut.clk, 1)
        dut.clkstrb.value = 0
        await ClockCycles(dut.clk, 3)

    # 0x7FA1 from spec
    crc = [0, 1, 1, 1, 1, 1, 1, 1, 1, 0, 1, 0, 0, 0, 0, 1]
    for i in range(16):
        dut.data_s_i.value = crc[i]
        dut.clkstrb.value = 1
        await ClockCycles(dut.clk, 1)
        dut.clkstrb.value = 0
        await ClockCycles(dut.clk, 3)
    
    # # Now nonzero_o should be 0