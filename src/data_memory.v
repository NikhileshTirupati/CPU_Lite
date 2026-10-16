module data_memory #(
    parameter integer WORDS = 16384,
    parameter INIT_FILE = "data.mem"
)(
    input  wire        clk,
    input  wire        rst_n,
    input  wire        rq_empty,
    input  wire [46:0] rq_data,
    output wire        rq_rinc,
    input  wire        rs_full,
    output wire        rs_winc,
    output wire [31:0] rs_wdata
);

    // 16K x 32-bit = 16384 words.
    // The memory is word addressed, so the address is 14 bits.
    reg [31:0] mem [0:WORDS-1];

    integer i;

    initial begin
        for (i = 0; i < WORDS; i = i + 1)
            mem[i] = 32'd0;
        $readmemh(INIT_FILE, mem);
    end

    wire        we    = rq_data[46];
    wire [13:0] waddr = rq_data[45:32];
    wire [31:0] wd    = rq_data[31:0];

    reg        pending;
    reg [31:0] rd_q;

    // Accept one request when there is no outstanding read response and the
    // response FIFO has space.
    wire do_req = !pending && !rq_empty && !rs_full;

    assign rq_rinc = do_req;

    always @(posedge clk) begin
        if (do_req) begin
            if (we)
                mem[waddr] <= wd;

            rd_q <= mem[waddr];
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            pending <= 1'b0;
        else
            pending <= do_req && !we;
    end

    assign rs_winc  = pending;
    assign rs_wdata = rd_q;

endmodule
