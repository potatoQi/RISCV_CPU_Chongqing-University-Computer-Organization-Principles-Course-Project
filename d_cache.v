`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2024/07/06 23:37:40
// Design Name: 
// Module Name: d_cache
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


module d_cache(
    input clk, rst,
    input         cpu_data_req     ,    // cpu向cache的请求信号
    input         cpu_data_wr      ,    // cpu对cache的写请求
    input  [1:0]  cpu_data_size    ,    // 数据大小
    input  [2:0]  load_store       ,    // 看是什么类型（4字节、2字节、1字节）
    input  [31:0] cpu_data_addr    ,    // cpu想读取 / 写入 的数据的地址
    input  [31:0] cpu_data_wdata   ,    // cpu想写入cache的数据
    output [31:0] cpu_data_rdata_true   // cpu从cache中读取出来的数据
);

    parameter INDEX_WIDTH = 10 , OFFSET_WIDTH = 0;
    localparam TAG_WIDTH = 32 - INDEX_WIDTH - OFFSET_WIDTH ;
    localparam CACHE_DEEPTH = 1 << INDEX_WIDTH ;
    
    // cache数据
    reg cache_valid [ CACHE_DEEPTH - 1 : 0];
    reg cache_dirty [CACHE_DEEPTH - 1 : 0];
    reg [ TAG_WIDTH -1:0] cache_tag [ CACHE_DEEPTH - 1 : 0];
    reg [31:0] cache_block [ CACHE_DEEPTH - 1 : 0];
    
    // 解析传入进来的pc
    wire [ INDEX_WIDTH -1:0] index ;
    wire [ TAG_WIDTH -1:0] tag ;
    assign index = cpu_data_addr [ INDEX_WIDTH + OFFSET_WIDTH - 1 : OFFSET_WIDTH ];
    assign tag = cpu_data_addr [31 : INDEX_WIDTH + OFFSET_WIDTH ];

    // 找到对应的cache行
    wire c_valid ;
    wire c_dirty ;
    wire [ TAG_WIDTH -1:0] c_tag ;
    wire [31:0] c_block ;
    assign c_valid = cache_valid [ index ];
    assign c_tag = cache_tag [ index ];
    assign c_block = cache_block [ index ];
    assign c_dirty = cache_dirty[ index ];

    // 判断是否命中 & 读or写 & 脏or干净
    wire hit, miss;
    assign hit  = c_valid & (c_tag == tag); 
    assign miss = ~hit;
    wire read, write;
    assign read  = ~write;
    assign write = cpu_data_wr;
    wire clean, dirty;
    assign dirty = c_valid & c_dirty;   //确认有效后再讨论是否是脏块
    assign clean = ~dirty;

    // 处理读进来的数据
    wire [31:0] cpu_data_wdata_true;
    assign cpu_data_wdata_true = (load_store == 3'b101) ? (
                                    (cpu_data_addr[1:0] == 2'b00) ? {cache_block[index][31:8], cpu_data_wdata[7:0]} :
                                    (cpu_data_addr[1:0] == 2'b01) ? {cache_block[index][31:16], cpu_data_wdata[7:0], cache_block[index][7:0]} :
                                    (cpu_data_addr[1:0] == 2'b10) ? {cache_block[index][31:24], cpu_data_wdata[7:0], cache_block[index][15:0]} :
                                                                    {cpu_data_wdata[7:0], cache_block[index][23:0]}
                                 ) : (load_store == 3'b110) ? (
                                    (cpu_data_addr[1] == 1'b0) ? {cache_block[index][31:16], cpu_data_wdata[15:0]} :
                                                                  {cpu_data_wdata[15:0], cache_block[index][15:0]}
                                 ) : (load_store == 3'b111) ? cpu_data_wdata : cache_block[index];

    // 初始化
    integer i;
    always @ (posedge clk) begin
        if (rst) begin
            for (i = 0; i < CACHE_DEEPTH; i = i + 1) begin
                cache_valid[i] <= 0;
                cache_tag [i] <= 0;
                cache_dirty[i] <= 0;
                cache_block[i] <= 0;
            end 
        end
    end

    // 处理读
    wire m_read;
    wire [31:0] data_from_ram;
    assign m_read = (cpu_data_req & read & miss);   // 从主存读数据
    assign cpu_data_rdata_true = (m_read ? data_from_ram : c_block);    // 如果有需要就从主存读，否则读cache即可
    
    // 处理写东西进主存
    wire m_write;
    wire [31:0] cpu_data_addr_true, cpu_data_wdata_true_true;
    assign m_write = (cpu_data_req & read & miss & dirty) | (cpu_data_req & write & miss & dirty);
    assign cpu_data_addr_true = (m_write ? {c_tag, index} : cpu_data_addr);
    assign cpu_data_wdata_true_true = (m_write ? c_block : cpu_data_wdata_true);
    
    // 处理写东西进cache
    wire if_write_to_cache;
    assign if_write_to_cache = (cpu_data_req & read & miss) | (cpu_data_req & write & hit) | (cpu_data_req & write & miss);
    always @ (posedge clk) begin // 目的是为了先让cpu_data_addr_true使用旧的cache内容更新（先写回去）
        if (if_write_to_cache) begin
            cache_valid[index] <= 1'b1;
            cache_dirty[index] <= 1'b0;
            cache_tag  [index] <= tag;
            if (cpu_data_req & read & miss) // 把主存取回的东西写入cache
                cache_block[index] <= data_from_ram;                            // 第一个周期的一半的时候才得到
            else if (cpu_data_req & write & hit) // 把cpu的东西写入cache
                cache_block[index] <= cpu_data_wdata_true;
            else                                // 把cpu的东西写入cache
                cache_block[index] <= cpu_data_wdata_true;
        end
    end
    
    data_ram data_ram (
        .clk(clk),
        .rst(rst),
        .addr(cpu_data_addr_true),
        .din(cpu_data_wdata_true_true),
        .we(m_write),
        .re(m_read),
        .load_store(load_store),
        .dout(data_from_ram)    // 一个周期的一半的时候，可以得到data_from_ram
    );

endmodule 