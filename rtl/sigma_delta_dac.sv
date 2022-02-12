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

    always_comb begin
        dac_ready = ipt_ena;
        fir_in = ipt_ena ? dac_input : 0;
        fir_in = dac_input;
        //cic_comb_data[0] = ipt_ena ? dac_input : 0;
        cic_comb_data[0] = fir_out;
        cic_inte_data[0] = cic_comb_data[CIC_STAGES];
    end

    bit [DAC_BITLEN:0] accum = 0;
    always_ff @(posedge clk) begin
        accum <= accum[DAC_BITLEN-1:0] + cic_inte_data[CIC_STAGES];
    end

    always_comb begin
        dac_pin = accum[DAC_BITLEN];
    end

    fir_compensator #(
        .WIDTH(DAC_BITLEN),
        .ALPHA_8(FIR_COMP_ALPHA_8)
    ) fir_comp_u0 (
        .clk(clk),
        .rst(rst),
        .ena(1'b1),
        .data_in (fir_in),
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


    

endmodule: sigma_delta_dac
