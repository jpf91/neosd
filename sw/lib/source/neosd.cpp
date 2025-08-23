#include "neosd.h"

#ifdef __cplusplus
extern "C" {
#endif

//FIXME: constexpr

/*
 * Matching https://www.ghsi.de/pages/subpages/Online%20CRC%20Calculation/indexDetails.php?Polynom=10001001
 * Note: Processes data Most-significant-Byte first to match SD protocol
 */
#define CRC7_POLY 0x89

/**********************************************************************//**
 * Get CRC7 according to SD standard.
 *
 * @note This implementation processes data from the most-significant byte
 * (data[length -1]) first.
 **************************************************************************/
uint8_t neosd_crc7(const uint8_t* data, size_t length)
{
    uint8_t crc = 0;
    for (size_t i = 0; i < length; i++)
    {
        crc ^= data[length - 1 - i];
        for (int j = 0; j < 8; j++)
        {
            if (crc & 0x80)
                crc = (crc << 1) ^ (CRC7_POLY << 1);
            else
                crc <<= 1;
        }
    }

    return crc >> 1;
}

/**********************************************************************//**
 * Get CRC7 for a command with index cmd_idx and data cmd_arg.
 **************************************************************************/
uint8_t neosd_cmd_crc(uint8_t cmd_idx, uint32_t cmd_arg)
{
    uint8_t data[5] = {0};
    data[4] = 0b01000000 | cmd_idx;
    data[3] = (cmd_arg >> 24) & 0xFF;
    data[2] = (cmd_arg >> 16) & 0xFF;
    data[1] = (cmd_arg >> 8) & 0xFF;
    data[0] = (cmd_arg >> 0) & 0xFF;
    return neosd_crc7(&data[0], 5);
}

/**********************************************************************//**
* Get CRC7 for a short response.
*
* @note According to SD specification, neosd_r3_t does not have a crc.
**************************************************************************/
uint8_t neosd_rshort_crc(neosd_rshort_t* data)
{
    // data[0] is the crc itself
    return neosd_crc7((uint8_t*)data + 1, 5);
}

/**********************************************************************//**
* Validate CRC7 for a short response.
*
* @note According to SD specification, neosd_r3_t does not have a crc.
**************************************************************************/
bool neosd_rshort_check(neosd_rshort_t* data)
{
    return neosd_rshort_crc(data) == data->crc;
}

uint8_t neosd_rlong_crc(neosd_r2_t* data)
{
    return neosd_crc7((uint8_t*)data + 1, 15);
}

bool neosd_rlong_check(neosd_r2_t* data)
{
    return neosd_rlong_crc(data) == (data->reg0 & 0x7F);
}

/**********************************************************************//**
 * Initial setup for the SD module.
 **************************************************************************/
void neosd_setup(int prsc, int cdiv, uint32_t irq_mask)
{
    // Instead of neosd_reset, clear the register fully
    NEOSD->CTRL = (1 << NEOSD_CTRL_RST);

    // setup prsc and enable
    NEOSD->CTRL = (prsc << NEOSD_CTRL_CDIV0) | (1 << NEOSD_CTRL_EN);
}

/**********************************************************************//**
 * Get configured clock speed in Hz.
 *
 * @return Actual configured SD clock speed in Hz.
 **************************************************************************/
uint32_t neosd_get_clock_speed(void)
{
    return 0;

// FIXME: Implement PRSRC ad CDIV in HW
#if 0
    const uint16_t PRSC_LUT[8] = {2, 4, 8, 64, 128, 1024, 2048, 4096};

    uint32_t ctrl = NEORV32_SPI->CTRL;
    uint32_t prsc_sel  = (ctrl >> SPI_CTRL_PRSC0) & 0x7;
    uint32_t clock_div = (ctrl >> SPI_CTRL_CDIV0) & 0xf;
  
    uint32_t tmp = 2 * PRSC_LUT[prsc_sel] * (1 + clock_div);
  
    return neorv32_sysinfo_get_clk() / tmp;
#endif
}

/**********************************************************************//**
 * Set configured clock speed dividers.
 *
 * @note Ensure the SD FSMs are idle by checking neosd_busy() before
 * calling this.
 **************************************************************************/
void neosd_set_clock_div(int prsc, int cdiv)
{
    // FIXME: CDIV
    uint32_t ctrl = NEOSD->CTRL;
    ctrl &= ~(0b1111 << NEOSD_CTRL_CDIV0);
    ctrl |= (prsc << NEOSD_CTRL_CDIV0);
    NEOSD->CTRL = ctrl;
}

/**********************************************************************//**
 * Disable the neosd controller.
 **************************************************************************/
void neosd_disable()
{
    NEOSD->CTRL &= ~(1 << NEOSD_CTRL_EN);
}

/**********************************************************************//**
 * Enable the neosd controller.
 **************************************************************************/
void neosd_enable()
{
    NEOSD->CTRL |= (1 << NEOSD_CTRL_EN);
}

/**********************************************************************//**
 * Whether to keep clock active in idle state.
 **************************************************************************/
void neosd_set_idle_clk(bool active)
{
    if (active)
        NEOSD->CTRL |= (1 << NEOSD_CTRL_IDLE_CLK);
    else
        NEOSD->CTRL &= ~(1 << NEOSD_CTRL_IDLE_CLK);
}

/**********************************************************************//**
 * Reset the neosd controller.
 *
 * @note This does not change / reset any register configuration!
 * @note You may want to wait on neosd_busy() to check when reset is done.
 **************************************************************************/
void neosd_begin_reset()
{
    NEOSD->CTRL |= (1 << NEOSD_CTRL_RST);
}

/**********************************************************************//**
 * Reset the neosd controller.
 *
 * @note This does not change / reset any register configuration!
 * @note You may want to wait on neosd_busy() to check when reset is done.
 **************************************************************************/
void neosd_end_reset()
{
    NEOSD->CTRL &= ~(1 << NEOSD_CTRL_RST);
}

/**********************************************************************//**
 * Check if the controller is currently active.
 *
 * In the simple cases, you should not start a new command as long as this
 * function returns a value other than 0. The controller however does
 * support sending "dataless" commands during a data transfer. So if this
 * returns 2 (transmitting data, but no cmd), then you can commit a new
 * command that must however not use the data line.
 *
 * @returns 0 if inactive, 1 if transmitting cmd, 2 if transmitting data
 * 3 if both.
 **************************************************************************/
int neosd_busy()
{
    return NEOSD->STAT & ((1 << NEOSD_STAT_IDLE_CMD) | (1 << NEOSD_STAT_IDLE_DAT));
}

/**********************************************************************//**
 * Commit a new command to SD controller.
 **************************************************************************/
void neosd_cmd_commit(SD_CMD_IDX cmd, uint32_t arg, NEOSD_RMODE rmode, NEOSD_DMODE dmode, bool stopDAT)
{
    uint32_t stopBit = stopDAT ? (1 << NEOSD_CMD_LAST_BLOCK) : 0;
    NEOSD->CMDARG = arg;
    NEOSD->CMD = (1 << NEOSD_CMD_COMMIT) | (dmode << NEOSD_CMD_DMODE0) |
        (rmode << NEOSD_CMD_RMODE0) | (cmd << NEOSD_CMD_IDX_LSB) |
        stopBit |
        (neosd_cmd_crc(cmd, arg) << NEOSD_CMD_CRC_LSB);
}

#ifdef __cplusplus
}
#endif