#pragma once

#include <stdint.h>
#include <stdlib.h>

#ifdef __cplusplus
extern "C" {
#endif

    #ifndef NEOSD_BASE
        #define NEOSD_BASE   (0xFFD20000U)
    #endif

    typedef volatile struct __attribute__((packed,aligned(4))) {
        uint32_t CTRL;     // NEOSD_CTRL_enum
        uint32_t STAT;     // unused
        uint32_t IRQ_FLAG; // NEOSD_IRQ_enum
        uint32_t IRQ_MASK; // NEOSD_IRQ_enum
        uint32_t CMDARG;   // 32 Bit CMD Argument
        uint32_t CMD;      // 
        uint32_t RESP;
        uint32_t DATA;
    } neosd_t;

    enum NEOSD_CTRL_enum {
        NEOSD_CTRL_EN            =  0,
        NEOSD_CTRL_RST           =  1,
        NEOSD_CTRL_ABRT          =  2,
        NEOSD_CTRL_CDIV0         =  3, // actually PRSCL
        NEOSD_CTRL_CDIV1         =  4,
        NEOSD_CTRL_CDIV2         =  5,
        NEOSD_CTRL_D4BIT         =  6,
        NEOSD_CTRL_IDLE_CLK      =  7,
    };

    enum NEOSD_IRQ_enum {
        NEOSD_IRQ_CMD_DONE       =  0,
        NEOSD_IRQ_CMD_RESP       =  1,
        NEOSD_IRQ_DAT_DONE       =  2,
        NEOSD_IRQ_DAT_DATA       =  3,
        NEOSD_IRQ_DAT_BLOCK      =  4,
    };

    enum NEOSD_STAT_enum {
        NEOSD_STAT_IDLE_CMD       =  0,
        NEOSD_STAT_IDLE_DAT       =  1,
        NEOSD_STAT_CRCERR         =  2,
    };

    enum NEOSD_CMD_enum {
        NEOSD_CMD_COMMIT          =  0,
        NEOSD_CMD_LAST_BLOCK      =  1,
        NEOSD_CMD_DMODE0          =  2,
        NEOSD_CMD_DMODE1          =  3,
        NEOSD_CMD_RMODE0          =  4,
        NEOSD_CMD_RMODE1          =  5,
        NEOSD_CMD_CRC_LSB         =  8,
        NEOSD_CMD_CRC_MSB         =  14,
        NEOSD_CMD_IDX_LSB         =  16,
        NEOSD_CMD_IDX_MSB         =  21
    };

    enum NEOSD_RMODE {
        NEOSD_RMODE_NONE          =  0,
        NEOSD_RMODE_SHORT         =  1,
        NEOSD_RMODE_LONG          =  2
    };

    enum NEOSD_DMODE {
        NEOSD_DMODE_NONE          =  0,
        NEOSD_DMODE_BUSY          =  1,
        NEOSD_DMODE_READ          =  2,
        NEOSD_DMODE_WRITE         =  3
    };

    enum SD_CMD_IDX {
        SD_CMD0          =  0,
        SD_CMD2          =  2,
        SD_CMD3          =  3,
        SD_CMD8          =  8,
        SD_ACMD41        = 41,
        SD_CMD55         = 55
    };

    enum {
        SD_ACMD41_HCS = 30,
        SD_ACMD41_XPC = 28,
        SD_ACMD41_S18R = 24,
        SD_ACMD41_OCR = 8
    };

    enum {
        SD_R3_BUSY = 31,
        SD_R3_CCS = 30,
        SD_R3_UHS2 = 29,
        SD_R3_S18A = 24
    };

    // Table 4-42 : Card Status
    typedef union {
        uint32_t _raw;
    } sd_status_t;

    enum SD_CODE {
        NEOSD_OK =  0,
        NEOSD_NO_CARD = 1,
        NEOSD_INCOMPAT_CARD = 2,
        NEOSD_CRC_ERR = 3,
        NEOSD_TIMEOUT = 4
    };

    #define NEOSD ((neosd_t*) (NEOSD_BASE))

    // 4.9 Responses
    typedef struct __attribute__((packed)) {
        bool _ebit: 1;
        uint8_t crc: 7;
        uint32_t status: 32;
        uint8_t cmd: 6;
        bool _tbit: 1;
        bool _sbit: 1;
    } neosd_r1_t;

    typedef struct __attribute__((packed)) {
        bool _ebit: 1;
        uint32_t reg0: 31;
        uint32_t reg1: 32;
        uint32_t reg2: 32;
        uint32_t reg3: 32;
        uint8_t _reserved: 6;
        bool _tbit: 1;
        bool _sbit: 1;
    } neosd_r2_t;

    typedef struct __attribute__((packed)) {
        bool _ebit: 1;
        uint8_t _reserved0: 7;
        uint32_t ocr: 32;
        uint8_t _reserved1: 6;
        bool _tbit: 1;
        bool _sbit: 1;
    } neosd_r3_t;

    typedef struct __attribute__((packed)) {
        bool _ebit: 1;
        uint8_t crc: 7;
        uint16_t status: 16;
        uint16_t rca: 16;
        uint8_t cmd: 6;
        bool _tbit: 1;
        bool _sbit: 1;
    } neosd_r6_t;

    typedef struct __attribute__((packed)) {
        bool _ebit: 1;
        uint8_t crc: 7;
        uint8_t pattern: 8;
        uint8_t voltage: 4;
        bool pcie: 1;
        bool pci12v: 1;
        uint32_t _reserved: 18;
        uint8_t cmd: 6;
        bool _tbit: 1;
        bool _sbit: 1;
    } neosd_r7_t;

    typedef union {
        neosd_r1_t r1;
        neosd_r3_t r3;
        neosd_r6_t r6;
        neosd_r7_t r7;
        struct __attribute__((packed)) {
            bool _ebit: 1;
            uint8_t crc: 7;
            uint64_t __dummy : 38;
            bool _tbit: 1;
            bool _sbit: 1;
        };
        uint32_t _raw[2];
    } neosd_rshort_t;
    

    typedef union {
        struct {
            uint32_t _dummy[3];
            neosd_rshort_t rshort;
        };
        neosd_r2_t r2;
        uint32_t _raw[5];
    } neosd_res_t;

    // Low-level helper functions
    uint8_t neosd_crc7(const uint8_t* data, size_t length);
    uint8_t neosd_cmd_crc(uint8_t cmd_idx, uint32_t cmd_arg);
    uint8_t neosd_rshort_crc(neosd_rshort_t* data);
    bool neosd_rshort_check(neosd_rshort_t* data);
    uint8_t neosd_rlong_crc(neosd_r2_t* data);
    bool neosd_rlong_check(neosd_r2_t* data);

    // Generic driver functions
    void neosd_setup(int prsc, int cdiv, uint32_t irq_mask);
    uint32_t neosd_get_clock_speed();
    void neosd_set_clock_div(int prsc, int cdiv);
    void neosd_disable();
    void neosd_enable();
    void neosd_begin_reset();
    void neosd_end_reset();
    void neosd_set_idle_clk(bool active);
    int neosd_busy();

    // Command functions
    void neosd_cmd_commit(SD_CMD_IDX cmd, uint32_t arg, NEOSD_RMODE rmode, NEOSD_DMODE dmode, bool stopDAT = false);

    // Blocking functions (neosd_block.cpp)
    void neosd_reset();
    uint64_t neosd_clint_time_get_ms();
    void neosd_wait_idle();
    bool neosd_cmd_wait_res(neosd_res_t* res, uint32_t rtimeout);
    SD_CODE neosd_acmd_commit(SD_CMD_IDX acmd, uint32_t arg, NEOSD_RMODE rmode, NEOSD_DMODE dmode, sd_status_t* status, size_t rca, uint32_t rtimeout);



#ifdef __cplusplus
}
#endif