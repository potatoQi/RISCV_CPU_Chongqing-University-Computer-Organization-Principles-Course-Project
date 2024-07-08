`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2024/05/12 21:18:11
// Design Name: 
// Module Name: immGen
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


module immGen #(
    parameter DATA_WIDTH = 32
)(
	input [DATA_WIDTH-1:0] din,
	input [2:0] immsel,
	output [DATA_WIDTH-1:0] dout
);
	assign dout = (immsel == 3'b000) ? (0) :                               //���漰��������
	              (immsel == 3'b001) ? ({{20{1'b0}}, din[24:20]}) :        //����չ(Arithmetic�е�slli, srli)
	              (immsel == 3'b010) ? ({{20{din[31]}}, din[31:20]}) :     //�з�����չ(Arithmetic�г���slli, srli, srai + lwϵ�� + jalr)
	              (immsel == 3'b011) ? ({{20{din[31]}}, din[31:25], din[11:7]}) :                        //�з�����չ��swϵ�У�
	              (immsel == 3'b100) ? ({{20{din[31]}}, din[31], din[7], din[30:25], din[11:8]}) :       //�з�����չ��Control�е�Bָ�
                  (immsel == 3'b101) ? ({{12{din[31]}}, din[31], din[19:12], din[20], din[30:21]}) :     //�з�����չ��jal��
                  (immsel == 3'b110) ? ({din[31:12], {12{1'b0}}}) :          //lui
                  (immsel == 3'b111) ? ({{20{1'b0}}, din[24:20]}) : 0;    //����չsrai
endmodule
