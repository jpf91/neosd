#pragma once

#include <cstdint>
#include "neosd.h"

#ifdef __cplusplus
extern "C" {
#endif

    #define NEOSD_CMD_TIMEOUT 100

    typedef struct {
        union {
            struct __attribute__((packed)) {
                uint8_t _dummy : 1;
                uint8_t crc : 7;
                uint16_t mdt : 12;
                uint8_t _dummy2 : 4;
                uint32_t psn;
                uint8_t prv;
                char pnm[5];
                char oid[2];
                uint8_t mid;
            };
            uint32_t _raw[4];
        };
    } cid_reg_t;

    typedef struct {
        uint8_t ccs: 1;
        uint8_t uhs2: 1;
        uint8_t s18a: 1;
        uint32_t ocr;
        cid_reg_t cid; // FIXME: Also get CSR?
        uint16_t rca;
    } sd_card_t;


    SD_CODE neosd_app_card_init(sd_card_t* info);
    bool neosd_app_configure_datamode(bool d4mode, uint16_t rca);
    bool neosd_app_read_block(size_t block, uint32_t* buf);
    
#ifdef __cplusplus
}
#endif