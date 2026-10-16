module program_counter #(
	parameter ADDR_WIDTH = 12
)(
	input wire clk,
	input wire rst_n,
	input wire en,
	input wire [ADDR_WIDTH-1:0] pc_next,
	output reg [ADDR_WIDTH-1:0] pc
);
	always@(posedge clk or negedge rst_n) begin
		if(!rst_n) pc<=0;
		else if(en) pc<=pc_next;
	end
endmodule