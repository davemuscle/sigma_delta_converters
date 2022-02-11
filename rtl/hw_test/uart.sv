//Dave Muscle

// Double-buffered basic UART module
// 8 data, 1 start, 1 stop
// No parity

module uart #(
    parameter int CLKRATE  = 50000000,
    parameter int BAUDRATE = 115200
)(
    // clock and reset
    input  logic clk,
    input  logic rst,

    // phy pins
    input  logic rx,
    output logic tx = 1,

    // transmit path
    input  logic tvalid,
    output logic tready = 0,
    input  logic [7:0] tdata,
    
    // receive path
    output logic rvalid = 0,
    input  logic rready,
    output logic [7:0] rdata
);

    //baud generation parameters
    localparam BAUD_DIV = CLKRATE/BAUDRATE;
    localparam BAUD_CNT = $clog2(BAUD_DIV-1);
    logic rx_baud_en = 0;
    logic tx_baud_en = 0;
    logic [BAUD_CNT-1:0] rx_baud_cnt = 0;
    logic [BAUD_CNT-1:0] tx_baud_cnt = 0;
    logic rx_baud_clk = 0;
    logic tx_baud_clk = 0;

    //Baud Generators
    always_ff @(posedge clk) begin: baud_gen
        //Receiver Baud
        if(rx_baud_en) begin
            if(rx_baud_cnt == BAUD_DIV-1) begin
                rx_baud_cnt <= 0;
                rx_baud_clk <= 1;
            end
            else begin
                rx_baud_cnt <= rx_baud_cnt + 1;
                rx_baud_clk <= 0;
            end
        end
        else begin
            rx_baud_cnt <= BAUD_DIV/2;
            rx_baud_clk <= 0;
        end
        //Transmitter Baud
        if(tx_baud_en) begin
            if(tx_baud_cnt == BAUD_DIV-1) begin
                tx_baud_cnt <= 0;
                tx_baud_clk <= 1;
            end
            else begin
                tx_baud_cnt <= tx_baud_cnt + 1;
                tx_baud_clk <= 0;
            end
        end
        else begin
            tx_baud_cnt <= BAUD_DIV/2;
            tx_baud_clk <= 0;
        end
    end

    //signals for receive
    logic [9:0] rx_data = 0;

    //Receive Path
    always_ff @(posedge clk) begin: rxp
        //start baud rate generator on falling edge (start bit)
        if(!rst & !rx & !rx_baud_en) begin
            rx_baud_en <= 1;
            //reset shift register
            rx_data <= '{default:1'b1};
        end
        //shift register
        if(rx_baud_clk) begin
            //data is placed in [9] and shifted right for lsb first
            rx_data[8:0] <= rx_data[9:1];
            rx_data[9] <= rx;
        end
        //kill the baud rate generator after a byte is received
        if(rx_baud_en == 1 && rx_data[0] == 0 && rx_data[9] == 1) begin
            rdata <= rx_data[8:1];
            rvalid <= 1;
            rx_baud_en <= 0;
        end
        //read handshake
        if(rvalid & rready) begin
            rvalid <= 0;
        end
        //reset
        if(rst) begin
            rvalid <= 0;
            rx_baud_en <= 0;
        end
    end

    //signals for transmit
    logic [9:0] tx_data = 0;

    //Transmit Path
    always_ff @(posedge clk) begin: txp
        //transmit side is ready when baud is disabled
        if(!rst & !tx_baud_en) begin
            tready <= 1;
        end
        else begin
            tready <= 0;
        end
        //start tx after handshake
        if(tready & tvalid) begin
            tx_baud_en <= 1;
            tready <= 0;
            //reset shift reg
            tx_data[9]   <= 1;
            tx_data[8:1] <= tdata;
            tx_data[0]   <= 0;
        end
        //shift out
        if(tx_baud_clk) begin
            tx <= tx_data[0];
            tx_data[8:0] <= tx_data[9:1];
            //push in a zero into the register for later
            tx_data[9] <= 0;
        end
        //default line high
        if(!tx_baud_en) begin
            tx <= 1;
        end
        //kill baud generator once byte is sent
        if(tx_baud_en == 1 && tx_data == 0) begin
            tx_baud_en <= 0;
        end
        if(rst) begin
            tx <= 1;
            tx_baud_en <= 0;
        end
    end

endmodule: uart
