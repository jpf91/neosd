`default_nettype none
`timescale 1ns / 1ps

module tb_dat_block ();

    initial begin
        $dumpfile("tb_data_block.vcd");
        $dumpvars(0, tb_dat_block);
        #1;
    end

    wire clk_i;
    wire clkstrb_i;
    wire rstn_i;
  
    wire ctrl_rnw_i;
    wire ctrl_d4_i;
    wire ctrl_rot_reg;
    wire [1:0] ctrl_omux_i;
    wire ctrl_output_crc_i;
  
    wire sd_dat0_i;
    wire sd_dat1_i;
    wire sd_dat2_i;
    wire sd_dat3_i;
  
    wire sd_dat0_o;
    wire sd_dat1_o;
    wire sd_dat2_o;
    wire sd_dat3_o;

    wire sd_dat_oe;
    assign sd_dat_oe = 0;
  
    wire shift_s_i;
    wire crc_nonzero_o;
    wire [31:0] data_p_i;
    wire load_p_i;
    wire [31:0] data_p_o;
  
    neosd_dat_block u_neosd_dat_block (
      .clk_i(clk_i),
      .clkstrb_i(clkstrb_i),
      .rstn_i(rstn_i),

      .ctrl_rnw_i(ctrl_rnw_i),
      .ctrl_d4_i(ctrl_d4_i),
      .ctrl_rot_reg(ctrl_rot_reg),
      .ctrl_omux_i(ctrl_omux_i),
      .ctrl_output_crc_i(ctrl_output_crc_i),

      .sd_dat0_i(sd_dat0_i),
      .sd_dat1_i(sd_dat1_i),
      .sd_dat2_i(sd_dat2_i),
      .sd_dat3_i(sd_dat3_i),
      .sd_dat0_o(sd_dat0_o),
      .sd_dat1_o(sd_dat1_o),
      .sd_dat2_o(sd_dat2_o),
      .sd_dat3_o(sd_dat3_o),

      .shift_s_i(shift_s_i),
      .crc_nonzero_o(crc_nonzero_o),
      .data_p_i(data_p_i),
      .load_p_i(load_p_i),
      .data_p_o(data_p_o)
    );

endmodule
