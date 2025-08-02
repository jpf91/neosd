import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles

async def clkstrb(dut):
    await ClockCycles(dut.clk_i, 3)
    dut.clkstrb_i.value = 1
    await ClockCycles(dut.clk_i, 1)
    dut.clkstrb_i.value = 0

async def test_d4_read(dut):
    dut.ctrl_rnw_i.value = 1
    dut.ctrl_d4_i.value = 1
    dut.ctrl_rot_reg.value = 0
    dut.ctrl_omux_i.value = 0
    dut.ctrl_output_crc_i.value = 0
    dut.shift_s_i.value = 0
    dut.load_p_i.value = 0
    dut.clkstrb_i.value = 0

    # Start bit
    dut.sd_dat0_i.value = 0
    dut.sd_dat1_i.value = 0
    dut.sd_dat2_i.value = 0
    dut.sd_dat3_i.value = 0
    await clkstrb(dut)

    # Data Block
    dut.sd_dat0_i.value = 1
    dut.sd_dat1_i.value = 1
    dut.sd_dat2_i.value = 1
    dut.sd_dat3_i.value = 1
    dut.shift_s_i.value = 1
    for i in range(512*8):
        await clkstrb(dut)

    # 0x7FA1 from spec
    crc = [0, 1, 1, 1, 1, 1, 1, 1, 1, 0, 1, 0, 0, 0, 0, 1]
    for i in range(16):
        dut.sd_dat0_i.value = crc[i]
        dut.sd_dat1_i.value = crc[i]
        dut.sd_dat2_i.value = crc[i]
        dut.sd_dat3_i.value = crc[i]
        await clkstrb(dut)
    

    # End Bit
    dut.shift_s_i.value = 0
    await ClockCycles(dut.clk_i, 4)

    # # Now nonzero_o should be 0

async def test_d1_read(dut):
    dut.ctrl_rnw_i.value = 1
    dut.ctrl_d4_i.value = 0
    dut.ctrl_rot_reg.value = 0
    dut.ctrl_omux_i.value = 0
    dut.ctrl_output_crc_i.value = 0
    dut.shift_s_i.value = 0
    dut.load_p_i.value = 0
    dut.clkstrb_i.value = 0

    # Start bit
    dut.sd_dat0_i.value = 0
    # Should be ignored
    dut.sd_dat1_i.value = 0
    dut.sd_dat2_i.value = 0
    dut.sd_dat3_i.value = 0
    await clkstrb(dut)

    # Data Block
    dut.sd_dat0_i.value = 1
    dut.shift_s_i.value = 1
    dut.ctrl_rot_reg.value = 1
    for i in range(512*8):
        await clkstrb(dut)

    # 0x7FA1 from spec
    crc = [0, 1, 1, 1, 1, 1, 1, 1, 1, 0, 1, 0, 0, 0, 0, 1]
    for i in range(16):
        dut.sd_dat0_i.value = crc[i]
        await clkstrb(dut)

    # End Bit
    dut.shift_s_i.value = 0
    dut.ctrl_rot_reg.value = 0
    await ClockCycles(dut.clk_i, 4)

    # # Now nonzero_o should be 0

async def load_data(dut, data):
    dut.data_p_i.value = data
    dut.load_p_i.value = 1
    await clkstrb(dut)
    dut.data_p_i.value = 0
    dut.load_p_i.value = 0

