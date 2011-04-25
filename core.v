//-----------------------------------------------------
// This is my first Verilog Program
// Design Name : hello_world
// File Name : hello_world.v
// Function : This program will print 'hello world'
// Coder    : Deepak
//-----------------------------------------------------

module fconsts();

	parameter PREFIX=4'b0000;
	parameter LOADAVAR=4'b0001;
	parameter LOADBVAR=4'b0010;
	parameter LOADALIT=4'b0011;
	parameter LOADBLIT=4'b0100;
	parameter STOREAVAR=4'b0101;
	parameter LOADAIND=4'b0110;
	parameter STOREBIND=4'b0111;
	parameter JUMP=4'b1000;
	parameter JUMPFALSE=4'b1001;
	parameter EQUALALIT=4'b1010;
	parameter ADDALIT=4'b1011;
	parameter ADJUST=4'b1100;
	parameter CALL=4'b1101;
	parameter OPERATE=4'b1110;

endmodule

module opconsts();

	parameter BOOT=4'b0000;
	parameter INPUT=4'b0001;
	parameter OUTPUT=4'b0010;
	parameter ALTERNATIVE=4'b0011;
	parameter GREATER=4'b0100;
	parameter SHIFTLEFT=4'b0101;
	parameter SHIFTRIGHT=4'b0110;
	parameter XORBITS=4'b0111;
	parameter ANDBITS=4'b1000;
	parameter ADD=4'b1001;
	parameter SUBTRACT=4'b1010;

endmodule

