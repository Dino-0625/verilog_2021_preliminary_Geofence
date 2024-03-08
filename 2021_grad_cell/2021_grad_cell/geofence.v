module geofence ( clk,reset,X,Y,R,valid,is_inside);
input clk;
input reset;
input [9:0] X;
input [9:0] Y;
input [10:0] R;
output valid;
output is_inside;

reg [9:0] x [1:7];
reg [9:0] y [1:7];
reg [10:0] d [1:7];
reg [10:0] p_d [1:7];
reg finish_calculate_area, finish_calculate_object_area, finish_getdata, finish_sort, finish_square;
reg [2:0] calculate_object_step;
reg [2:0] data_count, sort_count, sort_count_stop, calculate_count, state, nextState, pre_state, calculate_object_count, pre_sort_count;
reg signed [10:0] Ax, Ay, Bx, By;
reg [10:0] square_compare, square_ans, multi10bit_0, multi10bit_1;
wire [10:0] a, b, c;
reg [12:0] s;
reg [21:0] object_area, area, object_total_area;
reg signed [21:0] Ax_multi_By, Bx_multi_Ay, Ax_multi_By_minus_Bx_multi_Ay;
reg [19:0] distance_square_0, distance_square_1, distance_square, square_value, multi20bit_temp;
wire clock_wise, gotoPENDING;
wire [19:0] multi20bit;
parameter GETDATA = 3'b001;
parameter SORT = 3'b010;
parameter CALCULATE_AREA = 3'b011;
parameter CALCULATE_PD = 3'b100;
parameter CALCULATE_OBJECT_AREA = 3'b101;
parameter PENDING = 3'b110;
parameter RETURN = 3'b111;

assign distance_square = distance_square_0 * distance_square_0 + distance_square_1 * distance_square_1;
assign Ax_multi_By = Ax * By;
assign Bx_multi_Ay = Bx * Ay;
assign Ax_multi_By_minus_Bx_multi_Ay = Ax_multi_By - Bx_multi_Ay;
assign clock_wise = (Ax_multi_By_minus_Bx_multi_Ay < 0);
assign multi20bit = multi10bit_0 * multi10bit_1;
assign s = (a + b + c) >> 1;
assign valid = (state == RETURN);
assign is_inside = (object_total_area <= area);
assign gotoPENDING = (calculate_object_step == 1) || (calculate_object_step == 3);
assign a = p_d[calculate_object_count];
assign b = d[calculate_object_count];
assign c = d[calculate_object_count + 1];
always@(state, finish_calculate_area, finish_calculate_object_area, finish_getdata, finish_sort, finish_square, calculate_object_step, gotoPENDING)begin
	case(state)
		GETDATA:
			if(finish_getdata == 1)
				nextState = SORT;
			else
				nextState = GETDATA;
		
		SORT:
			if(finish_sort == 1)
				nextState = CALCULATE_AREA;
			else
				nextState = SORT;
		CALCULATE_AREA:
			nextState = PENDING;
		CALCULATE_PD:
			nextState = CALCULATE_OBJECT_AREA;
		CALCULATE_OBJECT_AREA:
			if(finish_calculate_object_area == 1)
				nextState = RETURN;
			else if(gotoPENDING)
				nextState = PENDING;
			else
				nextState = CALCULATE_OBJECT_AREA;
		PENDING:
			if(finish_square == 1)
				
				nextState = pre_state;
			else
				nextState = PENDING;
		RETURN:
			nextState = GETDATA;
		default:
			nextState = 0;
	endcase
end
always@(posedge clk)begin
	if(reset)
		state <= 1;
	else
		state <= nextState;
end
always@(state)begin
	square_value = (pre_state == CALCULATE_OBJECT_AREA) ? multi20bit_temp : distance_square;
