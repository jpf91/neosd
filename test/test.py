import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, RisingEdge, FallingEdge

from cocotbext.wishbone.driver import WishboneMaster
from cocotbext.wishbone.driver import WBOp

async def test_old(dut):
    # CMDArg 0x10, IDX=0b101010 CRC=1110011 COMMIT, SHORT Response
    # await wbs.send_cycle([WBOp(0x10, 42), WBOp(0x14, 0b00101010_01110011_00_01_00_0_1)])

    # await ClockCycles(dut.clk, 64*8)
    # dut.sd_cmd_i.value = 0
    # await ClockCycles(dut.clk, 16*8)
    # # Read flag reg, then read rdata reg
    # await wbs.send_cycle([WBOp(0x8), WBOp(0x18)])

    # # FIXME: Implement a proper SD card driver
    # await ClockCycles(dut.clk, 33*8)
    # dut.sd_cmd_i.value = 1
    # # Read flag reg, then read rdata reg
    # await wbs.send_cycle([WBOp(0x8), WBOp(0x18)])



    # CMDArg 0x10, IDX=0b110101 COMMIT, LONG Response
    # await wbs.send_cycle([WBOp(0x10, 42), WBOp(0x14, 0b1101010000000100001)])

    # await ClockCycles(dut.clk, 64*8)
    # dut.sd_cmd_i.value = 0
    # await ClockCycles(dut.clk, 136*8)
    # dut.sd_cmd_i.value = 1



    # # CMDArg 0x10, IDX=0b110101 COMMIT, NO Response
    # await wbs.send_cycle([WBOp(0x10, 42), WBOp(0x14, 0b00101010_01110011_00_00_00_0_1)])
    # await ClockCycles(dut.clk, 64*8)

    # # Clear done flag
    # await wbs.send_cycle([WBOp(0x8, 0b0)])

    # CMDArg 0x10, IDX=0b101010 CRC=1110011 SHORT Response, READ BLOCK, LAST BLOCK, COMMIT
    await wbs.send_cycle([WBOp(0x10, 42), WBOp(0x14, 0b00101010_01110011_00_01_10_1_1)])
    await ClockCycles(dut.clk, 64*8)

    # Read full response
    dut.sd_cmd_i.value = 0
    await ClockCycles(dut.clk, 16*8)
    # Read flag reg, then read rdata reg
    await wbs.send_cycle([WBOp(0x8), WBOp(0x18)])

    await ClockCycles(dut.clk, 34*8)
    # Read flag reg, then read rdata reg
    await wbs.send_cycle([WBOp(0x8), WBOp(0x18)])


    # Now we should start reading the data
    dut.sd_dat0_i.value = 0
    await ClockCycles(dut.clk, 36*8)
    # Read flag reg, then read data reg
    await wbs.send_cycle([WBOp(0x8), WBOp(0x1C)])


    # Clear rdone flag
    #await wbs.send_cycle([WBOp(0x8, 0b0)])



    await ClockCycles(dut.clk, 100 * 8)

async def test_read_block(dut, wbs):
    # Now we should start reading the data
    await FallingEdge(dut.sd_clk_o)
    dut.sd_dat0_i.value = 0
    dut.sd_dat1_i.value = 0
    dut.sd_dat2_i.value = 0
    dut.sd_dat3_i.value = 0

    # 512*8bit
    for word in range(128):
        # Transfer 32 bit of data
        await FallingEdge(dut.sd_clk_o)
        dut.sd_dat0_i.value = 1
        dut.sd_dat1_i.value = 1
        dut.sd_dat2_i.value = 1
        dut.sd_dat3_i.value = 1
        await ClockCycles(dut.sd_clk_o, 7)
        await ClockCycles(dut.clk, 8)
        # Read flags and data
        await wbs.send_cycle([WBOp(0x8), WBOp(0x1C)])

    # Output CRC: 0x7FA1 from spec
    crc = [0, 1, 1, 1, 1, 1, 1, 1, 1, 0, 1, 0, 0, 0, 0, 1]
    for i in range(16):
        await RisingEdge(dut.sd_clk_o)
        dut.sd_dat0_i.value = crc[i]
        dut.sd_dat1_i.value = crc[i]
        dut.sd_dat2_i.value = crc[i]
        dut.sd_dat3_i.value = crc[i]
    

