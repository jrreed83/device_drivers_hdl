`timescale 1ns/1ns

module dac_ad5541a_tb;

    logic        mclk;
    logic        rst;
    logic        en;
    logic        m_axis_valid;
    logic        s_axis_ready;
    logic [15:0] m_axis_data;

    logic sclk;
    logic cs_n;
    logic mosi;
    logic ldac_n;
    logic error;

    // 
    //    Clock Signal
    //
    localparam int CLK_FREQUENCY     = 50_000_000;
    localparam int CLK_CYCLE_NS      = 1_000_000_000 / CLK_FREQUENCY;
    localparam int HALF_CLK_CYCLE_NS = CLK_CYCLE_NS/2;

    initial begin
        forever begin 
            mclk = 0; #HALF_CLK_CYCLE_NS; mclk = 1; #HALF_CLK_CYCLE_NS;
        end
    end

    //
    // Reset Signal  
    //
    initial begin 
        rst = 0;
        #100ns;
        @(posedge mclk) 
        rst = 1;
        #30ns;
        en = 1;
        #40ns;
        rst = 0;
    end

    //
    // Set the total run time of the simulation and name the file that
    // contains the signal data for the waveform viewer
    //
    initial begin
        $dumpfile("dac_ad5541a.vcd");
        $dumpvars;
        #50us; 
        $finish;
    end

    //
    // 
    //
    data_generator gen
    (
        .clk          (mclk),
        .rst          (rst),
        .m_axis_valid (m_axis_valid), 
        .s_axis_ready (s_axis_ready),
        .m_axis_data  (m_axis_data)
    );

    //
    // 
    //
    dac_ad5541a dac_dut
    (
        // GENERAL SIGNALS FOR SYNCHRONOUS DESIGN
        .mclk (mclk),
        .rst  (rst),
        .en   (en),
        // AXI-STREAM SIGNALS
        .s_axis_valid (m_axis_valid),
        .m_axis_ready (s_axis_ready),
        .s_axis_data  (m_axis_data),
        // SPI SIGNALS
        .sclk   (sclk),
        .mosi   (mosi),
        .cs_n   (cs_n),
        .ldac_n (ldac_n),

        .error  (error)
    );


    //
    // 
    //
//    dac_ad5541a_check dac_check
//    (
//        .clk  (clk),
//        .rst  (rst),
//        .cs_n (cs_n),
//        .mosi (mosi),
//        .sclk (sclk)
//    );
endmodule

