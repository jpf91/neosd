module neosd (
    input clk_i,
    input rstn_i,

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
    output reg sd_dat0_o,
    input sd_dat0_i,
    output reg sd_dato_oe

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
        logic dummy;
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

    // SD Data Register (R/W)
    logic[31:0] NEOSD_DATA_REG;


    // Wishbone code based on https://zipcpu.com/zipcpu/2017/05/29/simple-wishbone.html
    wire wb_stall_o;

    // Wishbone Write Logic
    always @(posedge clk_i or negedge rstn_i) begin
        if (rstn_i == 1'b0) begin
            NEOSD_CTRL_REG <= '0;
            NEOSD_STAT_REG <= '0; // FIXME: STAT_DISABLED
            NEOSD_IRQ_FLAG_REG <= '0;
            NEOSD_IRQ_MASK_REG <= '0;
            // NEOSD_CMDARG_REG: Don't initialize
            NEOSD_CMD_REG[0] <= '0; // Initialize only commit bit
            // NEOSD_RESP0_REG: Don't initialize
            // NEOSD_RESP1_REG: Don't initialize
            // NEOSD_RESP2_REG: Don't initialize
            // NEOSD_RESP3_REG: Don't initialize
            // NEOSD_DATA_REG: Don't initialize
        end else begin
            // Flag auto-resets after one cycle
            NEOSD_CMD_REG.COMMIT <= 1'b0;

            if (wb_stb_i && wb_we_i && !wb_stall_o) begin
                case (wb_adr_i)
                    32'h00000000:
                        NEOSD_CTRL_REG <= wb_dat_i[$bits(NEOSD_CTRL_REG):0];
                    32'h00000004: begin
                        // NEOSD_STAT_REG is read-only
                    end
                    32'h00000008: // TODO: Write 1 to clear? What does neorv do?
                        NEOSD_IRQ_FLAG_REG <= wb_dat_i[$bits(NEOSD_IRQ_FLAG_REG):0];
                    32'h0000000C:
                        NEOSD_IRQ_MASK_REG <= wb_dat_i[$bits(NEOSD_IRQ_MASK_REG):0];
                    32'h00000010:
                        NEOSD_CMDARG_REG <= wb_dat_i[31:0];
                    32'h00000014:
                        NEOSD_CMD_REG <= wb_dat_i[$bits(NEOSD_CMD_REG):0];
                    32'h00000018: begin
                        // NEOSD_RESP0_REG is read-only
                    end
                    32'h0000001C: begin
                        // NEOSD_RESP1_REG is read-only
                    end
                    32'h00000020: begin
                        // NEOSD_RESP2_REG is read-only
                    end
                    32'h00000024: begin
                        // NEOSD_RESP3_REG is read-only
                    end
                    32'h00000028: begin
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
        case (wb_adr_i)
            32'h00000000:
                wb_dat_o[$bits(NEOSD_CTRL_REG):0] <= NEOSD_CTRL_REG;
            32'h00000004:
                wb_dat_o[$bits(NEOSD_STAT_REG):0] <= NEOSD_STAT_REG;
            32'h00000008:
                wb_dat_o[$bits(NEOSD_IRQ_FLAG_REG):0] <= NEOSD_IRQ_FLAG_REG;
            32'h0000000C:
                wb_dat_o[$bits(NEOSD_IRQ_MASK_REG):0] <= NEOSD_IRQ_MASK_REG;
            32'h00000010:
                wb_dat_o[31:0] <= NEOSD_CMDARG_REG;
            32'h00000014:
                wb_dat_o[$bits(NEOSD_CMD_REG):0] <= NEOSD_CMD_REG;
            32'h00000018:
                wb_dat_o[31:0] <= NEOSD_RESP0_REG;
            32'h0000001C:
                wb_dat_o[31:0] <= NEOSD_RESP1_REG;
            32'h00000020:
                wb_dat_o[31:0] <= NEOSD_RESP2_REG;
            32'h00000024:
                wb_dat_o[31:0] <= NEOSD_RESP3_REG;
            32'h00000028:
                wb_dat_o[31:0] <= NEOSD_DATA_REG;

            default: begin
                // Read unknown addresses as 0
            end
        endcase
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



    // SD Card logic: CMD FSM
    logic cmd_reg_load;
    logic[15:0] cmd_reg_din, cmd_reg_dout;

    sreg cmd_reg (
        .clk_i(clk_i),
        .rstn_i(rstn_i),
        .load_p_i(cmd_reg_load),
        .data_p_i(cmd_reg_din),
        .data_s_i(sd_cmd_i),
        .data_p_o(cmd_reg_dout),
        .data_s_o(sd_cmd_o)
    );

    typedef enum logic[4:0] {CMD_STATE_IDLE, CMD_STATE_W0, CMD_STATE_W1, CMD_STATE_W2, CMD_STATE_R} CMD_STATE;

    typedef struct packed {
        CMD_STATE state;
        logic[3:0] counter;
    } CMD_FSM_STATE;

    CMD_FSM_STATE cmd_fsm_curr;

    always @(posedge clk_i or negedge rstn_i) begin
        CMD_FSM_STATE cmd_fsm_next;

        if (rstn_i == 1'b0) begin
            cmd_fsm_curr.state <= CMD_STATE_IDLE;
            cmd_fsm_curr.counter <= 0;
            sd_cmd_oe <= 1'b0;
        end else begin
            cmd_reg_load <= 1'b0;
            // NEOSD_CTRL_REG RSTN, EN, ABRT

            // State transition logic
            cmd_fsm_next = cmd_fsm_curr;
            case (cmd_fsm_curr.state)
                CMD_STATE_IDLE: begin
                    if (NEOSD_CMD_REG.COMMIT == 1'b1) begin
                        cmd_fsm_next.state = CMD_STATE_W0;
                        cmd_fsm_next.counter = 0;
                        cmd_reg_load <= 1'b1;
                        cmd_reg_din <= {2'b01, NEOSD_CMD_REG.IDX, NEOSD_CMDARG_REG[31:24]};
                    end
                end
                CMD_STATE_W0: begin
                    sd_cmd_oe <= 1'b1;
                    if (cmd_fsm_curr.counter == 15) begin
                        cmd_fsm_next.state = CMD_STATE_W1;
                        cmd_fsm_next.counter = 0;
                        cmd_reg_load <= 1'b1;
                        cmd_reg_din <= NEOSD_CMDARG_REG[23:8];
                    end else begin
                        cmd_fsm_next.counter = cmd_fsm_curr.counter + 1;
                    end
                end
                CMD_STATE_W1: begin
                    if (cmd_fsm_curr.counter == 15) begin
                        cmd_fsm_next.state = CMD_STATE_W2;
                        cmd_fsm_next.counter = 0;
                        cmd_reg_load <= 1'b1;
                        cmd_reg_din <= {NEOSD_CMDARG_REG[7:0], NEOSD_CMD_REG.CRC, 1'b1};
                    end else begin
                        cmd_fsm_next.counter = cmd_fsm_curr.counter + 1;
                    end
                end
                CMD_STATE_W2: begin
                    if (cmd_fsm_curr.counter == 15) begin
                        cmd_fsm_next.state = CMD_STATE_R;
                        cmd_fsm_next.counter = 0;
                        sd_cmd_oe <= 1'b0;
                    end else begin
                        cmd_fsm_next.counter = cmd_fsm_curr.counter + 1;
                    end
                end
            endcase

            cmd_fsm_curr <= cmd_fsm_next;
        end
    end
endmodule