#include "neosd.h"
#include <neorv32.h>

#ifdef __cplusplus
extern "C" {
#endif


void neosd_uart0_print_r7(neosd_rshort_t* rshort)
{
    neosd_r7_t* r7 = &rshort->r7;
    neorv32_uart0_printf("NEOSD: R7 RAW: %x %x (%d)\n", rshort->_raw[1],
        rshort->_raw[0], sizeof(neosd_rshort_t));
    neorv32_uart0_printf("NEOSD: R7 CRC: %x CALC: %x OK: %d\n", rshort->crc,
        neosd_rshort_crc(rshort), neosd_rshort_check(rshort));
    neorv32_uart0_printf("NEOSD: R7 Pattern: %x, Voltage: %x, PCIE: %d, PCIE12V: %d CMD: %x\n",
        r7->pattern, r7->voltage, r7->pcie, r7->pci12v, r7->cmd);
    neorv32_uart0_printf("NEOSD: R7 Start Bit: %d, Transmission Bit: %d, End Bit: %d\n",
        r7->_sbit, r7->_tbit, r7->_ebit);
}

void neosd_uart0_print_r3(neosd_rshort_t* rshort)
{
    neosd_r3_t* r3 = &rshort->r3;
    neorv32_uart0_printf("NEOSD: R3 RAW: %x %x (%d)\n", rshort->_raw[1],
        rshort->_raw[0], sizeof(neosd_rshort_t));
    neorv32_uart0_printf("NEOSD: R3 OCR: %x\n", r3->ocr);
    neorv32_uart0_printf("NEOSD: R3 Start Bit: %d, Transmission Bit: %d, End Bit: %d\n",
        r3->_sbit, r3->_tbit, r3->_ebit);
}

void neosd_uart0_print_r1(neosd_rshort_t* rshort)
{
    neosd_r1_t* r1 = &rshort->r1;
    neorv32_uart0_printf("NEOSD: R1 RAW: %x %x (%d)\n", rshort->_raw[1],
        rshort->_raw[0], sizeof(neosd_rshort_t));
    neorv32_uart0_printf("NEOSD: R1 CRC: %x CALC: %x OK: %d\n", rshort->crc,
        neosd_rshort_crc(rshort), neosd_rshort_check(rshort));
    neorv32_uart0_printf("NEOSD: R1 STATUS: %x\n", r1->status);
    neorv32_uart0_printf("NEOSD: R1 Start Bit: %d, Transmission Bit: %d, End Bit: %d\n",
        r1->_sbit, r1->_tbit, r1->_ebit);
}

void neosd_uart0_print_r2(neosd_res_t* resp)
{
    neosd_r2_t* r2 = &resp->r2;
    neorv32_uart0_printf("NEOSD: R2 RAW: %x %x %x %x %x\n", resp->_raw[4], resp->_raw[3],
        resp->_raw[2], resp->_raw[1], resp->_raw[0]);
    neorv32_uart0_printf("NEOSD: R2 REG: %x %x %x %x\n", r2->reg3, r2->reg2, r2->reg1, r2->reg0);
    neorv32_uart0_printf("NEOSD: R2 CRC: %x CALC: %x OK: %d\n", r2->reg0 & 0x7F,
        neosd_rlong_crc(r2), neosd_rlong_check(r2));
    neorv32_uart0_printf("NEOSD: R2 Start Bit: %d, Transmission Bit: %d, End Bit: %d\n",
        r2->_sbit, r2->_tbit, r2->_ebit);
}

void neosd_uart0_print_r6(neosd_rshort_t* rshort)
{
    neosd_r6_t* r6 = &rshort->r6;
    neorv32_uart0_printf("NEOSD: R6 RAW: %x %x (%d)\n", rshort->_raw[1],
        rshort->_raw[0], sizeof(neosd_rshort_t));
    neorv32_uart0_printf("NEOSD: R6 CRC: %x CALC: %x OK: %d\n", rshort->crc,
        neosd_rshort_crc(rshort), neosd_rshort_check(rshort));
    neorv32_uart0_printf("NEOSD: R6 STATUS: %x RCA: %x\n", r6->status, r6->rca);
    neorv32_uart0_printf("NEOSD: R6 Start Bit: %d, Transmission Bit: %d, End Bit: %d\n",
        r6->_sbit, r6->_tbit, r6->_ebit);
}

#ifdef __cplusplus
}
#endif