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
    reg[7:0] clk_gen;

    reg[31:0] wb_adr_i;
    reg[31:0] wb_dat_i;
    reg wb_we_i;
    reg[3:0] wb_sel_i;
    reg wb_stb_i;
    reg wb_cyc_i;

    wire wb_ack_o;
    wire wb_err_o;
    wire[31:0] wb_dat_o;

    wire sd_clk_o;
    wire sd_cmd_o;
    wire sd_cmd_i;
    wire sd_cmd_oe;
    wire sd_dat0_o;
    wire sd_dat0_i;
    wire sd_dato_oe;

    neosd dut (
        .clk_i(clk),
        .rstn_i(rstn),
        .clkgen_i(clk_gen),
    
        .wb_adr_i(wb_adr_i),
        .wb_dat_i(wb_dat_i),
        .wb_we_i(wb_we_i),
        .wb_sel_i(wb_sel_i),
        .wb_stb_i(wb_stb_i),
        .wb_cyc_i(wb_cyc_i),
    
        .wb_ack_o(wb_ack_o),
        .wb_err_o(wb_err_o),
        .wb_dat_o(wb_dat_o),

        .sd_clk_o(sd_clk_o),
        .sd_cmd_o(sd_cmd_o),
        .sd_cmd_i(sd_cmd_i),
        .sd_cmd_oe(sd_cmd_oe),
        .sd_dat0_o(sd_dat0_o),
        .sd_dat0_i(sd_dat0_i),
        .sd_dato_oe(sd_dato_oe)
    );

    reg[11:0] cnt, cnt2;
    always @(posedge clk or negedge rstn) begin
        if (rstn == 0) begin
            cnt <= 0;
            cnt2 <= 0;
        end else begin
            cnt <= cnt + 1;
            cnt2 <= cnt;
        end
    end

    assign clk_gen[0] = cnt[0]  & !cnt2[0];  // clk_i / 2
    assign clk_gen[1] = cnt[1]  & !cnt2[1];  // clk_i / 4
    assign clk_gen[2] = cnt[2]  & !cnt2[2];  // clk_i / 8
    assign clk_gen[3] = cnt[5]  & !cnt2[5];  // clk_i / 64
    assign clk_gen[4] = cnt[6]  & !cnt2[6];  // clk_i / 128
    assign clk_gen[5] = cnt[9]  & !cnt2[9];  // clk_i / 1024
    assign clk_gen[6] = cnt[10] & !cnt2[10]; // clk_i / 2048
    assign clk_gen[7] = cnt[11] & !cnt2[11]; // clk_i / 4096

endmodule
