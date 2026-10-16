module instruction_decoder (
	input  wire [31:0] instr,
	output wire [7:0]  opcode,
	output wire [3:0]  rd_addr,
	output wire [3:0]  rs1_addr,
	output wire [3:0]  rs2_addr,
	output reg  [31:0] imm_ext,
	// control
	output reg reg_write,
	output reg mem_read,
	output reg mem_write,
	output reg [3:0] flag_we,
	output reg alu_b_imm,
	output reg is_branch,
	output reg is_halt,
	// register usage (for hazard detection)
	output reg use_rs1,
	output reg use_rs2,
	output reg use_rd      // store data comes from the rd field
);
	localparam OP_NOP = 8'h00, OP_LOAD = 8'h01, OP_LOAD_IND = 8'h02, OP_LOAD_IMM = 8'h03;
	localparam OP_STORE = 8'h04, OP_STORE_IND = 8'h05;
	localparam OP_ADD = 8'h06, OP_SUB = 8'h07, OP_MUL = 8'h08, OP_AND = 8'h09;
	localparam OP_OR = 8'h0A, OP_NOT = 8'h0B, OP_CMP = 8'h0C, OP_EQ = 8'h0D;
	localparam OP_JMP = 8'h0E, OP_JMP_IF = 8'h0F;
	localparam OP_SHL = 8'h11, OP_SHR = 8'h12, OP_SAR = 8'h13;
	localparam OP_ADDI = 8'h16, OP_SUBI = 8'h17;
	localparam OP_BEQ = 8'h20, OP_BNE = 8'h21, OP_BLT = 8'h22, OP_BGE = 8'h23;
	localparam OP_HALT = 8'hFF;
	
	wire [11:0] imm12;

	assign opcode   = instr[31:24];
	assign rd_addr  = instr[23:20];
	assign rs1_addr = instr[19:16];
	assign rs2_addr = instr[15:12];
	assign imm12    = instr[11:0];

	always @(*) begin
		reg_write = 0; mem_read = 0; mem_write = 0; flag_we = 0; alu_b_imm = 0;
		is_branch = 0; is_halt = 0; use_rs1 = 0; use_rs2 = 0; use_rd = 0;
		imm_ext = {20'b0, imm12};                       // zero-extend by default

		case (opcode)
			OP_LOAD:      begin reg_write = 1; mem_read = 1; end
			OP_LOAD_IND:  begin reg_write = 1; mem_read = 1; use_rs1 = 1; end
			OP_LOAD_IMM:  begin reg_write = 1; alu_b_imm = 1; end
			OP_STORE:     begin mem_write = 1; use_rd = 1; end
			OP_STORE_IND: begin mem_write = 1; use_rd = 1; use_rs2 = 1; end
			OP_ADD, OP_SUB: begin reg_write = 1; flag_we = 4'b1111; use_rs1 = 1; use_rs2 = 1; end
			OP_MUL, OP_AND, OP_OR:
			              begin reg_write = 1; use_rs1 = 1; use_rs2 = 1; flag_we = 4'b0011; end
			OP_EQ:        begin reg_write = 1; use_rs1 = 1; use_rs2 = 1; flag_we = 4'b0001; end
			OP_SHL, OP_SHR, OP_SAR: begin reg_write = 1; use_rs1 = 1; use_rs2 = 1; flag_we = 4'b0011; end
			OP_NOT:       begin reg_write = 1; use_rs1 = 1; flag_we = 4'b0011; end
			OP_CMP:       begin flag_we = 4'b1111; use_rs1 = 1; use_rs2 = 1; end
			OP_ADDI, OP_SUBI: begin
				reg_write = 1; flag_we = 4'b1111; use_rs1 = 1; alu_b_imm = 1;
				imm_ext = {{20{imm12[11]}}, imm12};     // sign-extend
			end
			OP_JMP, OP_BEQ, OP_BNE, OP_BLT, OP_BGE: is_branch = 1;
			OP_JMP_IF:    begin is_branch = 1; use_rs1 = 1; end
			OP_HALT:      is_halt = 1;
			default: begin reg_write = 0; mem_read = 0; mem_write = 0; flag_we = 0; alu_b_imm = 0;
				       is_branch = 0; is_halt = 0; use_rs1 = 0; use_rs2 = 0; use_rd = 0;
				       imm_ext = {20'b0, imm12};
			end                                   // unknown opcode acts as NOP
		endcase
	end
endmodule