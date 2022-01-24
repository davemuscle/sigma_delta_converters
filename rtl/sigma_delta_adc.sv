
module sigma_delta_adc #(
    parameter int BOSR = 256,
    parameter int WDTH = 16,
    parameter int BOX_AVG = 2,
    parameter int CIC_STAGES = 2
)(
    input bit clk,

    input bit adc_lvds_pin, // connect to analog input
    output bit adc_fb_pin,  // connect to integrator

    output bit [WDTH-1:0] adc_output, //16-bit signed output
    output bit adc_valid //signals valid output

);

    bit adc_in;

    //sample analog input connected to lvds positive
    always_ff @(posedge clk) begin: front_end
        adc_in <= adc_lvds_pin;
    end

    //feedback output connected to lvds negative
    always_comb begin
        adc_fb_pin = adc_in;
    end
if(CIC_STAGES == 0) begin
    //accumulate and decimate
    bit [WDTH-1:0] accum = 0;
    int cnt = 0;
    const bit [WDTH-1:0] ones = '{default:1'b1};
    bit valid = 0;
    bit [WDTH-1:0] adc_pre = 0;
    bit [WDTH-1:0] box [BOX_AVG-1:0] = '{default:0};

    always_ff @(posedge clk) begin: here
        int i;
        //accumulate
        if(accum != ones) begin
            accum <= accum + adc_in;
        end 
        //decimate
        cnt <= cnt + 1;
        valid <= 0;
        if(cnt == BOSR-1) begin
            cnt <= 0;
            adc_pre <= accum;
            valid <= 1;
            accum <= 0;
        end
        //average
        adc_valid <= 0;
        if(valid) begin
            adc_valid <= 1;
            for(i = 1; i < BOX_AVG; i = i + 1) begin
                box[i] <= box[i-1];
            end
            box[0] <= adc_pre;
            adc_output = box[0];
            for(i = 1; i < BOX_AVG; i = i + 1) begin
                adc_output = adc_output + box[i];
            end
            adc_output = adc_output >> $clog2(BOX_AVG);
        end
    end
end
else begin
    bit [WDTH-1:0] cic_int [CIC_STAGES-1:0] = '{default:0};
    bit [WDTH-1:0] cic_int_dly [CIC_STAGES-1:0] = '{default:0};
    bit [WDTH-1:0] cic_dec [CIC_STAGES-1:0] = '{default:0};
    bit [WDTH-1:0] cic_dec_dly [CIC_STAGES-1:0] = '{default:0};
    
    wire [WDTH-1:0] cic_int0, cic_int1, cic_dec0, cic_dec1;
    assign cic_int0 = cic_int[0];
    assign cic_int1 = cic_int[1];
    assign cic_dec0 = cic_dec[0];
    assign cic_dec1 = cic_dec[1];

    bit [WDTH-1:0] ccnt = 0;

    bit [$clog2(BOSR)-1:0] dec_cnt = 0;
    const bit [$clog2(BOSR)-1:0] dec_cmp = '{default:1};
    bit dec_ena = 0;

    //CIC Filter for BOSR decimation
    always_ff @(posedge clk) begin: cic_filter
        int i;
        //Integrator Filters
        for(i = 0; i < CIC_STAGES; i = i +1) begin
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
            for(i = 0; i < CIC_STAGES; i = i + 1) begin
                if(i == 0) begin
                    cic_dec[i] <= cic_dec_dly[i] - cic_int[CIC_STAGES-1];
                    cic_dec_dly[i] <= cic_int[CIC_STAGES-1];
                end
                else begin
                    cic_dec[i] <= cic_dec_dly[i] - cic_dec[i-1];
                    cic_dec_dly[i] <= cic_dec[i-1];
                end
            end
        end
        adc_output <= cic_dec[CIC_STAGES-1];
        //valid output -- todo: add fir filter
        adc_valid <= dec_ena;
    end
end

endmodule: sigma_delta_adc
