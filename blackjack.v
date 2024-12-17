`timescale 1ns/1ps

module blackjack_top (
    input wire clk,
    input wire reset,
    input wire [4:0] card_in,     // Initial card input for player
    input wire stand,             // Player chooses to stand
    input wire hit,               // Player chooses to hit
    input wire submit,            // Submit action to deal or draw cards
    input wire [4:0] seed,        // Seed input for LFSR
    output reg [5:0] dealer_sum,  // Sum of dealer's hand
    output reg [5:0] player_sum,  // Sum of player's hand
    output reg win,
    output reg lose,
    output reg draw,
    output reg blackjack,
    output wire [4:0] generated_card_out
);

    // State definitions
    localparam S_IDLE         = 3'b000;
    localparam S_INIT_DEAL    = 3'b001;
    localparam S_PLAYER_TURN  = 3'b010;
    localparam S_DEALER_TURN  = 3'b011;
    localparam S_EVAL         = 3'b100;
    localparam S_DONE         = 3'b101;

    reg [2:0] current_state, next_state;

    // Internal registers for counts and status
    reg [1:0] card_count_player;
    reg [1:0] card_count_dealer;
    reg player_done;
    reg dealer_done;

    // Track the number of Aces (for flexible 1 or 11 calculation)
    reg [2:0] player_aces;
    reg [2:0] dealer_aces;

    // LFSR for pseudo-random card generation
    reg [4:0] lfsr;
    wire feedback;
    assign feedback = lfsr[4] ^ lfsr[2];

    
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            lfsr <= seed;
        end else begin
            lfsr <= {lfsr[3:0], lfsr[4] ^ lfsr[2]};
        end
    end
    reg [5:0] card_temp;
    reg [4:0] generated_card;
    assign generated_card_out = generated_card;
    // Procedure to add a card to player's sum and adjust for Aces
    task add_player_card;
        input [4:0] c;
        reg [5:0] val;
    begin
        // Card c is already in range 1-10
        val = c;
        // Check if card is an Ace (we treat '1' as Ace)
        if (val == 1) begin
            player_aces = player_aces + 1;
            player_sum = player_sum + 1; // Add as 1 first
        end else begin
            player_sum = player_sum + val;
        end
        // Adjust Aces: If we have Aces and can make one or more Aces count as 11 without busting
        // Each Ace initially is counted as 1, adding 10 makes it 11.
        // For multiple Aces, try upgrading as many as possible.
        begin : adjust_aces
            integer i;
            for (i = 0; i < player_aces; i = i + 1) begin
                if (player_sum <= 11) begin
                    player_sum = player_sum + 10; // Turn one Ace from 1 to 11
                end else begin
                    // If turning another Ace into 11 would bust, don't do it
                    disable adjust_aces;
                end
            end
        end
    end
    endtask

    // Procedure to add a card to dealer's sum and adjust for Aces
    task add_dealer_card;
        input [4:0] c;
        reg [5:0] val;
    begin
        val = c;
        if (val == 1) begin
            dealer_aces = dealer_aces + 1;
            dealer_sum = dealer_sum + 1;
        end else begin
            dealer_sum = dealer_sum + val;
        end
        // Adjust Aces for dealer
        begin : adjust_aces_dealer
            integer i;
            for (i = 0; i < dealer_aces; i = i + 1) begin
                if (dealer_sum <= 11) begin
                    dealer_sum = dealer_sum + 10;
                end else begin
                    disable adjust_aces_dealer;
                end
            end
        end
    end
    endtask

    // Generate the card value from LFSR
    // card_temp range: 1-13
    // Map: 1=Ace(1), 2-10 as face value, 11/12/13 -> 10(J/Q/K)
    always @(*) begin
        card_temp = {2'b00, lfsr[3:0]} + 6'd1; // range 1 to 16
        if (card_temp > 13) begin
            // Map values >13 back into 1-13 range
            card_temp = ((card_temp - 1) % 13) + 1;
        end
        if (card_temp > 10) begin
            card_temp = 10; // J, Q, K are treated as 10
        end
        generated_card = card_temp[4:0];
    end

    // On reset
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            current_state     <= S_IDLE;
            player_sum        <= 0;
            dealer_sum        <= 0;
            card_count_player <= 0;
            card_count_dealer <= 0;
            player_done       <= 0;
            dealer_done       <= 0;
            blackjack         <= 0;
            win               <= 0;
            lose              <= 0;
            draw              <= 0;
            player_aces       <= 0;
            dealer_aces       <= 0;
            lfsr              <= (seed != 0) ? seed : 5'b00001;
        end else begin
            current_state <= next_state;
        end
    end

    // State transitions
    always @(*) begin
        next_state = current_state;
        case (current_state)
            S_IDLE: begin
                if (submit) begin
                    next_state = S_INIT_DEAL;
                end else begin
                    next_state = S_IDLE;
                end
            end

            S_INIT_DEAL: begin
                if (card_count_player == 2 && card_count_dealer == 2) begin
                    // Check for initial blackjack
                    if (player_sum == 21 || dealer_sum == 21) begin
                        next_state = S_EVAL;
                    end else begin
                        next_state = S_PLAYER_TURN;
                    end
                end else begin
                    next_state = S_INIT_DEAL;
                end
            end

            S_PLAYER_TURN: begin
                if (player_done) begin
                    next_state = S_DEALER_TURN;
                end else begin
                    next_state = S_PLAYER_TURN;
                end
            end

            S_DEALER_TURN: begin
                if (dealer_done) begin
                    next_state = S_EVAL;
                end else begin
                    next_state = S_DEALER_TURN;
                end
            end

            S_EVAL: begin
                next_state = S_DONE;
            end

            S_DONE: begin
                next_state = S_DONE;
            end

            default: next_state = S_IDLE;
        endcase
    end

    // Datapath and game logic
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            player_sum        <= 0;
            dealer_sum        <= 0;
            card_count_player <= 0;
            card_count_dealer <= 0;
            player_done       <= 0;
            dealer_done       <= 0;
            blackjack         <= 0;
            win               <= 0;
            lose              <= 0;
            draw              <= 0;
            player_aces       <= 0;
            dealer_aces       <= 0;
        end else begin
            case (current_state)
                S_IDLE: begin
                    // Waiting for submit
                end

                S_INIT_DEAL: begin
                    // Deal two cards to player and dealer on submit pulses
                    if (card_count_player < 2 && submit) begin
                        add_player_card(card_in); 
                        card_count_player <= card_count_player + 1;
                        // Check for player blackjack after second card
                        if (card_count_player == 1 && player_sum == 21) begin
                            blackjack <= 1;
                        end
                    end

                    if (card_count_dealer < 2 && submit) begin
                        add_dealer_card(generated_card);
                        card_count_dealer <= card_count_dealer + 1;
                    end

                    if (submit) begin
                        lfsr <= {lfsr[3:0], feedback};
                    end
                end

                S_PLAYER_TURN: begin
                    if (!player_done) begin
                        if (stand) begin
                            // Player chooses to stand
                            player_done <= 1;
                        end else if (hit && submit) begin
                            add_player_card(generated_card);
                            card_count_player <= card_count_player + 1;
                            lfsr              <= {lfsr[3:0], feedback};
                        end
                        // Check for bust
                        if (player_sum > 21) begin
                            player_done <= 1;
                        end
                    end else begin
                        // Already done
                    end
                end

                S_DEALER_TURN: begin
                    if (!dealer_done) begin
                        // Dealer hits until sum >= 17
                        if (dealer_sum >= 17) begin
                            dealer_done <=1;
                        end else if (submit) begin
                            add_dealer_card(generated_card);
                            card_count_dealer <= card_count_dealer +1;
                            lfsr              <= {lfsr[3:0], feedback};
                            // Check for bust
                            if (dealer_sum > 21) begin
                                dealer_done <=1;
                            end
                        end
                    end
                end

                S_EVAL: begin
                    // Reset previous results
                    win       <= 0;
                    lose      <= 0;
                    draw      <= 0;
                    // If we had marked blackjack earlier, we keep that in mind
                    // Evaluate results
                    if (player_sum > 21) begin
                        lose <= 1; // Player busts
                    end else if (dealer_sum > 21) begin
                        win <= 1;  // Dealer busts
                    end else if (player_sum > dealer_sum) begin
                        win <= 1; // Player higher sum
                    end else if (player_sum < dealer_sum) begin
                        lose <= 1; // Dealer higher sum
                    end else begin
                        draw <= 1; // Tie
                    end

                    // Check for initial blackjack
                    if (blackjack) begin
                        if (dealer_sum == 21) begin
                            draw <= 1; // Both have blackjack
                        end else begin
                            win <= 1;  // Player has blackjack
                        end
                    end
                end

                S_DONE: begin
                    // Waiting for next reset or new game
                end

            endcase
        end
    end

endmodule
