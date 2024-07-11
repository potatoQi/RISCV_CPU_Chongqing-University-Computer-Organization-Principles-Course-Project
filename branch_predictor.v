`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2024/07/05 14:32:08
// Design Name: 
// Module Name: branch_predictor
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

// 若检测到当前这条指令是分支跳转指令，则根据上一条分支跳转指令的状态返回预测结果 和 跳转地址。
// 若预测为跳转，则

module branch_predictor #(
    parameter DATA_WIDTH = 32,
    parameter DEPTH = 1024
) (
    input clk,
    input rst,
    input load_use_flag,
    input pcsrc,
    input [DATA_WIDTH-1:0] pc,          // 当前pc
    input [DATA_WIDTH-1:0] pc_M,
    input [DATA_WIDTH-1:0] instr,       // 当前指令
    input [DATA_WIDTH-1:0] instr_M,
    output branch,
    output prediction,                   // 预测结果
    output [DATA_WIDTH-1:0] label,        // 跳转地址
    output error,
    output correct,
    output [DATA_WIDTH-1:0] new_label
);
    wire [DATA_WIDTH-1:0] din;
    assign din = instr;
    
    wire [6:0] opcode = instr[6:0];
    assign branch = ((opcode == 7'b1100011) ? 1 : 0);

    // 预测表，大小为1024，初始状态为01 (弱不跳转)
    reg [1:0] predictor_table [DEPTH:0];  // 定义一个1025大小的数组，每个元素是2位
    integer i;
    
    // 初始化预测表和分支指令计数器
    always @(posedge clk) begin
        if (rst) begin
            for (i = 0; i <= DEPTH; i = i + 1) begin
                predictor_table[i] <= 2'b01;  // 初始化每个条目为弱不跳转 (01)
            end
        end
    end
    
    // 映射PC到预测表索引
    wire [9:0] index_IF, index_MEM;
    assign index_IF = pc[11:2] % DEPTH;
    assign index_MEM = pc_M[11:2] % DEPTH;
    
    // 预测阶段
    assign prediction = (branch ? (
        ((predictor_table[index_IF] == 2'b10) | (predictor_table[index_IF] == 2'b11)) ? 1 : 0
    ) : 0);
    assign label = (branch ? (
        (opcode == 7'b1100011) ? (pc + ({{19{din[31]}}, din[31], din[7], din[30:25], din[11:8], 1'b0})) : 0
    ) : 0);
    
    wire prediction_D, prediction_E, prediction_M;
    floprc #(1) r_pre_b1 (clk, rst, (pcsrc & (~correct)) | error, load_use_flag, prediction, prediction_D);
    floprc #(1) r_pre_b2 (clk, rst, (pcsrc & (~correct)) | error | load_use_flag, 0, prediction_D, prediction_E);
    floprc #(1) r_pre_b3 (clk, rst, (pcsrc & (~correct)) | error, 0, prediction_E, prediction_M);
    
    assign correct = (instr_M[6:0] == 7'b1100011) &
        (prediction_M == pcsrc)  ;  //如果预测正确，则取消静态预测
    
    assign error = (instr_M[6:0] == 7'b1100011) &
        (prediction_M == 1) & (pcsrc == 0);
    assign new_label = error ? (pc_M + 4) : 0;
    /*
        修正逻辑
        if (instr_M[6:0] == 跳转指令 && pcsrc != prediction_M) {
            if (prediction == 0 && pcsrc == 1) 静态预测会处理
            else if (prediction == 1 && pcsrc == 0) { // 只有这种情况才需要处理
                先做跟静态预测一样的事情，
                然后pc_nxt_true再叠一个mux2来选择，传一个新的label进去
            }
        }
    */
    
    always @ (posedge clk) begin
        if ((instr_M[6:0] == 7'b1100011)) begin
            if (prediction_M == pcsrc) begin
                case (predictor_table[index_MEM])
                    2'b00: predictor_table[index_MEM] <= 2'b01;
                    2'b01: predictor_table[index_MEM] <= 2'b10;
                    2'b10: predictor_table[index_MEM] <= 2'b11;
                    2'b11: predictor_table[index_MEM] <= 2'b11;
                endcase
            end else begin
                case (predictor_table[index_MEM])
                    2'b00: predictor_table[index_MEM] <= 2'b00;
                    2'b01: predictor_table[index_MEM] <= 2'b00;
                    2'b10: predictor_table[index_MEM] <= 2'b01;
                    2'b11: predictor_table[index_MEM] <= 2'b10;
                endcase
            end
        end
    end
    /*
        if (instr_M[6:0] == 跳转指令) {
            if (prediction == pcsrc) {  // 预测成功
                case (predictor_table[counter])
                    2'b00: predictor_table[counter + 1] <= 2'b01;
                    2'b01: predictor_table[counter + 1] <= 2'b10;
                    2'b10: predictor_table[counter + 1] <= 2'b11;
                    2'b11: predictor_table[counter + 1] <= 2'b11;
                endcase
            }
            else { // 预测失败
                case (predictor_table[counter])
                    2'b00: predictor_table[counter + 1] <= 2'b00;
                    2'b01: predictor_table[counter + 1] <= 2'b00;
                    2'b10: predictor_table[counter + 1] <= 2'b01;
                    2'b11: predictor_table[counter + 1] <= 2'b10;
                endcase
            }
            counter++;
        }
    */
endmodule
