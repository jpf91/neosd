#include <neorv32.h>
#include <neosd.h>

#define BAUD_RATE 19200

int main()
{
    neorv32_rte_setup();
    neorv32_uart0_setup(BAUD_RATE, 0);
    neorv32_uart0_puts("Test program booted\n");

    neosd_setup(CLK_PRSC_1024, 0, 0);
    neorv32_uart0_printf("NEOSD: Controller initialized\n");

    neosd_res_t resp;
    // Let's send a CMD0
    neosd_cmd_commit(SD_CMD0, 0, NEOSD_RMODE_NONE, NEOSD_DMODE_NONE);
    neosd_cmd_wait_res(&resp);
    neorv32_uart0_printf("NEOSD: Sent CMD0\n");

    // Now send CMD8
    neosd_cmd_commit(SD_CMD8, (0b0001 << 8) | (0xA4), NEOSD_RMODE_SHORT, NEOSD_DMODE_NONE);
    neorv32_uart0_printf("NEOSD: Sent CMD8\n");
    neosd_cmd_wait_res(&resp);

    neorv32_uart0_printf("NEOSD: Got Response\n");
    neosd_uart0_print_r7(&resp.rshort);

    return 0;
}
