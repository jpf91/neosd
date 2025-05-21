#include <neorv32.h>
#include <neosd.h>

#define BAUD_RATE 19200

// Implements Figure 4-2 from Physical Layer Simplified Specification Version 9.10
SD_CODE neosd_card_init(sd_card_t* info)
{
    neosd_res_t resp;
    sd_status_t status;
    *info = {};

    // Reset card with CMD0
    // No response expected on this command
    neosd_cmd_commit(SD_CMD0, 0, NEOSD_RMODE_NONE, NEOSD_DMODE_NONE);
    neosd_cmd_wait_res(&resp, NEOSD_CMD_TIMEOUT);
    NEOSD_DEBUG_MSG("NEOSD: Sent CMD0\n");

    // Now send CMD8
    neosd_cmd_commit(SD_CMD8, (0b0001 << 8) | (0xA4), NEOSD_RMODE_SHORT, NEOSD_DMODE_NONE);
    NEOSD_DEBUG_MSG("NEOSD: Sent CMD8\n");
    if (neosd_cmd_wait_res(&resp, NEOSD_CMD_TIMEOUT))
    {
        NEOSD_DEBUG_MSG("NEOSD: Got response. Is V2.0 or later card\n");
        NEOSD_DEBUG_R7(&resp.rshort);

        if (!neosd_rshort_check(&resp.rshort))
        {
            NEOSD_DEBUG_MSG("NEOSD: CRC invalid\n");
            return NEOSD_CRC_ERR;
        }
        if (resp.rshort.r7.pattern != 0xA4 ||
            resp.rshort.r7.voltage != 0b0001) // Table 4-41
        {
            NEOSD_DEBUG_MSG("NEOSD: Check pattern or voltage invalid\n");
            return NEOSD_INCOMPAT_CARD;
        }

            // Send inquiry ACMD41 to get OCR. 4.2.3.1 Initialization Command (ACMD41)
        switch (neosd_acmd_commit(SD_ACMD41, 0, NEOSD_RMODE_SHORT, NEOSD_DMODE_NONE, &status))
        {
            case NEOSD_CRC_ERR:
                return NEOSD_CRC_ERR;
            case NEOSD_OK:
                break;
            default:
                return NEOSD_INCOMPAT_CARD;
        }
        NEOSD_DEBUG_MSG("NEOSD: Sent inquiry ACMD41\n");

        if (!neosd_cmd_wait_res(&resp, NEOSD_CMD_TIMEOUT))
        {
            NEOSD_DEBUG_MSG("NEOSD: No response\n");
            return NEOSD_INCOMPAT_CARD;
        }
        NEOSD_DEBUG_MSG("NEOSD: Got response\n");
        NEOSD_DEBUG_R3(&resp.rshort);
        // Note: R3 does not have CRC. Figure 4-4
        // FIXME: Do voltage check with OCR here. See Table 5-1
        

        // Now do the initialization ACMD41. 4.2.3.1 Initialization Command (ACMD41)
        uint64_t timeout = neosd_clint_time_get_ms() + 1000;
        // FIXME: Voltage switch not supported for now in driver, always using 3.3V
        uint32_t acmd41_arg = (1 << SD_ACMD41_HCS) | (1 << SD_ACMD41_XPC) | (0 << SD_ACMD41_S18R) |
            (1 << 20); //3.3V
        NEOSD_DEBUG_MSG("NEOSD: acmd41_arg=%x\n", acmd41_arg);
        while (true)
        {
            if (neosd_clint_time_get_ms() > timeout)
            {
                NEOSD_DEBUG_MSG("NEOSD: Card was returning busy for more than 1s\n");
                return NEOSD_TIMEOUT;
            }

            switch (neosd_acmd_commit(SD_ACMD41, acmd41_arg, NEOSD_RMODE_SHORT, NEOSD_DMODE_NONE, &status))
            {
                case NEOSD_CRC_ERR:
                    return NEOSD_CRC_ERR;
                case NEOSD_OK:
                    break;
                default:
                    return NEOSD_INCOMPAT_CARD;
            }
            NEOSD_DEBUG_MSG("NEOSD: Sent init ACMD41\n");
    
            if (!neosd_cmd_wait_res(&resp, NEOSD_CMD_TIMEOUT))
            {
                NEOSD_DEBUG_MSG("NEOSD: No response\n");
                return NEOSD_INCOMPAT_CARD;
            }
            NEOSD_DEBUG_MSG("NEOSD: Got response\n");
            NEOSD_DEBUG_R3(&resp.rshort);
            // FIXME: Spec says: CCS (Bit 30), UHS-II (Bit 29) and S18A (Bit 24) are valid when Busy (Bit 31) is set to 1
            // But my card never sets busy but sets the CCS bit?
            if (resp.rshort.r3.ocr & (1 << SD_R3_BUSY))
            {
                info->ocr = resp.rshort.r3.ocr;
                info->ccs = resp.rshort.r3.ocr & (1 << SD_R3_CCS) ? 1: 0;
                info->uhs2 = resp.rshort.r3.ocr & (1 << SD_R3_UHS2) ? 1 : 0;
                info->s18a = resp.rshort.r3.ocr & (1 << SD_R3_S18A) ? 1 : 0;
                NEOSD_DEBUG_MSG("NEOSD: ACMD41 process finished\n");
                break;
            }
            else
            {/*
                // FIXME: Cleanup
                if (((status._raw >> 8) & 0xF) == 1 )
                {
                    NEOSD_DEBUG_MSG("NEOSD: Card is in wrong state\n");
                }
                else
                {*/
                    //NEOSD_DEBUG_MSG("NEOSD: ACMD41 process finished\n");
                    //break;
                //}
            }
        }
    }
    else
    {
        // No response could mean voltage mismatch, or Ver 1.X SD card or no card
        NEOSD_DEBUG_MSG("NEOSD: No response. Is V1.x or no card. Not supported yet\n");
#if 0
        if (!send_acmd41_with_hcs0)
        {
            // No SD Card
            return 0;
        }
        else
        {
            // Repeat ACMD41 until card does not return busy anymore
            
            // Time out or no response => Error, non compatible voltage

            // Not busy => Success. V1.X SC SD
        }
#endif
        return NEOSD_INCOMPAT_CARD;
    }

    // Do voltage switching here. Not supported yet
    /*
    if (S18R == 1 and S18A == 1)
    {
        send CMD11
    }
    */

    // Now send CMD2
    neosd_cmd_commit(SD_CMD2, 0, NEOSD_RMODE_LONG, NEOSD_DMODE_NONE);
    NEOSD_DEBUG_MSG("NEOSD: Sent CMD2\n");
    if (!neosd_cmd_wait_res(&resp, NEOSD_CMD_TIMEOUT))
    {
        NEOSD_DEBUG_MSG("NEOSD: No response\n");
        return NEOSD_INCOMPAT_CARD;
    }

    NEOSD_DEBUG_MSG("NEOSD: Got response\n");
    NEOSD_DEBUG_R2(&resp);

    if (!neosd_rlong_check(&resp.r2))
    {
        NEOSD_DEBUG_MSG("NEOSD: CRC invalid\n");
        return NEOSD_CRC_ERR;
    }

    info->cid._raw[0] = resp.r2.reg0;
    info->cid._raw[1] = resp.r2.reg1;
    info->cid._raw[2] = resp.r2.reg2;
    info->cid._raw[3] = resp.r2.reg3;

    // 5.2 CID register

    // Now send CMD3
    neosd_cmd_commit(SD_CMD3, 0, NEOSD_RMODE_SHORT, NEOSD_DMODE_NONE);
    NEOSD_DEBUG_MSG("NEOSD: Sent CMD3\n");
    if (!neosd_cmd_wait_res(&resp, NEOSD_CMD_TIMEOUT))
    {
        NEOSD_DEBUG_MSG("NEOSD: No response\n");
        return NEOSD_INCOMPAT_CARD;
    }

    NEOSD_DEBUG_MSG("NEOSD: Got response\n");
    NEOSD_DEBUG_R6(&resp.rshort);

    if (!neosd_rshort_check(&resp.rshort))
    {
        NEOSD_DEBUG_MSG("NEOSD: CRC invalid\n");
        return NEOSD_CRC_ERR;
    }

    // 4.4 clock control: Poll ACMD with 50ms

    return NEOSD_OK;
}

