module pc_control (
	input  wire [7:0]  op_code,
	input  wire        is_branch,
	input  wire [31:0] rs1_val,
	input  wire [3:0]  psr,        // [V,C,N,Z]
	output reg         taken
);
	always @(*) begin
		taken = 1'b0;
		if (is_branch) begin
			case (op_code)
				8'h0E:   taken = 1'b1;                    // JMP
				8'h0F:   taken = (rs1_val != 32'd0);      // JMP_IF
				8'h20:   taken = psr[0];                  // BEQ
				8'h21:   taken = ~psr[0];                 // BNE
				8'h22:   taken = psr[1] ^ psr[3];         // BLT
				8'h23:   taken = ~(psr[1] ^ psr[3]);      // BGE
				default: taken = 1'b0;
			endcase
		end
	end
endmodule