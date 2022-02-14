// Dave Muscle

// Sigma Delta DAC in FPGA

module sigma_delta_dac #(
    parameter int DAC_BITLEN = 16
)(
    input bit clk,
    input bit rst,

    input bit [DAC_BITLEN-1:0] dac_input,
    input bit dac_valid,

    output bit dac_pin

);

    bit [DAC_BITLEN:0] adcc;
    always_ff @(posedge clk) begin
        adcc <= adcc[DAC_BITLEN-1:0] + dac_input;
        dac_pin <= adcc[DAC_BITLEN];
        if(rst) begin
            dac_pin <= 0;
            adcc <= 0;
        end
    end


    //bit [DAC_BITLEN+2-1:0] acc;
    //bit [DAC_BITLEN+2-1:0] ext;

    //always_comb begin
    //    ext = {dac_input[15], dac_input[15], dac_input};
    //end

    //always_ff @(posedge clk) begin
    //    if(dac_pin) begin
    //        acc <= acc + ext - (2**15);
    //    end
    //    else begin
    //        acc <= acc + ext + (2**15);
    //    end
    //    dac_pin <= ~acc[17];
    //end

endmodule: sigma_delta_dac
