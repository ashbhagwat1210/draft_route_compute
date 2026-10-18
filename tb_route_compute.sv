`timescale 1ns/1ps

module tb_route_compute;

    logic [33:0] flit_in;
    logic        flit_valid;

    wire [4:0] output_control;
    wire       route_valid;

    // Split fields are exposed as separate signals to make inspection easier
    logic [1:0]  flit_type;
    logic [3:0]  dest_x;
    logic [3:0]  dest_y;
    logic [23:0] payload;

    logic [4:0] expected_port;
    logic       expected_valid;
    logic       test_failed;

    int test_number = 0;
    int errors = 0;

    // Port mapping
    // Local=0, North=1, South=2, East=3, West=4.
    // These are one-hot masks, not port indices.

    localparam logic [4:0] NORTH = 5'b00010;
    localparam logic [4:0] SOUTH = 5'b00100;
    localparam logic [4:0] EAST  = 5'b01000;
    localparam logic [4:0] WEST  = 5'b10000;
    localparam logic [4:0] LOCAL = 5'b00001;
    localparam logic [4:0] NONE  = 5'b00000;

    // Assembly of the 34-bit flit: type[33:32], X[31:28], Y[27:24],
    // and payload[23:0].
    assign flit_in = {flit_type, dest_x, dest_y, payload};

    // This testbench checks the router located at coordinate (1,1).
    // The same routing logic must be parameterized with each router's
    // CURRENT_X/CURRENT_Y when used in the full 2x2 mesh.
    route_compute #(
        .CURRENT_X(4'd1),
        .CURRENT_Y(4'd1),

        .PORT_N(3'd1),
        .PORT_S(3'd2),
        .PORT_E(3'd3),
        .PORT_W(3'd4),
        .PORT_L(3'd0)
    ) dut (
        .flit_in(flit_in),
        .flit_valid(flit_valid),
        .output_control(output_control),
        .route_valid(route_valid)
    );

    // Additional router instances let the same input flit be checked at
    // every physical coordinate in the 2x2 mesh.
    wire [4:0] output_control_00, output_control_10, output_control_01;
    wire       route_valid_00, route_valid_10, route_valid_01;

    route_compute #(.CURRENT_X(4'd0), .CURRENT_Y(4'd0)) dut_00 (
        .flit_in(flit_in), .flit_valid(flit_valid),
        .output_control(output_control_00), .route_valid(route_valid_00)
    );

    route_compute #(.CURRENT_X(4'd1), .CURRENT_Y(4'd0)) dut_10 (
        .flit_in(flit_in), .flit_valid(flit_valid),
        .output_control(output_control_10), .route_valid(route_valid_10)
    );

    route_compute #(.CURRENT_X(4'd0), .CURRENT_Y(4'd1)) dut_01 (
        .flit_in(flit_in), .flit_valid(flit_valid),
        .output_control(output_control_01), .route_valid(route_valid_01)
    );

    // Apply one inpt case, wait for combinational logic to settle, and
    // compare both the one-hot output request and route_valid against expected
    // values.
    task automatic check_route(
        input logic        next_valid,
        input logic [1:0]  next_type,
        input logic [3:0]  next_x,
        input logic [3:0]  next_y,
        input logic [23:0] next_payload,
        input logic [4:0]  next_expected,
        input string       test_name
    );
        begin
            test_number++;

            flit_valid     = next_valid;
            flit_type      = next_type;
            dest_x         = next_x;
            dest_y         = next_y;
            payload        = next_payload;
            expected_port  = next_expected;
            expected_valid = |next_expected;
            test_failed    = 1'b0;

            #1; // Allow the combinational route_compute outputs to settle.

            test_failed =
                (output_control !== expected_port) ||
                (route_valid !== expected_valid);

            if (test_failed) begin
                errors++;

                $display(
                    "FAIL test %0d [%s]: expected=%b actual=%b valid=%b",
                    test_number, test_name,
                    expected_port, output_control, route_valid
                );
            end
            else begin
                $display("PASS test %0d [%s]",
                         test_number, test_name);
            end

            #19; // Keep this case visible for a total of 20 ns.
        end
    endtask

    // Check an additional router instance using the same input case.
    // These checks contribut to the same test/error counters as check_route.
    task automatic check_other_router(
        input logic [4:0] actual_port,
        input logic       actual_valid,
        input logic [4:0] expected,
        input logic       exp_valid,
        input string      router_name,
        input string      case_name
    );
        begin
            test_number++;
            if ((actual_port !== expected) ||
                (actual_valid !== exp_valid)) begin
                errors++;
                $display(
                    "FAIL test %0d [%s - %s]: expected=%b actual=%b valid=%b",
                    test_number, router_name, case_name,
                    expected, actual_port, actual_valid
                );
            end else begin
                $display("PASS test %0d [%s - %s]",
                         test_number, router_name, case_name);
            end
        end
    endtask

    initial begin
        $dumpfile("route_compute.vcd");
        $dumpvars(0, tb_route_compute);

        // Initialize every testbench-driven signal to a known value.
        flit_valid     = 0;
        flit_type      = 0;
        dest_x         = 0;
        dest_y         = 0;
        payload        = 0;
        expected_port  = NONE;
        expected_valid = 0;
        test_failed    = 0;

        #20; // Initial quiet period before the first test.

        // Current router is (1,1).
        // TEST 1 - East: dest_x > CURRENT_X, so the router requests East.
        check_route(1, 2'b11, 4'd2, 4'd1, 24'd1, EAST,
                    "East");

        // TEST 2 - West: dest_x < CURRENT_X, so the router requests West.
        check_route(1, 2'b11, 4'd0, 4'd1, 24'd2, WEST,
                    "West");

        // TEST 3 - South: X matches; dest_y > CURRENT_Y.
        // The document defines increasing Y as movement toward South.
        check_route(1, 2'b11, 4'd1, 4'd2, 24'd3, SOUTH,
                    "South");

        // TEST 4 - North: X matches; dest_y < CURRENT_Y.
        check_route(1, 2'b11, 4'd1, 4'd0, 24'd4, NORTH,
                    "North");

        // TEST 5 - Local: destination equals this router's (1,1) coordinate.
        check_route(1, 2'b11, 4'd1, 4'd1, 24'd5, LOCAL,
                    "Local");

        // TEST 6 - X/Y priority toward East: both X and Y differ.
        // Expected East demonstrates that X routing takes priority over Y.
        check_route(1, 2'b11, 4'd2, 4'd0, 24'd0, EAST,
                    "X priority: East before North");

        // TEST 7 - X/Y priority toward West: both X and Y differ.
        // Expected West demonstrates that X routing takes priority over Y.
        check_route(1, 2'b11, 4'd0, 4'd2, 24'd0, WEST,
                    "X priority: West before South");

        // TEST 8 - Zero payload: route selection should depend on the
        // destination and flit type, not on the payload value.
        check_route(1, 2'b11, 4'd2, 4'd1, 24'h000000, EAST,
                    "Zero payload");

        // TEST 9 - All-one payload: verify that all payload bits being 1
        // does not change the route selected for the same destination.
        check_route(1, 2'b11, 4'd2, 4'd1, 24'hffffff, EAST,
                    "All-one payload");

        // TEST 10 - Invalid FIFO entry: flit_valid=0 must suppress routing,
        // even though the encoded flit type is SINGLE/AER.
        check_route(0, 2'b11, 4'd2, 4'd1, 24'd0, NONE,
                    "Invalid FIFO entry");

        // TEST 11 - HEAD type (01): unsupported by this single-flit MVP.
        // Expected: no request and route_valid=0.
        check_route(1, 2'b01, 4'd2, 4'd1, 24'd0, NONE,
                    "HEAD ignored");

        // TEST 12 - BODY type (00): unsupported by this single-flit MVP.
        check_route(1, 2'b00, 4'd2, 4'd1, 24'd0, NONE,
                    "BODY ignored");

        // TEST 13 - TAIL type (10): unsupported by this single-flit MVP.
        check_route(1, 2'b10, 4'd2, 4'd1, 24'd0, NONE,
                    "TAIL ignored");

        // TEST 14 - Recovery: after invalid/unsupported inputs, a valid
        // SINGLE/AER flit addressed locally should route to Local normally.
        check_route(1, 2'b11, 4'd1, 4'd1, 24'd0, LOCAL,
                    "Recovery to valid AER");


        // ADDITIONAL TESTS - other router positions.
        // The original 14 tests above are retained exactly. The following
        // cases check all four legal destinations at (0,0), (1,0), and (0,1)

        // Destination (0,0): R(0,0)=Local, R(1,0)=West, R(0,1)=North.
        flit_valid = 1'b1;
        flit_type  = 2'b11;
        dest_x     = 4'd0;
        dest_y     = 4'd0;
        payload    = 24'h000001;
        #1;
        check_other_router(output_control_00, route_valid_00, LOCAL, 1'b1,
                           "R(0,0)", "destination (0,0) Local");
        check_other_router(output_control_10, route_valid_10, WEST, 1'b1,
                           "R(1,0)", "destination (0,0) West");
        check_other_router(output_control_01, route_valid_01, NORTH, 1'b1,
                           "R(0,1)", "destination (0,0) North");
        check_other_router(output_control, route_valid, WEST, 1'b1,
                           "R(1,1)", "destination (0,0) X priority");

        // Destination (1,0): R(0,0)=East, R(1,0)=Local, R(0,1)=East
        // because X has priority over Y.
        dest_x  = 4'd1;
        dest_y  = 4'd0;
        payload = 24'h000002;
        #1;
        check_other_router(output_control_00, route_valid_00, EAST, 1'b1,
                           "R(0,0)", "destination (1,0) East");
        check_other_router(output_control_10, route_valid_10, LOCAL, 1'b1,
                           "R(1,0)", "destination (1,0) Local");
        check_other_router(output_control_01, route_valid_01, EAST, 1'b1,
                           "R(0,1)", "destination (1,0) X priority");
        check_other_router(output_control, route_valid, NORTH, 1'b1,
                           "R(1,1)", "destination (1,0) North");

        // Destination (0,1): R(0,0)=South, R(1,0)=West, R(0,1)=Local.
        dest_x  = 4'd0;
        dest_y  = 4'd1;
        payload = 24'h000003;
        #1;
        check_other_router(output_control_00, route_valid_00, SOUTH, 1'b1,
                           "R(0,0)", "destination (0,1) South");
        check_other_router(output_control_10, route_valid_10, WEST, 1'b1,
                           "R(1,0)", "destination (0,1) X priority");
        check_other_router(output_control_01, route_valid_01, LOCAL, 1'b1,
                           "R(0,1)", "destination (0,1) Local");
        check_other_router(output_control, route_valid, WEST, 1'b1,
                           "R(1,1)", "destination (0,1) X priority");

        // Destination (1,1): R(0,0)=East, R(1,0)=South, R(0,1)=East.
        dest_x  = 4'd1;
        dest_y  = 4'd1;
        payload = 24'h000004;
        #1;
        check_other_router(output_control_00, route_valid_00, EAST, 1'b1,
                           "R(0,0)", "destination (1,1) X priority");
        check_other_router(output_control_10, route_valid_10, SOUTH, 1'b1,
                           "R(1,0)", "destination (1,1) South");
        check_other_router(output_control_01, route_valid_01, EAST, 1'b1,
                           "R(0,1)", "destination (1,1) X priority");
        check_other_router(output_control, route_valid, LOCAL, 1'b1,
                           "R(1,1)", "destination (1,1) Local");

        // Invalid FIFO entry must suppress requests at all three additional
        // router positions, not just the original (1,1) instance.
        flit_valid = 1'b0;
        #1;
        check_other_router(output_control_00, route_valid_00, NONE, 1'b0,
                           "R(0,0)", "invalid FIFO entry");
        check_other_router(output_control_10, route_valid_10, NONE, 1'b0,
                           "R(1,0)", "invalid FIFO entry");
        check_other_router(output_control_01, route_valid_01, NONE, 1'b0,
                           "R(0,1)", "invalid FIFO entry");

        // Unsupported HEAD, BODY and TAIL flits must not create requests at
        // any additional router position.
        flit_valid = 1'b1;
        flit_type = 2'b01;
        #1;
        check_other_router(output_control_00, route_valid_00, NONE, 1'b0,
                           "R(0,0)", "HEAD unsupported");
        check_other_router(output_control_10, route_valid_10, NONE, 1'b0,
                           "R(1,0)", "HEAD unsupported");
        check_other_router(output_control_01, route_valid_01, NONE, 1'b0,
                           "R(0,1)", "HEAD unsupported");

        flit_type = 2'b00;
        #1;
        check_other_router(output_control_00, route_valid_00, NONE, 1'b0,
                           "R(0,0)", "BODY unsupported");
        check_other_router(output_control_10, route_valid_10, NONE, 1'b0,
                           "R(1,0)", "BODY unsupported");
        check_other_router(output_control_01, route_valid_01, NONE, 1'b0,
                           "R(0,1)", "BODY unsupported");

        flit_type = 2'b10;
        #1;
        check_other_router(output_control_00, route_valid_00, NONE, 1'b0,
                           "R(0,0)", "TAIL unsupported");
        check_other_router(output_control_10, route_valid_10, NONE, 1'b0,
                           "R(1,0)", "TAIL unsupported");
        check_other_router(output_control_01, route_valid_01, NONE, 1'b0,
                           "R(0,1)", "TAIL unsupported");

        // Final result includes original tests and all added checks.
        if (errors != 0)
            $fatal(1, "FAIL: %0d of %0d tests failed.", errors, test_number);

        $display("PASS: All %0d tests passed.", test_number);
        $finish;
    end

endmodule
