// Testbench for the minmax module
// Uncomment the define DEBUG to have a some informative output in the console.
// Adjust parameter NUM_TESTS to increase/decrease number of tests. Each test is carried out both for
// signed and unsigned casese as well as min and max search. Therefore, a total of
// NUM_TESTS * 2 * 2 will be carried out.

`timescale 1ns / 1ns

// `define DEBUG

module tb_minmax();

    localparam integer W            = 5;
    localparam integer NI           = 9;
    localparam integer OUT_CFG      = 0; // 0= output both value and index, 1= only value
    localparam integer MM_CFG       = 1; // 0= support both min/max, 1= only min, 2= only max
    localparam integer US_CFG       = 1; // 0= support both signed and unsigned, 1= only unsigned, 2= only signed
    localparam integer IDXW         = $clog2(NI);
    localparam integer NUM_TESTS    = 250;

    logic [NI*W-1 : 0] x;
    logic us_sel, min_max_sel;
    logic [W-1:0] result;
    logic [IDXW-1:0] index;

    minmax #(.W(W), .NI(NI), .IDXW(IDXW), .OUT_CFG(OUT_CFG), .MM_CFG(MM_CFG)) u_DUT (.*);

    time del = 1ns;
    initial begin
        static int errormins = 0, errormaxs = 0;
        static int errorminu = 0, errormaxu = 0;

        logic [W-1:0]       ar;
        logic [NI*W-1 : 0]  arand;
        logic [W-1:0]       min, max, idxmin, idxmax;

        int num_of_loops;

        if(US_CFG==0)
            num_of_loops = 2;
        else if(US_CFG==1 || US_CFG==2)
            num_of_loops = 1;

        for (int i = 0; i < num_of_loops; i++) begin
            if(US_CFG==0) begin
                if(i==0)
                    us_sel = 1'b0;
                else if(i==1)
                    us_sel = 1'b1;
            end else if(US_CFG==1 || US_CFG==2) begin
                if(US_CFG==1)
                    us_sel = 1'b0;
                else if(US_CFG==2)
                    us_sel = 1'b1;
            end

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

                x = arand;

                if(MM_CFG==0 || MM_CFG==1) begin // min
                    min_max_sel = 0;
                    #del;

                    // checking min
                    if(us_sel==1'b1) begin // signed
                        assert($signed(result) == $signed(min) && ((OUT_CFG == 0) && index == idxmin) || (OUT_CFG == 1))
                            `ifndef DEBUG
                                ;
                            `else
                                    $display("PASS"); 
                                else begin 
                                    $display("FAIL"); $display("result: ", $signed(result), " index: ", index, " min: ", $signed(min), " idxmin: ", idxmin); errormins++;
                                end
                            `endif
                    end else begin // unsigned
                        assert($unsigned(result) == $unsigned(min) && ((OUT_CFG == 0) && index == idxmin) || (OUT_CFG == 1))
                            `ifndef DEBUG
                                ;
                            `else
                                    $display("PASS");
                                else begin 
                                    $display("FAIL"); $display("result: ", $unsigned(result), " index: ", index, " min: ", $unsigned(min), " idxmin: ", idxmin); errorminu++;
                                end
                            `endif
                    end
                end

                if(MM_CFG==0 || MM_CFG==2) begin // max
                    min_max_sel = 1;
                    #del;

                    // checking max
                    if(us_sel==1'b1) begin // signed
                        assert($signed(result) == $signed(max) && ((OUT_CFG == 0) && index == idxmax) || (OUT_CFG == 1))
                            `ifndef DEBUG
                                ;
                            `else
                                    $display("PASS");
                                else begin 
                                    $display("FAIL"); $display("result: ", $signed(result), " index: ", index, " max: ", $signed(max), " idxmax: ", idxmax); errormaxs++;
                                end
                            `endif
                    end else begin // unsigned
                        assert($unsigned(result) == $unsigned(max) && ((OUT_CFG == 0) && index == idxmax) || (OUT_CFG == 1))
                            `ifndef DEBUG
                                ;
                            `else
                                    $display("PASS");
                                else begin 
                                    $display("FAIL"); $display("result: ", $unsigned(result), " index: ", index, " max: ", $unsigned(max), " idxmax: ", idxmax); errormaxu++;
                                end
                            `endif
                    end
                end
            end
        end

        if(MM_CFG==0 || MM_CFG==1) begin // min
            if(US_CFG==0 || US_CFG==2) // signed
                $display("MIN - SIGNED . ERRORS ", errormins, "/", NUM_TESTS);
            if(US_CFG==0 || US_CFG==1) // unsigned
                $display("MIN - UNSIGNED ERRORS ", errorminu, "/", NUM_TESTS);
        end

        if(MM_CFG==0 || MM_CFG==2) begin
            if(US_CFG==0 || US_CFG==2) // signed
                $display("MAX - SIGNED . ERRORS ", errormaxs, "/", NUM_TESTS);
            if(US_CFG==0 || US_CFG==1)
                $display("MAX - UNSIGNED ERRORS ", errormaxu, "/", NUM_TESTS);
        end
    end

endmodule
