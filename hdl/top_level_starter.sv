module top_level(   input  logic            clk_100mhz,     // clock
                    input  logic [15:0]     sw,             // switches
                    input  logic            btnc,           // center button
                    input  logic            btnu,           // up button
                    input  logic            btnl,           // left button
                    input  logic            btnr,           // right button
                    input  logic            btnd,           // down button
                    output logic [7:0]      ja, jb, jc, jd,  // pmod headers
                    output logic [15:0]     led,        // little LEDs above switches
                    output logic            led16_b,    // blue channel left RGB LED
                    output logic            led16_g,    // green channel left RGB LED
                    output logic            led16_r,    // red channel left RGB LED
                    output logic            led17_b,    // blue channel right RGB LED
                    output logic            led17_g,    // green channel right RGB LED
                    output logic            led17_r     // red channel right RGB LED
    );

    // PMOD DA3 Pinout:
    // ja[0] - CS
    // ja[1] - MOSI
    // ja[2] - LDAC
    // ja[3] - SCLK

    assign led = sw;

    display_controller  dc (.reset_in(btnc),
                            .clock_in(clk_100mhz),
                            .frame_delay(sw),

                            .x_sclk(ja[3]),
                            .x_mosi(ja[1]),
                            .x_cs(ja[0]),

                            .y_sclk(jb[3]),
                            .y_mosi(jb[1]),
                            .y_cs(jb[0]),

                            .r_pwm(jc[0]),
                            .g_pwm(jc[1]),
                            .b_pwm(jc[2]),
                            .frame_sync(jc[3]));
endmodule