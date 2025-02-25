module geofence (
	input clk,
	input reset,
	input [9:0] X,
	input [9:0] Y,
	input [10:0] R,
	output reg valid,
	output reg is_inside
	);
	parameter RADICAND_WIDTH = 20;
	localparam ITER = RADICAND_WIDTH >> 1;
	integer i; 
	
	reg [9:0] reg_x [5:0]; 
	reg [9:0] reg_y [5:0];
	reg [10:0] reg_r [5:0];	
	reg [9:0] arranged_reg_x [5:0]; 
	reg [9:0] arranged_reg_y [5:0];
	reg [10:0] arranged_reg_r [5:0];	
	reg signed [10:0] vectors_x [4:0]; 
	reg signed [10:0] vectors_y [4:0]; 
	reg [2:0] counter_data; 
	reg [3:0] counter_crossp;
	reg [2:0] counter_cpnum; //Counter for which cross product is counting now  (p.s. up to 4) 
	reg [2:0] count_pos_crossp; //counter for each cross product 
	 
	wire signed [22:0] cross_product_wire; 
	reg signed [11:0] vec_Ax; 
	reg signed [11:0] vec_Ay; 
	reg signed [11:0] vec_Bx; 
	reg signed [11:0] vec_By; 
	
	//CAL_TRI
	reg [2:0] count_triangle; //0~5 
	wire [19:0] receiver_range; 
	reg signed [10:0] xr1, xr2, yr1, yr2;
	wire [11:0] s; 
	reg [11:0] s_store; 
	reg [9:0] a, b, c;
	wire [21:0] mult; 
	reg [10:0] multiplier; 
	reg [10:0] multiplicand;
	reg [9:0] tri_left_root;  
	reg signed [20:0] sixtri_area; //s space
	
	////ROOT CIRCUIT
	reg [RADICAND_WIDTH-1:0] radicand;
	reg [RADICAND_WIDTH-1:0] in, in_next; 
	reg [RADICAND_WIDTH-1:0] q, q_next;
	reg [RADICAND_WIDTH+1:0] ac, ac_next; // 2 bits wider
	reg signed [RADICAND_WIDTH+1:0] test_result; // 2 bits wider 
	reg [3:0] root_counter;
	reg [RADICAND_WIDTH-1:0] root; 
	reg [7:0] counter_tri;
	reg root_valid; 
	reg root_busy;
	reg root_start;
	
	//HEX_AREA
	reg signed [20:0] hex_area; 
	reg [2:0] counter_hex; 
	
	reg [2:0] cstate;
	reg [2:0] nstate;
	parameter GET_COR = 3'b000;	//get coordinate and calculate vector
	parameter CROSSP = 3'b001;	//calculate cross product
	parameter REARRANGE = 3'b010;
	parameter CAL_TRI = 3'b011; //Triangle 
	parameter HEX_AREA = 3'b100; 

	always @(posedge clk or posedge reset) begin
		if(reset) 
			cstate <= GET_COR; 
		else
			cstate <= nstate;
	end
	
	always @(*) begin
		case(cstate)
			GET_COR: begin
				if(counter_data == 5) 
					nstate = CROSSP; 
				else 
					nstate = GET_COR; 
			end
			CROSSP: begin
				if (counter_cpnum == 5)
					nstate = CAL_TRI; 
				else if(counter_cpnum == 0 && counter_crossp < 4) 
					nstate = CROSSP;
				else if(counter_crossp < 3)
					nstate = CROSSP; 
				else
					nstate = REARRANGE; 
			end
			REARRANGE: 
				nstate = CROSSP;  
			CAL_TRI: begin
				if(count_triangle == 6)
					nstate = HEX_AREA; 
				else 
					nstate = cstate;
			end	
			HEX_AREA: begin
				if(valid)
					nstate = GET_COR; 
				else
					nstate = cstate; 
			end
			default: 
				nstate = GET_COR; 
		endcase
	end

	always @(posedge clk or posedge reset) begin
		if(reset) 
			counter_data <= 0; 
		else if (cstate == GET_COR)
			counter_data <= counter_data + 1; 
		else 
			counter_data <= 0; 
	end
	
	
	always @(posedge clk or posedge reset) begin
		if(reset) begin
			reg_x[5] <= 0;
			reg_x[4] <= 0;
			reg_x[3] <= 0;
			reg_x[2] <= 0;
			reg_x[1] <= 0;
			reg_x[0] <= 0;
		end else if(cstate == GET_COR) begin //Standard Shift Register Code! FOR ALL THE STREAMING INPUT
			reg_x[5] <= X;
			//reg_x[4:0] <= reg_x[5:1];
			reg_x[4] <= reg_x[5];
			reg_x[3] <= reg_x[4];
			reg_x[2] <= reg_x[3];
			reg_x[1] <= reg_x[2];
			reg_x[0] <= reg_x[1];
 		end else begin	//Sequential Circuit don't have to specify else. Because it is a register. It will stay the same if you leave it there
			reg_x[5] <= reg_x[5];
			reg_x[4] <= reg_x[4];
			reg_x[3] <= reg_x[3];
			reg_x[2] <= reg_x[2];
			reg_x[1] <= reg_x[1];
			reg_x[0] <= reg_x[0];
		end
	end
	
	always @(posedge clk or posedge reset) begin
		if(reset) begin
			reg_y[5] <= 0;
			reg_y[4] <= 0;
			reg_y[3] <= 0;
			reg_y[2] <= 0;
			reg_y[1] <= 0;
			reg_y[0] <= 0;
		end else if(cstate == GET_COR) begin //Standard Shift Register Code! FOR ALL THE STREAMING INPUT
			reg_y[5] <= Y;
			reg_y[4] <= reg_y[5];
			reg_y[3] <= reg_y[4];
			reg_y[2] <= reg_y[3];
			reg_y[1] <= reg_y[2];
			reg_y[0] <= reg_y[1];
 		end 
	end
	
	always @(posedge clk or posedge reset) begin
		if(reset) begin
			reg_r[5] <= 0;
			reg_r[4] <= 0;
			reg_r[3] <= 0;
			reg_r[2] <= 0;
			reg_r[1] <= 0;
			reg_r[0] <= 0;
		end else if(cstate == GET_COR) begin //Standard Shift Register Code! FOR ALL THE STREAMING INPUT
			reg_r[5] <= R;
			reg_r[4] <= reg_r[5];
			reg_r[3] <= reg_r[4];
			reg_r[2] <= reg_r[3];
			reg_r[1] <= reg_r[2];
			reg_r[0] <= reg_r[1];
 		end 
	end
	
	always @(posedge clk or posedge reset) begin //get vector
		if(reset) begin
			vectors_x[0] <= 0;
			vectors_x[1] <= 0;
			vectors_x[2] <= 0;
			vectors_x[3] <= 0;
			vectors_x[4] <= 0;
			vectors_y[0] <= 0;
			vectors_y[1] <= 0;
			vectors_y[2] <= 0;
			vectors_y[3] <= 0;
			vectors_y[4] <= 0;
		end else if (cstate == GET_COR) begin
			vectors_x[0] <= 0;
			vectors_x[1] <= 0;
			vectors_x[2] <= 0;
			vectors_x[3] <= 0;
			vectors_x[4] <= 0;
			vectors_y[0] <= 0;
			vectors_y[1] <= 0;
			vectors_y[2] <= 0;
			vectors_y[3] <= 0;
			vectors_y[4] <= 0;
		end else if (counter_cpnum == 0 && counter_crossp == 0) begin
			vectors_x[0] <= reg_x[1] - reg_x[0];
			vectors_x[1] <= reg_x[2] - reg_x[0];
			vectors_x[2] <= reg_x[3] - reg_x[0];
			vectors_x[3] <= reg_x[4] - reg_x[0];
			vectors_x[4] <= reg_x[5] - reg_x[0];
			vectors_y[0] <= reg_y[1] - reg_y[0];
			vectors_y[1] <= reg_y[2] - reg_y[0];
			vectors_y[2] <= reg_y[3] - reg_y[0];
			vectors_y[3] <= reg_y[4] - reg_y[0];
			vectors_y[4] <= reg_y[5] - reg_y[0];
		end 
	end
	
	///////////////////////////////////////////////
	//CROSSP
	always @(posedge clk or posedge reset) begin
		if(reset) 
			counter_crossp <= 0; 
		else if (cstate == CROSSP)
			counter_crossp <= counter_crossp + 1; 
		else 
			counter_crossp <= 0; 
	end
	
	always @(posedge clk or posedge reset) begin
		if(reset) begin
			counter_cpnum <= 0; 
		end else if (cstate == CROSSP || cstate == REARRANGE) begin
			if(counter_crossp == 5)
				counter_cpnum <= counter_cpnum + 1; 
			else if(counter_crossp == 4 && counter_cpnum != 0)
				counter_cpnum <= counter_cpnum + 1; 
			else 
				counter_cpnum <= counter_cpnum; 
		end else 
			counter_cpnum <= 0; 
	end
	
	assign cross_product_wire = vec_Ax * vec_By - vec_Bx * vec_Ay;
	
	always @(*) begin
		if (reset) begin
			vec_Ax = 0; 
			vec_Ay = 0;
			vec_Bx = 0; 
			vec_By = 0; 
		end else if(cstate == CROSSP) begin
			case(counter_cpnum)
				0: 	begin
					case(counter_crossp)
						1: begin
							vec_Ax = vectors_x[0];
							vec_Ay = vectors_y[0]; 
							vec_Bx = vectors_x[1]; 
							vec_By = vectors_y[1];
						end
						2: begin
							vec_Ax = vectors_x[0];
							vec_Ay = vectors_y[0]; 
							vec_Bx = vectors_x[2]; 
							vec_By = vectors_y[2];
						end
						3: begin
							vec_Ax = vectors_x[0];
							vec_Ay = vectors_y[0]; 
							vec_Bx = vectors_x[3]; 
							vec_By = vectors_y[3];
						end
						4: begin
							vec_Ax = vectors_x[0];
							vec_Ay = vectors_y[0]; 
							vec_Bx = vectors_x[4]; 
							vec_By = vectors_y[4];
						end
						default begin
							vec_Ax = 0;
							vec_Ay = 0; 
							vec_Bx = 0; 
							vec_By = 0;
						end
					endcase
				end
				1: begin //vec1 to rest
					case(counter_crossp)
						0: begin
							vec_Ax = vectors_x[1];
							vec_Ay = vectors_y[1]; 
							vec_Bx = vectors_x[0]; 
							vec_By = vectors_y[0];
						end
						1: begin
							vec_Ax = vectors_x[1];
							vec_Ay = vectors_y[1]; 
							vec_Bx = vectors_x[2]; 
							vec_By = vectors_y[2];
						end
						2: begin
							vec_Ax = vectors_x[1];
							vec_Ay = vectors_y[1]; 
							vec_Bx = vectors_x[3]; 
							vec_By = vectors_y[3];
						end
						3: begin
							vec_Ax = vectors_x[1];
							vec_Ay = vectors_y[1]; 
							vec_Bx = vectors_x[4]; 
							vec_By = vectors_y[4];
						end
						default begin
							vec_Ax = 0;
							vec_Ay = 0; 
							vec_Bx = 0; 
							vec_By = 0;
						end
					endcase
				end
				2: begin //vec2 to rest
					case(counter_crossp)
						0: begin
							vec_Ax = vectors_x[2];
							vec_Ay = vectors_y[2]; 
							vec_Bx = vectors_x[0]; 
							vec_By = vectors_y[0];
						end
						1: begin
							vec_Ax = vectors_x[2];
							vec_Ay = vectors_y[2]; 
							vec_Bx = vectors_x[1]; 
							vec_By = vectors_y[1];
						end
						2: begin
							vec_Ax = vectors_x[2];
							vec_Ay = vectors_y[2]; 
							vec_Bx = vectors_x[3]; 
							vec_By = vectors_y[3];
						end
						3: begin
							vec_Ax = vectors_x[2];
							vec_Ay = vectors_y[2]; 
							vec_Bx = vectors_x[4]; 
							vec_By = vectors_y[4];
						end
						default begin
							vec_Ax = 0;
							vec_Ay = 0; 
							vec_Bx = 0; 
							vec_By = 0;
						end
					endcase
				end
				3: begin //vec3 to rest
					case(counter_crossp)
						0: begin
							vec_Ax = vectors_x[3];
							vec_Ay = vectors_y[3]; 
							vec_Bx = vectors_x[0]; 
							vec_By = vectors_y[0];
						end
						1: begin
							vec_Ax = vectors_x[3];
							vec_Ay = vectors_y[3]; 
							vec_Bx = vectors_x[1]; 
							vec_By = vectors_y[1];
						end
						2: begin
							vec_Ax = vectors_x[3];
							vec_Ay = vectors_y[3]; 
							vec_Bx = vectors_x[2]; 
							vec_By = vectors_y[2];
						end
						3: begin
							vec_Ax = vectors_x[3];
							vec_Ay = vectors_y[3]; 
							vec_Bx = vectors_x[4]; 
							vec_By = vectors_y[4];
						end
						default: begin
							vec_Ax = 0;
							vec_Ay = 0; 
							vec_Bx = 0; 
							vec_By = 0;
						end
					endcase
				end
				4: begin //vec4 to rest
					case(counter_crossp)
						0: begin
							vec_Ax = vectors_x[4];
							vec_Ay = vectors_y[4]; 
							vec_Bx = vectors_x[0]; 
							vec_By = vectors_y[0];
						end
						1: begin
							vec_Ax = vectors_x[4];
							vec_Ay = vectors_y[4]; 
							vec_Bx = vectors_x[1]; 
							vec_By = vectors_y[1];
						end
						2: begin
							vec_Ax = vectors_x[4];
							vec_Ay = vectors_y[4]; 
							vec_Bx = vectors_x[2]; 
							vec_By = vectors_y[2];
						end
						3: begin
							vec_Ax = vectors_x[4];
							vec_Ay = vectors_y[4]; 
							vec_Bx = vectors_x[3]; 
							vec_By = vectors_y[3];
						end
						default: begin
							vec_Ax = 0;
							vec_Ay = 0; 
							vec_Bx = 0; 
							vec_By = 0;
						end
					endcase
				end
				default: begin
					vec_Ax = 0;
					vec_Ay = 0; 
					vec_Bx = 0; 
					vec_By = 0;
				end
			endcase
		end else if(cstate == HEX_AREA) begin
			case(counter_hex)
				0: begin
					vec_Ax = arranged_reg_x[0];
					vec_Ay = arranged_reg_y[0]; 
					vec_Bx = arranged_reg_x[1]; 
					vec_By = arranged_reg_y[1];
				end
				1: begin
					vec_Ax = arranged_reg_x[1];
					vec_Ay = arranged_reg_y[1]; 
					vec_Bx = arranged_reg_x[2]; 
					vec_By = arranged_reg_y[2];
				end
				2: begin
					vec_Ax = arranged_reg_x[2];
					vec_Ay = arranged_reg_y[2]; 
					vec_Bx = arranged_reg_x[3]; 
					vec_By = arranged_reg_y[3];
				end
				3: begin
					vec_Ax = arranged_reg_x[3];
					vec_Ay = arranged_reg_y[3]; 
					vec_Bx = arranged_reg_x[4]; 
					vec_By = arranged_reg_y[4];
				end
				4: begin
					vec_Ax = arranged_reg_x[4];
					vec_Ay = arranged_reg_y[4]; 
					vec_Bx = arranged_reg_x[5]; 
					vec_By = arranged_reg_y[5];
				end
				5: begin
					vec_Ax = arranged_reg_x[5];
					vec_Ay = arranged_reg_y[5]; 
					vec_Bx = arranged_reg_x[0]; 
					vec_By = arranged_reg_y[0];
				end
				default: begin
					vec_Ax = 0;
					vec_Ay = 0; 
					vec_Bx = 0; 
					vec_By = 0;
				end
			endcase
		end else begin
			vec_Ax = 0;
			vec_Ay = 0; 
			vec_Bx = 0; 
			vec_By = 0;
		end
	end
	
	
	always @(posedge clk or posedge reset) begin
		if(reset) 
			count_pos_crossp <= 0; 
		else if (cstate == CROSSP && counter_crossp < 5) begin
			if(cross_product_wire > 0) 
				count_pos_crossp <= count_pos_crossp + 1;
			else 
				count_pos_crossp <= count_pos_crossp;
		end else if(cstate == REARRANGE) 
			count_pos_crossp <= 0;
		else 
			count_pos_crossp <= count_pos_crossp; 
	end
	
	always @(posedge clk or posedge reset) begin
		if(reset) begin
			for(i=0; i<=5; i=i+1) begin //Repetitive Circuit use for loop to express
				arranged_reg_x[i] <= 0;
				arranged_reg_y[i] <= 0;
				arranged_reg_r[i] <= 0;
			end
		end else if(cstate == GET_COR) begin
			for(i=0; i<=5; i=i+1) begin //Repetitive Circuit use for loop to express
				arranged_reg_x[i] <= 0;
				arranged_reg_y[i] <= 0;
				arranged_reg_r[i] <= 0;
			end
		end else if(cstate == REARRANGE) begin
			case(counter_cpnum)
				0: begin
					case(count_pos_crossp)
						4: begin
							arranged_reg_x[0] <= reg_x[0];
							arranged_reg_x[1] <= reg_x[1];
							arranged_reg_y[0] <= reg_y[0];
							arranged_reg_y[1] <= reg_y[1];
							arranged_reg_r[0] <= reg_r[0];
							arranged_reg_r[1] <= reg_r[1];
							
						end
						3: begin
							arranged_reg_x[0] <= reg_x[0];
							arranged_reg_x[2] <= reg_x[1];
							arranged_reg_y[0] <= reg_y[0];
							arranged_reg_y[2] <= reg_y[1];
							arranged_reg_r[0] <= reg_r[0];
							arranged_reg_r[2] <= reg_r[1];
						end
						2: begin
							arranged_reg_x[0] <= reg_x[0];
							arranged_reg_x[3] <= reg_x[1];
							arranged_reg_y[0] <= reg_y[0];
							arranged_reg_y[3] <= reg_y[1];
							arranged_reg_r[0] <= reg_r[0];
							arranged_reg_r[3] <= reg_r[1];
						end
						1: begin
							arranged_reg_x[0] <= reg_x[0];
							arranged_reg_x[4] <= reg_x[1];
							arranged_reg_y[0] <= reg_y[0];
							arranged_reg_y[4] <= reg_y[1];
							arranged_reg_r[0] <= reg_r[0];
							arranged_reg_r[4] <= reg_r[1];
						end
						0: begin
							arranged_reg_x[0] <= reg_x[0];
							arranged_reg_x[5] <= reg_x[1];
							arranged_reg_y[0] <= reg_y[0];
							arranged_reg_y[5] <= reg_y[1];
							arranged_reg_r[0] <= reg_r[0];
							arranged_reg_r[5] <= reg_r[1];
						end
					endcase
				end
				1: begin
					case(count_pos_crossp)
						4: begin
							arranged_reg_x[1] <= reg_x[2];
							arranged_reg_y[1] <= reg_y[2];
							arranged_reg_r[1] <= reg_r[2];
						end
						3: begin
							arranged_reg_x[2] <= reg_x[2];
							arranged_reg_y[2] <= reg_y[2];
							arranged_reg_r[2] <= reg_r[2];
						end
						2: begin
							arranged_reg_x[3] <= reg_x[2];
							arranged_reg_y[3] <= reg_y[2];
							arranged_reg_r[3] <= reg_r[2];
						end
						1: begin
							arranged_reg_x[4] <= reg_x[2];
							arranged_reg_y[4] <= reg_y[2];
							arranged_reg_r[4] <= reg_r[2];
						end
						0: begin
							arranged_reg_y[5] <= reg_y[2];
							arranged_reg_r[5] <= reg_r[2];
							arranged_reg_x[5] <= reg_x[2];
						end
					endcase
				end
				2: begin
					case(count_pos_crossp)
						4: begin
							arranged_reg_x[1] <= reg_x[3];
							arranged_reg_y[1] <= reg_y[3];
							arranged_reg_r[1] <= reg_r[3];
						end
						3: begin
							arranged_reg_x[2] <= reg_x[3];
							arranged_reg_y[2] <= reg_y[3];
							arranged_reg_r[2] <= reg_r[3];
						end
						2: begin
							arranged_reg_x[3] <= reg_x[3];
							arranged_reg_y[3] <= reg_y[3];
							arranged_reg_r[3] <= reg_r[3];
						end
						1: begin
							arranged_reg_x[4] <= reg_x[3];
							arranged_reg_y[4] <= reg_y[3];
							arranged_reg_r[4] <= reg_r[3];
						end
						0: begin
							arranged_reg_x[5] <= reg_x[3];
							arranged_reg_y[5] <= reg_y[3];
							arranged_reg_r[5] <= reg_r[3];
						end
					endcase
				end
				3: begin
					case(count_pos_crossp)
						4: begin
							arranged_reg_x[1] <= reg_x[4];
							arranged_reg_y[1] <= reg_y[4];
							arranged_reg_r[1] <= reg_r[4];
						end
						3: begin
							arranged_reg_x[2] <= reg_x[4];
							arranged_reg_y[2] <= reg_y[4];
							arranged_reg_r[2] <= reg_r[4];
						end
						2: begin
							arranged_reg_x[3] <= reg_x[4];
							arranged_reg_y[3] <= reg_y[4];
							arranged_reg_r[3] <= reg_r[4];
						end
						1: begin
							arranged_reg_x[4] <= reg_x[4];
							arranged_reg_y[4] <= reg_y[4];
							arranged_reg_r[4] <= reg_r[4];
						end
						0: begin
							arranged_reg_x[5] <= reg_x[4];
							arranged_reg_y[5] <= reg_y[4];
							arranged_reg_r[5] <= reg_r[4];
						end
					endcase
				end
				4: begin
					case(count_pos_crossp)
						4: begin
							arranged_reg_x[1] <= reg_x[5];
							arranged_reg_y[1] <= reg_y[5];
							arranged_reg_r[1] <= reg_r[5];
						end
						3: begin
							arranged_reg_x[2] <= reg_x[5];
							arranged_reg_y[2] <= reg_y[5];
							arranged_reg_r[2] <= reg_r[5];
						end
						2: begin
							arranged_reg_x[3] <= reg_x[5];
							arranged_reg_y[3] <= reg_y[5];
							arranged_reg_r[3] <= reg_r[5];
						end
						1: begin
							arranged_reg_x[4] <= reg_x[5];
							arranged_reg_y[4] <= reg_y[5];
							arranged_reg_r[4] <= reg_r[5];
						end
						0: begin
							arranged_reg_x[5] <= reg_x[5];
							arranged_reg_y[5] <= reg_y[5];
							arranged_reg_r[5] <= reg_r[5];
						end
					endcase
				end
			endcase
		end 
	end
	
	//CAL_TRI
	assign receiver_range = (xr1 - xr2) * (xr1 - xr2) + (yr1 - yr2) * (yr1 - yr2); 
	
	always @(posedge clk or posedge reset) begin
		if(reset)
			count_triangle <= 0;
		else if(cstate == HEX_AREA)
			count_triangle <= 0;
		else if(counter_tri == 40) 
			count_triangle <= count_triangle + 1; 
	end
	
	always @(posedge clk or posedge reset) begin
		if(reset)
			counter_tri <= 0;
		else if (counter_tri == 40)
			counter_tri <= 0;  
		else if(cstate == CAL_TRI) 
			counter_tri <= counter_tri + 1;  
	end
	
	always @(*) begin
		case(count_triangle)
			0:	begin
				xr1 = arranged_reg_x[0];
				xr2 = arranged_reg_x[1];
				yr1 = arranged_reg_y[0];
				yr2 = arranged_reg_y[1];
				a = arranged_reg_r[0];
				b = arranged_reg_r[1];
			end
			1:	begin
				xr1 = arranged_reg_x[1];
				xr2 = arranged_reg_x[2];
				yr1 = arranged_reg_y[1];
				yr2 = arranged_reg_y[2];
				a = arranged_reg_r[1];
				b = arranged_reg_r[2];
			end
			2:	begin
				xr1 = arranged_reg_x[2];
				xr2 = arranged_reg_x[3];
				yr1 = arranged_reg_y[2];
				yr2 = arranged_reg_y[3];
				a = arranged_reg_r[2];
				b = arranged_reg_r[3];
			end
			3:	begin
				xr1 = arranged_reg_x[3];
				xr2 = arranged_reg_x[4];
				yr1 = arranged_reg_y[3];
				yr2 = arranged_reg_y[4];
				a = arranged_reg_r[3];
				b = arranged_reg_r[4];
			end
			4:	begin
				xr1 = arranged_reg_x[4];
				xr2 = arranged_reg_x[5];
				yr1 = arranged_reg_y[4];
				yr2 = arranged_reg_y[5];
				a = arranged_reg_r[4];
				b = arranged_reg_r[5];
			end
			5: 	begin
				xr1 = arranged_reg_x[5];
				xr2 = arranged_reg_x[0];
				yr1 = arranged_reg_y[5];
				yr2 = arranged_reg_y[0];
				a = arranged_reg_r[5];
				b = arranged_reg_r[0];
			end 
			default: begin
				xr1 = 0;
				xr2 = 0;
				yr1 = 0;
				yr2 = 0;
				a = 0;
				b = 0;
			end
		endcase
	end
	
	always @(posedge clk or posedge reset) begin
		if(reset) begin
			root_start <= 0;
			root_busy <= 0;
		end else if (root_counter == ITER-1) begin
			root_busy <= 0;
		end else if (root_busy) begin
			root_start <= 0;
		end else if (cstate == CAL_TRI) begin
			case(counter_tri)
				2: begin
					root_start <= 1;
					root_busy <= 1; 
				end
				15: begin
					root_start <= 1;
					root_busy <= 1;
				end
				28: begin
					root_start <= 1;
					root_busy <= 1;
				end
			endcase
		end	
	end
	
	always @(posedge clk or posedge reset) begin //assign radicand to square root circuit
		if(reset)
			radicand <= 0;
		case(counter_tri)
			2: 
				radicand <= receiver_range;
			15: 
				radicand <= mult; //mult
			28: 
				radicand <= mult; 
		endcase
	end
	//////////////////////////////////////////////////////////////
	//CAL_TRI - ROOT CIRCUIT
	always @(posedge clk) begin
		if(reset) begin
			root_valid <= 0; 
			root_counter <= 0;
			q <= 0; 
			ac <= 0; 
			in <= 0; 
			root <= 0; 
			//rem <= 0;
		end else if (root_start) begin
			q <= 0; 
			root <= 0; 
			root_valid <= 0;
			//{ac, in} <= {{RADICAND_WIDTH{1'b0}}, radicand, 2'b0}; // Use my philosophy to write {20 bits + 20 bits + 2 bits}
			ac <= {{RADICAND_WIDTH{1'b0}}, radicand[RADICAND_WIDTH-1:RADICAND_WIDTH-2]};
			in <= {radicand[RADICAND_WIDTH-3:0], 2'b0};
		end else if (root_busy) begin
			if(root_counter == ITER-1) begin
				root_valid <= 1; 
				root <= q_next;
				//rem <= ac_next[RADICAND_WIDTH+1:2]; 
			end else begin
				root_counter <= root_counter + 1; 
				in <= in_next; 
				ac <= ac_next; 
				q <= q_next; 
			end
		end else if(root_valid) begin
			root_counter <= 0;
			root_valid <= 0; 
		end
	end
	
	always @(*) begin
		test_result = ac - {q, 2'b01};
		if (reset) begin
			ac_next = 0;
			in_next = 0;
			q_next = 0;
		end else if(test_result[RADICAND_WIDTH+1] == 0) begin
			//{ac_next, in_next} = {test_result[RADICAND_WIDTH-1:0], in, 2'b0};
			ac_next = {test_result, in[RADICAND_WIDTH-1:RADICAND_WIDTH-2]}; //A=T and then shift X by two into A
			in_next = {in[RADICAND_WIDTH-3:0], 2'b0}; //Shifted X
			q_next = {q[RADICAND_WIDTH-2:0], 1'b1};
		end else begin
			//{ac_next, in_next} = {ac[RADICAND_WIDTH-1:0], in, 2'b0};
			ac_next = {ac[RADICAND_WIDTH-1:0], in[RADICAND_WIDTH-1:RADICAND_WIDTH-2]};
			in_next = {in[RADICAND_WIDTH-3:0], 2'b0};
			q_next = q << 1; 
		end
	end
	///////////////////////////////////////////////////////////////////////////
	
	assign s = (a + b + root) >> 1; 
	assign mult = multiplier * multiplicand; 
	
	always @(*) begin
		if(reset) begin
			multiplier = 0;
			multiplicand = 0; 
		end else if(counter_tri == 15) begin
			multiplier = s_store; 
			multiplicand = s_store - a;
		end else if(counter_tri == 28) begin
			multiplier = s_store - b; 
			multiplicand = s_store - c;
		end else if (counter_tri == 40) begin
			multiplier = root; 
			multiplicand = tri_left_root;
		end else begin
			multiplier = 0;
			multiplicand = 0; 
		end
	end
	
	always @(posedge clk or posedge reset) begin
		if(reset)
			tri_left_root <= 0;
		else if(counter_tri == 28)
			tri_left_root <= root; 
	end
	
	always @(posedge clk or posedge reset) begin
		if (reset) 
			s_store <= 0;
		else if(counter_tri == 14) 
			s_store <= s;
	end
	
	always @(posedge clk or posedge reset) begin
		if (reset) 
			c <= 0;
		else if(counter_tri == 14) 
			c <= root;
	end
	
	always @(posedge clk or posedge reset) begin
		if(reset) 
			sixtri_area <= 0;
		else if(cstate == GET_COR)
			sixtri_area <= 0; 
		else if(counter_tri == 40) 
			sixtri_area <= sixtri_area + mult;
	end
	
	always @(posedge clk or posedge reset) begin
		if(reset)
			counter_hex <= 0;
		else if(cstate == HEX_AREA) 
			counter_hex <= counter_hex + 1; 
		else 
			counter_hex <= 0; 
	end
	
	always @(posedge clk or posedge reset) begin
		if(reset)
			hex_area <= 0;
		else if(counter_hex == 6)
			hex_area <= hex_area >> 1; 
		else if(cstate == HEX_AREA)
			hex_area <= hex_area + cross_product_wire; 
		else 
			hex_area <= 0;
	end
	
	always @(posedge clk or posedge reset) begin
		if(reset)
			valid <= 0; 
		else if(counter_hex == 7)
			valid <= 1; 
		else 
			valid <= 0; 
	end
	
	always @(posedge clk or posedge reset) begin
		if(reset)
			is_inside <= 0;
		else if(counter_hex == 7 && sixtri_area < hex_area)
			is_inside <= 1;  
		else 
			is_inside <= 0; 
	end
endmodule
