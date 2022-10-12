//////////////////////////////////////////////////////////////////////
// This file contains the UART Receiver.  This receiver is able to
// receive 8 bits of serial data, one start bit, one stop bit,
// and no parity bit.  When receive is complete data_ready will be
// driven high for one clock cycle.
// 
// Set Parameter CLKS_PER_BIT as follows:
// CLKS_PER_BIT = (Frequency of clk)/(Frequency of UART)
// Example: 10 MHz Clock, 115200 baud UART
// (10000000)/(115200) = 87
  
module uart_rx 
  #(parameter CLKS_PER_BIT=87)
  (
   input  logic         clk,
   input  logic         rst_n,  
   input  logic         serial_in,
   output logic         data_ready,
   output logic   [7:0] rxdata
   );
    
  enum logic [2:0] {
  
      s_IDLE         = 3'b000,
      s_RX_START_BIT = 3'b001,
      s_VALID_START  = 3'b010,
      s_SAMPLE_COUNT = 3'b011,
      s_LATCH_BIT    = 3'b100,
      s_FULL_BYTE    = 3'b101,
      s_RX_STOP_BIT  = 3'b110,
      s_CLEANUP      = 3'b111
      } state, next;
   
  logic           r_Rx_Data_R = 1'b1;
  logic           r_Rx_Data   = 1'b1;
   
  logic [7:0]     r_Clock_Count = 0;
  logic [2:0]     r_Bit_Count   = 0; //8 bits total
  logic [7:0]     r_Rx_Byte     = 0;
  logic           r_Rx_DV       = 0;
  logic [2:0]     r_SM_Main     = 0;

  logic           clkcntr_rstN;
  logic           bitcntr_rstN;
  logic           shift_en;
   
//  // Purpose: Double-register the incoming data.
//  // This allows it to be used in the UART RX Clock Domain.
//  // (It removes problems caused by metastability)
  always @(posedge clk)
    begin
      r_Rx_Data_R <= serial_in;
      r_Rx_Data   <= r_Rx_Data_R;
    end
   
//  // RX 3-always State machine

  always_ff @(posedge clk or negedge rst_n)
    if(~rst_n) state <= s_IDLE;
    else       state <= next;

  always_comb begin
//    next = XXX;
    case(state)
      s_IDLE:         if (r_Rx_Data == 1'b0)                   next = s_RX_START_BIT;
                      else                                     next = s_IDLE;
      s_RX_START_BIT: if (r_Clock_Count == (CLKS_PER_BIT-1)/2) next = s_VALID_START;
                      else                                     next = s_RX_START_BIT;
      s_VALID_START:  if (r_Rx_Data == 1'b0)                   next = s_SAMPLE_COUNT;
                      else                                     next = s_IDLE;
      s_SAMPLE_COUNT:  if (r_Clock_Count < CLKS_PER_BIT-1)     next = s_SAMPLE_COUNT;
                      else                                     next = s_LATCH_BIT;
      s_LATCH_BIT:    if (r_Bit_Count < 7)                     next = s_SAMPLE_COUNT;
                      else                                     next = s_RX_STOP_BIT;
      s_RX_STOP_BIT:  if (r_Clock_Count < CLKS_PER_BIT-1)      next = s_RX_STOP_BIT;
                      else                                     next = s_IDLE;
   endcase

  end

  always_ff @(posedge clk or negedge rst_n) begin 
    if(~rst_n) begin
       data_ready     <=  0;
       rxdata         <= '0;
       shift_en       <=  0;  
       clkcntr_rstN   <=  0;
       bitcntr_rstN   <=  0;
    end else begin
         data_ready     <=  0;
         shift_en       <=  0;  
         clkcntr_rstN   <=  0;
         bitcntr_rstN   <=  0;

    unique case (next)
        s_IDLE: ;

        s_RX_START_BIT: begin

          clkcntr_rstN   <=  1;
          end 

        s_VALID_START: begin

          bitcntr_rstN   <=  1;

          end

        s_SAMPLE_COUNT: begin

          clkcntr_rstN   <=  1;
          bitcntr_rstN   <=  1;

          end 

        s_LATCH_BIT: begin 

          bitcntr_rstN   <=  1;
          shift_en       <=  1;  

          end

        s_RX_STOP_BIT: begin

          clkcntr_rstN   <=  1;
          data_ready     <=  1;

          end 
      endcase 
      end

    end 
  




  always_ff @(posedge clk or negedge rst_n) begin : proc_data
    if(~rst_n)
      rxdata <= '0;
    else if(shift_en)
      rxdata <= {serial_in, rxdata[7:1]};
  end


  always_ff @(posedge clk) begin : clk_counter
    if(~clkcntr_rstN)
      r_Clock_Count = '0;
    else
      r_Clock_Count <= r_Clock_Count + 1;
  end
   

  always_ff @(posedge clk) begin : bit_counter
    if(~bitcntr_rstN)
      r_Bit_Count = 0;
    else if(shift_en)
      r_Bit_Count <= r_Bit_Count + 1;
  end


   
endmodule // uart_rx