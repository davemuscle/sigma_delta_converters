// Dave Muscle

// Sigma Delta ADC in FPGA

module sigma_delta_adc #(
    parameter int BOSR = 256,
    parameter int STGS = 2,
    parameter int WDTH = 16
)(
    input bit clk,
    input bit rst, //reset for optional power saving

    input bit adc_lvds_pin, // connect to analog input
    output bit adc_fb_pin,  // connect to integrator

    output bit [WDTH-1:0] adc_output, //digital output
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
    bit [WDTH-1:0] cic_int [STGS-1:0] = '{default:0};
    bit [WDTH-1:0] cic_dec [STGS-1:0] = '{default:0};
    bit [WDTH-1:0] cic_dly [STGS-1:0] = '{default:0};
    bit [WDTH-1:0] cic_out = 0;
    bit            cic_vld = 0;
    //decimator signals
    localparam CNT_WDTH = $clog2(BOSR);
    bit [CNT_WDTH-1:0] dec_cnt = 0;
    const bit [CNT_WDTH-1:0] dec_cmp = CNT_WDTH'(BOSR-1);
    bit dec_ena = 0;

    //CIC Filter for BOSR decimation
    always_ff @(posedge clk) begin: cic_filter
        int i;

        //Integrator Filters
        for(i = 0; i < STGS; i = i +1) begin
            if(i == 0) begin
                cic_int[i] <= cic_int[i] + WDTH'(adc_in);
            end
            else begin
                cic_int[i] <= cic_int[i] + cic_int[i-1];
            end
        end

        //Time-gate decimators via enable signal
        dec_cnt <= dec_cnt + 1;
        if(dec_cnt == dec_cmp) begin
            dec_ena <= 1;
        end
        else begin
            dec_ena <= 0;
        end

        //Comb Filters
        if(dec_ena) begin
            for(i = 0; i < STGS; i = i + 1) begin
                if(i == 0) begin
                    cic_dec[i] <= cic_dly[i] - cic_int[STGS-1];
                    cic_dly[i] <= cic_int[STGS-1];
                end
                else begin
                    cic_dec[i] <= cic_dly[i] - cic_dec[i-1];
                    cic_dly[i] <= cic_dec[i-1];
                end
            end
        end
        cic_out <= cic_dec[STGS-1];
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

    //FIR Filter for optional extra decimation + smoothing
    always_ff @(posedge clk) begin
        adc_output <= cic_out;
        adc_valid  <= cic_vld;
    end


endmodule: sigma_delta_adc
