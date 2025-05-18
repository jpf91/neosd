#include "neosd.h"
#include "neorv32.h"

#ifdef __cplusplus
extern "C" {
#endif

static uint64_t neosd_clint_time_get_ms()
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
            neosd_begin_reset();
            neosd_wait_idle();
            return false;
        }

        auto irq = NEOSD->IRQ_FLAG;
        if (irq & (1 << NEOSD_IRQ_CMD_RESP))
            *(rptr--) = NEOSD->RESP;
        if (irq & (1 << NEOSD_IRQ_CMD_DONE))
        {
            NEOSD->IRQ_FLAG &= ~(1 << NEOSD_IRQ_CMD_DONE);
            break;
        }
    }

    return true;
}

#ifdef __cplusplus
}
#endif