// DaveMuscle

// Test bench for DAC

`timescale 1 ns / 1 ns

module sigma_delta_dac_tb #(
    //dut params
    parameter int    DAC_BITLEN         = 24,
    //tb params
    parameter int    DUMP_VCD    = 1,
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
    localparam CLK_NS = 10**9 / (BCLK * 2);
    bit clk;
    initial begin
        forever begin
            #(CLK_NS) clk <= 0;
            #(CLK_NS) clk <= 1;
        end
    end

    //generate sine wave
    localparam HOLD_RATE = 16;
    localparam int NUM_SAMPLES = NUM_CYCLES * (BCLK / FREQUENCY);
    localparam int SIG_BITLEN = DAC_BITLEN;
    localparam int HALF_OFFSET = (2**SIG_BITLEN) >> 1;
    localparam int HALF_SCALE = ((2**SIG_BITLEN) >> 1)-1;
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
            repeat(HOLD_RATE) @(posedge clk);
            dac_input = (HALF_SCALE*$cos(2.0*3.14*FREQUENCY*sample_in/(BCLK/HOLD_RATE))) + HALF_OFFSET;
            //dac_input &= ~(DAC_BITLEN'(OVERSAMPLE_RATE-1));
            //dac_input = HALF_OFFSET;
            sample_in = sample_in + 1;
            $fdisplay(fd, "%f", dac_input);
        end
        $fclose(fd);
    end

    // instantiate dac
    sigma_delta_dac #(
        .DAC_BITLEN(DAC_BITLEN)
    ) dut (
        .clk(clk),
        .rst(rst),
        .dac_input(dac_input),
        .dac_valid(1'b1),
        .dac_pin(dac_pin)
    );

    int bit_cnt = 0;
    real avg = 0;
    real this_avg = 0;
    real dac_output_voltage;

    real pre_filt_voltage = 0;
    localparam NUM_TAPS = 15;
    real taps [NUM_TAPS-1:0] = {
        0 :  0.05139720458207956,
        1 :  0.05981745638277061,
        2 :  -0.05440752590226353,
        3 :  0.022828641134352314,
        4 :  0.05109801416807096,
        5 :  -0.15226264364226097,
        6 :  0.24083576622966885,
        7 :  0.7239733376975287,
        8 :  0.24083576622966885,
        9 :  -0.15226264364226097,
        10:  0.05109801416807096,
        11:  0.022828641134352314,
        12:  -0.05440752590226353,
        13:  0.05981745638277061,
        14:  0.05139720458207956
    };
    real shifts [ NUM_TAPS-1:0] = '{default:0};
    

    // file output for visual inspection
    initial begin: file_output
        int fd;
        int i;
        real samples_out;
        samples_out = 0;
        wait(rst == 0);
        fd = $fopen(OUTPUT_FILE, "w");
        repeat(50) @(posedge clk);
        while(sim_done == 0) begin
            @(posedge clk) begin
                dac_output_voltage = 0;
                for(i = 0; i < NUM_TAPS-1; i = i + 1) begin
                    dac_output_voltage = dac_output_voltage + (taps[i]*shifts[i]);
                end
                shifts[0]= VCC*dac_pin;
                for(i = 0; i < NUM_TAPS-1; i = i + 1) begin
                    shifts[NUM_TAPS-1-i] = shifts[NUM_TAPS-2-i];
                end
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
