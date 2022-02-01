module top
(
    input bit clk,
    input bit pin,
    output bit vref,
    output bit fb,
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
        .ADC_BITLEN(24),
        .SIGNED_OUTPUT(1),
        .DC_BLOCK_SHIFT(7)
    ) dut (
        .clk(clk),
        .rst(1'b0),
        .adc_lvds_pin(pin),
        .adc_fb_pin(fb),
        .adc_output(adc_output),
        .adc_valid(adc_valid)
    );

    always_comb begin
        led = ~(adc_output[19:12]);
        led = 8'hFF; //todo undo lights off
        vref = 1;
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
    
    localparam NUM_SAMPLES = 1024;

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
