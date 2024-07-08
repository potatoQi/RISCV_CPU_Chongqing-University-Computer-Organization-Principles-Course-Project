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
    parameter ADDR_WIDTH = 32,  // 地址宽度
    parameter DATA_WIDTH = 32,  // 数据宽度
    parameter DEPTH = 1024      // 存储深度
) (
    input clk,                    // 时钟信号
    input rst,
    input [ADDR_WIDTH-1:0] addr,  // 地址
    input [DATA_WIDTH-1:0] din,   // 写入数据
    input we,                     // 写使能
    input re,                     // 读使能
    input [2:0] load_store,
    output reg [DATA_WIDTH-1:0] dout // 读取数据
);

    // 定义存储器阵列
    reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];
    integer i;

    // 写入操作
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
