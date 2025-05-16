#ifndef NEOSD_H
#define NEOSD_H
#ifdef __cplusplus
extern "C" {
#endif

    #include <cstdint>
    #include <cstdlib>

    // Replacing the internal SLINK
    //#define NEOSD_BASE   (0xFFEC0000U)
    // For XBUS
    #define NEOSD_BASE   (0xF0000000U)

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
        NEOSD_CTRL_CDIV3         =  6
    };

    enum NEOSD_IRQ_enum {
        NEOSD_IRQ_CMD_DONE       =  0,
        NEOSD_IRQ_CMD_RESP       =  1
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
        SD_CMD8          =  8
    };

    #define NEOSD ((neosd_t*) (NEOSD_BASE))

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
        uint32_t _raw[5];
    } neosd_res_t;

    // Low-level helper functions
    uint8_t neosd_crc7(const uint8_t* data, size_t length);
    uint8_t neosd_cmd_crc(uint8_t cmd_idx, uint32_t cmd_arg);
    uint8_t neosd_rshort_crc(neosd_rshort_t* data);
    bool neosd_rshort_check(neosd_rshort_t* data);

    // Generic driver functions
    void neosd_setup(int prsc, int cdiv, uint32_t irq_mask);
    uint32_t neosd_get_clock_speed();
    void neosd_set_clock_div(int prsc, int cdiv);
    void neosd_disable();
    void neosd_enable();
    void neosd_reset();
    int neosd_busy();

    // Command functions
    void neosd_cmd_commit(SD_CMD_IDX cmd, uint32_t arg, NEOSD_RMODE rmode, NEOSD_DMODE dmode);

    // Blocking functions (neosd_block.cpp)
    bool neosd_cmd_wait_res(neosd_res_t* res);

    // Debug code (neosd_dbg.cpp)
    void neosd_uart0_print_r7(neosd_rshort_t* rshort);

#ifdef __cplusplus
}
#endif
#endif //NEOSD_H