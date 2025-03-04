`default_nettype none
`timescale 1ns / 1ps

module tb ();

    initial begin
        $dumpfile("tb.vcd");
        $dumpvars(0, tb);
        #1;
    end

    reg clk;
    reg rstn;

    reg[31:0] wb_adr_i;
    reg[31:0] wb_dat_i;
    reg wb_we_i;
    reg[3:0] wb_sel_i;
    reg wb_stb_i;
    reg wb_cyc_i;

    wire wb_ack_o;
    wire wb_err_o;
    wire[31:0] wb_dat_o;

    neosd dut (
        .clk_i(clk),
        .rstn_i(rstn),
    
        .wb_adr_i(wb_adr_i),
        .wb_dat_i(wb_dat_i),
        .wb_we_i(wb_we_i),
        .wb_sel_i(wb_sel_i),
        .wb_stb_i(wb_stb_i),
        .wb_cyc_i(wb_cyc_i),
    
        .wb_ack_o(wb_ack_o),
        .wb_err_o(wb_err_o),
        .wb_dat_o(wb_dat_o)
    );

endmodule
