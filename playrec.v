parameter N = 8;
parameter W = 16;
parameter H = 8;

module filter1(input clock,
                input signed [W-1:0]Xin,
                output reg signed [W-1:0]Y);
    
  reg signed [W+H-1:0] y[N];
  reg signed [H-1:0] h[N];
  
  assign h[0] = -2;
  assign h[1] = 8;
  assign h[2] = -35;
  assign h[3] = 157;
  assign h[4] = 157;
  assign h[5] = -35;
  assign h[6] = 8;
  assign h[7] = -2;
  assign Y = y[N-1]>>H;
  
  always @(posedge clock)begin
      y[0] <= h[0]*Xin;
		for(int i = 1; i < N; i++)
		   y[i] <= y[i-1]+h[N-1-i]*Xin;
  end
endmodule

module filter2(input clock,
                input signed [W-1:0]Xin,
                output reg signed [W-1:0]Y);
  
  reg signed [W:0] y[N];  
  
  assign Y = y[N-1][W-1:0];
  
  always @(posedge clock)begin
      y[0] <= Xin;
		y[1] <= y[0];
		y[2] <= y[1];
		y[3] <= y[2];
		y[4] <= y[3];
		y[5] <= y[4];
		y[6] <= y[5];
		y[7] <= (y[6]>>1)+Xin;
  end
endmodule

module filter3(input clock,
                input signed [W-1:0]Xin,
                output reg signed [W-1:0]Y);
    
  reg signed [W+H-1:0] y[N];
  reg signed [H-1:0] h[N];
  
  assign h[0] = -1;
  assign h[1] = 5;
  assign h[2] = 39;
  assign h[3] = 86;
  assign h[4] = 86;
  assign h[5] = 39;
  assign h[6] = 5;
  assign h[7] = -1;
  assign Y = y[N-1]>>H;
  
  always @(posedge clock)begin
      y[0] <= h[0]*Xin;
		for(int i = 1; i < N; i++)
		   y[i] <= y[i-1]+h[N-1-i]*Xin;
  end
endmodule

parameter N2 = 9;
module filter4(input clock,
                input signed [W-1:0]Xin,
                output reg signed [W-1:0]Y);
    
  reg signed [W+H-1:0] y[N2];
  reg signed [H-1:0] h[N2];
  
  assign h[0] = 0;
  assign h[1] = -4;
  assign h[2] = -22;
  assign h[3] = -50;
  assign h[4] = 192;
  assign h[5] = -50;
  assign h[6] = -22;
  assign h[7] = -4;
  assign h[8] = 0;
  assign Y = y[N2-1]>>H;
  
  always @(posedge clock)begin
      y[0] <= h[0]*Xin;
		for(int i = 1; i < N2; i++)
		   y[i] <= y[i-1]+h[N2-1-i]*Xin;
  end
endmodule

module playrec(
	input			CLOCK_50, reset,
	output	[21:0]	ram_addr,
	output	[15:0]	ram_data_in,
	output			ram_read, ram_write,
	input	[15:0]	ram_data_out,
	input			ram_valid, ram_waitrq,

	output	[15:0]	audio_out,
	input	[15:0]	audio_in,
	input			audio_out_allowed, audio_in_available,
	output			write_audio_out, read_audio_in,

	input			play, record, pause,
	input	[1:0]	speed,
	input [2:0] sel
);

reg signed [W-1:0] Y1, Y2, Y3, Y4, Y;
filter1 filter (.clock(CLOCK_50), .Xin(audio_in), .Y(Y1));
filter2 echo (.clock(CLOCK_50), .Xin(audio_in), .Y(Y2));
filter3 hc1 (.clock(CLOCK_50), .Xin(audio_in), .Y(Y3));
filter4 hc (.clock(CLOCK_50), .Xin(audio_in), .Y(Y4));

always @(sel)begin
  case(sel)
  0: Y = audio_in;
  1: Y = Y1;
  2: Y = Y2;
  3: Y = Y3;
  4: Y = Y4;
  default: Y = audio_in;
  endcase
end

// FSM for moving audio data to/from dram

reg [2:0] st, streg;

localparam	st_start = 0,
			st_rc_audio_wait = 1,
			st_rc_ram_nextaddr = 2,
			st_rc_ram_wait = 3,
			st_pl_ram_rd = 4,
			st_pl_audio_wait = 5,
			st_pl_ram_nextaddr = 6,
			st_input_check = 7;

always @(*) begin
	st = streg;
	case(streg)
		st_start: st = st_input_check;
		st_input_check:
			if(!pause)
				if(play) st = st_pl_audio_wait;
				else if(record) st = st_rc_audio_wait;
				else st = st_start;

		st_rc_audio_wait: if(audio_in_available) st = st_rc_ram_nextaddr;
		st_rc_ram_nextaddr: st = st_rc_ram_wait;
		st_rc_ram_wait: if(!ram_waitrq) st = st_input_check;

		st_pl_audio_wait: if(audio_out_allowed) st = st_pl_ram_rd;
		st_pl_ram_rd: if(!ram_waitrq && ram_valid) st = st_pl_ram_nextaddr; // Technically, this should be 2 states. The way it is, we might perform
																			// several reads from the same address, but it doesn't matter.
		st_pl_ram_nextaddr: st = st_input_check;
	endcase
end

always @(posedge CLOCK_50)
	if(reset) streg <= st_input_check;
	else streg <= st;


// Ram address counter
always @(posedge CLOCK_50)
	if(reset) ram_addr <= 0;
	else
		case(streg)
			st_start: ram_addr <= 0;
			st_rc_ram_nextaddr: ram_addr <= ram_addr + 1;
			st_pl_ram_nextaddr: ram_addr <= ram_addr + 1 + speed;
		endcase

// Connect the audio controller

assign read_audio_in = (streg == st_rc_ram_nextaddr) || (streg == st_start && audio_in_available);
assign write_audio_out = (st == st_pl_ram_nextaddr);

// Connect the dram

assign ram_data_in = Y;
assign audio_out = ram_data_out;

assign ram_write = (streg == st_rc_ram_wait);
assign ram_read = (streg == st_pl_ram_rd);


endmodule
	