module processor(	input l0in, l1in, l2in, l3in,
					output 	l0out, l1out, l2out, l3out,
					input clk );


	// Local state for the process is the shift register for the channel end, and the channel
	// end signals. It also needs the link enable signals.

	// Each process has four link channel ends, so therefore needs four shift registers

	reg [7:0] link0shiftreg, link1shiftreg, link2shiftreg, link3shiftreg;

	// Each channel end produces a ready output signal, derived directly from two inputs
	// Each channel end has an "in" and an "out" which are derived from the shift reg
	// Each channel end has a sync input

	wire link0ready, link1ready, link2ready, link3ready;
	
	// All those signals need to be sent to the processor. The link enable signals are generated
	// locally, and are mainly used for the implementation of ALT

	reg[3:0] linkselect;
	reg sync0, sync1, sync2, sync3;

	assign link0ready = sync0 & (!(l0in&linkselect[0]));
	assign link1ready = sync1 & (!(l1in&linkselect[1]));
	assign link2ready = sync2 & (!(l2in&linkselect[2]));
	assign link3ready = sync3 & (!(l3in&linkselect[3]));

	assign l0out = linkselect[0] & (sync0 | link0shiftreg[0]);
	assign l1out = linkselect[1] & (sync1 | link1shiftreg[0]);
	assign l2out = linkselect[2] & (sync2 | link2shiftreg[0]);
	assign l3out = linkselect[3] & (sync3 | link3shiftreg[0]);

	wire running;

	reg[7:0] iptr, wptr;
	reg[7:0] areg, breg;
	reg[7:0] instruction;
	reg[3:0] funct, oper;
	reg[7:0] mem [255:0];

	reg[3:0] clocking;
	reg[3:0] count;

	initial begin
		mem[0] <= opconsts.BOOT;
		iptr <= 0;
		oper <= 0;
		count <= 0;
		link0shiftreg <= 0;
		link1shiftreg <= 0;
		link2shiftreg <= 0;
		link3shiftreg <= 0;
		linkselect <= 0;
		sync0 <= 0;
		sync1 <= 0;
		sync2 <= 0;
		sync3 <= 0;
		clocking <= 0;
		count <= 0;
	end

	assign running = (!(sync0 | sync1 | sync2 | sync3)) & (!(|clocking)) & clk;

	always @ (posedge (sync0 & clk))
	begin
		if (link0ready)
		begin
			clocking <= 1;
			sync0 <= 0;
		end
	end

	always @ (posedge (sync1 & clk))
	begin
		if (link1ready)
		begin
			clocking <= 2;
			sync1 <= 0;
		end
	end

	always @ (posedge (sync2 & clk))
	begin
		if (link2ready)
		begin
			clocking <= 4;
			sync2 <= 0;
		end
	end

	always @ (posedge (sync3 & clk))
	begin
		if (link3ready)
		begin
			clocking <= 8;
			sync3 <= 0;
		end
	end

	always @ (posedge clk)
	begin
		if (running)
		begin
			instruction <= mem[iptr];
			iptr <= iptr + 1;
			funct <= instruction & 8'hF0;
			oper <= (instruction & 8'h0F) | oper;
			$display("Instruction: %b", instruction);

			if (funct == fconsts.PREFIX) 
				oper <= oper << 4;
			else
			begin
				if (funct == fconsts.LOADAVAR)
					areg <= mem[wptr + oper];
				else if (funct == fconsts.LOADBVAR)
					breg <= mem[wptr + oper];
				else if (funct == fconsts.LOADALIT)
					areg <= oper;
				else if (funct == fconsts.LOADBLIT)
					breg <= oper;
				else if (funct == fconsts.STOREAVAR)
					mem[wptr + oper] <= areg;
				else if (funct == fconsts.LOADAIND)
					areg <= mem[areg + oper];
				else if (funct == fconsts.STOREBIND)
					mem[areg + oper] <= breg;
				else if (funct == fconsts.JUMP)
					iptr <= iptr + oper;
				else if (funct == fconsts.JUMPFALSE)
					begin
						if (areg == 0)
							iptr <= iptr + oper;
					end
				else if (funct == fconsts.EQUALALIT)
					areg <= (areg == oper) ? 1 : 0;
				else if (funct == fconsts.ADDALIT)
					areg <= areg + oper;
				else if (funct == fconsts.ADJUST)
					wptr <= wptr + oper;
				else if (funct == fconsts.CALL)
					begin
						areg <= iptr;
						iptr <= iptr + oper;
					end
				else if(funct == fconsts.OPERATE)
					begin
						if (oper == opconsts.INPUT)
							begin
								if (areg == 0)
								begin
									// Enable l0 (select)
									linkselect <= 1;
									// Enable sync
									sync0 <= 1;
									// This now polls the ready signal
								end
								else if (areg == 1)
								begin
									linkselect <= 2;
									sync1 <= 1;
								end
								else if (areg == 2)
								begin
									linkselect <= 4;
									sync2 <= 1;
								end
								else // if (areg == 3)
								begin
									linkselect <= 8;
									sync3 <= 1;
								end
							end
						else if (oper == opconsts.OUTPUT)
							begin
								if (areg == 1)
								begin
									link0shiftreg <= breg;
									linkselect <= 1;
									sync0 <= 1;
								end
								else if (areg == 2)
								begin
									link1shiftreg <= breg;
									linkselect <= 2;
									sync1 <= 1;
								end
								else if (areg == 4)
								begin
									link2shiftreg <= breg;
									linkselect <= 4;
									sync2 <= 1;
								end
								else // if (areg == 8)
								begin
									link3shiftreg <= breg;
									linkselect <= 8;
									sync3 <= 1;
								end
							end
						else if (oper == opconsts.ALTERNATIVE)
							; // TODO
						else if (oper == opconsts.GREATER)
							areg <= (areg > breg) ? 1 : 0;
						else if (oper == opconsts.SHIFTLEFT)
							areg <= areg << breg;
						else if (oper == opconsts.SHIFTRIGHT)
							areg <= areg >> breg;
						else if (oper == opconsts.XORBITS)
							areg <= areg ^ breg;
						else if (oper == opconsts.ANDBITS)
							areg <= areg & breg;
						else if (oper == opconsts.ADD)
							areg <= areg + breg;
						else if (oper == opconsts.SUBTRACT)
							areg <= areg - breg;
						else if (oper == opconsts.BOOT)
							; // TODO
					end
				oper <= 0;
			end
		end
		else if (|clocking)
		begin
			if (clocking==1)
			begin
				count <= count + 1;
				link0shiftreg[6:0] <= link0shiftreg[7:1];
				link0shiftreg[7] <= !(l0in&linkselect[0]);
			end
			else if (clocking==2)
			begin
				count <= count + 1;
				link1shiftreg[6:0] <= link1shiftreg[7:1];
				link1shiftreg[7] <= !(l1in&linkselect[1]);
			end
			else if (clocking==4)
			begin
				count <= count + 1;
				link2shiftreg[6:0] <= link2shiftreg[7:1];
				link2shiftreg[7] <= !(l2in&linkselect[2]);
			end
			else // if (clocking==8)
			begin
				count <= count + 1;
				link3shiftreg[6:0] <= link3shiftreg[7:1];
				link3shiftreg[7] <= !(l3in&linkselect[3]);
			end
			if (count == 8)
			begin
				// TODO NOTE, this replaces the output of areg after an output operation - prob not
				// intended behaviour
				clocking <= 0;
				count <= 0;
				areg <= (	linkselect[0] ? link0shiftreg : 
						 	linkselect[1] ? link1shiftreg :
						 	linkselect[2] ? link2shiftreg :
						 	linkselect[3] ? link3shiftreg : 0);
				linkselect <= 0;
			end
		end
	end

endmodule

module main();

  reg clk = 0;
  always #10 clk = !clk;

  wire l0a, l0b, l1a, l1b, l2a, l2b, l3a, l3b;

  processor pa(	l0a, l1a, l2a, l3a,
  				l0b, l1b, l2b, l3b, 
  				clk );
  				  
  processor pb(	l0b, l1b, l2b, l3b,
  				l0a, l1a, l2a, l3a, 
  				clk );

endmodule
