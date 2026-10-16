module forwarding_unit (
	input  wire [3:0] rs1_ex, rs2_ex, rd_ex,     // rd_ex = store-data source
	input  wire [3:0] rd_mem,  
	input wire reg_write_mem,
	input  wire [3:0] rd_wb,   
	input wire reg_write_wb,
	output wire [1:0] fwd_a_sel, fwd_b_sel, fwd_d_sel   // 00 regfile, 01 EX/MEM, 10 MEM/WB
);
	wire a_mem = reg_write_mem && (rd_mem == rs1_ex);
	wire a_wb  = reg_write_wb  && (rd_wb  == rs1_ex);
	wire b_mem = reg_write_mem && (rd_mem == rs2_ex);
	wire b_wb  = reg_write_wb  && (rd_wb  == rs2_ex);
	wire d_mem = reg_write_mem && (rd_mem == rd_ex);
	wire d_wb  = reg_write_wb  && (rd_wb  == rd_ex);

	assign fwd_a_sel = a_mem ? 2'b01 : a_wb ? 2'b10 : 2'b00;
	assign fwd_b_sel = b_mem ? 2'b01 : b_wb ? 2'b10 : 2'b00;
	assign fwd_d_sel = d_mem ? 2'b01 : d_wb ? 2'b10 : 2'b00;
endmodule