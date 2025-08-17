module neosd_dat_block (
    input clk_i,
    // Strobe to obtain the slow SD clock
    input clkstrb_i,

    // Control signals:
    // Read or write mode
    input ctrl_rnw_i,
    // 4 wire mode
    input ctrl_d4_i,
    // Rotate the registers in 1 bit mode, so input / output is muxed to different regs
    input ctrl_rot_reg_i,
    // Output '0' (0), '1' (1), register data (2) or crc (3). Independent of shift_s_i
    input[1:0] ctrl_omux_i,
    // Make CRC generators output CRC
    input ctrl_output_crc_i,
    // Reset CRC generators
    input ctrl_rstn_crc_i,
    // Clear data registers
    input ctrl_rstn_reg_i,
    // 
    input ctrl_rstn_rot_i,

    input sd_dat0_i,
    input sd_dat1_i,
    input sd_dat2_i,
    input sd_dat3_i,

    output sd_dat0_o,
    output sd_dat1_o,
    output sd_dat2_o,
    output sd_dat3_o,

    // Enable the shift registers
    input shift_s_i,
    output crc_nonzero_o,

    // Data register
    input[31:0] data_p_i,
    input load_p_i,
    output[31:0] data_p_o
);

    // For read mode: The input, either 4 pin or 1 pin
    logic[3:0] reg_data_s_i;
    assign reg_data_s_i[0] = sd_dat0_i;
    assign reg_data_s_i[1] = ctrl_d4_i ? sd_dat1_i : sd_dat0_i;
    assign reg_data_s_i[2] = ctrl_d4_i ? sd_dat2_i : sd_dat0_i;
    assign reg_data_s_i[3] = ctrl_d4_i ? sd_dat3_i : sd_dat0_i;

    // CRC input muxes
    logic[3:0] crc_data_s_i;
    assign crc_data_s_i[0] = ctrl_rnw_i ? reg_data_s_i[0] : sd_dat0_o;
    assign crc_data_s_i[1] = ctrl_rnw_i ? reg_data_s_i[1] : sd_dat1_o;
    assign crc_data_s_i[2] = ctrl_rnw_i ? reg_data_s_i[2] : sd_dat2_o;
    assign crc_data_s_i[3] = ctrl_rnw_i ? reg_data_s_i[3] : sd_dat3_o;

    // In read mode: if 1 pin mode, reg should read only read every 4th element
    logic[1:0] reg_active_n;
    always @(posedge clk_i or negedge ctrl_rstn_rot_i) begin
        if (ctrl_rstn_rot_i == 1'b0) begin
            reg_active_n <= 2'd3;
        end else begin
            if (clkstrb_i == 1'b1 && shift_s_i == 1'b1 && ctrl_rot_reg_i == 1'b1) begin
                reg_active_n <= reg_active_n - 1;
            end
        end
    end
    // In read mode: Gate the shift enable accordingly
    logic[3:0] reg_shift_s_i;
    assign reg_shift_s_i[0] = shift_s_i && ((reg_active_n == 0) || ctrl_d4_i);
    assign reg_shift_s_i[1] = shift_s_i && ((reg_active_n == 1) || ctrl_d4_i);
    assign reg_shift_s_i[2] = shift_s_i && ((reg_active_n == 2) || ctrl_d4_i);
    assign reg_shift_s_i[3] = shift_s_i && ((reg_active_n == 3) || ctrl_d4_i);

    // CRC result in read: In D4 mode, check all CRCs
    // In D0, all CRCs get the same data, so can or as well
    logic[3:0] crc_nonzero;
    assign crc_nonzero_o = |crc_nonzero;

    logic[7:0] reg_data_p_i[3:0];
    logic[7:0] reg_data_p_o[3:0];
    logic[3:0] reg_data_s_o, mux_data_s_o, crc_data_s_o;

    genvar i, j;
    generate
        for (i = 0; i < 4; i = i + 1) begin: regs
            neosd_dat_reg regi (
                .clk_i(clk_i),
                .clkstrb_i(clkstrb_i),
                .rstn_i(ctrl_rstn_reg_i),
                .data_p_i(reg_data_p_i[i]),
                .load_p_i(load_p_i),
                .data_p_o(reg_data_p_o[i]),
                .data_s_i(reg_data_s_i[i]),
                .shift_s_i(reg_shift_s_i[i]),
                .data_s_o(reg_data_s_o[i])
            );
            neosd_dat_crc crci (
                .clk_i(clk_i),
                .clkstrb_i(clkstrb_i),
                .rstn_i(ctrl_rstn_crc_i),
                .data_s_i(crc_data_s_i[i]),
                .shift_s_i(shift_s_i),
                .output_s_i(ctrl_output_crc_i),
                .data_s_o(crc_data_s_o[i]),
                .nonzero_o(crc_nonzero[i])
            );

            // Properly assign the reg_data_p_i/o for all registers
            for (j = 0; j < 8; j++) begin
                    assign reg_data_p_i[i][j] = data_p_i[j*4 + i];
                    assign data_p_o[j*4 + i] = reg_data_p_o[i][j];
            end

            // Output multiplexers
            assign mux_data_s_o[i] = (ctrl_omux_i == 2'b00) ? 1'b0 :
                                     (ctrl_omux_i == 2'b01) ? 1'b1 :
                                     (ctrl_omux_i == 2'b10) ? reg_data_s_o[i] :
                                     crc_data_s_o[i];
        end
    endgenerate

    // Drive outputs from muxes. dat0 in D0 mode muxes from all regs, but CRC output is always 0
    assign sd_dat0_o = mux_data_s_o[reg_active_n & {2{!ctrl_d4_i & (ctrl_omux_i != 2'b11)}}];
    assign sd_dat1_o = mux_data_s_o[1];
    assign sd_dat2_o = mux_data_s_o[2];
    assign sd_dat3_o = mux_data_s_o[3];

endmodule