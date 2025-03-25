module sreg (
    input clk_i,
    input rstn_i,
    input load_p_i,

    input[15:0] data_p_i,
    input data_s_i,

    output reg[15:0] data_p_o,
    output data_s_o
);

    always @(posedge clk_i or negedge rstn_i) begin
        if (rstn_i == 1'b0) begin
            data_p_o <= '0;
        end else begin
            if (load_p_i == 1'b1)
                data_p_o <= data_p_i;
            else
                data_p_o <= {data_p_o[14:0], data_s_i};
        end
    end

    assign data_s_o = data_p_o[15];

endmodule