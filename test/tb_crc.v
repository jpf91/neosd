`default_nettype none
`timescale 1ns / 1ps

module tb_crc ();

    initial begin
        $dumpfile("tb_crc.vcd");
        $dumpvars(0, tb_crc);
        #1;
    end

    wire clk;
    wire rstn;
    wire clkstrb;
    wire data_s_i;
    wire shift_s;
    wire output_s;
    wire data_s_o;
    wire nonzero;

    neosd_dat_crc dut (
        .clk_i(clk),
        .rstn_i(rstn),
        .clkstrb_i(clkstrb),
        .data_s_i(data_s_i),
        .shift_s_i(shift_s),
        .output_s_i(output_s),
        .data_s_o(data_s_o),
        .nonzero_o(nonzero)
    );

endmodule
