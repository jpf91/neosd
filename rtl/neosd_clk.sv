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

    logic sd_clk_div;
    logic sd_clk_div_last;
    // Divided clock used to generate sd_clk_o
    assign sd_clk_div = clkgen_i[sd_clksel_i];
    // Divided clock used to sample / output data signals
    logic clkstrb_tmp;
    assign clkstrb_tmp = sd_clk_div & sd_clk_div_last; 

    always @(posedge clk_i or negedge rstn_i) begin
        if (rstn_i == 1'b0) begin
            sd_clk_o <= 1'b0;
            sd_clk_div_last <= 1'b0;
        end else begin
            // sd_clk_div_last is delayed one cycle. So delay clkstrb_tmp here to really match falling edge
            clkstrb_o <= clkstrb_tmp;
            if (sd_clk_div == 1'b1) begin
                sd_clk_div_last <= !sd_clk_div_last;
                if (sd_clk_en_o == 1'b1)
                    sd_clk_o <= !sd_clk_div_last;
                else
                    sd_clk_o <= 1'b0;
            end
        end
    end
endmodule