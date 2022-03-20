// Testbench for the minmax module
// Uncomment the define DEBUG to have a some informative output in the console.
// Adjust parameter NUM_TESTS to increase/decrease number of tests. Each test is carried out both for
// signed and unsigned casese as well as min and max search. Therefore, a total of
// NUM_TESTS * 2 * 2 will be carried out.

`timescale 1ns / 1ns

//`define DEBUG

module tb_minmax();

    localparam integer W            = 12;
    localparam integer NI           = 9;
    localparam integer CFG          = 0; // 0= output both value and index, 1= only value
    localparam integer IDXW         = $clog2(NI);
    localparam integer NUM_TESTS    = 1250; // test will take NUM_TESTS*del*2*2 ns to complete

    logic [NI*W-1 : 0] x;
    logic us_sel, min_max_sel;
    logic [W-1:0] result;
    logic [IDXW-1:0] index;

    minmax #(.W(W), .NI(NI), .IDXW(IDXW), .CFG(CFG)) u_DUT (.*);

    time del = 1ns;
    initial begin
        static int error = 0;

        logic [W-1:0]       ar;
        logic [NI*W-1 : 0]  arand;
        logic [W-1:0]       min, max, idxmin, idxmax;

        for (int i = 0; i < 2; i++) begin
            if (i==0)
                us_sel = 1'b0; // 0 unsigned,
            else
                us_sel = 1'b1; // 1 signed

            for( int j = 0; j < NUM_TESTS; j++ ) begin
                `ifdef DEBUG $display("== TEST ",j," =="); `endif

                arand = '0;
                if( us_sel == 1'b1 ) begin
                    min = 2**(W-1)-1;
                    max = -2**(W-1);
                end else begin
                    min = 2**W-1;
                    max = -2**W;
                end
                idxmin = 0;
                idxmax = 0;
                for( int k=0; k < NI; k++ ) begin
                    ar = $urandom_range(2**W-1, 0);

                    `ifdef DEBUG
                        if( us_sel == 1'b1 )
                            $display("%d %d", $signed(ar), NI-k-1);
                        else
                            $display("%d %d", $unsigned(ar), NI-k-1);
                    `endif

                    arand = {arand, ar};

                    if( us_sel == 1'b1 ) begin
                        if($signed(ar) >= $signed(max)) begin
                            // update the index if they are equal and the new one is smaller than the previous. 
                            // in case there are two equal values, hardware "picks" always the smallest index, 
                            // as a side effect of its implementation
                            if($signed(ar) == $signed(max) && NI-k-1 < idxmax)
                                idxmax = NI-k-1;
                            else
                                idxmax = NI-k-1;
                            max = $signed(ar);
                        end
                        if($signed(ar) <= $signed(min)) begin
                            // update the index if they are equal and the new one is smaller than the previous. 
                            // in case there are two equal values, hardware "picks" always the smallest index, 
                            // as a side effect of its implementation
                            if($signed(ar) == $signed(min) && NI-k-1 < idxmin)
                                idxmin = NI-k-1;
                            else
                                idxmin = NI-k-1;
                            min = $signed(ar);
                        end
                    end else begin
                        if($unsigned(ar) >= $unsigned(max)) begin
                            // update the index if they are equal and the new one is smaller than the previous. 
                            // in case there are two equal values, hardware "picks" always the smallest index, 
                            // as a side effect of its implementation
                            if($unsigned(ar) == $unsigned(max) && NI-k-1 < idxmax)
                                idxmax = NI-k-1;
                            else
                                idxmax = NI-k-1;
                            max = $unsigned(ar);
                        end
                        if($unsigned(ar) <= $unsigned(min)) begin
                            // update the index if they are equal and the new one is smaller than the previous. 
                            // in case there are two equal values, hardware "picks" always the smallest index, 
                            // as a side effect of its implementation
                            if($unsigned(ar) == $unsigned(min) && NI-k-1 < idxmin)
                                idxmin = NI-k-1;
                            else
                                idxmin = NI-k-1;
                            min = $unsigned(ar);
                        end
                    end
                end

                min_max_sel = 0;
                x = arand;

                if(us_sel==1'b1) begin // signed
                    #del;
                    assert($signed(result) == $signed(min) && ((CFG == 0) && index == idxmin) || (CFG == 1))
                        `ifndef DEBUG
                            ;
                        `else 
                                $display("PASS"); 
                            else begin 
                                $display("FAIL"); $display("result: ", $signed(result), " index: ", index, " min: ", $signed(min), " idxmin: ", idxmin); error++;
                            end
                        `endif

                    min_max_sel = 1;
                    #del;
                    assert($signed(result) == $signed(max) && ((CFG == 0) && index == idxmax) || (CFG == 1))
                        `ifndef DEBUG
                            ;
                        `else
                                $display("PASS");
                            else begin 
                                $display("FAIL"); $display("result: ", $signed(result), " index: ", index, " max: ", $signed(max), " idxmax: ", idxmax); error++;
                            end
                        `endif
                end else begin // unsigned
                    #del;
                    assert($unsigned(result) == $unsigned(min) && ((CFG == 0) && index == idxmin) || (CFG == 1))
                        `ifndef DEBUG
                            ;
                        `else 
                                $display("PASS"); 
                            else begin 
                                $display("FAIL"); $display("result: ", $unsigned(result), " index: ", index, " min: ", $unsigned(min), " idxmin: ", idxmin); error++;
                            end
                        `endif

                    min_max_sel = 1;
                    #del;
                    assert($unsigned(result) == $unsigned(max) && ((CFG == 0) && index == idxmax) || (CFG == 1))
                        `ifndef DEBUG
                            ;
                        `else 
                                $display("PASS");
                            else begin 
                                $display("FAIL"); $display("result: ", $unsigned(result), " index: ", index, " max: ", $unsigned(max), " idxmax: ", idxmax); error++;
                            end
                        `endif
                end
            end
            $display("UN/SIGNED ", us_sel, " ERRORS ", error, "/", NUM_TESTS*2*2);
        end
    end

endmodule