#@cocotb.test()
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

    dut.sd_dat0_i.value = 1

    # Reset
    dut._log.info("Reset")
    dut.rstn.value = 0
    await ClockCycles(dut.clk, 3)
    dut.rstn.value = 1

    # CDIV = 4, D4MODE
    await wbs.send_cycle([WBOp(0x0, 0b000010), WBOp(0x0, 0b0000000), WBOp(0x0, 0b1_001_0_0_1), WBOp(0x0)])
    await ClockCycles(dut.clk, 3)


    # CMDArg 0x10, IDX=0b101010 CRC=1110011 SHORT Response, READ BLOCK, LAST BLOCK, COMMIT
    await wbs.send_cycle([WBOp(0x10, 42), WBOp(0x14, 0b00101010_01110011_00_01_10_0_1)])
    await ClockCycles(dut.clk, 64*8)

    # Read full response
    dut.sd_cmd_i.value = 0
    await ClockCycles(dut.clk, 16*8)
    # Read flag reg, then read rdata reg
    await wbs.send_cycle([WBOp(0x8), WBOp(0x18)])

    await ClockCycles(dut.clk, 34*8)
    # Read flag reg, then read rdata reg
    await wbs.send_cycle([WBOp(0x8), WBOp(0x18)])

    await test_read_block(dut, wbs)
    await test_read_block(dut, wbs)

    # Now issue the stop signal: In theory, would wait for BLOCK_DONE IRQ
    await ClockCycles(dut.clk, 8*8)
    # CMDArg 0x10, IDX=0b101010 CRC=1110011 SHORT Response, No Data, LAST BLOCK, COMMIT
    await wbs.send_cycle([WBOp(0x10, 42), WBOp(0x14, 0b00101010_01110011_00_01_00_1_1)])

    # Simulate data still being transferred for some cycles
    await RisingEdge(dut.sd_clk_o)
    dut.sd_dat0_i.value = 0
    dut.sd_dat1_i.value = 0
    dut.sd_dat2_i.value = 0
    dut.sd_dat3_i.value = 0
    await RisingEdge(dut.sd_clk_o)
    dut.sd_dat0_i.value = 1
    dut.sd_dat1_i.value = 1
    dut.sd_dat2_i.value = 1
    dut.sd_dat3_i.value = 1

    # Read full response
    dut.sd_cmd_i.value = 0
    await ClockCycles(dut.clk, 64*8)
    # Read flag reg, then read rdata reg
    await wbs.send_cycle([WBOp(0x8), WBOp(0x18)])

    await ClockCycles(dut.clk, 32*8)
    # Read flag reg, then read rdata reg
    await wbs.send_cycle([WBOp(0x8), WBOp(0x18)])

    await ClockCycles(dut.clk, 64*16)
    # Read flag reg, then read data reg
    #await wbs.send_cycle([WBOp(0x8), WBOp(0x1C)])


async def init_test(dut):
    dut._log.info("Start")

    # Set the clock to 100 MHz
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

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

    dut.sd_cmd_i.value = 1
    dut.sd_dat0_i.value = 1
    dut.sd_dat1_i.value = 1
    dut.sd_dat2_i.value = 1
    dut.sd_dat3_i.value = 1

    # Reset
    dut._log.info("Reset")
    dut.rstn.value = 0
    await ClockCycles(dut.clk, 3)
    dut.rstn.value = 1

    return wbs

async def configure_peripheral(dut, wbs, idleClk, d4Mode = True):
    # CDIV = 4, D4MODE
    # RST
    cfg = (0b0 << 0)
    if (idleClk):
        cfg = cfg | 0b1000
    if (d4Mode):
        cfg = cfg | 0b10
    # prsc
    cfg = cfg | (0b001 << 4)
    # hs
    cfg = cfg | (0b1 << 7)
    # cdiv
    cfg = cfg | (0b0000 << 8)


    await wbs.send_cycle([WBOp(0x4, cfg)])
    await ClockCycles(dut.clk, 3)

