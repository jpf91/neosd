
# Future Optimization

* Do not use separate registers for the data storage and the serdes register:
  Directly load CMD, CRC and CMDARG into the serdes register. Needs to be 48 bit then.
  This needs to happen using the main clock then => might have to split load enable / shift enable.
* Do not use multiple RESP registers but instead split into 32 bit chunks and
  stall clock until user read it, like with data register.