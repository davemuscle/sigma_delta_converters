// Dave Muscle

module sigma_delta_adc_harness #(
    parameter VCC  = 2.5,
    parameter CAP_FUDGE = 128,
    parameter OVERSAMPLE_RATE = 256,
    parameter CIC_STAGES = 2,
    parameter ADC_BITLEN = 2,
    parameter SIGNED_OUTPUT = 1,
    parameter DC_BLOCK_SHIFT = 7
)(
    input bit clk,
    input bit rst,
    input real adc_input,
    output real adc_output,
    output bit adc_valid

);

    // lvds pin + integrator
    real lvds_pin_p = 0.0;
    real lvds_pin_n = 0.0;
    real increase, decrease;
    bit adc_lvds_pin, adc_fb_pin;


    always_comb begin
        //charge on capacitor is proportional to voltage stored
        //taken from Lattice example
        //CAP_FUDGE chosen empirically, in HW this matches the impedance
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

    bit [ADC_BITLEN-1:0] adc_b_output;

    always_comb begin
        if(SIGNED_OUTPUT == 1) begin
            adc_output = real'(signed'(adc_b_output));
        end
        else begin
            adc_output = real'(unsigned'(adc_b_output));
        end
    end

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
        .adc_output(adc_b_output),
        .adc_valid(adc_valid)
    );

endmodule: sigma_delta_adc_harness
