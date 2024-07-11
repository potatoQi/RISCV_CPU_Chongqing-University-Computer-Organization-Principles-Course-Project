`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2024/05/12 21:17:31
// Design Name: 
// Module Name: datapath
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


module datapath #(
    parameter DATA_WIDTH = 32
)(
    input clk, rst,
    input error, correct,
    input [DATA_WIDTH-1:0] new_label,
    input [DATA_WIDTH-1:0] label,
    input pre_branch,
    input prediction,
    input [DATA_WIDTH-1:0] instr_D,         //由inst_ram传入
    input [DATA_WIDTH-1:0] readdata,        //由data_ram传入
    input [7:0] branch_M,
    input [2:0] load_store_M,
    input memread, memwrite,
    input regsrc,
    input load_use_flag,
    input alusrc,
    input [4:0] alucontrol,
    input regwrite,
    input [2:0] immsel,
    input [1:0] fowardA, fowardB,
    input fowardC,
    output [DATA_WIDTH-1:0] pc,
    output [DATA_WIDTH-1:0] alu_result_M,
    output [DATA_WIDTH-1:0] read_data2_M_true,
    output [DATA_WIDTH-1:0] instr_E, instr_M, instr_W,
    output [DATA_WIDTH-1:0] pc_M,
    output pcsrc
);
    wire [DATA_WIDTH-1:0] pc_nxt_1, pc_nxt_2, pc_nxt, pc_nxt_true, pc_nxt_true_true;
    wire [DATA_WIDTH-1:0] read_data1, write_data;
    wire [DATA_WIDTH-1:0] imm_gen, imm_gen_sl1;
    wire zero, zero_M;
    wire [DATA_WIDTH-1:0] alu_din2;
    wire [DATA_WIDTH-1:0] alu_result;
    wire [DATA_WIDTH-1:0] read_data2_M;
    
    wire [DATA_WIDTH-1:0] pc_D, pc_E, pc_W;
    wire [DATA_WIDTH-1:0] read_data1_E, read_data2_E;
    wire [DATA_WIDTH-1:0] imm_gen_E;
    wire [DATA_WIDTH-1:0] readdata_W;
    wire [DATA_WIDTH-1:0] alu_result_W;
    wire [DATA_WIDTH-1:0] alu_din1_true, alu_din2_true;
    
    wire [DATA_WIDTH-1:0] pc_plus_imm_gen_sl1_E, pc_plus_imm_gen_sl1_M;
    wire greater_signed, greater_unsigned, less_signed, less_unsigned, not_zero;
    wire greater_signed_M, greater_unsigned_M, less_signed_M, less_unsigned_M, not_zero_M;
    wire [DATA_WIDTH-1:0] write_data_true;
    wire [7:0] branch_W;
    wire [DATA_WIDTH-1:0] read_data2;

    //------------------------pc---------------------
    // pc + 4
    adder adder1 (
        .din1(pc),
        .din2(32'd4),
        .dout(pc_nxt_1)
    );
    //mux2 of pc_nxt_1/2
    assign pcsrc = ((zero_M & branch_M[0]) | (greater_signed_M & branch_M[1]) | 
                   (greater_unsigned_M & branch_M[2]) | (less_signed_M & branch_M[3]) | 
                   (less_unsigned_M & branch_M[4]) | (not_zero_M & branch_M[5]) |
                   branch_M[6] | branch_M[7]);
    mux2 mux2_pc (
        .din1(pc_nxt_2),
        .din2(pc_nxt_1),
        .op((pcsrc & (~correct))),         // 这里注意，如果预测正确，就不需要启动静态预测（对于其它寄存器同理）
        .dout(pc_nxt)
    );
    mux2 mux2_pc_jump (
        .din1(label),
        .din2(pc_nxt),
        .op(pre_branch & prediction), // 若此时检测到IF阶段为跳转指令且预测跳转
        .dout(pc_nxt_true)
    );
    mux2 mux2_pc_jump_correct (
        .din1(new_label),
        .din2(pc_nxt_true),
        .op(error),             // 若MEM阶段检测到预测错误则马上更改
        .dout(pc_nxt_true_true)
    );
    // 得到下一个pc
    pc get_nxt_pc (
        .clk(clk),
        .rst(rst),
        .load_use_flag(load_use_flag),
        .din(pc_nxt_true_true),
        .dout(pc)
    );
    floprc r2 (
        .clk(clk),
        .rst(rst),
        .clc((pcsrc & (~correct)) | error),
        .load_use_flag(load_use_flag),
        .din(pc),
        .dout(pc_D)
    );
    floprc r_pc_E (
        .clk(clk),
        .rst(rst),
        .clc((pcsrc & (~correct)) | load_use_flag | error),
        .load_use_flag(0),
        .din(pc_D),
        .dout(pc_E)
    );
    floprc r_pc_M_ (
        .clk(clk),
        .rst(rst),
        .clc((pcsrc & (~correct)) | error),
        .load_use_flag(0),
        .din(pc_E),
        .dout(pc_M)
    );
    floprc r_pc_W_ (
        .clk(clk),
        .rst(rst),
        .clc(0),
        .load_use_flag(0),
        .din(pc_M),
        .dout(pc_W)
    );
    
    //-----------------------registers----------------
    floprc r10 (
        .clk(clk),
        .rst(rst),
        .clc(0),
        .load_use_flag(0),
        .din(readdata),
        .dout(readdata_W)
    );
    floprc r11 (
        .clk(clk),
        .rst(rst),
        .clc(0),
        .load_use_flag(0),
        .din(alu_result_M),
        .dout(alu_result_W)
    );
    floprc r12 (
        .clk(clk),
        .rst(rst),
        .clc(0),
        .load_use_flag(0),
        .din(instr_M),
        .dout(instr_W)
    );
    mux2 mux2_reg (
        .din1(readdata_W),
        .din2(alu_result_W),
        .op(regsrc),
        .dout(write_data)
    );
    floprc branch_M_W_ (
        .clk(clk),
        .rst(rst),
        .clc(0),
        .load_use_flag(0),
        .din(branch_M),
        .dout(branch_W)
    );
    mux2 mux2_jal (
        .din1(pc_W + 4),
        .din2(write_data),
        .op(branch_W[6] | branch_W[7]),
        .dout(write_data_true)
    );
    registers registers (
        .clk(clk),
        .rst(rst),
        .opcode(instr_D[6:0]),
        .regWrite(regwrite),
        .wire_addr({{27{0}}, instr_W[11:7]}),
        .din(write_data_true),
        .read_addr1({{27{0}}, instr_D[19:15]}),
        .read_addr2({{27{0}}, instr_D[24:20]}),
        .dout1(read_data1),
        .dout2(read_data2)
    );
    floprc r3 (
        .clk(clk),
        .rst(rst),
        .clc((pcsrc & (~correct)) | load_use_flag | error),
        .load_use_flag(0),
        .din(read_data1),
        .dout(read_data1_E)
    );
    floprc r4 (
        .clk(clk),
        .rst(rst),
        .clc((pcsrc & (~correct)) | load_use_flag | error),
        .load_use_flag(0),
        .din(read_data2),
        .dout(read_data2_E)
    );
    floprc r8 (
        .clk(clk),
        .rst(rst),
        .clc((pcsrc & (~correct)) | error),
        .load_use_flag(0),
        .din(read_data2_E),
        .dout(read_data2_M)
    );
    mux2 mux2_store_forward (
        .din1(write_data_true),
        .din2(read_data2_M),
        .op(fowardC),
        .dout(read_data2_M_true)
    );
    floprc r6 (
        .clk(clk),
        .rst(rst),
        .clc((pcsrc & (~correct)) | load_use_flag | error),
        .load_use_flag(0),
        .din(instr_D),
        .dout(instr_E)
    );
    floprc r9 (
        .clk(clk),
        .rst(rst),
        .clc((pcsrc & (~correct)) | error),
        .load_use_flag(0),
        .din(instr_E),
        .dout(instr_M)
    );
    
    //----------------------immGen & sl1-------------------
    immGen immGen (
        .din(instr_D),
        .immsel(immsel),
        .dout(imm_gen)
    );
    floprc r5 (
        .clk(clk),
        .rst(rst),
        .clc((pcsrc & (~correct)) | load_use_flag | error),
        .load_use_flag(0),
        .din(imm_gen),
        .dout(imm_gen_E)
    );
    sl1 sl1 (
        .din(imm_gen_E),
        .dout(imm_gen_sl1)
    );
    adder pc_plus_imm_gen_sl1_ (
        .din1(pc_E),
        .din2(imm_gen_sl1),
        .dout(pc_plus_imm_gen_sl1_E)
    );
    floprc r_pc_plus_imm_gen_sl1 (
        .clk(clk),
        .rst(rst),
        .clc((pcsrc & (~correct)) | error),
        .load_use_flag(0),
        .din(pc_plus_imm_gen_sl1_E),
        .dout(pc_nxt_2)
    );
    
    //----------------------alu----------------------------
    mux2 mux2_alu (
        .din1(imm_gen_E),
        .din2(read_data2_E),
        .op(alusrc),
        .dout(alu_din2)
    );
    mux3 mux3_1 (
        .din1(read_data1_E),
        .din2(alu_result_M),
        .din3(write_data_true),
        .op(fowardA),
        .dout(alu_din1_true)
    );
    mux3 mux3_2 (
        .din1(alu_din2),
        .din2(alu_result_M),
        .din3(write_data_true),
        .op(fowardB),
        .dout(alu_din2_true)
    );
    alu alu (
        .din1(alu_din1_true),
        .din2(alu_din2_true),
        .op(alucontrol),
        .dout(alu_result),
        .zero(zero),
        .greater_signed(greater_signed),
        .greater_unsigned(greater_unsigned),
        .less_signed(less_signed),
        .less_unsigned(less_unsigned),
        .not_zero(not_zero)
    );
    floprc #(1) zero_E_to_M (
        .clk(clk),
        .rst(rst),
        .clc((pcsrc & (~correct)) | error),
        .load_use_flag(0),
        .din(zero),
        .dout(zero_M)
    );
    floprc #(1) greater_signed_ (
        .clk(clk),
        .rst(rst),
        .clc((pcsrc & (~correct)) | error),
        .load_use_flag(0),
        .din(greater_signed),
        .dout(greater_signed_M)
    );
    floprc #(1) greater_unsigned_ (
        .clk(clk),
        .rst(rst),
        .clc((pcsrc & (~correct)) | error),
        .load_use_flag(0),
        .din(greater_unsigned),
        .dout(greater_unsigned_M)
    );
    floprc #(1) less_signed_ (
        .clk(clk),
        .rst(rst),
        .clc((pcsrc & (~correct)) | error),
        .load_use_flag(0),
        .din(less_signed),
        .dout(less_signed_M)
    );
    floprc #(1) less_unsigned_ (
        .clk(clk),
        .rst(rst),
        .clc((pcsrc & (~correct)) | error),
        .load_use_flag(0),
        .din(less_unsigned),
        .dout(less_unsigned_M)
    );
    floprc #(1) not_zero_ (
        .clk(clk),
        .rst(rst),
        .clc((pcsrc & (~correct)) | error),
        .load_use_flag(0),
        .din(not_zero),
        .dout(not_zero_M)
    );
    floprc r7 (
        .clk(clk),
        .rst(rst),
        .clc((pcsrc & (~correct)) | error),
        .load_use_flag(0),
        .din(alu_result),
        .dout(alu_result_M)
    );
endmodule
