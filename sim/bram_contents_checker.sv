`timescale 1ns / 1ps


module bram_contents_checker();
    logic clk;
    logic [14:0] addr;
    logic [63:0] data_to_bram;
    logic [63:0] data_from_bram;
    logic write_enable;
   
    // clk has 50% duty cycle, 10ns period
    always #5 clk = ~clk;
    
    initial begin
        addr = 0;
        data_to_bram = 0;
        write_enable = 0;
        clk = 0;
        
        #20
        addr = 1;
        #20
        addr = 2;
        #20
        addr = 3;
        #20
        addr = 4;
        #20
        addr = 5;
        #20
        addr = 6;
        #20
        addr = 7;
        #20
        addr = 8;
        #20
        addr = 9;
        
       
    end
    
    blk_mem_gen_0 mybram(.addra(addr), .clka(clk), 
              .dina(data_to_bram), 
              .douta(data_from_bram), 
              .wea(write_enable));  
             
endmodule
