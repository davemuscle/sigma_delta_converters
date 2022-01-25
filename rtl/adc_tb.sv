
`timescale 1 ns / 1 ns

// Test bench used for quick ADC smoketest

module adc_tb;
    
    localparam SCLK = 44800;
    localparam BOSR = 256;
    localparam STGS = 2;
    localparam WDTH = 2 + $ceil(STGS * $clog2(BOSR));

    initial begin
        $display("Calculated %-d for ADC calculation width", WDTH);
    end

    //from Tom's site:
    // width = 1 bit pdm + ceil(stages * log2(bosr)) = 1 + ceil(2*10) = 21,
    // which kind of lines up with what I had to do here

    localparam CAP_FUDGE = 128;
    localparam BCLK = SCLK*BOSR;
   
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
    real VCC = 2.5;
    real FREQ = 440;
    real SCALE = 0.99*VCC;
    int sample_num = 0;
    real analog_in;
    real dc_in = 1.25;

    always @(posedge clk) begin
        analog_in = (VCC/2) + (SCALE/2)*$cos(2*3.14*FREQ*sample_num/BCLK); 
        sample_num = sample_num + 1;
    end

    // lvds pin + integrator
    real lvds_pin_p = 0.0;
    real lvds_pin_n = 0.0;
    real increase, decrease;
    bit adc_lvds_pin, adc_fb_pin;
    bit inp_valid = 0;

    initial begin: file_input
        int fdi;
        fdi = $fopen("adc_tb_input.txt", "w");
        forever begin
            @(posedge clk);
            if(inp_valid)
            $fdisplay(fdi, "%f", lvds_pin_p);
        end
        $fclose(fdi);
    end

    always @(posedge clk) begin: pin_gen
        int i;
        //###
        lvds_pin_p <= analog_in;
        //lvds_pin_p <= dc_in;
        inp_valid <= 1;

        //charge on capacitor is proportional to voltage stored
        //taken from Lattice example
        //CAP_FUDGE chosen empirically, in HW this matches the impedance
        increase = (VCC - lvds_pin_n) / CAP_FUDGE;
        decrease = (lvds_pin_n) / CAP_FUDGE;

        //external integrator circuit
        if(adc_fb_pin) begin
            lvds_pin_n <= lvds_pin_n + increase;
        end
        else begin
            lvds_pin_n <= lvds_pin_n - decrease;
        end

        //model lvds pin
        if(lvds_pin_p > lvds_pin_n) begin
            adc_lvds_pin <= 1;
        end
        else begin
            adc_lvds_pin <= 0;
        end
    end

    bit [WDTH-1:0] adc_output;
    bit adc_valid;

    // instantiate adc
    sigma_delta_adc #(
        .BOSR(BOSR),
        .STGS(STGS),
        .WDTH(WDTH)
    ) dut (
        .clk(clk),
        .rst(1'b0),
        .adc_lvds_pin(adc_lvds_pin),
        .adc_fb_pin(adc_fb_pin),
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
            if(t >= (2**WDTH-1))
                adc_output_voltage = 0;
            for(i = 0; i < STGS; i = i + 1) begin
                adc_output_voltage = adc_output_voltage / (BOSR);
            end
        end
    end

    // stim
    initial begin: stim
        int t, fdo;
        $dumpfile("dump.vcd");
        $dumpvars;
        fdo = $fopen("adc_tb_output.txt", "w");
        for(t = 0; t < 256; t = t + 1) begin
            @(posedge adc_valid) begin
                $fdisplay(fdo, "%f", adc_output_voltage);
            end
        end
        $fclose(fdo);
        $finish;
    end


endmodule: adc_tb
