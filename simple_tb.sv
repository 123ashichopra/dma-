`timescale 1ns/1ps

module tb;

    logic clk;
    logic rst_n;

    // Configuration interface
    config_if cfg_if(clk, rst_n);

    // Memory interface
    memory_if mem_if(clk, rst_n);

    // DUT
    dma_controller dut (
        .clk   (clk),
        .rst_n (rst_n),
        .cfg_if(cfg_if),
        .mem_if(mem_if)
    );

    // ------------------------------------------------------------
    // Clock
    // ------------------------------------------------------------

    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // ------------------------------------------------------------
    // Simple memory model
    // ------------------------------------------------------------

    logic [31:0] memory [0:1023];

    always_comb begin
        mem_if.rdata = 32'h0;
        mem_if.ready = 1'b0;

        if (mem_if.valid) begin
            mem_if.ready = 1'b1;

            if (mem_if.read_en) begin
                mem_if.rdata = memory[mem_if.addr >> 2];
            end
        end
    end

    always_ff @(posedge clk) begin
        if (mem_if.valid && mem_if.write_en && mem_if.ready) begin
            memory[mem_if.addr >> 2] <= mem_if.wdata;

            $display(
                "[MEM WRITE] addr=%h data=%h",
                mem_if.addr,
                mem_if.wdata
            );
        end
    end

    // ------------------------------------------------------------
    // Configuration write task
    // ------------------------------------------------------------

    task automatic cfg_write(
        input logic [7:0] addr,
        input logic [31:0] data
    );

        begin
            @(posedge clk);

            cfg_if.addr     <= addr;
            cfg_if.wdata    <= data;
            cfg_if.write_en <= 1'b1;
            cfg_if.read_en  <= 1'b0;

            @(posedge clk);

            wait(cfg_if.ready);

            @(posedge clk);

            cfg_if.write_en <= 1'b0;
            cfg_if.addr     <= 8'h00;
            cfg_if.wdata    <= 32'h0;
        end

    endtask

    // ------------------------------------------------------------
    // Test
    // ------------------------------------------------------------

    initial begin
        $dumpfile("dma.vcd");
        $dumpvars(0, tb);
        
        // Initialize everything
        rst_n = 0;

        cfg_if.addr     = 0;
        cfg_if.wdata    = 0;
        cfg_if.write_en = 0;
        cfg_if.read_en  = 0;

        // Initialize memory
        for (int i = 0; i < 1024; i++) begin
            memory[i] = 32'h0;
        end

        // Put some known data in source memory
        memory[32'h1000 >> 2] = 32'hAAAA1111;
        memory[32'h1004 >> 2] = 32'hBBBB2222;
        memory[32'h1008 >> 2] = 32'hCCCC3333;
        memory[32'h100C >> 2] = 32'hDDDD4444;

        // Reset
        repeat (2) @(posedge clk);
        rst_n = 1;

        $display("");
        $display("========================================");
        $display(" Starting DMA test");
        $display("========================================");

        // --------------------------------------------------------
        // Configure Channel 0
        // --------------------------------------------------------

        cfg_write(8'h00, 32'h00001000); // source
        cfg_write(8'h04, 32'h00002000); // destination
        cfg_write(8'h08, 32'd4);         // 4 words

        // Start channel 0
        cfg_write(8'h0C, 32'h1);

        // Wait for DMA to finish
        wait(dut.ch0_done);

        $display("");
        $display("========================================");
        $display(" DMA completed");
        $display("========================================");

        // --------------------------------------------------------
        // Check destination
        // --------------------------------------------------------

        if (memory[32'h2000 >> 2] !== 32'hAAAA1111)
            $fatal("ERROR at destination 0");

        if (memory[32'h2004 >> 2] !== 32'hBBBB2222)
            $fatal("ERROR at destination 1");

        if (memory[32'h2008 >> 2] !== 32'hCCCC3333)
            $fatal("ERROR at destination 2");

        if (memory[32'h200C >> 2] !== 32'hDDDD4444)
            $fatal("ERROR at destination 3");

        $display("");
        $display("========================================");
        $display(" TEST PASSED!");
        $display("========================================");

        #20;
        $finish;

    end

endmodule
