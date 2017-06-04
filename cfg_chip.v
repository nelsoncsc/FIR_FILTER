module cfg_chip(input clock50, start, output i2c_c, done, inout i2c_d);

	// Shift register holding all the config data
	reg [0:15] data [0:mcount-1];
	parameter addr = 8'b00110100;

	// Run I2C bus clock @ 50Mhz/256 = ~200kHz
	reg [7:0] counter;
	assign i2c_c = counter[7];
	wire fsm_c = counter[6];
	always @ (posedge clock50, posedge start) counter <= start?0:counter+1;

	// Master FSM, runs at twice the bus clock to handle start/stop conditions
	reg [2:0] mst = ms_init;
	localparam ms_start = 0, ms_send = 1, ms_stop = 4, ms_ack = 3, ms_done = 2, ms_init = 5, mcount = 9;

	reg error; // If high, chip failed to ack the data, so restart everything
	reg [3:0] bout, mout;
	reg [1:0] wout;
	reg [0:23] sout; // Current word to be shifted out

	always @(posedge fsm_c, posedge start) // Every posedge is in the _middle_ of the bus clock level
		if(start) begin
			mst <= ms_init;
			i2c_d <= 1'bz;
		end else
			case (mst)
				ms_init: begin
					mst <= ms_start;
					data[0] <= 16'h1e00; // reset
					data[1] <= 16'h0c00; // power up all subcircuits
					data[2] <= 16'h0a00; // DAC no mute, ADC HPF
					data[3] <= 16'h0e53; // DSP mode, data on 2nd edge of bclk
					data[4] <= 16'h0814; // mic to ADC, enable DAC
					data[5] <= 16'h0579; // output volume, 0dB
					data[6] <= 16'h0117; // input volume, 0dB
					data[7] <= 16'h1000; // normal mode, 48kHz in/out
					data[8] <= 16'h1201; // Activate data interface
					mout <= 0;
				end
				ms_start: // Generate start condition
					if(i2c_c) begin // Wait until we're in the middle of the high bus clock level
						i2c_d <= 0;
						mst <= ms_send;
						bout <= 0;
						wout <= 0;
						error <= 0;
						sout <= {addr, data[mout]};
					end
				ms_send:
					if(!i2c_c) // Only shift-out when bus clock is low, preparing for the next posedge
						if(bout == 8) begin
							mst <= ms_ack;
							i2c_d <= 1'bz;
						end else begin
							i2c_d <= sout[0]?1'bz:0;
							sout <= sout << 1;
							bout <= bout + 1;
						end
				ms_ack: // Guaranteed to enter this on the high bus clock, data must be low if ack'd
					if(i2c_d == 0) begin  // All good, keep sending or stop if done
						mst <= (wout == 2)?ms_stop:ms_send;
						wout <= wout + 1;
						bout <= 0;
					end else begin // Not ack'd
						error <= 1;
						mst <= ms_stop;
					end
				ms_stop:
					if(i2c_c == 0) i2c_d <= 0;
					else begin
						i2c_d <= 1'bz;
						mst <= (error || (mout < mcount-1))?ms_start:ms_done;
						if(!error) mout <= mout + 1;
					end
				ms_done: i2c_d <= 1'bz;
			endcase

	assign done = (mst == ms_done);
endmodule
