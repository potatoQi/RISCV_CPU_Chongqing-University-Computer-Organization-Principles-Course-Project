`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2024/05/12 21:20:32
// Design Name: 
// Module Name: sl1
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module sl1 #(
    parameter DATA_WIDTH = 32
)(
    input [DATA_WIDTH-1:0] din,
    output [DATA_WIDTH-1:0] dout
);
    assign dout = {din[30:0], 1'b0};
endmodule
