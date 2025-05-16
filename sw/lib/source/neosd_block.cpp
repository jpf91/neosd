#include "neosd.h"

#ifdef __cplusplus
extern "C" {
#endif

/**********************************************************************//**
 * Blocking wait for CMD to finish.
 *
 * @returns false if timeout occured, true if successful.
 **************************************************************************/
bool neosd_cmd_wait_res(neosd_res_t* res)
{
    // FIXME: Timeout support
    uint32_t* rptr = &res->_raw[4];
    while (true)
    {
      auto irq = NEOSD->IRQ_FLAG;
      if (irq & (1 << NEOSD_IRQ_CMD_RESP))
        *(rptr--) = NEOSD->RESP;
      if (irq & (1 << NEOSD_IRQ_CMD_DONE))
      {
        NEOSD->IRQ_FLAG &= ~(1 << NEOSD_IRQ_CMD_DONE);
        break;
      }
    }

    return 0;
}

#ifdef __cplusplus
}
#endif