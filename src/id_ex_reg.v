module id_ex_reg (
	input  wire clk, rst_n, en, flush,
	// from ID
	input  wire [7:0]  opcode_in,
	input  wire [3:0]  rd_in, rs1_in, rs2_in,
	input  wire [31:0] rs1_val_in, rs2_val_in, rd_val_in, imm_ext_in,
	input  wire reg_write_in, mem_read_in, mem_write_in,
	input  wire alu_b_imm_in, is_branch_in,
	input  wire [3:0] flag_we_in,
	// to EX
	output reg  [7:0]  opcode_ex,
	output reg  [3:0]  rd_ex, rs1_ex, rs2_ex,
	output reg  [31:0] rs1_val_ex, rs2_val_ex, rd_val_ex, imm_ext_ex,
	output reg  reg_write_ex, mem_read_ex, mem_write_ex,
	output reg  alu_b_imm_ex, is_branch_ex,
	output reg  [3:0] flag_we_ex
);
	always @(posedge clk or negedge rst_n) begin
		if (!rst_n) begin
			opcode_ex <= 0; rd_ex <= 0; rs1_ex <= 0; rs2_ex <= 0;
			rs1_val_ex <= 0; rs2_val_ex <= 0; rd_val_ex <= 0; imm_ext_ex <= 0;
			reg_write_ex <= 0; mem_read_ex <= 0; mem_write_ex <= 0;
			flag_we_ex <= 0; alu_b_imm_ex <= 0; is_branch_ex <= 0;
		end else if (en) begin
			if (flush) begin
				opcode_ex <= 0; rd_ex <= 0; rs1_ex <= 0; rs2_ex <= 0;
				rs1_val_ex <= 0; rs2_val_ex <= 0; rd_val_ex <= 0; imm_ext_ex <= 0;
				reg_write_ex <= 0; mem_read_ex <= 0; mem_write_ex <= 0;
				flag_we_ex <= 0; alu_b_imm_ex <= 0; is_branch_ex <= 0;
			end else begin
				opcode_ex <= opcode_in; rd_ex <= rd_in; rs1_ex <= rs1_in; rs2_ex <= rs2_in;
				rs1_val_ex <= rs1_val_in; rs2_val_ex <= rs2_val_in;
				rd_val_ex <= rd_val_in; imm_ext_ex <= imm_ext_in;
				reg_write_ex <= reg_write_in; mem_read_ex <= mem_read_in;
				mem_write_ex <= mem_write_in; flag_we_ex <= flag_we_in;
				alu_b_imm_ex <= alu_b_imm_in; is_branch_ex <= is_branch_in;
			end
		end
	end
endmodule