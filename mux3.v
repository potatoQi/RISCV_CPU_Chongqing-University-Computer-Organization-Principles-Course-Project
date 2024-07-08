`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2024/05/14 22:56:24
// Design Name: 
// Module Name: mux3
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


module mux3 # (parameter DATA_WIDTH = 32) (
	input [DATA_WIDTH-1:0] din1, din2, din3,
	input [1:0] op,
	output [DATA_WIDTH-1:0] dout
);
	assign dout = (op == 2'b00) ? din1 :
				  (op == 2'b01) ? din2 :
				  (op == 2'b10) ? din3 :
				  (op == 2'b11) ? din2 : din1;  // 如果为11则出现了双重数据冒险，取最新更新的前推
endmodule
