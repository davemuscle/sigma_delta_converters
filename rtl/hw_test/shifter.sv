
module shifter #(
    parameter int DATA_WIDTH,
    parameter int RAM_SIZE
)(
    input bit clk,
    input bit rst,
    input bit up,
    input bit down,
    input bit i_valid,
    input bit [DATA_WIDTH-1:0] i_data,
    output bit o_valid,
    output bit [DATA_WIDTH-1:0] o_data
);

    bit [DATA_WIDTH-1:0] ram_ping [RAM_SIZE-1:0];
    bit [DATA_WIDTH-1:0] ram_pong [RAM_SIZE-1:0];
    localparam ADDR_WIDTH = $clog2(RAM_SIZE);
    bit [ADDR_WIDTH-1:0] ram_wr_addr = 0;
    bit [ADDR_WIDTH-1:0] ram_rd_addr = 0;
    bit [DATA_WIDTH-1:0] ram_ping_data;
    bit [DATA_WIDTH-1:0] ram_pong_data;
    const bit [ADDR_WIDTH-1:0] ram_cmp = -1;
    bit ram_select = 0;
    bit ram_select_dly = 0;
    bit tgl = 0;

    always_comb begin
        o_data = ram_select_dly ? ram_ping_data : ram_pong_data;
    end

    always_ff @(posedge clk) begin
        o_valid <= 0;
        ram_ping_data <= ram_ping[ram_rd_addr];
        ram_pong_data <= ram_pong[ram_rd_addr];
        ram_select_dly <= ram_select;
        if(i_valid) begin
            //read ram
            o_valid <= 1;
            
            //add effect
            if(up & !down) begin
                ram_rd_addr <= ram_rd_addr + 2;
            end
            else if(!up & down) begin
                tgl <= ~tgl;
                if(tgl) begin
                    ram_rd_addr <= ram_rd_addr - 1;
                end
            end
            else begin
                ram_rd_addr <= ram_rd_addr + 1;
            end
            
            //write ram
            if(ram_select == 0) begin
                ram_ping[ram_wr_addr] <= i_data;
            end
            else begin
                ram_pong[ram_wr_addr] <= i_data;
            end
            ram_wr_addr <= ram_wr_addr + 1;
            if(ram_wr_addr == ram_cmp) begin
                ram_select  <= ~ram_select;
                ram_rd_addr <= 0;
            end
        end
    end

endmodule: shifter
