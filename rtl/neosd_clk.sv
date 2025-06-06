module neosd_clk (
    input clk_i,
    input rstn_i,
    input[7:0] clkgen_i,
    input[2:0] sd_clksel_i,

    // Strobe used to sample / emit sd_cmd signals
    output clkstrb_o,

    // If we want to have an SD card clock active
    input[1:0] sd_clk_req_i,
    // Whether the clock needs to stall
    input[1:0] sd_clk_stall_i,
    // If the clock actually is active and not stalled
    output sd_clk_en_o,
    // SD CLK wire
    output reg sd_clk_o
);
    // Clock can be needed and stalled by both CMD and DATA FSMs
    assign sd_clk_en_o = (sd_clk_req_i[1] || sd_clk_req_i[0]) // requested
        && !(sd_clk_stall_i[1] || sd_clk_stall_i[0]); // and not stalled

    logic sd_clk_div;
    logic sd_clk_div_last;
    // Divided clock used to generate sd_clk_o
    assign sd_clk_div = clkgen_i[sd_clksel_i];
    // Divided clock used to sample / output data signals
    assign clkstrb_o = sd_clk_div & sd_clk_div_last; 

    always @(posedge clk_i or negedge rstn_i) begin
        if (rstn_i == 1'b0) begin
            sd_clk_o <= 1'b0;
            sd_clk_div_last <= 1'b0;
        end else begin
            if (sd_clk_div == 1'b1) begin
                sd_clk_div_last <= !sd_clk_div_last;
                if (sd_clk_en_o == 1'b1)
                    sd_clk_o <= !sd_clk_o;
                else
                    sd_clk_o <= 1'b0;
            end
        end
    end
endmodule