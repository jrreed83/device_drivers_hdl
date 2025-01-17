`timescale 1ns/1ns

module dac_ad5541a_tb;

    logic        mclk;
    logic        rst;
    logic        m_axis_valid;
    logic        s_axis_ready;
    logic [15:0] m_axis_data;

    logic sclk;
    logic cs_n;
    logic mosi;
    logic ldac_n;

    /*
    * Instantiate the IP block.
    */
    dac_ad5541a dac_dut
    (
        // GENERAL SIGNALS FOR SYNCHRONOUS DESIGN
        .mclk (mclk),
        .rst  (rst),
        // AXI-STREAM SIGNALS
        .s_axis_valid (m_axis_valid),
        .m_axis_ready (s_axis_ready),
        .s_axis_data  (m_axis_data),
        // SPI SIGNAKS
        .sclk   (sclk),
        .mosi   (mosi),
        .cs_n   (cs_n),
        .ldac_n (ldac_n)
    );

    /* 
        Clock Signal
    */
    initial begin
        forever begin 
            mclk = 0; #10ns; mclk = 1; #10ns;
        end
    end

    /*
        Reset Signal  
    */
    initial begin 
        rst = 0;
        #100ns;
        @(posedge mclk) 
        rst = 1;
        #30ns;
        rst = 0;
    end

    /* 
        AXI Stream Stuff
    */

    logic [15:0] mem[0:3];
    initial begin 
        mem[0] = 16'hCAFE;
        mem[1] = 16'hBEEF;
        mem[2] = 16'hFACE;
        mem[3] = 16'hC0DE;
    end

    logic [2:0] cnt;

    always_ff @(posedge mclk) begin
        if (rst) begin 
            m_axis_valid <= 1'b1;
            m_axis_data  <= 0;
            cnt <= 0;

        end
        else if (m_axis_valid == 1'b1 && s_axis_ready == 1'b1) begin 
            m_axis_data  <= mem[cnt];
            cnt          <= cnt + 1;
        end
    end
    /*
    * Initial Block for simulation termination and simulation output file
    *
    */
    initial begin
        $dumpfile("dac_ad5541a.vcd");
        $dumpvars;
        #50us; 
        $finish;
    end
endmodule

