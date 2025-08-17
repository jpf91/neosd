module neosd_dat_fsm (
    input clk_i,
    input rstn_i,
    // Strobe used to sample / emit sd_cmd signals
    input clkstrb_i,

    // Data load signals
    input[31:0] dat_i,
    input dat_load_i,
    output[31:0] dat_o,

    // Status & control
    output status_idle_o,
    output status_data_o,
    input ctrl_start_i,
    input ctrl_dat_ack_i,
    input ctrl_last_block_i,
    input[1:0] ctrl_dmode_i,
    input ctrl_d4_i,

    // If we want to have an SD card clock active
    output sd_clk_req_o,
    // If we need to stall the clock, because we're waiting for something
    output sd_clk_stall_o,
    // If the clock actually is active and not stalled
    input sd_clk_en_i,
    // SD DAT wire
    output sd_dat0_oe,
    output sd_dat1_oe,
    output sd_dat2_oe,
    output sd_dat3_oe,
    output sd_dat0_o,
    output sd_dat1_o,
    output sd_dat2_o,
    output sd_dat3_o,
    input sd_dat0_i,
    input sd_dat1_i,
    input sd_dat2_i,
    input sd_dat3_i
);

    logic block_ctrl_rnw, block_ctrl_rot_reg, block_ctrl_omux, block_ctrl_output_crc;
    logic block_shift_s, block_crc_nonzero;
    logic[31:0] block_data_pi, block_data_po;
    logic block_d0_bit0;

    // Properly assign the block_data_pi/o: BE / LE swap
    genvar i, j;
    generate
      for (i = 0; i < 4; i = i + 1) begin: regs
        assign block_data_pi[(i+1)*8-1:i*8] = dat_i[(3-i+1)*8-1:(3-i)*8];
        assign dat_o[(i+1)*8-1:i*8] = block_data_po[(3-i+1)*8-1:(3-i)*8];
      end
    endgenerate
    assign block_d0_bit0 = block_data_po[0];

    neosd_dat_block block (
        .clk_i(clk_i),
        .clkstrb_i(clkstrb_i),
        .rstn_i(rstn_i),

        .ctrl_rnw_i(block_ctrl_rnw),
        .ctrl_d4_i(ctrl_d4_i),
        .ctrl_rot_reg_i(block_ctrl_rot_reg),
        .ctrl_omux_i(block_ctrl_omux),
        .ctrl_output_crc_i(block_ctrl_output_crc),

        .sd_dat0_i(sd_dat0_i),
        .sd_dat1_i(sd_dat1_i),
        .sd_dat2_i(sd_dat2_i),
        .sd_dat3_i(sd_dat3_i),
        .sd_dat0_o(sd_dat0_o),
        .sd_dat1_o(sd_dat1_o),
        .sd_dat2_o(sd_dat2_o),
        .sd_dat3_o(sd_dat3_o),

        .shift_s_i(block_shift_s),
        .crc_nonzero_o(block_crc_nonzero),
        .data_p_i(block_data_pi),
        .load_p_i(dat_load_i),
        .data_p_o(block_data_po)
    );

    typedef enum logic[3:0] {STATE_IDLE, STATE_WAIT_BLOCK, STATE_READ_BLOCK, STATE_REGOUT, STATE_READ_CRC,
        STATE_WRITE_BLOCK, STATE_REGIN, STATE_WRITE_CRC, STATE_WAIT_BUSY, STATE_TAIL} STATE;

    typedef struct packed {
        STATE state;
        logic[5:0] bit_counter;
        logic[8:0] word_counter;
        logic clk_req;
        logic clk_stall;
        logic dat_oe;
    } FSM_STATE;
    FSM_STATE dat_fsm_curr;
    FSM_STATE dat_fsm_next;

    // TODO: Remove
    STATE dbg_state;
    assign dbg_state = dat_fsm_curr.state;

    assign status_idle_o = dat_fsm_curr.state == STATE_IDLE;
    assign status_data_o = dat_fsm_curr.state == STATE_REGOUT;

    // FIXME
    assign dat_reg_shift = sd_clk_en_i && dat_fsm_curr.clk_req;

    assign sd_clk_req_o = dat_fsm_curr.clk_req;
    assign sd_clk_stall_o = dat_fsm_curr.clk_stall;

    assign sd_dat0_oe = dat_fsm_curr.dat_oe;
    assign sd_dat1_oe = dat_fsm_curr.dat_oe & ctrl_d4_i;
    assign sd_dat2_oe = dat_fsm_curr.dat_oe & ctrl_d4_i;
    assign sd_dat3_oe = dat_fsm_curr.dat_oe & ctrl_d4_i;

    // Transfer on data lines: No data, busy signal flag, read block, write block
    typedef enum logic[1:0] {DATA_NONE, DATA_BUSY, DATA_R, DATA_W} DATA_MODE;

    always @(posedge clk_i or negedge rstn_i) begin
        if (rstn_i == 1'b0) begin
            dat_fsm_curr <= '0;
        end else begin
            if (clkstrb_i == 1'b1) begin
                // State transition logic
                dat_fsm_next = dat_fsm_curr;
                case (dat_fsm_curr.state)
                    STATE_IDLE: begin
                        if (ctrl_start_i == 1'b1) begin
                            case (ctrl_dmode_i)
                                DATA_NONE: begin
                                    // Do nothing
                                    dat_fsm_next.state = STATE_IDLE;
                                end
                                DATA_BUSY: begin
                                    dat_fsm_next.state = STATE_WAIT_BUSY;
                                    dat_fsm_next.clk_req = 1'b1;
                                end
                                DATA_R: begin
                                    dat_fsm_next.clk_req = 1'b1;
                                    dat_fsm_next.word_counter = 511;
                                    dat_fsm_next.bit_counter = 0;
                                    dat_fsm_next.state = STATE_WAIT_BLOCK;
                                end
                                DATA_W: begin
                                    dat_fsm_next.dat_oe = 1'b1;
                                    dat_fsm_next.clk_req = 1'b1;
                                    dat_fsm_next.word_counter = 511;
                                    dat_fsm_next.bit_counter = 0;
                                    dat_fsm_next.state = STATE_WRITE_BLOCK;
                                end
                            endcase
                        end
                    end
                    STATE_WAIT_BLOCK: begin
                        // Wait for block begin marker 0
                        if (dat_reg_dout[0] == 1'b0) begin
                            dat_fsm_next.state = STATE_READ_BLOCK;
                        end
                    end
                    STATE_READ_BLOCK: begin
                        if (dat_fsm_curr.bit_counter == 31) begin
                            dat_fsm_next.bit_counter = 0;
                            dat_fsm_next.word_counter = dat_fsm_curr.word_counter - 1;
                            dat_fsm_next.clk_stall = 1;
                            dat_fsm_next.state = STATE_REGOUT;
                        end else begin
                            dat_fsm_next.bit_counter = dat_fsm_curr.bit_counter + 1;
                        end
                    end
                    STATE_REGOUT: begin
                        if (ctrl_dat_ack_i == 1'b1) begin
                            dat_fsm_next.clk_stall = 1'b0;
                            dat_fsm_next.state = STATE_READ_BLOCK;
                            if (dat_fsm_next.word_counter == 0) begin
                                dat_fsm_next.state = STATE_READ_CRC;
                            end
                        end
                    end
                    STATE_READ_CRC: begin
                        // FIXME
                        dat_fsm_next.bit_counter = 0;
                        if (ctrl_last_block_i == 1'b1) begin
                            dat_fsm_next.state = STATE_TAIL;
                        end else begin
                            dat_fsm_next.state = STATE_READ_BLOCK;
                        end
                    end
                    STATE_WRITE_BLOCK: begin
                        if (dat_fsm_curr.bit_counter == 31) begin
                            dat_fsm_next.bit_counter = 0;
                            dat_fsm_next.word_counter = dat_fsm_curr.word_counter - 1;
                            dat_fsm_next.clk_stall = 1'b1;
                            dat_fsm_next.state = STATE_REGIN;
                        end else begin
                            dat_fsm_next.bit_counter = dat_fsm_curr.bit_counter + 1;
                        end
                    end
                    STATE_REGIN: begin
                        if (ctrl_dat_ack_i == 1'b1) begin
                            dat_fsm_next.clk_stall = 1'b0;
                            dat_fsm_next.state = STATE_WRITE_BLOCK;
                            if (dat_fsm_next.word_counter == 0) begin
                                dat_fsm_next.state = STATE_WRITE_CRC;
                            end
                        end
                    end
                    STATE_WRITE_CRC: begin
                        //FIXME Note: End bit after CRC
                        dat_fsm_next.state = STATE_WAIT_BUSY;
                    end
                    STATE_WAIT_BUSY: begin
                        // Busy = 0 bit
                        if (dat_reg_dout[0] == 1'b1) begin
                            dat_fsm_next.bit_counter = 0;
                            if (ctrl_last_block_i == 1'b1) begin
                                dat_fsm_next.state = STATE_TAIL;
                            end else begin
                                dat_fsm_next.state = STATE_WRITE_BLOCK;
                            end
                        end
                    end
                    STATE_TAIL: begin
                        if (dat_fsm_curr.bit_counter == 7) begin
                            dat_fsm_next.clk_req = 1'b0;
                            dat_fsm_next.state = STATE_IDLE;
                        end else begin
                            dat_fsm_next.bit_counter = dat_fsm_curr.bit_counter + 1;
                        end
                    end
                endcase

                dat_fsm_curr <= dat_fsm_next;
            end
        end
    end
endmodule