module neosd_cmd_fsm (
    input clk_i,
    input rstn_i,
    // Strobe used to sample / emit sd_cmd signals
    input clkstrb_i,

    // Data load signals
    input[5:0] cmd_idx_i,
    input cmd_idx_load_i,
    input[6:0] cmd_crc_i,
    input cmd_crc_load_i,
    input[31:0] cmd_arg_i,
    input[3:0] cmd_arg_load_i,
    output[31:0] resp_data_o,

    // Status & control
    output status_idle_o,
    output status_resp_o,
    input ctrl_start_i,
    input ctrl_resp_ack_i,
    input[1:0] ctrl_rmode_i,
    input[1:0] ctrl_dmode_i,
    output start_dat_o,

    // If we want to have an SD card clock active
    output sd_clk_req_o,
    // If we need to stall the clock, because we're waiting for something
    output sd_clk_stall_o,
    // If the clock actually is active and not stalled
    input sd_clk_en_i,
    // SD CMD wire
    output sd_cmd_oe,
    output sd_cmd_o,
    input sd_cmd_i
);
    // Transfer on data lines: No data, busy signal flag, read block, write block
    typedef enum logic[1:0] {DATA_NONE, DATA_BUSY, DATA_R, DATA_W} DATA_MODE;

    // Hardwire to wishbone bus but load only if proper address selected
    logic[47:0] cmd_reg_din;
    logic[5:0] cmd_reg_load;
    assign cmd_reg_din = {2'b01, cmd_idx_i, cmd_arg_i, cmd_crc_i, 1'b1};
    assign cmd_reg_load = {cmd_idx_load_i, cmd_arg_load_i, cmd_crc_load_i};

    logic[47:0] cmd_reg_dout;
    logic cmd_reg_shift;

    neosd_cmd_reg sreg (
        .clk_i(clk_i),
        .clkstrb_i(clkstrb_i),
        .rstn_i(rstn_i),
        .data_p_i(cmd_reg_din),
        .load_p_i(cmd_reg_load),
        .data_p_o(cmd_reg_dout),
        .data_s_i(sd_cmd_i),
        .shift_s_i(cmd_reg_shift),
        .data_s_o(sd_cmd_o)
    );

    typedef enum logic[2:0] {STATE_IDLE, STATE_WRITE, STATE_WAIT_RESP, STATE_READ_RESP, STATE_REGOUT, STATE_TAIL} STATE;

    typedef struct packed {
        STATE state;
        logic[5:0] bit_counter;
        logic[2:0] word_counter;
        logic clk_req;
        logic clk_stall;
        logic cmd_oe;
        logic start_dat;
    } FSM_STATE;
    FSM_STATE cmd_fsm_curr;
    FSM_STATE cmd_fsm_next;

    assign status_idle_o = cmd_fsm_curr.state == STATE_IDLE;
    assign status_resp_o = cmd_fsm_curr.state == STATE_REGOUT;
    assign resp_data_o = cmd_reg_dout;
    assign cmd_reg_shift = sd_clk_en_i && cmd_fsm_curr.clk_req;
    assign sd_clk_req_o = cmd_fsm_curr.clk_req;
    assign sd_clk_stall_o = cmd_fsm_curr.clk_stall;
    assign sd_cmd_oe = cmd_fsm_curr.cmd_oe;
    assign start_dat_o = cmd_fsm_curr.start_dat;

    // Expected response: No response, short (? bit, Rx/Ry) response, long (? bit, Rx/Ry) response
    typedef enum logic[1:0] {RESP_NONE, RESP_SHORT, RESP_LONG} RESP_MODE;

    always @(posedge clk_i or negedge rstn_i) begin
        if (rstn_i == 1'b0) begin
            cmd_fsm_curr <= '0;
        end else begin
            if (clkstrb_i == 1'b1) begin
                // State transition logic
                cmd_fsm_next = cmd_fsm_curr;
                // Resets after one cycle, one-shot signal
                cmd_fsm_next.start_dat = 0;
                case (cmd_fsm_curr.state)
                    STATE_IDLE: begin
                        if (ctrl_start_i == 1'b1) begin
                            cmd_fsm_next.state = STATE_WRITE;
                            cmd_fsm_next.bit_counter = 0;
                            cmd_fsm_next.cmd_oe = 1'b1;
                            cmd_fsm_next.clk_req = 1'b1;
                        end
                    end
                    STATE_WRITE: begin
                        if (cmd_fsm_curr.bit_counter == 47) begin
                            cmd_fsm_next.bit_counter = 0;
                            cmd_fsm_next.cmd_oe = 1'b0;

                            // In read commands, data can arrive starting 2 clocks from last CMD bit
                            if (ctrl_dmode_i == DATA_R) begin
                                cmd_fsm_next.start_dat = 1;
                            end

                            case (ctrl_rmode_i)
                                RESP_NONE: begin
                                    cmd_fsm_next.state = STATE_TAIL;
                                    cmd_fsm_next.bit_counter = 0;
                                end
                                RESP_SHORT: begin
                                    cmd_fsm_next.word_counter = 2;
                                    // First register result should only read 16 bit, but 2 are read in
                                    // WAIT_RESP state, which does not advance counter
                                    cmd_fsm_next.bit_counter = 19;
                                    cmd_fsm_next.state = STATE_WAIT_RESP;
                                end
                                RESP_LONG: begin
                                    cmd_fsm_next.word_counter = 5;
                                    // First register result should only read 8 bit, but 2 are read in
                                    // WAIT_RESP state, which does not advance counter
                                    cmd_fsm_next.bit_counter = 27;
                                    cmd_fsm_next.state = STATE_WAIT_RESP;
                                end
                            endcase
                        end else begin
                            cmd_fsm_next.bit_counter = cmd_fsm_curr.bit_counter + 1;
                        end
                    end
                    STATE_WAIT_RESP: begin
                        // Wait for response begin marker 00
                        if (cmd_reg_dout[1:0] == 2'b00) begin
                            cmd_fsm_next.state = STATE_READ_RESP;
                        end
                    end
                    STATE_READ_RESP: begin
                        if (cmd_fsm_curr.bit_counter == 31) begin
                            cmd_fsm_next.bit_counter = 0;
                            cmd_fsm_next.word_counter = cmd_fsm_curr.word_counter - 1;
                            cmd_fsm_next.clk_stall = 1;
                            cmd_fsm_next.state = STATE_REGOUT;
                        end else begin
                            cmd_fsm_next.bit_counter = cmd_fsm_curr.bit_counter + 1;
                        end
                    end
                    STATE_REGOUT: begin
                        if (ctrl_resp_ack_i == 1'b1) begin
                            cmd_fsm_next.clk_stall = 1'b0;
                            cmd_fsm_next.state = STATE_READ_RESP;
                            if (cmd_fsm_next.word_counter == 0) begin
                                // Write blocks at earliest 2 clocks from last response bit
                                // We just assume same ting for busy (R1b), this is not specified
                                if (ctrl_dmode_i == DATA_W || ctrl_dmode_i == DATA_BUSY) begin
                                    cmd_fsm_next.start_dat = 1;
                                end
                                // Even if data FSM kicks in, just go to tail. Both can run parallel
                                cmd_fsm_next.state = STATE_TAIL;
                            end
                        end
                    end
                    STATE_TAIL: begin
                        if (cmd_fsm_curr.bit_counter == 7) begin
                            cmd_fsm_next.clk_req = 1'b0;
                            cmd_fsm_next.state = STATE_IDLE;
                        end else begin
                            cmd_fsm_next.bit_counter = cmd_fsm_curr.bit_counter + 1;
                        end
                    end
                endcase

                cmd_fsm_curr <= cmd_fsm_next;
            end
        end
    end
endmodule