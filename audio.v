module audio(

input CLOCK_50, reset,
input [15:0] aout,
output reg [15:0] ain,
output reg aout_avail, ain_new,

input			AUD_ADCLRCK,			//	Audio CODEC ADC LR Clock
input			AUD_ADCDAT,				//	Audio CODEC ADC Data
input			AUD_DACLRCK,			//	Audio CODEC DAC LR Clock
output			AUD_DACDAT,				//	Audio CODEC DAC Data
input			AUD_BCLK,				//	Audio CODEC Bit-Stream Clock
output			AUD_XCK 				//	Audio CODEC Chip Clock
);


reg [15:0] sr_out, sr_in;	// Shift registers
reg [7:0] cnt_in, cnt_out;	// Counters

reg sync;


// Shift register to DAC.
// We have data for only 1 channel, so spin it twice
always @(negedge AUD_BCLK)
	if(reset) sr_out <= 0;
	else sr_out <= sync ? aout : {sr_out[14:0], sr_out[15]};

assign AUD_DACDAT = sr_out[15];

// Get the sync signal which is valid on the posedge
always @(posedge AUD_BCLK) sync <= AUD_DACLRCK;

// Output counter
always @(posedge AUD_BCLK)
	if(reset || AUD_DACLRCK) cnt_out <= 0;
	else if(cnt_out < 32) cnt_out <= cnt_out + 1;

// Generate the aout_avail signal
reg [1:0] ao;
always @(posedge CLOCK_50)
	if(reset) ao <= 0;
	else ao <= {ao[0], (cnt_out == 32)};

assign aout_avail = (ai == 2'b01);


// Shift register from ADC
always @(posedge AUD_BCLK)
	if(reset) sr_in <= 0;
	else if(cnt_in < 16) sr_in <= {sr_in[14:0], AUD_ADCDAT};

// Input counter
always @(posedge AUD_BCLK)
	if(reset || AUD_ADCLRCK) cnt_in <= 0;
	else if(cnt_in < 16) cnt_in <= cnt_in + 1;

// Generate the ain_new signal
reg [1:0] ai;
always @(posedge CLOCK_50)
	if(reset) ai <= 0;
	else ai <= {ai[0], (cnt_in == 16)};

assign ain_new = (ai == 2'b01);

// Register ain to make sure it's always valid
always @(posedge CLOCK_50)
	if(reset) ain <= 0;
	else if(cnt_in == 16) ain <= sr_in;


// Generate clock for audio chip

reg [1:0] xck;

always @(posedge CLOCK_50) xck++;

assign AUD_XCK = xck[1];

endmodule
