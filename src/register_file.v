module register_file #(
	parameter DATA_WIDTH = 32,
	parameter ADDR_WIDTH = 4,
	parameter NUM_REGS = 16
)(
	input wire clk,
	input wire rst_n,
	
	input wire [ADDR_WIDTH-1:0] r1_addr,
	output wire [DATA_WIDTH-1:0] r1_data,

	input wire [ADDR_WIDTH-1:0] r2_addr,
	output wire [DATA_WIDTH-1:0] r2_data,
	
	input wire [ADDR_WIDTH-1:0] r3_addr,
	output wire [DATA_WIDTH-1:0] r3_data,

	input wire wr_en,
	input wire [ADDR_WIDTH-1:0] wr_addr,
	input wire [DATA_WIDTH-1:0] wr_data
);
	reg [DATA_WIDTH-1:0] regs [0:NUM_REGS-1];

	integer i;
	always@(posedge clk or negedge rst_n) begin
		if(!rst_n) begin
			for(i=0; i<NUM_REGS; i=i+1) regs[i] <= 0;
		end
		else if(wr_en) regs[wr_addr] <= wr_data;
	end
	
	assign r1_data = (wr_en && (wr_addr == r1_addr)) ? wr_data : regs[r1_addr];
	assign r2_data = (wr_en && (wr_addr == r2_addr)) ? wr_data : regs[r2_addr];
	assign r3_data = (wr_en && (wr_addr == r3_addr)) ? wr_data : regs[r3_addr];
endmodule