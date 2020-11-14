`timescale 1ns / 1ps

module display_controller(
    input logic         reset_in,
    input logic         clock_in,
    input logic [15:0]  frame_delay,
    
    output logic x_sclk,
    output logic x_mosi,
    output logic x_cs,
    output logic y_sclk,
    output logic y_mosi,
    output logic y_cs,
    
    output logic b_sclk,
    output logic b_mosi,
    output logic b_cs,
    output logic r_sclk,
    output logic r_mosi,
    output logic r_cs,
    output logic g_sclk,
    output logic g_mosi,
    output logic g_cs
    );
    
    parameter X_LENGTH = 16; //how many bits in the memory address to allocate for X, Y, B, G, R
    parameter Y_LENGTH = 16;
    
    parameter B_LENGTH = 8;
    parameter G_LENGTH = 8;
    parameter R_LENGTH = 8;
    
    // BRAM framebuffer
    logic [14:0] bram_addr;
    logic [63:0] bram_data_in;
    logic [63:0] bram_data_out;
    
    blk_mem_gen_0 bram (.addra(bram_addr),
                        .clka(clock_in), 
                        .dina(bram_data_in), 
                        .douta(bram_data_out), 
                        .wea(0));  

    
    // SPI controllers
    logic x_start, y_start, b_start, g_start, r_start;
    logic x_busy, y_busy, b_busy, g_busy, r_busy;
    logic [15:0] x, y;
    logic [7:0] b, g, r;
    
    
    // State Machine
    
    assign x = bram_data_out[55:40];
    assign y = bram_data_out[39:24];
    assign b = bram_data_out[23:16];
    assign g = bram_data_out[15:8];
    assign r = bram_data_out[7:0];
    
    logic [18:0] frame_delay_counter;
    
    always_ff @(posedge clock_in) begin
        if(reset_in) begin
            bram_addr <= 0;
            frame_delay_counter <= 0;
            x_start <= 0;
            y_start <= 0;
            b_start <= 0;
            g_start <= 0;
            r_start <= 0;
        end else begin
            frame_delay_counter <= frame_delay_counter + 1;
            
            if(frame_delay_counter == frame_delay - 2) begin
                bram_addr <= bram_addr + 1;
            end
            
            if(frame_delay_counter == frame_delay - 1) begin
                x_start <= 1;
                y_start <= 1;
                b_start <= 1;
                g_start <= 1;
                r_start <= 1;
            end
            
            if(frame_delay_counter == frame_delay) begin
                frame_delay_counter <= 0;
                x_start <= 0;
                y_start <= 0;
                b_start <= 0;
                g_start <= 0;
                r_start <= 0; 
            end            
        end
    end
        
    
    spi x_spi_controller(
            .reset_in(reset_in),
            .clock_in(clock_in),
            .data_in(x),
            .data_length_in(X_LENGTH),
            .start_in(x_start),
            .busy_out(x_busy),
            
            .sclk_out(x_sclk),
            .mosi_out(x_mosi),
            .cs_out(x_cs));
            
    spi y_spi_controller(
            .reset_in(reset_in),
            .clock_in(clock_in),
            .data_in(y),
            .data_length_in(Y_LENGTH),
            .start_in(y_start),
            .busy_out(y_busy),
            
            .sclk_out(y_sclk),
            .mosi_out(y_mosi),
            .cs_out(y_cs));
   
    spi b_spi_controller(
            .reset_in(reset_in),
            .clock_in(clock_in),
            .data_in(b),
            .data_length_in(B_LENGTH),
            .start_in(b_start),
            .busy_out(b_busy),
            
            .sclk_out(b_sclk),
            .mosi_out(b_mosi),
            .cs_out(b_cs));
            
    spi g_spi_controller(
            .reset_in(reset_in),
            .clock_in(clock_in),
            .data_in(g),
            .data_length_in(G_LENGTH),
            .start_in(g_start),
            .busy_out(g_busy),
            
            .sclk_out(g_sclk),
            .mosi_out(g_mosi),
            .cs_out(g_cs));
    
    spi r_spi_controller(
            .reset_in(reset_in),
            .clock_in(clock_in),
            .data_in(r),
            .data_length_in(R_LENGTH),
            .start_in(r_start),
            .busy_out(r_busy),
            
            .sclk_out(r_sclk),
            .mosi_out(r_mosi),
            .cs_out(r_cs));
    
endmodule
