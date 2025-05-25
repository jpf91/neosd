module neosd_dat_reg (
    input clk_i,
    // Strobe to obtain the slow SD clock
    input clkstrb_i,
    input rstn_i,

    input[31:0] data_p_i,
    input load_p_i,
    output reg[31:0] data_p_o,

    input data_s_i,
    input shift_s_i,
    output data_s_o
);

    always @(posedge clk_i or negedge rstn_i) begin
        if (rstn_i == 1'b0) begin
            data_p_o <= '1;
        end else begin
            // Load using fast clock
            if (load_p_i != 1'b0) begin
                data_p_o[31:0] <= data_p_i[31:0];
            // Shift using slow clock
            end else if (clkstrb_i == 1'b1 && shift_s_i == 1'b1) begin
                data_p_o <= {data_p_o[30:0], data_s_i};
            end
        end
    end

    assign data_s_o = data_p_o[31];

endmodule