`timescale 1ns / 1ps

/* CRC32-BZIP2 implementation for the Ethernet
 * stack. Takes in two bits at a time.
 *
 * This code was generated with the help of CRCGEN.PL v1.7
 */

// Disclaimer: THESE DESIGNS ARE PROVIDED "AS IS" WITH NO WARRANTY
//             WHATSOEVER AND XILINX SPECIFICALLY DISCLAIMS ANY
//             IMPLIED WARRANTIES OF MERCHANTABILITY, FITNESS FOR
//             A PARTICULAR PURPOSE, OR AGAINST INFRINGEMENT.
//
// Copyright (c) 2001,2002 Xilinx, Inc.  All rights reserved.

module crc32_bzip2(
    input logic[1:0]    d,
    input logic         calc,
    input logic         init,
    input logic         d_valid,
    input logic         clk,
    input logic         reset,

    output logic[31:0]  crc_reg,
    output logic[1:0]   crc
    );

    //////////////////////////////////////////////////////////////////////////////
    // Internal Signals
    //////////////////////////////////////////////////////////////////////////////
    wire   [31:0] next_crc;

    //////////////////////////////////////////////////////////////////////////////
    // Infer CRC-32 registers
    //
    // The crc_reg register stores the CRC-32 value.
    // The crc register is the most significant 2 bits of the
    // CRC-32 value.
    //
    // Truth Table:
    // -----+---------+----------+----------------------------------------------
    // calc | d_valid | crc_reg  | crc
    // -----+---------+----------+----------------------------------------------
    //  0   |     0   | crc_reg  | crc
    //  0   |     1   |  shift   | bit-swapped, complimented msbyte of crc_reg
    //  1   |     0   | crc_reg  | crc
    //  1   |     1   | next_crc | bit-swapped, complimented msbyte of next_crc
    // -----+---------+----------+----------------------------------------------
    //
    //////////////////////////////////////////////////////////////////////////////

    always @ (posedge clk or posedge reset)
    begin
       if (reset) begin
          crc_reg <= 32'hFFFFFFFF;
          crc     <= 2'hF;
       end

       else if (init) begin
          crc_reg <= 32'hFFFFFFFF;
          crc     <=  2'hF;
       end

       else if (calc & d_valid) begin
          crc_reg <= next_crc;
          crc     <= ~{next_crc[30], next_crc[31]};
       end

       else if (~calc & d_valid) begin
          crc_reg <=  {crc_reg[29:0], 2'hF};
          crc     <= ~{crc_reg[28], crc_reg[29]};
       end
    end

    //////////////////////////////////////////////////////////////////////////////
    // CRC XOR equations
    //////////////////////////////////////////////////////////////////////////////

    assign next_crc[0] = d[1] ^ crc_reg[30];
    assign next_crc[1] = d[0] ^ d[1] ^ crc_reg[30] ^ crc_reg[31];
    assign next_crc[2] = crc_reg[31] ^ crc_reg[30] ^ d[1] ^ d[0] ^ crc_reg[0];
    assign next_crc[3] = crc_reg[31] ^ d[0] ^ crc_reg[1];
    assign next_crc[4] = crc_reg[30] ^ d[1] ^ crc_reg[2];
    assign next_crc[5] = crc_reg[3] ^ d[0] ^ d[1] ^ crc_reg[30] ^ crc_reg[31];
    assign next_crc[6] = crc_reg[31] ^ d[0] ^ crc_reg[4];
    assign next_crc[7] = crc_reg[30] ^ crc_reg[5] ^ d[1];
    assign next_crc[8] = crc_reg[30] ^ crc_reg[31] ^ crc_reg[6] ^ d[0] ^ d[1];
    assign next_crc[9] = d[0] ^ crc_reg[7] ^ crc_reg[31];
    assign next_crc[10] = crc_reg[30] ^ crc_reg[8] ^ d[1];
    assign next_crc[11] = crc_reg[31] ^ crc_reg[30] ^ d[1] ^ crc_reg[9] ^ d[0];
    assign next_crc[12] = d[0] ^ d[1] ^ crc_reg[10] ^ crc_reg[30] ^ crc_reg[31];
    assign next_crc[13] = d[0] ^ crc_reg[11] ^ crc_reg[31];
    assign next_crc[14] = crc_reg[12];
    assign next_crc[15] = crc_reg[13];
    assign next_crc[16] = crc_reg[14] ^ d[1] ^ crc_reg[30];
    assign next_crc[17] = crc_reg[31] ^ d[0] ^ crc_reg[15];
    assign next_crc[18] = crc_reg[16];
    assign next_crc[19] = crc_reg[17];
    assign next_crc[20] = crc_reg[18];
    assign next_crc[21] = crc_reg[19];
    assign next_crc[22] = d[1] ^ crc_reg[20] ^ crc_reg[30];
    assign next_crc[23] = d[0] ^ d[1] ^ crc_reg[30] ^ crc_reg[31] ^ crc_reg[21];
    assign next_crc[24] = d[0] ^ crc_reg[22] ^ crc_reg[31];
    assign next_crc[25] = crc_reg[23];
    assign next_crc[26] = crc_reg[24] ^ d[1] ^ crc_reg[30];
    assign next_crc[27] = crc_reg[31] ^ crc_reg[25] ^ d[0];
    assign next_crc[28] = crc_reg[26];
    assign next_crc[29] = crc_reg[27];
    assign next_crc[30] = crc_reg[28];
    assign next_crc[31] = crc_reg[29];
endmodule
