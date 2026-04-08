`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 15.01.2024 19:56:12
// Design Name: 
// Module Name: round
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module round37to32(
    input [36:0] i_data,
    output [31:0] o_data
    );

    parameter IWID = 37,
              OWID = 32; 
              
    wire [(IWID-1):0] w_convergent;   

assign	w_convergent = i_data[(IWID-1):0]
			+ { {(OWID){1'b0}},
				i_data[(IWID-OWID)],
				{(IWID-OWID-1){!i_data[(IWID-OWID)]}}};
	
assign o_data = w_convergent[(IWID-1):(IWID-OWID)];
	
endmodule
