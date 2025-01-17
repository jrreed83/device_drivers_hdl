`timescale 1ns/1ns

//
// Good references:
// FPGA For Beginners: Stacey.  
// State machine talk
// https://www.youtube.com/watch?v=JXT-4ghebfI
//
//
// 
//
// mclk:    50MHz
// sclk:    6.25MHz - divide by 8  
// dac_clk: 500KHz  - divide by 100
//
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
    output logic sclk
);


/*
    State machine
*/
typedef enum { IDLE, LOAD, START, DATA, FINISH, DONE } state_e;


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
                if (ready_for_sample == 1'b1) begin 
                    next_state = LOAD;
                end
            end
        LOAD: 
            begin
                next_state = START;
            end
        START: 
            begin 
                next_state = DATA;
            end
        DATA: 
            begin 
                if (sclk_posedge_cnt == 16) begin 
                    next_state = FINISH;
                end
            end
        FINISH:
            begin 
                if (sclk_posedge_cnt == 17) begin 
                    next_state = DONE;
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
logic [15:0] cnt;
always_ff @(posedge mclk) begin 
    if (rst) begin 
        cnt <= 0;
    end
    else begin 
        if (curr_state != next_state) begin 
            cnt <= 0;
        end
        else begin 
            cnt <= cnt + 1;
        end
    end
end



assign ready_for_sample = (curr_state == IDLE && cnt == MCLK_CYCLES_PER_DAC_CLK_CYCLE-1);


/*
    
    AXI Stream handshake.  

    Data should only be 'loaded in' when the ready and valid signals are high.  

*/

assign m_axis_ready = ready_for_sample;


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
// SPI Clock
//
logic [15:0] sclk_cnt;
always_ff @(posedge mclk) begin 
    if (rst) begin 
        sclk_cnt <= 0;
    end
    else begin
        case (curr_state)
            DATA:
                if (sclk_cnt == MCLK_CYCLES_PER_SPI_CLK_CYCLE-1) begin
                    sclk_cnt <= 0;
                end 
                else begin 
                    sclk_cnt <= sclk_cnt + 1;
                end
            FINISH:
                 if (sclk_cnt == MCLK_CYCLES_PER_SPI_CLK_CYCLE-1) begin
                    sclk_cnt <= 0;
                end 
                else begin 
                    sclk_cnt <= sclk_cnt + 1;
                end
            DONE:
                begin
                    sclk_cnt <= 0;
                end
        endcase
    end
end


always_ff @(posedge mclk) begin 
    if (rst) begin 
        sclk <= 1'b1;
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
            DATA: 
                begin
                    if (sclk_cnt == 0) begin 
                        sclk <= ~sclk;
                    end

                    if (sclk_negedge == 1'b1) begin 
                        mosi <= data_in[15-sclk_posedge_cnt];
                    end
                end
            FINISH: 
                begin 
                    if (sclk_cnt == 0) begin 
                        sclk <= ~sclk;
                    end

                    if (sclk_negedge == 1'b1) begin 
                        cs_n <= 1'b1;
                    end
                end
            DONE: 
                begin
                    mosi <= 1'b0;
                    sclk <= 1'b1;
                end
        endcase
    end
end





/*
    Detect the rising and falling edges of the SPI clock signal
*/  
logic sclk_negedge;
logic sclk_posedge;
logic sclk_q;

always_ff @(posedge mclk) begin 
    sclk_q <= sclk;
end 

assign sclk_posedge =  sclk & ~sclk_q;
assign sclk_negedge = ~sclk &  sclk_q;



//
// Serial Data
//


logic [15:0] sclk_posedge_cnt;
always_ff @(posedge mclk) begin 
    if (rst) begin 
        sclk_posedge_cnt <= 0;
    end
    else begin
        case (curr_state)
            IDLE: 
                begin 
                    sclk_posedge_cnt <= 0;
                end 
            DATA:
                begin
                    if (sclk_posedge == 1'b1) begin 
                        sclk_posedge_cnt <= sclk_posedge_cnt + 1;
                    end
                end
            FINISH:
                 begin
                    if (sclk_posedge == 1'b1) begin 
                        sclk_posedge_cnt <= sclk_posedge_cnt + 1;
                    end
                end
            default:
                begin 
                    sclk_posedge_cnt <= 0;
                end
        endcase
    end
end

assign ldac_n = 1'b0;

endmodule

