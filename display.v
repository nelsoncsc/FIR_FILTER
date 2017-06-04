module display(	input clock, reset, freeze,
				input [15:0] data,

				output reg [8:0] x,
				output reg [7:0] y,
				output [2:0] color,
				output plot);

localparam sweep_delay = 10000, xmax = 319, ymax = 239;

reg [31:0] delay_counter;

reg st, streg;


// FSM for sweep control
localparam st_ploty = 0, st_done = 1;

always @(*) begin
	st = streg;
	case(streg)
		st_ploty: if(y == ymax) st = st_done;
		st_done: if(!freeze && (delay_counter == sweep_delay)) st = st_ploty;
	endcase
end

always @(posedge clock)
	if(reset) streg <= st_done;
	else streg <= st;


// Delay and X counters
always @(posedge clock)
	if(reset) begin
		delay_counter <= 0;
		x <= 0;
	end else if(streg == st_done)
		if(delay_counter == sweep_delay) begin
			delay_counter <= 0;
			x <= (x == xmax) ? 0 : x + 1;
		end else delay_counter <= delay_counter + 1;

// Y counter
always @(posedge clock)
	if(reset || (streg == st_done)) y <= 0;
	else if(y < ymax) y <= y + 1;


assign plot = (streg == st_ploty);
assign color = (y == 8'd120+{data[15], data[6:0]});

endmodule
