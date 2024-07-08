`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2024/07/04 01:02:04
// Design Name: 
// Module Name: instr_ram
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


module instr_ram #(
    parameter ADDR_WIDTH = 32,  // 地址宽度
    parameter DATA_WIDTH = 32,  // 数据宽度
    parameter DEPTH = 1024      // 存储深度
 )(
    input clk,                  // 时钟信号
    input [ADDR_WIDTH-1:0] addr, // 读取地址
    output [DATA_WIDTH-1:0] dout // 读取数据
);

    reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];

    // 初始化存储器，可以在这里预先加载一些指令
    initial begin
        $readmemh("D:/Projects/viProjects/lab3/instructions.hex", mem); // 从文件加载指令
    end

    assign dout = mem[addr >> 2];
endmodule
