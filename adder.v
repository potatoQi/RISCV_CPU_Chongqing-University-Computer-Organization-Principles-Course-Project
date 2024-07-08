`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2024/05/12 21:15:58
// Design Name: 
// Module Name: adder
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


module adder # (
    parameter DATA_WIDTH = 32
)(
    input [DATA_WIDTH-1:0] din1, din2,
    output [DATA_WIDTH-1:0] dout
);
    assign dout = din1 + din2;
endmodule
