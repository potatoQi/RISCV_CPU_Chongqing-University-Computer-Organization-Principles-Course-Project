`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2024/05/15 01:48:39
// Design Name: 
// Module Name: foward_detecting
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


module foward_detecting # (
    parameter DATA_WIDTH = 32
) (
    input [6:0] opcode_E,
    input [6:0] opcode_D,
    input [DATA_WIDTH-1:0] ID_EX_Rs1,
    input [DATA_WIDTH-1:0] ID_EX_Rs2,
    input [DATA_WIDTH-1:0] EX_MEM_Rd,
    input [DATA_WIDTH-1:0] MEM_WB_Rd,
    input [DATA_WIDTH-1:0] EX_MEM_Rs2,
    input EX_MEM_Regwrite,
    input MEM_WB_Regwrite,
    input memwrite,
    output [1:0] fowardA,
    output [1:0] fowardB,
    output fowardC,
    input memread_E,
    input ID_EX_Regwrite,
    output load_use_flag,
    input [DATA_WIDTH-1:0] ID_EX_Rd,
    input [DATA_WIDTH-1:0] IF_ID_Rs1, IF_ID_Rs2
);
    assign fowardA[0] = (EX_MEM_Regwrite && (EX_MEM_Rd != 0) && (EX_MEM_Rd == ID_EX_Rs1));
    assign fowardA[1] = (MEM_WB_Regwrite && (MEM_WB_Rd != 0) && (MEM_WB_Rd == ID_EX_Rs1));
    
    assign fowardB[0] = (EX_MEM_Regwrite && (EX_MEM_Rd != 0) && (EX_MEM_Rd == ID_EX_Rs2) && (opcode_E == 7'b0110011 || opcode_E == 7'b1100011));
    assign fowardB[1] = (MEM_WB_Regwrite && (MEM_WB_Rd != 0) && (MEM_WB_Rd == ID_EX_Rs2) && (opcode_E == 7'b0110011 || opcode_E == 7'b1100011)); 
    //只有需要确实会用到rs2的指令才考虑是否前推
    
    assign fowardC = (memwrite && MEM_WB_Regwrite && (MEM_WB_Rd != 0) && (MEM_WB_Rd == EX_MEM_Rs2));
    
    assign load_use_flag = (memread_E == 1 && ID_EX_Regwrite == 1 && opcode_E == 7'b0000011 && (ID_EX_Rd != 0) &&
        (
            (ID_EX_Rd == IF_ID_Rs1) || 
            (ID_EX_Rd == IF_ID_Rs2 && (opcode_D == 7'b0110011 || opcode_D == 7'b1100011))
        )
    );
 
endmodule