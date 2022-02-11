// DaveMuscle

// Multiplier-less FIR compensator meant for post-processing CIC filters
// ALPHA is reduced to a fraction out of 8, eg: 0.358 -> 0.375 = 3/8
// Implicitly casts data to signed format, unsigned will not work

//https://dsp.stackexchange.com/questions/19584/how-to-make-cic-compensation-filter

/*
    x[n] ------> [ z^-1 ] -----
           |                  |
           + <-- [ z^-1 ] ----| 
           |                  x (1+a)
    (-a/2) x                  |
           |                  |
           -------------------+---> y[n]
*/

module fir_compensator #(
    parameter int WIDTH = 32,
    parameter int ALPHA_8 = 2
)(
    input bit clk,
    input bit rst,
    input bit ena,
    input  bit [WIDTH-1:0] data_in ,
    output bit [WIDTH-1:0] data_out
);

    bit signed [WIDTH-1:0] d1, d2;
    bit signed [WIDTH-1:0] sum, dly;
    
    bit signed [WIDTH-1:0] sum_mult;
    bit signed [WIDTH-1:0] dly_mult;
    bit signed [WIDTH-1:0] dly_dly;

    // h = (-a / 2) * (n'' + n) + (1+a)*n'

    // multiply by 'a/2' on the intermediate sum (n'' + n) and 'a' on the delay ( n')
    always_comb begin
        int i;
        bit signed [WIDTH-1:0] d[2];
        bit signed [WIDTH-1:0] e[2];
        bit signed [WIDTH-1:0] f[2];
        bit signed [WIDTH-1:0] h[2];
        bit signed [WIDTH-1:0] s[2];

        //shift amounts 
        //   ALPHA_8 = 1 --> 0.125 == 1/8
        //   ALPHA_8 = 2 --> 0.250 == 1/4
        //   ALPHA_8 = 3 --> 0.375 == 1/4 + 1/8
        //   ALPHA_8 = 4 --> 0.500 == 1/2
        //   ALPHA_8 = 5 --> 0.625 == 1/2 + 1/8
        //   ALPHA_8 = 6 --> 0.750 == 1/2 + 1/4
        //   ALPHA_8 = 7 --> 0.875 == 1/2 + 1/4 + 1/8

        d[0] = sum;
        d[1] = dly;

        //shifts
        for(i = 0; i < 2; i = i + 1) begin
            e[i] = 0;
            f[i] = 0;
            h[i] = 0;
            if((ALPHA_8 % 2) == 1) begin
                e[i] = d[i] >>> 3;
            end
            if((ALPHA_8 & 3) >= 2) begin
                f[i] = d[i] >>> 2; 
            end
            if(ALPHA_8 >= 4) begin
                h[i] = d[i] >>> 1;
            end
            //do the sum
            if(ALPHA_8 == 0) begin
                s[i] = 0;
            end
            else if(ALPHA_8 == 8) begin
                s[i] = sum;
            end
            else begin
                s[i] = e[i] + f[i] + h[i];
            end
        end
        sum_mult = s[0] >>> 1;
        dly_mult = s[1];
        dly_dly  = d[1];
    end

    always_ff @(posedge clk) begin
        if(ena) begin
            d1 <= data_in ;
            d2 <= d1;
            sum <= d2 + data_in ;
            dly <= d1;
            data_out <= ~sum_mult + 1 + dly_dly + dly_mult;
        end
        if(rst) begin
            d1 <= 0;
            d2 <= 0;
            sum <= 0;
            dly <= 0;
            data_out <= 0;
        end
    end

endmodule: fir_compensator
