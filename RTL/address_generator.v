`timescale 1ns / 1ps

module address_generator #(
    parameter IMG_HEIGHT = 28,
    parameter IMG_WIDTH  = 28,
    parameter NUM_FILTERS = 8
)(
    input  wire clk,
    input  wire rst_n,
    input  wire clear,          
    input  wire inc_filter,     
    input  wire inc_window,     
    
    output reg  [$clog2(NUM_FILTERS)-1:0] filter_cnt,
    
    output reg  [31:0] write_addr,
    
    output wire last_filter,    
    output wire done_all
);

    localparam OUT_H = IMG_HEIGHT - 2;
    localparam OUT_W = IMG_WIDTH - 2;
    localparam TOTAL_WINDOWS = OUT_H * OUT_W;

    reg [$clog2(OUT_H)-1:0] fmap_row;
    reg [$clog2(OUT_W)-1:0] fmap_col;
    reg [$clog2(TOTAL_WINDOWS+1)-1:0] windows_processed;

    // Status Signals
    assign last_filter = (filter_cnt == NUM_FILTERS - 1);
    assign done_all = (windows_processed == TOTAL_WINDOWS - 1); 

    // =========================================================================
    // Registered Address Calculation
    // =========================================================================
    // We calculate the address one cycle early and store it in a register.
    // This breaks the long critical path from Counters -> Multipliers -> RAM.
    always @(posedge clk) begin
        if (!rst_n || clear) 
            write_addr <= 0;
        else 
            write_addr <= (filter_cnt * TOTAL_WINDOWS) + (fmap_row * OUT_W) + fmap_col;
    end

    // Main Counter Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            filter_cnt <= 0;
            fmap_row <= 0; fmap_col <= 0;
            windows_processed <= 0;
        end else if (clear) begin
            filter_cnt <= 0;
            fmap_row <= 0; fmap_col <= 0;
            windows_processed <= 0;
        end else begin
            if (inc_filter) begin
                if (filter_cnt < NUM_FILTERS - 1)
                    filter_cnt <= filter_cnt + 1;
                else
                    filter_cnt <= 0; 
            end
            
            if (inc_window) begin
                filter_cnt <= 0; 
                windows_processed <= windows_processed + 1;
                
                if (fmap_col == OUT_W - 1) begin
                    fmap_col <= 0;
                    if (fmap_row == OUT_H - 1) 
                        fmap_row <= 0;
                    else 
                        fmap_row <= fmap_row + 1;
                end else begin
                    fmap_col <= fmap_col + 1;
                end
            end
        end
    end
endmodule