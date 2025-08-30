module neosd_clk (
    input clk_i,
    input rstn_i,
    input[7:0] clkgen_i,
    input[2:0] sd_clksel_i,

    // Strobe used to sample / emit sd_cmd signals
    output reg clkstrb_o,

    // If we want to have an SD card clock active
    input[2:0] sd_clk_req_i,
    // Whether the clock needs to stall
    input[1:0] sd_clk_stall_i,
    // If the clock actually is active and not stalled
    output sd_clk_en_o,
    // SD CLK wire
    output reg sd_clk_o
);
    // Clock can be needed and stalled by both CMD and DATA FSMs
    assign sd_clk_en_o = (|sd_clk_req_i) // requested
        && !(|sd_clk_stall_i); // and not stalled

    logic sd_clk_strb;
    logic sd_clk_cont;

    // Strobe used to generate sd_clk_o
    assign sd_clk_strb = clkgen_i[sd_clksel_i];

    always @(posedge clk_i or negedge rstn_i) begin
        if (rstn_i == 1'b0) begin
            sd_clk_o <= 1'b0;
            sd_clk_cont <= 1'b0;
        end else begin
            // Divided clock used to sample / output data signals
            clkstrb_o <= sd_clk_strb & sd_clk_cont;

            if (sd_clk_strb == 1'b1) begin
                // Generate this all the time to derive clkstrb_o
                sd_clk_cont <= !sd_clk_cont;
                // The clock to the SD Card is gated
                if (sd_clk_en_o == 1'b1)
                    sd_clk_o <= !sd_clk_cont;
                else
                    sd_clk_o <= 1'b0;
            end
        end
    end
endmodule