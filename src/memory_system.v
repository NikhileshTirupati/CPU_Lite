module memory_system (
    input  wire        clk,
    input  wire        mem_clk,
    input  wire        rst_n,
    input  wire        req_read,
    input  wire        req_write,
    input  wire [13:0] addr,
    input  wire [31:0] wdata,
    output wire [31:0] rdata,
    output wire        ready
);

    wire mrst_n;

    reset_sync u_rs (
        .clk   (mem_clk),
        .arst_n(rst_n),
        .rst_n (mrst_n)
    );

    // Request FIFO: CPU clock domain -> memory clock domain.
    // Width = 1 write bit + 14-bit word address + 32-bit data = 47 bits.
    wire        rq_winc;
    wire        rq_wfull;
    wire        rq_rinc;
    wire        rq_rempty;
    wire [46:0] rq_wdata;
    wire [46:0] rq_rdata;

    async_fifo #(
        .DATA_W(47),
        .PTR_W(3)
    ) u_req_fifo (
        .wclk   (clk),
        .wrst_n (rst_n),
        .winc   (rq_winc),
        .wdata  (rq_wdata),
        .wfull  (rq_wfull),
        .rclk   (mem_clk),
        .rrst_n (mrst_n),
        .rinc   (rq_rinc),
        .rdata  (rq_rdata),
        .rempty (rq_rempty)
    );

    // Response FIFO: memory clock domain -> CPU clock domain.
    wire        rs_winc;
    wire        rs_wfull;
    wire        rs_rinc;
    wire        rs_rempty;
    wire [31:0] rs_wdata;
    wire [31:0] rs_rdata;

    async_fifo #(
        .DATA_W(32),
        .PTR_W(3)
    ) u_resp_fifo (
        .wclk   (mem_clk),
        .wrst_n (mrst_n),
        .winc   (rs_winc),
        .wdata  (rs_wdata),
        .wfull  (rs_wfull),
        .rclk   (clk),
        .rrst_n (rst_n),
        .rinc   (rs_rinc),
        .rdata  (rs_rdata),
        .rempty (rs_rempty)
    );

    l1_data_cache u_cache (
        .clk      (clk),
        .rst_n    (rst_n),
        .req_read (req_read),
        .req_write(req_write),
        .addr     (addr),
        .wdata    (wdata),
        .rdata    (rdata),
        .ready    (ready),
        .rq_winc  (rq_winc),
        .rq_wdata (rq_wdata),
        .rq_wfull (rq_wfull),
        .rs_rinc  (rs_rinc),
        .rs_rdata (rs_rdata),
        .rs_rempty(rs_rempty)
    );

    data_memory u_dmem (
        .clk     (mem_clk),
        .rst_n   (mrst_n),
        .rq_empty(rq_rempty),
        .rq_data (rq_rdata),
        .rq_rinc (rq_rinc),
        .rs_full (rs_wfull),
        .rs_winc (rs_winc),
        .rs_wdata(rs_wdata)
    );

endmodule
