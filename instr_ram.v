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
    parameter ADDR_WIDTH = 32,  // ��ַ���
    parameter DATA_WIDTH = 32,  // ���ݿ��
    parameter DEPTH = 1024      // �洢���
 )(
    input clk,                  // ʱ���ź�
    input [ADDR_WIDTH-1:0] addr, // ��ȡ��ַ
    output [DATA_WIDTH-1:0] dout // ��ȡ����
);

    reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];

    // ��ʼ���洢��������������Ԥ�ȼ���һЩָ��
    initial begin
        $readmemh("D:/Projects/viProjects/lab3/instructions.hex", mem); // ���ļ�����ָ��
    end

    assign dout = mem[addr >> 2];
endmodule
