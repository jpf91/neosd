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

    // If we want to have an SD card clock active
    output sd_clk_req_o,
    // If we need to stall the clock, because we're waiting for something
    output sd_clk_stall_o,
    // If the clock actually is active and not stalled
    input sd_clk_en_i,
    // SD DAT wire
    output sd_dat_oe,
    output sd_dat_o,
    input sd_dat_i
);
    logic[31:0] dat_reg_dout;
    logic dat_reg_shift;

    neosd_dat_reg sreg (
        .clk_i(clk_i),
        .clkstrb_i(clkstrb_i),
        .rstn_i(rstn_i),
        .data_p_i(dat_i),
        .load_p_i(dat_load_i),
        .data_p_o(dat_reg_dout),
        .data_s_i(sd_dat_i),
        .shift_s_i(dat_reg_shift),
        .data_s_o(sd_dat_o)
    );

    // FIXME: Support R1b. Figure out this busy bit... Figure 3-9
    typedef enum logic[3:0] {STATE_IDLE, STATE_WAIT_BLOCK, STATE_READ_BLOCK, STATE_REGOUT, STATE_READ_CRC,
        STATE_WRITE_BLOCK, STATE_REGIN, STATE_WRITE_CRC, STATE_WAIT_BUSY, STATE_TAIL} STATE;

    typedef struct packed {
        STATE state;
        logic[5:0] bit_counter;
        logic[8:0] word_counter;
        logic clk_req;
        logic dat_oe;
    } FSM_STATE;
    FSM_STATE dat_fsm_curr;
    FSM_STATE dat_fsm_next;

    assign status_idle_o = dat_fsm_curr.state == STATE_IDLE;
    assign status_data_o = dat_fsm_curr.state == STATE_REGOUT;
    assign dat_o = dat_reg_dout;
    assign dat_reg_shift = sd_clk_en_i && dat_fsm_curr.clk_req;
    assign sd_clk_req_o = dat_fsm_curr.clk_req;
    assign sd_clk_stall_o = 1'b0; // FIXME
    assign sd_dat_oe = dat_fsm_curr.dat_oe;

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
                            dat_fsm_next.clk_req = 0;
                            dat_fsm_next.state = STATE_REGOUT;
                        end else begin
                            dat_fsm_next.bit_counter = dat_fsm_curr.bit_counter + 1;
                        end
                    end
                    STATE_REGOUT: begin
                        if (ctrl_dat_ack_i == 1'b1) begin
                            dat_fsm_next.clk_req = 1'b1;
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
                            dat_fsm_next.clk_req = 0;
                            dat_fsm_next.state = STATE_REGIN;
                        end else begin
                            dat_fsm_next.bit_counter = dat_fsm_curr.bit_counter + 1;
                        end
                    end
                    STATE_REGIN: begin
                        if (ctrl_dat_ack_i == 1'b1) begin
                            // FIXME: Load reg? But i think this is done with external signal
                            dat_fsm_next.clk_req = 1'b1;
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