`timescale 1ns / 1ps

module sliding_window_3x3 #(
    parameter IMG_WIDTH = 28
)(
    input  wire        clk,
    input  wire        rst_n,
    input  wire        pixel_valid,
    input  wire  [7:0]  pixel_in,
    output reg         win_valid,
    output reg  [7:0]  w0, w1, w2, w3, w4, w5, w6, w7, w8
);

    // Line buffers - store 2 complete rows
    reg  [7:0] line0 [0:IMG_WIDTH-1];  // Oldest row
    reg  [7:0] line1 [0:IMG_WIDTH-1];  // Middle row
    
    // Position tracking
    reg [$clog2(IMG_WIDTH):0] col;
    reg [15:0] row;
    
    // Window buffers - hold current 3x3 window
    reg [7:0] win_buf [0:2][0:2];  // [row][col]
    
    integer i, j;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            col <= 0;
            row <= 0;
            win_valid <= 0;
            
            for (i = 0; i < IMG_WIDTH; i = i + 1) begin
                line0[i] <= 0;
                line1[i] <= 0;
            end
            
            for (i = 0; i < 3; i = i + 1) begin
                for (j = 0; j < 3; j = j + 1) begin
                    win_buf[i][j] <= 0;
                end
            end
            
            w0 <= 0; w1 <= 0; w2 <= 0;
            w3 <= 0; w4 <= 0; w5 <= 0;
            w6 <= 0; w7 <= 0; w8 <= 0;
            
        end else if (pixel_valid) begin
            
            // Shift window columns left
            win_buf[0][0] <= win_buf[0][1];
            win_buf[0][1] <= win_buf[0][2];
            win_buf[1][0] <= win_buf[1][1];
            win_buf[1][1] <= win_buf[1][2];
            win_buf[2][0] <= win_buf[2][1];
            win_buf[2][1] <= win_buf[2][2];
            
            // Load new column from line buffers + current pixel
            win_buf[0][2] <= line0[col];
            win_buf[1][2] <= line1[col];
            win_buf[2][2] <= pixel_in;
            
            // Update line buffers
            line0[col] <= line1[col];
            line1[col] <= pixel_in;
            
            // Update position counters
            if (col == IMG_WIDTH - 1) begin
                col <= 0;
                row <= row + 1;
            end else begin
                col <= col + 1;
            end
            
            // Valid signal
            win_valid <= (row >= 2) && (col >= 2);
            
            // ========================================
            // KEY FIX: Output what the window WILL BE after the shift
            // ========================================
            // After shift, win_buf[*][0] will contain win_buf[*][1]
            // After shift, win_buf[*][1] will contain win_buf[*][2]
            // After shift, win_buf[*][2] will contain the new column data
            
            w0 <= win_buf[0][1];  // Will become win_buf[0][0] after shift
            w1 <= win_buf[0][2];  // Will become win_buf[0][1] after shift
            w2 <= line0[col];     // Will become win_buf[0][2] after shift
            
            w3 <= win_buf[1][1];
            w4 <= win_buf[1][2];
            w5 <= line1[col];
            
            w6 <= win_buf[2][1];
            w7 <= win_buf[2][2];
            w8 <= pixel_in;
            
        end else begin
            win_valid <= 0;
        end
    end

endmodule