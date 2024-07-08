`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2024/05/12 21:18:41
// Design Name: 
// Module Name: mux2
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


module mux2 #(
    parameter DATA_WIDTH = 32
)(
    input [DATA_WIDTH-1:0] din1,din2,
	input op,
	output [DATA_WIDTH-1:0] dout
);
	assign dout = op ? din1 : din2;
endmodule
