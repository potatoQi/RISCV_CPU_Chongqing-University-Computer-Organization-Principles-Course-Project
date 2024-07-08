`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2024/05/14 12:48:40
// Design Name: 
// Module Name: floprc
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


module floprc # (parameter DATA_WIDTH = 32) (
    input clk, rst, clc, load_use_flag,
    input [DATA_WIDTH-1:0] din,
    output reg [DATA_WIDTH-1:0] dout
);
    always @ (posedge clk) begin
        if (rst) begin
            dout <= 0;
        end else if (clc) begin
            dout <= 0;
        end else if (load_use_flag == 1) begin
            dout <= dout;
        end else begin
            dout <= din;
        end
    end  
endmodule
