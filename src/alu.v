module alu (
	input wire [31:0] op_a,
	input wire [31:0] op_b,
	input wire [7:0] op_code,
	output reg [3:0] flags,
	output reg [31:0] result
);
	localparam NOP = 8'h00;
	localparam LOAD = 8'h01;
	localparam LOAD_IND = 8'h02;
	localparam LOAD_IMM = 8'h03;
	localparam STORRE = 8'h04;
	localparam STORRE_IND = 8'h05;
	localparam ADD = 8'h06;
	localparam SUB = 8'h07;
	localparam MUL = 8'h08;
	localparam ANDD = 8'h09;
	localparam ORR = 8'h0A;
	localparam NOTT = 8'h0B;
	localparam CMP = 8'h0C;
	localparam EQ = 8'h0D;
	localparam ADDI = 8'h16;
	localparam SUBI = 8'h17;
	localparam SHL = 8'h11;
	localparam SHR = 8'h12;
	localparam SAR = 8'h13;
	localparam JMP = 8'h0E;
	localparam JMP_IF = 8'h0F;
	localparam BEQ = 8'h20;
	localparam BNE = 8'h21;
	localparam BLT = 8'h22;
	localparam BGE = 8'h23;
	localparam HALT = 8'hFF;

	always@(*) begin
		flags[3] = 0;
		flags[2] = 0;
		case(op_code)
			ADD,ADDI: begin
				{flags[2],result} = $signed(op_a) + $signed(op_b);
				flags[3] = (op_a[31] == op_b[31]) && (result[31] != op_a[31]);
			end
			SUB,CMP,SUBI: begin
				{flags[2],result} = $signed(op_a) - $signed(op_b);
				flags[3] = (op_a[31] != op_b[31]) && (result[31] != op_a[31]);
			end
			MUL: begin
				result = op_a * op_b;
			end
			ANDD: begin
				result = op_a & op_b;
			end
			ORR: begin
				result = op_a | op_b;
			end
			NOTT: begin
				result = ~op_a;
			end
			EQ: begin
				result = {31'b0,(op_a == op_b)};
			end	
			SHL: begin
				result = op_a << op_b[4:0];
			end
			SAR: begin
				result = $signed(op_a) >>> op_b[4:0];
			end
			SHR: begin
				result = op_a >> op_b[4:0];
			end
			LOAD_IMM: result = op_b;
			default: result = 0; // NOP
		endcase
		flags[1] = result[31];
		flags[0] = (result == 0);
	end
endmodule