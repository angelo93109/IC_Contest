module SME (clk, reset, chardata, isstring, ispattern, valid, match, match_index); 
	input clk;
	input reset;
	input [7:0] chardata;
	input isstring;
	input ispattern; 
	output reg valid; 
	output match;
	output reg [4:0] match_index; 

	logic [3:0] cstate;
	logic [3:0] nstate; 
	
	parameter IDLE = 4'd0;
	parameter LOAD_STRING = 4'd1;
	parameter LOAD_PATTERN = 4'd2;
	parameter CLASSIFY = 4'd3;
	parameter NORMAL = 4'd4;
	parameter HAT = 4'd5;
	parameter STAR = 4'd6;
	parameter DOLLAR = 4'd7; 
	parameter MATCH = 4'd8;
	parameter UNMATCH = 4'd9;
	parameter MOVE = 4'd10;
	parameter RESULT = 4'd11; 
	
	logic [7:0] input_string [31:0]; //32*8bits words
	logic [4:0] string_len;  //string length
	logic [4:0] string_counter;  //string length
	logic [7:0] input_pattern [9:0]; //8*8bits words + two special signs
	logic [3:0] pattern_len; //pattern length
	logic [3:0] pattern_counter; //pattern length
	logic [4:0] pattern_min_len;
	logic [4:0] left_string;
	logic [4:0] front_star_left_string;
	logic [2:0] special_sign_count; //count special signs number
	
	logic [4:0] string_pointer;	//point to the word which is under matching
	logic [3:0] pattern_pointer; 	//point to the pattern which is under matching
	logic [4:0] front_star_match_index; 
	
	logic [7:0] compare_string;
	logic [7:0] compare_pattern;
	logic [7:0] compare_next_pattern;
	
	logic front_star_flag;
	logic normal_flag; 
	logic hat_flag; 
	logic [3:0] hat_pass_counter; 
	logic star_flag; 
	// logic dollar_flag; 
	logic match_flag;
	logic isstring_r;
	logic ispattern_r;
	
	
	int i, j; //remember use integer instead of int
	
	//State Register
	always_ff @(posedge clk or posedge reset) begin
		if (reset)
			cstate <= IDLE;
		else
			cstate <= nstate;
	end
	
	assign compare_string = input_string[string_pointer];
	assign compare_pattern = input_pattern[pattern_pointer];
	assign compare_next_pattern = input_pattern[pattern_pointer+1]; //for hat and star
	
	assign left_string = string_len - string_pointer;
	assign front_star_left_string = string_len - front_star_match_index;
	
	assign front_star_flag = (input_pattern[0] == 'h2A) ? 1 : 0;
	
	assign pattern_min_len = pattern_counter - special_sign_count;
	
	
	//State Logic
	always_comb begin
		case (cstate)
			IDLE: 
				nstate = (isstring)? LOAD_STRING : cstate; 
			
			LOAD_STRING: 
				nstate = (ispattern)? LOAD_PATTERN : cstate;
			
			LOAD_PATTERN: 
				nstate = (!ispattern)? CLASSIFY : cstate;
			
			CLASSIFY: // pattern_pointer++, string_pointer++ (include front star case: match pointer won't keep add up)
			begin
				if(compare_pattern == 94) //hat
					nstate = HAT;
				else if(compare_pattern == 42) //star
					nstate = STAR; 
				else if(compare_pattern == 'h24) //dollar
					nstate = DOLLAR;
				else if( star_flag & (compare_next_pattern == 'h24))
					nstate = DOLLAR; 
				else 
					nstate = NORMAL; 
			end
			
			NORMAL: 
			begin
				if(star_flag && compare_next_pattern == compare_string)
					nstate = MATCH;
				else if(compare_pattern == compare_string || compare_pattern == 46)
					nstate = MATCH; 
				else
					nstate = UNMATCH; 
			end
			
			HAT: //pattern_pointer+1, string_pointer++
			begin
				//either the first letter of the string or behind a space
				if((string_pointer == 0) || (input_string[string_pointer-1] == 32)) begin
					if(compare_string == compare_next_pattern || compare_next_pattern == 'h2e)
						nstate = MATCH; 
					else
						nstate = UNMATCH;
				end else
					nstate = UNMATCH; 
			end
			
			STAR: //pattern_pointer+1, string_pointer++
			begin
				if( (compare_pattern == 'h2a) && (pattern_pointer == pattern_len) ) //star at the end
					nstate = RESULT; //pass!
				else if(compare_string == compare_next_pattern) //star in the middle
					nstate = MATCH;
				else 
					nstate = UNMATCH;
			end
			
			DOLLAR: //string_pointer+1
			begin
				if(compare_string == 32 || (string_pointer == string_len + 1)) //Last letter or follow by a space 
					nstate = MATCH; //pass
				else
					nstate = UNMATCH;
			end
			
			MATCH:
			begin
				if(star_flag & (pattern_pointer + 1 == pattern_len))
					nstate = RESULT; 
				else if(pattern_pointer == pattern_counter-1)
					nstate = RESULT;
				else
					nstate = MOVE; 
			end
			
			UNMATCH: 
			begin
				if(front_star_flag) begin
					if(pattern_min_len > front_star_left_string)
						nstate = RESULT;
					else 
						nstate = MOVE; 
				end 					
				else if(pattern_min_len > left_string)
					nstate = RESULT;
				else
					nstate = MOVE;
			end
			
			MOVE: 
				nstate = CLASSIFY; 	
			
			RESULT: 
			begin
				if(isstring) 
					nstate = LOAD_STRING;
				else if(ispattern)
					nstate = LOAD_PATTERN;
				else
					nstate = cstate; 
			end
			
			default:
				nstate = cstate;
		endcase
	end
	
	
	
	/////// Store Input //////////////////
	always_ff @(posedge clk or posedge reset) begin
		if(reset) 
			string_counter <= 0;
		else if(nstate == RESULT)
			string_counter <= 0;
		else if(isstring)
			string_counter <= string_counter + 1;
	end
	
	always_ff @(posedge clk or posedge reset) begin
		if(reset) 
			pattern_counter <= 0;
		else if(nstate == RESULT) 
			pattern_counter <= 0;
		else if(nstate == LOAD_PATTERN)
			pattern_counter <= pattern_counter + 1;
	end
	
	always_ff @(posedge clk or posedge reset) begin
		if(reset) begin
			for (i=0; i < 32; i=i+1) 
				input_string[i] <= 0;
		end else if(nstate == LOAD_STRING) 
			input_string[string_counter] <= chardata;			
	end
	
	always_ff @(posedge clk or posedge reset ) begin
		if(reset) begin
			for (j=0; j < 10; j=j+1) 
				input_pattern[j] <= 0;
		end else if(nstate == LOAD_PATTERN) 
			input_pattern[pattern_counter] <= chardata;
	end
	
	/////// length counter ////////// (actual length-1)
	always_ff @(posedge clk) begin
		isstring_r <= isstring;
		ispattern_r <= ispattern;
	end
	
	always_ff @(posedge clk or posedge reset) begin
		if(reset) 
			string_len <= 0;
		else if((isstring==1) & (isstring_r==0)) //Clever Condition!!! Don't have to use edge  
			string_len <= 0;
		else if(isstring)
			string_len <= string_len + 1;
	end
	
	always_ff @(posedge clk or posedge reset) begin
		if(reset) 
			pattern_len <= 0;
		else if((ispattern==1) & (ispattern_r==0)) //Clever Condition!!! Don't have to use edge  
			pattern_len <= 0;
		else if(nstate == LOAD_PATTERN)
			pattern_len <= pattern_len + 1;
	end
	
	//count pattern special sign ^, *, $ (for min_pattern_len calculation)
	always_ff @(posedge clk or posedge reset) begin
		if(reset) 
			special_sign_count <= 0;
		else if(valid)
			special_sign_count <= 0;
		else if(cstate == LOAD_PATTERN) begin
			if(input_pattern[pattern_len] == 94 || input_pattern[pattern_len] == 42 || input_pattern[pattern_len] == 36)
				special_sign_count <= special_sign_count + 1;
		end
	end
	
	////////////////////// Move Index /////////////////////////////
	//match_index sequential logic
	always_ff @(posedge clk or posedge reset) begin
		if (reset)
			match_index <= 0;
		else if(ispattern || front_star_flag) //match_index will stuck in here forever
			match_index <= 0;
		else if(nstate == UNMATCH) begin //add one to match_index beforehand
			if(star_flag)
				match_index <= match_index;
			else 
				match_index <= match_index + 1;
		end else if(cstate == RESULT)
			match_index <= 0;
	end
	
	always_ff @(posedge clk or posedge reset) begin
		if(reset)
			front_star_match_index <= 0; 
		else if(front_star_flag) begin
			if(nstate == UNMATCH)
				front_star_match_index <= front_star_match_index + 1;
			else if(nstate == RESULT)
				front_star_match_index <= 0;
		end 
 	end
	
	// string_pointer sequential logic 
	always_ff @(posedge clk or posedge reset) begin
		if(reset)
			string_pointer <= 0;
		else if(nstate == MOVE) begin
			if(front_star_flag & !match_flag)
				string_pointer <= front_star_match_index;
			else if (star_flag & !match_flag)
				string_pointer <= string_pointer+1;
			else if(!match_flag)
				string_pointer <= match_index; 
			else	
				string_pointer <= string_pointer + 1;
		end else if (nstate == RESULT) 
			string_pointer <= 0; 
	end
	
	//pattern_pointer sequential logic
	always_ff @(posedge clk or posedge reset) begin
		if(reset)
			pattern_pointer <= 0; 
		else if(nstate == MOVE) begin
			if(hat_pass_counter == 1)
				pattern_pointer <= pattern_pointer + 2; 
			else if(match_flag)
				pattern_pointer <= pattern_pointer + 1; 
			else if(star_flag & !match_flag) begin //pattern_pointer no move
				if(front_star_flag)
					pattern_pointer <= 1; 
				else if(normal_flag) 
					pattern_pointer <= 0; 
				else 
					pattern_pointer <= pattern_pointer;
			end else 
				pattern_pointer <= 0;
		end else if (nstate == RESULT)
			pattern_pointer <= 0;
		//else pattern_pointer don't move
	end
	
	//counter for hat pattern: pattern_pointer+2 for the first time it pass
	always_ff @(posedge clk or posedge reset) begin
		if(reset)
			hat_pass_counter <= 0;
		else if(hat_flag && (nstate == MATCH)) 
			hat_pass_counter <= hat_pass_counter + 1; 
		else if(nstate == UNMATCH)
			hat_pass_counter <= 0; 
	end
	
	/////////////flag///////////////
	
	//normal flag 
	always_ff @(posedge clk or posedge reset) begin
		if(reset)
			normal_flag <= 0;
		else if(nstate == NORMAL)
			normal_flag <= 1; 
		else if(nstate == CLASSIFY)
			normal_flag <= 0;
	end	
	
	//hat flag 
	always_ff @(posedge clk or posedge reset) begin
		if(reset)
			hat_flag <= 0;
		else if(nstate == HAT)
			hat_flag <= 1; 
		else if(nstate == RESULT)
			hat_flag <= 0; 
	end
	
	//star flag 
	always_ff @(posedge clk or posedge reset) begin
		if(reset)
			star_flag <= 0;
		else if(nstate == STAR)
			star_flag <= 1; 
		else if(nstate == RESULT)
			star_flag <= 0; 
	end
	
	//match flag
	always_ff @(posedge clk or posedge reset) begin
		if(reset)
			match_flag <= 0;
		else if(nstate == MATCH) //if unmatch match_flag stays 0; 
			match_flag <= 1;
		else if(nstate == CLASSIFY)
			match_flag <= 0;
	end
	
	assign match = match_flag; 
	
	//Output signal control
	always_ff @(posedge clk or posedge reset) begin
		if(reset)
			valid <= 0; 
		else if (isstring || ispattern)
			valid <= 0;
		else if(nstate == RESULT)
			valid <= 1; 
	end
	
endmodule