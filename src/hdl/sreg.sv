module sreg (
    input clk_i,
    input en_i,
    input rstn_i,
    input load_p_i,

    input[7:0] data_p_i,
    input data_s_i,

    output reg[7:0] data_p_o,
    output data_s_o
);

    always @(posedge clk_i or negedge rstn_i) begin
        if (rstn_i == 1'b0) begin
            data_p_o <= '0;
        end else begin
            if (en_i == 1'b1) begin
                if (load_p_i == 1'b1)
                    data_p_o <= data_p_i;
                else
                    data_p_o <= {data_p_o[6:0], data_s_i};
            end
        end
    end

    assign data_s_o = data_p_o[7];

endmodule