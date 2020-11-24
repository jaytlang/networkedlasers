`timescale 1ns / 1ps
module display_controller_tb();
    logic reset;
    logic clock;

    logic x_sclk, y_sclk;
    logic x_mosi, y_mosi;
    logic x_cs, y_cs;
    logic r_pwm, g_pwm, b_pwm;

    logic [7:0] pkt_buf_in [1518 -1 : 0];

    display_controller uut (.reset_in(reset),
                            .clock_in(clock),
                            .frame_delay(40000),

                            .pkt_buf_in(pkt_buf_in),
                            .x_sclk(x_sclk),
                            .x_mosi(x_mosi),
                            .x_cs(x_cs),
                            .y_sclk(y_sclk),
                            .y_mosi(y_mosi),
                            .y_cs(y_cs),

                            .r_pwm(r_pwm),
                            .g_pwm(g_pwm),
                            .b_pwm(b_pwm));

    // clk has 50% duty cycle, 10ns period
    always #5 clock = ~clock;

    initial begin
        pkt_buf_in[15] = 0;
        pkt_buf_in[16] = 0;
        pkt_buf_in[17] = 0;
        pkt_buf_in[18] = 0;
        pkt_buf_in[19] = 0;
        pkt_buf_in[20] = 0;
        pkt_buf_in[21] = 0;
        reset = 0;
        clock = 0;
        #20
        reset = 1;
        #20
        reset = 0;
        #20
        pkt_buf_in[15] = 8'h1;
        pkt_buf_in[16] = 8'h1;
        pkt_buf_in[17] = 8'h1;
        pkt_buf_in[18] = 8'h1;
        pkt_buf_in[19] = 8'h1;
        pkt_buf_in[20] = 8'h1;
        pkt_buf_in[21] = 8'h1;
        #20
        pkt_buf_in[15] = 8'h2;
        pkt_buf_in[16] = 8'h2;
        pkt_buf_in[17] = 8'h2;
        pkt_buf_in[18] = 8'h2;
        pkt_buf_in[19] = 8'h2;
        pkt_buf_in[20] = 8'h2;
        pkt_buf_in[21] = 8'h2;
        #20
        pkt_buf_in[15] = 8'h3;
        pkt_buf_in[16] = 8'h3;
        pkt_buf_in[17] = 8'h3;
        pkt_buf_in[18] = 8'h3;
        pkt_buf_in[19] = 8'h3;
        pkt_buf_in[20] = 8'h3;
        pkt_buf_in[21] = 8'h3;
        #20
        pkt_buf_in[15] = 8'h4;
        pkt_buf_in[16] = 8'h4;
        pkt_buf_in[17] = 8'h4;
        pkt_buf_in[18] = 8'h4;
        pkt_buf_in[19] = 8'h4;
        pkt_buf_in[20] = 8'h4;
        pkt_buf_in[21] = 8'h4;
        #20
        pkt_buf_in[15] = 8'h5;
        pkt_buf_in[16] = 8'h5;
        pkt_buf_in[17] = 8'h5;
        pkt_buf_in[18] = 8'h5;
        pkt_buf_in[19] = 8'h5;
        pkt_buf_in[20] = 8'h5;
        pkt_buf_in[21] = 8'h5;
        #20
        pkt_buf_in[15] = 8'h6;
        pkt_buf_in[16] = 8'h6;
        pkt_buf_in[17] = 8'h6;
        pkt_buf_in[18] = 8'h6;
        pkt_buf_in[19] = 8'h6;
        pkt_buf_in[20] = 8'h6;
        pkt_buf_in[21] = 8'h6;
        
        // change BRAM banks
        #20
        pkt_buf_in[15] = 8'hFF;
        pkt_buf_in[16] = 8'hFF;
        pkt_buf_in[17] = 8'hFF;
        pkt_buf_in[18] = 8'hFF;
        pkt_buf_in[19] = 8'hFF;
        pkt_buf_in[20] = 8'hFF;
        pkt_buf_in[21] = 8'hFF;
              
        #500
        pkt_buf_in[15] = 8'hFE;
        pkt_buf_in[16] = 8'hFE;
        pkt_buf_in[17] = 8'hFE;
        pkt_buf_in[18] = 8'hFE;
        pkt_buf_in[19] = 8'hFE;
        pkt_buf_in[20] = 8'hFE;
        pkt_buf_in[21] = 8'hFE; 
        #20
        pkt_buf_in[15] = 8'hFD;
        pkt_buf_in[16] = 8'hFD;
        pkt_buf_in[17] = 8'hFD;
        pkt_buf_in[18] = 8'hFD;
        pkt_buf_in[19] = 8'hFD;
        pkt_buf_in[20] = 8'hFD;
        pkt_buf_in[21] = 8'hFD; 
        #20
        pkt_buf_in[15] = 8'hFC;
        pkt_buf_in[16] = 8'hFC;
        pkt_buf_in[17] = 8'hFC;
        pkt_buf_in[18] = 8'hFC;
        pkt_buf_in[19] = 8'hFC;
        pkt_buf_in[20] = 8'hFC;
        pkt_buf_in[21] = 8'hFC; 
        #20
        pkt_buf_in[15] = 8'hFB;
        pkt_buf_in[16] = 8'hFB;
        pkt_buf_in[17] = 8'hFB;
        pkt_buf_in[18] = 8'hFB;
        pkt_buf_in[19] = 8'hFB;
        pkt_buf_in[20] = 8'hFB;
        pkt_buf_in[21] = 8'hFB; 
        #20
        pkt_buf_in[15] = 8'hFA;
        pkt_buf_in[16] = 8'hFA;
        pkt_buf_in[17] = 8'hFA;
        pkt_buf_in[18] = 8'hFA;
        pkt_buf_in[19] = 8'hFA;
        pkt_buf_in[20] = 8'hFA;
        pkt_buf_in[21] = 8'hFA;
        // change BRAM banks
        #20
        pkt_buf_in[15] = 8'hFF;
        pkt_buf_in[16] = 8'hFF;
        pkt_buf_in[17] = 8'hFF;
        pkt_buf_in[18] = 8'hFF;
        pkt_buf_in[19] = 8'hFF;
        pkt_buf_in[20] = 8'hFF;
        pkt_buf_in[21] = 8'hFF;
    end
endmodule
