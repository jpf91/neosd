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
    output reg[31:0] wb_dat_o,

    output irq_o,
    output flag_data_o,

    // SD Card Signals
    output sd_clk_o,
    output sd_cmd_o,
    input sd_cmd_i,
    output sd_cmd_oe,
    output[3:0] sd_dat_o,
    input[3:0] sd_dat_i,
    output[3:0] sd_dat_oe
);
    localparam ADDR_INFO = 8'h00;
    localparam ADDR_CTRL = 8'h04;
    localparam ADDR_CMDARG = 8'h08;
    localparam ADDR_CMD = 8'h0C;
    localparam ADDR_RESP = 8'h10;
    localparam ADDR_DATA = 8'h14;

    // Control and status register
    logic CTRL_RST, CTRL_D4, CTRL_IDLE_SDCLK;
    logic[2:0] CTRL_CLK_PRSC;
    logic[3:0] CTRL_CLK_DIV;
    logic CTRL_CLK_HS;
    logic CTRL_STAT_CRCERR;
    logic CTRL_FLAG_CMD_RESP, CTRL_FLAG_DAT_DATA, CTRL_FLAG_CMD_DONE, CTRL_FLAG_DAT_DONE, CTRL_FLAG_BLK_DONE;
    logic CTRL_MASK_CMD_RESP, CTRL_MASK_DAT_DATA, CTRL_MASK_CMD_DONE, CTRL_MASK_DAT_DONE, CTRL_MASK_BLK_DONE;

    // Command register
    logic CMD_COMMIT, CMD_ABRT_DAT;
    logic[1:0] CMD_DMODE;
    logic[1:0] CMD_RMODE;

    // Wishbone code based on https://zipcpu.com/zipcpu/2017/05/29/simple-wishbone.html
    logic wb_stall_o;

    logic clkstrb;
    // Status signals from FSMs and latched signals for edge detection
    logic status_idle_cmd, status_resp_cmd;
    logic status_idle_cmd_last, status_resp_cmd_last;
    logic status_idle_dat, status_data_dat;
    logic status_idle_dat_last, status_data_dat_last;
    logic status_block_done, status_crc_ok;


    // CTRL_FLAG_DAT_DATA gets cleared on read and write, so it get's its own block
    always @(posedge clk_i or negedge rstn_i) begin
        if (rstn_i == 1'b0) begin
            CTRL_FLAG_DAT_DATA <= 1'b0;
            status_data_dat_last <= 1'b0;
        end else begin
            // DAT DATA IRQ is edge triggered
            status_data_dat_last <= status_data_dat;
            if (status_data_dat == 1'b1 && status_data_dat_last == 1'b0)
                CTRL_FLAG_DAT_DATA <= 1'b1;

            if (wb_stb_i && (!wb_we_i || !wb_stall_o)) begin
                if (wb_adr_i[7:0] == ADDR_DATA) begin
                    CTRL_FLAG_DAT_DATA <= 1'b0;
                end;
            end
        end
    end

    // Wishbone Write Logic
    always @(posedge clk_i or negedge rstn_i) begin
        if (rstn_i == 1'b0) begin
            CTRL_RST <= '0;
            CTRL_D4 <= '0;
            CTRL_IDLE_SDCLK <= '0;
            CTRL_CLK_PRSC <= '0;
            CTRL_CLK_DIV <= '0;
            CTRL_CLK_HS <= '0;
            CTRL_STAT_CRCERR <= '0;
            CTRL_FLAG_CMD_DONE <= '0;
            CTRL_FLAG_DAT_DONE <= '0;
            CTRL_FLAG_BLK_DONE <= '0;
            CTRL_MASK_CMD_RESP <= '0;
            CTRL_MASK_DAT_DATA <= '0;
            CTRL_MASK_CMD_DONE <= '0;
            CTRL_MASK_DAT_DONE <= '0;
            CTRL_MASK_BLK_DONE <= '0;
        
            CMD_COMMIT <= '0;
            CMD_ABRT_DAT <= '0;
            CMD_DMODE <= '0;
            CMD_RMODE <= '0;

            status_idle_cmd_last <= 1'b1;
            status_idle_dat_last <= 1'b1;
        end else begin
            // Auto-reset after CMD FSM read those
            if (clkstrb == 1'b1) begin
                CMD_COMMIT <= 1'b0;
                if (status_block_done == 1'b1) begin
                    CTRL_FLAG_BLK_DONE <= 1'b1;
                    CTRL_STAT_CRCERR <= CTRL_STAT_CRCERR | !status_crc_ok;
                end
            end

            // CMD done IRQ is edge triggered
            status_idle_cmd_last <= status_idle_cmd;
            if (status_idle_cmd == 1'b1 && status_idle_cmd_last == 1'b0)
                CTRL_FLAG_CMD_DONE <= 1'b1;

            // DATA done IRQ is edge triggered
            status_idle_dat_last <= status_idle_dat;
            if (status_idle_dat == 1'b1 && status_idle_dat_last == 1'b0)
                CTRL_FLAG_DAT_DONE <= 1'b1;

            if (wb_stb_i && wb_we_i && !wb_stall_o) begin
                case (wb_adr_i[7:0])
                    ADDR_CTRL: begin
                        CTRL_RST <= wb_dat_i[0];
                        CTRL_D4 <= wb_dat_i[1];
                        CTRL_IDLE_SDCLK <= wb_dat_i[3];

                        CTRL_CLK_PRSC <= wb_dat_i[6:4];
                        CTRL_CLK_HS <= wb_dat_i[7];
                        CTRL_CLK_DIV <= wb_dat_i[11:8];

                        // status_idle_cmd and status_idle_dat are read only
                        CTRL_STAT_CRCERR <= wb_dat_i[14];

                        // CTRL_FLAG_CMD_RESP and CTRL_FLAG_DAT_DATA clear on data read instead
                        CTRL_FLAG_CMD_DONE <= wb_dat_i[18];
                        CTRL_FLAG_DAT_DONE <= wb_dat_i[19];
                        CTRL_FLAG_BLK_DONE <= wb_dat_i[20];

                        CTRL_MASK_CMD_RESP <= wb_dat_i[22];
                        CTRL_MASK_DAT_DATA <= wb_dat_i[23];
                        CTRL_MASK_CMD_DONE <= wb_dat_i[24];
                        CTRL_MASK_DAT_DONE <= wb_dat_i[25];
                        CTRL_MASK_BLK_DONE <= wb_dat_i[26];
                    end
                    ADDR_CMD: begin
                        CMD_COMMIT <= wb_dat_i[0];
                        CMD_ABRT_DAT <= wb_dat_i[1];
                        CMD_DMODE <= wb_dat_i[5:4];
                        CMD_RMODE <= wb_dat_i[7:6];
                        // Rest handled async and forwarded to neosd_cmd_fsm
                    end
                    // INFO REG is readonly
                    // CMDARG handled async and forwarded to neosd_cmd_fsm
                    // CMD_RESP handled async and forwarded to neosd_cmd_fsm
                    // DAT_DATA handled async and forwarded to neosd_dat_fsm
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
            CTRL_FLAG_CMD_RESP <= 1'b0;
            status_resp_cmd_last <= 1'b0;
        end else begin    
            // CMD RESP IRQ is edge triggered
            status_resp_cmd_last <= status_resp_cmd;
            if (status_resp_cmd == 1'b1 && status_resp_cmd_last == 1'b0)
                CTRL_FLAG_CMD_RESP <= 1'b1;

            // For neorv bus switch
            wb_dat_o <= '0;
            if (wb_stb_i && !wb_we_i) begin
                case (wb_adr_i[7:0])
                    ADDR_INFO: begin
                        wb_dat_o[31:16] <= 16'hE05D;
                        // Version X.Y.Z
                        wb_dat_o[11:8] <= 0;
                        wb_dat_o[7:4] <= 0;
                        wb_dat_o[3:0] <= 0;
                    end
                    ADDR_CTRL: begin
                        wb_dat_o[0] <= CTRL_RST;
                        wb_dat_o[1] <= CTRL_D4;
                        wb_dat_o[3] <= CTRL_IDLE_SDCLK;

                        wb_dat_o[6:4] <= CTRL_CLK_PRSC;
                        wb_dat_o[7] <= CTRL_CLK_HS;
                        wb_dat_o[11:8] <= CTRL_CLK_DIV;

                        wb_dat_o[12] <= !status_idle_cmd;
                        wb_dat_o[13] <= !status_idle_dat;
                        wb_dat_o[14] <= CTRL_STAT_CRCERR;

                        wb_dat_o[16] <= CTRL_FLAG_CMD_RESP;
                        wb_dat_o[17] <= CTRL_FLAG_DAT_DATA;
                        wb_dat_o[18] <= CTRL_FLAG_CMD_DONE;
                        wb_dat_o[19] <= CTRL_FLAG_DAT_DONE;
                        wb_dat_o[20] <= CTRL_FLAG_BLK_DONE;

                        wb_dat_o[22] <= CTRL_MASK_CMD_RESP;
                        wb_dat_o[23] <= CTRL_MASK_DAT_DATA;
                        wb_dat_o[24] <= CTRL_MASK_CMD_DONE;
                        wb_dat_o[25] <= CTRL_MASK_DAT_DONE;
                        wb_dat_o[26] <= CTRL_MASK_BLK_DONE;
                    end
                    ADDR_RESP: begin
                        wb_dat_o[31:0] <= cmd_resp_data;
                        CTRL_FLAG_CMD_RESP <= 1'b0;
                    end
                    ADDR_DATA: begin
                        wb_dat_o[31:0] <= dat_data_o;
                        // CTRL_FLAG_DAT_DATA is reset in extra block
                    end
                    // CMDARG is write-only
                    // CMD is write-only
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

    // Never stall
    assign wb_stall_o = 1'b0;

    logic sd_clk_en;
    logic sd_clk_req_dat, sd_clk_stall_dat;
    logic dat_load;
    logic dat_start;

    neosd_dat_fsm dat_fsm (
        .clk_i(clk_i),
        .rstn_i(rstn_i),
        .clkstrb_i(clkstrb),
        .fsm_rst_i(CTRL_RST),

        .dat_i(wb_dat_i),
        .dat_load_i(dat_load),
        .dat_o(dat_data_o),

        .status_idle_o(status_idle_dat),
        .status_data_o(status_data_dat),
        .status_block_done_o(status_block_done),
        .status_crc_ok_o(status_crc_ok),
        .ctrl_start_i(dat_start),
        .ctrl_dat_ack_i(~CTRL_FLAG_DAT_DATA),
        .ctrl_last_block_i(CMD_ABRT_DAT),
        .ctrl_dmode_i(CMD_DMODE),
        .ctrl_d4_i(CTRL_D4),

        .sd_clk_req_o(sd_clk_req_dat),
        .sd_clk_stall_o(sd_clk_stall_dat),
        .sd_clk_en_i(sd_clk_en),
        .sd_dat_oe(sd_dat_oe),
        .sd_dat_o(sd_dat_o),
        .sd_dat_i(sd_dat_i)
    );

    // Forward register accesses to neosd_dat_fsm
    always_comb begin
        dat_load = 1'b0;
        if (wb_stb_i && wb_we_i && !wb_stall_o) begin
            if (wb_adr_i[7:0] == ADDR_DATA) begin
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
    logic[31:0] cmdarg;
    logic[3:0] cmdarg_load;

    neosd_cmd_fsm cmd_fsm (
        .clk_i(clk_i),
        .rstn_i(rstn_i),
        .clkstrb_i(clkstrb),
        .fsm_rst_i(CTRL_RST),

        .cmd_idx_i(cmd_idx),
        .cmd_idx_load_i(cmd_idx_load),
        .cmd_crc_i(cmd_crc),
        .cmd_crc_load_i(cmd_crc_load),
        .cmd_arg_i(cmdarg),
        .cmd_arg_load_i(cmdarg_load),
        .resp_data_o(cmd_resp_data),

        .status_idle_o(status_idle_cmd),
        .status_resp_o(status_resp_cmd),
        .ctrl_start_i(CMD_COMMIT),
        .ctrl_resp_ack_i(~CTRL_FLAG_CMD_RESP),
        .ctrl_rmode_i(CMD_RMODE),
        .ctrl_dmode_i(CMD_DMODE),
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
        cmd_idx = wb_dat_i[29:24];
        cmd_crc = wb_dat_i[22:16];
        cmdarg = wb_dat_i;

        cmd_idx_load = 1'b0;
        cmd_crc_load = 1'b0;
        cmdarg_load = 4'b0000;

        // TODO: Should we use wb_sel_i and support byte access?
        if (wb_stb_i && wb_we_i && !wb_stall_o) begin
            case (wb_adr_i[7:0])
                ADDR_CMDARG: begin
                    cmdarg_load = 4'b1111;
                end
                ADDR_CMD: begin
                    cmd_idx_load = 1'b1;
                    cmd_crc_load = 1'b1;
                end
                default: begin
                end
            endcase
        end
    end

    // Interrupts
    assign irq_o = (CTRL_FLAG_BLK_DONE & CTRL_MASK_BLK_DONE) |
        (CTRL_FLAG_CMD_DONE & CTRL_MASK_CMD_DONE) |
        (CTRL_FLAG_CMD_RESP & CTRL_MASK_CMD_RESP) |
        (CTRL_FLAG_DAT_DATA & CTRL_MASK_DAT_DATA) |
        (CTRL_FLAG_DAT_DONE & CTRL_MASK_DAT_DONE);
    
    assign flag_data_o = CTRL_FLAG_DAT_DATA;

    logic[7:0] clkgen;

    neosd_clken clken (
        .clk_i(clk_i),
        .rstn_i(rstn_i),
        .clk_en_o(clkgen),
        .enable_i(1'b1)
    );
    
    // SD Implementation: CLK
    neosd_clk sd_clk (
        .clk_i(clk_i),
        .rstn_i(rstn_i),
        .clkgen_i(clkgen),
        .sd_clksel_i(CTRL_CLK_PRSC),
        .sd_clkdiv_i(CTRL_CLK_DIV),
        .sd_clkhs_i(CTRL_CLK_HS),
        .clkstrb_o(clkstrb),
        .sd_clk_req_i({sd_clk_req_cmd, sd_clk_req_dat, CTRL_IDLE_SDCLK}),
        .sd_clk_stall_i({sd_clk_stall_cmd, sd_clk_stall_dat}),
        .sd_clk_en_o(sd_clk_en),
        .sd_clk_o(sd_clk_o)
    );
endmodule