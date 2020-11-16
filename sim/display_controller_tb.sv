`timescale 1ns / 1ps
module display_controller_tb();
    logic reset;
    logic clock;

    logic x_sclk, y_sclk;
    logic x_mosi, y_mosi;
    logic x_cs, y_cs;
    logic r_pwm, g_pwm, b_pwm;

    display_controller uut (.reset_in(reset),
                            .clock_in(clock),
                            .frame_delay(100000),

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
        reset = 0;
        clock = 0;
        #20
        reset = 1;
        #20
        reset = 0;
    end
endmodule
