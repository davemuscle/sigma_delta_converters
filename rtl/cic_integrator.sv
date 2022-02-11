// Dave Muscle

//Integrator designed for use in a multi-stage CIC filter

/*
    x[n] ---> + --> y[n] --->
              |             |
              |<--[z^-1]----| 
*/

module cic_integrator #(
    parameter int WIDTH = 32
)(
    input  bit clk,
    input  bit rst,
    input  bit ena,
    input  bit [WIDTH-1:0] data_in ,
    output bit [WIDTH-1:0] data_out
);

    always_ff @(posedge clk) begin
        if(ena) begin
            data_out <= data_out + data_in ;
        end
        if(rst) begin
            data_out <= 0;
        end
    end

endmodule: cic_integrator
