`timescale 1ns/1ns

// mclk:    50MHz
// sclk:    6.25MHz - divide by 8  
// dac_clk: 500KHz  - divide by 100
//
//

`define sequential_output 

module dac_ad5541a
#(
    parameter MCLK_CYCLES_PER_DAC_CLK_CYCLE = 100,
              MCLK_CYCLES_PER_SPI_CLK_CYCLE = 8
)
(
    input logic mclk,
    input logic rst,
    input logic en,
    // AXI-STREAM SIGNALS
    input  logic        s_axis_valid,
    output logic        m_axis_ready,
    input  logic [15:0] s_axis_data,
    // SPI SIGNALS
    output logic cs_n,
    output logic ldac_n,
    output logic mosi,
    output logic sclk,

    output logic error
);


    /*
        State machine
    */
    typedef enum logic[2:0] { IDLE, LOAD, START, XMIT, FINISH, DONE } state_e;


    state_e curr_state;
    state_e next_state;

    always_ff @(posedge mclk) begin 
        if (rst) begin 
            curr_state <= IDLE;
        end
        else begin 
            curr_state <= next_state; 
        end
    end





    always_comb begin
        next_state = curr_state;
        case (curr_state)
            IDLE: 
                begin
                    if (en == 1'b1) begin 
                        if (state_cnt == MCLK_CYCLES_PER_DAC_CLK_CYCLE-1) begin 
                            next_state = LOAD;
                        end
                    end  
                    else begin 
                        next_state = IDLE;
                    end
                end
            LOAD: 
                begin
                    if (en == 1'b1) begin 
                        next_state = START;
                    end
                    else begin 
                        next_state = IDLE;
                    end
                end
            START: 
                begin 
                    if (en == 1'b1) begin 
                        next_state = XMIT;
                    end
                    else begin 
                        next_state = IDLE;
                    end
                end
            XMIT: 
                begin 
                    if (en == 1'b1) begin 
                        if (sclk_posedge_cnt == 16) begin 
                            next_state = FINISH;
                        end
                    end
                    else begin 
                        next_state = IDLE;
                    end
                end
            FINISH:
                begin 
                    if (sclk_posedge_cnt == 17) begin 
                        next_state = DONE;
                    end
                    else begin 
                        next_state = IDLE;
                    end
                end 
            DONE: 
                begin 
                    next_state = IDLE;
                end
            default:
                begin

                    next_state = curr_state;
                end  
        endcase

    end



    //
    // Counter resets at each state transition
    //
    logic [15:0] state_cnt;
    always_ff @(posedge mclk) begin 
        if (rst) begin 
            state_cnt <= 0;
        end
        else begin 
            if (curr_state != next_state) begin 
                state_cnt <= 0;
            end
            else begin 
                state_cnt <= state_cnt + 1;
            end
        end
    end



    //
    //
    //    AXI Stream handshake.  
    //
    //    Data should only be 'loaded in' when the ready and valid signals are high. 
    //    
    //
    //

    
    assign m_axis_ready = curr_state == IDLE && next_state == LOAD;


    logic [15:0] data_in;

    always_ff @(posedge mclk) begin
        if (rst) begin 
            data_in <= 0;
        end
        else begin 
            if (s_axis_valid == 1'b1 && m_axis_ready == 1'b1) begin 
                data_in <= s_axis_data;
            end
        end
    end

    // 
    // Error occurs when the DAC is prepared to transmit, but there's no valid data to transmit.
    //
    assign error = ~s_axis_valid & m_axis_ready;

    //
    // Registered Outputs
    //
    always_ff @(posedge mclk) begin
        if (rst) begin 
            cs_n   <= 1'b1;
            sclk   <= 1'b1;
            mosi   <= 1'b0;
            ldac_n <= 1'b0;
        end
        else begin 
            case (curr_state)
                IDLE:
                    begin
                        cs_n <= 1'b1;
                        sclk <= 1'b1;
                        mosi <= 1'b0;
                    end
        
                START:
                    begin
                        cs_n <= 1'b0;
                    end
        
                XMIT:
                    //
                    // Toggle the clock and load the data on falling edge of the clock
                    //
                    begin
                        if (sclk_negedge == 1) begin
                            sclk <= 0;
                            mosi <= data_in[15-sclk_posedge_cnt];
                        end
                        else if (sclk_posedge == 1) begin
                            sclk <= 1;
                        end
                    end
        
                FINISH:
                    //
                    // Last cycle, data bin and chip select should go back to initial values
                    //
                    begin
                        if (sclk_negedge == 1) begin 
                            sclk <= 1'b0;
                            cs_n <= 1'b1;
                            mosi <= 1'b0;
                        end
                        else if (sclk_posedge == 1) begin 
                            sclk <= 1;
                        end
                    end
  
            endcase
        end
    end



    logic [15:0] sclk_posedge_cnt;
    logic [15:0] sclk_cnt;
    always_ff @(posedge mclk) begin 
        if (rst) begin 
            sclk_cnt         <= 0;
            sclk_posedge_cnt <= 0;
        end
        else begin
            if (curr_state == XMIT || curr_state == FINISH) begin 
                if (sclk_cnt == MCLK_CYCLES_PER_SPI_CLK_CYCLE-1) begin
                    sclk_cnt <= 0;
                end
                else begin 
                    sclk_cnt <= sclk_cnt + 1;
                end


                if (sclk_posedge == 1'b1) begin 
                    sclk_posedge_cnt <= sclk_posedge_cnt + 1;
                end
            end
            else if (curr_state == IDLE) begin 
                sclk_cnt         <= 0;
                sclk_posedge_cnt <= 0;
            end
        end
    end



    
    logic sclk_posedge;
    logic sclk_negedge;

    assign sclk_posedge = sclk_cnt == MCLK_CYCLES_PER_SPI_CLK_CYCLE/2;
    assign sclk_negedge = sclk_cnt == 0;



endmodule

