
`timescale 1 ns / 1 ns

// Test bench used for quick ADC smoketest

module sigma_delta_adc_tb;
    
    localparam SCLK = 44800;
    localparam BOSR = 256;
    localparam STGS = 2;
    //from Tom's site:
    // width = 1 bit pdm + ceil(stages * log2(bosr)) = 1 + ceil(2*10) = 21,
    // which kind of lines up with what I had to do here
    localparam WDTH = 2 + $ceil(STGS * $clog2(BOSR));
    localparam VCC = 2.5;
    localparam CAP_FUDGE = 128;
    localparam BCLK = SCLK*BOSR;
    localparam FREQ = 440;
    localparam SCALE = 0.99*VCC;
    localparam NUM_OUTPUT_SAMPLES = 256;

    initial begin
        $display("Calculated %-d for ADC calculation width", WDTH);
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
        fdi = $fopen("./tb_dumps/modelsim_adc_tb_input.txt", "w");
        forever begin
            @(posedge clk);
            if(sample_num > 0)
                $fdisplay(fdi, "%f", analog_in);
        end
        $fclose(fdi);
    end

    bit [WDTH-1:0] adc_output;
    bit adc_valid;

    // instantiate adc
    sigma_delta_adc_harness #(
        .VCC(VCC),
        .CAP_FUDGE(CAP_FUDGE),
        .BOSR(BOSR),
        .STGS(STGS),
        .WDTH(WDTH)
    ) dut (
        .clk(clk),
        .rst(1'b0),
        .adc_input(analog_in),
        .adc_output(adc_output),
        .adc_valid(adc_valid)
    );

    real adc_output_voltage = 0.0;

    always @(posedge clk) begin: out_convert
        int i;
        real t;
        real f [51:0];
        if(adc_valid) begin
            t = real'(adc_output); 
            adc_output_voltage = VCC * t;
            adc_output_voltage = t;
            //if(t >= (2**WDTH-1))
            //    adc_output_voltage = 0;
            //for(i = 0; i < STGS; i = i + 1) begin
            //    adc_output_voltage = adc_output_voltage / (BOSR);
            //end
        end
    end

    // stim
    initial begin: stim
        int t, fdo;
        $dumpfile("dump.vcd");
        $dumpvars;
        fdo = $fopen("./tb_dumps/modelsim_adc_tb_output.txt", "w");
        for(t = 0; t < NUM_OUTPUT_SAMPLES; t = t + 1) begin
            @(posedge adc_valid) begin
                $fdisplay(fdo, "%f", adc_output_voltage);
            end
        end
        $fclose(fdo);
        $finish;
    end


endmodule: sigma_delta_adc_tb