int main()
{
    neorv32_rte_setup();
    neorv32_uart0_setup(BAUD_RATE, 0);
    neorv32_uart0_puts("Test program booted\n");

    neosd_setup(CLK_PRSC_1024, 0, 0);
    neorv32_uart0_printf("NEOSD: Controller initialized\n");

    sd_card_t info;
    switch (neosd_card_init(&info))
    {
        case NEOSD_OK:
            neorv32_uart0_printf("SD Card initialized: CCS: %d, UHS2: %d, S18A: %d, OCR: %x\n",
                info.ccs, info.uhs2, info.s18a, info.ocr);
            neorv32_uart0_printf("    Manufacturer: %x, OID: %c%c, Product: %c%c%c%c%c\n",
                info.cid.mid, info.cid.oid[1], info.cid.oid[0], info.cid.pnm[4],
                info.cid.pnm[3], info.cid.pnm[2], info.cid.pnm[1], info.cid.pnm[0]);
            neorv32_uart0_printf("    Revision: %d.%d, Serial: %u, Date: %d/%d\n",
                info.cid.prv >> 4, info.cid.prv & 0xF, info.cid.psn, info.cid.mdt & 0xF,
                (info.cid.mdt >> 4) + 2000);
            break;
        case NEOSD_NO_CARD:
            neorv32_uart0_printf("No SD Card found\n");
            break;
        case NEOSD_INCOMPAT_CARD:
            neorv32_uart0_printf("Inserted SD Card is not compatible\n");
            break;
        case NEOSD_CRC_ERR:
            neorv32_uart0_printf("CRC error during communication\n");
            break;
        case NEOSD_TIMEOUT:
            neorv32_uart0_printf("Timeout during communication\n");
            break;
    }

    // neosd_card_read
    // neosd_card_write

    return 0;
}