end
always@(posedge clk)begin
	if(state == PENDING)begin
		if(multi20bit <= square_value)begin
			square_ans <= square_ans + square_compare;
			multi10bit_0 <= square_ans + square_compare + (square_compare >> 1);
			multi10bit_1 <= square_ans + square_compare + (square_compare >> 1);
		end
		else begin
			square_ans <= square_ans;
			multi10bit_0 <= square_ans + (square_compare >> 1);
			multi10bit_1 <= square_ans + (square_compare >> 1);
		end
		square_compare <= square_compare >> 1;
		
		if(square_compare == 10'b00_0000_0001)
			finish_square <= 1;
		else
			finish_square <= 0;
	end
	else begin
		square_ans <= 10'b00_0000_0000;
		square_compare <= 10'b10_0000_0000;
	end
end
always@(posedge clk)begin

	finish_calculate_object_area <= 0;
	finish_getdata <= 0;
	finish_sort <= 0;
	
	
	if(reset)begin
		area <= 0;
		object_area <= 0;
		data_count <= 1;
		sort_count <= 2;
		sort_count_stop <= 5;
		calculate_count <= 1;
		calculate_object_count <= 1;
		calculate_object_step <= 0;
		object_total_area <= 0;
	end
	else
		case(state)
			GETDATA:begin
				x[data_count] <= X;
				y[data_count] <= Y;
				d[data_count] <= R;
				data_count <= data_count + 1;
				if(data_count == 5)
					finish_getdata <= 1;
				else
					finish_getdata <= 0;
				
			end
			SORT:begin
				//sort 5 point 
				Ax <= x[sort_count] - x[1];
				Ay <= y[sort_count] - y[1];
				Bx <= x[sort_count + 1] - x[1];
				By <= y[sort_count + 1] - y[1];
				if(clock_wise == 1'b1)begin
					x[pre_sort_count] <= x[pre_sort_count];
					y[pre_sort_count] <= y[pre_sort_count];
					d[pre_sort_count] <= d[pre_sort_count];
					x[pre_sort_count + 1] <= x[pre_sort_count + 1];
					y[pre_sort_count + 1] <= y[pre_sort_count + 1];
					d[pre_sort_count + 1] <= d[pre_sort_count + 1];
				end
				else begin
					x[pre_sort_count] <= x[pre_sort_count + 1];
					y[pre_sort_count] <= y[pre_sort_count + 1];
					d[pre_sort_count] <= d[pre_sort_count + 1];
					x[pre_sort_count + 1] <= x[pre_sort_count];
					y[pre_sort_count + 1] <= y[pre_sort_count];
					d[pre_sort_count + 1] <= d[pre_sort_count];
				end
				
				if(sort_count == 2 && sort_count_stop == 1)begin
					x[7] <= x[1];
					y[7] <= y[1];
					d[7] <= d[1];
					finish_sort <= 1;
				end
				else if(sort_count == 5)begin
					pre_sort_count <= sort_count;
					sort_count <= 2;
					sort_count_stop <= sort_count_stop - 1;
				end
				else begin
					sort_count <= sort_count + 1;
					pre_sort_count <= sort_count;
				end
				
			end
			CALCULATE_AREA:begin
				Ax <= x[calculate_count];
				By <= y[calculate_count + 1];
				Bx <= x[calculate_count + 1];
				Ay <= y[calculate_count];
				distance_square_0 <= x[calculate_count] - x[calculate_count + 1];
				distance_square_1 <= y[calculate_count] - y[calculate_count + 1];
				
				if(calculate_count == 1)begin
					area <= area;
				end
				else begin
					area <= area + Ax_multi_By_minus_Bx_multi_Ay;
					p_d[calculate_count - 1] <= square_ans;
				end
				if(calculate_count == 6)begin
					finish_calculate_area <= 1;
					pre_state <= CALCULATE_PD;
				end
				else begin
					finish_calculate_area <= 0;
					calculate_count <= calculate_count + 1;
					pre_state <= CALCULATE_AREA;
				end
				
				
				multi10bit_0 <= 10'b10_0000_0000;
				multi10bit_1 <= 10'b10_0000_0000;
			end
			CALCULATE_PD:begin
				p_d[calculate_count] <= square_ans;
				area <= (-(area + Ax_multi_By_minus_Bx_multi_Ay)) >> 1;
			end
			CALCULATE_OBJECT_AREA:begin
				
				if(calculate_object_step == 0)begin
					multi10bit_0 <= s;
					multi10bit_1 <= s - a;
					calculate_object_step <= 1;
				end
				else if(calculate_object_step == 1)begin
					multi20bit_temp <= multi20bit;
					
					calculate_object_step <= 2;
					multi10bit_0 <= 10'b10_0000_0000;
					multi10bit_1 <= 10'b10_0000_0000;
				end
				else if(calculate_object_step == 2)begin
					object_area <= square_ans;
					multi10bit_0 <= s - b;
					multi10bit_1 <= s - c;
					calculate_object_step <= 3;
					
				end
				else if(calculate_object_step == 3)begin
					multi20bit_temp <= multi20bit;
					calculate_object_step <= 4;
					multi10bit_0 <= 10'b10_0000_0000;
					multi10bit_1 <= 10'b10_0000_0000;
				end
				else begin
					calculate_object_count <= calculate_object_count + 1;
					calculate_object_step <= 0;
					object_total_area <= object_total_area + square_ans * object_area;
					object_area <= 0;
				end
					
				if(calculate_object_count == 7)
					finish_calculate_object_area <= 1;
				else
					finish_calculate_object_area <= 0;
				
				pre_state <= CALCULATE_OBJECT_AREA;
			end
			RETURN:begin
				area <= 0;
				object_area <= 0;
				calculate_object_step <= 0;
				object_total_area <= 0;
				data_count <= 1;
				sort_count_stop <= 5;
				sort_count <= 2;
				calculate_count <= 1;
				calculate_object_count <= 1;
				
		
			end
			
		endcase
end
endmodule