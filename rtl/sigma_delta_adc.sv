// Dave Muscle

// Sigma Delta ADC in FPGA

module sigma_delta_adc #(
    parameter int OVERSAMPLE_RATE = 256,
    parameter int CIC_STAGES = 2,
    parameter int ADC_BITLEN = 16,
    parameter bit USE_FIR_COMP = 1,
    parameter int FIR_COMP_ALPHA_8 = 2
)(
    input bit clk,
    input bit rst, //reset for optional power saving

    input bit adc_lvds_pin, // connect to analog input
    output bit adc_fb_pin,  // connect to integrator

    output bit [ADC_BITLEN-1:0] adc_output, //digital output
    output bit adc_valid              //signals valid output

);
    
    //add an extra bit to pad a sign bit for underflows
    localparam int CIC_BITLEN = 1 + 1 + int'((CIC_STAGES * $clog2(OVERSAMPLE_RATE)));

    bit adc_in;

    //decimator signals
    localparam CNT_ADC_BITLEN = $clog2(OVERSAMPLE_RATE);
    bit [CNT_ADC_BITLEN-1:0] dec_cnt = 0;
    const bit [CNT_ADC_BITLEN-1:0] dec_cmp = CNT_ADC_BITLEN'(OVERSAMPLE_RATE-1);
    bit dec_ena = 0;

    //comb/integrator signals
    bit [CIC_BITLEN-1:0] cic_inte_data [CIC_STAGES:0] = '{default:0};
    bit [CIC_BITLEN-1:0] cic_comb_data [CIC_STAGES:0] = '{default:0};
    
    //sample analog input connected to lvds positive
    always_ff @(posedge clk) begin
        //sample input
        adc_in <= adc_lvds_pin;
        //feedback output connected to lvds negative
        adc_fb_pin <= adc_lvds_pin;
        //decimator control
        dec_cnt <= dec_cnt + CNT_ADC_BITLEN'(1);
        if(dec_cnt == dec_cmp) begin
            dec_ena <= 1;
        end
        else begin
            dec_ena <= 0;
        end
        //reset 
        if(rst) begin
            adc_in <= 0;
            dec_cnt <= 0;
        end
    end

    //assign first values to array
    always_comb begin
        cic_inte_data[0] = CIC_BITLEN'(adc_in);
        cic_comb_data[0] = cic_inte_data[CIC_STAGES];
    end

    //place cic decimator
    genvar i;
    generate
        for(i = 0; i < CIC_STAGES; i = i + 1) begin: gen_cic
            cic_integrator #(
                .WIDTH(CIC_BITLEN)
            ) cic_inst_u0 (
                .clk(clk), 
                .rst(rst),
                .ena(1'b1),
                .data_in (cic_inte_data[i]),
                .data_out(cic_inte_data[i+1])
            );
            cic_comb #(
                .WIDTH(CIC_BITLEN)
            ) cic_inst_u1 (
                .clk(clk),
                .rst(rst),
                .ena(dec_ena),
                .data_in (cic_comb_data[i]),
                .data_out(cic_comb_data[i+1])
            );
        end
    endgenerate

    bit [CIC_BITLEN-1:0] fir_data;
    bit [CIC_BITLEN-1:0] post_fir_data;

    //place optional fir compensator
    generate
    if(USE_FIR_COMP) begin: gen_fir
        fir_compensator #(
            .WIDTH(CIC_BITLEN),
            .ALPHA_8(FIR_COMP_ALPHA_8)
        ) fir_comp_u0 (
            .clk(clk),
            .rst(rst),
            .ena(dec_ena),
            .data_in (cic_comb_data[CIC_STAGES]),
            .data_out(fir_data)
        );
    end
    endgenerate
    
    //switch between fir and cic path
    always_comb begin
        if(USE_FIR_COMP) begin
            post_fir_data = fir_data;
        end
        else begin
            post_fir_data = cic_comb_data[CIC_STAGES];
        end
    end

    //assign output, do saturation if too high or low
    //tested in sim with a sine input twice the fullscale voltage
    always_ff @(posedge clk) begin
        localparam cmp =  (2**ADC_BITLEN)-1;
        adc_valid <= dec_ena;
        //clip underflow
        if(post_fir_data[CIC_BITLEN-1]) begin
            adc_output <= 0;
        end
        //clip overflow
        else if(post_fir_data > CIC_BITLEN'(cmp)) begin
            adc_output <= ADC_BITLEN'(cmp);
        end
        //just assign normally
        else begin
            adc_output <= ADC_BITLEN'(post_fir_data);
        end
    end



endmodule: sigma_delta_adc
