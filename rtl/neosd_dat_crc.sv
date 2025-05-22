module neosd_dat_crc (
    input clk_i,
    input rstn_i,
    // Strobe to obtain the slow SD clock
    input clkstrb_i,

    input data_s_i,
    input shift_s_i,
    input output_s_i,
    output data_s_o,
    output nonzero_o
);
    logic[15:0] sreg;
    logic sreg_fb;

    assign nonzero_o = |sreg;
    assign data_s_o = sreg[0];
    // If we're shifting out, sreg_fb should be 0 so that we don't modify stored values
    assign sreg_fb = (data_s_i ^ sreg[0]) & ~output_s_i;

    always @(posedge clk_i or negedge rstn_i) begin
        if (rstn_i == 1'b0) begin
            sreg <= '0;
        end else begin
            if (clkstrb_i == 1'b1 && shift_s_i == 1'b1) begin
                sreg[15] <= sreg_fb;
                sreg[14:11] <= sreg[15:12];
                sreg[10] <= sreg[11] ^ sreg_fb;
                sreg[9:4] <= sreg[10:5];
                sreg[3] <= sreg[4] ^ sreg_fb;
                sreg[2:0] <= sreg[3:1];
            end
        end
    end
endmodule