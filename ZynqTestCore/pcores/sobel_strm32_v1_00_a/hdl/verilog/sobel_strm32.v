// ==============================================================
// File generated by AutoESL - High-Level Synthesis System (C, C++, SystemC)
// Version: 2011.4
// Copyright (C) 2011 Xilinx Inc. All rights reserved.
// 
// ==============================================================

`timescale 1 ns / 1 ps
module sobel_strm32 (
//INPUT_STREAM_ACLK,
//INPUT_STREAM_ARESETN,
INPUT_STREAM_TVALID,
INPUT_STREAM_TREADY,
INPUT_STREAM_TDATA,
INPUT_STREAM_TSTRB,
INPUT_STREAM_TUSER,
INPUT_STREAM_TLAST,
INPUT_STREAM_TDEST,
//OUTPUT_STREAM_ACLK,
//OUTPUT_STREAM_ARESETN,
OUTPUT_STREAM_TVALID,
OUTPUT_STREAM_TREADY,
OUTPUT_STREAM_TDATA,
OUTPUT_STREAM_TSTRB,
OUTPUT_STREAM_TUSER,
OUTPUT_STREAM_TLAST,
OUTPUT_STREAM_TDEST,

//INPUT_STREAM_32_ACLK,
//INPUT_STREAM_32_ARESETN,
INPUT_STREAM_32_TVALID,
INPUT_STREAM_32_TREADY,
INPUT_STREAM_32_TDATA,
INPUT_STREAM_32_TSTRB,
INPUT_STREAM_32_TUSER,
INPUT_STREAM_32_TLAST,
INPUT_STREAM_32_TDEST,
//OUTPUT_STREAM_32_ACLK,
//OUTPUT_STREAM_32_ARESETN,
OUTPUT_STREAM_32_TVALID,
OUTPUT_STREAM_32_TREADY,
OUTPUT_STREAM_32_TDATA,
OUTPUT_STREAM_32_TSTRB,
OUTPUT_STREAM_32_TUSER,
OUTPUT_STREAM_32_TLAST,
OUTPUT_STREAM_32_TDEST
);


//input INPUT_STREAM_ACLK ;
//input INPUT_STREAM_ARESETN ;
input INPUT_STREAM_TVALID ;
output INPUT_STREAM_TREADY ;
input [23:0] INPUT_STREAM_TDATA ;
input [2:0] INPUT_STREAM_TSTRB ;
input [0:0] INPUT_STREAM_TUSER ;
input [0:0] INPUT_STREAM_TLAST ;
input [0:0] INPUT_STREAM_TDEST ;

//input OUTPUT_STREAM_ACLK ;
//input OUTPUT_STREAM_ARESETN ;
output OUTPUT_STREAM_TVALID ;
input OUTPUT_STREAM_TREADY ;
output [24 - 1:0] OUTPUT_STREAM_TDATA ;
output [3 - 1:0] OUTPUT_STREAM_TSTRB ;
output [1 - 1:0] OUTPUT_STREAM_TUSER ;
output [1 - 1:0] OUTPUT_STREAM_TLAST ;
output [1 - 1:0] OUTPUT_STREAM_TDEST ;

//input INPUT_STREAM_32_ACLK ;
//input INPUT_STREAM_32_ARESETN ;
input INPUT_STREAM_32_TVALID ;
output INPUT_STREAM_32_TREADY ;
input [31:0] INPUT_STREAM_32_TDATA ;
input [3:0] INPUT_STREAM_32_TSTRB ;
input [0:0] INPUT_STREAM_32_TUSER ;
input [0:0] INPUT_STREAM_32_TLAST ;
input [0:0] INPUT_STREAM_32_TDEST ;

//input OUTPUT_STREAM_32_ACLK ;
//input OUTPUT_STREAM_32_ARESETN ;
output OUTPUT_STREAM_32_TVALID ;
input OUTPUT_STREAM_32_TREADY ;
output [31:0] OUTPUT_STREAM_32_TDATA ;
output [3:0] OUTPUT_STREAM_32_TSTRB ;
output [0:0] OUTPUT_STREAM_32_TUSER ;
output [0:0] OUTPUT_STREAM_32_TLAST ;
output [0:0] OUTPUT_STREAM_32_TDEST ;



assign OUTPUT_STREAM_32_TVALID = INPUT_STREAM_TVALID;
assign INPUT_STREAM_TREADY     = OUTPUT_STREAM_32_TREADY;
assign OUTPUT_STREAM_32_TDATA  = {8'hFF,INPUT_STREAM_TDATA[7:0],INPUT_STREAM_TDATA[15:8],INPUT_STREAM_TDATA[23:16]};
assign OUTPUT_STREAM_32_TSTRB  = {1'b1,INPUT_STREAM_TSTRB};
assign OUTPUT_STREAM_32_TUSER  = INPUT_STREAM_TUSER;
assign OUTPUT_STREAM_32_TLAST  = INPUT_STREAM_TLAST;
assign OUTPUT_STREAM_32_TDEST  = INPUT_STREAM_TDEST;

assign OUTPUT_STREAM_TVALID = INPUT_STREAM_32_TVALID;
assign INPUT_STREAM_32_TREADY     = OUTPUT_STREAM_TREADY;
assign OUTPUT_STREAM_TDATA  = {INPUT_STREAM_32_TDATA[7:0],INPUT_STREAM_32_TDATA[15:8],INPUT_STREAM_32_TDATA[23:16]};
assign OUTPUT_STREAM_TSTRB  = INPUT_STREAM_32_TSTRB[2:0];
assign OUTPUT_STREAM_TUSER  = INPUT_STREAM_32_TUSER;
assign OUTPUT_STREAM_TLAST  = INPUT_STREAM_32_TLAST;
assign OUTPUT_STREAM_TDEST  = INPUT_STREAM_32_TDEST;



endmodule