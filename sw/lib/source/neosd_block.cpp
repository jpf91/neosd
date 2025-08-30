#include "neosd.h"
#include "neosd_dbg.h"
#include "neorv32.h"

#ifdef __cplusplus
extern "C" {
#endif

uint64_t neosd_clint_time_get_ms()
{
    return neorv32_clint_time_get() / (((uint64_t)neorv32_sysinfo_get_clk() / 1000));
}

/**********************************************************************//**
 * Blocking wait for FSMs to return to idle state.
 *
 * @note Use this after neosd_begin_reset to wait until reset is finished.
 **************************************************************************/
void neosd_wait_idle()
{
    while(neosd_busy() != 0) {}
}

/**********************************************************************//**
 * Reset and wait for FSMs to return to idle state.
 *
 * @note Use this after neosd_begin_reset to wait until reset is finished.
 **************************************************************************/
void neosd_reset()
{
    neosd_begin_reset();
    while(neosd_busy()) {}
    // Clear data irq flags
    NEOSD->RESP;
    NEOSD->DATA;
    // Clear IRQ flags and CRC sticky bit
    NEOSD->CTRL &= ~((1 << NEOSD_CTRL_FLAG_CMD_DONE) | (1 << NEOSD_CTRL_FLAG_DAT_DONE) | (1 << NEOSD_CTRL_FLAG_BLK_DONE) | (1 << NEOSD_CTRL_CRCERR));
    neosd_end_reset();
}

/**********************************************************************//**
 * Blocking wait for CMD to finish.
 *
 * @returns false if timeout occured, true if successful.
 **************************************************************************/
bool neosd_cmd_wait_res(neosd_res_t* res, uint32_t rtimeout)
{
    uint64_t timeout = neosd_clint_time_get_ms() + rtimeout;

    uint32_t* rptr = &res->_raw[4];
    while (true)
    {
        if (neosd_clint_time_get_ms() > timeout)
        {
            neosd_reset();
            return false;
        }

        auto irq = NEOSD->CTRL;
        if (irq & (1 << NEOSD_CTRL_FLAG_CMD_RESP))
            *(rptr--) = NEOSD->RESP;
        if (irq & (1 << NEOSD_CTRL_FLAG_CMD_DONE))
        {
            NEOSD->CTRL &= ~(1 << NEOSD_CTRL_FLAG_CMD_DONE);
            break;
        }
    }

    return true;
}

SD_CODE neosd_acmd_commit(SD_CMD_IDX acmd, uint32_t arg, NEOSD_RMODE rmode,
    NEOSD_DMODE dmode, sd_status_t* status, size_t rca, uint32_t rtimeout)
{
    // 4.3.9.1 Application-Specific Command – APP_CMD (CMD55)

    neosd_cmd_commit(SD_CMD55, rca << 16, NEOSD_RMODE_SHORT, NEOSD_DMODE_NONE);
    NEOSD_DEBUG_MSG("NEOSD: Sent CMD55\n");

    neosd_res_t resp;
    if (!neosd_cmd_wait_res(&resp, rtimeout))
    {
        NEOSD_DEBUG_MSG("NEOSD: No response\n");
        return NEOSD_TIMEOUT;
    }
    NEOSD_DEBUG_R1(&resp.rshort);

    if (!neosd_rshort_check(&resp.rshort))
    {
        NEOSD_DEBUG_MSG("NEOSD: CRC invalid.\n");
        return NEOSD_CRC_ERR;
    }

    // Could look at card status APP_CMD flag, but don't think it's needed 
    status->_raw = resp.rshort.r1.status;
    neosd_cmd_commit(acmd, arg, rmode, dmode);
    return NEOSD_OK;
}

#ifdef __cplusplus
}
#endif