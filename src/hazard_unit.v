module hazard_unit (
	// instruction in EX
	input  wire       mem_read_ex,
	input  wire [3:0] rd_ex,
	// instruction in ID
	input  wire       use_rs1_id, use_rs2_id, use_rd_id,
	input  wire [3:0] rs1_id, rs2_id, rd_id,
	// instruction in MEM
	input  wire       mem_op_mem,     // mem_read_mem | mem_write_mem
	input  wire       mem_ready,      // cache done (hit or fill complete)
	output wire       load_use,
	output wire       mem_stall
);
	assign load_use = mem_read_ex &&
	                  ((use_rs1_id && rs1_id == rd_ex) ||
	                   (use_rs2_id && rs2_id == rd_ex) ||
	                   (use_rd_id  && rd_id  == rd_ex));

	assign mem_stall = mem_op_mem & ~mem_ready;
endmodule