async def test_d4_write(dut):
    dut.ctrl_rnw_i.value = 0
    dut.ctrl_d4_i.value = 1
    dut.ctrl_rot_reg.value = 0
    dut.ctrl_omux_i.value = 1
    dut.ctrl_output_crc_i.value = 0
    dut.shift_s_i.value = 0
    dut.load_p_i.value = 0
    dut.clkstrb_i.value = 0
    dut.sd_dat_oe.value = 0

    # Load data
    await load_data(dut, 0xFFFF8421)

    # Start bit
    dut.sd_dat_oe.value = 1
    dut.ctrl_omux_i.value = 0
    await clkstrb(dut)

    # Data Block
    dut.ctrl_omux_i.value = 2
    dut.shift_s_i.value = 1
    for i in range(512):
        for j in range(8):
            await clkstrb(dut)
        dut.shift_s_i.value = 0
        dut.sd_dat_oe.value = 0
        # Note: Last load here is unnecessary
        await load_data(dut, 0xFFFF8421)
        dut.sd_dat_oe.value = 1
        dut.shift_s_i.value = 1

    # Output CRC
    dut.ctrl_omux_i.value = 3
    dut.ctrl_output_crc_i.value = 1
    for i in range(16):
        await clkstrb(dut)
    dut.ctrl_output_crc_i.value = 0

    #dut.shift_s_i.value = 1

    # Output End bit
    dut.ctrl_omux_i.value = 1
    await clkstrb(dut)
    dut.sd_dat_oe.value = 0

    # Read the CRC result block
    # 2 Cycles of Z
    dut.sd_dat0_i.value = 1
    dut.sd_dat1_i.value = 1
    dut.sd_dat2_i.value = 1
    dut.sd_dat3_i.value = 1
    for i in range(2):
        await clkstrb(dut)
    # Start Bit
    dut.sd_dat0_i.value = 0
    dut.sd_dat1_i.value = 0
    dut.sd_dat2_i.value = 0
    dut.sd_dat3_i.value = 0
    await clkstrb(dut)

    # 3 Status bits + 1 End bit
    dut.sd_dat0_i.value = 1
    dut.sd_dat1_i.value = 1
    dut.sd_dat2_i.value = 1
    dut.sd_dat3_i.value = 1
    for i in range(4):
        await clkstrb(dut)

    # Can now read CRCs from data_p_o (need to respect mapping though...)

    await ClockCycles(dut.clk_i, 16)

async def test_d1_write(dut):
    dut.ctrl_rnw_i.value = 0
    dut.ctrl_d4_i.value = 0
    dut.ctrl_rot_reg.value = 0
    dut.ctrl_omux_i.value = 1
    dut.ctrl_output_crc_i.value = 0
    dut.shift_s_i.value = 0
    dut.load_p_i.value = 0
    dut.clkstrb_i.value = 0
    dut.sd_dat_oe.value = 0

    # Load data
    await load_data(dut, 0xFFFF8421)

    # Start bit
    dut.sd_dat_oe.value = 1
    dut.ctrl_omux_i.value = 0
    await clkstrb(dut)

    # Data Block
    dut.ctrl_omux_i.value = 2
    dut.shift_s_i.value = 1
    dut.ctrl_rot_reg.value = 1
    for i in range(128):
        for j in range(32):
            await clkstrb(dut)
        dut.shift_s_i.value = 0
        dut.sd_dat_oe.value = 0
        # Note: Last load here is unnecessary
        await load_data(dut, 0xFFFF8421)
        dut.sd_dat_oe.value = 1
        dut.shift_s_i.value = 1

    # Output CRC
    dut.ctrl_rot_reg.value = 0
    dut.ctrl_omux_i.value = 3
    dut.ctrl_output_crc_i.value = 1
    for i in range(16):
        await clkstrb(dut)
    dut.ctrl_output_crc_i.value = 0

    dut.shift_s_i.value = 1

    # Output End bit
    dut.ctrl_omux_i.value = 1
    await clkstrb(dut)
    dut.sd_dat_oe.value = 0

    # Read the CRC result block
    # 2 Cycles of Z
    dut.sd_dat0_i.value = 1
    for i in range(2):
        await clkstrb(dut)
    # Start Bit
    dut.sd_dat0_i.value = 0
    await clkstrb(dut)

    # 3 Status bits + 1 End bit
    dut.sd_dat0_i.value = 1
    for i in range(4):
        await clkstrb(dut)

    # Can now read CRC from data_p_o (need to respect mapping though...)

    await ClockCycles(dut.clk_i, 16)

@cocotb.test()
async def test_project(dut):
    dut._log.info("Start")

    # Set the clock to 100 MHz
    clock = Clock(dut.clk_i, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Reset
    dut._log.info("Reset")
    dut.rstn_i.value = 0
    await ClockCycles(dut.clk_i, 3)
    dut.rstn_i.value = 1

    #await test_d4_read(dut)
    await test_d1_read(dut)
    #await test_d4_write(dut)
    #await test_d1_write(dut)
