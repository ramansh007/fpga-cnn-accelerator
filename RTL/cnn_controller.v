`timescale 1ns / 1ps

module cnn_controller (
    input  wire clk,
    input  wire rst_n,
    input  wire start,
    
    input  wire win_valid,          
    input  wire conv_done,          
    input  wire last_filter,        
    input  wire done_all_windows,   
    input  wire pool_done,          
    
    output reg  addr_clear,         
    output reg  conv_start,         
    output reg  ram_we,             
    output reg  inc_filter,         
    output reg  inc_window,         
    output reg  pool_start,         
    output wire is_streaming,       
    output wire is_shifting         
);

    localparam IDLE         = 4'd0,
               STREAM_ALL   = 4'd1,
               SHIFT_NEXT   = 4'd2,
               SETUP_CONV   = 4'd3,
               PROCESS_CONV = 4'd4,
               CONV_WAIT    = 4'd5,
               STORE_RESULT = 4'd6,
               CHECK_LOOP   = 4'd7,
               WAIT_POOL    = 4'd8,
               POOLING_ACT  = 4'd9;

    reg [3:0] state;

    assign is_streaming = (state == STREAM_ALL);
    assign is_shifting  = (state == SHIFT_NEXT);

    always @(posedge clk ) begin
        if (!rst_n) begin
            state <= IDLE;
            addr_clear <= 0; conv_start <= 0; ram_we <= 0;
            inc_filter <= 0; inc_window <= 0; pool_start <= 0;
        end else begin
            // Clear pulses
            addr_clear <= 0; conv_start <= 0; ram_we <= 0;
            inc_filter <= 0; inc_window <= 0; pool_start <= 0;

            case (state)
                IDLE: begin
                    if (start) begin
                        state <= STREAM_ALL;
                        addr_clear <= 1; 
                    end
                end

                STREAM_ALL:   if (win_valid) state <= SETUP_CONV;
                SHIFT_NEXT:   state <= STREAM_ALL;
                SETUP_CONV:   state <= PROCESS_CONV;
                
                PROCESS_CONV: begin
                    conv_start <= 1;
                    state <= CONV_WAIT;
                end

                CONV_WAIT:    if (conv_done) state <= STORE_RESULT;

                STORE_RESULT: begin
                    ram_we <= 1; 
                    state <= CHECK_LOOP;
                end

                CHECK_LOOP: begin
                    if (!last_filter) begin
                        // Case 1: More filters for THIS window
                        inc_filter <= 1; 
                        state <= SETUP_CONV;
                    end else begin
                        // Case 2: Last filter done. Check if it was the Last Window.
                        if (done_all_windows) begin
                            // Do NOT increment window. Go straight to pooling.
                            state <= WAIT_POOL; 
                        end else begin
                            // Not done yet, move to next window
                            inc_window <= 1; 
                            state <= SHIFT_NEXT; 
                        end
                    end
                end
                
                WAIT_POOL: begin
                    pool_start <= 1;
                    state <= POOLING_ACT;
                end
                
                POOLING_ACT: if (pool_done) state <= IDLE;
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule