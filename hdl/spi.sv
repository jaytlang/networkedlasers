`timescale 1ns / 1ps

module spi(
    input logic         reset_in,
    input logic         clock_in,
    input logic [15:0]  data_in,
    input logic [5:0]   data_length_in,
    input logic         start_in,
    output logic        busy_out,

    output logic        sclk_out,
    output logic        mosi_out,
    output logic        cs_out
);

parameter PRESCALER = 1000;
logic [12:0] prescale_counter;
logic [5:0]  data_index;

always_ff @(posedge clock_in) begin
    if (reset_in) begin
        data_index <= 0;
        prescale_counter <= 0;
        
        busy_out <= 0;
        sclk_out <= 0;
        mosi_out <= 0;
        cs_out <= 1;
    end
    
    if (!reset_in && start_in && !busy_out) begin
            prescale_counter <= 0;
            mosi_out <= 0;
            data_index <= 0;
            cs_out <= 0;
        busy_out <= 1;
    end
    
    if (!reset_in && busy_out)begin
        // if we're not resetting, check if we need to start sending out data
        if (prescale_counter == 0) begin
            mosi_out <= data_in[data_index];
        end
        
        if (prescale_counter == PRESCALER/2) begin
            sclk_out <= !sclk_out;
        end

        if (prescale_counter == PRESCALER) begin
            sclk_out <= !sclk_out;
            data_index <= data_index + 1;
            prescale_counter <= 0;
        end
        
        else begin
            prescale_counter <= prescale_counter + 1;
        end


        if (data_index == data_length_in) begin
            mosi_out <= 0;
            cs_out <= 1;
            busy_out <= 0;        
        end
    end
end

endmodule
