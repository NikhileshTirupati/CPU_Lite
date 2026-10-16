`timescale 1ns / 1ps

module tb_cpu_core();

    // ============================================================
    // Configuration
    // ============================================================

    // Set to 0 to silence the per-cycle trace.
    localparam VERBOSE_TRACE = 1;

    // Number of clk_150 cycles to allow after HALT is detected.
    // Your CPU has IF -> ID -> EX -> MEM -> WB.
    localparam PIPELINE_DRAIN_CYCLES = 10;

    reg clk_150;
    reg clk_70;
    reg rst_n;

    integer pass_count = 0;
    integer fail_count = 0;

    // ============================================================
    // Clock generation
    // ============================================================

    initial begin
        clk_150 = 1'b0;
        forever #3.33 clk_150 = ~clk_150;
    end

    initial begin
        clk_70 = 1'b0;
        forever #7.14 clk_70 = ~clk_70;
    end

    // ============================================================
    // DUT
    // ============================================================

    cpu_top dut (
        .clk     (clk_150),
        .mem_clk (clk_70),
        .rst_n   (rst_n)
    );

    // ============================================================
    // HALT detection
    //
    // cpu_top already generates:
    //
    //     halted = halted_r
    //
    // Therefore use dut.halted rather than checking opcode_id.
    // ============================================================

    reg halt_detected;

    always @(posedge clk_150 or negedge rst_n) begin
        if (!rst_n)
            halt_detected <= 1'b0;
        else if (dut.halted)
            halt_detected <= 1'b1;
    end

    // ============================================================
    // Optional pipeline trace
    // ============================================================

    always @(posedge clk_150) begin

        if (VERBOSE_TRACE && rst_n) begin

            $display(
                "T=%0t PC=%03h IF=%08h ID=%08h OP_ID=%02h PSR=%01h R1=%08h R2=%08h R3=%08h R4=%08h R14=%08h R15=%08h ALU=%08h LOAD_USE=%b MEM_STALL=%b BRANCH=%b MEM_REQ=%b MEM_READY=%b HALTED=%b",
                $time,
                dut.pc,
                dut.inst_if,
                dut.inst_id,
                dut.opcode_id,
                dut.psr_flags,
                dut.u_rf.regs[1],
                dut.u_rf.regs[2],
                dut.u_rf.regs[3],
                dut.u_rf.regs[4],
                dut.u_rf.regs[14],
                dut.u_rf.regs[15],
                dut.alu_result,
                dut.load_use,
                dut.mem_stall,
                dut.branch_taken,
                (dut.mem_read_mem | dut.mem_write_mem),
                dut.mem_ready,
                dut.halted
            );

        end

    end

    // ============================================================
    // Program memory helper
    // ============================================================

    task write_instr(
        input integer addr,
        input [31:0] val
    );

        begin

            dut.u_imem.mem[addr] = val;

        end

    endtask

    // ============================================================
    // Clear program memory
    //
    // Every unused location contains HALT.
    // ============================================================

    task clear_program_mem;

        integer k;

        begin

            for (k = 0; k < 4096; k = k + 1)
                dut.u_imem.mem[k] = 32'hFF000000;

        end

    endtask

    // ============================================================
    // Reset
    // ============================================================

    task do_reset;

        begin

            rst_n = 1'b0;

            #50;

            rst_n = 1'b1;

            // Give the pipeline a few cycles to leave reset.
            repeat (5)
                @(posedge clk_150);

        end

    endtask

    // ============================================================
    // Pipeline drain
    //
    // HALT is recognized in ID.
    //
    // At that point older instructions can still be in:
    //
    //     EX
    //     MEM
    //     WB
    //
    // Therefore wait before checking results.
    // ============================================================

    task drain_pipeline;

        integer i;

        begin

            for (i = 0;
                 i < PIPELINE_DRAIN_CYCLES;
                 i = i + 1) begin

                @(posedge clk_150);

            end

        end

    endtask

    // ============================================================
    // Wait for HALT
    // ============================================================

    task wait_for_halt;

        input integer timeout_cycles;
        output reg timed_out;

        integer cyc;

        begin

            cyc = 0;
            timed_out = 1'b0;

            while (!halt_detected &&
                   cyc < timeout_cycles) begin

                @(posedge clk_150);

                cyc = cyc + 1;

            end

            if (!halt_detected) begin

                timed_out = 1'b1;

            end
            else begin

                // HALT reached the ID stage.
                // Allow the remaining pipeline instructions
                // to complete.
                drain_pipeline;

            end

        end

    endtask

    // ============================================================
    // Comparison helper
    // ============================================================

    task check_equal;

        input [31:0] actual;
        input [31:0] expected;
        input [335:0] what;

        begin

            if (actual === expected) begin

                pass_count = pass_count + 1;

                $display(
                    "  [PASS] %-42s got=0x%08h",
                    what,
                    actual
                );

            end
            else begin

                fail_count = fail_count + 1;

                $display(
                    "  [FAIL] %-42s got=0x%08h expected=0x%08h",
                    what,
                    actual,
                    expected
                );

            end

        end

    endtask

    // ============================================================
    // Register helper
    // ============================================================

    function [31:0] REG;

        input integer n;

        begin

            REG = dut.u_rf.regs[n];

        end

    endfunction

    // ============================================================
    // TEST 1
    //
    // Array sum:
    //
    // mem[0x100] ... mem[0x109]
    // result = 55
    // result stored at mem[0x200]
    //
    // Exercises:
    // LOAD_IMM
    // CMP
    // BGE
    // ADD
    // LOAD_IND
    // ADDI
    // JMP
    // STORE
    // HALT
    // ============================================================

    task load_test1_array_sum;

        begin

            clear_program_mem;

            write_instr( 0, 32'h03100100); // LOAD_IMM R1,#0x100 (base addr)
            write_instr( 1, 32'h0320000a); // LOAD_IMM R2,#10    (count)
            write_instr( 2, 32'h03300000); // LOAD_IMM R3,#0     (sum)
            write_instr( 3, 32'h03400000); // LOAD_IMM R4,#0     (i)
            write_instr( 4, 32'h0c042000); // loop: CMP R4,R2
            write_instr( 5, 32'h2300000b); // BGE ->11
            write_instr( 6, 32'h06514000); // ADD R5,R1,R4
            write_instr( 7, 32'h02650000); // LOAD_IND R6,R5
            write_instr( 8, 32'h06336000); // ADD R3,R3,R6
            write_instr( 9, 32'h16440001); // ADDI R4,R4,#1
            write_instr(10, 32'h0e000004); // JMP ->4
            write_instr(11, 32'h04300200); // STORE R3 -> [0x200]
            write_instr(12, 32'hff000000); // HALT

        end

    endtask

    // ============================================================
    // TEST 2
    //
    // ALU operations
    // ============================================================

    task load_test2_alu;

        begin

            clear_program_mem;

            write_instr( 0, 32'h03100005); // R1 = 5
            write_instr( 1, 32'h03200003); // R2 = 3

            write_instr( 2, 32'h06312000); // ADD
            write_instr( 3, 32'h07412000); // SUB
            write_instr( 4, 32'h08512000); // MUL
            write_instr( 5, 32'h09612000); // AND
            write_instr( 6, 32'h0A712000); // OR
            write_instr( 7, 32'h0B910000); // NOT

            write_instr( 8, 32'h03A00002); // R10 = 2

            write_instr(9, 32'h11B1A000); // SHL
            write_instr(10, 32'h12C1A000); // SHR
            write_instr(11, 32'h13D9A000); // SAR

            write_instr(12, 32'h16E1000A); // ADDI
            write_instr(13, 32'h17F10003); // SUBI

            write_instr(14, 32'hFF000000); // HALT

        end

    endtask

    // ============================================================
    // TEST 4
    //
    // Control flow
    // ============================================================

    task load_test4_control_flow;

        begin

            clear_program_mem;

            // R1 = 5
            write_instr( 0, 32'h03100005);

            // R2 = 5
            write_instr( 1, 32'h03200005);

            // CMP R1,R2
            write_instr( 2, 32'h0C012000);

            // BEQ -> 6
            write_instr( 3, 32'h20000006);

            // Wrong path
            write_instr( 4, 32'h03900EEE);
            write_instr( 5, 32'h0E000064);

            // Correct path
            write_instr( 6, 32'h03300001);
            write_instr( 7, 32'h03400003);

            // CMP R1,R4
            write_instr( 8, 32'h0C014000);

            // BNE -> 12
            write_instr( 9, 32'h2100000C);

            // Wrong path
            write_instr(10, 32'h03900EEE);
            write_instr(11, 32'h0E000064);

            // Correct path
            write_instr(12, 32'h03500001);

            // CMP R4,R1
            write_instr(13, 32'h0C041000);

            // BLT -> 17
            write_instr(14, 32'h22000011);

            // Wrong path
            write_instr(15, 32'h03900EEE);
            write_instr(16, 32'h0E000064);

            // Correct path
            write_instr(17, 32'h03600001);

            // CMP R1,R4
            write_instr(18, 32'h0C014000);

            // BGE -> 22
            write_instr(19, 32'h23000016);

            // Wrong path
            write_instr(20, 32'h03900EEE);
            write_instr(21, 32'h0E000064);

            // Correct path
            write_instr(22, 32'h03700001);

            // R10 = 0
            write_instr(23, 32'h03A00000);

            // JMP_IF R10 -> 27
            // Not taken
            write_instr(24, 32'h0F0A001B);

            // Fall-through
            write_instr(25, 32'h03B00001);

            // R10 = 1
            write_instr(26, 32'h03A00001);

            // JMP_IF R10 -> 30
            // Taken
            write_instr(27, 32'h0F0A001E);

            // Wrong path
            write_instr(28, 32'h03900EEE);
            write_instr(29, 32'h0E000064);

            // Correct path
            write_instr(30, 32'h03C00001);

            // JMP -> 33
            write_instr(31, 32'h0E000021);

            // Wrong path
            write_instr(32, 32'h03900EEE);

            // Correct path
            write_instr(33, 32'h03D00001);

            // EQ R1,R2
            write_instr(34, 32'h0DE12000);

            // EQ R1,R4
            write_instr(35, 32'h0DF14000);

            // HALT
            write_instr(36, 32'hFF000000);

        end

    endtask

    // ============================================================
    // TEST 5
    //
    // Direct LOAD and STORE_IND
    // ============================================================

    task load_test5_mem_addressing;

        begin

            clear_program_mem;

            // LOAD R2,[0x104]
            write_instr(0, 32'h01200104);

            // R3 = 7
            write_instr(1, 32'h03300007);

            // R4 = 0x210
            write_instr(2, 32'h03400210);

            // STORE_IND R3,[R4]
            write_instr(3, 32'h05304000);

            // HALT
            write_instr(4, 32'hFF000000);

        end

    endtask

    // ============================================================
    // TEST SEQUENCER
    // ============================================================

    reg timed_out;

    initial begin

        rst_n = 1'b0;

        // ========================================================
        // TEST 1
        // ========================================================

        $display("");
        $display("================================================");
        $display("TEST 1: Array Sum");
        $display("================================================");

        load_test1_array_sum;

        do_reset;

        wait_for_halt(10000, timed_out);

        if (timed_out) begin

            fail_count = fail_count + 1;

            $display(
                "  [FAIL] TIMEOUT waiting for HALT"
            );

        end
        else begin

            // Give CDC / slow memory time to finish.
            #2000;

            $display(
                "  Sum stored at 0x200 = %0d (0x%0h)",
                dut.u_mem.u_dmem.mem[14'h0200],
                dut.u_mem.u_dmem.mem[14'h0200]
            );

            check_equal(
                dut.u_mem.u_dmem.mem[14'h0200],
                32'd55,
                "sum(1..10) at mem[0x200]"
            );

        end

        // ========================================================
        // TEST 2
        // ========================================================

        $display("");
        $display("================================================");
        $display("TEST 2: ALU Operations");
        $display("================================================");

        load_test2_alu;

        do_reset;

        wait_for_halt(1000, timed_out);

        if (timed_out) begin

            fail_count = fail_count + 1;

            $display(
                "  [FAIL] TIMEOUT waiting for HALT"
            );

        end
        else begin

            check_equal(
                REG(3),
                32'd8,
                "ADD  R3=R1+R2"
            );

            check_equal(
                REG(4),
                32'd2,
                "SUB  R4=R1-R2"
            );

            check_equal(
                REG(5),
                32'd15,
                "MUL  R5=R1*R2"
            );

            check_equal(
                REG(6),
                32'd1,
                "AND  R6=R1&R2"
            );

            check_equal(
                REG(7),
                32'd7,
                "OR   R7=R1|R2"
            );

            check_equal(
                REG(9),
                32'hFFFFFFFA,
                "NOT  R9=~R1"
            );

            check_equal(
                REG(11),
                32'd20,
                "SHL  R11=R1<<2"
            );

            check_equal(
                REG(12),
                32'd1,
                "SHR  R12=R1>>2"
            );

            check_equal(
                REG(13),
                32'hFFFFFFFE,
                "SAR  R13=R9>>>2"
            );

            check_equal(
                REG(14),
                32'd15,
                "ADDI R14=R1+10"
            );

            check_equal(
                REG(15),
                32'd2,
                "SUBI R15=R1-3"
            );

        end

        

        // ========================================================
        // TEST 4
        // ========================================================

        $display("");
        $display("================================================");
        $display("TEST 4: Control Flow");
        $display("================================================");

        load_test4_control_flow;

        do_reset;

        wait_for_halt(3000, timed_out);

        if (timed_out) begin

            fail_count = fail_count + 1;

            $display(
                "  [FAIL] TIMEOUT waiting for HALT"
            );

        end
        else begin

            check_equal(
                REG(3),
                32'd1,
                "BEQ took correct branch"
            );

            check_equal(
                REG(5),
                32'd1,
                "BNE took correct branch"
            );

            check_equal(
                REG(6),
                32'd1,
                "BLT took correct branch"
            );

            check_equal(
                REG(7),
                32'd1,
                "BGE took correct branch"
            );

            check_equal(
                REG(11),
                32'd1,
                "JMP_IF not taken (cond=0)"
            );

            check_equal(
                REG(12),
                32'd1,
                "JMP_IF taken (cond!=0)"
            );

            check_equal(
                REG(13),
                32'd1,
                "JMP unconditional"
            );

            check_equal(
                REG(14),
                32'd1,
                "EQ R1==R2 -> 1"
            );

            check_equal(
                REG(15),
                32'd0,
                "EQ R1==R4 -> 0"
            );

            check_equal(
                REG(9),
                32'd0,
                "sentinel: no wrong branch taken"
            );

        end

        // ========================================================
        // TEST 5
        // ========================================================

        $display("");
        $display("================================================");
        $display("TEST 5: Memory Addressing");
        $display("================================================");

        load_test5_mem_addressing;

        do_reset;

        wait_for_halt(1000, timed_out);

        if (timed_out) begin

            fail_count = fail_count + 1;

            $display(
                "  [FAIL] TIMEOUT waiting for HALT"
            );

        end
        else begin

            // CDC + slow memory settling
            #2000;

            check_equal(
                REG(2),
                32'd5,
                "LOAD R2 <- mem[0x104]"
            );

            check_equal(
                dut.u_mem.u_dmem.mem[14'h0210],
                32'd7,
                "STORE_IND mem[0x210] <- R3"
            );

        end

        // ========================================================
        // SUMMARY
        // ========================================================

        $display("");
        $display("========================================");
        $display(
            "PIPELINED CPU TOTAL: %0d passed, %0d failed",
            pass_count,
            fail_count
        );
        $display("========================================");

        if (fail_count == 0)
            $display("ALL PIPELINED CPU TESTS PASSED");
        else
            $display("PIPELINED CPU TESTS FAILED");

        $finish;

    end

    // ============================================================
    // Global safety timeout
    // ============================================================

    initial begin

        #2000000;

        $display("");
        $display("========================================");
        $display(
            "GLOBAL TIMEOUT: simulation did not complete"
        );
        $display("========================================");

        $finish;

    end

endmodule