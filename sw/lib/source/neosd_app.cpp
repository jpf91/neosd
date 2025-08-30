#include "neosd_app.h"
#include "neosd_dbg.h"

extern "C" {

    // Implements Figure 4-2 from Physical Layer Simplified Specification Version 9.10
    // TODO: Revisit spec and finalize this
    SD_CODE neosd_app_card_init(sd_card_t* info)
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
            switch (neosd_acmd_commit(SD_ACMD41, 0, NEOSD_RMODE_SHORT, NEOSD_DMODE_NONE, &status, 0, NEOSD_TIMEOUT))
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
            NEOSD_DEBUG_R3(&resp.rshort);
            // Note: R3 does not have CRC. Figure 4-4
            // FIXME: Do voltage check with OCR here. See Table 5-1
            

            // Now do the initialization ACMD41. 4.2.3.1 Initialization Command (ACMD41)
            uint64_t timeout = neosd_clint_time_get_ms() + 1000;
            // FIXME: Voltage switch not supported for now in driver, always using 3.3V
            uint32_t acmd41_arg = (1 << SD_ACMD41_HCS) | (1 << SD_ACMD41_XPC) | (0 << SD_ACMD41_S18R) | (1 << 20); //3.3V
            NEOSD_DEBUG_MSG("NEOSD: acmd41_arg=%x\n", acmd41_arg);
            while (true)
            {
                if (neosd_clint_time_get_ms() > timeout)
                {
                    NEOSD_DEBUG_MSG("NEOSD: Card was returning busy for more than 1s\n");
                    return NEOSD_TIMEOUT;
                }

                switch (neosd_acmd_commit(SD_ACMD41, acmd41_arg, NEOSD_RMODE_SHORT, NEOSD_DMODE_NONE, &status, 0, NEOSD_TIMEOUT))
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
            return NEOSD_INCOMPAT_CARD;
        }

        // Could do voltage switching here. Not supported though.
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
        NEOSD_DEBUG_R6(&resp.rshort);

        if (!neosd_rshort_check(&resp.rshort))
        {
            NEOSD_DEBUG_MSG("NEOSD: CRC invalid\n");
            return NEOSD_CRC_ERR;
        }

        info->rca = resp.rshort.r6.rca;

        // 4.4 clock control: Poll ACMD with 50ms

    
        // Now send CMD3 to go to data mode
        // FIXME: Use NEOSD_DMODE_BUSY
        neosd_cmd_commit((SD_CMD_IDX)7, info->rca << 16, NEOSD_RMODE_SHORT, /*NEOSD_DMODE_BUSY*/NEOSD_DMODE_NONE);

        NEOSD_DEBUG_MSG("NEOSD: Sent CMD7\n");
        if (!neosd_cmd_wait_res(&resp, 10*NEOSD_CMD_TIMEOUT))
        {
            NEOSD_DEBUG_MSG("NEOSD: No response\n");
            return NEOSD_INCOMPAT_CARD;
        }
        NEOSD_DEBUG_R1(&resp.rshort);

        // Do CMD42 to unlock here, but not supported for now
        // CMD6: Could select some adiditonal things...

    
        // CMD16 Set block length
        neosd_cmd_commit((SD_CMD_IDX)16, 512, NEOSD_RMODE_SHORT, NEOSD_DMODE_NONE);

        NEOSD_DEBUG_MSG("NEOSD: Sent CMD16\n");
        if (!neosd_cmd_wait_res(&resp, NEOSD_CMD_TIMEOUT))
        {
            NEOSD_DEBUG_MSG("NEOSD: No response\n");
            return NEOSD_INCOMPAT_CARD;
        }
        NEOSD_DEBUG_R1(&resp.rshort);


        return NEOSD_OK;
    }

    bool neosd_app_configure_datamode(bool d4mode, uint16_t rca)
    {
        neosd_res_t resp;

        // ACMD6 SET_BUS_WIDTH 10=4 bit, 00=1 bit
        size_t arg = d4mode ? 0b10 : 0b00;
        sd_status_t status;
        if (neosd_acmd_commit((SD_CMD_IDX)6, arg, NEOSD_RMODE_SHORT, NEOSD_DMODE_NONE, &status, rca, NEOSD_TIMEOUT) != NEOSD_OK)
            return false;

        NEOSD_DEBUG_MSG("NEOSD: Sent ACMD6\n");
        if (!neosd_cmd_wait_res(&resp, NEOSD_CMD_TIMEOUT))
        {
            NEOSD_DEBUG_MSG("NEOSD: No response\n");
            return false;
        }
        NEOSD_DEBUG_R1(&resp.rshort);

        if (d4mode)
            NEOSD->CTRL |= (1 << NEOSD_CTRL_D4);
        else
            NEOSD->CTRL &= ~(1 << NEOSD_CTRL_D4);

        return true;
    }

    bool neosd_app_read_block(size_t block, uint32_t* buf)
    {
        neosd_res_t resp;

        // CMD17: READ_SINGLE_BLOCK
        neosd_cmd_commit((SD_CMD_IDX)17, block, NEOSD_RMODE_SHORT, NEOSD_DMODE_READ);
        NEOSD_DEBUG_MSG("NEOSD: Sent CMD17\n");

        uint32_t* rptr = &resp._raw[4];
        uint32_t* dptr = &buf[0];

        // R1 and maybe data
        while (true)
        {
            auto irq = NEOSD->CTRL;

            if (irq & (1 << NEOSD_CTRL_FLAG_CMD_RESP))
                *(rptr--) = NEOSD->RESP;

            if (irq & (1 << NEOSD_CTRL_FLAG_CMD_DONE))
            {
                NEOSD->CTRL &= ~(1 << NEOSD_CTRL_FLAG_CMD_DONE);
                NEOSD_DEBUG_R1(&resp.rshort);
            }

            if (irq & (1 << NEOSD_CTRL_FLAG_DAT_DATA))
                *(dptr++) = NEOSD->DATA;

            if (irq & (1 << NEOSD_CTRL_FLAG_BLK_DONE))
            {
                NEOSD->CTRL &= ~(1 << NEOSD_CTRL_FLAG_BLK_DONE);
                NEOSD->CMD = (1 << NEOSD_CMD_ABRT_DAT);
            }

            if (irq & (1 << NEOSD_CTRL_FLAG_DAT_DONE))
            {
                NEOSD->CTRL &= ~(1 << NEOSD_CTRL_FLAG_DAT_DONE);
                break;
            }
        }

        // FIXME: return CRC flag...
        // FIXME: Wait for controller IDLE
        return true;
    }
}