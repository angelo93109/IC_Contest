module CONV(
	input 	clk, 
	input 	reset, 
	output reg busy,
	input 	ready, 
	// for access picture pixels
	output 	[11:0] iaddr, 
	input	[19:0] idata,
	// for write in memory
	output 	reg cwr,
	output 	reg [11:0] caddr_wr,
	output 	reg [19:0] cdata_wr,
	// for read memory
	output 	reg crd,
	output 	reg [11:0] caddr_rd,
	input 	[19:0] cdata_rd, 
	// for select which memory
	output reg [2:0] csel
	);

integer i;

enum reg [3:0] {IDLE, LOAD_CONV_0, STORE_M0, LOAD_CONV_1, STORE_M1, //CONV
				MAX_POOLING_LOAD_0, MAX_POOLING_STORE_0, MAX_POOLING_LOAD_1, MAX_POOLING_STORE_1, // MAXPOOLING
				FLATTEN_LOAD_0, FLATTEN_LOAD_1, FLATTEN_STORE_0, FLATTEN_STORE_1} cstate, nstate; //FLATTENING

////// Reg & Wire //////
// Convolution
reg signed [19:0] kernel [8:0];
reg signed [19:0] kernel_mult_wire;
reg signed [19:0] bias; 
reg signed [38:0] bias_39;
	
reg [3:0] window_counter; 
reg [11:0] center_counter; 
reg signed [12:0] center_addr, index_square_move; // 1 sign + 12 index
 

reg signed [19:0] image;  // 1s + 3 int + 16 frac = 20 bits
wire signed [38:0] conv_mult_intermediate; // 1s + 6 int + 16*2 frac = 39 bits
wire signed [38:0] conv_result_1; // 1s + 6 int + 16*2 frac = 39 bits
reg signed [39:0] conv_result; // 1s + 6+1 int + 16*2 frac = 40 bits
wire signed [19:0] conv_result_temp;
wire signed [19:0] conv_result_relu;

// MAXPOOLING 
reg [9:0] max_pooling_addr_counter; 
reg signed [19:0] max_temp; 

// FLATTENING
reg mem_rd_delay; 

////////////// FSM ////////////////
always_ff @(posedge clk or posedge reset)
	if(reset)
		cstate <= IDLE; 
	else 
		cstate <= nstate; 

always_comb begin
	case(cstate)  
		IDLE: 
			nstate = (busy) ? LOAD_CONV_0 : IDLE;
		LOAD_CONV_0: 
			nstate = (window_counter == 9) ? STORE_M0 : LOAD_CONV_0; 
		STORE_M0:
			nstate = LOAD_CONV_1;
		LOAD_CONV_1: 
			nstate = (window_counter == 9) ? STORE_M1 : LOAD_CONV_1; 
		STORE_M1:  
			nstate = (center_counter == 4095) ?  MAX_POOLING_LOAD_0 : LOAD_CONV_0;
		MAX_POOLING_LOAD_0:
			nstate = (window_counter == 4) ? MAX_POOLING_STORE_0 : MAX_POOLING_LOAD_0; 
		MAX_POOLING_STORE_0: 
			nstate = MAX_POOLING_LOAD_1; 
		MAX_POOLING_LOAD_1:
			nstate = (window_counter == 4) ? MAX_POOLING_STORE_1 : MAX_POOLING_LOAD_1; 
		MAX_POOLING_STORE_1: 
			nstate = (max_pooling_addr_counter == 1023) ?  FLATTEN_LOAD_0 : MAX_POOLING_LOAD_0;
		FLATTEN_LOAD_0:
			nstate = mem_rd_delay ? FLATTEN_STORE_0 : FLATTEN_LOAD_0; 
		FLATTEN_STORE_0:
			nstate =  FLATTEN_LOAD_1;
		FLATTEN_LOAD_1:
			nstate = mem_rd_delay ? FLATTEN_STORE_1 : FLATTEN_LOAD_1; 
		FLATTEN_STORE_1:
			nstate = (center_counter == 2047) ? IDLE : FLATTEN_LOAD_0;
		default: 
			nstate = IDLE; 
	endcase
end

