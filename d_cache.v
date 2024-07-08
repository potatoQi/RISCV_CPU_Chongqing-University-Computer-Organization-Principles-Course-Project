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
    
    output [31:0] cpu_data_rdata_true , // cpu从cache中读取出来的数据
    output        cpu_data_addr_ok ,    // cache确认地址接受完成信号
    output        cpu_data_data_ok ,    // 对于读表示cpu已成功收到cache数据（cpu_data_rdata）；对于写表示数据已成功写入cache
    
    output         cache_data_req     ,  // cache向主存的请求信号
    output         cache_data_wr      ,  // cache对主存的写请求
    output  [1 :0] cache_data_size    ,  // cache想写入主存的数据的大小(00 1字节，01 2字节，10 4字节)
    output  [9:0]  cache_data_addr    ,  // cache想读取 / 写入 的数据的地址
    output  [31:0] cache_data_wdata   ,  // cache想写入主存的数据
    
    input   [31:0] cache_data_rdata   ,  // cache从主存中读取出来的数据
    input          cache_data_addr_ok ,  // 主存确认地址接收完成信号
    input          cache_data_data_ok    // 对于读表示cache已成功收到主存数据(cache_data_rdata)；对于写表示数据已成功写入主存
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

    // RW state machine
    // IDLE:空闲
    // RM:读内存
    // WRM:写主存，读内存
    // WM:写主存
    parameter IDLE = 2'b00, RM = 2'b01, WRM = 2'b10, WM = 2'b11;
    reg  [1:0] state;
    always @(posedge clk) begin
        if(rst) begin
            state <= IDLE;
        end else begin
            case(state)
                IDLE:   state <= cpu_data_req & read & miss & clean ? RM :  // 如果是读但miss且干净，就直接从主存读数据到cache
                                 cpu_data_req & read & miss & dirty ? WRM : // 如果是读但miss且dirty，就先写回主存再从主存读数据
                                 cpu_data_req & write & miss & dirty ? WM : IDLE; // 如果是写且miss且dirty，就先写回主存（write && hit或者write && miss && clean的情况直接把数据写到cache就好了，不需要额外进入其它状态）
                RM:     state <= cache_data_data_ok ? IDLE : RM;    // 如果cache成功的接收到主存的数据，那么进入IDLE
                WM:     state <= cache_data_data_ok ? IDLE : WM;    // 如果cache成功的完成了写主存，那么进入IDLE
                WRM:    state <= cache_data_data_ok ? RM : WRM;     // 如果cache成功的完成了写主存，那么进入RM去主存读数据
            endcase
        end
    end
    
    wire [31:0] cpu_data_rdata;
    assign cpu_data_rdata   = hit ? c_block : cache_data_rdata; // 如果hit了直接返回数据给cpu
    assign cpu_data_rdata_true = (load_store == 3'b000) ?       // lb
                                    (
                                    (cpu_data_addr[1:0] == 2'b00) ? {{24{cpu_data_rdata[7]}}, cpu_data_rdata[7:0]} :
                                    (cpu_data_addr[1:0] == 2'b01) ? {{24{cpu_data_rdata[15]}}, cpu_data_rdata[15:8]} :
                                    (cpu_data_addr[1:0] == 2'b10) ? {{24{cpu_data_rdata[23]}}, cpu_data_rdata[23:16]} :
                                    (cpu_data_addr[1:0] == 2'b11) ? {{24{cpu_data_rdata[31]}}, cpu_data_rdata[31:24]} : 0
                                    ) :
                                 (load_store == 3'b001) ?       // lbu
                                    (
                                    (cpu_data_addr[1:0] == 2'b00) ? {24'b0, cpu_data_rdata[7:0]} :
                                    (cpu_data_addr[1:0] == 2'b01) ? {24'b0, cpu_data_rdata[15:8]} :
                                    (cpu_data_addr[1:0] == 2'b10) ? {24'b0, cpu_data_rdata[23:16]} :
                                    (cpu_data_addr[1:0] == 2'b11) ? {24'b0, cpu_data_rdata[31:24]} : 0
                                    ) :
                                 (load_store == 3'b010) ?       // lh
                                    (
                                    (cpu_data_addr[1] == 1'b0) ? {{16{cpu_data_rdata[15]}}, cpu_data_rdata[15:0]} :
                                    (cpu_data_addr[1] == 1'b1) ? {{16{cpu_data_rdata[31]}}, cpu_data_rdata[31:16]} : 0
                                    ) :
                                 (load_store == 3'b011) ?       // lhu
                                    (
                                    (cpu_data_addr[1] == 1'b0) ? {16'b0, cpu_data_rdata[15:0]} :
                                    (cpu_data_addr[1] == 1'b1) ? {16'b0, cpu_data_rdata[31:16]} : 0
                                    ) :
                                 (load_store == 3'b100) ? cpu_data_rdata : 0;   // lw
    
    assign cpu_data_addr_ok = cpu_data_req & (hit | write & clean) | (state==RM || state==WM) & cache_data_addr_ok;
    assign cpu_data_data_ok = cpu_data_req & (hit | write & clean) | (state==RM || state==WM) & cache_data_data_ok;
    
    // 把状态机的状态用俩变量记录一下
    wire read_req;
    assign read_req = state == RM;
    wire write_req;
    assign write_req = state == WRM || state == WM;
    
    // 返回信号处理（1表示可以返回数据到cache_dat_rdata）
    reg addr_rcv;
    always @(posedge clk) begin
        addr_rcv <= rst ? 1'b0 : cache_data_req & cache_data_addr_ok ? 1'b1 : cache_data_data_ok ? 1'b0 : addr_rcv;
        // 如果cache需要向主存拿数据且主存已经接收到信号，那么该信号置为1，代表可以将数据返回到cache_data_rdata
    end
    
    // 这俩信号用来检测主存是否把成果交付到cache手里
    wire read_finish, write_finish;
    assign read_finish = read_req & cache_data_data_ok;
    assign write_finish = write_req & cache_data_data_ok;
    
    // cache与主存之间的交互信号处理一下
    assign cache_data_req   = (state!=IDLE) & ~addr_rcv;
    assign cache_data_wr    = write_req ? 1'b1 : 1'b0;
    assign cache_data_size  = write_req ? 2'b10 : cpu_data_size;  //写内存size均为2（这里考虑是否要修改）
    // assign cache_data_addr  = write_req ? {c_tag, index} : cpu_data_addr;
    assign cache_data_addr  = write_req ? index : cpu_data_addr[INDEX_WIDTH + OFFSET_WIDTH - 1 : OFFSET_WIDTH]; // 按理说应该是上面那句话，但是Block Memory开不了那么大
    assign cache_data_wdata = c_block; //写内存一定是替换脏块

    // 保存当前地址请求的标签和索引（cpu想要数据但是发现cache里找不到时会用到）
    reg [TAG_WIDTH-1:0] tag_save;
    reg [INDEX_WIDTH-1:0] index_save;
    always @(posedge clk) begin
        tag_save   <= rst ? 0 : cpu_data_req ? tag : tag_save;      //写入时，tag不变
        index_save <= rst ? 0 : cpu_data_req ? index : index_save;  //写入时，index不变
    end
     
    integer t;
    always @(posedge clk) begin
        if(rst) begin
            // Unrolled loop for cache initialization
            cache_valid[0] <= 0; // Cache line 0's valid bit set to 0
            cache_valid[1] <= 0; // Cache line 1's valid bit set to 0
            cache_valid[2] <= 0; // Cache line 2's valid bit set to 0
            cache_valid[3] <= 0; // Cache line 3's valid bit set to 0
            cache_valid[4] <= 0; // Cache line 4's valid bit set to 0
            cache_valid[5] <= 0; // Cache line 5's valid bit set to 0
            cache_valid[6] <= 0; // Cache line 6's valid bit set to 0
            cache_valid[7] <= 0; // Cache line 7's valid bit set to 0
            cache_valid[8] <= 0; // Cache line 8's valid bit set to 0
            cache_valid[9] <= 0; // Cache line 9's valid bit set to 0
            cache_valid[10] <= 0; // Cache line 10's valid bit set to 0
            cache_valid[11] <= 0; // Cache line 11's valid bit set to 0
            cache_valid[12] <= 0; // Cache line 12's valid bit set to 0
            cache_valid[13] <= 0; // Cache line 13's valid bit set to 0
            cache_valid[14] <= 0; // Cache line 14's valid bit set to 0
            cache_valid[15] <= 0; // Cache line 15's valid bit set to 0
            cache_valid[16] <= 0; // Cache line 16's valid bit set to 0
            cache_valid[17] <= 0; // Cache line 17's valid bit set to 0
            cache_valid[18] <= 0; // Cache line 18's valid bit set to 0
            cache_valid[19] <= 0; // Cache line 19's valid bit set to 0
            cache_valid[20] <= 0; // Cache line 20's valid bit set to 0
            cache_valid[21] <= 0; // Cache line 21's valid bit set to 0
            cache_valid[22] <= 0; // Cache line 22's valid bit set to 0
            cache_valid[23] <= 0; // Cache line 23's valid bit set to 0
            cache_valid[24] <= 0; // Cache line 24's valid bit set to 0
            cache_valid[25] <= 0; // Cache line 25's valid bit set to 0
            cache_valid[26] <= 0; // Cache line 26's valid bit set to 0
            cache_valid[27] <= 0; // Cache line 27's valid bit set to 0
            cache_valid[28] <= 0; // Cache line 28's valid bit set to 0
            cache_valid[29] <= 0; // Cache line 29's valid bit set to 0
            cache_valid[30] <= 0; // Cache line 30's valid bit set to 0
            cache_valid[31] <= 0; // Cache line 31's valid bit set to 0
            cache_valid[32] <= 0; // Cache line 32's valid bit set to 0
            cache_valid[33] <= 0; // Cache line 33's valid bit set to 0
            cache_valid[34] <= 0; // Cache line 34's valid bit set to 0
            cache_valid[35] <= 0; // Cache line 35's valid bit set to 0
            cache_valid[36] <= 0; // Cache line 36's valid bit set to 0
            cache_valid[37] <= 0; // Cache line 37's valid bit set to 0
            cache_valid[38] <= 0; // Cache line 38's valid bit set to 0
            cache_valid[39] <= 0; // Cache line 39's valid bit set to 0
            cache_valid[40] <= 0; // Cache line 40's valid bit set to 0
            cache_valid[41] <= 0; // Cache line 41's valid bit set to 0
            cache_valid[42] <= 0; // Cache line 42's valid bit set to 0
            cache_valid[43] <= 0; // Cache line 43's valid bit set to 0
            cache_valid[44] <= 0; // Cache line 44's valid bit set to 0
            cache_valid[45] <= 0; // Cache line 45's valid bit set to 0
            cache_valid[46] <= 0; // Cache line 46's valid bit set to 0
            cache_valid[47] <= 0; // Cache line 47's valid bit set to 0
            cache_valid[48] <= 0; // Cache line 48's valid bit set to 0
            cache_valid[49] <= 0; // Cache line 49's valid bit set to 0
            cache_valid[50] <= 0; // Cache line 50's valid bit set to 0
            cache_valid[51] <= 0; // Cache line 51's valid bit set to 0
            cache_valid[52] <= 0; // Cache line 52's valid bit set to 0
            cache_valid[53] <= 0; // Cache line 53's valid bit set to 0
            cache_valid[54] <= 0; // Cache line 54's valid bit set to 0
            cache_valid[55] <= 0; // Cache line 55's valid bit set to 0
            cache_valid[56] <= 0; // Cache line 56's valid bit set to 0
            cache_valid[57] <= 0; // Cache line 57's valid bit set to 0
            cache_valid[58] <= 0; // Cache line 58's valid bit set to 0
            cache_valid[59] <= 0; // Cache line 59's valid bit set to 0
            cache_valid[60] <= 0; // Cache line 60's valid bit set to 0
            cache_valid[61] <= 0; // Cache line 61's valid bit set to 0
            cache_valid[62] <= 0; // Cache line 62's valid bit set to 0
            cache_valid[63] <= 0; // Cache line 63's valid bit set to 0
            cache_valid[64] <= 0; // Cache line 64's valid bit set to 0
            cache_valid[65] <= 0; // Cache line 65's valid bit set to 0
            cache_valid[66] <= 0; // Cache line 66's valid bit set to 0
            cache_valid[67] <= 0; // Cache line 67's valid bit set to 0
            cache_valid[68] <= 0; // Cache line 68's valid bit set to 0
            cache_valid[69] <= 0; // Cache line 69's valid bit set to 0
            cache_valid[70] <= 0; // Cache line 70's valid bit set to 0
            cache_valid[71] <= 0; // Cache line 71's valid bit set to 0
            cache_valid[72] <= 0; // Cache line 72's valid bit set to 0
            cache_valid[73] <= 0; // Cache line 73's valid bit set to 0
            cache_valid[74] <= 0; // Cache line 74's valid bit set to 0
            cache_valid[75] <= 0; // Cache line 75's valid bit set to 0
            cache_valid[76] <= 0; // Cache line 76's valid bit set to 0
            cache_valid[77] <= 0; // Cache line 77's valid bit set to 0
            cache_valid[78] <= 0; // Cache line 78's valid bit set to 0
            cache_valid[79] <= 0; // Cache line 79's valid bit set to 0
            cache_valid[80] <= 0; // Cache line 80's valid bit set to 0
            cache_valid[81] <= 0; // Cache line 81's valid bit set to 0
            cache_valid[82] <= 0; // Cache line 82's valid bit set to 0
            cache_valid[83] <= 0; // Cache line 83's valid bit set to 0
            cache_valid[84] <= 0; // Cache line 84's valid bit set to 0
            cache_valid[85] <= 0; // Cache line 85's valid bit set to 0
            cache_valid[86] <= 0; // Cache line 86's valid bit set to 0
            cache_valid[87] <= 0; // Cache line 87's valid bit set to 0
            cache_valid[88] <= 0; // Cache line 88's valid bit set to 0
            cache_valid[89] <= 0; // Cache line 89's valid bit set to 0
            cache_valid[90] <= 0; // Cache line 90's valid bit set to 0
            cache_valid[91] <= 0; // Cache line 91's valid bit set to 0
            cache_valid[92] <= 0; // Cache line 92's valid bit set to 0
            cache_valid[93] <= 0; // Cache line 93's valid bit set to 0
            cache_valid[94] <= 0; // Cache line 94's valid bit set to 0
            cache_valid[95] <= 0; // Cache line 95's valid bit set to 0
            cache_valid[96] <= 0; // Cache line 96's valid bit set to 0
            cache_valid[97] <= 0; // Cache line 97's valid bit set to 0
            cache_valid[98] <= 0; // Cache line 98's valid bit set to 0
            cache_valid[99] <= 0; // Cache line 99's valid bit set to 0
            cache_valid[100] <= 0; // Cache line 100's valid bit set to 0
            cache_valid[101] <= 0; // Cache line 101's valid bit set to 0
            cache_valid[102] <= 0; // Cache line 102's valid bit set to 0
            cache_valid[103] <= 0; // Cache line 103's valid bit set to 0
            cache_valid[104] <= 0; // Cache line 104's valid bit set to 0
            cache_valid[105] <= 0; // Cache line 105's valid bit set to 0
            cache_valid[106] <= 0; // Cache line 106's valid bit set to 0
            cache_valid[107] <= 0; // Cache line 107's valid bit set to 0
            cache_valid[108] <= 0; // Cache line 108's valid bit set to 0
            cache_valid[109] <= 0; // Cache line 109's valid bit set to 0
            cache_valid[110] <= 0; // Cache line 110's valid bit set to 0
            cache_valid[111] <= 0; // Cache line 111's valid bit set to 0
            cache_valid[112] <= 0; // Cache line 112's valid bit set to 0
            cache_valid[113] <= 0; // Cache line 113's valid bit set to 0
            cache_valid[114] <= 0; // Cache line 114's valid bit set to 0
            cache_valid[115] <= 0; // Cache line 115's valid bit set to 0
            cache_valid[116] <= 0; // Cache line 116's valid bit set to 0
            cache_valid[117] <= 0; // Cache line 117's valid bit set to 0
            cache_valid[118] <= 0; // Cache line 118's valid bit set to 0
            cache_valid[119] <= 0; // Cache line 119's valid bit set to 0
            cache_valid[120] <= 0; // Cache line 120's valid bit set to 0
            cache_valid[121] <= 0; // Cache line 121's valid bit set to 0
            cache_valid[122] <= 0; // Cache line 122's valid bit set to 0
            cache_valid[123] <= 0; // Cache line 123's valid bit set to 0
            cache_valid[124] <= 0; // Cache line 124's valid bit set to 0
            cache_valid[125] <= 0; // Cache line 125's valid bit set to 0
            cache_valid[126] <= 0; // Cache line 126's valid bit set to 0
            cache_valid[127] <= 0; // Cache line 127's valid bit set to 0
            cache_valid[128] <= 0; // Cache line 128's valid bit set to 0
            cache_valid[129] <= 0; // Cache line 129's valid bit set to 0
            cache_valid[130] <= 0; // Cache line 130's valid bit set to 0
            cache_valid[131] <= 0; // Cache line 131's valid bit set to 0
            cache_valid[132] <= 0; // Cache line 132's valid bit set to 0
            cache_valid[133] <= 0; // Cache line 133's valid bit set to 0
            cache_valid[134] <= 0; // Cache line 134's valid bit set to 0
            cache_valid[135] <= 0; // Cache line 135's valid bit set to 0
            cache_valid[136] <= 0; // Cache line 136's valid bit set to 0
            cache_valid[137] <= 0; // Cache line 137's valid bit set to 0
            cache_valid[138] <= 0; // Cache line 138's valid bit set to 0
            cache_valid[139] <= 0; // Cache line 139's valid bit set to 0
            cache_valid[140] <= 0; // Cache line 140's valid bit set to 0
            cache_valid[141] <= 0; // Cache line 141's valid bit set to 0
            cache_valid[142] <= 0; // Cache line 142's valid bit set to 0
            cache_valid[143] <= 0; // Cache line 143's valid bit set to 0
            cache_valid[144] <= 0; // Cache line 144's valid bit set to 0
            cache_valid[145] <= 0; // Cache line 145's valid bit set to 0
            cache_valid[146] <= 0; // Cache line 146's valid bit set to 0
            cache_valid[147] <= 0; // Cache line 147's valid bit set to 0
            cache_valid[148] <= 0; // Cache line 148's valid bit set to 0
            cache_valid[149] <= 0; // Cache line 149's valid bit set to 0
            cache_valid[150] <= 0; // Cache line 150's valid bit set to 0
            cache_valid[151] <= 0; // Cache line 151's valid bit set to 0
            cache_valid[152] <= 0; // Cache line 152's valid bit set to 0
            cache_valid[153] <= 0; // Cache line 153's valid bit set to 0
            cache_valid[154] <= 0; // Cache line 154's valid bit set to 0
            cache_valid[155] <= 0; // Cache line 155's valid bit set to 0
            cache_valid[156] <= 0; // Cache line 156's valid bit set to 0
            cache_valid[157] <= 0; // Cache line 157's valid bit set to 0
            cache_valid[158] <= 0; // Cache line 158's valid bit set to 0
            cache_valid[159] <= 0; // Cache line 159's valid bit set to 0
            cache_valid[160] <= 0; // Cache line 160's valid bit set to 0
            cache_valid[161] <= 0; // Cache line 161's valid bit set to 0
            cache_valid[162] <= 0; // Cache line 162's valid bit set to 0
            cache_valid[163] <= 0; // Cache line 163's valid bit set to 0
            cache_valid[164] <= 0; // Cache line 164's valid bit set to 0
            cache_valid[165] <= 0; // Cache line 165's valid bit set to 0
            cache_valid[166] <= 0; // Cache line 166's valid bit set to 0
            cache_valid[167] <= 0; // Cache line 167's valid bit set to 0
            cache_valid[168] <= 0; // Cache line 168's valid bit set to 0
            cache_valid[169] <= 0; // Cache line 169's valid bit set to 0
            cache_valid[170] <= 0; // Cache line 170's valid bit set to 0
            cache_valid[171] <= 0; // Cache line 171's valid bit set to 0
            cache_valid[172] <= 0; // Cache line 172's valid bit set to 0
            cache_valid[173] <= 0; // Cache line 173's valid bit set to 0
            cache_valid[174] <= 0; // Cache line 174's valid bit set to 0
            cache_valid[175] <= 0; // Cache line 175's valid bit set to 0
            cache_valid[176] <= 0; // Cache line 176's valid bit set to 0
            cache_valid[177] <= 0; // Cache line 177's valid bit set to 0
            cache_valid[178] <= 0; // Cache line 178's valid bit set to 0
            cache_valid[179] <= 0; // Cache line 179's valid bit set to 0
            cache_valid[180] <= 0; // Cache line 180's valid bit set to 0
            cache_valid[181] <= 0; // Cache line 181's valid bit set to 0
            cache_valid[182] <= 0; // Cache line 182's valid bit set to 0
            cache_valid[183] <= 0; // Cache line 183's valid bit set to 0
            cache_valid[184] <= 0; // Cache line 184's valid bit set to 0
            cache_valid[185] <= 0; // Cache line 185's valid bit set to 0
            cache_valid[186] <= 0; // Cache line 186's valid bit set to 0
            cache_valid[187] <= 0; // Cache line 187's valid bit set to 0
            cache_valid[188] <= 0; // Cache line 188's valid bit set to 0
            cache_valid[189] <= 0; // Cache line 189's valid bit set to 0
            cache_valid[190] <= 0; // Cache line 190's valid bit set to 0
            cache_valid[191] <= 0; // Cache line 191's valid bit set to 0
            cache_valid[192] <= 0; // Cache line 192's valid bit set to 0
            cache_valid[193] <= 0; // Cache line 193's valid bit set to 0
            cache_valid[194] <= 0; // Cache line 194's valid bit set to 0
            cache_valid[195] <= 0; // Cache line 195's valid bit set to 0
            cache_valid[196] <= 0; // Cache line 196's valid bit set to 0
            cache_valid[197] <= 0; // Cache line 197's valid bit set to 0
            cache_valid[198] <= 0; // Cache line 198's valid bit set to 0
            cache_valid[199] <= 0; // Cache line 199's valid bit set to 0
            cache_valid[200] <= 0; // Cache line 200's valid bit set to 0
            cache_valid[201] <= 0; // Cache line 201's valid bit set to 0
            cache_valid[202] <= 0; // Cache line 202's valid bit set to 0
            cache_valid[203] <= 0; // Cache line 203's valid bit set to 0
            cache_valid[204] <= 0; // Cache line 204's valid bit set to 0
            cache_valid[205] <= 0; // Cache line 205's valid bit set to 0
            cache_valid[206] <= 0; // Cache line 206's valid bit set to 0
            cache_valid[207] <= 0; // Cache line 207's valid bit set to 0
            cache_valid[208] <= 0; // Cache line 208's valid bit set to 0
            cache_valid[209] <= 0; // Cache line 209's valid bit set to 0
            cache_valid[210] <= 0; // Cache line 210's valid bit set to 0
            cache_valid[211] <= 0; // Cache line 211's valid bit set to 0
            cache_valid[212] <= 0; // Cache line 212's valid bit set to 0
            cache_valid[213] <= 0; // Cache line 213's valid bit set to 0
            cache_valid[214] <= 0; // Cache line 214's valid bit set to 0
            cache_valid[215] <= 0; // Cache line 215's valid bit set to 0
            cache_valid[216] <= 0; // Cache line 216's valid bit set to 0
            cache_valid[217] <= 0; // Cache line 217's valid bit set to 0
            cache_valid[218] <= 0; // Cache line 218's valid bit set to 0
            cache_valid[219] <= 0; // Cache line 219's valid bit set to 0
            cache_valid[220] <= 0; // Cache line 220's valid bit set to 0
            cache_valid[221] <= 0; // Cache line 221's valid bit set to 0
            cache_valid[222] <= 0; // Cache line 222's valid bit set to 0
            cache_valid[223] <= 0; // Cache line 223's valid bit set to 0
            cache_valid[224] <= 0; // Cache line 224's valid bit set to 0
            cache_valid[225] <= 0; // Cache line 225's valid bit set to 0
            cache_valid[226] <= 0; // Cache line 226's valid bit set to 0
            cache_valid[227] <= 0; // Cache line 227's valid bit set to 0
            cache_valid[228] <= 0; // Cache line 228's valid bit set to 0
            cache_valid[229] <= 0; // Cache line 229's valid bit set to 0
            cache_valid[230] <= 0; // Cache line 230's valid bit set to 0
            cache_valid[231] <= 0; // Cache line 231's valid bit set to 0
            cache_valid[232] <= 0; // Cache line 232's valid bit set to 0
            cache_valid[233] <= 0; // Cache line 233's valid bit set to 0
            cache_valid[234] <= 0; // Cache line 234's valid bit set to 0
            cache_valid[235] <= 0; // Cache line 235's valid bit set to 0
            cache_valid[236] <= 0; // Cache line 236's valid bit set to 0
            cache_valid[237] <= 0; // Cache line 237's valid bit set to 0
            cache_valid[238] <= 0; // Cache line 238's valid bit set to 0
            cache_valid[239] <= 0; // Cache line 239's valid bit set to 0
            cache_valid[240] <= 0; // Cache line 240's valid bit set to 0
            cache_valid[241] <= 0; // Cache line 241's valid bit set to 0
            cache_valid[242] <= 0; // Cache line 242's valid bit set to 0
            cache_valid[243] <= 0; // Cache line 243's valid bit set to 0
            cache_valid[244] <= 0; // Cache line 244's valid bit set to 0
            cache_valid[245] <= 0; // Cache line 245's valid bit set to 0
            cache_valid[246] <= 0; // Cache line 246's valid bit set to 0
            cache_valid[247] <= 0; // Cache line 247's valid bit set to 0
            cache_valid[248] <= 0; // Cache line 248's valid bit set to 0
            cache_valid[249] <= 0; // Cache line 249's valid bit set to 0
            cache_valid[250] <= 0; // Cache line 250's valid bit set to 0
            cache_valid[251] <= 0; // Cache line 251's valid bit set to 0
            cache_valid[252] <= 0; // Cache line 252's valid bit set to 0
            cache_valid[253] <= 0; // Cache line 253's valid bit set to 0
            cache_valid[254] <= 0; // Cache line 254's valid bit set to 0
            cache_valid[255] <= 0; // Cache line 255's valid bit set to 0
            cache_valid[256] <= 0; // Cache line 256's valid bit set to 0
            cache_valid[257] <= 0; // Cache line 257's valid bit set to 0
            cache_valid[258] <= 0; // Cache line 258's valid bit set to 0
            cache_valid[259] <= 0; // Cache line 259's valid bit set to 0
            cache_valid[260] <= 0; // Cache line 260's valid bit set to 0
            cache_valid[261] <= 0; // Cache line 261's valid bit set to 0
            cache_valid[262] <= 0; // Cache line 262's valid bit set to 0
            cache_valid[263] <= 0; // Cache line 263's valid bit set to 0
            cache_valid[264] <= 0; // Cache line 264's valid bit set to 0
            cache_valid[265] <= 0; // Cache line 265's valid bit set to 0
            cache_valid[266] <= 0; // Cache line 266's valid bit set to 0
            cache_valid[267] <= 0; // Cache line 267's valid bit set to 0
            cache_valid[268] <= 0; // Cache line 268's valid bit set to 0
            cache_valid[269] <= 0; // Cache line 269's valid bit set to 0
            cache_valid[270] <= 0; // Cache line 270's valid bit set to 0
            cache_valid[271] <= 0; // Cache line 271's valid bit set to 0
            cache_valid[272] <= 0; // Cache line 272's valid bit set to 0
            cache_valid[273] <= 0; // Cache line 273's valid bit set to 0
            cache_valid[274] <= 0; // Cache line 274's valid bit set to 0
            cache_valid[275] <= 0; // Cache line 275's valid bit set to 0
            cache_valid[276] <= 0; // Cache line 276's valid bit set to 0
            cache_valid[277] <= 0; // Cache line 277's valid bit set to 0
            cache_valid[278] <= 0; // Cache line 278's valid bit set to 0
            cache_valid[279] <= 0; // Cache line 279's valid bit set to 0
            cache_valid[280] <= 0; // Cache line 280's valid bit set to 0
            cache_valid[281] <= 0; // Cache line 281's valid bit set to 0
            cache_valid[282] <= 0; // Cache line 282's valid bit set to 0
            cache_valid[283] <= 0; // Cache line 283's valid bit set to 0
            cache_valid[284] <= 0; // Cache line 284's valid bit set to 0
            cache_valid[285] <= 0; // Cache line 285's valid bit set to 0
            cache_valid[286] <= 0; // Cache line 286's valid bit set to 0
            cache_valid[287] <= 0; // Cache line 287's valid bit set to 0
            cache_valid[288] <= 0; // Cache line 288's valid bit set to 0
            cache_valid[289] <= 0; // Cache line 289's valid bit set to 0
            cache_valid[290] <= 0; // Cache line 290's valid bit set to 0
            cache_valid[291] <= 0; // Cache line 291's valid bit set to 0
            cache_valid[292] <= 0; // Cache line 292's valid bit set to 0
            cache_valid[293] <= 0; // Cache line 293's valid bit set to 0
            cache_valid[294] <= 0; // Cache line 294's valid bit set to 0
            cache_valid[295] <= 0; // Cache line 295's valid bit set to 0
            cache_valid[296] <= 0; // Cache line 296's valid bit set to 0
            cache_valid[297] <= 0; // Cache line 297's valid bit set to 0
            cache_valid[298] <= 0; // Cache line 298's valid bit set to 0
            cache_valid[299] <= 0; // Cache line 299's valid bit set to 0
            cache_valid[300] <= 0; // Cache line 300's valid bit set to 0
            cache_valid[301] <= 0; // Cache line 301's valid bit set to 0
            cache_valid[302] <= 0; // Cache line 302's valid bit set to 0
            cache_valid[303] <= 0; // Cache line 303's valid bit set to 0
            cache_valid[304] <= 0; // Cache line 304's valid bit set to 0
            cache_valid[305] <= 0; // Cache line 305's valid bit set to 0
            cache_valid[306] <= 0; // Cache line 306's valid bit set to 0
            cache_valid[307] <= 0; // Cache line 307's valid bit set to 0
            cache_valid[308] <= 0; // Cache line 308's valid bit set to 0
            cache_valid[309] <= 0; // Cache line 309's valid bit set to 0
            cache_valid[310] <= 0; // Cache line 310's valid bit set to 0
            cache_valid[311] <= 0; // Cache line 311's valid bit set to 0
            cache_valid[312] <= 0; // Cache line 312's valid bit set to 0
            cache_valid[313] <= 0; // Cache line 313's valid bit set to 0
            cache_valid[314] <= 0; // Cache line 314's valid bit set to 0
            cache_valid[315] <= 0; // Cache line 315's valid bit set to 0
            cache_valid[316] <= 0; // Cache line 316's valid bit set to 0
            cache_valid[317] <= 0; // Cache line 317's valid bit set to 0
            cache_valid[318] <= 0; // Cache line 318's valid bit set to 0
            cache_valid[319] <= 0; // Cache line 319's valid bit set to 0
            cache_valid[320] <= 0; // Cache line 320's valid bit set to 0
            cache_valid[321] <= 0; // Cache line 321's valid bit set to 0
            cache_valid[322] <= 0; // Cache line 322's valid bit set to 0
            cache_valid[323] <= 0; // Cache line 323's valid bit set to 0
            cache_valid[324] <= 0; // Cache line 324's valid bit set to 0
            cache_valid[325] <= 0; // Cache line 325's valid bit set to 0
            cache_valid[326] <= 0; // Cache line 326's valid bit set to 0
            cache_valid[327] <= 0; // Cache line 327's valid bit set to 0
            cache_valid[328] <= 0; // Cache line 328's valid bit set to 0
            cache_valid[329] <= 0; // Cache line 329's valid bit set to 0
            cache_valid[330] <= 0; // Cache line 330's valid bit set to 0
            cache_valid[331] <= 0; // Cache line 331's valid bit set to 0
            cache_valid[332] <= 0; // Cache line 332's valid bit set to 0
            cache_valid[333] <= 0; // Cache line 333's valid bit set to 0
            cache_valid[334] <= 0; // Cache line 334's valid bit set to 0
            cache_valid[335] <= 0; // Cache line 335's valid bit set to 0
            cache_valid[336] <= 0; // Cache line 336's valid bit set to 0
            cache_valid[337] <= 0; // Cache line 337's valid bit set to 0
            cache_valid[338] <= 0; // Cache line 338's valid bit set to 0
            cache_valid[339] <= 0; // Cache line 339's valid bit set to 0
            cache_valid[340] <= 0; // Cache line 340's valid bit set to 0
            cache_valid[341] <= 0; // Cache line 341's valid bit set to 0
            cache_valid[342] <= 0; // Cache line 342's valid bit set to 0
            cache_valid[343] <= 0; // Cache line 343's valid bit set to 0
            cache_valid[344] <= 0; // Cache line 344's valid bit set to 0
            cache_valid[345] <= 0; // Cache line 345's valid bit set to 0
            cache_valid[346] <= 0; // Cache line 346's valid bit set to 0
            cache_valid[347] <= 0; // Cache line 347's valid bit set to 0
            cache_valid[348] <= 0; // Cache line 348's valid bit set to 0
            cache_valid[349] <= 0; // Cache line 349's valid bit set to 0
            cache_valid[350] <= 0; // Cache line 350's valid bit set to 0
            cache_valid[351] <= 0; // Cache line 351's valid bit set to 0
            cache_valid[352] <= 0; // Cache line 352's valid bit set to 0
            cache_valid[353] <= 0; // Cache line 353's valid bit set to 0
            cache_valid[354] <= 0; // Cache line 354's valid bit set to 0
            cache_valid[355] <= 0; // Cache line 355's valid bit set to 0
            cache_valid[356] <= 0; // Cache line 356's valid bit set to 0
            cache_valid[357] <= 0; // Cache line 357's valid bit set to 0
            cache_valid[358] <= 0; // Cache line 358's valid bit set to 0
            cache_valid[359] <= 0; // Cache line 359's valid bit set to 0
            cache_valid[360] <= 0; // Cache line 360's valid bit set to 0
            cache_valid[361] <= 0; // Cache line 361's valid bit set to 0
            cache_valid[362] <= 0; // Cache line 362's valid bit set to 0
            cache_valid[363] <= 0; // Cache line 363's valid bit set to 0
            cache_valid[364] <= 0; // Cache line 364's valid bit set to 0
            cache_valid[365] <= 0; // Cache line 365's valid bit set to 0
            cache_valid[366] <= 0; // Cache line 366's valid bit set to 0
            cache_valid[367] <= 0; // Cache line 367's valid bit set to 0
            cache_valid[368] <= 0; // Cache line 368's valid bit set to 0
            cache_valid[369] <= 0; // Cache line 369's valid bit set to 0
            cache_valid[370] <= 0; // Cache line 370's valid bit set to 0
            cache_valid[371] <= 0; // Cache line 371's valid bit set to 0
            cache_valid[372] <= 0; // Cache line 372's valid bit set to 0
            cache_valid[373] <= 0; // Cache line 373's valid bit set to 0
            cache_valid[374] <= 0; // Cache line 374's valid bit set to 0
            cache_valid[375] <= 0; // Cache line 375's valid bit set to 0
            cache_valid[376] <= 0; // Cache line 376's valid bit set to 0
            cache_valid[377] <= 0; // Cache line 377's valid bit set to 0
            cache_valid[378] <= 0; // Cache line 378's valid bit set to 0
            cache_valid[379] <= 0; // Cache line 379's valid bit set to 0
            cache_valid[380] <= 0; // Cache line 380's valid bit set to 0
            cache_valid[381] <= 0; // Cache line 381's valid bit set to 0
            cache_valid[382] <= 0; // Cache line 382's valid bit set to 0
            cache_valid[383] <= 0; // Cache line 383's valid bit set to 0
            cache_valid[384] <= 0; // Cache line 384's valid bit set to 0
            cache_valid[385] <= 0; // Cache line 385's valid bit set to 0
            cache_valid[386] <= 0; // Cache line 386's valid bit set to 0
            cache_valid[387] <= 0; // Cache line 387's valid bit set to 0
            cache_valid[388] <= 0; // Cache line 388's valid bit set to 0
            cache_valid[389] <= 0; // Cache line 389's valid bit set to 0
            cache_valid[390] <= 0; // Cache line 390's valid bit set to 0
            cache_valid[391] <= 0; // Cache line 391's valid bit set to 0
            cache_valid[392] <= 0; // Cache line 392's valid bit set to 0
            cache_valid[393] <= 0; // Cache line 393's valid bit set to 0
            cache_valid[394] <= 0; // Cache line 394's valid bit set to 0
            cache_valid[395] <= 0; // Cache line 395's valid bit set to 0
            cache_valid[396] <= 0; // Cache line 396's valid bit set to 0
            cache_valid[397] <= 0; // Cache line 397's valid bit set to 0
            cache_valid[398] <= 0; // Cache line 398's valid bit set to 0
            cache_valid[399] <= 0; // Cache line 399's valid bit set to 0
            cache_valid[400] <= 0; // Cache line 400's valid bit set to 0
            cache_valid[401] <= 0; // Cache line 401's valid bit set to 0
            cache_valid[402] <= 0; // Cache line 402's valid bit set to 0
            cache_valid[403] <= 0; // Cache line 403's valid bit set to 0
            cache_valid[404] <= 0; // Cache line 404's valid bit set to 0
            cache_valid[405] <= 0; // Cache line 405's valid bit set to 0
            cache_valid[406] <= 0; // Cache line 406's valid bit set to 0
            cache_valid[407] <= 0; // Cache line 407's valid bit set to 0
            cache_valid[408] <= 0; // Cache line 408's valid bit set to 0
            cache_valid[409] <= 0; // Cache line 409's valid bit set to 0
            cache_valid[410] <= 0; // Cache line 410's valid bit set to 0
            cache_valid[411] <= 0; // Cache line 411's valid bit set to 0
            cache_valid[412] <= 0; // Cache line 412's valid bit set to 0
            cache_valid[413] <= 0; // Cache line 413's valid bit set to 0
            cache_valid[414] <= 0; // Cache line 414's valid bit set to 0
            cache_valid[415] <= 0; // Cache line 415's valid bit set to 0
            cache_valid[416] <= 0; // Cache line 416's valid bit set to 0
            cache_valid[417] <= 0; // Cache line 417's valid bit set to 0
            cache_valid[418] <= 0; // Cache line 418's valid bit set to 0
            cache_valid[419] <= 0; // Cache line 419's valid bit set to 0
            cache_valid[420] <= 0; // Cache line 420's valid bit set to 0
            cache_valid[421] <= 0; // Cache line 421's valid bit set to 0
            cache_valid[422] <= 0; // Cache line 422's valid bit set to 0
            cache_valid[423] <= 0; // Cache line 423's valid bit set to 0
            cache_valid[424] <= 0; // Cache line 424's valid bit set to 0
            cache_valid[425] <= 0; // Cache line 425's valid bit set to 0
            cache_valid[426] <= 0; // Cache line 426's valid bit set to 0
            cache_valid[427] <= 0; // Cache line 427's valid bit set to 0
            cache_valid[428] <= 0; // Cache line 428's valid bit set to 0
            cache_valid[429] <= 0; // Cache line 429's valid bit set to 0
            cache_valid[430] <= 0; // Cache line 430's valid bit set to 0
            cache_valid[431] <= 0; // Cache line 431's valid bit set to 0
            cache_valid[432] <= 0; // Cache line 432's valid bit set to 0
            cache_valid[433] <= 0; // Cache line 433's valid bit set to 0
            cache_valid[434] <= 0; // Cache line 434's valid bit set to 0
            cache_valid[435] <= 0; // Cache line 435's valid bit set to 0
            cache_valid[436] <= 0; // Cache line 436's valid bit set to 0
            cache_valid[437] <= 0; // Cache line 437's valid bit set to 0
            cache_valid[438] <= 0; // Cache line 438's valid bit set to 0
            cache_valid[439] <= 0; // Cache line 439's valid bit set to 0
            cache_valid[440] <= 0; // Cache line 440's valid bit set to 0
            cache_valid[441] <= 0; // Cache line 441's valid bit set to 0
            cache_valid[442] <= 0; // Cache line 442's valid bit set to 0
            cache_valid[443] <= 0; // Cache line 443's valid bit set to 0
            cache_valid[444] <= 0; // Cache line 444's valid bit set to 0
            cache_valid[445] <= 0; // Cache line 445's valid bit set to 0
            cache_valid[446] <= 0; // Cache line 446's valid bit set to 0
            cache_valid[447] <= 0; // Cache line 447's valid bit set to 0
            cache_valid[448] <= 0; // Cache line 448's valid bit set to 0
            cache_valid[449] <= 0; // Cache line 449's valid bit set to 0
            cache_valid[450] <= 0; // Cache line 450's valid bit set to 0
            cache_valid[451] <= 0; // Cache line 451's valid bit set to 0
            cache_valid[452] <= 0; // Cache line 452's valid bit set to 0
            cache_valid[453] <= 0; // Cache line 453's valid bit set to 0
            cache_valid[454] <= 0; // Cache line 454's valid bit set to 0
            cache_valid[455] <= 0; // Cache line 455's valid bit set to 0
            cache_valid[456] <= 0; // Cache line 456's valid bit set to 0
            cache_valid[457] <= 0; // Cache line 457's valid bit set to 0
            cache_valid[458] <= 0; // Cache line 458's valid bit set to 0
            cache_valid[459] <= 0; // Cache line 459's valid bit set to 0
            cache_valid[460] <= 0; // Cache line 460's valid bit set to 0
            cache_valid[461] <= 0; // Cache line 461's valid bit set to 0
            cache_valid[462] <= 0; // Cache line 462's valid bit set to 0
            cache_valid[463] <= 0; // Cache line 463's valid bit set to 0
            cache_valid[464] <= 0; // Cache line 464's valid bit set to 0
            cache_valid[465] <= 0; // Cache line 465's valid bit set to 0
            cache_valid[466] <= 0; // Cache line 466's valid bit set to 0
            cache_valid[467] <= 0; // Cache line 467's valid bit set to 0
            cache_valid[468] <= 0; // Cache line 468's valid bit set to 0
            cache_valid[469] <= 0; // Cache line 469's valid bit set to 0
            cache_valid[470] <= 0; // Cache line 470's valid bit set to 0
            cache_valid[471] <= 0; // Cache line 471's valid bit set to 0
            cache_valid[472] <= 0; // Cache line 472's valid bit set to 0
            cache_valid[473] <= 0; // Cache line 473's valid bit set to 0
            cache_valid[474] <= 0; // Cache line 474's valid bit set to 0
            cache_valid[475] <= 0; // Cache line 475's valid bit set to 0
            cache_valid[476] <= 0; // Cache line 476's valid bit set to 0
            cache_valid[477] <= 0; // Cache line 477's valid bit set to 0
            cache_valid[478] <= 0; // Cache line 478's valid bit set to 0
            cache_valid[479] <= 0; // Cache line 479's valid bit set to 0
            cache_valid[480] <= 0; // Cache line 480's valid bit set to 0
            cache_valid[481] <= 0; // Cache line 481's valid bit set to 0
            cache_valid[482] <= 0; // Cache line 482's valid bit set to 0
            cache_valid[483] <= 0; // Cache line 483's valid bit set to 0
            cache_valid[484] <= 0; // Cache line 484's valid bit set to 0
            cache_valid[485] <= 0; // Cache line 485's valid bit set to 0
            cache_valid[486] <= 0; // Cache line 486's valid bit set to 0
            cache_valid[487] <= 0; // Cache line 487's valid bit set to 0
            cache_valid[488] <= 0; // Cache line 488's valid bit set to 0
            cache_valid[489] <= 0; // Cache line 489's valid bit set to 0
            cache_valid[490] <= 0; // Cache line 490's valid bit set to 0
            cache_valid[491] <= 0; // Cache line 491's valid bit set to 0
            cache_valid[492] <= 0; // Cache line 492's valid bit set to 0
            cache_valid[493] <= 0; // Cache line 493's valid bit set to 0
            cache_valid[494] <= 0; // Cache line 494's valid bit set to 0
            cache_valid[495] <= 0; // Cache line 495's valid bit set to 0
            cache_valid[496] <= 0; // Cache line 496's valid bit set to 0
            cache_valid[497] <= 0; // Cache line 497's valid bit set to 0
            cache_valid[498] <= 0; // Cache line 498's valid bit set to 0
            cache_valid[499] <= 0; // Cache line 499's valid bit set to 0
            cache_valid[500] <= 0; // Cache line 500's valid bit set to 0
            cache_valid[501] <= 0; // Cache line 501's valid bit set to 0
            cache_valid[502] <= 0; // Cache line 502's valid bit set to 0
            cache_valid[503] <= 0; // Cache line 503's valid bit set to 0
            cache_valid[504] <= 0; // Cache line 504's valid bit set to 0
            cache_valid[505] <= 0; // Cache line 505's valid bit set to 0
            cache_valid[506] <= 0; // Cache line 506's valid bit set to 0
            cache_valid[507] <= 0; // Cache line 507's valid bit set to 0
            cache_valid[508] <= 0; // Cache line 508's valid bit set to 0
            cache_valid[509] <= 0; // Cache line 509's valid bit set to 0
            cache_valid[510] <= 0; // Cache line 510's valid bit set to 0
            cache_valid[511] <= 0; // Cache line 511's valid bit set to 0
            cache_valid[512] <= 0; // Cache line 512's valid bit set to 0
            cache_valid[513] <= 0; // Cache line 513's valid bit set to 0
            cache_valid[514] <= 0; // Cache line 514's valid bit set to 0
            cache_valid[515] <= 0; // Cache line 515's valid bit set to 0
            cache_valid[516] <= 0; // Cache line 516's valid bit set to 0
            cache_valid[517] <= 0; // Cache line 517's valid bit set to 0
            cache_valid[518] <= 0; // Cache line 518's valid bit set to 0
            cache_valid[519] <= 0; // Cache line 519's valid bit set to 0
            cache_valid[520] <= 0; // Cache line 520's valid bit set to 0
            cache_valid[521] <= 0; // Cache line 521's valid bit set to 0
            cache_valid[522] <= 0; // Cache line 522's valid bit set to 0
            cache_valid[523] <= 0; // Cache line 523's valid bit set to 0
            cache_valid[524] <= 0; // Cache line 524's valid bit set to 0
            cache_valid[525] <= 0; // Cache line 525's valid bit set to 0
            cache_valid[526] <= 0; // Cache line 526's valid bit set to 0
            cache_valid[527] <= 0; // Cache line 527's valid bit set to 0
            cache_valid[528] <= 0; // Cache line 528's valid bit set to 0
            cache_valid[529] <= 0; // Cache line 529's valid bit set to 0
            cache_valid[530] <= 0; // Cache line 530's valid bit set to 0
            cache_valid[531] <= 0; // Cache line 531's valid bit set to 0
            cache_valid[532] <= 0; // Cache line 532's valid bit set to 0
            cache_valid[533] <= 0; // Cache line 533's valid bit set to 0
            cache_valid[534] <= 0; // Cache line 534's valid bit set to 0
            cache_valid[535] <= 0; // Cache line 535's valid bit set to 0
            cache_valid[536] <= 0; // Cache line 536's valid bit set to 0
            cache_valid[537] <= 0; // Cache line 537's valid bit set to 0
            cache_valid[538] <= 0; // Cache line 538's valid bit set to 0
            cache_valid[539] <= 0; // Cache line 539's valid bit set to 0
            cache_valid[540] <= 0; // Cache line 540's valid bit set to 0
            cache_valid[541] <= 0; // Cache line 541's valid bit set to 0
            cache_valid[542] <= 0; // Cache line 542's valid bit set to 0
            cache_valid[543] <= 0; // Cache line 543's valid bit set to 0
            cache_valid[544] <= 0; // Cache line 544's valid bit set to 0
            cache_valid[545] <= 0; // Cache line 545's valid bit set to 0
            cache_valid[546] <= 0; // Cache line 546's valid bit set to 0
            cache_valid[547] <= 0; // Cache line 547's valid bit set to 0
            cache_valid[548] <= 0; // Cache line 548's valid bit set to 0
            cache_valid[549] <= 0; // Cache line 549's valid bit set to 0
            cache_valid[550] <= 0; // Cache line 550's valid bit set to 0
            cache_valid[551] <= 0; // Cache line 551's valid bit set to 0
            cache_valid[552] <= 0; // Cache line 552's valid bit set to 0
            cache_valid[553] <= 0; // Cache line 553's valid bit set to 0
            cache_valid[554] <= 0; // Cache line 554's valid bit set to 0
            cache_valid[555] <= 0; // Cache line 555's valid bit set to 0
            cache_valid[556] <= 0; // Cache line 556's valid bit set to 0
            cache_valid[557] <= 0; // Cache line 557's valid bit set to 0
            cache_valid[558] <= 0; // Cache line 558's valid bit set to 0
            cache_valid[559] <= 0; // Cache line 559's valid bit set to 0
            cache_valid[560] <= 0; // Cache line 560's valid bit set to 0
            cache_valid[561] <= 0; // Cache line 561's valid bit set to 0
            cache_valid[562] <= 0; // Cache line 562's valid bit set to 0
            cache_valid[563] <= 0; // Cache line 563's valid bit set to 0
            cache_valid[564] <= 0; // Cache line 564's valid bit set to 0
            cache_valid[565] <= 0; // Cache line 565's valid bit set to 0
            cache_valid[566] <= 0; // Cache line 566's valid bit set to 0
            cache_valid[567] <= 0; // Cache line 567's valid bit set to 0
            cache_valid[568] <= 0; // Cache line 568's valid bit set to 0
            cache_valid[569] <= 0; // Cache line 569's valid bit set to 0
            cache_valid[570] <= 0; // Cache line 570's valid bit set to 0
            cache_valid[571] <= 0; // Cache line 571's valid bit set to 0
            cache_valid[572] <= 0; // Cache line 572's valid bit set to 0
            cache_valid[573] <= 0; // Cache line 573's valid bit set to 0
            cache_valid[574] <= 0; // Cache line 574's valid bit set to 0
            cache_valid[575] <= 0; // Cache line 575's valid bit set to 0
            cache_valid[576] <= 0; // Cache line 576's valid bit set to 0
            cache_valid[577] <= 0; // Cache line 577's valid bit set to 0
            cache_valid[578] <= 0; // Cache line 578's valid bit set to 0
            cache_valid[579] <= 0; // Cache line 579's valid bit set to 0
            cache_valid[580] <= 0; // Cache line 580's valid bit set to 0
            cache_valid[581] <= 0; // Cache line 581's valid bit set to 0
            cache_valid[582] <= 0; // Cache line 582's valid bit set to 0
            cache_valid[583] <= 0; // Cache line 583's valid bit set to 0
            cache_valid[584] <= 0; // Cache line 584's valid bit set to 0
            cache_valid[585] <= 0; // Cache line 585's valid bit set to 0
            cache_valid[586] <= 0; // Cache line 586's valid bit set to 0
            cache_valid[587] <= 0; // Cache line 587's valid bit set to 0
            cache_valid[588] <= 0; // Cache line 588's valid bit set to 0
            cache_valid[589] <= 0; // Cache line 589's valid bit set to 0
            cache_valid[590] <= 0; // Cache line 590's valid bit set to 0
            cache_valid[591] <= 0; // Cache line 591's valid bit set to 0
            cache_valid[592] <= 0; // Cache line 592's valid bit set to 0
            cache_valid[593] <= 0; // Cache line 593's valid bit set to 0
            cache_valid[594] <= 0; // Cache line 594's valid bit set to 0
            cache_valid[595] <= 0; // Cache line 595's valid bit set to 0
            cache_valid[596] <= 0; // Cache line 596's valid bit set to 0
            cache_valid[597] <= 0; // Cache line 597's valid bit set to 0
            cache_valid[598] <= 0; // Cache line 598's valid bit set to 0
            cache_valid[599] <= 0; // Cache line 599's valid bit set to 0
            cache_valid[600] <= 0; // Cache line 600's valid bit set to 0
            cache_valid[601] <= 0; // Cache line 601's valid bit set to 0
            cache_valid[602] <= 0; // Cache line 602's valid bit set to 0
            cache_valid[603] <= 0; // Cache line 603's valid bit set to 0
            cache_valid[604] <= 0; // Cache line 604's valid bit set to 0
            cache_valid[605] <= 0; // Cache line 605's valid bit set to 0
            cache_valid[606] <= 0; // Cache line 606's valid bit set to 0
            cache_valid[607] <= 0; // Cache line 607's valid bit set to 0
            cache_valid[608] <= 0; // Cache line 608's valid bit set to 0
            cache_valid[609] <= 0; // Cache line 609's valid bit set to 0
            cache_valid[610] <= 0; // Cache line 610's valid bit set to 0
            cache_valid[611] <= 0; // Cache line 611's valid bit set to 0
            cache_valid[612] <= 0; // Cache line 612's valid bit set to 0
            cache_valid[613] <= 0; // Cache line 613's valid bit set to 0
            cache_valid[614] <= 0; // Cache line 614's valid bit set to 0
            cache_valid[615] <= 0; // Cache line 615's valid bit set to 0
            cache_valid[616] <= 0; // Cache line 616's valid bit set to 0
            cache_valid[617] <= 0; // Cache line 617's valid bit set to 0
            cache_valid[618] <= 0; // Cache line 618's valid bit set to 0
            cache_valid[619] <= 0; // Cache line 619's valid bit set to 0
            cache_valid[620] <= 0; // Cache line 620's valid bit set to 0
            cache_valid[621] <= 0; // Cache line 621's valid bit set to 0
            cache_valid[622] <= 0; // Cache line 622's valid bit set to 0
            cache_valid[623] <= 0; // Cache line 623's valid bit set to 0
            cache_valid[624] <= 0; // Cache line 624's valid bit set to 0
            cache_valid[625] <= 0; // Cache line 625's valid bit set to 0
            cache_valid[626] <= 0; // Cache line 626's valid bit set to 0
            cache_valid[627] <= 0; // Cache line 627's valid bit set to 0
            cache_valid[628] <= 0; // Cache line 628's valid bit set to 0
            cache_valid[629] <= 0; // Cache line 629's valid bit set to 0
            cache_valid[630] <= 0; // Cache line 630's valid bit set to 0
            cache_valid[631] <= 0; // Cache line 631's valid bit set to 0
            cache_valid[632] <= 0; // Cache line 632's valid bit set to 0
            cache_valid[633] <= 0; // Cache line 633's valid bit set to 0
            cache_valid[634] <= 0; // Cache line 634's valid bit set to 0
            cache_valid[635] <= 0; // Cache line 635's valid bit set to 0
            cache_valid[636] <= 0; // Cache line 636's valid bit set to 0
            cache_valid[637] <= 0; // Cache line 637's valid bit set to 0
            cache_valid[638] <= 0; // Cache line 638's valid bit set to 0
            cache_valid[639] <= 0; // Cache line 639's valid bit set to 0
            cache_valid[640] <= 0; // Cache line 640's valid bit set to 0
            cache_valid[641] <= 0; // Cache line 641's valid bit set to 0
            cache_valid[642] <= 0; // Cache line 642's valid bit set to 0
            cache_valid[643] <= 0; // Cache line 643's valid bit set to 0
            cache_valid[644] <= 0; // Cache line 644's valid bit set to 0
            cache_valid[645] <= 0; // Cache line 645's valid bit set to 0
            cache_valid[646] <= 0; // Cache line 646's valid bit set to 0
            cache_valid[647] <= 0; // Cache line 647's valid bit set to 0
            cache_valid[648] <= 0; // Cache line 648's valid bit set to 0
            cache_valid[649] <= 0; // Cache line 649's valid bit set to 0
            cache_valid[650] <= 0; // Cache line 650's valid bit set to 0
            cache_valid[651] <= 0; // Cache line 651's valid bit set to 0
            cache_valid[652] <= 0; // Cache line 652's valid bit set to 0
            cache_valid[653] <= 0; // Cache line 653's valid bit set to 0
            cache_valid[654] <= 0; // Cache line 654's valid bit set to 0
            cache_valid[655] <= 0; // Cache line 655's valid bit set to 0
            cache_valid[656] <= 0; // Cache line 656's valid bit set to 0
            cache_valid[657] <= 0; // Cache line 657's valid bit set to 0
            cache_valid[658] <= 0; // Cache line 658's valid bit set to 0
            cache_valid[659] <= 0; // Cache line 659's valid bit set to 0
            cache_valid[660] <= 0; // Cache line 660's valid bit set to 0
            cache_valid[661] <= 0; // Cache line 661's valid bit set to 0
            cache_valid[662] <= 0; // Cache line 662's valid bit set to 0
            cache_valid[663] <= 0; // Cache line 663's valid bit set to 0
            cache_valid[664] <= 0; // Cache line 664's valid bit set to 0
            cache_valid[665] <= 0; // Cache line 665's valid bit set to 0
            cache_valid[666] <= 0; // Cache line 666's valid bit set to 0
            cache_valid[667] <= 0; // Cache line 667's valid bit set to 0
            cache_valid[668] <= 0; // Cache line 668's valid bit set to 0
            cache_valid[669] <= 0; // Cache line 669's valid bit set to 0
            cache_valid[670] <= 0; // Cache line 670's valid bit set to 0
            cache_valid[671] <= 0; // Cache line 671's valid bit set to 0
            cache_valid[672] <= 0; // Cache line 672's valid bit set to 0
            cache_valid[673] <= 0; // Cache line 673's valid bit set to 0
            cache_valid[674] <= 0; // Cache line 674's valid bit set to 0
            cache_valid[675] <= 0; // Cache line 675's valid bit set to 0
            cache_valid[676] <= 0; // Cache line 676's valid bit set to 0
            cache_valid[677] <= 0; // Cache line 677's valid bit set to 0
            cache_valid[678] <= 0; // Cache line 678's valid bit set to 0
            cache_valid[679] <= 0; // Cache line 679's valid bit set to 0
            cache_valid[680] <= 0; // Cache line 680's valid bit set to 0
            cache_valid[681] <= 0; // Cache line 681's valid bit set to 0
            cache_valid[682] <= 0; // Cache line 682's valid bit set to 0
            cache_valid[683] <= 0; // Cache line 683's valid bit set to 0
            cache_valid[684] <= 0; // Cache line 684's valid bit set to 0
            cache_valid[685] <= 0; // Cache line 685's valid bit set to 0
            cache_valid[686] <= 0; // Cache line 686's valid bit set to 0
            cache_valid[687] <= 0; // Cache line 687's valid bit set to 0
            cache_valid[688] <= 0; // Cache line 688's valid bit set to 0
            cache_valid[689] <= 0; // Cache line 689's valid bit set to 0
            cache_valid[690] <= 0; // Cache line 690's valid bit set to 0
            cache_valid[691] <= 0; // Cache line 691's valid bit set to 0
            cache_valid[692] <= 0; // Cache line 692's valid bit set to 0
            cache_valid[693] <= 0; // Cache line 693's valid bit set to 0
            cache_valid[694] <= 0; // Cache line 694's valid bit set to 0
            cache_valid[695] <= 0; // Cache line 695's valid bit set to 0
            cache_valid[696] <= 0; // Cache line 696's valid bit set to 0
            cache_valid[697] <= 0; // Cache line 697's valid bit set to 0
            cache_valid[698] <= 0; // Cache line 698's valid bit set to 0
            cache_valid[699] <= 0; // Cache line 699's valid bit set to 0
            cache_valid[700] <= 0; // Cache line 700's valid bit set to 0
            cache_valid[701] <= 0; // Cache line 701's valid bit set to 0
            cache_valid[702] <= 0; // Cache line 702's valid bit set to 0
            cache_valid[703] <= 0; // Cache line 703's valid bit set to 0
            cache_valid[704] <= 0; // Cache line 704's valid bit set to 0
            cache_valid[705] <= 0; // Cache line 705's valid bit set to 0
            cache_valid[706] <= 0; // Cache line 706's valid bit set to 0
            cache_valid[707] <= 0; // Cache line 707's valid bit set to 0
            cache_valid[708] <= 0; // Cache line 708's valid bit set to 0
            cache_valid[709] <= 0; // Cache line 709's valid bit set to 0
            cache_valid[710] <= 0; // Cache line 710's valid bit set to 0
            cache_valid[711] <= 0; // Cache line 711's valid bit set to 0
            cache_valid[712] <= 0; // Cache line 712's valid bit set to 0
            cache_valid[713] <= 0; // Cache line 713's valid bit set to 0
            cache_valid[714] <= 0; // Cache line 714's valid bit set to 0
            cache_valid[715] <= 0; // Cache line 715's valid bit set to 0
            cache_valid[716] <= 0; // Cache line 716's valid bit set to 0
            cache_valid[717] <= 0; // Cache line 717's valid bit set to 0
            cache_valid[718] <= 0; // Cache line 718's valid bit set to 0
            cache_valid[719] <= 0; // Cache line 719's valid bit set to 0
            cache_valid[720] <= 0; // Cache line 720's valid bit set to 0
            cache_valid[721] <= 0; // Cache line 721's valid bit set to 0
            cache_valid[722] <= 0; // Cache line 722's valid bit set to 0
            cache_valid[723] <= 0; // Cache line 723's valid bit set to 0
            cache_valid[724] <= 0; // Cache line 724's valid bit set to 0
            cache_valid[725] <= 0; // Cache line 725's valid bit set to 0
            cache_valid[726] <= 0; // Cache line 726's valid bit set to 0
            cache_valid[727] <= 0; // Cache line 727's valid bit set to 0
            cache_valid[728] <= 0; // Cache line 728's valid bit set to 0
            cache_valid[729] <= 0; // Cache line 729's valid bit set to 0
            cache_valid[730] <= 0; // Cache line 730's valid bit set to 0
            cache_valid[731] <= 0; // Cache line 731's valid bit set to 0
            cache_valid[732] <= 0; // Cache line 732's valid bit set to 0
            cache_valid[733] <= 0; // Cache line 733's valid bit set to 0
            cache_valid[734] <= 0; // Cache line 734's valid bit set to 0
            cache_valid[735] <= 0; // Cache line 735's valid bit set to 0
            cache_valid[736] <= 0; // Cache line 736's valid bit set to 0
            cache_valid[737] <= 0; // Cache line 737's valid bit set to 0
            cache_valid[738] <= 0; // Cache line 738's valid bit set to 0
            cache_valid[739] <= 0; // Cache line 739's valid bit set to 0
            cache_valid[740] <= 0; // Cache line 740's valid bit set to 0
            cache_valid[741] <= 0; // Cache line 741's valid bit set to 0
            cache_valid[742] <= 0; // Cache line 742's valid bit set to 0
            cache_valid[743] <= 0; // Cache line 743's valid bit set to 0
            cache_valid[744] <= 0; // Cache line 744's valid bit set to 0
            cache_valid[745] <= 0; // Cache line 745's valid bit set to 0
            cache_valid[746] <= 0; // Cache line 746's valid bit set to 0
            cache_valid[747] <= 0; // Cache line 747's valid bit set to 0
            cache_valid[748] <= 0; // Cache line 748's valid bit set to 0
            cache_valid[749] <= 0; // Cache line 749's valid bit set to 0
            cache_valid[750] <= 0; // Cache line 750's valid bit set to 0
            cache_valid[751] <= 0; // Cache line 751's valid bit set to 0
            cache_valid[752] <= 0; // Cache line 752's valid bit set to 0
            cache_valid[753] <= 0; // Cache line 753's valid bit set to 0
            cache_valid[754] <= 0; // Cache line 754's valid bit set to 0
            cache_valid[755] <= 0; // Cache line 755's valid bit set to 0
            cache_valid[756] <= 0; // Cache line 756's valid bit set to 0
            cache_valid[757] <= 0; // Cache line 757's valid bit set to 0
            cache_valid[758] <= 0; // Cache line 758's valid bit set to 0
            cache_valid[759] <= 0; // Cache line 759's valid bit set to 0
            cache_valid[760] <= 0; // Cache line 760's valid bit set to 0
            cache_valid[761] <= 0; // Cache line 761's valid bit set to 0
            cache_valid[762] <= 0; // Cache line 762's valid bit set to 0
            cache_valid[763] <= 0; // Cache line 763's valid bit set to 0
            cache_valid[764] <= 0; // Cache line 764's valid bit set to 0
            cache_valid[765] <= 0; // Cache line 765's valid bit set to 0
            cache_valid[766] <= 0; // Cache line 766's valid bit set to 0
            cache_valid[767] <= 0; // Cache line 767's valid bit set to 0
            cache_valid[768] <= 0; // Cache line 768's valid bit set to 0
            cache_valid[769] <= 0; // Cache line 769's valid bit set to 0
            cache_valid[770] <= 0; // Cache line 770's valid bit set to 0
            cache_valid[771] <= 0; // Cache line 771's valid bit set to 0
            cache_valid[772] <= 0; // Cache line 772's valid bit set to 0
            cache_valid[773] <= 0; // Cache line 773's valid bit set to 0
            cache_valid[774] <= 0; // Cache line 774's valid bit set to 0
            cache_valid[775] <= 0; // Cache line 775's valid bit set to 0
            cache_valid[776] <= 0; // Cache line 776's valid bit set to 0
            cache_valid[777] <= 0; // Cache line 777's valid bit set to 0
            cache_valid[778] <= 0; // Cache line 778's valid bit set to 0
            cache_valid[779] <= 0; // Cache line 779's valid bit set to 0
            cache_valid[780] <= 0; // Cache line 780's valid bit set to 0
            cache_valid[781] <= 0; // Cache line 781's valid bit set to 0
            cache_valid[782] <= 0; // Cache line 782's valid bit set to 0
            cache_valid[783] <= 0; // Cache line 783's valid bit set to 0
            cache_valid[784] <= 0; // Cache line 784's valid bit set to 0
            cache_valid[785] <= 0; // Cache line 785's valid bit set to 0
            cache_valid[786] <= 0; // Cache line 786's valid bit set to 0
            cache_valid[787] <= 0; // Cache line 787's valid bit set to 0
            cache_valid[788] <= 0; // Cache line 788's valid bit set to 0
            cache_valid[789] <= 0; // Cache line 789's valid bit set to 0
            cache_valid[790] <= 0; // Cache line 790's valid bit set to 0
            cache_valid[791] <= 0; // Cache line 791's valid bit set to 0
            cache_valid[792] <= 0; // Cache line 792's valid bit set to 0
            cache_valid[793] <= 0; // Cache line 793's valid bit set to 0
            cache_valid[794] <= 0; // Cache line 794's valid bit set to 0
            cache_valid[795] <= 0; // Cache line 795's valid bit set to 0
            cache_valid[796] <= 0; // Cache line 796's valid bit set to 0
            cache_valid[797] <= 0; // Cache line 797's valid bit set to 0
            cache_valid[798] <= 0; // Cache line 798's valid bit set to 0
            cache_valid[799] <= 0; // Cache line 799's valid bit set to 0
            cache_valid[800] <= 0; // Cache line 800's valid bit set to 0
            cache_valid[801] <= 0; // Cache line 801's valid bit set to 0
            cache_valid[802] <= 0; // Cache line 802's valid bit set to 0
            cache_valid[803] <= 0; // Cache line 803's valid bit set to 0
            cache_valid[804] <= 0; // Cache line 804's valid bit set to 0
            cache_valid[805] <= 0; // Cache line 805's valid bit set to 0
            cache_valid[806] <= 0; // Cache line 806's valid bit set to 0
            cache_valid[807] <= 0; // Cache line 807's valid bit set to 0
            cache_valid[808] <= 0; // Cache line 808's valid bit set to 0
            cache_valid[809] <= 0; // Cache line 809's valid bit set to 0
            cache_valid[810] <= 0; // Cache line 810's valid bit set to 0
            cache_valid[811] <= 0; // Cache line 811's valid bit set to 0
            cache_valid[812] <= 0; // Cache line 812's valid bit set to 0
            cache_valid[813] <= 0; // Cache line 813's valid bit set to 0
            cache_valid[814] <= 0; // Cache line 814's valid bit set to 0
            cache_valid[815] <= 0; // Cache line 815's valid bit set to 0
            cache_valid[816] <= 0; // Cache line 816's valid bit set to 0
            cache_valid[817] <= 0; // Cache line 817's valid bit set to 0
            cache_valid[818] <= 0; // Cache line 818's valid bit set to 0
            cache_valid[819] <= 0; // Cache line 819's valid bit set to 0
            cache_valid[820] <= 0; // Cache line 820's valid bit set to 0
            cache_valid[821] <= 0; // Cache line 821's valid bit set to 0
            cache_valid[822] <= 0; // Cache line 822's valid bit set to 0
            cache_valid[823] <= 0; // Cache line 823's valid bit set to 0
            cache_valid[824] <= 0; // Cache line 824's valid bit set to 0
            cache_valid[825] <= 0; // Cache line 825's valid bit set to 0
            cache_valid[826] <= 0; // Cache line 826's valid bit set to 0
            cache_valid[827] <= 0; // Cache line 827's valid bit set to 0
            cache_valid[828] <= 0; // Cache line 828's valid bit set to 0
            cache_valid[829] <= 0; // Cache line 829's valid bit set to 0
            cache_valid[830] <= 0; // Cache line 830's valid bit set to 0
            cache_valid[831] <= 0; // Cache line 831's valid bit set to 0
            cache_valid[832] <= 0; // Cache line 832's valid bit set to 0
            cache_valid[833] <= 0; // Cache line 833's valid bit set to 0
            cache_valid[834] <= 0; // Cache line 834's valid bit set to 0
            cache_valid[835] <= 0; // Cache line 835's valid bit set to 0
            cache_valid[836] <= 0; // Cache line 836's valid bit set to 0
            cache_valid[837] <= 0; // Cache line 837's valid bit set to 0
            cache_valid[838] <= 0; // Cache line 838's valid bit set to 0
            cache_valid[839] <= 0; // Cache line 839's valid bit set to 0
            cache_valid[840] <= 0; // Cache line 840's valid bit set to 0
            cache_valid[841] <= 0; // Cache line 841's valid bit set to 0
            cache_valid[842] <= 0; // Cache line 842's valid bit set to 0
            cache_valid[843] <= 0; // Cache line 843's valid bit set to 0
            cache_valid[844] <= 0; // Cache line 844's valid bit set to 0
            cache_valid[845] <= 0; // Cache line 845's valid bit set to 0
            cache_valid[846] <= 0; // Cache line 846's valid bit set to 0
            cache_valid[847] <= 0; // Cache line 847's valid bit set to 0
            cache_valid[848] <= 0; // Cache line 848's valid bit set to 0
            cache_valid[849] <= 0; // Cache line 849's valid bit set to 0
            cache_valid[850] <= 0; // Cache line 850's valid bit set to 0
            cache_valid[851] <= 0; // Cache line 851's valid bit set to 0
            cache_valid[852] <= 0; // Cache line 852's valid bit set to 0
            cache_valid[853] <= 0; // Cache line 853's valid bit set to 0
            cache_valid[854] <= 0; // Cache line 854's valid bit set to 0
            cache_valid[855] <= 0; // Cache line 855's valid bit set to 0
            cache_valid[856] <= 0; // Cache line 856's valid bit set to 0
            cache_valid[857] <= 0; // Cache line 857's valid bit set to 0
            cache_valid[858] <= 0; // Cache line 858's valid bit set to 0
            cache_valid[859] <= 0; // Cache line 859's valid bit set to 0
            cache_valid[860] <= 0; // Cache line 860's valid bit set to 0
            cache_valid[861] <= 0; // Cache line 861's valid bit set to 0
            cache_valid[862] <= 0; // Cache line 862's valid bit set to 0
            cache_valid[863] <= 0; // Cache line 863's valid bit set to 0
            cache_valid[864] <= 0; // Cache line 864's valid bit set to 0
            cache_valid[865] <= 0; // Cache line 865's valid bit set to 0
            cache_valid[866] <= 0; // Cache line 866's valid bit set to 0
            cache_valid[867] <= 0; // Cache line 867's valid bit set to 0
            cache_valid[868] <= 0; // Cache line 868's valid bit set to 0
            cache_valid[869] <= 0; // Cache line 869's valid bit set to 0
            cache_valid[870] <= 0; // Cache line 870's valid bit set to 0
            cache_valid[871] <= 0; // Cache line 871's valid bit set to 0
            cache_valid[872] <= 0; // Cache line 872's valid bit set to 0
            cache_valid[873] <= 0; // Cache line 873's valid bit set to 0
            cache_valid[874] <= 0; // Cache line 874's valid bit set to 0
            cache_valid[875] <= 0; // Cache line 875's valid bit set to 0
            cache_valid[876] <= 0; // Cache line 876's valid bit set to 0
            cache_valid[877] <= 0; // Cache line 877's valid bit set to 0
            cache_valid[878] <= 0; // Cache line 878's valid bit set to 0
            cache_valid[879] <= 0; // Cache line 879's valid bit set to 0
            cache_valid[880] <= 0; // Cache line 880's valid bit set to 0
            cache_valid[881] <= 0; // Cache line 881's valid bit set to 0
            cache_valid[882] <= 0; // Cache line 882's valid bit set to 0
            cache_valid[883] <= 0; // Cache line 883's valid bit set to 0
            cache_valid[884] <= 0; // Cache line 884's valid bit set to 0
            cache_valid[885] <= 0; // Cache line 885's valid bit set to 0
            cache_valid[886] <= 0; // Cache line 886's valid bit set to 0
            cache_valid[887] <= 0; // Cache line 887's valid bit set to 0
            cache_valid[888] <= 0; // Cache line 888's valid bit set to 0
            cache_valid[889] <= 0; // Cache line 889's valid bit set to 0
            cache_valid[890] <= 0; // Cache line 890's valid bit set to 0
            cache_valid[891] <= 0; // Cache line 891's valid bit set to 0
            cache_valid[892] <= 0; // Cache line 892's valid bit set to 0
            cache_valid[893] <= 0; // Cache line 893's valid bit set to 0
            cache_valid[894] <= 0; // Cache line 894's valid bit set to 0
            cache_valid[895] <= 0; // Cache line 895's valid bit set to 0
            cache_valid[896] <= 0; // Cache line 896's valid bit set to 0
            cache_valid[897] <= 0; // Cache line 897's valid bit set to 0
            cache_valid[898] <= 0; // Cache line 898's valid bit set to 0
            cache_valid[899] <= 0; // Cache line 899's valid bit set to 0
            cache_valid[900] <= 0; // Cache line 900's valid bit set to 0
            cache_valid[901] <= 0; // Cache line 901's valid bit set to 0
            cache_valid[902] <= 0; // Cache line 902's valid bit set to 0
            cache_valid[903] <= 0; // Cache line 903's valid bit set to 0
            cache_valid[904] <= 0; // Cache line 904's valid bit set to 0
            cache_valid[905] <= 0; // Cache line 905's valid bit set to 0
            cache_valid[906] <= 0; // Cache line 906's valid bit set to 0
            cache_valid[907] <= 0; // Cache line 907's valid bit set to 0
            cache_valid[908] <= 0; // Cache line 908's valid bit set to 0
            cache_valid[909] <= 0; // Cache line 909's valid bit set to 0
            cache_valid[910] <= 0; // Cache line 910's valid bit set to 0
            cache_valid[911] <= 0; // Cache line 911's valid bit set to 0
            cache_valid[912] <= 0; // Cache line 912's valid bit set to 0
            cache_valid[913] <= 0; // Cache line 913's valid bit set to 0
            cache_valid[914] <= 0; // Cache line 914's valid bit set to 0
            cache_valid[915] <= 0; // Cache line 915's valid bit set to 0
            cache_valid[916] <= 0; // Cache line 916's valid bit set to 0
            cache_valid[917] <= 0; // Cache line 917's valid bit set to 0
            cache_valid[918] <= 0; // Cache line 918's valid bit set to 0
            cache_valid[919] <= 0; // Cache line 919's valid bit set to 0
            cache_valid[920] <= 0; // Cache line 920's valid bit set to 0
            cache_valid[921] <= 0; // Cache line 921's valid bit set to 0
            cache_valid[922] <= 0; // Cache line 922's valid bit set to 0
            cache_valid[923] <= 0; // Cache line 923's valid bit set to 0
            cache_valid[924] <= 0; // Cache line 924's valid bit set to 0
            cache_valid[925] <= 0; // Cache line 925's valid bit set to 0
            cache_valid[926] <= 0; // Cache line 926's valid bit set to 0
            cache_valid[927] <= 0; // Cache line 927's valid bit set to 0
            cache_valid[928] <= 0; // Cache line 928's valid bit set to 0
            cache_valid[929] <= 0; // Cache line 929's valid bit set to 0
            cache_valid[930] <= 0; // Cache line 930's valid bit set to 0
            cache_valid[931] <= 0; // Cache line 931's valid bit set to 0
            cache_valid[932] <= 0; // Cache line 932's valid bit set to 0
            cache_valid[933] <= 0; // Cache line 933's valid bit set to 0
            cache_valid[934] <= 0; // Cache line 934's valid bit set to 0
            cache_valid[935] <= 0; // Cache line 935's valid bit set to 0
            cache_valid[936] <= 0; // Cache line 936's valid bit set to 0
            cache_valid[937] <= 0; // Cache line 937's valid bit set to 0
            cache_valid[938] <= 0; // Cache line 938's valid bit set to 0
            cache_valid[939] <= 0; // Cache line 939's valid bit set to 0
            cache_valid[940] <= 0; // Cache line 940's valid bit set to 0
            cache_valid[941] <= 0; // Cache line 941's valid bit set to 0
            cache_valid[942] <= 0; // Cache line 942's valid bit set to 0
            cache_valid[943] <= 0; // Cache line 943's valid bit set to 0
            cache_valid[944] <= 0; // Cache line 944's valid bit set to 0
            cache_valid[945] <= 0; // Cache line 945's valid bit set to 0
            cache_valid[946] <= 0; // Cache line 946's valid bit set to 0
            cache_valid[947] <= 0; // Cache line 947's valid bit set to 0
            cache_valid[948] <= 0; // Cache line 948's valid bit set to 0
            cache_valid[949] <= 0; // Cache line 949's valid bit set to 0
            cache_valid[950] <= 0; // Cache line 950's valid bit set to 0
            cache_valid[951] <= 0; // Cache line 951's valid bit set to 0
            cache_valid[952] <= 0; // Cache line 952's valid bit set to 0
            cache_valid[953] <= 0; // Cache line 953's valid bit set to 0
            cache_valid[954] <= 0; // Cache line 954's valid bit set to 0
            cache_valid[955] <= 0; // Cache line 955's valid bit set to 0
            cache_valid[956] <= 0; // Cache line 956's valid bit set to 0
            cache_valid[957] <= 0; // Cache line 957's valid bit set to 0
            cache_valid[958] <= 0; // Cache line 958's valid bit set to 0
            cache_valid[959] <= 0; // Cache line 959's valid bit set to 0
            cache_valid[960] <= 0; // Cache line 960's valid bit set to 0
            cache_valid[961] <= 0; // Cache line 961's valid bit set to 0
            cache_valid[962] <= 0; // Cache line 962's valid bit set to 0
            cache_valid[963] <= 0; // Cache line 963's valid bit set to 0
            cache_valid[964] <= 0; // Cache line 964's valid bit set to 0
            cache_valid[965] <= 0; // Cache line 965's valid bit set to 0
            cache_valid[966] <= 0; // Cache line 966's valid bit set to 0
            cache_valid[967] <= 0; // Cache line 967's valid bit set to 0
            cache_valid[968] <= 0; // Cache line 968's valid bit set to 0
            cache_valid[969] <= 0; // Cache line 969's valid bit set to 0
            cache_valid[970] <= 0; // Cache line 970's valid bit set to 0
            cache_valid[971] <= 0; // Cache line 971's valid bit set to 0
            cache_valid[972] <= 0; // Cache line 972's valid bit set to 0
            cache_valid[973] <= 0; // Cache line 973's valid bit set to 0
            cache_valid[974] <= 0; // Cache line 974's valid bit set to 0
            cache_valid[975] <= 0; // Cache line 975's valid bit set to 0
            cache_valid[976] <= 0; // Cache line 976's valid bit set to 0
            cache_valid[977] <= 0; // Cache line 977's valid bit set to 0
            cache_valid[978] <= 0; // Cache line 978's valid bit set to 0
            cache_valid[979] <= 0; // Cache line 979's valid bit set to 0
            cache_valid[980] <= 0; // Cache line 980's valid bit set to 0
            cache_valid[981] <= 0; // Cache line 981's valid bit set to 0
            cache_valid[982] <= 0; // Cache line 982's valid bit set to 0
            cache_valid[983] <= 0; // Cache line 983's valid bit set to 0
            cache_valid[984] <= 0; // Cache line 984's valid bit set to 0
            cache_valid[985] <= 0; // Cache line 985's valid bit set to 0
            cache_valid[986] <= 0; // Cache line 986's valid bit set to 0
            cache_valid[987] <= 0; // Cache line 987's valid bit set to 0
            cache_valid[988] <= 0; // Cache line 988's valid bit set to 0
            cache_valid[989] <= 0; // Cache line 989's valid bit set to 0
            cache_valid[990] <= 0; // Cache line 990's valid bit set to 0
            cache_valid[991] <= 0; // Cache line 991's valid bit set to 0
            cache_valid[992] <= 0; // Cache line 992's valid bit set to 0
            cache_valid[993] <= 0; // Cache line 993's valid bit set to 0
            cache_valid[994] <= 0; // Cache line 994's valid bit set to 0
            cache_valid[995] <= 0; // Cache line 995's valid bit set to 0
            cache_valid[996] <= 0; // Cache line 996's valid bit set to 0
            cache_valid[997] <= 0; // Cache line 997's valid bit set to 0
            cache_valid[998] <= 0; // Cache line 998's valid bit set to 0
            cache_valid[999] <= 0; // Cache line 999's valid bit set to 0
            cache_valid[1000] <= 0; // Cache line 1000's valid bit set to 0
            cache_valid[1001] <= 0; // Cache line 1001's valid bit set to 0
            cache_valid[1002] <= 0; // Cache line 1002's valid bit set to 0
            cache_valid[1003] <= 0; // Cache line 1003's valid bit set to 0
            cache_valid[1004] <= 0; // Cache line 1004's valid bit set to 0
            cache_valid[1005] <= 0; // Cache line 1005's valid bit set to 0
            cache_valid[1006] <= 0; // Cache line 1006's valid bit set to 0
            cache_valid[1007] <= 0; // Cache line 1007's valid bit set to 0
            cache_valid[1008] <= 0; // Cache line 1008's valid bit set to 0
            cache_valid[1009] <= 0; // Cache line 1009's valid bit set to 0
            cache_valid[1010] <= 0; // Cache line 1010's valid bit set to 0
            cache_valid[1011] <= 0; // Cache line 1011's valid bit set to 0
            cache_valid[1012] <= 0; // Cache line 1012's valid bit set to 0
            cache_valid[1013] <= 0; // Cache line 1013's valid bit set to 0
            cache_valid[1014] <= 0; // Cache line 1014's valid bit set to 0
            cache_valid[1015] <= 0; // Cache line 1015's valid bit set to 0
            cache_valid[1016] <= 0; // Cache line 1016's valid bit set to 0
            cache_valid[1017] <= 0; // Cache line 1017's valid bit set to 0
            cache_valid[1018] <= 0; // Cache line 1018's valid bit set to 0
            cache_valid[1019] <= 0; // Cache line 1019's valid bit set to 0
            cache_valid[1020] <= 0; // Cache line 1020's valid bit set to 0
            cache_valid[1021] <= 0; // Cache line 1021's valid bit set to 0
            cache_valid[1022] <= 0; // Cache line 1022's valid bit set to 0
            cache_valid[1023] <= 0; // Cache line 1023's valid bit set to 0
            // End of unrolled loop
        end
        else begin
            if(read_finish) begin   // 若主存已经把要读的数据传到cache_data_rdata，则把数据写到cache里
                cache_valid[index_save] <= 1'b1;
                cache_dirty[index_save] <= 1'b0;
                cache_tag  [index_save] <= tag_save;
                cache_block[index_save] <= cache_data_rdata;
            end
            else if(cpu_data_req & write & (hit | clean)) begin // 如果cpu要写且直接hit或者是clean的话，直接写入cache即可(store)
                cache_valid[index] <= 1'b1; 
                cache_dirty[index] <= 1'b1;
                cache_tag  [index] <= tag;  
                case (load_store)
                    3'b101: case(cpu_data_addr[1:0]) // sb
                        2'b00: cache_block[index_save][7:0] <= cpu_data_wdata[7:0];
                        2'b01: cache_block[index_save][15:8] <= cpu_data_wdata[7:0];
                        2'b10: cache_block[index_save][23:16] <= cpu_data_wdata[7:0];
                        2'b11: cache_block[index_save][31:24] <= cpu_data_wdata[7:0];
                    endcase
                    3'b110: case(cpu_data_addr[1]) // sh
                        1'b0: cache_block[index_save][15:0] <= cpu_data_wdata[15:0];
                        1'b1: cache_block[index_save][31:16] <= cpu_data_wdata[15:0];
                    endcase
                    3'b111: cache_block[index_save] <= cpu_data_wdata; // sw
                endcase
            end
            else if(write & write_finish) begin     // 如果cpu要写但是没hit，且已经从主存写完到cache了，就将数据写入cache(store)
                cache_valid[index_save] <= 1'b1;
                cache_dirty[index_save] <= 1'b1;
                cache_tag  [index_save] <= tag_save;
                case (load_store)
                    3'b101: case(cpu_data_addr[1:0]) // sb
                        2'b00: cache_block[index_save][7:0] <= cpu_data_wdata[7:0];
                        2'b01: cache_block[index_save][15:8] <= cpu_data_wdata[7:0];
                        2'b10: cache_block[index_save][23:16] <= cpu_data_wdata[7:0];
                        2'b11: cache_block[index_save][31:24] <= cpu_data_wdata[7:0];
                    endcase
                    3'b110: case(cpu_data_addr[1]) // sh
                        1'b0: cache_block[index_save][15:0] <= cpu_data_wdata[15:0];
                        1'b1: cache_block[index_save][31:16] <= cpu_data_wdata[15:0];
                    endcase
                    3'b111: cache_block[index_save] <= cpu_data_wdata; // sw
                endcase
            end
        end
    end
    
endmodule 