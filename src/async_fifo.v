module async_fifo #(
	parameter DATA_W = 32,
	parameter PTR_W = 3                 // depth = 2**PTR_W (needs >= 2)
)(
	input  wire              wclk, wrst_n, winc,
	input  wire [DATA_W-1:0] wdata,
	output reg               wfull,
	input  wire              rclk, rrst_n, rinc,
	output wire [DATA_W-1:0] rdata,      // first-word-fall-through
	output reg               rempty
);
	reg [DATA_W-1:0] mem [0:(1<<PTR_W)-1];

	reg [PTR_W:0] wbin, wptr, rbin, rptr;      // binary and Gray pointers
	reg [PTR_W:0] rptr_s1, rptr_s2;            // rptr synchronised into wclk
	reg [PTR_W:0] wptr_s1, wptr_s2;            // wptr synchronised into rclk

	// ---------------- write domain ----------------
	wire [PTR_W:0] wbin_n  = wbin + {{PTR_W{1'b0}}, (winc & ~wfull)};
	wire [PTR_W:0] wptr_n  = (wbin_n >> 1) ^ wbin_n;
	wire           wfull_n = (wptr_n == {~rptr_s2[PTR_W:PTR_W-1], rptr_s2[PTR_W-2:0]});

	always @(posedge wclk or negedge wrst_n) begin
		if (!wrst_n) begin
			wbin <= 0; wptr <= 0; wfull <= 1'b0; rptr_s1 <= 0; rptr_s2 <= 0;
		end else begin
			wbin <= wbin_n; wptr <= wptr_n; wfull <= wfull_n;
			rptr_s1 <= rptr; rptr_s2 <= rptr_s1;
		end
	end

	always @(posedge wclk)
		if (winc & ~wfull) mem[wbin[PTR_W-1:0]] <= wdata;

	// ---------------- read domain -----------------
	wire [PTR_W:0] rbin_n   = rbin + {{PTR_W{1'b0}}, (rinc & ~rempty)};
	wire [PTR_W:0] rptr_n   = (rbin_n >> 1) ^ rbin_n;
	wire           rempty_n = (rptr_n == wptr_s2);

	always @(posedge rclk or negedge rrst_n) begin
		if (!rrst_n) begin
			rbin <= 0; rptr <= 0; rempty <= 1'b1; wptr_s1 <= 0; wptr_s2 <= 0;
		end else begin
			rbin <= rbin_n; rptr <= rptr_n; rempty <= rempty_n;
			wptr_s1 <= wptr; wptr_s2 <= wptr_s1;
		end
	end

	assign rdata = mem[rbin[PTR_W-1:0]];
endmodule