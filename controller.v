`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2024/05/12 21:16:58
// Design Name: 
// Module Name: controller
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


module main_dec (
    input [6:0] op,
    input [2:0] funct3,
    input [6:0] funct7,
    output [2:0] load_store,
    output [7:0] branch,
    output memread, memwrite,
    output regsrc,
    output alusrc,
    output regwrite,
    output [2:0] immsel
);
    reg [18:0] controls;
    assign {load_store, branch, memread, regsrc, memwrite, alusrc, regwrite, immsel} = controls;
    always @ (*) begin
        case (op)
            7'h33: controls <= 19'b0000000000000001000;  //Arithmetic中不涉及到立即数
            7'h13: case(funct3) //Arithmetic中涉及到立即数的指令
                3'b001: controls <= 19'b0000000000000011001; //slli（零扩展）
                3'b101: case(funct7)
                    7'b0000000: controls <= 19'b0000000000000011001; //srli（零扩展）
                    7'b0100000: controls <= 19'b0000000000000011111; //srai（符号扩展）
                endcase
                default: controls <= 19'b0000000000000011010; //符号扩展
            endcase
            7'h03: case(funct3) //load系列指令
                3'b000: controls <= 19'b0000000000011011010;
                3'b100: controls <= 19'b0010000000011011010;
                3'b001: controls <= 19'b0100000000011011010;
                3'b101: controls <= 19'b0110000000011011010;
                3'b010: controls <= 19'b1000000000011011010;   
            endcase
            7'h23: case(funct3) //store系列指令
                3'b000: controls <= 19'b1010000000000110011;
                3'b001: controls <= 19'b1100000000000110011;
                3'b010: controls <= 19'b1110000000000110011;
            endcase
            7'h63: case(funct3) //Control中的B指令
                3'b000: controls <= 19'b0000000000100000100;
                3'b101: controls <= 19'b0000000001000000100;
                3'b111: controls <= 19'b0000000010000000100;
                3'b100: controls <= 19'b0000000100000000100;
                3'b110: controls <= 19'b0000001000000000100;
                3'b001: controls <= 19'b0000010000000000100;
            endcase
            7'h6F: controls <= 19'b0000100000000001101;  //Control中的jal
            7'h67: controls <= 19'b0001000000000001010;  //Control中的jalr
            7'h37: controls <= 19'b0000000000000011110; //lui
            default: controls <= 19'b0000000000000000000;
        endcase
    end
endmodule

module alu_dec (
    input [6:0] opcode,
    input [2:0] funct3,
    input [6:0] funct7,
    output reg [4:0] alucontrol
);
    always @ (*) begin
        case (opcode)
            //Arithmetic中的非立即数部分
            7'b0110011: case(funct3)
                3'b000: case(funct7) //add, sub
                    7'b0000000: alucontrol <= 5'b00001;
                    7'b0100000: alucontrol <= 5'b00010;
                    default: alucontrol <= 5'b00000;
                endcase
                3'b111: case(funct7) //and
                    7'b0000000: alucontrol <= 5'b00011;
                    default: alucontrol <= 5'b00000;
                endcase
                3'b110: case(funct7) //or
                    7'b0000000: alucontrol <= 5'b00100;
                    default: alucontrol <= 5'b00000;
                endcase
                3'b100: case(funct7) //xor
                    7'b0000000: alucontrol <= 5'b00101;
                    default: alucontrol <= 5'b00000;
                endcase
                3'b001: case(funct7) //sll
                    7'b0000000: alucontrol <= 5'b00110;
                    default: alucontrol <= 5'b00000;
                endcase
                3'b101: case(funct7) //srl, sra
                    7'b0000000: alucontrol <= 5'b00111;
                    7'b0100000: alucontrol <= 5'b01000;
                    default: alucontrol <= 5'b00000;
                endcase
                3'b010: case(funct7) //slt
                    7'b0000000: alucontrol <= 5'b01001;
                    default: alucontrol <= 5'b00000;
                endcase
                3'b0111: case(funct7) //sltu
                    7'b0000000: alucontrol <= 5'b01010;
                    default: alucontrol <= 5'b00000;
                endcase
            endcase
            
            //Arithmetic中的立即数部分 
            7'b0010011: case(funct3)
                3'b000: alucontrol <= 5'b01011; //addi
                3'b111: alucontrol <= 5'b01100; //andi
                3'b110: alucontrol <= 5'b01101; //ori
                3'b100: alucontrol <= 5'b01110; //xori
                3'b001: alucontrol <= 5'b01111; //slli
                3'b101: case(funct7) //srli, srai
                    7'b0000000: alucontrol <= 5'b10000;
                    7'b0100000: alucontrol <= 5'b10001;
                    default: alucontrol <= 5'b00000;
                endcase
                3'b010: alucontrol <= 5'b10010; //slti
                3'b011: alucontrol <= 5'b10011;  //sltiu
            endcase
            
            //Memory
            7'b0000011: case(funct3) //load系列
                3'b000: alucontrol <= 5'b01011;
                3'b100: alucontrol <= 5'b01011;
                3'b001: alucontrol <= 5'b01011;
                3'b101: alucontrol <= 5'b01011;
                3'b010: alucontrol <= 5'b01011;
            endcase
            7'b0100011: case(funct3) //store系列
                3'b000: alucontrol <= 5'b01011;
                3'b001: alucontrol <= 5'b01011;
                3'b010: alucontrol <= 5'b01011;
            endcase
            
            //Other
            7'b0110111: alucontrol <= 5'b01011; //lui，当作addi rd x0 immu
            
            default: alucontrol <= 5'b00000;
        endcase
    end
endmodule

module controller #(
    parameter DATA_WIDTH = 32
)(
    input clk, rst,
    input error, correct,
    input pcsrc, 
    input load_use_flag,   
    input [DATA_WIDTH-1:0] instr_D,
    input is_bubble,
    output [7:0] branch_M,
    output [2:0] load_store_M,
    output memread_M_true,
    output memwrite_M_true,
    output memread_E_true,
    output regsrc_W_true,
    output alusrc_E_true,
    output [4:0] alucontrol_E_true,
    output regwrite_E_true,
    output regwrite_W_true,
    output regwrite_M_true,
    output [2:0] immsel_D
);
    wire alusrc_D, alusrc_E;
    wire [4:0] alucontrol_D, alucontrol_E;
    wire memread_D, memread_E, memread_M;
    wire memwrite_D, memwrite_E, memwrite_M;
    wire regsrc_D, regsrc_E, regsrc_M, regsrc_W;
    wire regwrite_D, regwrite_E, regwrite_M, regwrite_W;
    wire [7:0] branch_D, branch_E;
    wire [2:0] load_store_D, load_store_E;
    
    mux2 #(1) m1 (0, alusrc_E, is_bubble, alusrc_E_true);
    mux2 #(5) m2 (0, alucontrol_E, is_bubble, alucontrol_E_true);
    mux2 #(1) m8 (0, memread_E, is_bubble, memread_E_true);
    mux2 #(1) m3 (0, memread_M, is_bubble, memread_M_true);
    mux2 #(1) m4 (0, memwrite_M, is_bubble, memwrite_M_true);
    mux2 #(1) m5 (0, regsrc_W, is_bubble, regsrc_W_true);
    mux2 #(1) m9 (0, regwrite_E, is_bubble, regwrite_E_true);
    mux2 #(1) m6 (0, regwrite_W, is_bubble, regwrite_W_true);
    mux2 #(1) m7 (0, regwrite_M, is_bubble, regwrite_M_true);
    
    floprc #(1) r13 (clk, rst, (pcsrc & (~correct)) | load_use_flag | error, 0, alusrc_D, alusrc_E);
    floprc #(5) r14 (clk, rst, (pcsrc & (~correct)) | error, 0, alucontrol_D, alucontrol_E);
    floprc #(1) r15 (clk, rst, (pcsrc & (~correct)) | error | load_use_flag, 0, memread_D, memread_E);
    floprc #(1) r16 (clk, rst, (pcsrc & (~correct)) | error, 0, memread_E, memread_M);
    floprc #(1) r17 (clk, rst, (pcsrc & (~correct)) | error | load_use_flag, 0, memwrite_D, memwrite_E);
    floprc #(1) r18 (clk, rst, (pcsrc & (~correct)) | error, 0, memwrite_E, memwrite_M);
    floprc #(1) r19 (clk, rst, (pcsrc & (~correct)) | error | load_use_flag, 0, regsrc_D, regsrc_E);
    floprc #(1) r20 (clk, rst, (pcsrc & (~correct)) | error, 0, regsrc_E, regsrc_M);
    floprc #(1) r21 (clk, rst, 0, 0, regsrc_M, regsrc_W);
    floprc #(1) r22 (clk, rst, (pcsrc & (~correct)) | error | load_use_flag, 0, regwrite_D, regwrite_E);
    floprc #(1) r23 (clk, rst, (pcsrc & (~correct)) | error, 0, regwrite_E, regwrite_M);
    floprc #(1) r24 (clk, rst, 0, 0, regwrite_M, regwrite_W);
    floprc #(8) r25 (clk, rst, (pcsrc & (~correct)) | error | load_use_flag, 0, branch_D, branch_E);
    floprc #(8) r26 (clk, rst, (pcsrc & (~correct)) | error, 0, branch_E, branch_M);
    floprc #(3) r27 (clk, rst, (pcsrc & (~correct)) | error | load_use_flag, 0, load_store_D, load_store_E);
    floprc #(3) r28 (clk, rst, (pcsrc & (~correct)) | error, 0, load_store_E, load_store_M);

    main_dec main_dec (
        .op(instr_D[6:0]),
        .funct3(instr_D[14:12]),
        .funct7(instr_D[31:25]),
        .load_store(load_store_D),
        .branch(branch_D),
        .memread(memread_D),
        .memwrite(memwrite_D),
        .regsrc(regsrc_D),
        .alusrc(alusrc_D),
        .regwrite(regwrite_D),
        .immsel(immsel_D)
    );
    alu_dec alu_dec (
        .opcode(instr_D[6:0]),
        .funct3(instr_D[14:12]),
        .funct7(instr_D[31:25]),
        .alucontrol(alucontrol_D)
    );
endmodule
