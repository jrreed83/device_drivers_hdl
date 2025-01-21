module data_generator
(
    input logic clk,
    input logic rst,

    output logic        m_axis_valid,
    input  logic        s_axis_ready,
    output logic [15:0] m_axis_data
);

    logic [ 3:0] sample_cnt;
    logic [15:0] memory[0:3];

    always_ff @(posedge clk) begin 
        if (rst) begin 
            sample_cnt <= 0;

            memory[0] <= 16'hCAFE;
            memory[1] <= 16'hC0DE;
            memory[2] <= 16'hBEEF;
            memory[3] <= 16'hB0BA;

            m_axis_data <= 0;
        end
        else begin 
            if (m_axis_valid == 1'b1 && s_axis_ready == 1'b1) begin 
                m_axis_data  <= memory[sample_cnt]; 

                if (sample_cnt == 3) begin
                    sample_cnt <= 0;
                end
                else begin 
                    sample_cnt <= sample_cnt + 1;
                end
            end
        end
    end

    assign m_axis_valid = 1'b1;
endmodule
