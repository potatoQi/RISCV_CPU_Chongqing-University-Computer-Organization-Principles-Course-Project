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
    input         cpu_data_req     ,    // cpu��cache�������ź�
    input         cpu_data_wr      ,    // cpu��cache��д����
    input  [1:0]  cpu_data_size    ,    // ���ݴ�С
    input  [2:0]  load_store       ,    // ����ʲô���ͣ�4�ֽڡ�2�ֽڡ�1�ֽڣ�
    input  [31:0] cpu_data_addr    ,    // cpu���ȡ / д�� �����ݵĵ�ַ
    input  [31:0] cpu_data_wdata   ,    // cpu��д��cache������
    output [31:0] cpu_data_rdata_true,   // cpu��cache�ж�ȡ����������
    output miss_ok
);

    parameter INDEX_WIDTH = 10 , OFFSET_WIDTH = 0;
    localparam TAG_WIDTH = 32 - INDEX_WIDTH - OFFSET_WIDTH ;
    localparam CACHE_DEEPTH = 1 << INDEX_WIDTH ;
    
    // cache����
    reg cache_valid [ CACHE_DEEPTH - 1 : 0];
    reg cache_dirty [CACHE_DEEPTH - 1 : 0];
    reg [ TAG_WIDTH -1:0] cache_tag [ CACHE_DEEPTH - 1 : 0];
    reg [31:0] cache_block [ 0 : CACHE_DEEPTH - 1];
    
    // �������������pc
    wire [ INDEX_WIDTH -1:0] index ;
    wire [ TAG_WIDTH -1:0] tag ;
    assign index = cpu_data_addr [ INDEX_WIDTH + OFFSET_WIDTH - 1 : OFFSET_WIDTH ];
    assign tag = cpu_data_addr [31 : INDEX_WIDTH + OFFSET_WIDTH ];

    // �ҵ���Ӧ��cache��
    wire c_valid ;
    wire c_dirty ;
    wire [ TAG_WIDTH -1:0] c_tag ;
    wire [0:31] c_block ;
    assign c_valid = cache_valid [ index ];
    assign c_tag = cache_tag [ index ];
    assign c_block = cache_block [ index ];
    assign c_dirty = cache_dirty[ index ];

    // �ж��Ƿ����� & ��orд & ��or�ɾ�
    wire hit, miss;
    assign hit  = c_valid & (c_tag == tag); 
    assign miss = cpu_data_req & (~hit);
    reg miss_reg1 = 0, miss_reg2 = 0;
    always @ (posedge clk) begin
        miss_reg1 <= miss;
        miss_reg2 <= miss_reg1;
    end
    assign miss_ok = (cpu_data_req & miss);
    wire read, write;
    assign read  = ~write;
    assign write = cpu_data_wr;
    reg read_reg1 = 0, read_reg2 = 0;
    always @ (posedge clk) begin
        read_reg1 <= read;
        read_reg2 <= read_reg1;
    end
    reg write_rev = 1;
    always @ (posedge clk) begin
        write_rev <= ~write; 
    end
    wire clean, dirty;
    assign dirty = c_valid & c_dirty;   //ȷ����Ч���������Ƿ������
    assign clean = ~dirty;

    // ���������������
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

    // ��ʼ��
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

    // �����
    wire m_read;
    wire [31:0] data_from_ram;
    assign m_read = (cpu_data_req & read & miss);   // �����������
    assign cpu_data_rdata_true = (m_read) ? data_from_ram : c_block;
    
    // ����д����������
    wire m_write;
    wire [31:0] cpu_data_addr_true, cpu_data_wdata_true_true;
    assign m_write = (cpu_data_req & read & miss & dirty) | (cpu_data_req & write & miss & dirty);
    assign cpu_data_addr_true = (m_write ? {c_tag, index} : cpu_data_addr);
    assign cpu_data_wdata_true_true = (m_write ? c_block : cpu_data_wdata_true);
    
    // ����д������cache
    wire if_write_to_cache;
    assign if_write_to_cache = (cpu_data_req & read_reg2 & miss_reg2) | (cpu_data_req & write & hit & write_rev) | (cpu_data_req & write & miss & write_rev);
    always @ (posedge clk) begin // Ŀ����Ϊ������cpu_data_addr_trueʹ�þɵ�cache���ݸ��£���д��ȥ��
        if (if_write_to_cache) begin
            cache_valid[index] <= 1'b1;
            cache_dirty[index] <= 1'b0;
            cache_tag  [index] <= tag;
            if (cpu_data_req & read_reg2 & miss_reg2) // ������ȡ�صĶ���д��cache
                cache_block[index] <= data_from_ram;
            else if (cpu_data_req & write & hit) // ��cpu�Ķ���д��cache
                cache_block[index] <= cpu_data_wdata_true;
            else                                // ��cpu�Ķ���д��cache
                cache_block[index] <= cpu_data_wdata_true;
        end
    end
    
//    data_ram data_ram (
//        .clk(clk),
//        .rst(rst),
//        .addr(cpu_data_addr_true),
//        .din(cpu_data_wdata_true_true),
//        .we(m_write),
//        .re(m_read),
//        .load_store(load_store),
//        .dout(data_from_ram)    // һ�����ڵ�һ���ʱ�򣬿��Եõ�data_from_ram
//    );
    BM your_instance_name (
      // д��
      .clka(clk),    // input wire clka
      .ena(m_write),      // input wire ena
      .wea(m_write),      // input wire [0 : 0] wea
      .addra(cpu_data_addr_true),  // input wire [9 : 0] addra
      .dina(cpu_data_wdata_true_true),    // input wire [31 : 0] dina
      // ����
      // �õ�data_from_ram�Ķ����ӳ�һ����������
      .clkb(clk),    // input wire clkb
      .enb(m_read),      // input wire enb
      .addrb(cpu_data_addr),  // input wire [9 : 0] addrb
      .doutb(data_from_ram)  // output wire [31 : 0] doutb
    );

endmodule 