module top
(
    input bit clk,
    input bit [1:0] sw,
    input bit pin,
    output bit fb,
    output bit dac_pin,
    output bit [7:0] led,
    output bit tx,
    input bit rx
);

    bit [23:0] adc_output;
    bit adc_valid;

    // instantiate adc
    sigma_delta_adc #(
        .OVERSAMPLE_RATE(1024),
        .CIC_STAGES(2),
        .ADC_BITLEN(20)
    ) dut_adc (
        .clk(clk),
        .rst(1'b0),
        .adc_lvds_pin(pin),
        .adc_fb_pin(fb),
        .adc_output(adc_output),
        .adc_valid(adc_valid)
    );

    bit [23:0] dac_input = 0;

    localparam BITLEN = 20;
    const int sine_lut [256] = '{
        0: 1048476,
        1: 1048318,
        2: 1047844,
        3: 1047055,
        4: 1045951,
        5: 1044533,
        6: 1042802,
        7: 1040758,
        8: 1038403,
        9: 1035739,
        10: 1032766,
        11: 1029487,
        12: 1025904,
        13: 1022019,
        14: 1017834,
        15: 1013351,
        16: 1008574,
        17: 1003505,
        18: 998148,
        19: 992505,
        20: 986580,
        21: 980377,
        22: 973899,
        23: 967150,
        24: 960134,
        25: 952856,
        26: 945319,
        27: 937529,
        28: 929490,
        29: 921207,
        30: 912685,
        31: 903929,
        32: 894944,
        33: 885736,
        34: 876311,
        35: 866673,
        36: 856829,
        37: 846785,
        38: 836546,
        39: 826119,
        40: 815511,
        41: 804727,
        42: 793774,
        43: 782659,
        44: 771388,
        45: 759968,
        46: 748407,
        47: 736710,
        48: 724886,
        49: 712940,
        50: 700881,
        51: 688716,
        52: 676451,
        53: 664095,
        54: 651655,
        55: 639138,
        56: 626552,
        57: 613904,
        58: 601202,
        59: 588454,
        60: 575667,
        61: 562849,
        62: 550008,
        63: 537152,
        64: 524288,
        65: 511423,
        66: 498567,
        67: 485726,
        68: 472908,
        69: 460121,
        70: 447373,
        71: 434671,
        72: 422023,
        73: 409437,
        74: 396920,
        75: 384480,
        76: 372124,
        77: 359859,
        78: 347694,
        79: 335635,
        80: 323689,
        81: 311865,
        82: 300168,
        83: 288607,
        84: 277187,
        85: 265916,
        86: 254801,
        87: 243848,
        88: 233064,
        89: 222456,
        90: 212029,
        91: 201790,
        92: 191746,
        93: 181902,
        94: 172264,
        95: 162839,
        96: 153631,
        97: 144646,
        98: 135890,
        99: 127368,
        100: 119085,
        101: 111046,
        102: 103256,
        103: 95719,
        104: 88441,
        105: 81425,
        106: 74676,
        107: 68198,
        108: 61995,
        109: 56070,
        110: 50427,
        111: 45070,
        112: 40001,
        113: 35224,
        114: 30741,
        115: 26556,
        116: 22671,
        117: 19088,
        118: 15809,
        119: 12836,
        120: 10172,
        121: 7817,
        122: 5773,
        123: 4042,
        124: 2624,
        125: 1520,
        126: 731,
        127: 257,
        128: 100,
        129: 257,
        130: 731,
        131: 1520,
        132: 2624,
        133: 4042,
        134: 5773,
        135: 7817,
        136: 10172,
        137: 12836,
        138: 15809,
        139: 19088,
        140: 22671,
        141: 26556,
        142: 30741,
        143: 35224,
        144: 40001,
        145: 45070,
        146: 50427,
        147: 56070,
        148: 61995,
        149: 68198,
        150: 74676,
        151: 81425,
        152: 88441,
        153: 95719,
        154: 103256,
        155: 111046,
        156: 119085,
        157: 127368,
        158: 135890,
        159: 144646,
        160: 153631,
        161: 162839,
        162: 172264,
        163: 181902,
        164: 191746,
        165: 201790,
        166: 212029,
        167: 222456,
        168: 233064,
        169: 243848,
        170: 254801,
        171: 265916,
        172: 277187,
        173: 288607,
        174: 300168,
        175: 311865,
        176: 323689,
        177: 335635,
        178: 347694,
        179: 359859,
        180: 372124,
        181: 384480,
        182: 396920,
        183: 409437,
        184: 422023,
        185: 434671,
        186: 447373,
        187: 460121,
        188: 472908,
        189: 485726,
        190: 498567,
        191: 511423,
        192: 524287,
        193: 537152,
        194: 550008,
        195: 562849,
        196: 575667,
        197: 588454,
        198: 601202,
        199: 613904,
        200: 626552,
        201: 639138,
        202: 651655,
        203: 664095,
        204: 676451,
        205: 688716,
        206: 700881,
        207: 712940,
        208: 724886,
        209: 736710,
        210: 748407,
        211: 759968,
        212: 771388,
        213: 782659,
        214: 793774,
        215: 804727,
        216: 815511,
        217: 826119,
        218: 836546,
        219: 846785,
        220: 856829,
        221: 866673,
        222: 876311,
        223: 885736,
        224: 894944,
        225: 903929,
        226: 912685,
        227: 921207,
        228: 929490,
        229: 937529,
        230: 945319,
        231: 952856,
        232: 960134,
        233: 967150,
        234: 973899,
        235: 980377,
        236: 986580,
        237: 992505,
        238: 998148,
        239: 1003505,
        240: 1008574,
        241: 1013351,
        242: 1017834,
        243: 1022019,
        244: 1025904,
        245: 1029487,
        246: 1032766,
        247: 1035739,
        248: 1038403,
        249: 1040758,
        250: 1042802,
        251: 1044533,
        252: 1045951,
        253: 1047055,
        254: 1047844,
        255: 1048318
    };
        
    localparam FREQ_CNT = 443;
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
        .DAC_BITLEN(20)
    ) dut_dac (
        .clk(clk),
        .rst(sw[0]),
        .dac_input(dac_input),
        .dac_pin(dac_pin)
    );

    always_comb begin
        led = ~(adc_output[19:12]);
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
        .CLKRATE(50000000),
        .BAUDRATE(115200)
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
    
    localparam NUM_SAMPLES = 4096;

    bit [23:0] samples [NUM_SAMPLES-1:0];
    bit [31:0] sample_idx = 0;

    localparam WAIT_CNT = 5000;
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
