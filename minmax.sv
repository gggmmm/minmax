`timescale 1ns / 1ns

module minmax #(
    parameter integer W     = 10,            // input data width
    parameter integer NI    = 17,            // Number of inputs
    parameter integer IDXW  = $clog2(NI),   // num. bits to represent and index
    parameter integer CFG   = 1             // 0= output both value and index, 1= only value
)(
    input   logic [NI*W-1 : 0] x,
    input   logic us_sel, min_max_sel,

    output  logic [W-1:0] result,
    output  logic [IDXW-1:0] index
);


    function integer f_NumInputFromPreiousLevel(integer level, integer NI);
        integer i;
        begin
            f_NumInputFromPreiousLevel = NI;
            for (i = 0; i < level; i=i+1) begin
                if(f_NumInputFromPreiousLevel % 2 == 1)
                    f_NumInputFromPreiousLevel = (f_NumInputFromPreiousLevel-1)/2 +1;
                else
                    f_NumInputFromPreiousLevel = f_NumInputFromPreiousLevel/2;
            end
        end
    endfunction

    localparam treeDepth = $clog2(NI);
    generate
        wire [W-1:0]    intermediate        [treeDepth-1:0][NI/2:0];
        wire [IDXW-1:0] intermediateIdx     [treeDepth-1:0][NI/2:0];

        for(genvar i=0; i<treeDepth; i=i+1) begin : vertical
            for(genvar j=0; j<f_NumInputFromPreiousLevel(i, NI); j=j+2) begin : horizontal

                // the code in the if is the same as in the else, only the indices change
                if(i==0) begin : first_level // first level in the tree, use input
                    if( (f_NumInputFromPreiousLevel(i, NI) % 2 == 0)   ||
                        (j+1) < (f_NumInputFromPreiousLevel(i, NI)-1)    ) begin : even_or_not_last
                        
                        if(CFG==0)
                            minmax2 #(IDXW, W, CFG) u_mm2(
                                      .x            (x[W*(j+1)-1:W*j]           ),
                                      .y            (x[W*(j+2)-1:W*(j+1)]       ),
                                      .xi           (j                          ),
                                      .yi           (j+1                        ),
                                      .us_sel       (us_sel                     ),
                                      .min_max_sel  (min_max_sel                ),
                                      .result       (intermediate[i][j/2]       ),
                                      .index        (intermediateIdx[i][j/2]    ) // same index as result
                                    );
                        else if(CFG==1)
                            minmax2 #(IDXW, W, CFG) u_mm2(
                                  .x            (x[W*(j+1)-1:W*j]           ),
                                  .y            (x[W*(j+2)-1:W*(j+1)]       ),
                                  .us_sel       (us_sel                     ),
                                  .min_max_sel  (min_max_sel                ),
                                  .result       (intermediate[i][j/2]       )
                                );
                    end else begin : odd_and_last
                        // just skip, this result is alone and needs to be just moved to the next level
                        if(CFG==0)
                            PassThrough #(IDXW, W, CFG) u_pt(
                                .value_in   (x[W*(j+1)-1:W*j]           ),
                                .index_in   (j                          ),
                                .result     (intermediate[i][j/2]       ),
                                .index      (intermediateIdx[i][j/2]    )
                            );
                        else if(CFG==1)
                            PassThrough #(IDXW, W, CFG) u_pt(
                                .value_in   (x[W*(j+1)-1:W*j]           ),
                                .result     (intermediate[i][j/2]       )
                            );
                    end
                end else begin : other_level // any other level, use intermediate variable

                    if( (f_NumInputFromPreiousLevel(i, NI) % 2 == 0) ||
                        (j+1) < (f_NumInputFromPreiousLevel(i, NI)-1)  ) begin : even_or_not_last

                        if(CFG==0)
                            minmax2 #(IDXW, W, CFG) u_mm2(
                                      .x            (intermediate[i-1][j]       ),
                                      .y            (intermediate[i-1][j+1]     ),
                                      .xi           (intermediateIdx[i-1][j]    ), // same index as x
                                      .yi           (intermediateIdx[i-1][j+1]  ), // same index as y
                                      .us_sel       (us_sel                     ),
                                      .min_max_sel  (min_max_sel                ),
                                      .result       (intermediate[i][j/2]       ),
                                      .index        (intermediateIdx[i][j/2]    )  // same index as result
                                    );
                        else if(CFG==1)
                            minmax2 #(IDXW, W, CFG) u_mm2(
                                      .x            (intermediate[i-1][j]       ),
                                      .y            (intermediate[i-1][j+1]     ),
                                      .us_sel       (us_sel                     ),
                                      .min_max_sel  (min_max_sel                ),
                                      .result       (intermediate[i][j/2]       )
                                    );
                    end else begin : odd_and_last
                        // just skip, this result is alone and needs to be just moved to the next level
                        if(CFG==0)
                            PassThrough #(IDXW, W, CFG) u_pt(
                                .value_in   (intermediate[i-1][j]   ),
                                .index_in   (intermediateIdx[i-1][j]),
                                .result     (intermediate[i][j/2]   ),
                                .index      (intermediateIdx[i][j/2])
                            );
                        else if(CFG==1)
                            PassThrough #(IDXW, W, CFG) u_pt(
                                .value_in   (intermediate[i-1][j]   ),
                                .result     (intermediate[i][j/2]   )
                            );
                    end
                end
            end
        end

        // connecting with the outputs
        assign result = intermediate[treeDepth-1][0];
        if(CFG==0)
            assign index = intermediateIdx[treeDepth-1][0];
    endgenerate

endmodule

// This is needed simply to have a better view in the schematic
module PassThrough #(
    parameter IDXW  = 2,
    parameter W     = 6,
    parameter CFG   = 0
)(
    input   logic [W-1 : 0]       value_in,
    input   logic [IDXW-1 : 0]    index_in,

    output  logic [W-1 : 0]       result,
    output  logic [IDXW-1 : 0]    index  
);
    assign result = value_in;

    generate
        if (CFG==0)
            assign index = index_in;
    endgenerate
endmodule // passThrough

// This is the core of the minmax, does all the heavy lifting.
// Notice how the index is chosen, always compared first with x,
// hence if x is equal to y, x index is passed forward.
module minmax2 #(
    parameter IDXW  = 2,
    parameter W     = 6,
    parameter CFG   = 0
)(
    input   logic [W-1 : 0]     x, y,
    input   logic [IDXW-1 : 0]  xi, yi,
    input   logic               us_sel, min_max_sel,

    output  logic [W-1 : 0]     result,
    output  logic [IDXW-1 : 0]  index
);

    assign result = us_sel == 0 ? min_max_sel == 0  ? $unsigned(x) < $unsigned(y)   ? x // unsigned, min
                                                                                    : y
                                                    : $unsigned(x) > $unsigned(y)   ? x // unsigned, max
                                                                                    : y
                                : min_max_sel == 0  ? $signed(x) < $signed(y)       ? x // signed, min
                                                                                    : y
                                                    : $signed(x) > $signed(y)       ? x // signed, max
                                                                                    : y;
    generate
        if(CFG==0)
            assign index = result == x ? xi : yi;
    endgenerate
endmodule
