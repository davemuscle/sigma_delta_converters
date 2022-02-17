module top
(
    input bit clk50,
    input bit [1:0] sw,
    input bit pin,
    output bit fb,
    output bit dac_pin,
    output bit [7:0] led,
    output bit tx,
    input bit rx
);

    localparam OSR = 128;
    localparam CIC = 2;
    localparam BITLEN = CIC*$clog2(OSR);
    localparam CLKRATE = 6250000;
    localparam FREQ_CNT = CLKRATE / (256*440);
    localparam BAUDRATE = 115200;
    localparam NUM_SAMPLES = 512;
    localparam WAIT_CNT = 500;

    bit clk;

    pll	pll_inst (
	.inclk0 ( clk50 ),
	.c0 ( clk )
	);

    bit [BITLEN-1:0] adc_output;
    bit [BITLEN-1:0] dac_input;
    bit adc_valid;

    // instantiate adc
    sigma_delta_adc #(
        .OVERSAMPLE_RATE(OSR),
        .CIC_STAGES(CIC),
        .ADC_BITLEN(BITLEN),
        .USE_FIR_COMP(1),
        .FIR_COMP_ALPHA_8(2)
    ) dut_adc (
        .clk(clk),
        .rst(1'b0),
        .adc_lvds_pin(pin),
        .adc_fb_pin(fb),
        .adc_output(adc_output),
        .adc_valid(adc_valid)
    );


    const int sine_lut [256] = '{
        0: 16284,1: 16281,2: 16274,3: 16262,4: 16245,5: 16223,6: 16196,7: 16164,
        8: 16128,9: 16087,10: 16041,11: 15990,12: 15935,13: 15875,14: 15810,15: 15741,
        16: 15668,17: 15589,18: 15507,19: 15419,20: 15328,21: 15232,22: 15132,23: 15028,
        24: 14920,25: 14807,26: 14691,27: 14571,28: 14447,29: 14319,30: 14187,31: 14052,
        32: 13913,33: 13771,34: 13626,35: 13477,36: 13325,37: 13170,38: 13012,39: 12851,
        40: 12687,41: 12521,42: 12352,43: 12180,44: 12006,45: 11830,46: 11651,47: 11471,
        48: 11288,49: 11104,50: 10918,51: 10730,52: 10540,53: 10350,54: 10158,55: 9964,
        56: 9770,57: 9575,58: 9379,59: 9182,60: 8985,61: 8787,62: 8589,63: 8390,
        64: 8192,65: 7993,66: 7794,67: 7596,68: 7398,69: 7201,70: 7004,71: 6808,
        72: 6613,73: 6419,74: 6225,75: 6033,76: 5843,77: 5653,78: 5465,79: 5279,
        80: 5095,81: 4912,82: 4732,83: 4553,84: 4377,85: 4203,86: 4031,87: 3862,
        88: 3696,89: 3532,90: 3371,91: 3213,92: 3058,93: 2906,94: 2757,95: 2612,
        96: 2470,97: 2331,98: 2196,99: 2064,100: 1936,101: 1812,102: 1692,103: 1576,
        104: 1463,105: 1355,106: 1251,107: 1151,108: 1055,109: 964,110: 876,111: 794,
        112: 715,113: 642,114: 573,115: 508,116: 448,117: 393,118: 342,119: 296,
        120: 255,121: 219,122: 187,123: 160,124: 138,125: 121,126: 109,127: 102,
        128: 100,129: 102,130: 109,131: 121,132: 138,133: 160,134: 187,135: 219,
        136: 255,137: 296,138: 342,139: 393,140: 448,141: 508,142: 573,143: 642,
        144: 715,145: 794,146: 876,147: 964,148: 1055,149: 1151,150: 1251,151: 1355,
        152: 1463,153: 1576,154: 1692,155: 1812,156: 1936,157: 2064,158: 2196,159: 2331,
        160: 2470,161: 2612,162: 2757,163: 2906,164: 3058,165: 3213,166: 3371,167: 3532,
        168: 3696,169: 3862,170: 4031,171: 4203,172: 4377,173: 4553,174: 4732,175: 4912,
        176: 5095,177: 5279,178: 5465,179: 5653,180: 5843,181: 6033,182: 6225,183: 6419,
        184: 6613,185: 6808,186: 7004,187: 7201,188: 7398,189: 7596,190: 7794,191: 7993,
        192: 8191,193: 8390,194: 8589,195: 8787,196: 8985,197: 9182,198: 9379,199: 9575,
        200: 9770,201: 9964,202: 10158,203: 10350,204: 10540,205: 10730,206: 10918,207: 11104,
        208: 11288,209: 11471,210: 11651,211: 11830,212: 12006,213: 12180,214: 12352,215: 12521,
        216: 12687,217: 12851,218: 13012,219: 13170,220: 13325,221: 13477,222: 13626,223: 13771,
        224: 13913,225: 14052,226: 14187,227: 14319,228: 14447,229: 14571,230: 14691,231: 14807,
        232: 14920,233: 15028,234: 15132,235: 15232,236: 15328,237: 15419,238: 15507,239: 15589,
        240: 15668,241: 15741,242: 15810,243: 15875,244: 15935,245: 15990,246: 16041,247: 16087,
        248: 16128,249: 16164,250: 16196,251: 16223,252: 16245,253: 16262,254: 16274,255: 16281
    };
        
    bit [31:0] lut_tick = 0;
    bit [7:0] lut_idx = 0;
    bit [BITLEN-1:0] lut_read = 0;

    always_ff @(posedge clk) begin
        lut_tick <= lut_tick + 1;
        if(lut_tick == FREQ_CNT-1) begin
            lut_tick <= 0;
            lut_idx <= lut_idx + 1;
        end
        lut_read <= sine_lut[lut_idx];
    end

    always_comb begin
        dac_input = (sw[1]) ? adc_output : lut_read;
    end

    sigma_delta_dac #(
        .DAC_BITLEN(BITLEN)
    ) dut_dac (
        .clk(clk),
        .rst(sw[0]),
        .dac_input(dac_input),
        .dac_pin(dac_pin)
    );

    always_comb begin
        led = 8'hFF; //todo undo lights off
    end

    //uart signals
    bit tvalid = 0;
    bit tready = 0;
    bit rvalid = 0;
    bit rready = 0;
    bit [7:0] tdata = 0;
    bit [7:0] rdata = 0;

    uart #(
        .CLKRATE(CLKRATE),
        .BAUDRATE(BAUDRATE)
    ) u (
        .clk(clk),
        .rst(0),
        .rx(rx),
        .tx(tx),
        .tvalid(tvalid),
        .tready(tready),
        .tdata(tdata),
        .rvalid(rvalid),
        .rready(rready),
        .rdata(rdata)
    );
        
    //uart control
    bit sitting = 1;
    bit sampling = 0;
    bit pushing = 0;

    bit [23:0] samples [NUM_SAMPLES-1:0];
    bit [31:0] sample_idx = 0;

    bit [31:0] wait_idx = 0;
    bit [2:0] nibble_idx = 0;
    bit sample_read = 0;
    bit [23:0] sample_out;
    bit [7:0] nibble_to_send = 0;

    always_ff @(posedge clk) begin
        //receive command from uart 
        if(rvalid) begin
            rready <= 1;
        end
        if(rvalid & rready) begin
            rready <= 0;
            //if we got 's' or 'S' change cmd
            if(rdata == 8'h73 || rdata == 8'h53) begin
                if(sitting == 1) begin
                    sitting <= 0;
                    sampling <= 1;
                    sample_idx <= 0;
                end
            end
        end
        //pick up samples
        if(sampling) begin
            if(adc_valid) begin
                samples[sample_idx] <= adc_output;
                sample_idx <= sample_idx + 1;
                if(sample_idx == NUM_SAMPLES-1) begin
                    sampling <= 0;
                    pushing <= 1;
                    sample_idx <= 0;
                    nibble_idx <= 0;
                    wait_idx <= 0;
                end
            end
        end
        //send over uart
        sample_read <= 0;
        if(pushing) begin
            if(wait_idx == WAIT_CNT-1) begin
                //send sample
                wait_idx <= 0;
                sample_read <= 1;
            end
            else begin
                wait_idx <= wait_idx + 1;
            end
            
            //mux, blocking intentional
            case(nibble_idx)
                0: nibble_to_send = sample_out[23:20];
                1: nibble_to_send = sample_out[19:16];
                2: nibble_to_send = sample_out[15:12];
                3: nibble_to_send = sample_out[11:8];
                4: nibble_to_send = sample_out[7:4];
                5: nibble_to_send = sample_out[3:0];
            endcase
            
            if(sample_read) begin
                tvalid <= 1;
                if(nibble_idx < 6) begin
                    if(nibble_to_send < 10) begin
                        //number
                        tdata <= nibble_to_send + 8'h30;
                    end
                    else begin
                        //uppercase
                        tdata <= nibble_to_send + 8'h37;
                    end
                end
                else if(nibble_idx == 6) begin
                    //newline
                    tdata <= 8'h0A;
                end
                else begin
                    //carriage return
                    tdata <= 8'h0D;
                end
            end
            
            if(tvalid & tready) begin
                tvalid <= 0;
                if(nibble_idx >= 7) begin
                    nibble_idx <= 0;
                    sample_idx <= sample_idx + 1;
                    if(sample_idx == NUM_SAMPLES-1) begin
                        pushing <= 0;
                        sitting <= 1;
                        sample_idx <= 0;
                        nibble_idx <= 0;
                    end
                end
                else begin
                    nibble_idx <= nibble_idx + 1;
                end
            end
        end
        sample_out <= samples[sample_idx];
    end

endmodule: top
