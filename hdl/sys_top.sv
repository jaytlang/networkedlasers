`timescale 1ns / 1ps

/* Top level everything */
module sys_top(
    input logic         clk_100mhz,

    input logic         btnc,

    input logic         eth_crsdv,
    input logic[1:0]    eth_rxd,

    output logic        eth_txen,
    output logic[1:0]   eth_txd,
    output logic        eth_refclk,
    output logic        eth_rstn,

    output logic[15:0] led
    );
    
    `include "offsets.svh"
    `include "errno.svh"
    
    logic sys_clk;
    logic sys_rst;
    
    logic[7:0] netout[ETH_MTU - 1:0];
    logic[15:0] netout_len;
    logic netout_valid;

    /* All submodules here */
    eth_refclk_divider  erd(.in(clk_100mhz),
                            .out(sys_clk),
                            .reset(sys_rst));
    
                
    netstack            netstack(.sys_clk(sys_clk),
                                 .sys_rst(sys_rst),
                                 .eth_crsdv(eth_crsdv),
                                 .eth_rxd(eth_rxd),
                                 .eth_txen(eth_txen),
                                 .eth_txd(eth_txd),
                                 .eth_refclk(eth_refclk),
                                 .eth_rstn(eth_rstn),
                                 .errno(led),
                                 .databuf(netout),
                                 .databuf_len(netout_len),
                                 .databuf_valid(netout_valid));
                                 
    /* All preliminary assignments here */
    assign sys_rst = btnc;

endmodule