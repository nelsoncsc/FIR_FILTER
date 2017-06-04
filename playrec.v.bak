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
	input	[1:0]	speed
);

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

assign ram_data_in = audio_in;
assign audio_out = ram_data_out;

assign ram_write = (streg == st_rc_ram_wait);
assign ram_read = (streg == st_pl_ram_rd);


endmodule