////////////// KERNEL /////////////
always @(*) begin
	case(cstate)
		LOAD_CONV_0: 
			begin
				kernel[0] = 20'h0A89E;
				kernel[1] = 20'h092D5;
				kernel[2] = 20'h06D43;
				kernel[3] = 20'h01004;
				kernel[4] = 20'hF8F71;
				kernel[5] = 20'hF6E54;
				kernel[6] = 20'hFA6D7;
				kernel[7] = 20'hFC834;
				kernel[8] = 20'hFAC19;
				bias = 20'h01310;
			end 
		LOAD_CONV_1:
			begin
				kernel[0] = 20'hFDB55;
				kernel[1] = 20'h02992;
				kernel[2] = 20'hFC994;
				kernel[3] = 20'h050FD;
				kernel[4] = 20'h02F20;
				kernel[5] = 20'h0202D;
				kernel[6] = 20'h03BD7;
				kernel[7] = 20'hFD369;
				kernel[8] = 20'h05E68;
				bias = 20'hF7295;
			end
		default
			begin
				for (i=0; i<=8; i++)
					kernel[i] = 0;
				bias = 0;
			end
	endcase
	bias_39 = {{4{bias[19]}}, bias[18:0], 16'b0};
end

always @(posedge clk or posedge reset) begin
	if(reset)
		busy <= 0; 
	else if(ready)
		busy <= 1;
	else if (nstate == IDLE)
		busy <= 0; 
end

always @(posedge clk or posedge reset) begin
	if(reset) begin 
		center_counter <= 0; 
	end else if (cstate == STORE_M1) begin
		if(center_counter == 4095)
			center_counter <= 0; // reset counter after Layer 0 finished
		else
			center_counter <= center_counter + 1;
	end else if (cstate == MAX_POOLING_STORE_1) begin
		if(center_counter == 4030)
			center_counter <= 0;
		else if (center_counter[5:0] == 6'b111110) // 62, 126, 254, ...
			center_counter <= center_counter + 66; // skip the next line to the second line below.
		else
			center_counter <= center_counter + 2;
	end else if (cstate == FLATTEN_STORE_0 | cstate == FLATTEN_STORE_1) begin //addr for storing flattening data into memory 
		center_counter <= center_counter + 1;
	end
end

always @(posedge clk or posedge reset) begin
	if(reset)
		max_pooling_addr_counter <= 0;
	else if (cstate == MAX_POOLING_STORE_1)
		max_pooling_addr_counter <= max_pooling_addr_counter + 1; 
	else if (cstate == FLATTEN_STORE_1) // addr for reading maxpooling result from memory in flattening stage 
		max_pooling_addr_counter <= max_pooling_addr_counter + 1; 
end

always @(posedge clk or posedge reset) begin
	if(reset) begin 
		window_counter <= 0; 
	end else if (cstate == LOAD_CONV_0 | cstate == LOAD_CONV_1 | cstate == MAX_POOLING_LOAD_0 | cstate == MAX_POOLING_LOAD_1) begin
		window_counter <= window_counter + 1;
	end else if (cstate == STORE_M0 | cstate == STORE_M1 | cstate == MAX_POOLING_STORE_0 | cstate == MAX_POOLING_STORE_1) begin
		window_counter <= 0;
	end
end

always @(*) begin
	case (cstate)
		LOAD_CONV_0, LOAD_CONV_1:
			case(window_counter)
				0:	index_square_move = -65;
				1:	index_square_move = -64;
				2:	index_square_move = -63;
				3:	index_square_move = -1;
				4:	index_square_move = 0;	
				5:	index_square_move = 1;
				6:	index_square_move = 63;
				7:	index_square_move = 64;
				8:	index_square_move = 65;
				default: index_square_move = 0; 
			endcase
		MAX_POOLING_LOAD_0, MAX_POOLING_LOAD_1: 
			case(window_counter)
				0:	index_square_move = 0;	
				1:	index_square_move = 1;	
				2:	index_square_move = 64;
				3:	index_square_move = 65;
				default: index_square_move = 0;
			endcase
		default: 
			index_square_move = 0;
	endcase
end

assign center_addr = {1'b0, center_counter};
assign iaddr = center_addr + index_square_move; 
assign kernel_mult_wire = (window_counter < 9) ? kernel[window_counter] : 0 ;
assign conv_mult_intermediate = image * kernel_mult_wire; 

always @(*) begin
	// Zero Padding
	case (center_counter)
		0: 
			case(window_counter)
				0, 1, 2, 3, 6: 
					image = 0;
				default:
					image = idata; 
			endcase
		63:
			case(window_counter)
				0, 1, 2, 5, 8: 
					image = 0;
				default:
					image = idata; 
			endcase
		4032: 
			case(window_counter)
				0, 3, 6, 7, 8: 
					image = 0;
				default:
					image = idata; 
			endcase
		4095: 
			case(window_counter)
				2, 5, 6, 7, 8: 
					image = 0;
				default:
					image = idata; 
			endcase
		default:
			if(center_counter[11:6] == 6'b0) // top row 1, 2, ..., 62
				case(window_counter)
					0, 1, 2: 
						image = 0;
					default:
						image = idata; 
				endcase
			else if(center_counter[5:0] == 6'b0) // leftmost column 64, 128, ..., 3968
				case(window_counter)
					0, 3, 6: 
						image = 0;
					default:
						image = idata; 
				endcase
			else if(center_counter[5:0] == 6'b111111) // rightmost column 127, 191, ..., 4031
				case(window_counter)
					2, 5, 8: 
						image = 0;
					default:
						image = idata; 
				endcase
			else if(center_counter[11:6] == 6'b111111) // bottom column 4034, 4035 ... ,4094
				case(window_counter)
					6, 7, 8: 
						image = 0;
					default:
						image = idata; 
				endcase
			else
				image = idata;
	endcase
end

assign conv_result_1 = {conv_result[39], conv_result[37:0]};

always @(posedge clk or posedge reset) begin
	if (reset) begin
		conv_result <= 0;
	end else if (cstate == LOAD_CONV_0 || cstate == LOAD_CONV_1) begin
		if(window_counter == 9)
			conv_result <= conv_result_1 + bias_39; // 40 bits = 39 bits + 39 bits; 
		else
			conv_result <= conv_result_1 + conv_mult_intermediate; // 40 bits = 39 bits + 39 bits; 
	end else if (cstate == STORE_M0 || cstate == STORE_M1) begin
		conv_result <= 0;
	end
end

assign conv_result_temp = {conv_result[15] == 1} ? {conv_result[35:16] + 1} : {conv_result[35:16]};
assign conv_result_relu = {conv_result_temp[19] == 1} ? 0 : conv_result_temp;

always @(posedge clk or posedge reset) begin
	if(reset) begin
		max_temp <= 0; 
	end else if (cstate == MAX_POOLING_STORE_0 | cstate == MAX_POOLING_STORE_1) begin
		max_temp <= 0;
	end else if (cstate == MAX_POOLING_LOAD_0 | cstate == MAX_POOLING_LOAD_1) begin 
		if(cdata_rd > max_temp) begin
			max_temp <= cdata_rd;
		end
	end else if(cstate == FLATTEN_LOAD_0 | cstate == FLATTEN_LOAD_1) begin
		max_temp <= cdata_rd; 
	end 
end

always @(posedge clk or posedge reset) begin
	if (reset)
		mem_rd_delay <= 0;
	else if(cstate == FLATTEN_LOAD_0 | cstate == FLATTEN_LOAD_1)
		mem_rd_delay <= 1;
	else if(cstate == FLATTEN_STORE_0 | cstate == FLATTEN_STORE_1)
		mem_rd_delay <= 0;
end

always @(*) begin
	case (cstate) 
		STORE_M0: 
			begin
				csel = 3'b001; 
				cwr = 1;
				caddr_wr = center_counter;
				cdata_wr = conv_result_relu; 
				crd = 0;
				caddr_rd = 12'b0; 
			end
		STORE_M1: 
			begin
				csel = 3'b010; 
				cwr = 1;
				caddr_wr = center_counter;
				cdata_wr = conv_result_relu; 
				crd = 0;
				caddr_rd = 12'b0; 
			end
		MAX_POOLING_LOAD_0:
			begin
				csel = 3'b001; 
				cwr = 0;
				caddr_wr = 12'b0;
				cdata_wr = 20'b0; 
				crd = 1;
				caddr_rd = iaddr; 
			end
		MAX_POOLING_STORE_0:
			begin
				csel = 3'b011; 
				cwr = 1;
				caddr_wr = max_pooling_addr_counter;
				cdata_wr = max_temp; 
				crd = 0;
				caddr_rd = 12'b0; 
			end
		MAX_POOLING_LOAD_1:
			begin
				csel = 3'b010; 
				cwr = 0;
				caddr_wr = 12'b0;
				cdata_wr = 20'b0;
				crd = 1;
				caddr_rd = iaddr; 
			end
		MAX_POOLING_STORE_1:
			begin
				csel = 3'b100; 
				cwr = 1;
				caddr_wr = max_pooling_addr_counter;
				cdata_wr = max_temp;
				crd = 0;
				caddr_rd = 12'b0; 
			end
		FLATTEN_LOAD_0:
			begin
				csel = 3'b011; 
				cwr = 0;
				caddr_wr = 12'b0;
				cdata_wr = 20'b0;
				crd = 1;
				caddr_rd = max_pooling_addr_counter; 
			end
		FLATTEN_LOAD_1:
			begin
				csel = 3'b100;
				cwr = 0;
				caddr_wr = 12'b0;
				cdata_wr = 20'b0;
				crd = 1;
				caddr_rd = max_pooling_addr_counter; 
			end
		FLATTEN_STORE_0, FLATTEN_STORE_1: 
			begin
				csel = 3'b101; 
				cwr = 1;
				caddr_wr = center_counter;
				cdata_wr = max_temp;
				crd = 0;
				caddr_rd = 12'b0; 
			end
		default:
			begin 
				csel = 3'b000; 
				cwr = 0;
				caddr_wr = 12'b0;
				cdata_wr = 20'b0; 
				crd = 0;
				caddr_rd = 12'b0; 
			end
	endcase
end

endmodule
	
	
