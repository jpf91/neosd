# NeoSD SD Card Controller

This is an SD Card controller with a coding style inspired by the [NEORV32 RISC-V](https://github.com/stnolting/neorv32).
The IP core has a generic wishbone interface (+ a generic interface for interrupts) so it can be used with any CPU.
The drivers and the code have been written in a similar style to the NEORV32 though, so it likely integrates best with this CPU.

> **Warning!** This project is still very much WIP and currently lacks documentation.

## Current Status

This project is still very much work in progress.
Right now there's a working example that can issue commands to an SD card and there's code for the standard SD card initialization.
Data transfers on the DAT line are not yet implemented though, so you are limited to non-data commands.
See below for a detailed TODO list.

### Hardware

- [x] Wishbone Register Interface
- [x] Transmitting SD Commands
- [x] Receiving Short Responses (R1, R3, R6, R7)
- [x] Receiving Long Responses (R2)
- [x] Response Timeout: Handled in Software. SW performs Reset of Controller, Reset not implemented in HW yet.
- [x] Reading Commands From Single 32 bit Register
- [x] Stalling the SD Card Clock When Waiting for CPU to Read Data
- [x] Clock Arbiter, so Both Command and Data FSM Can Stall Clock
- [x] Continuous Clocking During Idle for ACMD41
- [x] Busy Response (R1b) Support
- [x] Single Data Block Read
- [x] Single Data Block Write
- [x] Multiple Data Block Read (includes proper Stop CMD Timing)
- [ ] Multiple Data Block Write (includes proper Stop CMD Timing)
- [x] 1-Wire Data Transport
- [x] 4-Wire Data Transport
- [ ] Interrupt Support
- [ ] NEORV-like Clock Divider
- [ ] Independent Data Interrupt Output for DMA
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


## Future Optimization Ideas

* Do not use separate registers for the data storage and the serdes register:
  Directly load CMD, CRC and CMDARG into the serdes register. Needs to be 48 bit then.
  This needs to happen using the main clock then => might have to split load enable / shift enable.
* Do not use multiple RESP registers but instead split into 32 bit chunks and
  stall clock until user read it, like with data register.