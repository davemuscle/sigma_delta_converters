
`timescale 1 ns / 1 ns

module adc_tb;
    
    localparam SCLK = 44800;
    localparam BOSR = 256;
    localparam WDTH = 16;
    localparam CAP_FUDGE = 128;
    localparam BCLK = SCLK*BOSR;
    localparam CIC_STAGES = 2;
    localparam BOX_AVG = 8;
   
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
    real SCALE = 0.9*VCC;
    int sample_num = 0;
    real analog_in;
    real dc_in = 1.25;

    always @(posedge clk) begin
        analog_in = (SCALE/2) + (SCALE/4)*$cos(2*3.14*FREQ*sample_num/BCLK); 
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
        fdi = $fopen("adc_input.txt", "w");
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
        increase = (VCC - lvds_pin_n) / CAP_FUDGE;
        decrease = (lvds_pin_n) / CAP_FUDGE;

        if(adc_fb_pin) begin
            lvds_pin_n <= lvds_pin_n + increase;
        end
        else begin
            lvds_pin_n <= lvds_pin_n - decrease;
        end

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
        .WDTH(WDTH),
        .BOX_AVG(BOX_AVG),
        .CIC_STAGES(CIC_STAGES)
    ) dut (
        .clk(clk),
        .adc_lvds_pin(adc_lvds_pin),
        .adc_fb_pin(adc_fb_pin),
        .adc_output(adc_output),
        .adc_valid(adc_valid)
    );

    real filter_taps [51:0];
    initial begin
        filter_taps[1 ]= 0.00016955983346700256;
        filter_taps[2 ]= -0.00017386325569869785;
        filter_taps[3 ]= 4.05474073915333e-05;
        filter_taps[4 ]= 0.00029732773409100295;
        filter_taps[5 ]= -0.0008803482040328832;
        filter_taps[6 ]= 0.0016970681376454234;
        filter_taps[7 ]= -0.00266175916874267;
        filter_taps[8 ]= 0.0036024089898627214;
        filter_taps[9 ]= -0.004265243426297466;
        filter_taps[10]= 0.004339902475205507;
        filter_taps[11]= -0.003505859064189463;
        filter_taps[12]= 0.0014962952786092842;
        filter_taps[13]= 0.0018286977008164001;
        filter_taps[14]= -0.006411050880365359;
        filter_taps[15]= 0.011938572488160066;
        filter_taps[16]= -0.017815140865602513;
        filter_taps[17]= 0.023164138496725807;
        filter_taps[18]= -0.02686417826675521;
        filter_taps[19]= 0.02760442372838124;
        filter_taps[20]= -0.023928532674029855;
        filter_taps[21]= 0.014201204731615569;
        filter_taps[22]= 0.0036593765326553124;
        filter_taps[23]= -0.03315161312326534;
        filter_taps[24]= 0.08276148228255578;
        filter_taps[25]= -0.18406111072537024;
        filter_taps[26]= 0.626917693837167;
        filter_taps[27]= 0.626917693837167;
        filter_taps[28]= -0.18406111072537024;
        filter_taps[29]= 0.08276148228255578;
        filter_taps[30]= -0.03315161312326534;
        filter_taps[31]= 0.0036593765326553124;
        filter_taps[32]= 0.014201204731615569;
        filter_taps[33]= -0.023928532674029855;
        filter_taps[34]= 0.02760442372838124;
        filter_taps[35]= -0.02686417826675521;
        filter_taps[36]= 0.023164138496725807;
        filter_taps[37]= -0.017815140865602513;
        filter_taps[38]= 0.011938572488160066;
        filter_taps[39]= -0.006411050880365359;
        filter_taps[40]= 0.0018286977008164001;
        filter_taps[41]= 0.0014962952786092842;
        filter_taps[42]= -0.003505859064189463;
        filter_taps[43]= 0.004339902475205507;
        filter_taps[44]= -0.004265243426297466;
        filter_taps[45]= 0.0036024089898627214;
        filter_taps[46]= -0.00266175916874267;
        filter_taps[47]= 0.0016970681376454234;
        filter_taps[48]= -0.0008803482040328832;
        filter_taps[49]= 0.00029732773409100295;
        filter_taps[50]= -0.00017386325569869785;
        filter_taps[51]= 0.00016955983346700256;
    end

    real adc_output_voltage = 0.0;
    always @(posedge clk) begin: out_convert
        int i;
        real t;
        real f [51:0];
        if(adc_valid) begin
            //for(i = 1; i < 52; i = i + 1) begin
            //    f[i] = f[i-1];
            //end
            //f[0] = real'(adc_output);
            //t = 0;
            //for(i = 0; i < 52; i = i + 1) begin
            //    t = t + (filter_taps[i] * f[i]);
            //end
            //for(i = 0; i < CIC_STAGES; i = i + 1) begin
            //    t = t / (BOSR);
            //end
            t = real'(adc_output); 
            //adc_output_voltage = VCC * t / BOSR;
            if(CIC_STAGES > 0) begin
                adc_output_voltage = VCC * t;
                for(i = 0; i < CIC_STAGES; i = i + 1) begin
                    adc_output_voltage = adc_output_voltage / (BOSR);
                end
            end
            else begin
                adc_output_voltage = VCC * t/ BOSR;
            end
            
        end
    end



    // stim
    initial begin: stim
        int t, fdo;
        $dumpfile("dump.vcd");
        $dumpvars;
        fdo = $fopen("adc_output.txt", "w");
        for(t = 0; t < 256; t = t + 1) begin
            @(posedge adc_valid) begin
                $fdisplay(fdo, "%f", adc_output_voltage);
            end
        end
        $fclose(fdo);
        $finish;
    end


endmodule: adc_tb
