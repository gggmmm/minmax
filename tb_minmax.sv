// Testbench for the minmax module
// Uncomment the define DEBUG to have a some informative output in the console.
// Adjust parameter NUM_TESTS to increase/decrease number of tests. Each test is carried out both for
// min and max search. Therefore, a total of NUM_TESTS * 2 will be carried out.

`timescale 1ns / 1ns

// `define DEBUG

module tb_minmax();

    localparam integer W            = 8;
    localparam integer NI           = 9;
    localparam integer OUT_CFG      = 0; // 0= output both value and index, 1= only value
    localparam integer MM_CFG       = 0; // 0= support both min/max,        1= only min,    2= only max
    localparam integer IDXW         = $clog2(NI);
    localparam integer NUM_TESTS    = 500;

    logic [W-1:0] x [NI];
    logic min_max_sel;
    logic [W-1:0] result;
    logic [IDXW-1:0] index;

    minmax #(.W(W), .NI(NI), .IDXW(IDXW), .OUT_CFG(OUT_CFG), .MM_CFG(MM_CFG)) u_DUT (.*);

    time del = 1ns;
    initial begin
        static int errorminu = 0, errormaxu = 0;

        logic [W-1:0] min, max, idxmin, idxmax;

        automatic int mm_num_loops = MM_CFG==0 ? 2 : 1;

        for( int h=0; h < mm_num_loops; h++) begin
            if(MM_CFG==0)
                min_max_sel = h;
            else
                min_max_sel = MM_CFG == 1 ? 0 : 1;

            for( int j = 0; j < NUM_TESTS; j++ ) begin
                `ifdef DEBUG $display("== TEST ",j," =="); `endif

                min = 2**W-1;
                max = 0;
                idxmin = 0;
                idxmax = 0;
                for( int k=0; k < NI; k++ ) begin
                    x[k] = $urandom_range(2**W-1, 0);

                    `ifdef DEBUG
                            $display("%d %d", x[k], k);
                    `endif

                    if(x[k] > max) begin
                        max = x[k];
                        idxmax = k;
                    end
                    if(x[k] < min) begin
                        min = x[k];
                        idxmin = k;
                    end
                end

                #del;

                if(min_max_sel==1'b0) begin // min
                    assert(result == min && ((OUT_CFG == 0) && index == idxmin) || (OUT_CFG == 1))
                        `ifndef DEBUG
                            else errorminu++;
                        `else
                                $display("PASS");
                            else begin
                                $display("FAIL"); $display("result: ", result, " index: ", index, " min: ", min, " idxmin: ", idxmin); errorminu++;
                            end
                        `endif
                end else begin // max
                    assert(result == max && ((OUT_CFG == 0) && index == idxmax) || (OUT_CFG == 1))
                        `ifndef DEBUG
                            else errormaxu++;
                        `else
                                $display("PASS");
                            else begin
                                $display("FAIL"); $display("result: ", result, " index: ", index, " max: ", max, " idxmax: ", idxmax); errormaxu++;
                            end
                        `endif
                end
            end
        end

        if(MM_CFG==0 || MM_CFG==1)
                $display("MIN - ERRORS ", errorminu, "/", NUM_TESTS);

        if(MM_CFG==0 || MM_CFG==2)
                $display("MAX - ERRORS ", errormaxu, "/", NUM_TESTS);
    end

endmodule
