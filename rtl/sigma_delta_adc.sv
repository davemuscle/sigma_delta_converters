// Dave Muscle

// Sigma Delta ADC in FPGA

module sigma_delta_adc #(
    parameter int OVERSAMPLE_RATE = 256,
    parameter int CIC_STAGES = 2,
    parameter int ADC_BITLEN = 16,
    parameter bit USE_FIR_COMP = 1,
    parameter int FIR_COMP_ALPHA_8 = 2,
    parameter bit SIGNED_OUTPUT = 1,
    parameter int DC_BLOCK_SHIFT = 7,
    parameter int GLITCHLESS_STARTUP = 10
)(
    input bit clk,
    input bit rst, //reset for optional power saving

    input bit adc_lvds_pin, // connect to analog input
    output bit adc_fb_pin,  // connect to integrator

    output bit [ADC_BITLEN-1:0] adc_output, //digital output
    output bit adc_valid              //signals valid output

);

    bit adc_in;

    //decimator signals
    localparam CNT_ADC_BITLEN = $clog2(OVERSAMPLE_RATE);
    bit [CNT_ADC_BITLEN-1:0] dec_cnt = 0;
    const bit [CNT_ADC_BITLEN-1:0] dec_cmp = CNT_ADC_BITLEN'(OVERSAMPLE_RATE-1);
    bit dec_ena = 0;

    //comb/integrator signals
    bit [ADC_BITLEN-1:0] cic_inte_data [CIC_STAGES:0] = '{default:0};
    bit [ADC_BITLEN-1:0] cic_comb_data [CIC_STAGES:0] = '{default:0};
    
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
        cic_inte_data[0] = ADC_BITLEN'(adc_in);
        cic_comb_data[0] = cic_inte_data[CIC_STAGES];
    end

    //place cic decimator
    genvar i;
    generate
        for(i = 0; i < CIC_STAGES; i = i + 1) begin: gen_cic
            cic_integrator #(
                .WIDTH(ADC_BITLEN)
            ) cic_inst_u0 (
                .clk(clk), 
                .rst(rst),
                .ena(1'b1),
                .data_in (cic_inte_data[i]),
                .data_out(cic_inte_data[i+1])
            );
            cic_comb #(
                .WIDTH(ADC_BITLEN)
            ) cic_inst_u1 (
                .clk(clk),
                .rst(rst),
                .ena(dec_ena),
                .data_in (cic_comb_data[i]),
                .data_out(cic_comb_data[i+1])
            );
        end
    endgenerate

    bit [ADC_BITLEN-1:0] fir_data;
    bit [ADC_BITLEN-1:0] post_fir_data;

    //place optional fir compensator
    generate
    if(USE_FIR_COMP) begin: gen_fir
        fir_compensator #(
            .WIDTH(ADC_BITLEN),
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
    
    //generic to switch between fir and normal path
    always_comb begin
        if(USE_FIR_COMP) begin
            post_fir_data = fir_data;
        end
        else begin
            post_fir_data = cic_comb_data[CIC_STAGES];
        end
    end

    bit [ADC_BITLEN-1:0] dc_blocked;
    bit [ADC_BITLEN-1:0] post_dc_blocked;

    //DC Removal / Assign Output
    generate
    if(SIGNED_OUTPUT) begin: gen_signed
        dc_blocker #(
            .WIDTH(ADC_BITLEN),
            .DC_BLOCK_SHIFT(DC_BLOCK_SHIFT)
        ) dc_blocker_u0 (
            .clk(clk),
            .rst(rst),
            .ena(dec_ena),
            .data_in (post_fir_data),
            .data_out(dc_blocked)
        ); 
    end
    endgenerate

    //generic to switch between dc blocked and normal path
    always_comb begin
        if(SIGNED_OUTPUT) begin
            post_dc_blocked = dc_blocked;
        end
        else begin
            post_dc_blocked = post_fir_data;
        end
    end

    localparam CNT_GLT_STALEN = $clog2(GLITCHLESS_STARTUP);
    const bit [CNT_GLT_STALEN-1:0] glt_cmp = CNT_GLT_STALEN'(GLITCHLESS_STARTUP-1);
    bit [CNT_GLT_STALEN-1:0] glt_cnt = 0;

    //Provide option for glitchless output
    always_ff @(posedge clk) begin
        if(GLITCHLESS_STARTUP == 0) begin
            adc_valid <= dec_ena;
        end
        else begin
            //assign output only when glitch count is saturated
            if(glt_cnt == glt_cmp) begin
                adc_valid <= dec_ena;
            end
            else begin
                adc_valid <= 0;
            end
            //update count
            if(dec_ena == 1 && glt_cnt < glt_cmp) begin
                glt_cnt <= glt_cnt + 1;
            end
        end
        //reset
        if(rst) begin
            glt_cnt <= 0;
        end
        //update output
        adc_output <= post_dc_blocked;
    end

endmodule: sigma_delta_adc
