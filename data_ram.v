`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2024/07/04 02:12:01
// Design Name: 
// Module Name: data_ram
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


module data_ram # (
    parameter ADDR_WIDTH = 32,  // ��ַ���
    parameter DATA_WIDTH = 32,  // ���ݿ��
    parameter DEPTH = 1024      // �洢���
) (
    input clk,                    // ʱ���ź�
    input rst,
    input [ADDR_WIDTH-1:0] addr,  // ��ַ
    input [DATA_WIDTH-1:0] din,   // д������
    input we,                     // дʹ��
    input re,                     // ��ʹ��
    input [2:0] load_store,
    output reg [DATA_WIDTH-1:0] dout // ��ȡ����
);

    // ����洢������
    reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];
    integer i;

    // д�����
    always @(posedge clk) begin
        if (rst) begin
            for (i = 0; i < DEPTH; i = i + 1) begin
                mem[i] <= 0;
            end
        end else if (we) begin
            case (load_store)
                3'b101: case(addr[1:0]) // sb
                    2'b00: mem[addr >> 2][7:0] <= din[7:0];
                    2'b01: mem[addr >> 2][15:8] <= din[7:0];
                    2'b10: mem[addr >> 2][23:16] <= din[7:0];
                    2'b11: mem[addr >> 2][31:24] <= din[7:0];
                endcase
                3'b110: case(addr[1]) // sh
                    1'b0: mem[addr >> 2][15:0] <= din[15:0];
                    1'b1: mem[addr >> 2][31:16] <= din[15:0];
                endcase
                3'b111: mem[addr >> 2] <= din; // sw
            endcase
        end
    end
    
    always @ (negedge clk) begin
        if (re) begin
            case (load_store)
                3'b000: case(addr[1:0]) // lb
                    2'b00: dout <= {{24{mem[addr >> 2][7]}}, mem[addr >> 2][7:0]};
                    2'b01: dout <= {{24{mem[addr >> 2][15]}}, mem[addr >> 2][15:8]};
                    2'b10: dout <= {{24{mem[addr >> 2][23]}}, mem[addr >> 2][23:16]};
                    2'b11: dout <= {{24{mem[addr >> 2][31]}}, mem[addr >> 2][31:24]};
                endcase
                3'b001: case(addr[1:0]) // lbu
                    2'b00: dout <= {24'b0, mem[addr >> 2][7:0]};
                    2'b01: dout <= {24'b0, mem[addr >> 2][15:8]};
                    2'b10: dout <= {24'b0, mem[addr >> 2][23:16]};
                    2'b11: dout <= {24'b0, mem[addr >> 2][31:24]};
                endcase
                3'b010: case(addr[1]) // lh
                    1'b0: dout <= {{16{mem[addr >> 2][15]}}, mem[addr >> 2][15:0]};
                    1'b1: dout <= {{16{mem[addr >> 2][31]}}, mem[addr >> 2][31:16]};
                endcase
                3'b011: case(addr[1]) // lhu
                    1'b0: dout <= {16'b0, mem[addr >> 2][15:0]};
                    1'b1: dout <= {16'b0, mem[addr >> 2][31:16]};
                endcase
                3'b100: dout <= mem[addr >> 2]; // lw
            endcase
        end else begin
            dout <= {DATA_WIDTH{1'bz}};
        end
    end
    
endmodule
