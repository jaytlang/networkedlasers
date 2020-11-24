`timescale 1ns / 1ps

module display_controller(
    input logic         reset_in,
    input logic         clock_in,
    input logic [15:0]  frame_delay,

    input logic [7:0]   pkt_buf_in [1518 - 1:0], // ETH_MTU - 1
    input logic         pkt_buf_doorbell_in,

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

    parameter ETH_DATA_START = 14;
    logic old_pkt_buf_doorbell;

    // BRAM framebuffer
    logic        bram_select; // 0 to read from 0 and write to 1, 1 to read from 1 and write to 0
    logic [14:0] bram_0_addr, bram_1_addr;
    logic [14:0] bram_0_max_addr, bram_1_max_addr;
    logic [63:0] bram_0_data_in, bram_1_data_in;
    logic [63:0] bram_0_data_out, bram_1_data_out;
    
    blk_mem_gen_0 bram0 (.addra(bram_0_addr),
                         .clka(clock_in),
                         .dina(bram_0_data_in),
                         .douta(bram_0_data_out),
                         .wea(bram_select),
                         .ena(1));

    blk_mem_gen_0 bram1 (.addra(bram_1_addr),
                        .clka(clock_in),
                        .dina(bram_1_data_in),
                        .douta(bram_1_data_out),
                        .wea(!bram_select),
                        .ena(1));

    logic [63:0] current_flattened_packet;
    assign current_flattened_packet = {pkt_buf_in[ETH_DATA_START-1], pkt_buf_in[ETH_DATA_START], 
                                       pkt_buf_in[ETH_DATA_START+1], pkt_buf_in[ETH_DATA_START+2],
                                       pkt_buf_in[ETH_DATA_START+3], pkt_buf_in[ETH_DATA_START+4],
                                       pkt_buf_in[ETH_DATA_START+5], pkt_buf_in[ETH_DATA_START+6], 8'hFF};

    // SPI controllers
    logic x_start, y_start;
    logic x_busy, y_busy;
    logic [15:0] x, y;
    logic [7:0] r, g, b;

    // State Machine
    logic [18:0] frame_delay_counter;
    
    
    // ILA
    ila_0               ila(.clk(clock_in),
                            .probe0(bram_0_addr),
                            .probe1(bram_1_addr),
                            .probe2(bram_0_data_in),
                            .probe3(bram_1_data_in),
                            .probe4(bram_0_data_out),
                            .probe5(bram_1_data_out),
                            .probe6(bram_select),
                            .probe7(current_flattened_packet),
                            .probe8(pkt_buf_doorbell_in),
                            .probe9(x),
                            .probe10(y),
                            .probe11(r),
                            .probe12(g),
                            .probe13(b));

    always_ff @(posedge clock_in) begin
        if(reset_in) begin
            bram_select <= 0;
            
            bram_0_addr <= 0;
            bram_1_addr <= 0;
            bram_0_max_addr <= 0;
            bram_1_max_addr <= 0;
            bram_0_data_in <= 0;
            bram_1_data_in <= 0;
            
            old_pkt_buf_doorbell <= 0;

            frame_delay_counter <= 0;
            x_start <= 0;
            y_start <= 0;
            frame_sync <= 0;
        end else begin
            // state machine that takes data from the packet buffer and stashes it in BRAM
            
            if (pkt_buf_doorbell_in && !old_pkt_buf_doorbell) begin
                // switch BRAM if we need to
                bram_select <= current_flattened_packet == 64'hFFFFFFFFFFFFFFFF ? !bram_select : bram_select;
                
                // load into BRAM
                bram_0_data_in <= current_flattened_packet;
                bram_1_data_in <= current_flattened_packet;

                // increment the address pointer of whatever BRAM is selected
                bram_0_addr <= bram_0_addr + (bram_select ? 1 : 0);
                bram_1_addr <= bram_1_addr + (bram_select ? 0 : 1);

                bram_0_max_addr <= bram_0_addr + (bram_select ? 1 : 0);
                bram_1_max_addr <= bram_1_addr + (bram_select ? 0 : 1);
            end
            
            old_pkt_buf_doorbell <= pkt_buf_doorbell_in;


            // state machine that gets pulls data from the active BRAM and writes it to the display 
            frame_delay_counter <= frame_delay_counter + 1;

            if(frame_delay_counter == frame_delay - 2) begin
                r = bram_select ? bram_1_data_out[15:8] : bram_0_data_out[15:8];
                g = bram_select ? bram_1_data_out[23:16] : bram_0_data_out[23:16];
                b = bram_select ? bram_1_data_out[31:24] : bram_0_data_out[31:24];
                y = bram_select ? bram_1_data_out[47:32] : bram_0_data_out[47:32];
                x = bram_select ? bram_1_data_out[63:48] : bram_0_data_out[63:48];

                x_start <= 1;
                y_start <= 1;
            end

            if(frame_delay_counter == frame_delay - 1) begin
                x_start <= 0;
                y_start <= 0;
                frame_sync <= ~frame_sync;
            end

            if(frame_delay_counter == frame_delay) begin
                frame_delay_counter <= 0;

                // update bram address, wrapping around if necessary
                if(!bram_select) begin
                    if(bram_0_addr == bram_0_max_addr) begin
                        bram_0_addr <= 0;
                    end else begin
                        bram_0_addr <= bram_0_addr + 1;
                    end
                end

                if(bram_select) begin
                    if(bram_1_addr == bram_1_max_addr) begin
                        bram_1_addr <= 0;
                    end else begin
                        bram_1_addr <= bram_1_addr + 1;
                    end
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