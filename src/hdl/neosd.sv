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
    output reg[31:0] wb_dat_o
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
    typedef enum {RESP_NONE, RESP_SHORT, RESP_LONG} RESP_MODE;
    // Transfer on data lines: No data, busy signal flag, read block, write block
    typedef enum {DATA_NONE, DATA_BUSY, DATA_R, DATA_W} DATA_MODE;

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

endmodule