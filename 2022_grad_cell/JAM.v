// Design: 2022 IC Contest JAM 
// Developer: Angelo Yu
// Date: 2022/07

// Area: 7877.633349
// Total Cycles: 403207


module JAM (
	input CLK,
	input RST,
	output reg [2:0] W,
	output reg [2:0] J,
	input [6:0] Cost,
	output reg [3:0] MatchCount,
	output reg [9:0] MinCost,
	output reg Valid );

	parameter IDLE = 2'b00;
	parameter DICTIONARY_ARR = 2'b01;
	parameter OUTPUT = 2'b10; 
	
	integer i; 
	
	reg [1:0] cstate;
	reg [1:0] nstate;
	reg [15:0] counter_total;	// 0~40320
	reg [3:0] counter_dic;		//0~8
	reg [9:0] total_sum;	// Maximum 200*8 = 1600 
	reg [2:0] J_STORE [7:0];
	reg [2:0] swap_idx;	//index of swap point 
	reg [2:0] cmp_idx; 
	reg [3:0] compare_idx; //maximum = 8
	
	wire [2:0] j_store [7:0]; 
	reg [3:0] MatchCount_nxt; 
	reg [9:0] MinCost_nxt;	
	wire [15:0]	counter_total_nxt;
	wire [9:0] total_sum_nxt; 
	reg [2:0] swap_idx_nxt;
	reg [2:0] cmp_idx_nxt;
	reg [3:0] compare_idx_nxt; 
	
	/////////////////////////////////////////////
	/////////////////// FSM /////////////////////
	/////////////////////////////////////////////
	
	always @(posedge CLK or posedge RST) 
		begin
			if(RST)
				cstate <= IDLE;
			else 
				cstate <= nstate; 
		end
	
	always @(*) 
		begin
			case(cstate)
				IDLE:
					nstate = DICTIONARY_ARR; 
				DICTIONARY_ARR: begin
						if(counter_total == 40319 && counter_dic == 9)
							nstate = OUTPUT; 
						else 
							nstate = DICTIONARY_ARR;
				end
				OUTPUT: 
					nstate = IDLE;
				default: 
					nstate = IDLE; 
			endcase
		end

	// counter_total 
	always @(posedge CLK or posedge RST) 
		begin
			if(RST)
				counter_total <= 0; 
			else if(cstate == DICTIONARY_ARR) begin
				//counter_total <= counter_total_nxt;
				if(counter_dic == 9) begin
					counter_total <= counter_total + 1;
				end else 
					counter_total <= counter_total;
			end
			else 
				counter_total <= 0; 
		end
	//assign counter_total_nxt = (counter_dic == 9) ? counter_total + 1 : counter_total; 
	
	// counter_dic 0~8: arrange and get & sum cost  9: compare
	always @(posedge CLK or posedge RST) 
		begin
			if(RST)
				counter_dic <= 0 ;
			else if(cstate == DICTIONARY_ARR && counter_dic != 9) 
					counter_dic <= counter_dic + 1; 
			else 
				counter_dic <= 0;
		end
	//assign counter_dic_nxt = (counter_dic == 9) ? 0 : counter_dic + 1; 
	
	// W, J
	always @(posedge CLK or posedge RST) 
		begin
			if(RST) begin
				W <= 0;
				J <= j_store[0];
			end
			else if(counter_dic == 0) begin
				W <= 1; 
				J <= j_store[1];
			end
			else if(counter_dic == 1) begin
				W <= 2; 
				J <= j_store[2];
			end
			else if(counter_dic == 2) begin
				W <= 3; 
				J <= j_store[3];
			end
			else if(counter_dic == 3) begin
				W <= 4; 
				J <= j_store[4];
			end
			else if(counter_dic == 4) begin
				W <= 5; 
				J <= j_store[5];
			end
			else if(counter_dic == 5) begin
				W <= 6; 
				J <= j_store[6];
			end
			else if(counter_dic == 6) begin
				W <= 7; 
				J <= j_store[7];
			end
			else begin 
				W <= 0; 
				J <= j_store[0];
			end
		end
		
	//total_sum
	always @(posedge CLK or posedge RST) 
		begin
			if (RST) 
				total_sum <= 0; 
			else if(counter_dic == 9) //reset`
				total_sum <= 0;
			else if(counter_dic > 0 && counter_dic < 9)
				total_sum <= total_sum_nxt;
			else  //counter_dic = 9 => the true total will ready
				total_sum <= 0;
	end
	
	assign total_sum_nxt = total_sum + Cost; 
	
	// MinCost, MatchCount
	always @(posedge CLK or posedge RST) 
		begin
			if(RST) begin 
				MinCost <= 0;
				MatchCount <= 1; 
			end
			else begin 
				MinCost <= MinCost_nxt;
				MatchCount <= MatchCount_nxt; 
			end
		end
	
	always @(*) //MinCost
		begin
			if(counter_total == 0 && counter_dic == 9) begin
				MinCost_nxt = total_sum;
				MatchCount_nxt = 1;				
			end
			else if (counter_dic == 9) begin
				if (MinCost > total_sum) begin //MinCost change and MatchCount reset 
					MinCost_nxt = total_sum; 
					MatchCount_nxt = 1;
				end
				else if (MinCost == total_sum) begin
					MinCost_nxt = MinCost;
					MatchCount_nxt = MatchCount + 1;
				end
				else begin 
					MinCost_nxt = MinCost;
					MatchCount_nxt = MatchCount;
				end
			end
			else begin
				MinCost_nxt = MinCost; //RESET
				MatchCount_nxt = MatchCount;
			end
		end	

	assign j_store[0] = J_STORE[0]; 
	assign j_store[1] = J_STORE[1];
	assign j_store[2] = J_STORE[2];
	assign j_store[3] = J_STORE[3];
	assign j_store[4] = J_STORE[4];
	assign j_store[5] = J_STORE[5];
	assign j_store[6] = J_STORE[6];
	assign j_store[7] = J_STORE[7];
	
	//J_STORE
	always @(posedge CLK or posedge RST) 
		begin
			if(RST) begin
				J_STORE[0] <= 0;
				J_STORE[1] <= 1;
				J_STORE[2] <= 2;
				J_STORE[3] <= 3;
				J_STORE[4] <= 4;
				J_STORE[5] <= 5;
				J_STORE[6] <= 6;
				J_STORE[7] <= 7;
			end
			else if(cstate == IDLE) begin
				for (i=0; i<8; i=i+1) begin
					J_STORE[i] <= i; //LOAD the FIRST set of DATA
				end
			end
			else if(counter_dic == 8) begin
				J_STORE[swap_idx] <= j_store[cmp_idx];
				J_STORE[cmp_idx] <= j_store[swap_idx];
				
			end
			else if (counter_dic == 9) begin
				case(swap_idx)
					0: begin
						J_STORE[0] <= j_store[0];
						J_STORE[1] <= j_store[7];
						J_STORE[2] <= j_store[6];
						J_STORE[3] <= j_store[5];
						J_STORE[4] <= j_store[4];
						J_STORE[5] <= j_store[3];
						J_STORE[6] <= j_store[2];
						J_STORE[7] <= j_store[1];
					end
					1: begin
						J_STORE[0] <= j_store[0];
						J_STORE[1] <= j_store[1];
						J_STORE[2] <= j_store[7];
						J_STORE[3] <= j_store[6];
						J_STORE[4] <= j_store[5];
						J_STORE[5] <= j_store[4];
						J_STORE[6] <= j_store[3];
						J_STORE[7] <= j_store[2];
					end
					2: begin
						J_STORE[0] <= j_store[0];
						J_STORE[1] <= j_store[1];
						J_STORE[2] <= j_store[2];
						J_STORE[3] <= j_store[7];
						J_STORE[4] <= j_store[6];
						J_STORE[5] <= j_store[5];
						J_STORE[6] <= j_store[4];
						J_STORE[7] <= j_store[3];
					end
					3: begin
						J_STORE[0] <= j_store[0];
						J_STORE[1] <= j_store[1];
						J_STORE[2] <= j_store[2];
						J_STORE[3] <= j_store[3];
						J_STORE[4] <= j_store[7];
						J_STORE[5] <= j_store[6];
						J_STORE[6] <= j_store[5];
						J_STORE[7] <= j_store[4];
					end
					4: begin
						J_STORE[0] <= j_store[0];
						J_STORE[1] <= j_store[1];
						J_STORE[2] <= j_store[2];
						J_STORE[3] <= j_store[3];
						J_STORE[4] <= j_store[4];
						J_STORE[5] <= j_store[7];
						J_STORE[6] <= j_store[6];
						J_STORE[7] <= j_store[5];
					end
					5: begin
						J_STORE[0] <= j_store[0];
						J_STORE[1] <= j_store[1];
						J_STORE[2] <= j_store[2];
						J_STORE[3] <= j_store[3];
						J_STORE[4] <= j_store[4];
						J_STORE[5] <= j_store[5];
						J_STORE[6] <= j_store[7];
						J_STORE[7] <= j_store[6];
					end
					6: begin
						J_STORE[0] <= j_store[0];
						J_STORE[1] <= j_store[1];
						J_STORE[2] <= j_store[2];
						J_STORE[3] <= j_store[3];
						J_STORE[4] <= j_store[4];
						J_STORE[5] <= j_store[5];
						J_STORE[6] <= j_store[6];
						J_STORE[7] <= j_store[7];
					end
					default: begin
						J_STORE[0] <= j_store[0];
						J_STORE[1] <= j_store[1];
						J_STORE[2] <= j_store[2];
						J_STORE[3] <= j_store[3];
						J_STORE[4] <= j_store[4];
						J_STORE[5] <= j_store[5];
						J_STORE[6] <= j_store[6];
						J_STORE[7] <= j_store[7];
					end
				endcase
			end
			else begin
				for (i=0; i<8; i=i+1) begin
					J_STORE[i] <= j_store[i];
				end
			end
		end
	
	////////////////////////////////////////////
	///////// Dictionary Sort Algorithm //////// 
	////////////////////////////////////////////
	
	// 1 Find Swap Index
	always @(posedge CLK or posedge RST) 
		begin
			if(RST) 
				swap_idx <= 0;  
			else 
				swap_idx <= swap_idx_nxt;
		end
		
	always @(*)
		begin
			if(counter_dic == 0) begin  // ???????????? CONDITION HAVEN"T DECIDED ????????????????????
				if(J_STORE[7] > J_STORE[6])
					swap_idx_nxt = 6;
				else if(J_STORE[6] > J_STORE[5])
					swap_idx_nxt = 5;
				else if(J_STORE[5] > J_STORE[4])
					swap_idx_nxt = 4;
				else if(J_STORE[4] > J_STORE[3])
					swap_idx_nxt = 3;
				else if(J_STORE[3] > J_STORE[2])
					swap_idx_nxt = 2;
				else if(J_STORE[2] > J_STORE[1])
					swap_idx_nxt = 1;
				else if(J_STORE[1] > J_STORE[0])
					swap_idx_nxt = 0;
				else
					swap_idx_nxt = swap_idx; 
			end
			else 
				swap_idx_nxt = swap_idx; //Next set of J, reset swap index 
		end
	//2 find the smallest number which is larger than swap number
	always @(posedge CLK or posedge RST)  
		begin
			if(RST) begin
				cmp_idx <= 0; 
				compare_idx <= 0;
			end
			else begin 
				cmp_idx <= cmp_idx_nxt; 
				compare_idx <= compare_idx_nxt;
			end
		end
	
	always @(*) begin
			if (counter_dic == 0) begin
				cmp_idx_nxt = swap_idx_nxt + 1;
				compare_idx_nxt = swap_idx_nxt + 2;
			end
			else if(counter_dic < 9 && compare_idx < 8) begin //compare_idx < 8 is the terminate condition
				cmp_idx_nxt = ( (j_store[compare_idx] > j_store[swap_idx]) && (j_store[compare_idx] < j_store[cmp_idx]) ) ? compare_idx : cmp_idx;
				compare_idx_nxt = compare_idx + 1; 
			end
			else begin 
				cmp_idx_nxt = cmp_idx; 
				compare_idx_nxt = compare_idx;
			end				
	end
	
	always @(posedge CLK or posedge RST) 
		begin
			if(RST)
				Valid <= 0;
			else if(cstate == OUTPUT)
				Valid <= 1; 
			else 
				Valid <= 0;
		end
endmodule
