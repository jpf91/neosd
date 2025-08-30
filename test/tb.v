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
    wire irq_o;
    wire flag_data_o;

    wire sd_clk_o;
    wire sd_cmd_o;
    wire sd_cmd_i;
    wire sd_cmd_oe;
    wire[3:0] sd_dat_o, sd_dat_i, sd_dat_oe;
    wire sd_dat0_o, sd_dat1_o, sd_dat2_o, sd_dat3_o;
    wire sd_dat0_i, sd_dat1_i, sd_dat2_i, sd_dat3_i;
    wire sd_dat0_oe, sd_dat1_oe, sd_dat2_oe, sd_dat3_oe;
    assign sd_dat_i = {sd_dat3_i, sd_dat2_i, sd_dat1_i, sd_dat0_i};
    assign sd_dat0_o = sd_dat_o[0];
    assign sd_dat1_o = sd_dat_o[1];
    assign sd_dat2_o = sd_dat_o[2];
    assign sd_dat3_o = sd_dat_o[3];
    assign sd_dat0_oe = sd_dat_oe[0];
    assign sd_dat1_oe = sd_dat_oe[1];
    assign sd_dat2_oe = sd_dat_oe[2];
    assign sd_dat3_oe = sd_dat_oe[3];

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
        .wb_dat_o(wb_dat_o),

        .irq_o(irq_o),
        .flag_data_o(flag_data_o),

        .sd_clk_o(sd_clk_o),
        .sd_cmd_o(sd_cmd_o),
        .sd_cmd_i(sd_cmd_i),
        .sd_cmd_oe(sd_cmd_oe),
        .sd_dat_o(sd_dat_o),
        .sd_dat_i(sd_dat_i),
        .sd_dat_oe(sd_dat_oe)
    );

endmodule
