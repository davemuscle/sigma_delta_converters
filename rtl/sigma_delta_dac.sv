// Dave Muscle

// Sigma Delta DAC in FPGA

module sigma_delta_dac #(
    parameter int DAC_BITLEN = 16
)(
    input bit clk,
    input bit rst,

    input bit [DAC_BITLEN-1:0] dac_input,
    output bit dac_pin

);

    bit [DAC_BITLEN:0] acc1 = 0;
    always_ff @(posedge clk) begin
        acc1 <= acc1[DAC_BITLEN-1:0] + dac_input;
        dac_pin <= acc1[DAC_BITLEN];
        if(rst) begin
            dac_pin <= 0;
            acc1 <= 0;
        end
    end


endmodule: sigma_delta_dac
