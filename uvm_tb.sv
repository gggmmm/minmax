import uvm_pkg::*;
`include "uvm_macros.svh"

`define NI 5
`define W 4
`define IDXW $clog2(`NI)
`define OUT_CFG 0
`define MM_CFG  0
`define MIN_NUM_TESTS 10
`define MAX_NUM_TESTS 20

interface dut_vif ();
    logic [`W-1:0] x [`NI];
    logic min_max_sel;

    logic [`W-1:0] result;
    logic [`IDXW-1:0] index;
endinterface : dut_vif

class item extends uvm_sequence_item;
    logic [`W-1:0] x [`NI];
    logic min_max_sel;
    logic [`W-1:0] result;
    logic [`IDXW-1:0] index;

    `uvm_object_utils_begin(item)
        `uvm_field_int (min_max_sel, UVM_DEFAULT)
    `uvm_object_utils_end

    function new(string name="item");
        super.new(name);
    endfunction : new

    function void my_randomize();
        for(int i=0; i<`NI; i++) begin
            x[i] = $urandom_range(0,2**`W-1);
        end
        min_max_sel = $urandom_range(0,1);
    endfunction : my_randomize
endclass : item

class driver extends uvm_driver #(item);
    `uvm_component_utils(driver)

    function new(string name="driver", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual dut_vif vif;

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if(!uvm_config_db#(virtual dut_vif)::get(this, "", "dut_vif", vif))
            `uvm_fatal("DRV", "couldn't gt vif")
    endfunction : build_phase

    virtual task run_phase(uvm_phase phase);
        super.run_phase(phase);
        forever begin
            item i;
            seq_item_port.get_next_item(i);
            drive_item(i);
            seq_item_port.item_done();
        end
    endtask : run_phase

    virtual task drive_item(item i);
        vif.x <= i.x;
        vif.min_max_sel <= i.min_max_sel;
    endtask : drive_item
endclass : driver

class monitor extends uvm_monitor;
    `uvm_component_utils(monitor)

    uvm_analysis_port #(item) mon_ap;
    virtual dut_vif vif;
    semaphore sem;

    function new(string name="monitor", uvm_component parent=null);
        super.new(name, parent);
    endfunction : new

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if(!uvm_config_db#(virtual dut_vif)::get(this, "", "dut_vif", vif))
            `uvm_fatal("MON", "couldn't get vif")
        sem = new(1);
        mon_ap = new ("mon_ap", this);
    endfunction : build_phase

    virtual task run_phase(uvm_phase phase);
        super.run_phase(phase);
        forever begin
            item i = new;
            @(vif.x or vif.min_max_sel or vif.result or vif.index);
            i.x             = vif.x;
            i.min_max_sel   = vif.min_max_sel;
            i.result        = vif.result;
            i.index         = vif.index;
            mon_ap.write(i);
        end
    endtask : run_phase
endclass

class agent extends uvm_agent;
    `uvm_component_utils(agent)
    function new(string name="agent", uvm_component parent = null);
        super.new(name, parent);
    endfunction : new

    driver d0;
    monitor m0;
    uvm_sequencer #(item) s0;

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        d0 = driver::type_id::create("d0", this);
        m0 = monitor::type_id::create("m0", this);
        s0 = uvm_sequencer#(item)::type_id::create("s0", this);
    endfunction : build_phase

    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        d0.seq_item_port.connect(s0.seq_item_export);
    endfunction : connect_phase
endclass : agent

class scoreboard extends uvm_scoreboard;
    `uvm_component_utils(scoreboard)

    item item_q[10];
    uvm_analysis_imp #(item, scoreboard) m_analysis_imp;

    function new(string name="scoreboard", uvm_component parent = null);
        super.new(name, parent);
    endfunction : new

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        m_analysis_imp = new("m_analysis_imp", this);
    endfunction : build_phase

    function logic [`W-1:0] findMinMax( logic [`W-1:0] x [`NI],
                                        logic min_max_sel);
        logic [`W-1:0] result = x[0];
        for(int i=0; i<`NI; i++) begin
            if(min_max_sel == 0) // min
                result = x[i] < result ? x[i] : result;
            else // max
                result = x[i] > result ? x[i] : result;
        end
        return result;
    endfunction : findMinMax

    virtual function void write(item i);
        int expResult = findMinMax(i.x, i.min_max_sel);
        if(i.result != expResult)
            `uvm_error(get_type_name(), $sformatf("Error exp %0d got %0d", expResult, i.result))
        else
            `uvm_info(get_type_name(), $sformatf("Exp %0d got %0d", expResult, i.result), UVM_LOW)
    endfunction : write
endclass : scoreboard

class env extends uvm_env;
    `uvm_component_utils(env)

    function new(string name="env", uvm_component parent=null);
        super.new(name, parent);
    endfunction : new

    agent a0;
    scoreboard s0;

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        a0 = agent::type_id::create("a0", this);
        s0 = scoreboard::type_id::create("s0", this);
    endfunction

    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        a0.m0.mon_ap.connect(s0.m_analysis_imp);
    endfunction
endclass

class gen_item_seq extends uvm_sequence;
    `uvm_object_utils(gen_item_seq)
    function new(string name="gen_item_seq");
        super.new(name);
    endfunction : new

    int num;

    function void my_randomize();
        num = $urandom_range(`MIN_NUM_TESTS, `MAX_NUM_TESTS);
    endfunction : my_randomize

    virtual task body();
        for(int i=0; i<num; i++) begin
            item it = item::type_id::create("it");
            `uvm_info(get_type_name(), $sformatf("Iteration num %0d / %0d",i, num), UVM_LOW)
            start_item(it);
            it.my_randomize();
            it.print();
            #1ns;
            finish_item(it);
        end
    endtask : body
endclass

class test extends uvm_test;
    `uvm_component_utils(test)
    function new(string name="test", uvm_component parent=null);
        super.new(name, parent);
    endfunction

    env e0;
    virtual dut_vif vif;
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        e0 = env::type_id::create("e0", this);
        if(!uvm_config_db#(virtual dut_vif)::get(this, "", "dut_vif", vif))
            `uvm_fatal(get_type_name(), "couldn't get vif")

        uvm_config_db#(virtual dut_vif)::set(this, "a0.s0.*", "dut_vif", vif);
    endfunction : build_phase

    virtual task run_phase(uvm_phase phase);
        gen_item_seq seq = gen_item_seq::type_id::create("seq", this);
        phase.raise_objection(this);
            seq.my_randomize();
            seq.start(e0.a0.s0);
            #(`NI*2ns);
        phase.drop_objection(this);
    endtask
endclass

module uvm_tb_top();
    dut_vif vif();

    minmax #(
        .W(`W),
        .NI(`NI),
        .IDXW(`IDXW),
        .OUT_CFG(`OUT_CFG),
        .MM_CFG(`MM_CFG)
    ) u_DUT (
        .x(vif.x),
        .min_max_sel(vif.min_max_sel),
        .result(vif.result),
        .index(vif.index)
    );

    initial begin
        uvm_config_db#(virtual dut_vif)::set(null, "*", "dut_vif", vif);
        run_test("test");
    end

endmodule : uvm_tb_top

