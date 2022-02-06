// DaveMuscle

// Test bench for ADC

`timescale 1 ns / 1 ns

module sigma_delta_adc_tb #(
    //dut params
    parameter int OVERSAMPLE_RATE = 256,
    parameter int CIC_STAGES      = 2,
    parameter int ADC_BITLEN      = 24,
    parameter int SIGNED_OUTPUT   = 1,
    parameter int DC_BLOCK_SHIFT  = 10,
    //tb params
    parameter int    DUMP_VCD    = 0,
    parameter int    BCLK        = 12880000,
    parameter real   VCC         = 2.5,
    parameter string INPUT_FILE  = "test_input.txt",  //expected raw floats representing voltage
    parameter string OUTPUT_FILE = "test_output.txt" //same as above
);
    
    // print parameters
    initial begin
        $display("* Param: OVERSAMPLE_RATE=%-d", OVERSAMPLE_RATE);
        $display("* Param: CIC_STAGES=%-d", CIC_STAGES);
        $display("* Param: ADC_BITLEN=%-d", ADC_BITLEN);
        $display("* Param: DC_BLOCK_SHIFT=%-d", DC_BLOCK_SHIFT);
        $display("* Param: SIGNED_OUTPUT=%-d", SIGNED_OUTPUT);
        $display("* Param: VCC=%f", VCC);
        $display("* Param: BCLK=%-d", BCLK);
        $display("* Param: INPUT_FILE=%s", INPUT_FILE);
        $display("* Param: OUTPUT_FILE=%s", OUTPUT_FILE);
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
   
    // read input from text file
    bit finish_later = 0;
    real adc_input;
    bit rst = 1;

    initial begin: file_input
        int fd;
        string line;
        fd = $fopen(INPUT_FILE, "r");
        if(fd) begin
            rst = 0;
            while(!$feof(fd)) begin
                @(posedge clk);
                void'($fgets(line, fd));
                //convert to float
                adc_input = line.atoreal();
            end
        end
        else begin
            $error("Could not open input file: %s", INPUT_FILE);
        end
        $fclose(fd);
        finish_later = 1;
    end

    localparam CAP_FUDGE = 128;

    // lvds pin + integrator
    real lvds_pin_p = 0.0;
    real lvds_pin_n = 0.0;
    real increase, decrease;
    bit adc_lvds_pin, adc_fb_pin;

    always_comb begin
        //charge on capacitor is proportional to voltage stored
        //taken from Lattice example
        //CAP_FUDGE chosen empirically, in HW this matches the capacitance
        increase = (VCC - lvds_pin_n) / CAP_FUDGE;
        decrease = (lvds_pin_n) / CAP_FUDGE;
    end

    always_ff @(posedge clk) begin
        lvds_pin_p <= adc_input;

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

    bit [ADC_BITLEN-1:0] adc_output;
    bit adc_valid;

    // instantiate adc
    sigma_delta_adc #(
        .OVERSAMPLE_RATE(OVERSAMPLE_RATE),
        .CIC_STAGES(CIC_STAGES),
        .ADC_BITLEN(ADC_BITLEN),
        .SIGNED_OUTPUT(SIGNED_OUTPUT),
        .DC_BLOCK_SHIFT(DC_BLOCK_SHIFT)
    ) dut (
        .clk(clk),
        .rst(rst),
        .adc_lvds_pin(adc_lvds_pin),
        .adc_fb_pin(adc_fb_pin),
        .adc_output(adc_output),
        .adc_valid(adc_valid)
    );

    // file output stimulus
    initial begin: file_output
        int fd;
        int i;
        real adc_output_voltage;
        wait(rst == 0);
        fd = $fopen(OUTPUT_FILE, "w");
        forever begin
            @(posedge adc_valid) begin
                if(SIGNED_OUTPUT) begin
                    adc_output_voltage = real'(signed'(adc_output)) * real'(VCC);
                end
                else begin
                    adc_output_voltage = real'(unsigned'(adc_output)) * real'(VCC);
                end
                for(i = 0; i < CIC_STAGES; i = i + 1) begin
                    adc_output_voltage = adc_output_voltage / real'(OVERSAMPLE_RATE);
                end
                $fdisplay(fd, "%f", adc_output_voltage);
            end
        end
        $fclose(fd);
    end
    
    localparam FINISH_CLOCKS = OVERSAMPLE_RATE; //how many clocks to run after the end of the input file

    //testbench start/stop
    initial begin
        if(DUMP_VCD) begin
            $dumpfile("dump.vcd");
            $dumpvars;
        end
        wait(finish_later);
        repeat(FINISH_CLOCKS) @(posedge clk);
        $finish;
    end

endmodule: sigma_delta_adc_tb
