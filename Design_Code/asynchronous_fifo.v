`timescale 1ns/1ps

module asynchronous_fifo #(
    parameter DEPTH = 16,
    parameter WIDTH = 8,
    parameter PTR_WIDTH = $clog2(DEPTH) //4
)(
    input wr_clk,
    input rd_clk,
    input rst,

    input [WIDTH-1:0] wdata,
    input wr_en,
    output reg full,
    output wr_error,

    output reg [WIDTH-1:0] rdata,
    input rd_en,
    output reg empty,
    output rd_error
);

    // Internal variables

    // Binary pointers
    // Extra MSB is used for wrap-around detection.
    reg [PTR_WIDTH:0] wr_ptr_bin;
    reg [PTR_WIDTH:0] rd_ptr_bin;

    // Gray code pointers
    reg [PTR_WIDTH:0] wr_ptr_gray;
    reg [PTR_WIDTH:0] rd_ptr_gray;

    // Synchronized pointers
    // Write pointer synchronized into read-clock domain
    reg [PTR_WIDTH:0] wr_ptr_rd_clk;
    reg [PTR_WIDTH:0] wr_ptr_rd_clk_q;

    // Read pointer synchronized into write-clock domain
    reg [PTR_WIDTH:0] rd_ptr_wr_clk;
    reg [PTR_WIDTH:0] rd_ptr_wr_clk_q;

    // Next-state variables
    wire [PTR_WIDTH:0] wr_ptr_bin_next;
    wire [PTR_WIDTH:0] rd_ptr_bin_next;

    wire [PTR_WIDTH:0] wr_ptr_gray_next;
    wire [PTR_WIDTH:0] rd_ptr_gray_next;

    wire full_next;
    wire empty_next;

    // FIFO memory
    reg [WIDTH-1:0] mem [0:DEPTH-1];


    // Binary to Gray conversion
    function [PTR_WIDTH:0] bin_to_gray;
        input [PTR_WIDTH:0] binary_value;
        begin
            bin_to_gray = (binary_value >> 1) ^ binary_value;
        end
    endfunction


    // WRITE POINTER NEXT STATE

    assign wr_ptr_bin_next =
        (wr_en && !full) ? (wr_ptr_bin + 1'b1) : wr_ptr_bin;

    assign wr_ptr_gray_next =
        bin_to_gray(wr_ptr_bin_next);


    // READ POINTER NEXT STATE

    assign rd_ptr_bin_next =
        (rd_en && !empty) ? (rd_ptr_bin + 1'b1) : rd_ptr_bin;

    assign rd_ptr_gray_next =
        bin_to_gray(rd_ptr_bin_next);


    // FULL DETECTION
    // FIFO is full when the next write pointer reaches
    // the read pointer with the two MSBs inverted.

    assign full_next =
        (wr_ptr_gray_next ==
        {~rd_ptr_wr_clk[PTR_WIDTH:PTR_WIDTH-1],
          rd_ptr_wr_clk[PTR_WIDTH-2:0]});


    // EMPTY DETECTION
    // FIFO is empty when the next read pointer
    // is equal to the synchronized write pointer.

    assign empty_next =
        (rd_ptr_gray_next == wr_ptr_rd_clk);


    // WRITE CLOCK DOMAIN

    always @(posedge wr_clk or posedge rst) begin

        if (rst) begin
            wr_ptr_bin <= 0;
            wr_ptr_gray <= 0;
            full <= 0;
        end

        else begin

            // Write data into FIFO memory
            if (wr_en && !full) begin
                mem[wr_ptr_bin[PTR_WIDTH-1:0]] <= wdata;
            end

            wr_ptr_bin <= wr_ptr_bin_next;
            wr_ptr_gray <= wr_ptr_gray_next;
            full <= full_next;
        end
    end


    // READ CLOCK DOMAIN

    always @(posedge rd_clk or posedge rst) begin

        if (rst) begin
            rd_ptr_bin <= 0;
            rd_ptr_gray <= 0;
            empty <= 1;
            rdata <= 0;
        end

        else begin

            // Read data from FIFO memory
            if (rd_en && !empty) begin
                rdata <= mem[rd_ptr_bin[PTR_WIDTH-1:0]];
            end

            rd_ptr_bin <= rd_ptr_bin_next;
            rd_ptr_gray <= rd_ptr_gray_next;
            empty <= empty_next;

        end

    end


    // WRITE POINTER CDC
    // Synchronize write pointer into read-clock domain
    // using two flip-flop stages.

    always @(posedge rd_clk or posedge rst) begin

        if (rst) begin
            wr_ptr_rd_clk <= 0;
            wr_ptr_rd_clk_q <= 0;
        end

        else begin
            wr_ptr_rd_clk_q <= wr_ptr_gray;
            wr_ptr_rd_clk <= wr_ptr_rd_clk_q;
        end
    end


    // READ POINTER CDC
    // Synchronize read pointer into write-clock domain
    // using two flip-flop stages.

    always @(posedge wr_clk or posedge rst) begin

        if (rst) begin
            rd_ptr_wr_clk <= 0;
            rd_ptr_wr_clk_q <= 0;
        end

        else begin
            rd_ptr_wr_clk_q <= rd_ptr_gray;
            rd_ptr_wr_clk <= rd_ptr_wr_clk_q;
        end

    end


    // ERROR FLAGS

    assign wr_error = wr_en && full;

    assign rd_error = rd_en && empty;

endmodule
