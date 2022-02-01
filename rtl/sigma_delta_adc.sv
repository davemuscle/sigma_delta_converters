// Dave Muscle

// Sigma Delta ADC in FPGA

module sigma_delta_adc #(
    parameter int OVERSAMPLE_RATE = 256,
    parameter int CIC_STAGES = 2,
    parameter int ADC_BITLEN = 16,
    parameter int SIGNED_OUTPUT = 1,
    parameter int DC_BLOCK_SHIFT = 7
)(
    input bit clk,
    input bit rst, //reset for optional power saving

    input bit adc_lvds_pin, // connect to analog input
    output bit adc_fb_pin,  // connect to integrator

    output bit [ADC_BITLEN-1:0] adc_output, //digital output
    output bit adc_valid              //signals valid output

);

    bit adc_in;

    //sample analog input connected to lvds positive
    always_ff @(posedge clk) begin: front_end
        adc_in <= adc_lvds_pin;
        if(rst) begin
            adc_in <= 0;
        end
    end

    //feedback output connected to lvds negative
    always_comb begin
        adc_fb_pin = adc_in;
    end
   
    //comb/integrator signals
    bit [ADC_BITLEN-1:0] cic_int [CIC_STAGES-1:0] = '{default:0};
    bit [ADC_BITLEN-1:0] cic_dec [CIC_STAGES-1:0] = '{default:0};
    bit [ADC_BITLEN-1:0] cic_dly [CIC_STAGES-1:0] = '{default:0};
    bit [ADC_BITLEN-1:0] cic_out = 0;
    bit cic_vld = 0;
    //decimator signals
    localparam CNT_ADC_BITLEN = $clog2(OVERSAMPLE_RATE);
    bit [CNT_ADC_BITLEN-1:0] dec_cnt = 0;
    const bit [CNT_ADC_BITLEN-1:0] dec_cmp = CNT_ADC_BITLEN'(OVERSAMPLE_RATE-1);
    bit dec_ena = 0;

    //CIC Filter for OVERSAMPLE_RATE decimation
    always_ff @(posedge clk) begin: cic_filter
        int i;

        //Integrator Filters
        for(i = 0; i < CIC_STAGES; i = i +1) begin
            if(i == 0) begin
                cic_int[i] <= cic_int[i] + ADC_BITLEN'(adc_in);
            end
            else begin
                cic_int[i] <= cic_int[i] + cic_int[i-1];
            end
        end

        //Time-gate decimators via enable signal
        dec_cnt <= dec_cnt + CNT_ADC_BITLEN'(1);
        if(dec_cnt == dec_cmp) begin
            dec_ena <= 1;
        end
        else begin
            dec_ena <= 0;
        end

        //Comb Filters
        if(dec_ena) begin
            for(i = 0; i < CIC_STAGES; i = i + 1) begin
                if(i == 0) begin
                    cic_dec[i] <= cic_dly[i] - cic_int[CIC_STAGES-1];
                    cic_dly[i] <= cic_int[CIC_STAGES-1];
                end
                else begin
                    cic_dec[i] <= cic_dly[i] - cic_dec[i-1];
                    cic_dly[i] <= cic_dec[i-1];
                end
            end
        end
        cic_out <= cic_dec[CIC_STAGES-1];
        cic_vld <= dec_ena;

        //reset
        if(rst) begin
            cic_int <= '{default:0};
            dec_cnt <= 0;
            dec_ena <= 0;
            cic_dec <= '{default:0};
            cic_dly <= '{default:0};
            cic_out <= 0;
            cic_vld <= 0;
        end

    end

    //DC Removal / Assign Output
    bit signed [ADC_BITLEN-1:0] dc_yn = 0; 
    bit signed [ADC_BITLEN-1:0] dc_yn_reg = 0;
    bit dc_vld;

    always_ff @(posedge clk) begin
        if(SIGNED_OUTPUT == 1) begin
            // choose lower values of alpha (lower shift)
            // this will avoid attenuation of lower freqs
            adc_valid <= 0;
            if(cic_vld) begin
                dc_yn <= cic_out - dc_yn_reg;
                dc_vld <= cic_vld;
                dc_yn_reg <= (dc_yn >>> DC_BLOCK_SHIFT) + dc_yn_reg;
                adc_output <= dc_yn;
                adc_valid <= 1;
            end
            if(rst) begin
                dc_vld <= 0;
                dc_yn <= 0;
                dc_yn_reg <= 0;
            end
        end
        else begin
            adc_output <= cic_out;
            adc_valid <= cic_vld;
        end
    end

endmodule: sigma_delta_adc
