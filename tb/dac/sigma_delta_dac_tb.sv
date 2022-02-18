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
            repeat(HOLD_RATE-1) @(posedge clk);
            dac_input <= (HALF_SCALE*$cos(2.0*3.14*FREQUENCY*sample_in/(BCLK/HOLD_RATE))) + HALF_OFFSET;
            sample_in = sample_in + 1;
            $fdisplay(fd, "%f", dac_input);
            @(posedge clk);
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
        .dac_pin(dac_pin)
    );

    real dac_output_voltage;

    localparam NUM_TAPS = 53;
    real shifts [ NUM_TAPS-1:0] = '{default:0};
    real taps [NUM_TAPS-1:0] = {
        0  : -0.0003787956096559532,
        1  : -0.0006502713115530898,
        2  : -0.0011411470819661525,
        3  : -0.001798691970786232,
        4  : -0.002613567260764689,
        5  : -0.0035482165032426523,
        6  : -0.004532185454722294,
        7  : -0.005459709768864222,
        8  : -0.006190800400573852,
        9  : -0.006556736831012499,
        10 : -0.006369922865185568,
        11 : -0.005438445435277057,
        12 : -0.0035837053451363643,
        13 : -0.0006593165738201801,
        14 : 0.0034296083914184283,
        15 : 0.008708889313889159,
        16 : 0.015122507781640052,
        17 : 0.022525967925374306,
        18 : 0.03068638959995707,
        19 : 0.03929097634296657,
        20 : 0.047963927059195964,
        21 : 0.05628963664090415,
        22 : 0.06384076887313744,
        23 : 0.07021019541485123,
        24 : 0.0750419347501615,
        25 : 0.07805820093423071,
        26 : 0.07908399097168786,
        27 : 0.07805820093423071,
        28 : 0.0750419347501615,
        29 : 0.07021019541485123,
        30 : 0.06384076887313744,
        31 : 0.05628963664090415,
        32 : 0.047963927059195964,
        33 : 0.03929097634296657,
        34 : 0.03068638959995707,
        35 : 0.022525967925374306,
        36 : 0.015122507781640052,
        37 : 0.008708889313889159,
        38 : 0.0034296083914184283,
        39 : -0.0006593165738201801,
        40 : -0.0035837053451363643,
        41 : -0.005438445435277057,
        42 : -0.006369922865185568,
        43 : -0.006556736831012499,
        44 : -0.006190800400573852,
        45 : -0.005459709768864222,
        46 : -0.004532185454722294,
        47 : -0.0035482165032426523,
        48 : -0.002613567260764689,
        49 : -0.001798691970786232,
        50 : -0.0011411470819661525,
        51 : -0.0006502713115530898,
        52 : -0.0003787956096559532
        };

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
