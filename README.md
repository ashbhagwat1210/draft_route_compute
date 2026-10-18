route_compute.v
This module implements combinational X–Y dimension-order routing for the Project Chiron 2×2 NoC mesh MVP
It determines the next-hop output port based on the current router coordinates and the destination coordinates. X-direction routing (East/West) is prioritised over Y-direction routing (North/South). Flits addressed to the current router are directed to the Local port.
The module supports SINGLE/AER flits (type 2'b11) and rejects invalid flits and unsupported HEAD, BODY and TAIL types (applicable for the MVP)
The 34-bit flit format consists of a 2-bit type field, 4-bit destination X, 4-bit destination Y and 24-bit payload/Axon ID (used the same one as the doc)


tb_route_compute.sv
these tests were performed thru the testbench: 

1. Basic routing in the East, West, North, South and Local directions.
2. X–Y routing priority when both destination coordinates differ.
3. Payload independence using zero and all-one payloads 
4. Invalid FIFO entry handling when flit_valid is low.
5. Rejection of unsupported HEAD, BODY and TAIL flit types (for the MVP, since we have single ones only)
6. Recovery to valid routing after invalid or unsupported inputs. 
7. Routing decisions for all four legal destinations from all four router positions in the 2×2 mesh.
8. Invalid flit and unsupported flit-type handling across multiple router positions.

tests passed

