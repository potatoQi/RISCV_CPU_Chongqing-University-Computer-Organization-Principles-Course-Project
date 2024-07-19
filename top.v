`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2024/05/12 21:21:06
// Design Name: 
// Module Name: top
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


module top # (
    parameter DATA_WIDTH = 32
) (
    input clk, rst
);
    wire [DATA_WIDTH-1:0] instr, pc;
    wire memread, memwrite;
    wire [DATA_WIDTH-1:0] readdata;
    wire [DATA_WIDTH-1:0] alu_result, read_data2;
    wire [2:0] load_store;
    wire prediction;
    wire [DATA_WIDTH-1:0] label;
    wire pre_branch;
    wire pcsrc, load_use_flag;
    wire [DATA_WIDTH-1:0] instr_M;
    wire [DATA_WIDTH-1:0] pc_M;
    wire error, correct;
    wire [DATA_WIDTH-1:0] new_label;
    wire miss;
    
    //----------------------------inst_ram--------------------------
    instr_ram instr_ram (
        .clk(clk),
        .addr(pc),
        .dout(instr)
    );
    wire [DATA_WIDTH-1:0] instr_true;
    assign instr_true = (instr === 32'bz || instr === 32'bx) ? 32'b0 : instr;
//    reg [DATA_WIDTH-1:0] instr_true;
//    always @(*) begin
//        if (instr === 32'bz || instr === 32'bx) begin
//            instr_true = 32'b0;
//        end else begin
//            instr_true = instr;
//        end
//    end
    
    //---------------------------d_cache & BM---------------------------
//    data_ram data_ram (
//        .clk(clk),
//        .rst(rst),
//        .re(memread),
//        .we(memwrite),
//        .load_store(load_store),
//        .addr(alu_result),
//        .din(read_data2),
//        .dout(readdata)
//    );
    wire [1:0] cpu_data_size;
    assign cpu_data_size = (load_store == 3'b000) ? (2'b00) :
                           (load_store == 3'b001) ? (2'b00) :
                           (load_store == 3'b010) ? (2'b01) :
                           (load_store == 3'b011) ? (2'b01) :
                           (load_store == 3'b100) ? (2'b10) :
                           (load_store == 3'b101) ? (2'b00) :
                           (load_store == 3'b110) ? (2'b01) :
                           (load_store == 3'b111) ? (2'b10) : (2'b10);
    wire cache_data_req, cache_data_wr;
    wire [1:0] cache_data_size;
    wire [9:0] cache_data_addr;
    wire [31:0] cache_data_wdata;
    wire [31:0] cache_data_rdata;
    wire cache_data_addr_ok, cache_data_data_ok;
    d_cache d_cache (
        .clk(clk),
        .rst(rst),
        .cpu_data_req(memread | memwrite),
        .cpu_data_wr(memwrite),
        .cpu_data_size(cpu_data_size),
        .load_store(load_store),
        .cpu_data_addr(alu_result),
        .cpu_data_wdata(read_data2),
        .cpu_data_rdata_true(readdata),
        .miss_ok(miss)
    );
//    BM your_instance_name (
//        .clka(clk),    // input wire clka
//        .ena(cache_data_req),      // input wire ena
//        .wea(cache_data_wr),      // input wire [0 : 0] wea
//        .addra(cache_data_addr),  // input wire [9 : 0] addra
//        .dina(cache_data_wdata),    // input wire [31 : 0] dina
//        .douta(cache_data_rdata)  // output wire [31 : 0] douta
//    );
    
    //---------------------------riscv--------------------------------
    riscv riscv (
        .clk(clk),
        .rst(rst),
        .miss(miss),
        .error(error),
        .correct(correct),
        .new_label(new_label),
        .label(label),
        .pre_branch(pre_branch),
        .prediction(prediction),
        .instr(instr_true),
        .readdata(readdata),
        .pc(pc),
        .alu_result(alu_result),
        .read_data2(read_data2),
        .instr_M(instr_M),
        .memread_M(memread),
        .memwrite(memwrite),
        .load_store_M(load_store),
        .pcsrc(pcsrc),
        .load_use_flag(load_use_flag),
        .pc_M(pc_M)
    );
    
    //------------------------branch_predictor-------------------------
    branch_predictor branch_predictor (
        .clk(clk),
        .rst(rst),
        .miss(miss),
        .load_use_flag(load_use_flag),
        .pcsrc(pcsrc),
        .pc(pc),
        .pc_M(pc_M),
        .instr(instr_true),
        .instr_M(instr_M),
        .branch(pre_branch),
        .prediction(prediction),
        .label(label),
        .error(error),
        .correct(correct),
        .new_label(new_label)
    );
endmodule
