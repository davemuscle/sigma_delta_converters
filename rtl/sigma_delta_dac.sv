// Dave Muscle

// Sigma Delta DAC in FPGA

module sigma_delta_dac #(
    parameter int OVERSAMPLE_RATE = 256,
    parameter int CIC_STAGES = 2,
    parameter int DAC_BITLEN = 16,
    parameter bit USE_FIR_COMP = 1,
    parameter int FIR_COMP_ALPHA_8 = 2
)(
    input bit clk,
    input bit rst,

    input bit [DAC_BITLEN-1:0] dac_input,
    output bit dac_ready,

    output bit dac_pin

);

    //iptimator signals
    localparam CNT_DAC_BITLEN = $clog2(OVERSAMPLE_RATE);
    bit [CNT_DAC_BITLEN-1:0] ipt_cnt = 0;
    const bit [CNT_DAC_BITLEN-1:0] ipt_cmp = CNT_DAC_BITLEN'(OVERSAMPLE_RATE-1);
    bit ipt_ena = 0;

    //compensator
    bit [DAC_BITLEN-1:0] fir_in, fir_out;

    //comb/integrator signals
    bit [DAC_BITLEN-1:0] cic_comb_data [CIC_STAGES:0] = '{default:0};
    bit [DAC_BITLEN-1:0] cic_inte_data [CIC_STAGES:0] = '{default:0};

    //lazy upscaler
    bit [DAC_BITLEN-1:0] lazy_interp_reg = 0;
    bit [DAC_BITLEN-1:0] lazy_interp_dly = 0;
    bit [DAC_BITLEN-1:0] lazy_interp_step = 0;
    bit [DAC_BITLEN-1:0] lazy_out = 0;
    localparam OSR_LOG2 = $clog2(OVERSAMPLE_RATE);
    
    always_ff @(posedge clk) begin
        //iptimator control
        ipt_cnt <= ipt_cnt + CNT_DAC_BITLEN'(1);
        if(ipt_cnt == ipt_cmp) begin
            ipt_ena <= 1;
        end
        else begin
            ipt_ena <= 0;
        end
        //reset 
        if(rst) begin
            ipt_cnt <= 0;
        end
    end

    bit [DAC_BITLEN-1:0] pre_out;

    always_comb begin
        dac_ready = ipt_ena;
        fir_in = ipt_ena ? dac_input : 0;
        fir_in = dac_input;
        //cic_comb_data[0] = ipt_ena ? dac_input : 0;
        cic_comb_data[0] = fir_in;
        cic_inte_data[0] = cic_comb_data[CIC_STAGES];
        pre_out = cic_inte_data[CIC_STAGES];
    end

    //lazy upscaler
    always_ff @(posedge clk) begin
        bit [DAC_BITLEN-1:0] sub;
        if(ipt_ena) begin
            lazy_interp_reg <= dac_input << OSR_LOG2;
            lazy_interp_dly <= lazy_interp_reg;
            lazy_out <= lazy_interp_dly;
            lazy_interp_step <= signed'(lazy_interp_reg - lazy_interp_dly) >>> OSR_LOG2;
        end
        else begin
            lazy_out <= lazy_out + lazy_interp_step;
        end
    end


    fir_compensator #(
        .WIDTH(DAC_BITLEN),
        .ALPHA_8(FIR_COMP_ALPHA_8)
    ) fir_comp_u0 (
        .clk(clk),
        .rst(rst),
        .ena(1'b1),
        .data_in (lazy_out),
        .data_out(fir_out)
    );

    //place cic iptimator
    genvar i;
    generate
        for(i = 0; i < CIC_STAGES; i = i + 1) begin: gen_cic
            cic_comb #(
                .WIDTH(DAC_BITLEN)
            ) cic_inst_u0 (
                .clk(clk),
                .rst(rst),
                .ena(1'b1),
                .data_in (cic_comb_data[i]),
                .data_out(cic_comb_data[i+1])
            );
            cic_integrator #(
                .WIDTH(DAC_BITLEN)
            ) cic_inst_u1 (
                .clk(clk), 
                .rst(rst),
                .ena(1'b1),
                .data_in (cic_inte_data[i]),
                .data_out(cic_inte_data[i+1])
            );
        end
    endgenerate

    bit [DAC_BITLEN:0] accum = 0;
    always_ff @(posedge clk) begin
        accum <= accum[DAC_BITLEN-1:0] + pre_out;
    end

    always_comb begin
        dac_pin = accum[DAC_BITLEN];
    end

    

endmodule: sigma_delta_dac
