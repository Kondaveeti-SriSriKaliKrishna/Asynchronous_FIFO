`timescale 1ns/1ps

`include "asynchronous_fifo.v"

module tb;

    parameter DEPTH = 16;
    parameter WIDTH = 8;
    parameter PTR_WIDTH = $clog2(DEPTH); //4

    parameter WR_TP = 20; 
	parameter RD_TP = 10; 
	
	// WR_TP = 10, RD_TP = 20 for test_write_fast


    reg wr_clk;
    reg rd_clk;
    reg rst;

    reg [WIDTH-1:0] wdata;
    reg wr_en;
    wire full;
    wire wr_error;

    wire [WIDTH-1:0] rdata;
    reg rd_en;
    wire empty;
    wire rd_error;


    integer i;

    reg [8*30:1] testname;


    // SIMPLE SCOREBOARD MEMORY

    reg [WIDTH-1:0] expected_mem [0:DEPTH-1];

    integer expected_wr_ptr;
    integer expected_rd_ptr;

    integer pass_count;
    integer fail_count;


    // DUT

    asynchronous_fifo #(
        .DEPTH(DEPTH),
        .WIDTH(WIDTH),
        .PTR_WIDTH(PTR_WIDTH)
    ) dut (
        .wr_clk(wr_clk),
        .rd_clk(rd_clk),
        .rst(rst),

        .wdata(wdata),
        .wr_en(wr_en),
        .full(full),
        .wr_error(wr_error),

        .rdata(rdata),
        .rd_en(rd_en),
        .empty(empty),
        .rd_error(rd_error)
    );


    // WRITE CLOCK

    initial begin
        wr_clk = 0;
        forever #(WR_TP/2) wr_clk = ~wr_clk;
    end


    // READ CLOCK

    initial begin
        rd_clk = 0;
        forever #(RD_TP/2) rd_clk = ~rd_clk;
    end


    // TEST SELECTION

    initial begin

        $value$plusargs("testname=%0s", testname);

        $display("Selected test = %0s", testname);

        initialize();

        fifo_reset();


        case (testname)

            "basic":
                test_basic();

            "overflow":
                test_overflow();

            "underflow":
                test_underflow();

            "wrap":
                test_wrap();

            "concurrent":
                test_concurrent();

            "write_fast":
                test_write_faster();

            "read_fast":
                test_read_faster();

            "reset":
                test_reset();

            default:
                $display("ERROR: Unknown test '%s'", testname);

        endcase


        #100;

        print_result();

        $finish;

    end


    // INITIALIZATION

    task initialize;

        begin

            rst   = 1;
            wr_en = 0;
            rd_en = 0;
            wdata = 0;

            expected_wr_ptr = 0;
            expected_rd_ptr = 0;

            pass_count = 0;
            fail_count = 0;

        end

    endtask


    // RESET

    task fifo_reset;

        begin

            rst = 1;
            wr_en = 0;
            rd_en = 0;
            wdata = 0;

            #25;

            rst = 0;

            @(posedge wr_clk);
            @(posedge rd_clk);

        end

    endtask


    // WRITE TASK

    task write_fifo;

        input integer num_writes;

        integer k;

        begin

            for (k = 0; k < num_writes; k = k + 1) begin

                @(negedge wr_clk);

                wr_en = 1;
                wdata = $urandom_range(5,15);


                if (!full) begin

                    expected_mem[expected_wr_ptr] = wdata;

                    expected_wr_ptr = (expected_wr_ptr + 1) % DEPTH;

                    $display("%0t WRITE ACCEPTED : data=%h expected_ptr=%0d", $time, wdata, expected_wr_ptr);

                end

                else begin

                    $display("%0t WRITE BLOCKED : FIFO FULL, data=%h", $time, wdata);

                end

            end

            @(negedge wr_clk);

            wr_en = 0;
            wdata = 0;

        end

    endtask


    // READ AND CHECK TASK

    task read_and_check;

        input integer num_reads;

        integer k;

        reg [WIDTH-1:0] expected_data;

        reg read_was_allowed;


        begin

            for (k = 0; k < num_reads; k = k + 1) begin

                @(negedge rd_clk);

                rd_en = 1;

                read_was_allowed = !empty;


                if (read_was_allowed) begin

                    expected_data = expected_mem[expected_rd_ptr];

                end


                @(posedge rd_clk);

                #1;


                if (read_was_allowed) begin

                    if (rdata === expected_data) begin

                        $display("%0t READ PASS: expected=%h actual=%h", $time, expected_data, rdata);

                        pass_count = pass_count + 1;

                    end

                    else begin

                        $display("%0t READ FAIL: expected=%h actual=%h", $time, expected_data, rdata);

                        fail_count = fail_count + 1;

                    end


                    expected_rd_ptr = (expected_rd_ptr + 1) % DEPTH;

                end

                else begin

                    if (rd_error !== 1'b1) begin

                        $display("%0t READ FAIL: Expected rd_error=1", $time);

                        fail_count = fail_count + 1;

                    end

                    else begin

                        $display("%0t READ PASS: Underflow correctly detected", $time);

                        pass_count = pass_count + 1;

                    end

                end

            end


            @(negedge rd_clk);

            rd_en = 0;

        end

    endtask


    // TEST 1: BASIC

    task test_basic;

        begin

            $display("");
            $display("TEST: BASIC");


            write_fifo(8);


            // Wait for write pointer synchronization
            repeat (3) @(posedge rd_clk);

            read_and_check(8);

        end

    endtask


    // TEST 2: OVERFLOW

    task test_overflow;

        integer k;

        reg write_was_allowed;

        begin

            $display("");
            $display("TEST: OVERFLOW");

            for (k = 0; k < DEPTH + 1; k = k + 1) begin

                @(negedge wr_clk);

                wr_en = 1;
                wdata = k;

                write_was_allowed = !full;


                @(posedge wr_clk);

                #1;


                if (write_was_allowed) begin

                    expected_mem[expected_wr_ptr] = k;

                    expected_wr_ptr = (expected_wr_ptr + 1) % DEPTH;


                    $display("%0t PASS: Write accepted data=%h", $time, k);

                    pass_count = pass_count + 1;

                end

                else begin

                    if (wr_error === 1'b1) begin

                        $display("%0t PASS: Overflow detected", $time);

                        pass_count = pass_count + 1;

                    end

                    else begin

                        $display("%0t FAIL: wr_error should be 1", $time);

                        fail_count = fail_count + 1;

                    end

                end

            end


            @(negedge wr_clk);

            wr_en = 0;

        end

    endtask


    // TEST 3: UNDERFLOW

    task test_underflow;

        begin

            $display("");
            $display("TEST: UNDERFLOW");


            // FIFO is empty after reset.

            read_and_check(3);

        end

    endtask


    // TEST 4: POINTER WRAP

    task test_wrap;

        begin

            $display("");
            $display("TEST: POINTER WRAP");


            // First cycle

            write_fifo(DEPTH);

            repeat (4) @(posedge rd_clk);

            read_and_check(DEPTH);


            // Second cycle

            write_fifo(DEPTH);

            repeat (4) @(posedge rd_clk);

            read_and_check(DEPTH);

        end

    endtask


    // TEST 5: CONCURRENT READ / WRITE

    task test_concurrent;

        begin

            $display("");
            $display("TEST: CONCURRENT");


            fork

                write_fifo(32);

                begin

                    repeat (3) @(posedge rd_clk);

                    read_and_check(32);

                end

            join

        end

    endtask


    // TEST 6: WRITE CLOCK FASTER

    task test_write_faster;

        begin

            $display("");
            $display("TEST: CONCURRENT - WRITE FASTER");


            // WR_TP = 10 ns
            // RD_TP = 20 ns
            // Write clock is faster

            fork

                write_fifo(32);

                begin

                    repeat (3) @(posedge rd_clk);

                    read_and_check(32);

                end

            join

        end

    endtask


    // TEST 7: READ CLOCK FASTER

    task test_read_faster;

        begin

            $display("");
            $display("TEST: CONCURRENT - READ FASTER");


            // WR_TP = 20 ns
            // RD_TP = 10 ns
            // Read clock is faster.


            write_fifo(8);


            // Allow write pointer to synchronize

            repeat (3) @(posedge rd_clk);


            fork

                write_fifo(12);

                read_and_check(12);

            join

        end

    endtask


    // TEST 8: RESET

    task test_reset;

        begin

            $display("");
            $display("TEST: RESET");


            write_fifo(8);

            repeat (2) @(posedge rd_clk);


            rst = 1;

            #5;

            rst = 0;


            @(posedge wr_clk);
            @(posedge rd_clk);


            if (empty === 1'b1) begin

                $display("%0t PASS: FIFO empty after reset", $time);

                pass_count = pass_count + 1;

            end

            else begin

                $display("%0t FAIL: FIFO not empty after reset", $time);

                fail_count = fail_count + 1;

            end

        end

    endtask


    // FINAL RESULT

    task print_result;

        begin

            $display("");
            $display("====================================");
            $display("FINAL RESULT");
            $display("====================================");

            $display("PASS COUNT = %0d", pass_count);
            $display("FAIL COUNT = %0d", fail_count);


            if (fail_count == 0) begin

                $display("             TEST PASSED");

            end

            else begin

                $display("             TEST FAILED");

            end

            $display("====================================");

        end

    endtask

endmodule
