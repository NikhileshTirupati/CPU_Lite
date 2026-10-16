module if_id_reg #(
	parameter INST_WIDTH = 32
)(
	input  wire clk,
	input  wire rst_n,
	input  wire en,
	input  wire flush,
	input  wire [INST_WIDTH-1:0] inst_in,
	output reg  [INST_WIDTH-1:0] inst_out
);
	always @(posedge clk or negedge rst_n) begin
		if (!rst_n)      inst_out <= 0;
		else if (en) begin
			if (flush)   inst_out <= 0;   // 0 = NOP, all controls low
			else         inst_out <= inst_in;
		end
	end
endmodule