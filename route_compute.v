/*
 * route_compute.v
 *
 * Combinational X-Y dimension-order routing for the Project Chiron MVP.
 *
 * Flit format:
 *   [33:32] type: 2'b11 = SINGLE/AER (supported by this MVP)
 *   [31:28] destination X
 *   [27:24] destination Y
 *   [23:0]  payload / axon_id (unused by route computation)
 *
 * Port indices per the microarchitectural spec:
 *   Local=0, North=1, South=2, East=3, West=4.
 *
 * HEAD/BODY/TAIL are intentionally unsupported in the single-flit MVP.
 */

module route_compute #(
    parameter [3:0] CURRENT_X = 4'd0,
    parameter [3:0] CURRENT_Y = 4'd0,

    parameter [2:0] PORT_N = 3'd1,
    parameter [2:0] PORT_S = 3'd2,
    parameter [2:0] PORT_E = 3'd3,
    parameter [2:0] PORT_W = 3'd4,
    parameter [2:0] PORT_L = 3'd0
) (
    input  wire [33:0] flit_in,
    input  wire        flit_valid,
    output reg  [4:0]  output_control,
    output reg         route_valid
);

    localparam [4:0] OUT_N = 5'b00001 << PORT_N;
    localparam [4:0] OUT_S = 5'b00001 << PORT_S;
    localparam [4:0] OUT_E = 5'b00001 << PORT_E;
    localparam [4:0] OUT_W = 5'b00001 << PORT_W;
    localparam [4:0] OUT_L = 5'b00001 << PORT_L;

    wire [1:0] flit_type = flit_in[33:32];
    wire [3:0] dest_x    = flit_in[31:28];
    wire [3:0] dest_y    = flit_in[27:24];

    always @* begin
        output_control = 5'b00000;
        route_valid    = 1'b0;

        if (flit_valid && (flit_type == 2'b11)) begin
            // X dimension has priority: finish East/West movement first.
            if (dest_x > CURRENT_X)
                output_control = OUT_E;
            else if (dest_x < CURRENT_X)
                output_control = OUT_W;
            else if (dest_y > CURRENT_Y)
                output_control = OUT_S;
            else if (dest_y < CURRENT_Y)
                output_control = OUT_N;
            else
                output_control = OUT_L;

            route_valid = 1'b1;
        end
    end

endmodule
