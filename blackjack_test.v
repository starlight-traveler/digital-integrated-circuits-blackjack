`timescale 1ns/1ps

module blackjack_top_tb;

    // Testbench Signals
    reg clk;
    reg reset;
    reg [4:0] card_in;
    reg stand;
    reg hit;
    reg submit;
    reg [4:0] seed;
    wire [5:0] dealer_sum;
    wire [5:0] player_sum;
    wire win;
    wire lose;
    wire draw;
    wire blackjack;

    // Instantiate the DUT
    blackjack_top dut (
        .clk(clk),
        .reset(reset),
        .card_in(card_in),
        .stand(stand),
        .hit(hit),
        .submit(submit),
        .seed(seed),
        .dealer_sum(dealer_sum),
        .player_sum(player_sum),
        .win(win),
        .lose(lose),
        .draw(draw),
        .blackjack(blackjack)
    );

    // Generate Clock
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // Task to Perform a Submit Pulse
    task perform_submit;
    begin
        submit = 1;
        @(posedge clk);
        @(posedge clk);

        submit = 0;
        @(posedge clk);
        
    end
    endtask


    initial begin
        // Initialize signals
        reset = 1;
        stand = 0;
        hit = 0;
        submit = 0;
        card_in = 5'd0;

        // Use a fixed seed for reproducibility
        // For example, seed = 5'b10101;
        seed = 5'b10001;

        // Apply Reset
        @(posedge clk);
        @(posedge clk);
        reset = 0;

        // Wait a couple of cycles
        @(posedge clk);
        @(posedge clk);

        // -----------------------------------
        // Deal Player's Initial Cards
        // -----------------------------------
        card_in = 5'd10;
        @(posedge clk);
        perform_submit();

        card_in = 5'd8;  // Ace
        @(posedge clk);
        perform_submit();


        // At this point, player_sum should be 21 if Ace is handled correctly (10 + 11)
        // Dealer will receive cards from the LFSR.

        // Wait for the state machine to process initial dealing
        repeat(5) @(posedge clk);

        // If initial blackjack is detected, the game should jump to evaluation.
        if (blackjack) begin
            $display("Initial Blackjack detected!");
        end else begin
            // If no blackjack, player turn logic:
            // For this test, let's just stand immediately to let dealer play.
            @(posedge clk);
            stand = 1;
            @(posedge clk);
            stand = 0;
        end

        // Dealer's turn: send a few submits to allow the dealer to draw
        repeat(5) begin
            @(posedge clk);
            perform_submit();
        end

        // Wait for evaluation
        repeat(10) @(posedge clk);

        // Display Results
        $display("------------------------------------------------");
        $display("Final Player Sum: %d", player_sum);
        $display("Final Dealer Sum: %d", dealer_sum);
        $display("Blackjack: %b, Win: %b, Lose: %b, Draw: %b", blackjack, win, lose, draw);
        $display("------------------------------------------------");

        // Finish simulation
        $finish;
    end

endmodule
