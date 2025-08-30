module neosd_dat_fsm (
    input clk_i,
    input rstn_i,
    // Strobe used to sample / emit sd_cmd signals
    input clkstrb_i,
    input fsm_rst_i,

    // Data load signals
    input[31:0] dat_i,
    input dat_load_i,
    output[31:0] dat_o,

    // Status & control
    output status_idle_o,
    output status_data_o,
    output status_block_done_o,
    output status_crc_ok_o,
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
    output[3:0] sd_dat_o,
    input[3:0] sd_dat_i,
    output[3:0] sd_dat_oe
);

    logic block_crc_nonzero, block_rstn_i, block_shift_s;
    logic[31:0] block_data_pi, block_data_po;

    logic[2:0] crc_token;
    assign crc_token[0] = block_data_po[4];
    assign crc_token[1] = block_data_po[8];
    assign crc_token[2] = block_data_po[12];

    // Properly assign the block_data_pi/o: BE / LE swap
    genvar i, j;
    generate
      for (i = 0; i < 4; i = i + 1) begin: regs
        assign block_data_pi[(i+1)*8-1:i*8] = dat_i[(3-i+1)*8-1:(3-i)*8];
        assign dat_o[(i+1)*8-1:i*8] = block_data_po[(3-i+1)*8-1:(3-i)*8];
      end
    endgenerate

    logic block_ctrl_rnw, block_ctrl_rot_reg, block_ctrl_output_crc, block_ctrl_rstn_crc, block_ctrl_rstn_reg, block_ctrl_rstn_rot;
    logic[1:0] block_ctrl_omux;

    neosd_dat_block block (
        .clk_i(clk_i),
        .clkstrb_i(clkstrb_i),

        .ctrl_rnw_i(block_ctrl_rnw),
        .ctrl_d4_i(ctrl_d4_i),
        .ctrl_rot_reg_i(block_ctrl_rot_reg),
        .ctrl_omux_i(block_ctrl_omux),
        .ctrl_output_crc_i(block_ctrl_output_crc),
        .ctrl_rstn_crc_i(block_ctrl_rstn_crc),
        .ctrl_rstn_reg_i(block_ctrl_rstn_reg),
        .ctrl_rstn_rot_i(block_ctrl_rstn_rot),

        .sd_dat_i(sd_dat_i),
        .sd_dat_o(sd_dat_o),

        .shift_s_i(block_shift_s),
        .crc_nonzero_o(block_crc_nonzero),
        .data_p_i(block_data_pi),
        .load_p_i(dat_load_i),
        .data_p_o(block_data_po)
    );

    typedef enum logic[3:0] {STATE_IDLE, STATE_WAIT_BLOCK, STATE_READ_BLOCK, STATE_REGOUT, STATE_READ_CRC, STATE_READ_FINISH,
        STATE_TAIL, STATE_WAIT_BUSY,
        STATE_WRITE_START, STATE_WRITE_DATA, STATE_WRITE_REGIN, STATE_WRITE_CRC, STATE_WRITE_STOP, STATE_WRITE_CHECK_CRC, STATE_WRITE_BUSY, STATE_WRITE_TAIL} STATE;

    typedef struct packed {
        STATE state;
        logic[5:0] bit_counter;
        logic[8:0] word_counter;
        logic clk_req;
        logic clk_stall;
        logic dat_oe;
        logic block_ctrl_rnw, block_ctrl_rot_reg, block_ctrl_output_crc, block_ctrl_rstn_crc, block_ctrl_rstn_reg, block_shift_s, block_ctrl_rstn_rot;
        logic[1:0] block_ctrl_omux;
        logic crc_ok, block_done;
        logic write_start;
    } FSM_STATE;
    FSM_STATE dat_fsm_curr;
    FSM_STATE dat_fsm_next;

    // Debug only signals
    STATE dbg_state;
    assign dbg_state = dat_fsm_curr.state;
    logic[5:0] dbg_bit_counter;
    assign dbg_bit_counter = dat_fsm_curr.bit_counter;
    logic[8:0] dbg_word_counter;
    assign dbg_word_counter = dat_fsm_curr.word_counter;

    assign status_idle_o = dat_fsm_curr.state == STATE_IDLE;
    assign status_data_o = dat_fsm_curr.state == STATE_REGOUT || dat_fsm_curr.state == STATE_WRITE_REGIN;

    assign sd_clk_req_o = dat_fsm_curr.clk_req;
    assign sd_clk_stall_o = dat_fsm_curr.clk_stall;

    assign sd_dat_oe[0] = dat_fsm_curr.dat_oe;
    assign sd_dat_oe[1] = dat_fsm_curr.dat_oe & ctrl_d4_i;
    assign sd_dat_oe[2] = dat_fsm_curr.dat_oe & ctrl_d4_i;
    assign sd_dat_oe[3] = dat_fsm_curr.dat_oe & ctrl_d4_i;

    assign status_crc_ok_o = dat_fsm_curr.crc_ok;
    assign status_block_done_o = dat_fsm_curr.block_done;

    assign block_shift_s = sd_clk_en_i && dat_fsm_curr.block_shift_s;

    assign block_ctrl_rnw = dat_fsm_curr.block_ctrl_rnw;
    assign block_ctrl_rot_reg = dat_fsm_curr.block_ctrl_rot_reg; 
    assign block_ctrl_output_crc = dat_fsm_curr.block_ctrl_output_crc; 
    assign block_ctrl_rstn_crc = dat_fsm_curr.block_ctrl_rstn_crc;
    assign block_ctrl_rstn_reg = dat_fsm_curr.block_ctrl_rstn_reg;
    assign block_ctrl_omux = dat_fsm_curr.block_ctrl_omux;
    assign block_ctrl_rstn_rot = dat_fsm_curr.block_ctrl_rstn_rot;

    // Transfer on data lines: No data, busy signal flag, read block, write block
    typedef enum logic[1:0] {DATA_NONE, DATA_BUSY, DATA_R, DATA_W} DATA_MODE;

    always @(posedge clk_i or negedge rstn_i) begin
        if (rstn_i == 1'b0) begin
            dat_fsm_curr <= '0;
        end else begin
            if (clkstrb_i == 1'b1) begin
                // State transition logic
                dat_fsm_next = dat_fsm_curr;
                // Strobe signal
                dat_fsm_next.block_done = 1'b0;

                case (dat_fsm_curr.state)
                    STATE_IDLE: begin
                        if (ctrl_start_i == 1'b1) begin
                            case (ctrl_dmode_i)
                                DATA_NONE: begin
                                    // Do nothing
                                end
                                DATA_R: begin
                                    dat_fsm_next.clk_req = 1'b1;
                                    dat_fsm_next.block_ctrl_rnw = 1'b1;
                                    dat_fsm_next.block_shift_s = 1'b1;
                                    dat_fsm_next.block_ctrl_rstn_reg = 1'b1;
                                    dat_fsm_next.block_ctrl_rstn_rot = 1'b1;
                                    dat_fsm_next.state = STATE_WAIT_BLOCK;
                                end
                                DATA_BUSY: begin
                                    dat_fsm_next.clk_req = 1'b1;
                                    dat_fsm_next.state = STATE_WAIT_BUSY;
                                end
                                DATA_W: begin
                                    dat_fsm_next.write_start = 1'b1;
                                    dat_fsm_next.block_ctrl_rnw = 1'b0;
                                    dat_fsm_next.clk_req = 1'b1;
                                    // Technically, we don't necessarily have to stall here
                                    dat_fsm_next.clk_stall = 1'b1;
                                    dat_fsm_next.block_ctrl_rstn_reg = 1'b1;
                                    dat_fsm_next.state = STATE_WRITE_REGIN;
                                end
                            endcase
                        end
                    end
                    STATE_WAIT_BLOCK: begin
                        // Wait for block begin marker 0
                        if ((sd_clk_en_i == 1'b1) && (sd_dat_i[0] == 1'b0)) begin
                            dat_fsm_next.state = STATE_READ_BLOCK;
                            dat_fsm_next.block_ctrl_rstn_crc = 1'b1;
                            dat_fsm_next.block_ctrl_rot_reg = 1'b1;
                            dat_fsm_next.bit_counter = 0;
                            dat_fsm_next.word_counter = 128;
                        end
                    end
                    STATE_READ_BLOCK: begin
                        // Only count, if not stalled
                        if (sd_clk_en_i == 1'b1) begin
                            if (dat_fsm_curr.bit_counter == (ctrl_d4_i == 1'b1 ? 7 : 31)) begin
                                dat_fsm_next.bit_counter = 0;
                                dat_fsm_next.word_counter = dat_fsm_curr.word_counter - 1;
                                dat_fsm_next.clk_stall = 1;
                                dat_fsm_next.state = STATE_REGOUT;
                            end else begin
                                dat_fsm_next.bit_counter = dat_fsm_curr.bit_counter + 1;
                            end
                        end
                    end
                    STATE_REGOUT: begin
                        if (ctrl_dat_ack_i == 1'b1) begin
                            dat_fsm_next.clk_stall = 1'b0;
                            dat_fsm_next.state = STATE_READ_BLOCK;
                            dat_fsm_next.bit_counter = 0;
                            if (dat_fsm_next.word_counter == 0) begin
                                dat_fsm_next.state = STATE_READ_CRC;
                            end
                        end
                    end
                    STATE_READ_CRC: begin
                        // Only read, if not stalled
                        if (sd_clk_en_i == 1'b1) begin
                            if (dat_fsm_curr.bit_counter == 15) begin
                                // Not so nice, but stall 1 CLK here so we can report & reset CRC reg
                                dat_fsm_next.clk_stall = 1'b1;
                                dat_fsm_next.block_ctrl_rstn_reg = 1'b0;
                                dat_fsm_next.block_ctrl_rstn_rot = 1'b0;
                                dat_fsm_next.state = STATE_READ_FINISH;
                            end else begin
                                dat_fsm_next.bit_counter = dat_fsm_curr.bit_counter + 1;
                            end
                        end
                    end
                    STATE_READ_FINISH: begin
                        dat_fsm_next.bit_counter = 0;
                        dat_fsm_next.block_ctrl_rstn_crc = 1'b0;
                        dat_fsm_next.block_ctrl_rstn_reg = 1'b1;
                        dat_fsm_next.clk_stall = 1'b0;
                        dat_fsm_next.block_ctrl_rstn_rot = 1'b1;
                        dat_fsm_next.block_ctrl_rot_reg = 1'b0;

                        // Report CRC status
                        dat_fsm_next.crc_ok = !block_crc_nonzero;
                        dat_fsm_next.block_done = 1'b1;
                        dat_fsm_next.state = STATE_WAIT_BLOCK;
                    end
                    STATE_TAIL: begin
                        // Only count, if not stalled
                        if (sd_clk_en_i == 1'b1) begin
                            if (dat_fsm_curr.bit_counter == 7) begin
                                dat_fsm_next.clk_req = 1'b0;
                                dat_fsm_next.state = STATE_IDLE;
                            end else begin
                                dat_fsm_next.bit_counter = dat_fsm_curr.bit_counter + 1;
                            end
                        end
                    end
                    STATE_WAIT_BUSY: begin
                        // Wait for line high
                        if ((sd_clk_en_i == 1'b1) && (sd_dat_i[0] == 1'b1)) begin
                            dat_fsm_next.state = STATE_TAIL;
                            dat_fsm_next.bit_counter = 0;
                        end
                    end
                    STATE_WRITE_REGIN: begin
                        if (ctrl_dat_ack_i == 1'b1) begin
                            dat_fsm_next.clk_stall = 1'b0;
                            dat_fsm_next.bit_counter = 0;
                            
                            if (dat_fsm_next.write_start == 1'b1) begin
                                dat_fsm_next.block_ctrl_omux = 2'b00;
                                dat_fsm_next.dat_oe = 1'b1;
                                dat_fsm_next.state = STATE_WRITE_START;
                            end else begin
                                dat_fsm_next.state = STATE_WRITE_DATA;
                            end
                        end
                    end
                    STATE_WRITE_START: begin
                        // Only continue, if not stalled
                        if (sd_clk_en_i == 1'b1) begin
                            dat_fsm_next.state = STATE_WRITE_DATA;
                            dat_fsm_next.write_start = 1'b0;
                            dat_fsm_next.block_ctrl_omux = 2'b10;
                            dat_fsm_next.block_shift_s = 1'b1;
                            dat_fsm_next.word_counter = 128;
                            dat_fsm_next.block_ctrl_rstn_crc = 1'b1;
                            dat_fsm_next.block_ctrl_rstn_rot = 1'b1;
                            dat_fsm_next.block_ctrl_rot_reg = 1'b1;
                        end
                    end
                    STATE_WRITE_DATA: begin
                        // Only count, if not stalled
                        if (sd_clk_en_i == 1'b1) begin
                            if (dat_fsm_curr.bit_counter == (ctrl_d4_i == 1'b1 ? 7 : 31)) begin
                                dat_fsm_next.bit_counter = 0;
                                dat_fsm_next.word_counter = dat_fsm_curr.word_counter - 1;
                                if (dat_fsm_curr.word_counter == 1) begin
                                    dat_fsm_next.block_ctrl_omux = 2'b11;
                                    dat_fsm_next.block_ctrl_output_crc = 1'b1;
                                    dat_fsm_next.state = STATE_WRITE_CRC;
                                end else begin
                                    dat_fsm_next.clk_stall = 1;
                                    dat_fsm_next.state = STATE_WRITE_REGIN;
                                end
                            end else begin
                                dat_fsm_next.bit_counter = dat_fsm_curr.bit_counter + 1;
                            end
                        end
                    end
                    STATE_WRITE_CRC: begin
                        // Only count, if not stalled
                        if (sd_clk_en_i == 1'b1) begin
                            dat_fsm_next.bit_counter = dat_fsm_curr.bit_counter + 1;
                            if (dat_fsm_curr.bit_counter == 14) begin
                                dat_fsm_next.block_ctrl_rot_reg = 1'b0;
                            end else if (dat_fsm_curr.bit_counter == 15) begin
                                dat_fsm_next.bit_counter = 0;
                                dat_fsm_next.block_ctrl_omux = 2'b01;
                                dat_fsm_next.block_ctrl_output_crc = 1'b0;
                                dat_fsm_next.state = STATE_WRITE_STOP;
                            end
                        end
                    end
                    STATE_WRITE_STOP: begin
                        // Only continue, if not stalled
                        if (sd_clk_en_i == 1'b1) begin
                            dat_fsm_next.state = STATE_WRITE_CHECK_CRC;
                            dat_fsm_next.dat_oe = 1'b0;
                        end
                    end
                    STATE_WRITE_CHECK_CRC: begin
                        // Only continue, if not stalled
                        if (sd_clk_en_i == 1'b1) begin
                            if (dat_fsm_curr.bit_counter == 6) begin
                                dat_fsm_next.bit_counter = 0;
                                dat_fsm_next.write_start = 1'b1;
                                dat_fsm_next.block_shift_s = 1'b0;
                                dat_fsm_next.block_ctrl_rstn_crc = 1'b0;
                                dat_fsm_next.block_ctrl_rstn_reg = 1'b0;
                                dat_fsm_next.block_ctrl_rstn_rot = 1'b0;

                                dat_fsm_next.crc_ok = crc_token == 3'b010; 

                                dat_fsm_next.state = STATE_WRITE_BUSY;
                            end else begin
                                dat_fsm_next.bit_counter = dat_fsm_curr.bit_counter + 1;
                            end
                        end
                    end
                    STATE_WRITE_BUSY: begin
                        // Only continue, if not stalled
                        if ((sd_clk_en_i == 1'b1) && (sd_dat_i[0] == 1'b1)) begin
                            dat_fsm_next.block_done = 1'b1;
                            dat_fsm_next.state = STATE_WRITE_TAIL;
                        end
                    end
                    STATE_WRITE_TAIL: begin
                        // Only continue, if not stalled
                        if (sd_clk_en_i == 1'b1) begin
                            if (dat_fsm_curr.bit_counter == 7) begin
                                dat_fsm_next.bit_counter = 0;
                                dat_fsm_next.clk_stall = 1'b1;
                                dat_fsm_next.block_ctrl_rstn_reg = 1'b1;
                                dat_fsm_next.state = STATE_WRITE_REGIN;
                            end else begin
                                dat_fsm_next.bit_counter = dat_fsm_curr.bit_counter + 1;
                            end
                        end
                    end
                    default: begin

                    end
                endcase

                // Abort
                if (dat_fsm_curr.state != STATE_IDLE &&
                    dat_fsm_curr.state != STATE_TAIL &&
                    ctrl_last_block_i == 1'b1) begin
                    
                    dat_fsm_next.block_ctrl_rstn_crc = 1'b0;
                    dat_fsm_next.block_ctrl_rstn_reg = 1'b0;
                    dat_fsm_next.block_ctrl_rot_reg = 1'b0;
                    dat_fsm_next.block_ctrl_rstn_rot = 1'b0;
                    dat_fsm_next.block_shift_s = 1'b0;
                    dat_fsm_next.clk_stall = 1'b0;

                    dat_fsm_next.bit_counter = 0;
                    dat_fsm_next.state = STATE_TAIL;
                end

                if (fsm_rst_i == 1'b1)
                    dat_fsm_curr <= '0;
                else
                    dat_fsm_curr <= dat_fsm_next;
            end
        end
    end
endmodule