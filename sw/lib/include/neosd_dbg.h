#pragma once

#include <neosd.h>

#ifdef __cplusplus
extern "C" {
#endif

    //#define NEOSD_DEBUG
    //#define NEOSD_DEBUG_CMDS

    #ifdef NEOSD_DEBUG
        #include <neorv32.h>
        #define NEOSD_DEBUG_MSG(...) neorv32_uart0_printf(__VA_ARGS__)
    #else
        #define NEOSD_DEBUG_MSG(...)
    #endif

    #ifdef NEOSD_DEBUG_CMDS
        #define NEOSD_DEBUG_R7(...) neosd_uart0_print_r7(__VA_ARGS__)
        #define NEOSD_DEBUG_R3(...) neosd_uart0_print_r3(__VA_ARGS__)
        #define NEOSD_DEBUG_R1(...) neosd_uart0_print_r1(__VA_ARGS__)
        #define NEOSD_DEBUG_R2(...) neosd_uart0_print_r2(__VA_ARGS__)
        #define NEOSD_DEBUG_R6(...) neosd_uart0_print_r6(__VA_ARGS__)
    #else
        #define NEOSD_DEBUG_R7(...)
        #define NEOSD_DEBUG_R3(...)
        #define NEOSD_DEBUG_R1(...)
        #define NEOSD_DEBUG_R2(...)
        #define NEOSD_DEBUG_R6(...)
    #endif

    // Debug code (neosd_dbg.cpp)
    void neosd_uart0_print_r7(neosd_rshort_t* rshort);
    void neosd_uart0_print_r3(neosd_rshort_t* rshort);
    void neosd_uart0_print_r1(neosd_rshort_t* rshort);
    void neosd_uart0_print_r6(neosd_rshort_t* rshort);
    void neosd_uart0_print_r2(neosd_res_t* res);

#ifdef __cplusplus
}
#endif