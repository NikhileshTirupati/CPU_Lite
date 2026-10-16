module mem_wb_reg (
	input  wire clk, rst_n, en,
	input  wire [31:0] alu_result_in, mem_rdata_in,
	input  wire [3:0]  rd_in,
	input  wire reg_write_in, mem_to_reg_in,
	output reg  [31:0] wb_data,
	output reg  [3:0]  wb_rd_addr,
	output reg         wb_write
);
	always @(posedge clk or negedge rst_n) begin
		if (!rst_n) begin
			wb_data <= 0; wb_rd_addr <= 0; wb_write <= 0;
		end else if (en) begin
			wb_data    <= mem_to_reg_in ? mem_rdata_in : alu_result_in;
			wb_rd_addr <= rd_in;
			wb_write   <= reg_write_in;
		end
	end
endmodule