async def test_fsm_rst_impl(dut, idleClk):
    wbs = await init_test(dut)
    await configure_peripheral(dut, wbs, idleClk)

    # CMDArg 0x10, IDX=0b101010 CRC=1110011 SHORT Response, READ BLOCK, LAST BLOCK, COMMIT
    await wbs.send_cycle([WBOp(0x10, 42), WBOp(0x14, 0b00101010_01110011_00_01_10_0_1)])
    await ClockCycles(dut.clk, 64*8)

    # FSM should report busy
    await wbs.send_cycle([WBOp(0x4)])

    # Send reset request
    result = await wbs.send_cycle([WBOp(0x0)])
    cfg = result[0].datrd | 0b10
    await wbs.send_cycle([WBOp(0x0, cfg)])

    # Should go to idle
    isIdle = False
    for i in range(20):
        result = await wbs.send_cycle([WBOp(0x4)])
        if (result[0].datrd & 0b11 == 0b00):
            isIdle = True
            break

    # Release reset
    assert(isIdle)
    result = await wbs.send_cycle([WBOp(0x0)])
    cfg = result[0].datrd & ~0b10
    await wbs.send_cycle([WBOp(0x0, cfg)])

    # Wait some time in idle and check that SD clock is toggling
    await ClockCycles(dut.clk, 8*8)

@cocotb.test()
async def test_fsm_rst(dut):
    await test_fsm_rst_impl(dut, False)

@cocotb.test()
async def test_fsm_rst_idleclk(dut):
    await test_fsm_rst_impl(dut, True)

@cocotb.test()
async def test_busy_response(dut):
    wbs = await init_test(dut)
    await configure_peripheral(dut, wbs, False)

    # CMDArg 0x10, IDX=0b101010 CRC=1110011 SHORT Response, DATA BUSY, COMMIT
    await wbs.send_cycle([WBOp(0x10, 42), WBOp(0x14, 0b00101010_01110011_00_01_01_0_1)])
    await ClockCycles(dut.clk, 64*8)

    # Emulate busy going high
    dut.sd_dat0_i.value = 0

    # Read the response
    dut.sd_cmd_i.value = 0
    await ClockCycles(dut.clk, 16*8)
    # Read flag reg, then read rdata reg
    await wbs.send_cycle([WBOp(0x8), WBOp(0x18)])

    await ClockCycles(dut.clk, 34*8)
    # Read flag reg, then read rdata reg
    await wbs.send_cycle([WBOp(0x8), WBOp(0x18)])

    dut.sd_cmd_i.value = 1
    await ClockCycles(dut.sd_clk_o, 8)

    # Data FSM should be busy
    result = await wbs.send_cycle([WBOp(0x4)])
    assert((result[0].datrd & 0b10) != 0)

    # Emulate busy going low
    dut.sd_dat0_i.value = 1
    await ClockCycles(dut.clk, 8*8)

    # Should be in idle state again
    result = await wbs.send_cycle([WBOp(0x4)])
    assert((result[0].datrd & 0b11) == 0)


async def write_block_data(dut, wbs, d4Mode):
    # Write data
    for i in range(128):
        await wbs.send_cycle([WBOp(0x1C, 0xFFFFFFFF)])
        if (d4Mode):
            await ClockCycles(dut.clk, 12*8)
        else:
            await ClockCycles(dut.clk, 4*12*8)
        #result = await wbs.send_cycle([WBOp(0x8)])
        #assert((result[0].datrd & 0b1000) != 0)

    # Wrote 512 byte. driver now writes CRC on it's own
    await FallingEdge(dut.sd_dat0_oe)

    # Here we start sampling again
    # The start bit needs to come 2 cycles after the data block end bit
    await FallingEdge(dut.sd_clk_o)
    await FallingEdge(dut.sd_clk_o)

    # Start bit

    dut.sd_dat0_i.value = 0
    dut.sd_dat1_i.value = 1
    dut.sd_dat2_i.value = 1
    dut.sd_dat3_i.value = 1

    await FallingEdge(dut.sd_clk_o)
    dut.sd_dat0_i.value = 0

    await FallingEdge(dut.sd_clk_o)
    dut.sd_dat0_i.value = 1

    await FallingEdge(dut.sd_clk_o)
    dut.sd_dat0_i.value = 0

    # End bit
    await FallingEdge(dut.sd_clk_o)
    dut.sd_dat0_i.value = 1

    # Busy marker
    await FallingEdge(dut.sd_clk_o)
    dut.sd_dat0_i.value = 0

    await FallingEdge(dut.sd_clk_o)
    dut.sd_dat0_i.value = 1

    await ClockCycles(dut.clk, 10*8)

