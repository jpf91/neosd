module neosd_cmd_reg (
    input clk_i,
    // Strobe to obtain the slow SD clock
    input clkstrb_i,
    input rstn_i,

    input[47:0] data_p_i,
    input[5:0] load_p_i,
    output reg[47:0] data_p_o,

    input data_s_i,
    input shift_s_i,
    output data_s_o
);

    always @(posedge clk_i or negedge rstn_i) begin
        if (rstn_i == 1'b0) begin
            data_p_o <= '0;
        end else begin
            // Load using fast clock
            if (load_p_i != '0) begin
                if (load_p_i[0] == 1'b1)
                    data_p_o[7:0] <= data_p_i[7:0];
                if (load_p_i[1] == 1'b1)
                    data_p_o[15:8] <= data_p_i[15:8];
                if (load_p_i[2] == 1'b1)
                    data_p_o[23:16] <= data_p_i[23:16];
                if (load_p_i[3] == 1'b1)
                    data_p_o[31:24] <= data_p_i[31:24];
                if (load_p_i[4] == 1'b1)
                    data_p_o[39:32] <= data_p_i[39:32];
                if (load_p_i[5] == 1'b1)
                    data_p_o[47:40] <= data_p_i[47:40];
            // Shift using slow clock
            end else if (clkstrb_i == 1'b1 && shift_s_i == 1'b1) begin
                data_p_o <= {data_p_o[46:0], data_s_i};
            end
        end
    end

    assign data_s_o = data_p_o[47];

endmodule