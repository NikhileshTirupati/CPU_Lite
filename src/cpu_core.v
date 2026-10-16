module cpu_core (
    input  wire        clk,
    input  wire        rst_n,

    // Instruction memory interface
    output wire [11:0] pc,
    input  wire [31:0] inst_if,

    // Data memory system interface (MEM stage)
    output wire        mem_read_mem,
    output wire        mem_write_mem,
    output wire [31:0] mem_addr_mem,
    output wire [31:0] store_data_mem,
    input  wire [31:0] dmem_rdata,
    input  wire        mem_ready,

    output wire        halted
);

    localparam OP_LOAD_IND  = 8'h02;
    localparam OP_STORE_IND = 8'h05;

    // ============================================================
    // Cross-stage wires
    // ============================================================
    wire        branch_taken;
    wire        load_use;
    wire        mem_stall;
    wire        front_en;

    wire [11:0] branch_target;

    wire        wb_write;
    wire [3:0]  wb_rd_addr;
    wire [31:0] wb_data;

    wire [31:0] alu_result_mem;

    wire [3:0]  rd_mem;

    wire        reg_write_mem;

    assign front_en = ~load_use & ~mem_stall;

    // ============================================================
    // IF
    // ============================================================
    wire [11:0] pc_next;

    wire [31:0] inst_id;

    wire        is_halt_id;
    wire        halt_now;
    wire        stop_fetch;

    reg         halted_r;

    assign pc_next =
            branch_taken ?
            branch_target :
            (pc + 12'd1);

    program_counter #(
        .ADDR_WIDTH(12)
    ) u_pc (
        .clk     (clk),
        .rst_n   (rst_n),
        .en      (front_en & ~stop_fetch),
        .pc_next (pc_next),
        .pc      (pc)
    );

    assign halt_now   = is_halt_id & ~branch_taken;
    assign stop_fetch = halted_r | halt_now;
    assign halted     = halted_r;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            halted_r <= 1'b0;
        else if (halt_now)
            halted_r <= 1'b1;
    end

    if_id_reg u_if_id (
        .clk     (clk),
        .rst_n   (rst_n),
        .en      (front_en),
        .flush   (branch_taken | stop_fetch),
        .inst_in (inst_if),
        .inst_out(inst_id)
    );

    // ============================================================
    // ID
    // ============================================================
    wire [7:0]  opcode_id;

    wire [3:0]  rd_id;
    wire [3:0]  rs1_id;
    wire [3:0]  rs2_id;

    wire [31:0] imm_ext_id;

    wire        reg_write_id;
    wire        mem_read_id;
    wire        mem_write_id;
    wire        alu_b_imm_id;
    wire        is_branch_id;

    wire [3:0]  flag_we_id;

    wire        use_rs1_id;
    wire        use_rs2_id;
    wire        use_rd_id;

    wire [31:0] rs1_val_id;
    wire [31:0] rs2_val_id;
    wire [31:0] rd_val_id;

    instruction_decoder u_dec (
        .instr     (inst_id),
        .opcode    (opcode_id),

        .rd_addr   (rd_id),
        .rs1_addr  (rs1_id),
        .rs2_addr  (rs2_id),

        .imm_ext   (imm_ext_id),

        .reg_write (reg_write_id),
        .mem_read  (mem_read_id),
        .mem_write (mem_write_id),

        .flag_we   (flag_we_id),
        .alu_b_imm (alu_b_imm_id),

        .is_branch (is_branch_id),
        .is_halt   (is_halt_id),

        .use_rs1   (use_rs1_id),
        .use_rs2   (use_rs2_id),
        .use_rd    (use_rd_id)
    );

    register_file u_rf (
        .clk     (clk),
        .rst_n   (rst_n),

        .r1_addr (rs1_id),
        .r1_data (rs1_val_id),

        .r2_addr (rs2_id),
        .r2_data (rs2_val_id),

        .r3_addr (rd_id),
        .r3_data (rd_val_id),

        .wr_en   (wb_write),
        .wr_addr (wb_rd_addr),
        .wr_data (wb_data)
    );

    // ============================================================
    // ID / EX
    // ============================================================
    wire [7:0] opcode_ex;

    wire [3:0] rd_ex;
    wire [3:0] rs1_ex;
    wire [3:0] rs2_ex;

    wire [31:0] rs1_val_ex;
    wire [31:0] rs2_val_ex;
    wire [31:0] rd_val_ex;
    wire [31:0] imm_ext_ex;

    wire        reg_write_ex;
    wire        mem_read_ex;
    wire        mem_write_ex;

    wire [3:0]  flag_we_ex;

    wire        alu_b_imm_ex;
    wire        is_branch_ex;

    id_ex_reg u_id_ex (
        .clk           (clk),
        .rst_n         (rst_n),
        .en            (~mem_stall),
        .flush         (branch_taken | load_use), // If any jmp is executed or load is being executed and stall is requiered

        .opcode_in     (opcode_id),
        .rd_in         (rd_id),
        .rs1_in        (rs1_id),
        .rs2_in        (rs2_id),

        .rs1_val_in    (rs1_val_id),
        .rs2_val_in    (rs2_val_id),
        .rd_val_in     (rd_val_id),

        .imm_ext_in    (imm_ext_id),

        .reg_write_in  (reg_write_id),
        .mem_read_in   (mem_read_id),
        .mem_write_in  (mem_write_id),

        .flag_we_in    (flag_we_id),
        .alu_b_imm_in  (alu_b_imm_id),
        .is_branch_in  (is_branch_id),

        .opcode_ex     (opcode_ex),
        .rd_ex         (rd_ex),
        .rs1_ex        (rs1_ex),
        .rs2_ex        (rs2_ex),

        .rs1_val_ex    (rs1_val_ex),
        .rs2_val_ex    (rs2_val_ex),
        .rd_val_ex     (rd_val_ex),

        .imm_ext_ex    (imm_ext_ex),

        .reg_write_ex  (reg_write_ex),
        .mem_read_ex   (mem_read_ex),
        .mem_write_ex  (mem_write_ex),

        .flag_we_ex    (flag_we_ex),
        .alu_b_imm_ex  (alu_b_imm_ex),
        .is_branch_ex  (is_branch_ex)
    );

    // ============================================================
    // Hazard detection
    // ============================================================
    hazard_unit u_haz (
        .mem_read_ex  (mem_read_ex),
        .rd_ex        (rd_ex),

        .use_rs1_id   (use_rs1_id),
        .use_rs2_id   (use_rs2_id),
        .use_rd_id    (use_rd_id),

        .rs1_id       (rs1_id),
        .rs2_id       (rs2_id),
        .rd_id        (rd_id),

        .mem_op_mem   (mem_read_mem | mem_write_mem),
        .mem_ready    (mem_ready),

        .load_use     (load_use),
        .mem_stall    (mem_stall)
    );

    // ============================================================
    // Forwarding
    // ============================================================
    wire [1:0] fwd_a_sel;
    wire [1:0] fwd_b_sel;
    wire [1:0] fwd_d_sel;

    forwarding_unit u_fwd (
        .rs1_ex       (rs1_ex),
        .rs2_ex       (rs2_ex),
        .rd_ex        (rd_ex),

        .rd_mem       (rd_mem),
        .reg_write_mem(reg_write_mem),

        .rd_wb        (wb_rd_addr),
        .reg_write_wb (wb_write),

        .fwd_a_sel    (fwd_a_sel),
        .fwd_b_sel    (fwd_b_sel),
        .fwd_d_sel    (fwd_d_sel)
    );

    // ============================================================
    // EX forwarding
    // ============================================================
    wire [31:0] fwd_a;
    wire [31:0] fwd_b;
    wire [31:0] fwd_d;

    assign fwd_a =
            (fwd_a_sel == 2'b01) ? alu_result_mem :
            (fwd_a_sel == 2'b10) ? wb_data :
                                   rs1_val_ex;

    assign fwd_b =
            (fwd_b_sel == 2'b01) ? alu_result_mem :
            (fwd_b_sel == 2'b10) ? wb_data :
                                   rs2_val_ex;

    assign fwd_d =
            (fwd_d_sel == 2'b01) ? alu_result_mem :
            (fwd_d_sel == 2'b10) ? wb_data :
                                   rd_val_ex;

    // ============================================================
    // EX - ALU
    // ============================================================
    wire [31:0] alu_a;
    wire [31:0] alu_b;

    wire [31:0] alu_result;
    wire [3:0]  alu_flags;

    assign alu_a = fwd_a;

    assign alu_b =
            alu_b_imm_ex ?
            imm_ext_ex :
            fwd_b;

    alu u_alu (
        .op_a    (alu_a),
        .op_b    (alu_b),
        .op_code (opcode_ex),

        .flags   (alu_flags),
        .result  (alu_result)
    );

    // ============================================================
    // PSR
    // ============================================================
    wire [3:0] psr_flags;

    psr u_psr (
        .clk      (clk),
        .rst_n    (rst_n),

        .flag_en  (flag_we_ex),
        .alu_flags(alu_flags),

        .flags    (psr_flags)
    );

    // ============================================================
    // Branch / PC control
    // ============================================================
    pc_control u_pcc (
        .op_code   (opcode_ex),
        .is_branch (is_branch_ex),

        .rs1_val   (fwd_a),

        .psr       (psr_flags),

        .taken     (branch_taken)
    );

    assign branch_target = imm_ext_ex[11:0];

    // ============================================================
    // Memory address generation
    // ============================================================
    wire [31:0] mem_addr_ex;

    assign mem_addr_ex =
            (opcode_ex == OP_LOAD_IND)  ? fwd_a :
            (opcode_ex == OP_STORE_IND) ? fwd_b :
                                          imm_ext_ex;

    // ============================================================
    // EX / MEM
    // ============================================================
    ex_mem_reg u_ex_mem (
        .clk           (clk),
        .rst_n         (rst_n),
        .en            (~mem_stall),

        .alu_result_in (alu_result),
        .mem_addr_in   (mem_addr_ex),
        .store_data_in (fwd_d),

        .rd_in         (rd_ex),

        .reg_write_in  (reg_write_ex),
        .mem_read_in   (mem_read_ex),
        .mem_write_in  (mem_write_ex),

        .alu_result_mem(alu_result_mem),
        .mem_addr_mem  (mem_addr_mem),
        .store_data_mem(store_data_mem),

        .rd_mem        (rd_mem),

        .reg_write_mem (reg_write_mem),
        .mem_read_mem  (mem_read_mem),
        .mem_write_mem (mem_write_mem)
    );

    // ============================================================
    // MEM
    // ============================================================
    // memory_system lives outside the core (in cpu_top):
    // request signals are exported, dmem_rdata / mem_ready are imported.

    // ============================================================
    // MEM / WB
    // ============================================================
    mem_wb_reg u_mem_wb (
        .clk           (clk),
        .rst_n         (rst_n),
        .en            (~mem_stall),

        .alu_result_in  (alu_result_mem),
        .mem_rdata_in   (dmem_rdata),

        .rd_in          (rd_mem),

        .reg_write_in   (reg_write_mem),
        .mem_to_reg_in  (mem_read_mem),

        .wb_data        (wb_data),
        .wb_rd_addr     (wb_rd_addr),
        .wb_write       (wb_write)
    );

endmodule