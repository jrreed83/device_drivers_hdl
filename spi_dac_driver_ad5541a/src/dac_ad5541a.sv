module dac_ad5541a
#(
    parameter MCLK_CYCLES_PER_XMIT          = 256,
              MCLK_CYCLES_PER_SPI_CLK_CYCLE = 8
)
(
    input  logic mclk,
    input  logic rst,

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
            if (ready_for_sample == 1'b1) begin 
                next_state = LOAD;
            end
        LOAD:
            next_state = START;
        START:
            next_state = DATA;
        DATA:
            if (all_bits_sent == 1'b1) begin 
                next_state = FINISH;
            end
        FINISH:
            next_state = DONE;
        DONE:
            next_state = IDLE;
        default:
            next_state = curr_state;
    endcase

end



//
//Counter resets at each state transition
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





/*
    
    AXI Stream handshake.  

    Data should only be 'loaded in' when the ready and valid signals are high.  

*/
assign ready_for_sample = (curr_state == IDLE && cnt == MCLK_CYCLES_PER_XMIT-1);

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






/*

    OUTPUT Signals

*/



//
// Chip Select
//
always_ff @(posedge mclk) begin 
    if (rst) begin 
        cs_n <= 1'b1;
    end
    else begin 
        case (curr_state)  
            START: cs_n <= 1'b0;
            DONE:  cs_n <= 1'b1;
        endcase
    end
end

logic cs_n_q;





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
                if (sclk_cnt == MCLK_CYCLES_PER_SPI_CLK_CYCLE) begin
                    sclk_cnt <= 0;
                end 
                else begin 
                    sclk_cnt <= sclk_cnt + 1;
                end
        endcase
    end
end


always_ff @(posedge mclk) begin 
    if (rst) begin 
        sclk <= 1'b1;
    end
    else begin
        if (curr_state == DATA) begin
            if (sclk_cnt == 0) begin 
                sclk <= ~sclk;
            end
        end
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


logic [15:0] bit_cnt;
always_ff @(posedge mclk) begin 
    if (rst) begin 
        bit_cnt <= 0;
    end
    else begin
        case (curr_state)
            IDLE: 
                begin 
                    bit_cnt <= 0;
                end 
            DATA: 
                if (sclk_posedge == 1'b1) begin 
                    bit_cnt <= bit_cnt + 1;
                end
            default:
                bit_cnt <= 0;            
        endcase
    end
end


logic all_bits_sent;
assign all_bits_sent = bit_cnt == 16;


/* 
    Output Serial Data:
    Load the bit on the falling edge of the SPI clock so that it's settled for the rising edge.
*/ 

always_ff @(posedge mclk) begin 
    case (curr_state)
        DATA:
            if (sclk_negedge == 1'b1) begin 
                mosi <= data_in[15-bit_cnt];
            end
        default: mosi <= 0;
    endcase
end


//
//
//
assign ldac_n = 1'b0;

endmodule

