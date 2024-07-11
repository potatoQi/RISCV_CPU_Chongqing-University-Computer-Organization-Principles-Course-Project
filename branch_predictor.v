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

// ����⵽��ǰ����ָ���Ƿ�֧��תָ��������һ����֧��תָ���״̬����Ԥ���� �� ��ת��ַ��
// ��Ԥ��Ϊ��ת����

module branch_predictor #(
    parameter DATA_WIDTH = 32,
    parameter DEPTH = 1024
) (
    input clk,
    input rst,
    input load_use_flag,
    input pcsrc,
    input [DATA_WIDTH-1:0] pc,          // ��ǰpc
    input [DATA_WIDTH-1:0] pc_M,
    input [DATA_WIDTH-1:0] instr,       // ��ǰָ��
    input [DATA_WIDTH-1:0] instr_M,
    output branch,
    output prediction,                   // Ԥ����
    output [DATA_WIDTH-1:0] label,        // ��ת��ַ
    output error,
    output correct,
    output [DATA_WIDTH-1:0] new_label
);
    wire [DATA_WIDTH-1:0] din;
    assign din = instr;
    
    wire [6:0] opcode = instr[6:0];
    assign branch = ((opcode == 7'b1100011) ? 1 : 0);

    // Ԥ�����СΪ1024����ʼ״̬Ϊ01 (������ת)
    reg [1:0] predictor_table [DEPTH:0];  // ����һ��1025��С�����飬ÿ��Ԫ����2λ
    integer i;
    
    // ��ʼ��Ԥ���ͷ�ָ֧�������
    always @(posedge clk) begin
        if (rst) begin
            for (i = 0; i <= DEPTH; i = i + 1) begin
                predictor_table[i] <= 2'b01;  // ��ʼ��ÿ����ĿΪ������ת (01)
            end
        end
    end
    
    // ӳ��PC��Ԥ�������
    wire [9:0] index_IF, index_MEM;
    assign index_IF = pc[11:2] % DEPTH;
    assign index_MEM = pc_M[11:2] % DEPTH;
    
    // Ԥ��׶�
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
        (prediction_M == pcsrc)  ;  //���Ԥ����ȷ����ȡ����̬Ԥ��
    
    assign error = (instr_M[6:0] == 7'b1100011) &
        (prediction_M == 1) & (pcsrc == 0);
    assign new_label = error ? (pc_M + 4) : 0;
    /*
        �����߼�
        if (instr_M[6:0] == ��תָ�� && pcsrc != prediction_M) {
            if (prediction == 0 && pcsrc == 1) ��̬Ԥ��ᴦ��
            else if (prediction == 1 && pcsrc == 0) { // ֻ�������������Ҫ����
                ��������̬Ԥ��һ�������飬
                Ȼ��pc_nxt_true�ٵ�һ��mux2��ѡ�񣬴�һ���µ�label��ȥ
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
        if (instr_M[6:0] == ��תָ��) {
            if (prediction == pcsrc) {  // Ԥ��ɹ�
                case (predictor_table[counter])
                    2'b00: predictor_table[counter + 1] <= 2'b01;
                    2'b01: predictor_table[counter + 1] <= 2'b10;
                    2'b10: predictor_table[counter + 1] <= 2'b11;
                    2'b11: predictor_table[counter + 1] <= 2'b11;
                endcase
            }
            else { // Ԥ��ʧ��
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
