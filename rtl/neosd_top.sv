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
    output sd_clk_o,
    output sd_cmd_o,
    input sd_cmd_i,
    output sd_cmd_oe,
    output sd_dat0_o,
    output sd_dat1_o,
    output sd_dat2_o,
    output sd_dat3_o,
    input sd_dat0_i,
    input sd_dat1_i,
    input sd_dat2_i,
    input sd_dat3_i,
    output sd_dat0_oe,
    output sd_dat1_oe,
    output sd_dat2_oe,
    output sd_dat3_oe
);
    // Control and status register
    struct packed {
        logic D4BIT;
        logic[2:0] CDIV;
        logic ABRT;
        logic RST;
        logic EN;
    } NEOSD_CTRL_REG;

    // Interrupt flag register
    logic IRQ_FLAG_CMD_RESP;
    logic IRQ_FLAG_CMD_DONE;
    logic IRQ_FLAG_DAT_DATA;
    logic IRQ_FLAG_BLOCK_DONE;
    logic IRQ_FLAG_DAT_DONE;

    // Command register
    struct packed {
        logic[1:0] RMODE;
        logic[1:0] DMODE;
        logic LAST_BLOCK;
        logic COMMIT;
    } NEOSD_CMD_REG_BASE;

    // Wishbone code based on https://zipcpu.com/zipcpu/2017/05/29/simple-wishbone.html
    logic wb_stall_o;

    logic clkstrb;
    // Status signals from FSMs and latched signals for edge detection
    logic status_idle_cmd, status_resp_cmd;
    logic status_idle_cmd_last, status_resp_cmd_last;
    logic status_idle_dat, status_data_dat;
    logic status_idle_dat_last, status_data_dat_last;
    logic status_block_done, status_crc_ok;


    // IRQ_FLAG_DAT_DATA gets cleared on read and write, so it get's its own block
    always @(posedge clk_i or negedge rstn_i) begin
        if (rstn_i == 1'b0) begin
            IRQ_FLAG_DAT_DATA <= 1'b0;
            status_data_dat_last <= 1'b0;
        end else begin
            // DAT DATA IRQ is edge triggered
            status_data_dat_last <= status_data_dat;
            if (status_data_dat == 1'b1 && status_data_dat_last == 1'b0)
                IRQ_FLAG_DAT_DATA <= 1'b1;

            if (wb_stb_i && (!wb_we_i || !wb_stall_o)) begin
                if (wb_adr_i[7:0] == 8'h1C) begin
                    IRQ_FLAG_DAT_DATA <= 1'b0;
                end;
            end
        end
    end

    // Wishbone Write Logic
    always @(posedge clk_i or negedge rstn_i) begin
        if (rstn_i == 1'b0) begin
            NEOSD_CTRL_REG <= '0;
            IRQ_FLAG_CMD_DONE <= '0;
            IRQ_FLAG_BLOCK_DONE <= '0;
            IRQ_FLAG_DAT_DONE <= '0;
            // NEOSD_CMDARG_REG: Don't initialize
            NEOSD_CMD_REG_BASE <= '0;
            // NEOSD_RESP_REG: Don't initialize
            // NEOSD_DATA_REG: Don't initialize
            status_idle_cmd_last <= 1'b1;
            status_idle_dat_last <= 1'b1;
        end else begin
            // Auto-reset after CMD FSM read those
            if (clkstrb == 1'b1) begin
                NEOSD_CMD_REG_BASE.COMMIT <= 1'b0;
                if (status_block_done == 1'b1)
                    IRQ_FLAG_BLOCK_DONE <= 1'b1;
            end

            // CMD done IRQ is edge triggered
            status_idle_cmd_last <= status_idle_cmd;
            if (status_idle_cmd == 1'b1 && status_idle_cmd_last == 1'b0)
                IRQ_FLAG_CMD_DONE <= 1'b1;

            // DATA done IRQ is edge triggered
            status_idle_dat_last <= status_idle_dat;
            if (status_idle_dat == 1'b1 && status_idle_dat_last == 1'b0)
                IRQ_FLAG_DAT_DONE <= 1'b1;

            if (wb_stb_i && wb_we_i && !wb_stall_o) begin
                case (wb_adr_i[7:0])
                    8'h00:
                        NEOSD_CTRL_REG <= wb_dat_i[$bits(NEOSD_CTRL_REG):0];
                    8'h04: begin
                        // FIXME: REMOVE extra stat reg
                    end
                    8'h08: begin
                        IRQ_FLAG_CMD_DONE <= wb_dat_i[0];
                        IRQ_FLAG_DAT_DONE <= wb_dat_i[2];
                        IRQ_FLAG_BLOCK_DONE <= wb_dat_i[4];
                    end
                    //8'h0C:
                    //    NEOSD_IRQ_MASK_REG <= wb_dat_i[$bits(NEOSD_IRQ_MASK_REG):0];
                    8'h10: begin
                        // Handled async and forwarded to neosd_cmd_fsm
                    end
                    8'h14:
                        NEOSD_CMD_REG_BASE <= wb_dat_i[$bits(NEOSD_CMD_REG_BASE):0];
                    8'h18: begin
                        // NEOSD_RESP_REG is read-only
                    end
                    8'h1C: begin
                        // Handled async and forwarded to neosd_dat_fsm
                    end

                    default: begin
                    end
                endcase
            end
        end
    end

    logic[31:0] cmd_resp_data;
    logic[31:0] dat_data_o;
    // Wishbone Read Logic
    always @(posedge clk_i or negedge rstn_i) begin
        if (rstn_i == 1'b0) begin
            IRQ_FLAG_CMD_RESP <= 1'b0;
            status_resp_cmd_last <= 1'b0;
        end else begin    
            // CMD RESP IRQ is edge triggered
            status_resp_cmd_last <= status_resp_cmd;
            if (status_resp_cmd == 1'b1 && status_resp_cmd_last == 1'b0)
                IRQ_FLAG_CMD_RESP <= 1'b1;

            // For neorv bus switch
            wb_dat_o <= '0;
            if (wb_stb_i && !wb_we_i) begin
                case (wb_adr_i[7:0])
                    8'h00:
                        wb_dat_o[$bits(NEOSD_CTRL_REG):0] <= NEOSD_CTRL_REG;
                    8'h04: begin

                    end
                    8'h08:
                        wb_dat_o[5:0] <= {status_crc_ok, IRQ_FLAG_BLOCK_DONE, IRQ_FLAG_DAT_DATA, IRQ_FLAG_DAT_DONE, IRQ_FLAG_CMD_RESP, IRQ_FLAG_CMD_DONE};
                    //8'h0C: 
                    //    wb_dat_o[$bits(NEOSD_IRQ_MASK_REG):0] <= NEOSD_IRQ_MASK_REG;
                    8'h10: begin
                        // Reading CMDARG is not supported 
                    end
                    8'h14:
                        wb_dat_o[$bits(NEOSD_CMD_REG_BASE):0] <= NEOSD_CMD_REG_BASE;
                    8'h18: begin
                        wb_dat_o[31:0] <= cmd_resp_data;
                        IRQ_FLAG_CMD_RESP <= 1'b0;
                    end
                    8'h1C: begin
                        wb_dat_o[31:0] <= dat_data_o;
                    end

                    default: begin
                        // Read unknown addresses as 0
                    end
                endcase
            end
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

    logic sd_clk_en;
    logic sd_clk_req_dat, sd_clk_stall_dat;
    logic dat_load;
    logic dat_start;

    neosd_dat_fsm dat_fsm (
        .clk_i(clk_i),
        .rstn_i(rstn_i),
        .clkstrb_i(clkstrb),

        .dat_i(wb_dat_i),
        .dat_load_i(dat_load),
        .dat_o(dat_data_o),

        .status_idle_o(status_idle_dat),
        .status_data_o(status_data_dat),
        .status_block_done_o(status_block_done),
        .status_crc_ok_o(status_crc_ok),
        .ctrl_start_i(dat_start),
        .ctrl_dat_ack_i(~IRQ_FLAG_DAT_DATA),
        .ctrl_last_block_i(NEOSD_CMD_REG_BASE.LAST_BLOCK),
        .ctrl_dmode_i(NEOSD_CMD_REG_BASE.DMODE),
        .ctrl_d4_i(NEOSD_CTRL_REG.D4BIT),

        .sd_clk_req_o(sd_clk_req_dat),
        .sd_clk_stall_o(sd_clk_stall_dat),
        .sd_clk_en_i(sd_clk_en),
        .sd_dat0_oe(sd_dat0_oe),
        .sd_dat1_oe(sd_dat1_oe),
        .sd_dat2_oe(sd_dat2_oe),
        .sd_dat3_oe(sd_dat3_oe),
        .sd_dat0_o(sd_dat0_o),
        .sd_dat1_o(sd_dat1_o),
        .sd_dat2_o(sd_dat2_o),
        .sd_dat3_o(sd_dat3_o),
        .sd_dat0_i(sd_dat0_i),
        .sd_dat1_i(sd_dat1_i),
        .sd_dat2_i(sd_dat2_i),
        .sd_dat3_i(sd_dat3_i)
    );

    // Forward register accesses to neosd_dat_fsm
    always_comb begin
        dat_load = 1'b0;
        if (wb_stb_i && wb_we_i && !wb_stall_o) begin
            if (wb_adr_i[7:0] == 8'h1C) begin
                dat_load = 1'b1;
            end
        end
    end

    // SD Implementation: CMD
    logic sd_clk_req_cmd, sd_clk_stall_cmd;

    logic[5:0] cmd_idx;
    logic cmd_idx_load;
    logic[6:0] cmd_crc;
    logic cmd_crc_load;
    logic[31:0] cmd_arg;
    logic[3:0] cmd_arg_load;

    neosd_cmd_fsm cmd_fsm (
        .clk_i(clk_i),
        .rstn_i(rstn_i),
        .clkstrb_i(clkstrb),

        .cmd_idx_i(cmd_idx),
        .cmd_idx_load_i(cmd_idx_load),
        .cmd_crc_i(cmd_crc),
        .cmd_crc_load_i(cmd_crc_load),
        .cmd_arg_i(cmd_arg),
        .cmd_arg_load_i(cmd_arg_load),
        .resp_data_o(cmd_resp_data),

        .status_idle_o(status_idle_cmd),
        .status_resp_o(status_resp_cmd),
        .ctrl_start_i(NEOSD_CMD_REG_BASE.COMMIT),
        .ctrl_resp_ack_i(~IRQ_FLAG_CMD_RESP),
        .ctrl_rmode_i(NEOSD_CMD_REG_BASE.RMODE),
        .ctrl_dmode_i(NEOSD_CMD_REG_BASE.DMODE),
        .start_dat_o(dat_start),

        .sd_clk_req_o(sd_clk_req_cmd),
        .sd_clk_stall_o(sd_clk_stall_cmd),
        .sd_clk_en_i(sd_clk_en),
        .sd_cmd_oe(sd_cmd_oe),
        .sd_cmd_o(sd_cmd_o),
        .sd_cmd_i(sd_cmd_i)
    );

    // Forward register accesses to neosd_cmd_fsm
    always_comb begin
        cmd_idx = wb_dat_i[21:16];
        cmd_crc = wb_dat_i[14:8];
        cmd_arg = wb_dat_i;

        cmd_idx_load = 1'b0;
        cmd_crc_load = 1'b0;
        cmd_arg_load = 4'b0000;

        // TODO: Should we use wb_sel_i and support byte access?
        if (wb_stb_i && wb_we_i && !wb_stall_o) begin
            case (wb_adr_i[7:0])
                8'h10: begin
                    cmd_arg_load = 4'b1111;
                end
                8'h14: begin
                    cmd_idx_load = 1'b1;
                    cmd_crc_load = 1'b1;
                end
                default: begin
                end
            endcase
        end
    end

    // SD Implementation: CLK
    neosd_clk sd_clk (
        .clk_i(clk_i),
        .rstn_i(rstn_i),
        .clkgen_i(clkgen_i),
        .sd_clksel_i(NEOSD_CTRL_REG.CDIV),
        .clkstrb_o(clkstrb),
        .sd_clk_req_i({sd_clk_req_cmd, sd_clk_req_dat}),
        .sd_clk_stall_i({sd_clk_stall_cmd, sd_clk_stall_dat}),
        .sd_clk_en_o(sd_clk_en),
        .sd_clk_o(sd_clk_o)
    );
endmodule