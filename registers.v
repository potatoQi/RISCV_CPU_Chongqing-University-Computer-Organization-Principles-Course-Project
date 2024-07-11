`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2024/05/12 21:19:34
// Design Name: 
// Module Name: registers
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


module registers #(
    parameter DATA_WIDTH = 32
)(
    input clk,
    input rst,
    input [6:0] opcode,
    input regWrite,
    input [DATA_WIDTH-1:0] wire_addr,
    input [DATA_WIDTH-1:0] din,
    input [DATA_WIDTH-1:0] read_addr1,
    input [DATA_WIDTH-1:0] read_addr2,
    output [DATA_WIDTH-1:0] dout1,
    output [DATA_WIDTH-1:0] dout2
);

reg [DATA_WIDTH-1:0] registers[0:(1<<5)-1];
integer i;

// �����ȡ����0�żĴ��������ݣ���ôֱ��return 0��ȥ
assign dout1 = (read_addr1 == 0 || opcode == 7'b0110111) ? 0 : registers[read_addr1];   //luiָ���������addi rd x0 immu����
assign dout2 = (read_addr2 == 0) ? 0 : registers[read_addr2];

always @ (negedge clk) begin
    if (rst) begin
        for (i = 0; i < (1<<5); i = i + 1) begin
            registers[i] <= 0;
        end
        registers[2] <= 128;
    end else if (regWrite && (wire_addr != 0)) begin // ֻ����regWrite����wire_addr��Ϊ0�żĴ�����ʱ��Ű�����д��ȥ
        registers[wire_addr] <= din;
    end
end

endmodule
