`timescale 1ns/1ps

module blackjack_top (
    input wire clk,
    input wire reset,
    input wire [4:0] card_in,     // Initial card input for player
    input wire stand,             // Player chooses to stand
    input wire hit,               // Player chooses to hit
    input wire submit,            // Submit action to deal or draw cards
    input wire [4:0] seed,        // New: Seed input for LFSR
    output reg [5:0] dealer_sum,  // Sum of dealer's hand
    output reg [5:0] player_sum,  // Sum of player's hand
    output reg win,
    output reg lose,
    output reg draw,
    output reg blackjack
);

    // Local parameters for state encoding
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

    // LFSR for pseudo-random card generation
    reg [4:0] lfsr;
    wire feedback;
    assign feedback = lfsr[4] ^ lfsr[2];

    reg [5:0] card_temp;
    reg [4:0] generated_card;

    // Expose LFSR state

    // Generate the card value from LFSR
    always @(*) begin
        card_temp = {2'b00, lfsr[3:0]} + 6'd1; // range 1 to 16
        if (card_temp > 13) begin
            card_temp = card_temp % 13; // Ensure range 1-13
        end
        // Map card_temp to standard Blackjack values
        if (card_temp > 10) begin
            card_temp = 10; // J, Q, K are treated as 10
        end
        generated_card = card_temp[4:0];
    end

    // State transition on clock edge or reset
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
            lfsr              <= (seed != 0) ? seed : 5'b00001; // Initialize LFSR with seed or default to 00001
        end else begin
            current_state <= next_state;
        end
    end

    // Next state logic based on current state and inputs
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
                // Wait until two cards are dealt to both player and dealer
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
                // Await reset or new game initiation
                next_state = S_DONE;
            end

            default: next_state = S_IDLE;
        endcase
    end

    // Datapath and game logic updates
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
            // lfsr is already initialized above
        end else begin
            case (current_state)
                S_IDLE: begin
                    // No action needed; waiting for submit
                end

                S_INIT_DEAL: begin
                    // Deal two cards to player and dealer on submit pulses
                    if (card_count_player < 2 && submit) begin
                        player_sum        <= player_sum + card_in; // Use card_in for player
                        card_count_player <= card_count_player + 1;
                        // Check for player blackjack after second card
                        if (card_count_player == 1 && (player_sum + card_in) == 21) begin
                            blackjack <= 1;
                        end
                    end

                    if (card_count_dealer < 2 && submit) begin
                        dealer_sum        <= dealer_sum + generated_card; // Dealer uses generated_card
                        card_count_dealer <= card_count_dealer + 1;
                        // Dealer blackjack is checked during evaluation
                    end

                    // Advance LFSR for next card generation
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
                            // Player chooses to hit
                            player_sum        <= player_sum + generated_card;
                            card_count_player <= card_count_player + 1;
                            lfsr              <= {lfsr[3:0], feedback};
                        end
                        // Check for bust
                        if (player_sum > 21) begin
                            player_done <= 1;
                        end
                    end
                end

                S_DEALER_TURN: begin
                    if (!dealer_done) begin
                        // Dealer hits until sum >=17
                        if (dealer_sum >= 17) begin
                            dealer_done <=1;
                        end else if (submit) begin
                            dealer_sum        <= dealer_sum + generated_card;
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
                    win    <= 0;
                    lose   <= 0;
                    draw   <= 0;
                    blackjack <= 0;

                    // Evaluate results
                    if (player_sum > 21) begin
                        lose <= 1; // Player busts
                    end else if (dealer_sum > 21) begin
                        win <=1;  // Dealer busts
                    end else if (player_sum > dealer_sum) begin
                        win <=1; // Player has higher sum
                    end else if (player_sum < dealer_sum) begin
                        lose <=1; // Dealer has higher sum
                    end else begin
                        draw <=1; // Tie
                    end

                    // Check for initial blackjack
                    if (blackjack) begin
                        if (dealer_sum == 21) begin
                            draw <=1; // Both have blackjack
                        end else begin
                            win <=1; // Player has blackjack
                        end
                    end
                end

                S_DONE: begin
                    // Awaiting reset or new game
                    // Outputs remain stable
                end

            endcase
        end
    end

endmodule
