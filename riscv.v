`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2024/05/12 21:20:03
// Design Name: 
// Module Name: riscv
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


module riscv # (
    parameter DATA_WIDTH = 32
) (
    input clk, rst,
    input miss,
    input error, correct,
    input [DATA_WIDTH-1:0] new_label,
    input [DATA_WIDTH-1:0] label,
    input pre_branch,
    input prediction,
    input [DATA_WIDTH-1:0] instr,
    input [DATA_WIDTH-1:0] readdata,
    output [DATA_WIDTH-1:0] pc,
    output [DATA_WIDTH-1:0] alu_result,
    output [DATA_WIDTH-1:0] read_data2,
    output [DATA_WIDTH-1:0] instr_M,
    output memread_M, memwrite,
    output [2:0] load_store_M,
    output pcsrc, load_use_flag,
    output [DATA_WIDTH-1:0] pc_M
);
    wire regsrc, alusrc, regwrite_W, regwrite_M;
    wire [4:0] alucontrol;
    wire [2:0] immsel;
    wire [DATA_WIDTH-1:0] instr_D;
    wire [1:0] fowardA, fowardB;
    wire fowardC;
    wire [DATA_WIDTH-1:0] instr_E, instr_W;
    wire [7:0] branch_M;
    wire memread_E, regwrite_E;
    
    floprc r1 (
        .clk(clk),
        .rst(rst),
        .clc((pcsrc & (~correct)) | error),
        .load_use_flag(load_use_flag | miss),
        .din(instr),
        .dout(instr_D)
    );
    //------------------datapath------------------
    datapath datapath (
        .clk(clk),
        .rst(rst),
        .miss(miss),
        .correct(correct),
        .error(error),
        .new_label(new_label),
        .label(label),
        .pre_branch(pre_branch),
        .prediction(prediction),
        .pcsrc(pcsrc),
        .load_use_flag(load_use_flag),
        .instr_D(instr_D),
        .readdata(readdata),
        .branch_M(branch_M),
        .load_store_M(load_store_M),
        .memread(memread_M),
        .memwrite(memwrite),
        .regsrc(regsrc),
        .alusrc(alusrc),
        .alucontrol(alucontrol),
        .regwrite(regwrite_W),
        .immsel(immsel),
        .pc(pc),
        .alu_result_M(alu_result),
        .read_data2_M_true(read_data2),
        .fowardA(fowardA),
        .fowardB(fowardB),
        .fowardC(fowardC),
        .instr_E(instr_E),
        .instr_M(instr_M),
        .instr_W(instr_W),
        .pc_M(pc_M)
    );
    
    //-----------------controller--------------
    controller controller (
        .miss(miss),
        .is_bubble(0),
        .clk(clk),
        .rst(rst),
        .correct(correct),
        .error(error),
        .pcsrc(pcsrc),
        .load_use_flag(load_use_flag),
        .instr_D(instr_D),
        .branch_M(branch_M),
        .load_store_M(load_store_M),
        .memread_E_true(memread_E),
        .memread_M_true(memread_M),
        .memwrite_M_true(memwrite),
        .regsrc_W_true(regsrc),
        .alusrc_E_true(alusrc),
        .alucontrol_E_true(alucontrol),
        .regwrite_E_true(regwrite_E),
        .regwrite_W_true(regwrite_W),
        .regwrite_M_true(regwrite_M),
        .immsel_D(immsel)
    );
    
    //-----------------foward_detecting--------------
    foward_detecting foward_detecting (
        .opcode_E(instr_E[6:0]),
        .opcode_D(instr_D[6:0]),
        .ID_EX_Rs1({{27{0}}, instr_E[19:15]}),
        .ID_EX_Rs2({{27{0}}, instr_E[24:20]}),
        .EX_MEM_Rd({{27{0}}, instr_M[11:7]}),
        .MEM_WB_Rd({{27{0}}, instr_W[11:7]}),
        .EX_MEM_Rs2({{27{0}}, instr_M[24:20]}),
        .EX_MEM_Regwrite(regwrite_M),
        .MEM_WB_Regwrite(regwrite_W),
        .fowardA(fowardA),
        .fowardB(fowardB),
        .fowardC(fowardC),
        .memread_E(memread_E),
        .ID_EX_Regwrite(regwrite_E),
        .load_use_flag(load_use_flag),
        .ID_EX_Rd({{27{0}}, instr_E[11:7]}),
        .IF_ID_Rs1({{27{0}}, instr_D[19:15]}),
        .IF_ID_Rs2({{27{0}}, instr_D[24:20]}),
        .memwrite(memwrite)
    );
endmodule
