module neosd_clken(
  input  wire clk_i,
  input  wire rstn_i,
  input  wire enable_i,
  output reg  [7:0] clk_en_o
);

  reg [11:0] cnt, cnt2;

  always @(posedge clk_i or negedge rstn_i) begin
    if (!rstn_i) begin
      cnt  <= 12'b0;
      cnt2 <= 12'b0;
    end else begin
      if (enable_i)
        cnt <= cnt + 1;
      else
        cnt <= 12'b0;
      cnt2 <= cnt;
    end
  end

  // Clock enables: rising edge detectors
  always @(*) begin
    clk_en_o[0] = cnt[0]  & ~cnt2[0];  // clk_i / 2
    clk_en_o[1] = cnt[1]  & ~cnt2[1];  // clk_i / 4
    clk_en_o[2] = cnt[2]  & ~cnt2[2];  // clk_i / 8
    clk_en_o[3] = cnt[5]  & ~cnt2[5];  // clk_i / 64
    clk_en_o[4] = cnt[6]  & ~cnt2[6];  // clk_i / 128
    clk_en_o[5] = cnt[9]  & ~cnt2[9];  // clk_i / 1024
    clk_en_o[6] = cnt[10] & ~cnt2[10]; // clk_i / 2048
    clk_en_o[7] = cnt[11] & ~cnt2[11]; // clk_i / 4096
  end

endmodule