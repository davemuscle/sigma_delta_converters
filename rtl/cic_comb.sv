// Dave Muscle

//Decimator designed for use in a multi-stage CIC filter

/*
    x[n] --|---------> + ----> y[n]
           |           x (-1)
           ---[z^-1]-->|
*/

module cic_comb #(
    parameter int WIDTH = 32
)(
    input  bit clk,
    input  bit rst,
    input  bit ena,
    input  bit [WIDTH-1:0] data_in ,
    output bit [WIDTH-1:0] data_out
);
    bit [WIDTH-1:0] r_data;

    always_ff @(posedge clk) begin
        if(ena) begin
            r_data <= data_in ;
            data_out <= r_data - data_in ;
        end
        if(rst) begin
            data_out <= 0;
            r_data <= 0;
        end
    end

endmodule: cic_comb
