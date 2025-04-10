module neosd (
    input clk_i,
    input rstn_i,
    input[7:0] clkgen_i,

    input[31:0] wb_adr_i,
    input[31:0] wb_dat_i,
    input wb_we_i,
    input[3:0] wb_sel_i,
    input wb_stb_i,
    input wb_cyc_i,

    output reg wb_ack_o,
    output wb_err_o,
    output reg[31:0] wb_dat_o,

    // SD Card Signals
    output reg sd_clk_o,
    output reg sd_cmd_o,
    input sd_cmd_i,
    output reg sd_cmd_oe,
    output sd_dat0_o,
    input sd_dat0_i,
    output sd_dat0_oe
);

    // Control and status registers
    struct packed {
        logic[2:0] CDIV;
        logic ABRT;
        logic RST;
        logic EN;
    } NEOSD_CTRL_REG;

    struct packed {
        logic dummy;
    } NEOSD_STAT_REG;

    // Interrupt registers
    typedef struct packed {
        logic IRQ_CMD_DONE;
    } IRQ_SET;

    IRQ_SET NEOSD_IRQ_FLAG_REG;
    IRQ_SET NEOSD_IRQ_MASK_REG;


    // SD Command Registers
    logic[31:0] NEOSD_CMDARG_REG;

    // Expected response: No response, short (? bit, Rx/Ry) response, long (? bit, Rx/Ry) response
    typedef enum logic[1:0] {RESP_NONE, RESP_SHORT, RESP_LONG} RESP_MODE;
    // Transfer on data lines: No data, busy signal flag, read block, write block
    typedef enum logic[1:0] {DATA_NONE, DATA_BUSY, DATA_R, DATA_W} DATA_MODE;

    struct packed {
        logic[5:0] IDX;
        logic[6:0] CRC;
        RESP_MODE RMODE; // 2 bit
        DATA_MODE DMODE; // 2 bit
        logic LAST_BLOCK;
        logic COMMIT;
    } NEOSD_CMD_REG;


    // SD Response registers
    logic[31:0] NEOSD_RESP0_REG;
    logic[31:0] NEOSD_RESP1_REG;
    logic[31:0] NEOSD_RESP2_REG;
    logic[31:0] NEOSD_RESP3_REG;
    logic[7:0] NEOSD_RESP4_REG;

    // SD Data Register (R/W)
    logic[31:0] NEOSD_DATA_REG;


    // Wishbone code based on https://zipcpu.com/zipcpu/2017/05/29/simple-wishbone.html
    wire wb_stall_o;


    logic sd_clk_div2;
    logic sd_status_cmd_done;

    // Wishbone Write Logic
    always @(posedge clk_i or negedge rstn_i) begin
        if (rstn_i == 1'b0) begin
            NEOSD_CTRL_REG <= '0;
            NEOSD_STAT_REG <= '0; // FIXME: STAT_DISABLED
            NEOSD_IRQ_FLAG_REG <= '0;
            NEOSD_IRQ_MASK_REG <= '0;
            // NEOSD_CMDARG_REG: Don't initialize
            NEOSD_CMD_REG <= '0; // Initialize only commit bit
            // NEOSD_RESP0_REG: Don't initialize
            // NEOSD_RESP1_REG: Don't initialize
            // NEOSD_RESP2_REG: Don't initialize
            // NEOSD_RESP3_REG: Don't initialize
            // NEOSD_RESP4_REG: Don't initialize
            // NEOSD_DATA_REG: Don't initialize
        end else begin
            // Flag auto-resets after CMD FSM read it
            if (sd_clk_div2 == 1'b1) begin
                NEOSD_CMD_REG.COMMIT <= 1'b0;
                if (sd_status_cmd_done == 1'b1)
                    NEOSD_IRQ_FLAG_REG.IRQ_CMD_DONE <= 1'b1;
            end

            if (wb_stb_i && wb_we_i && !wb_stall_o) begin
                case (wb_adr_i[7:0])
                    8'h00:
                        NEOSD_CTRL_REG <= wb_dat_i[$bits(NEOSD_CTRL_REG):0];
                    8'h04: begin
                        // NEOSD_STAT_REG is read-only
                    end
                    8'h08: // TODO: Write 1 to clear? What does neorv do?
                        NEOSD_IRQ_FLAG_REG <= wb_dat_i[$bits(NEOSD_IRQ_FLAG_REG):0];
                    8'h0C:
                        NEOSD_IRQ_MASK_REG <= wb_dat_i[$bits(NEOSD_IRQ_MASK_REG):0];
                    8'h10:
                        NEOSD_CMDARG_REG <= wb_dat_i[31:0];
                    8'h14:
                        NEOSD_CMD_REG <= wb_dat_i[$bits(NEOSD_CMD_REG):0];
                    8'h18: begin
                        // NEOSD_RESP0_REG is read-only
                    end
                    8'h1C: begin
                        // NEOSD_RESP1_REG is read-only
                    end
                    8'h20: begin
                        // NEOSD_RESP2_REG is read-only
                    end
                    8'h24: begin
                        // NEOSD_RESP3_REG is read-only
                    end
                    8'h28: begin
                        // NEOSD_RESP4_REG is read-only
                    end
                    8'h2C: begin
                        NEOSD_DATA_REG <= wb_dat_i[31:0];
                        // TODO: Can only be written in Block write mode.
                        // TODO: Trigger something on written
                    end

                    default: begin
                        // Ignore writes to unknown address
                    end
                endcase
            end
        end
    end

    // Wishbone Read Logic
    always @(posedge clk_i) begin
        case (wb_adr_i)
            32'h0: wb_dat_o <= 32'h00000000;
            default: wb_dat_o <= 32'h00000000;
        endcase

        wb_dat_o <= '0;
        // Not needed for wishbone, but for neorv bus switch...
        if (wb_stb_i && !wb_we_i) begin
            case (wb_adr_i[7:0])
                8'h00:
                    wb_dat_o[$bits(NEOSD_CTRL_REG):0] <= NEOSD_CTRL_REG;
                8'h04:
                    wb_dat_o[$bits(NEOSD_STAT_REG):0] <= NEOSD_STAT_REG;
                8'h08:
                    wb_dat_o[$bits(NEOSD_IRQ_FLAG_REG):0] <= NEOSD_IRQ_FLAG_REG;
                8'h0C:
                    wb_dat_o[$bits(NEOSD_IRQ_MASK_REG):0] <= NEOSD_IRQ_MASK_REG;
                8'h10:
                    wb_dat_o[31:0] <= NEOSD_CMDARG_REG;
                8'h14:
                    wb_dat_o[$bits(NEOSD_CMD_REG):0] <= NEOSD_CMD_REG;
                8'h18:
                    wb_dat_o[31:0] <= NEOSD_RESP0_REG;
                8'h1C:
                    wb_dat_o[31:0] <= NEOSD_RESP1_REG;
                8'h20:
                    wb_dat_o[31:0] <= NEOSD_RESP2_REG;
                8'h24:
                    wb_dat_o[31:0] <= NEOSD_RESP3_REG;
                8'h28:
                    wb_dat_o[31:0] <= {24'b0, NEOSD_RESP4_REG};
                8'h2C:
                    wb_dat_o[31:0] <= NEOSD_DATA_REG;

                default: begin
                    // Read unknown addresses as 0
                end
            endcase
        end
    end

    // Handle the handshake
    always @(posedge clk_i) begin
        if (rstn_i == 1'b0)
            wb_ack_o <= 1'b0;
        else
            wb_ack_o <= (wb_stb_i && !wb_stall_o);
    end

    // Never stall, never error
    assign wb_stall_o = 1'b0;
    assign wb_err_o = 1'b0;


    // SD Card: SDCLK
    logic sd_clk_div;
    logic sd_clk_div_last;
    logic sd_clk_en;
    assign sd_clk_div = clkgen_i[NEOSD_CTRL_REG.CDIV];
    assign sd_clk_div2 = sd_clk_div & sd_clk_div_last; 

    assign sd_dat0_o = 1'b0;
    assign sd_dat0_oe = 1'b0;

    always @(posedge clk_i or negedge rstn_i) begin
        if (rstn_i == 1'b0) begin
            sd_clk_o <= 1'b0;
            sd_clk_div_last <= 1'b0;
        end else begin
            if (sd_clk_div == 1'b1) begin
                sd_clk_div_last <= !sd_clk_div_last;
                if (sd_clk_en == 1'b1)
                    sd_clk_o <= !sd_clk_o;
                else
                    sd_clk_o <= 1'b0;
            end
        end
    end

    // SD Card logic: CMD FSM
    logic cmd_reg_load;
    logic[7:0] cmd_reg_din, cmd_reg_dout;

    sreg cmd_reg (
        .clk_i(clk_i),
        .en_i(sd_clk_div2),
        .rstn_i(rstn_i),
        .load_p_i(cmd_reg_load),
        .data_p_i(cmd_reg_din),
        .data_s_i(sd_cmd_i),
        .data_p_o(cmd_reg_dout),
        .data_s_o(sd_cmd_o)
    );

    typedef enum logic[1:0] {CMD_STATE_IDLE, CMD_STATE_WRITE, CMD_STATE_WAIT_RESP, CMD_STATE_READ_RESP} CMD_STATE;

    typedef struct packed {
        CMD_STATE state;
        logic[2:0] bit_counter;
        logic[4:0] byte_counter;
    } CMD_FSM_STATE;

    CMD_FSM_STATE cmd_fsm_curr;
    CMD_FSM_STATE cmd_fsm_next;

    always @(posedge clk_i or negedge rstn_i) begin

        if (rstn_i == 1'b0) begin
            cmd_fsm_curr <= '0;
            sd_cmd_oe <= 1'b0;
            sd_clk_en <= 1'b0;
            sd_status_cmd_done <= 1'b0;
        end else begin
            if (sd_clk_div2 == 1'b1) begin
                cmd_reg_load <= 1'b0;
                cmd_reg_din <= '0;
                sd_cmd_oe <= 1'b0;
                // NEOSD_CTRL_REG RSTN, EN, ABRT

                // State transition logic
                cmd_fsm_next = cmd_fsm_curr;
                case (cmd_fsm_curr.state)
                    CMD_STATE_IDLE: begin
                        sd_status_cmd_done <= 1'b0;
                        if (NEOSD_CMD_REG.COMMIT == 1'b1) begin
                            cmd_fsm_next.state = CMD_STATE_WRITE;
                            cmd_fsm_next.bit_counter = 0;
                            cmd_fsm_next.byte_counter = 5;
                            cmd_reg_load <= 1'b1;
                            cmd_reg_din <= {2'b01, NEOSD_CMD_REG.IDX};
                        end
                    end
                    CMD_STATE_WRITE: begin
                        sd_cmd_oe <= 1'b1;
                        sd_clk_en <= 1'b1;
                        if (cmd_fsm_curr.bit_counter == 7) begin
                            cmd_fsm_next.bit_counter = 0;
                            cmd_fsm_next.byte_counter = cmd_fsm_curr.byte_counter - 1;
                            cmd_reg_load <= 1'b1;
                            case (cmd_fsm_curr.byte_counter)
                                0: begin
                                    cmd_reg_load <= 1'b0;
                                    case (NEOSD_CMD_REG.RMODE)
                                        RESP_NONE: begin
                                            cmd_fsm_next.state = CMD_STATE_IDLE;
                                            sd_clk_en <= 1'b0;
                                            sd_status_cmd_done <= 1'b1;
                                        end
                                        RESP_SHORT: begin
                                            cmd_fsm_next.byte_counter = 5;
                                            cmd_fsm_next.bit_counter = 2;
                                            cmd_fsm_next.state = CMD_STATE_WAIT_RESP;
                                        end
                                        RESP_LONG: begin
                                            cmd_fsm_next.byte_counter = 16;
                                            cmd_fsm_next.bit_counter = 2;
                                            cmd_fsm_next.state = CMD_STATE_WAIT_RESP;
                                        end
                                    endcase
                                end
                                1:
                                    cmd_reg_din <= {NEOSD_CMD_REG.CRC, 1'b1};
                                2:
                                    cmd_reg_din <= NEOSD_CMDARG_REG[7:0];
                                3:
                                    cmd_reg_din <= NEOSD_CMDARG_REG[15:8];
                                4:
                                    cmd_reg_din <= NEOSD_CMDARG_REG[23:16];
                                5:
                                    cmd_reg_din <= NEOSD_CMDARG_REG[31:24];
                            endcase
                        end else begin
                            cmd_fsm_next.bit_counter = cmd_fsm_curr.bit_counter + 1;
                        end
                    end
                    CMD_STATE_WAIT_RESP: begin
                        if (cmd_reg_dout[1:0] == 2'b00) begin
                            cmd_fsm_next.state = CMD_STATE_READ_RESP;
                        end
                    end
                    CMD_STATE_READ_RESP: begin
                        if (cmd_fsm_curr.bit_counter == 7) begin
                            cmd_fsm_next.bit_counter = 0;
                            cmd_fsm_next.byte_counter = cmd_fsm_curr.byte_counter - 1;
                            case (cmd_fsm_curr.byte_counter)
                                0: begin
                                    NEOSD_RESP0_REG[7:0] <= cmd_reg_dout;
                                    cmd_fsm_next.state = CMD_STATE_IDLE;
                                    sd_clk_en <= 1'b0;
                                    /* In theory, we could do this one sd_clk_div2 cycle earlier,
                                     * as the handoff to the other state machine / the registers takes one cycle.
                                     * However, have to think about this later, when I add support to stall the clock.
                                     * We don't want this to be reported multiple times...
                                     */
                                    sd_status_cmd_done <= 1'b1;
                                end
                                1:
                                    NEOSD_RESP0_REG[15:8] <= cmd_reg_dout;
                                2:
                                    NEOSD_RESP0_REG[23:16] <= cmd_reg_dout;
                                3:
                                    NEOSD_RESP0_REG[31:24] <= cmd_reg_dout;
                                4:
                                    NEOSD_RESP1_REG[7:0] <= cmd_reg_dout;
                                5:
                                    NEOSD_RESP1_REG[15:8] <= cmd_reg_dout;
                                6:
                                    NEOSD_RESP1_REG[23:16] <= cmd_reg_dout;
                                7:
                                    NEOSD_RESP1_REG[31:24] <= cmd_reg_dout;
                                8:
                                    NEOSD_RESP2_REG[7:0] <= cmd_reg_dout;
                                9:
                                    NEOSD_RESP2_REG[15:8] <= cmd_reg_dout;
                                10:
                                    NEOSD_RESP2_REG[23:16] <= cmd_reg_dout;
                                11:
                                    NEOSD_RESP2_REG[31:24] <= cmd_reg_dout;
                                12:
                                    NEOSD_RESP3_REG[7:0] <= cmd_reg_dout;
                                13:
                                    NEOSD_RESP3_REG[15:8] <= cmd_reg_dout;
                                14:
                                    NEOSD_RESP3_REG[23:16] <= cmd_reg_dout;
                                15:
                                    NEOSD_RESP3_REG[31:24] <= cmd_reg_dout;
                                16:
                                    NEOSD_RESP4_REG[7:0] <= cmd_reg_dout;
                            endcase
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