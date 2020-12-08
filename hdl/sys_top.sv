`timescale 1ns / 1ps

/* Top level everything */
module sys_top(
    input logic         clk_100mhz,

    input logic         btnc,
    input logic[15:0]   sw,
    output logic[7:0]   ja, jb, jc, jd,

    output logic [7:0]  an,
    output logic        ca, cb, cc, cd, ce, cf, cg, dp,

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
    logic[31:0] display_data;
    logic[6:0] segments;
    
    /* All preliminary assignments */
    assign display_data = {netout[0], 
                           netout[1],
                           netout[2],
                           netout[3]};
                           
    assign {cg, cf, ce, cd, cc, cb, ca} = segments[6:0];

    /* All submodules here */

    
    hex_display           hd(.clk_in(sys_clk),
                             .data_in(display_data),
                             .seg_out(segments),
                             .strobe_out(an));
    
    eth_refclk_divider  erd(.in(clk_100mhz),
                            .out(sys_clk),
                            .reset(sys_rst));
    
    display_controller  dctl(.reset_in(sys_rst),
                             .clock_in(sys_clk),
                             .frame_delay(sw),
                             .pkt_buf_in(netout),
                             .pkt_buf_doorbell_in(netout_valid),

                             .x_sclk(jd[0]),
                             .x_mosi(jd[5]),
                             .x_cs(jd[4]),
                             .y_sclk(),
                             .y_mosi(jd[6]),
                             .y_cs(),

                             .r_pwm(jd[1]),
                             .g_pwm(jd[2]),
                             .b_pwm(jd[3]),
                             .frame_sync(jd[7]));
                
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