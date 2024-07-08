`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2024/05/12 21:16:32
// Design Name: 
// Module Name: alu
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


module alu # (
    parameter DATA_WIDTH = 32
)(
    input [DATA_WIDTH-1:0] din1,
    input [DATA_WIDTH-1:0] din2,
    input [4:0] op,
    output [DATA_WIDTH-1:0] dout,
    output zero, not_zero, greater_signed, greater_unsigned, less_signed, less_unsigned
);
    assign dout = (op == 5'b00001) ? (din1 + din2) :
                  (op == 5'b00010) ? (din1 - din2) :
                  (op == 5'b00011) ? (din1 & din2) :
                  (op == 5'b00100) ? (din1 | din2) :
                  (op == 5'b00101) ? (din1 ^ din2) :
                  (op == 5'b00110) ? (din1 << din2) :
                  (op == 5'b00111) ? (din1 >> din2) :
                  (op == 5'b01000) ? ((din1[31]==1'b1)?~((~din1)>>din2):(din1>>din2)) : //官方的signed配合>>>感觉有bug，这一句引用了舍友的代码
                  (op == 5'b01001) ? ($signed(din1) < $signed(din2)) :
                  (op == 5'b01010) ? (din1 < din2) :
                  
                  (op == 5'b01011) ? (din1 + din2) :
                  (op == 5'b01100) ? (din1 & din2) :
                  (op == 5'b01101) ? (din1 | din2) :
                  (op == 5'b01110) ? (din1 ^ din2) :
                  (op == 5'b01111) ? (din1 << din2) :
                  (op == 5'b10000) ? (din1 >> din2) :
                  (op == 5'b10001) ? ((din1[31]==1'b1)?~((~din1)>>din2):(din1>>din2)) :
                  (op == 5'b10010) ? ($signed(din1) < $signed(din2)) :
                  (op == 5'b10011) ? (din1 < din2) : 0;
                  
    assign zero = ($signed(din1) == $signed(din2));
    assign greater_signed = ($signed(din1) >= $signed(din2));
    assign greater_unsigned = (din1 >= din2);
    assign less_signed = ($signed(din1) < $signed(din2));
    assign less_unsigned = (din1 < din2);
    assign not_zero = (din1 != din2);
endmodule
