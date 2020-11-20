`timescale 1ns / 1ps
module spi_tb();
    logic         reset;
    logic         clock;
    logic [15:0]  data;
    logic [5:0]   data_length;
    logic         start;
    logic         busy;

    logic         sclk;
    logic         mosi;
    logic         cs;

    // clk has 50% duty cycle, 10ns period
    always #5 clock = ~clock;

    initial begin
        reset = 0;
        clock = 0;
        data = 15'h3f3c;
        data_length = 16'd16;
        start = 0;
        
        #20
        reset = 1;
        #20
        reset = 0;
        #20
        start = 1;
        #20
        start = 0;        
    end
    
    

    spi      #(.PRESCALER(10)) 
           uut(.reset_in(reset),
            .clock_in(clock),
            .data_in(data),
            .data_length_in(data_length),
            .start_in(start),
            .busy_out(busy),
            
            .sclk_out(sclk),
            .mosi_out(mosi),
            .cs_out(cs));

endmodule
