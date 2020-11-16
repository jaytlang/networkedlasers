`timescale 1ns / 1ps

module pwm(
    input logic         reset_in,
    input logic         clock_in,
    input logic [7:0]   value,

    output logic        pwm_out
);

parameter FREQ_PRESCALER = 4; // going to try 100kHz first 
logic [4:0] freq_prescaler_counter;
logic [7:0] duty_cycle_counter;

always_ff @(posedge clock_in) begin
    if (reset_in) begin
        pwm_out <= 0;
        freq_prescaler_counter <= 0;
        duty_cycle_counter <= 0;
    end else begin
        freq_prescaler_counter <= freq_prescaler_counter + 1;

        if(freq_prescaler_counter == FREQ_PRESCALER) begin
            freq_prescaler_counter <= 0;
            duty_cycle_counter <= duty_cycle_counter + 1;
        end

        pwm_out <= duty_cycle_counter > value ? 0:1;
    end
end

endmodule