async def test_write_block(dut, d4Mode):
    wbs = await init_test(dut)
    await configure_peripheral(dut, wbs, False, d4Mode)

    # CMDArg 0x10, IDX=0b101010 CRC=1110011 SHORT Response, DATA WRITE, COMMIT
    await wbs.send_cycle([WBOp(0x10, 42), WBOp(0x14, 0b00101010_01110011_00_01_11_0_1)])
    await ClockCycles(dut.clk, 64*8)

    # Read the response
    dut.sd_cmd_i.value = 0
    await ClockCycles(dut.clk, 16*8)
    # Read flag reg, then read rdata reg
    await wbs.send_cycle([WBOp(0x8), WBOp(0x18)])

    await ClockCycles(dut.clk, 34*8)
    # Read flag reg, then read rdata reg
    await wbs.send_cycle([WBOp(0x8), WBOp(0x18)])
    dut.sd_cmd_i.value = 1
    # SD Clock is stalled here
    await ClockCycles(dut.clk, 8*8)

    # Flags should have data interrupt
    result = await wbs.send_cycle([WBOp(0x8)])
    assert((result[0].datrd & 0b1000) != 0)

    await write_block_data(dut, wbs, d4Mode)

    # Flags should have data interrupt
    result = await wbs.send_cycle([WBOp(0x8)])
    assert((result[0].datrd & 0b1000) != 0)

    await write_block_data(dut, wbs, d4Mode)

    # Send stop CMD
    # CMDArg 0x10, IDX=0b101010 CRC=1110011 SHORT Response, No Data, LAST BLOCK, COMMIT
    await wbs.send_cycle([WBOp(0x10, 42), WBOp(0x14, 0b00101010_01110011_00_01_00_1_1)])

    # Read full response
    dut.sd_cmd_i.value = 0
    await ClockCycles(dut.clk, 64*8)
    # Read flag reg, then read rdata reg
    await wbs.send_cycle([WBOp(0x8), WBOp(0x18)])

    await ClockCycles(dut.clk, 40*8)
    # Read flag reg, then read rdata reg
    await wbs.send_cycle([WBOp(0x8), WBOp(0x18)])

    await ClockCycles(dut.clk, 64*16)

@cocotb.test()
async def test_write_block_d1(dut):
    await test_write_block(dut, False)

@cocotb.test()
async def test_write_block_d4(dut):
    await test_write_block(dut, True)

@cocotb.test()
async def test_basic(dut):
    wbs = await init_test(dut)
    await configure_peripheral(dut, wbs, False, False)

    # CMDArg 0x10, IDX=0b101010 CRC=1110011 SHORT Response, DATA WRITE, COMMIT
    cmd = 0
    # Commit
    cmd = cmd | 0b1
    # DMODE
    cmd = cmd | (0b0 << 4)
    # RMODE: short
    cmd = cmd | (1 << 6)
    # CRC
    cmd = cmd | (0b1110011 << 16)
    # IDX
    cmd = cmd | (0b101010 << 24)

    await wbs.send_cycle([WBOp(0x8, 42), WBOp(0xC, cmd)])
    await ClockCycles(dut.clk, 64*8)

    # Read the response
    dut.sd_cmd_i.value = 0
    await ClockCycles(dut.clk, 17*8)
    # Read flag reg, then read rdata reg
    await wbs.send_cycle([WBOp(0x4), WBOp(0x14)])

    await ClockCycles(dut.clk, 64*8)
    await wbs.send_cycle([WBOp(0x4), WBOp(0x14)])

    await ClockCycles(dut.clk, 64*8)
    await wbs.send_cycle([WBOp(0x4), WBOp(0x14)])

@cocotb.test()
async def test_idle(dut):
    wbs = await init_test(dut)
    await configure_peripheral(dut, wbs, True, False)

    await ClockCycles(dut.clk, 64*8)