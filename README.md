# NeoSD SD Card Controller

This is an SD Card controller with a coding style inspired by the [NEORV32 RISC-V](https://github.com/stnolting/neorv32).
The IP core has a generic wishbone interface (+ a generic interface for interrupts) and can be used with any CPU.
The drivers and the code have been written in a similar style to the NEORV32 though, they integrate best with this CPU.

> **Warning!** This project is still WIP and currently lacks documentation.

## Current Status

The hardware is feature complete and hardware revision `v0.1.0` has been finalized.
It has been tested on Tang Nano FPGA using the open source toolchains and on 7 series Xilinx FPGAs using proprietary Xilinx tools.
Some functionality has also been tested in simulation, although the simulation suite is still incomplete.

The driver library is still very rough.
It currently only supports a blocking API and some edge cases have not been fully implemented or tested (reset after timeout etc).
It can however be used to read and write data and there's also ready to use code for card initialization.
There is even a backend for FatFs and reading files from FAT formatted SD Cards is fully supported.
See the [psoc-sw-player](https://github.com/kit-kch/psoc-sw-player) audio player firmware for details.

Both the hardware and the library currently don't have any documentation, but there are ready-to-use examples available.

### Hardware

- [x] Wishbone Register Interface
- [x] Transmitting SD Commands
- [x] Receiving Short Responses (R1, R3, R6, R7)
- [x] Receiving Long Responses (R2)
- [x] Response Timeout: Handled in Software. SW performs Reset of Controller, Reset is implemented in HW.
- [x] Reading Commands From Single 32 bit Register
- [x] Stalling the SD Card Clock When Waiting for CPU to Read Data
- [x] Clock Arbiter, so Both Command and Data FSM Can Stall Clock
- [x] Continuous Clocking During Idle for ACMD41
- [x] Busy Response (R1b) Support
- [x] Single Data Block Read
- [x] Single Data Block Write
- [x] Multiple Data Block Read (Includes proper Stop CMD Timing)
- [x] Multiple Data Block Write (Includes proper Stop CMD Timing)
- [x] 1-Wire Data Transport
- [x] 4-Wire Data Transport
- [x] Interrupt Support
- [x] Independent Data Interrupt Output for DMA
- [x] NEORV-like Clock Divider

### Driver
- [x] Low-Level Definitions
- [x] Low-Level Blocking API
- [x] Application-Level API (Currently limited to blocking API)
- [ ] Low-Level Interrupt API
- [ ] FreeRTOS Wrapper


### Testing

- [x] Basic CocoTB Simulation
- [ ] Proper CocoTB Drivers and Monitors for SD Card
- [ ] Extensive Test Cases for Special Cases

- [x] FPGA Test: Intialize SD Card
- [x] FPGA Test: Read single block
- [x] FPGA Test: Write single block
- [x] FPGA Test: Read multiple blocks
- [x] FPGA Test: Write multiple blocks
- [x] FPGA Test: FatFs port (reading)