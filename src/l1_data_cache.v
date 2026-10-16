module l1_data_cache (
    input  wire        clk,
    input  wire        rst_n,

    // From the MEM stage.
    // addr is a 14-bit WORD address.
    input  wire        req_read,
    input  wire        req_write,
    input  wire [13:0] addr,
    input  wire [31:0] wdata,
    output wire [31:0] rdata,
    output wire        ready,

    // Request FIFO write side.
    // {write_enable, word_address[13:0], write_data[31:0]}
    output wire        rq_winc,
    output wire [46:0] rq_wdata,
    input  wire        rq_wfull,

    // Response FIFO read side.
    output wire        rs_rinc,
    input  wire [31:0] rs_rdata,
    input  wire        rs_rempty
);

    localparam integer LINES = 256;
    localparam integer WORDS_PER_LINE = 4;
    localparam integer CACHE_WORDS = LINES * WORDS_PER_LINE;

    // 14-bit word address:
    //   [13:10] = 4-bit tag
    //   [9:2]   = 8-bit line index
    //   [1:0]   = 2-bit word offset
    wire [3:0] addr_tag   = addr[13:10];
    wire [7:0] addr_index = addr[9:2];
    wire [1:0] addr_word  = addr[1:0];

    reg [31:0] data [0:CACHE_WORDS-1];
    reg [3:0]  tags [0:LINES-1];
    reg [LINES-1:0] valid;

    // Latched miss information. This prevents the cache request from
    // changing while the four-word line fill is in progress.
    reg [3:0] miss_tag;
    reg [7:0] miss_index;
    reg [13:0] miss_base_addr;

    reg [2:0] req_cnt;
    reg [2:0] resp_cnt;

    localparam S_IDLE = 1'b0;
    localparam S_FILL = 1'b1;
    reg state;

    wire hit = valid[addr_index] && (tags[addr_index] == addr_tag);

    wire [9:0] cache_word_addr = {addr_index, addr_word};
    assign rdata = data[cache_word_addr];

    wire idle = (state == S_IDLE);

    // A load miss starts a four-word line fill.
    wire start_fill = idle && req_read && !hit;

    // Stores are write-through. A store request is accepted whenever the
    // request FIFO has room. On a store hit, the cache copy is updated too.
    wire write_go = idle && req_write && !rq_wfull;

    // Send one read request for each word in the cache line.
    wire fill_push = (state == S_FILL) && (req_cnt < 3'd4) && !rq_wfull;

    // Consume a returned word whenever one is available during a fill.
    wire fill_wr = (state == S_FILL) && !rs_rempty;

    // The CPU may proceed when there is no request, a load hits, or a store
    // has been accepted into the request FIFO.
    assign ready = !(req_read || req_write) ||
                   (idle && (req_read ? hit : !rq_wfull));

    assign rq_winc = write_go || fill_push;

    // Store request: use the current CPU address/data.
    // Fill request: use the latched line base plus the current word count.
    assign rq_wdata = write_go ?
                      {1'b1, addr, wdata} :
                      {1'b0, (miss_base_addr + {12'd0, req_cnt[1:0]}), 32'd0};

    assign rs_rinc = fill_wr;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state         <= S_IDLE;
            req_cnt       <= 3'd0;
            resp_cnt      <= 3'd0;
            valid         <= {LINES{1'b0}};
            miss_tag      <= 4'd0;
            miss_index    <= 8'd0;
            miss_base_addr <= 14'd0;
        end
        else begin
            case (state)
                S_IDLE: begin
                    if (start_fill) begin
                        state          <= S_FILL;
                        req_cnt        <= 3'd0;
                        resp_cnt       <= 3'd0;
                        miss_tag       <= addr_tag;
                        miss_index     <= addr_index;
                        miss_base_addr <= {addr[13:2], 2'b00};
                        valid[addr_index] <= 1'b0;
                    end
                end

                S_FILL: begin
                    if (fill_push)
                        req_cnt <= req_cnt + 3'd1;

                    if (fill_wr) begin
                        resp_cnt <= resp_cnt + 3'd1;

                        if (resp_cnt == 3'd3) begin
                            valid[miss_index] <= 1'b1;
                            state             <= S_IDLE;
                        end
                    end
                end

                default: begin
                    state <= S_IDLE;
                end
            endcase
        end
    end

    always @(posedge clk) begin
        if (fill_wr)
            data[{miss_index, resp_cnt[1:0]}] <= rs_rdata;
        else if (write_go && hit)
            data[{addr_index, addr_word}] <= wdata;

        if (fill_wr && (resp_cnt == 3'd3))
            tags[miss_index] <= miss_tag;
    end

endmodule
