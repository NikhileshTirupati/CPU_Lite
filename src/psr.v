module psr (
	input wire clk,
	input wire rst_n,
	input wire [3:0] flag_en,
	input wire [3:0] alu_flags,
	output reg [3:0] flags
);
	always@(posedge clk or negedge rst_n) begin
		if(!rst_n) flags <= 0;
		else begin
			if(flag_en[0]) flags[0] <= alu_flags[0]; // Z
			if(flag_en[1]) flags[1] <= alu_flags[1]; // N
			if(flag_en[2]) flags[2] <= alu_flags[2]; // C
			if(flag_en[3]) flags[3] <= alu_flags[3]; // V
		end
	end
endmodule