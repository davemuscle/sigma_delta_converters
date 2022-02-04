
`timescale 1 ns / 1 ns

// Test bench used for quick ADC smoketest

module sigma_delta_adc_tb;
    
    localparam SCLK = 44800;
    localparam OVERSAMPLE_RATE = 256;
    localparam CIC_STAGES = 2;
    //from Tom's site:
    // width = 1 bit pdm + ceil(stages * log2(bosr)) = 1 + ceil(2*10) = 21,
    // which kind of lines up with what I had to do here
    localparam ADC_BITLEN = 24;
    //localparam ADC_BITLEN = 2 + $ceil(CIC_STAGES * $clog2(OVERSAMPLE_RATE));
    localparam SIGNED_OUTPUT = 1;
    localparam DC_BLOCK_SHIFT = 10;

    localparam VCC = 2.5;
    localparam CAP_FUDGE = 128;
    localparam BCLK = SCLK*OVERSAMPLE_RATE;
    localparam FREQ = 440;
    localparam SCALE = 0.99*VCC;
    localparam NUM_OUTPUT_SAMPLES = 256;

    initial begin
        $display("Calculated %-d for ADC calculation width", ADC_BITLEN);
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
    
    real adc_output;
    bit adc_valid;

    // analog input generator
    int sample_num = 0;
    real analog_in;
    real dc_in = VCC/2;

    always @(posedge clk) begin
        analog_in = dc_in + (SCALE/2)*$cos(2*3.14*FREQ*sample_num/BCLK); 
        sample_num = sample_num + 1;
    end

    initial begin: file_input
        int fdi;
        int t;
        fdi = $fopen("./tb_dumps/modelsim_adc_tb_input.txt", "w");
        $fdisplay(fdi, "index,voltage (V)");
        forever begin
            @(posedge clk);
            if(adc_valid) begin
                $fdisplay(fdi, "%0.f,%f", t, analog_in);
                t = t + 1;
            end
        end
        $fclose(fdi);
    end


    // instantiate adc
    sigma_delta_adc_harness #(
        .VCC(VCC),
        .CAP_FUDGE(CAP_FUDGE),
        .OVERSAMPLE_RATE(OVERSAMPLE_RATE),
        .CIC_STAGES(CIC_STAGES),
        .ADC_BITLEN(ADC_BITLEN),
        .SIGNED_OUTPUT(SIGNED_OUTPUT),
        .DC_BLOCK_SHIFT(DC_BLOCK_SHIFT)
    ) dut (
        .clk(clk),
        .rst(1'b0),
        .adc_input(analog_in),
        .adc_output(adc_output),
        .adc_valid(adc_valid)
    );

    // stim
    initial begin: stim
        int i, t, fdou, fdos;
        real adc_output_voltage;
        $dumpfile("dump.vcd");
        $dumpvars;
        fdou = $fopen("./tb_dumps/modelsim_adc_tb_output.txt", "w");
        $fdisplay(fdou, "index,decimal out");
        for(t = 0; t < NUM_OUTPUT_SAMPLES; t = t + 1) begin
            adc_output_voltage = real'(adc_output);
            for(i = 0; i < CIC_STAGES; i = i + 1) begin
                adc_output_voltage = adc_output_voltage / real'(OVERSAMPLE_RATE);
            end
            @(posedge adc_valid) begin
                $fdisplay(fdou, "%0.f,%f", t, adc_output_voltage);
            end
        end
        $fclose(fdou);
        $fclose(fdos);
        $finish;
    end


endmodule: sigma_delta_adc_tb
