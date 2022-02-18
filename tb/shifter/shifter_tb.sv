// DaveMuscle

`timescale 1 ns / 1 ns

module shifter_tb;

    bit sim_done = 0;
    initial begin
        $dumpfile("dump.vcd");
        $dumpvars;
        wait(sim_done == 1);
        $finish;
    end

    localparam BCLK = 10000000;
    localparam CLK_NS = 100/2;
    
    bit clk;
    bit rst = 1;
    
    initial begin
        forever begin
            #(CLK_NS) clk <= 0;
            #(CLK_NS) clk <= 1;
        end
    end
    
    localparam int NUM_CYCLES = 20;
    localparam real FREQUENCY = 8800;
    localparam int NUM_SAMPLES = NUM_CYCLES * (BCLK / FREQUENCY);

    localparam DATA_WIDTH = 16;
    bit i_valid = 0;
    bit [DATA_WIDTH-1:0] i_data;
    bit o_valid = 0;
    bit [DATA_WIDTH-1:0] o_data;

    real i_data_f, o_data_f;

    always_comb begin
        i_data_f = real'(signed'(i_data));
        o_data_f = real'(signed'(o_data));
    end

    //generate input stimulus
    initial begin
        int sample_in;
        sample_in = 0;
        //proc reset
        repeat(5) @(posedge clk);
        rst <= 0;
        repeat(5) @(posedge clk);
        while(sample_in < NUM_SAMPLES) begin
            //generate wave
            i_data = (2**(DATA_WIDTH-2)-1)*$cos(2.0*3.14*FREQUENCY*sample_in/BCLK);
            i_valid <= 1;
            sample_in = sample_in + 1;
            @(posedge clk);
            i_valid <= 0;
            repeat(15) @(posedge clk);
        end
        sim_done = 1;
    end

    shifter #(
        .DATA_WIDTH(DATA_WIDTH),
        .RAM_SIZE(4096)
    ) dut (
        .clk(clk),
        .rst(rst),
        .up(1'b1),
        .down(1'b0),
        .i_valid(i_valid),
        .i_data(i_data),
        .o_valid(o_valid),
        .o_data(o_data)
    );

endmodule: shifter_tb
