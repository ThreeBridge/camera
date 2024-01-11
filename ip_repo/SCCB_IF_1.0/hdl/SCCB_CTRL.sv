//
module SCCB_CTRL(
    input               CLK                 ,   //
    input               RSTn                ,   //
    input   [  1: 0]    I_SCCB_CTRL         ,   //
    input   [ 15: 0]    I_SCCB_ADDR         ,   //
    input   [  7: 0]    I_SCCB_WDATA        ,   //
    output  [  7: 0]    O_SCCB_RDATA        ,   //
    output              O_SCCB_RDATA_EN     ,   //
    output              O_SCL               ,   //
    output              O_SDA               ,   //
    output              O_SDA_OE            ,   //
    input               I_SDA                   //
);

    parameter           P_CLK_MAX    = 10   ;
    parameter           P_SLAVE_ADDR = 7'h3C;

    typedef enum logic[2:0] { IDLE, WAIT, SLV_ID, SLV_ADDR1, SLV_ADDR2, SLV_WDATA, SLV_RDATA } state;
    state               r_st, w_nx_st       ;

    logic   [  1: 0]    r_sccb_ctrl         ;
    logic   [ 15: 0]    r_sccb_addr         ;
    logic   [  7: 0]    r_sccb_wdata        ;
    logic   [  1: 0]    r_sccb_start        ;
    logic               w_sccb_start_pos    ;
    logic               w_rwsel             ;

    logic   [ 17: 0]    r_5ms_cnt           ;
    logic   [ 15: 0]    r_clk_cnt           ;
    logic               r_clk_en            ;
    logic   [  4: 0]    r_scl_cnt           ;
    logic               r_scl               ;
    logic   [  7: 0]    r_sda_buff          ;
    logic               r_sda               ;
    logic               r_sda_oe            ;

    logic   [  1: 0]    r_sda_sync          ;
    logic   [  7: 0]    r_rdata             ;
    logic               r_rdata_en          ;

    always_ff @(posedge CLK)begin
        if( !RSTn )begin
            r_sccb_ctrl     <= 2'd0         ;
            r_sccb_addr     <= 16'd0        ;
            r_sccb_wdata    <= 8'd0         ;
        end else begin
            r_sccb_ctrl     <= I_SCCB_CTRL  ;
            r_sccb_addr     <= I_SCCB_ADDR  ;
            r_sccb_wdata    <= I_SCCB_WDATA ;
        end
    end

    always_ff @(posedge CLK)begin
        if( !RSTn )begin
            r_sccb_start    <= 2'd0         ;
        end else begin
            r_sccb_start    <= { r_sccb_start[0], r_sccb_ctrl[0] };
        end
    end

    assign w_sccb_start_pos = ~r_sccb_start[1] & r_sccb_start[0];
    assign w_rwsel = r_sccb_ctrl[1];

    // State Machine
    always_ff @(posedge CLK)begin
        if( !RSTn )begin
            r_st    <= IDLE;
        end else begin
            r_st    <= w_nx_st;
        end
    end

    always_comb begin
        w_nx_st = r_st;
        case (r_st)
            IDLE        : if( r_5ms_cnt == 18'd250000 )
                            w_nx_st = WAIT;
                          else
                            w_nx_st = r_st;
            WAIT        : if( w_sccb_start_pos )
                            w_nx_st = SLV_ID;
                          else
                            w_nx_st = r_st;
            SLV_ID      : if( r_clk_en && r_scl && ( r_scl_cnt == 5'd9 ) )
                            w_nx_st = SLV_ADDR1;
                          else
                            w_nx_st = r_st;
            SLV_ADDR1   : if( r_clk_en && r_scl && ( r_scl_cnt == 5'd9 ) )
                            w_nx_st = SLV_ADDR2;
                          else
                            w_nx_st = r_st;
            SLV_ADDR2   : if( r_clk_en && r_scl && ( r_scl_cnt == 5'd9 ) )
                            if( w_rwsel )
                                w_nx_st = SLV_WDATA;
                            else
                                w_nx_st = SLV_RDATA;
                          else
                            w_nx_st = r_st;
            SLV_WDATA   : if( r_clk_en && r_scl && ( r_scl_cnt == 5'd9 ) )
                            w_nx_st = WAIT;
                          else
                            w_nx_st = r_st;
            SLV_RDATA   : if( r_clk_en && r_scl && ( r_scl_cnt == 5'd9 ) )
                            w_nx_st = WAIT;
                          else
                            w_nx_st = r_st;
            default     : w_nx_st = IDLE;
        endcase
    end

    // Wait 5ms
    always_ff @(posedge CLK)begin
        if( !RSTn )begin
            r_5ms_cnt       <= 18'd0;
        end else begin
            if( r_5ms_cnt == 18'd250000 )begin
                r_5ms_cnt   <= r_5ms_cnt;
            end else begin
                r_5ms_cnt   <= r_5ms_cnt + 18'd1;
            end
        end
    end

    // SCCB Ctrl
    always_ff @(posedge CLK)begin
        if( !RSTn )begin
            r_clk_cnt       <= 16'd0;
        end else begin
            if( ( r_st == IDLE ) || ( r_st == WAIT ) )begin
                r_clk_cnt   <= 16'd0;
            end else begin
                if( r_clk_cnt == P_CLK_MAX - 1 )begin
                    r_clk_cnt   <= 16'd0;
                end else begin
                    r_clk_cnt   <= r_clk_cnt + 16'd1;
                end
            end
        end
    end

    always_ff @(posedge CLK)begin
        if( !RSTn )begin
            r_clk_en        <= 1'd0;
        end else begin
            if( r_clk_cnt == P_CLK_MAX - 1 )begin
                r_clk_en    <= 1'd1;
            end else begin
                r_clk_en    <= 1'd0;
            end
        end
    end

    always_ff @(posedge CLK)begin
        if( !RSTn )begin
            r_scl_cnt           <= 5'd0;
        end else begin
            if( ( r_st == IDLE ) || ( r_st == WAIT ) )begin
                r_scl_cnt       <= 5'd0;
            end else begin
                if( r_clk_en & r_scl )begin
                    if( r_scl_cnt == 5'd9 )
                        r_scl_cnt   <= 5'd1;
                    else
                        r_scl_cnt   <= r_scl_cnt + 5'd1;
                end
            end
        end
    end

    // SCL
    always_ff @(posedge CLK)begin
        if( !RSTn )begin
            r_scl       <= 1'b1;
        end else begin
            if( ( r_st == IDLE ) || ( r_st == WAIT ) )begin
                r_scl   <= 1'b1;
            end else if( ( ( r_st == SLV_WDATA ) || ( r_st == SLV_RDATA ) ) && ( ( r_scl_cnt == 5'd9 ) && r_clk_en ) )begin
                r_scl   <= 1'b1;
            end else begin
                r_scl   <= ( r_clk_en ) ? ~r_scl : r_scl;
            end
        end
    end

    // SDA
    always_ff @(posedge CLK)begin
        if( !RSTn )begin
            r_sda_buff                              <= 8'd0;
        end else begin
            if( r_clk_en & r_scl)begin
                if( ( r_scl_cnt == 5'd0 ) || ( r_scl_cnt == 5'd9 ) )begin
                    case (w_nx_st)
                        IDLE        : r_sda_buff    <= 8'd0;
                        SLV_ID      : r_sda_buff    <= { P_SLAVE_ADDR, w_rwsel};
                        SLV_ADDR1   : r_sda_buff    <= r_sccb_addr[15:8];
                        SLV_ADDR2   : r_sda_buff    <= r_sccb_addr[ 7:0];
                        SLV_WDATA   : r_sda_buff    <= r_sccb_wdata;
                        default     : r_sda_buff    <= 8'd0;
                    endcase
                end else begin
                    r_sda_buff                      <= { r_sda_buff[6:0], r_sda_buff[7] };
                end
            end
        end
    end

    always_ff @(posedge CLK)begin
        if( !RSTn )begin
            r_sda       <= 1'b1;
        end else begin
            if( ( r_st == IDLE ) || ( r_st == WAIT ) )begin
                r_sda   <= 1'b1;
            end else begin
                r_sda   <= r_sda_buff[7];
            end
        end
    end

    always_ff @(posedge CLK)begin
        if( !RSTn )begin
            r_sda_oe        <= 1'b0;
        end else begin
            if( ( r_st == IDLE ) || ( r_st == WAIT ) || ( r_st == SLV_RDATA ) ) begin
                r_sda_oe    <= 1'b0;
            end else if( r_scl_cnt == 5'd9 ) begin
                r_sda_oe    <= 1'b0;
            end else begin
                r_sda_oe    <= 1'b1;
            end
        end
    end

    // Latch Read Data
    always_ff @(posedge CLK)begin
        if( !RSTn )begin
            r_sda_sync  <= 2'b00;
        end else begin
            r_sda_sync  <= { r_sda_sync[0], I_SDA };
        end
    end

    always_ff @(posedge CLK)begin
        if( !RSTn )begin
            r_rdata     <= 8'd0;
        end else begin
            if( r_st == SLV_RDATA )begin
                r_rdata <= ( r_clk_en & ~r_scl ) ? { r_rdata[6:0], r_sda_sync[1] } : r_rdata;
            end
        end
    end

    always_ff @(posedge CLK)begin
        if( !RSTn )begin
            r_rdata_en      <= 1'b0;
        end else begin
            if( ( r_st == SLV_RDATA ) && ( r_clk_en && r_scl && ( r_scl_cnt == 5'd8 ) ) )begin
                r_rdata_en  <= 1'b1;
            end else begin
                r_rdata_en  <= 1'b0;
            end
        end
    end

    // output
    assign O_SCL            = r_scl         ;
    assign O_SDA            = r_sda         ;
    assign O_SDA_OE         = r_sda_oe      ;
    assign O_SCCB_RDATA     = r_rdata       ;
    assign O_SCCB_RDATA_EN  = r_rdata_en    ;

endmodule
