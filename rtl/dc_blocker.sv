// DaveMuscle

// DC Blocking Filter

// choose lower values of alpha (higher DC_BLOCK_SHIFT)
// this will avoid attenuation of lower freqs in favor of tau

//https://www.embedded.com/dsp-tricks-dc-removal/
/*
    x[n] ---> + -------------------------> y[n]
              |                       |
         (-1) x      --------->|      x (1-a)
              |      |         |      |
              <---[ z^-1 ] <-- + <----
*/ 

module dc_blocker #(
    parameter int WIDTH = 32,
    parameter int DC_BLOCK_SHIFT = 10
)(
    input  bit clk,
    input  bit rst,
    input  bit ena,
    input  bit [WIDTH-1:0] data_in ,
    output bit [WIDTH-1:0] data_out
);

    bit signed [WIDTH-1:0] dc_yn = 0; 
    bit signed [WIDTH-1:0] dc_yn_reg = 0;

    always_ff @(posedge clk) begin
        if(ena) begin
            dc_yn <= data_in  - dc_yn_reg;
            dc_yn_reg <= (dc_yn >>> DC_BLOCK_SHIFT) + dc_yn_reg;
            data_out <= dc_yn;
        end
        if(rst) begin
            dc_yn <= 0;
            dc_yn_reg <= 0;
        end
    end

endmodule: dc_blocker
