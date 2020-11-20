`timescale 1ns / 1ps

module display_controller(
    input logic         reset_in,
    input logic         clock_in,
    input logic [15:0]  frame_delay,
    
    input logic[7:0] net_in[1517:0],
    input logic net_in_valid,
    
    output logic x_sclk,
    output logic x_mosi,
    output logic x_cs,
    output logic y_sclk,
    output logic y_mosi,
    output logic y_cs,
    
    output logic r_pwm,
    output logic g_pwm,
    output logic b_pwm,

    output logic frame_sync
    );
    
    parameter X_LENGTH = 16; //how many bits in the memory address to allocate for X, Y, B, G, R
    parameter Y_LENGTH = 16;
    
    parameter B_LENGTH = 8;
    parameter G_LENGTH = 8;
    parameter R_LENGTH = 8;
    
    parameter MAX_PKT_LEN = 1518;
    
    // BRAM framebuffer
    logic [7:0] bram_handoff[1517:0];   // janky but whatever - jtl
    logic [31:0] bram_handoff_ctr;
    logic [14:0] bram_addr;
    logic [63:0] bram_data_in;
    logic [63:0] bram_data_out;
    logic bram_wea;
    
    blk_mem_gen_0 bram (.addra(bram_addr),
                        .clka(clock_in), 
                        .dina(bram_data_in), 
                        .douta(bram_data_out), 
                        .wea(bram_wea));  

    // SPI controllers
    logic x_start, y_start;
    logic x_busy, y_busy;
    logic [15:0] x, y;    
    logic [7:0] r, g, b;
    
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
            frame_sync <= 0;
            foreach(bram_handoff[i]) bram_handoff[i] <= 0;
            bram_handoff_ctr <= 0;
            bram_wea <= 0;
        end else begin
            // Stage zero: new data has arrived
            if(bram_handoff_ctr == 0 && net_in_valid == 1'b1) begin
                bram_handoff <= net_in;
                bram_handoff_ctr <= 32'h1;
                bram_wea <= 1'b0;
                
            // Stage one: data needs to be copied into BRAM
            //      Pretty sure that this gets the last 8 bits, but pls check me
            end else if(bram_handoff_ctr > 0 && bram_handoff_ctr < MAX_PKT_LEN) begin
                bram_addr <= (bram_handoff_ctr - 1) >> 3;
                bram_handoff_ctr <= bram_handoff_ctr + 8;
                bram_wea <= 1'b1;
                bram_data_in <= {bram_handoff_ctr[((bram_handoff_ctr - 1) >> 3) + 7],
                                 bram_handoff_ctr[((bram_handoff_ctr - 1) >> 3) + 6],
                                 bram_handoff_ctr[((bram_handoff_ctr - 1) >> 3) + 5],
                                 bram_handoff_ctr[((bram_handoff_ctr - 1) >> 3) + 4],
                                 bram_handoff_ctr[((bram_handoff_ctr - 1) >> 3) + 3],
                                 bram_handoff_ctr[((bram_handoff_ctr - 1) >> 3) + 2],
                                 bram_handoff_ctr[((bram_handoff_ctr - 1) >> 3) + 1],
                                 bram_handoff_ctr[((bram_handoff_ctr - 1) >> 3) + 0]};
            
            // Stage two: data has been copied, commence le drawing where we left off
            //      Note that bram_addr is trashed at this rate
            // Stage three: continue drawing knowing new data is coming in
            end else begin
                bram_wea <= 1'b0;
                if(net_in_valid == 1'b0) bram_handoff_ctr <= 0;
                
                frame_delay_counter <= frame_delay_counter + 1;
                
                if(frame_delay_counter == frame_delay - 2) begin
                    bram_addr <= bram_addr + 1;
                end
                
                if(frame_delay_counter == frame_delay - 1) begin
                    x_start <= 1;
                    y_start <= 1;
                end
                
                if(frame_delay_counter == frame_delay) begin
                    frame_delay_counter <= 0;
                    x_start <= 0;
                    y_start <= 0;
                    frame_sync <= ~frame_sync;
                end   
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

    pwm r_pwm_controller(
            .reset_in(reset_in),
            .clock_in(clock_in),
            .value(r),
            .pwm_out(r_pwm));
    
    pwm g_pwm_controller(
            .reset_in(reset_in),
            .clock_in(clock_in),
            .value(g),
            .pwm_out(g_pwm));
            
    pwm b_pwm_controller(
            .reset_in(reset_in),
            .clock_in(clock_in),
            .value(b),
            .pwm_out(b_pwm));    
endmodule
