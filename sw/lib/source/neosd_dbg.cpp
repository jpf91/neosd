#include "neosd.h"
#include <neorv32.h>

#ifdef __cplusplus
extern "C" {
#endif

/**********************************************************************//**
 * Blocking wait for CMD to finish.
 *
 * @returns false if timeout occured, true if successful.
 **************************************************************************/
void neosd_uart0_print_r7(neosd_rshort_t* rshort)
{
    neosd_r7_t* r7 = &rshort->r7;
    neorv32_uart0_printf("NEOSD: Flags: %x\n", NEOSD->IRQ_FLAG);
    neorv32_uart0_printf("NEOSD: CMD8 RAW: %x %x (%d)\n", rshort->_raw[1],
        rshort->_raw[0], sizeof(neosd_rshort_t));
    neorv32_uart0_printf("NEOSD: CMD8 CRC: %x CALC: %x OK: %d\n", rshort->crc,
        neosd_rshort_crc(rshort), neosd_rshort_check(rshort));
    neorv32_uart0_printf("NEOSD: CMD8 Pattern: %x, Voltage: %x, PCIE: %d, PCIE12V: %d CMD: %x\n",
        r7->pattern, r7->voltage, r7->pcie, r7->pci12v, r7->cmd);
    neorv32_uart0_printf("NEOSD: CMD8 Start Bit: %d, Transmission Bit: %d, End Bit: %d\n",
        r7->_sbit, r7->_tbit, r7->_ebit);
}

#ifdef __cplusplus
}
#endif