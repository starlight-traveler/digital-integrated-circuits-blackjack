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
// wire [4:0] lfsr_out; 

// Instantiate the DUT (Device Under Test)
blackjack_top dut (
    .clk(clk),
    .reset(reset),
    .card_in(card_in),
    .stand(stand),
    .hit(hit),
    .submit(submit),
    .seed(seed),                // Connect seed
    .dealer_sum(dealer_sum),
    .player_sum(player_sum),
    .win(win),
    .lose(lose),
    .draw(draw),
    .blackjack(blackjack)
);

// Clock Generation: 100MHz Clock (10ns Period)
initial begin
    clk = 0;
    forever #5 clk = ~clk;  // Toggle clock every 5ns
end

// Task to Perform a Submit Pulse
task perform_submit;
    begin
        submit = 1;
        @(posedge clk);
        submit = 0;
        @(posedge clk);
    end
endtask

// Test Scenario:
initial begin

    // Initialize All Signals
    reset = 1;
    stand = 0;
    hit = 0;
    submit = 0;
    card_in = 5'd0;   // Initialize card_in to 0

    // Wait for a small delay to let $time increment
    #6;

    // Generate a random seed
    seed = ($random) ^ ($random << 3) ^ ($time % 32);

    // Ensure seed is not zero
    if (seed == 0) seed = 5'b00001;

    $display("Initial Seed: %b", seed);

    // Apply Reset
    @(posedge clk);
    @(posedge clk);
    reset = 0;   // De-assert reset

    // Wait for a Couple of Clock Cycles
    @(posedge clk);
    @(posedge clk);

    // -------------------------------
    // Step 1: Deal First Player Card
    // -------------------------------

    card_in = 5'd8;   // First card for player (e.g., 8)
    perform_submit();  // Submit first player card

    // -------------------------------
    // Step 2: Deal Second Player Card
    // -------------------------------

    card_in = 5'd7;   // Second card for player (e.g., 7)
    perform_submit();  // Submit second player card

    // -------------------------------
    // Step 3: Wait for Evaluation to Complete
    // -------------------------------

    @(posedge clk); // Wait for the state machine to transition
    if (blackjack) begin
        $display("Initial Blackjack detected!");
        // Proceed to Evaluation without player actions
    end else begin

    // -------------------------------
    // Step 4: Player's Turn - Decide to Hit or Stand
    // -------------------------------
    // Example Scenario: Player Hits Once and Then Stands

    // Player Chooses to Hit
    @(posedge clk);
    hit = 1;          // Assert Hit
    perform_submit(); // Submit hit action
    hit = 0;          // De-assert Hit

    // Player Chooses to Stand
    @(posedge clk);
    stand = 1;        // Assert Stand
    @(posedge clk);
    stand = 0;        // De-assert Stand
    end

    // -------------------------------
    // Step 5: Dealer's Turn
    // -------------------------------
    // Dealer's actions are automated based on game logic.
    // Simulate submit pulses to allow dealer to draw cards until done.

    // Issue Multiple Submit Pulses to Cover Dealer's Possible Draws
    repeat (5) begin
        @(posedge clk);
        perform_submit();
    end

    // -------------------------------
    // Step 6: Wait for Evaluation to Complete
    // -------------------------------
    repeat (10) @(posedge clk);

    // -------------------------------
    // Step 7: Display Final Results
    // -------------------------------

    $display("------------------------------------------------");
    $display("Final Player Sum: %d", player_sum);
    $display("Final Dealer Sum: %d", dealer_sum);
    $display("Blackjack: %b, Win: %b, Lose: %b, Draw: %b", blackjack, win, lose, draw);
    $display("------------------------------------------------");

    // Finish the Simulation
    $finish;
end

// Monitor State Transitions and LFSR for Debugging
always @(posedge clk) begin
    // Uncomment the following line to display internal state and sums each clock cycle
    /*
    $display("Time: %0t | State: %b | LFSR: %b | Player Sum: %d | Dealer Sum: %d | Blackjack: %b | Win: %b | Lose: %b | Draw: %b",
             $time, dut.current_state, lfsr_out, player_sum, dealer_sum, blackjack, win, lose, draw);
    */
end

endmodule
