// DaveMuscle

// Test bench for DAC

`timescale 1 ns / 1 ns

module sigma_delta_dac_tb #(
    //dut params
    parameter int OVERSAMPLE_RATE    = 256,
    parameter int CIC_STAGES         = 2,
    parameter int DAC_BITLEN         = 24,
    parameter bit USE_FIR_COMP       = 1,
    parameter int FIR_COMP_ALPHA_8   = 2,
    //tb params
    parameter int    DUMP_VCD    = 0,
    parameter int    BCLK        = 12880000,
    parameter int    NUM_CYCLES  = 10,
    parameter real   VCC         = 2.5,
    parameter real   FREQUENCY   = 440.0,
    parameter real   AMPLITUDE   = 1.0,
    parameter real   OFFSET      = 1.25,
    parameter string INPUT_FILE  = "test_input.txt",  //expected raw floats representing voltage
    parameter string OUTPUT_FILE = "test_output.txt" //same as above
);

    bit sim_done = 0;
    bit [DAC_BITLEN-1:0] dac_input;
    bit dac_ready;
    bit dac_pin;

    //testbench vcd dump and finish
    initial begin
        if(DUMP_VCD) begin
            $dumpfile("dump.vcd");
            $dumpvars;
        end
        wait(sim_done == 1);
        $finish;
    end

    // clock generator 
    localparam SCLK = BCLK/OVERSAMPLE_RATE;
    localparam CLK_NS = 10**9 / (BCLK * 2);
    bit clk;
    initial begin
        forever begin
            #(CLK_NS) clk <= 0;
            #(CLK_NS) clk <= 1;
        end
    end

    //generate sine wave
    localparam int NUM_SAMPLES = NUM_CYCLES * (BCLK / FREQUENCY);
    localparam int HALF_OFFSET = (2**DAC_BITLEN) >> 1;
    localparam int HALF_SCALE = ((2**DAC_BITLEN-1) >> 1)-1;
    bit rst = 1;
    bit enable_output = 0;

    initial begin
        int fd;
        int sample_in;
        sample_in = 0;
        //reset and dc startup
        repeat(5) @(posedge clk);
        rst <= 0;
        enable_output <= 1;
        fd = $fopen(INPUT_FILE, "w");
        //generate
        while(sample_in < NUM_SAMPLES) begin
            @(posedge clk);
            if(dac_ready) begin
                dac_input = (HALF_SCALE*$cos(2.0*3.14*FREQUENCY*sample_in/(BCLK/OVERSAMPLE_RATE))) + HALF_OFFSET;
                //dac_input = HALF_OFFSET;
                sample_in = sample_in + 1;
                $fdisplay(fd, "%f", dac_input);
            end
        end
        $fclose(fd);
    end

    // instantiate dac
    sigma_delta_dac #(
        .OVERSAMPLE_RATE(OVERSAMPLE_RATE),
        .CIC_STAGES(CIC_STAGES),
        .DAC_BITLEN(DAC_BITLEN),
        .USE_FIR_COMP(USE_FIR_COMP),
        .FIR_COMP_ALPHA_8(FIR_COMP_ALPHA_8)
    ) dut (
        .clk(clk),
        .rst(rst),
        .dac_input(dac_input),
        .dac_ready(dac_ready),
        .dac_pin(dac_pin)
    );

    int bit_cnt = 0;
    real avg = 0;
    real this_avg = 0;
    real dac_output_voltage;

    // file output for visual inspection
    initial begin: file_output
        int fd;
        int i;
        real samples_out;
        samples_out = 0;
        wait(rst == 0);
        fd = $fopen(OUTPUT_FILE, "w");
        repeat(50) wait(dac_ready);
        while(sim_done == 0) begin
            @(posedge clk) begin
                dac_output_voltage = 0;
                avg = avg + dac_pin;
                if(bit_cnt == 2*OVERSAMPLE_RATE-1) begin
                    bit_cnt <= 0;
                    this_avg = avg; 
                    avg = 0;
                end
                else begin
                    bit_cnt <= bit_cnt + 1;
                end
                dac_output_voltage = VCC*this_avg / real'(2*OVERSAMPLE_RATE);
                if(enable_output) begin
                    samples_out = samples_out + 1;
                    //write output into file
                    $fdisplay(fd, "%f", dac_output_voltage);
                    if(samples_out == int'(NUM_SAMPLES)) begin
                        sim_done = 1;
                    end
                end
            end
        end
        $fclose(fd);
    end

endmodule: sigma_delta_dac_tb
