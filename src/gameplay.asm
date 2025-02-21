.segment "CODE"
;*****************************************************************
; Set gamestate
;*****************************************************************
.proc set_gamestate
    LDA gamestate
    CMP #1              ; Check if gamestate = 1 (rolling dice)
    BNE done            ; If not, skip the rest of the logic

    ; Verify if all dice have been rolled (dice_values != 0)
    LDY #0              ; Initialize iterator for dice_values
check_values:
    LDA dice_values, y  ; Load value for die `y`
    CMP #$ff            ; Check if die value is still $ff
    BEQ done            ; If any die value is $ff, stay in current gamestate
    INY
    CPY #6              ; Check all 6 dice (0 to 5)
    BNE check_values    ; Continue checking if not done

    ; All dice have rolled, update gamestate to 2 = selecting dice
    LDA #2
    STA gamestate

    ; Clear 3 lines of the text box, one per frame
    LDY #0              ; Initialize iterator
line_loop:
    STY temp + 2        ; stash Y in temp + 2 to retrieve after clear_textbox_line
    STY temp + 3        ; set line number to clear
    JSR clear_textbox_line
    LDY temp + 2
    JSR wait_frame

    ;Clear the update flag for the next iteration
    LDA #0
    STA need_horiz_update
    INY
    CPY #3              ; Compare Y with 3 (number of lines)
    BNE line_loop       ; Continue if more lines to clear

    ; player will press B to finish selecting dice. 
    ; gamestate is set to 3 in player_actions.
    
done:
    RTS
.endproc


;*****************************************************************
; Increments dice_roll during vblank, keeping it between 0 and 5
;*****************************************************************
.proc increment_dice_roll
    LDA dice_roll
    CMP #5
    BEQ reset             ; If dice_roll is 5, reset to 0
    INC dice_roll         ; Otherwise, increment it
    RTS
reset:
    LDA #0
    STA dice_roll
    RTS
.endproc


;*****************************************************************
; Initialize dice to $ff, denoting them as unrolled
;*****************************************************************
.proc initialize_dice
    LDY #0                  ;iterator
loop:
    LDA #$ff
    STA dice_values, y
    STA dice_kept, y
    STA dice_counts, y
    INY
    CPY #6
    BNE loop
    RTS
.endproc

;*****************************************************************
; Get a value from dice_roll and draw that number on the selected die
;*****************************************************************
.proc roll_die
    ;store whatever's in dice_roll to dice_values[pointed_to_die]
    LDX pointed_to_die
    LDA dice_values, x
    CMP #$ff                ;make sure the die has not been rolled yet
    BNE skip
    LDA dice_roll
    STA dice_values, x

    STA draw_die_number

    ;set starting address for draw_die
    LDA PPU_STATUS
    LDA #$20
    STA paddr + 1
    LDA dice_starting_adresses_lo, x
    STA paddr

    ;set animation timer for the rolled die
    LDA #6
    STA dice_timers, x
skip:
    RTS
.endproc


;*****************************************************************
; Select a die for scoring
;*****************************************************************
.proc select_die
    ;get the value on the selected die and store it to temp
    LDX pointed_to_die
    LDA dice_values, x 
    CMP #6
    BEQ skip            ;6 here means the die is already selected
    STA temp

    ;find the first $ff in dice_kept, where we will store the value
    LDY #255             ;iterator, will roll over to 0 
loop:
    INY
    CPY #6
    BEQ skip            ;make sure we don't search past dice_kept's max size
    LDA dice_kept, y 
    CMP #$ff
    BNE loop

    ;store value at dice_kept, y
    LDA temp
    STA dice_kept, y 

    ;set starting address for draw_die
    LDA #$20
    STA paddr + 1
    LDA dice_starting_adresses_lo, x
    STA paddr

    ;draw an X on the die we selected
    LDA #6               ;6 is the index for the X'ed out die
    STA draw_die_number
    STA dice_values, x   ;store 6 to dice_values so we know the die is X'ed out 
    LDA #1
    STA need_draw_die
    JSR wait_frame
    
    ;draw the die in the text box
    ; Y still contains the index of dice_kept we're working with,
    ; use that to figure out starting address for draw_die
    LDA dice_kept, y 
    STA draw_die_number
    LDA #$21
    STA paddr +1
    TYA
    TAX
    LDA text_box_die_start_addresses_lo, x 
    STA paddr

    LDA #1
    STA need_draw_die
skip:
    RTS
.endproc


;*****************************************************************
; Score selected dice dynamically as they are selected
;*****************************************************************
.proc calculate_running_score
    ;Initialize memory for this routine
    LDA #0
    STA dice_counts 
    STA dice_counts + 1
    STA dice_counts + 2
    STA dice_counts + 3
    STA dice_counts + 4
    STA dice_counts + 5
    STA SKIP_STRAIGHT
    STA PAIRS_FOUND
    STA TRIPLES_FOUND

    ;Count occurrences of each die value in dice_kept and update dice_counters.
    ;Each byte of dice_counters contains the count of kept instances of each value, 1-6.
    LDY #0
count_loop:
    LDA dice_kept, y 
    CMP #$ff            ;ignore unused slots
    BEQ next_die
    TAX
    INC dice_counts, x  ;increment the count of that value

next_die:
    INY
    CPY #6              ;max of 6 kept dice
    BNE count_loop

    ;Scoring logic
    LDX #0
score_loop:
    LDA dice_counts, x 
    CMP #1              ;if it isn't a 1, we can skip checking for straights later
    BEQ +:
        PHA
        LDA #1
        STA SKIP_STRAIGHT
        PLA
    :
    
    ;Check for a pair
    CMP #2
    BEQ +:
        INC PAIRS_FOUND ;Pairs aren't scored unless there are 3, or with a quad
    :

    CMP #3
    BCC check_singles   ;if less than 3, check for single dice scoring

    ;Check for triples
    CMP #3              ;is it exactly 3?
    BNE check_quads
    INC TRIPLES_FOUND

    ;Triples are worth face value * 100
    STA ADD_RUNNING_SCORE_VALUE
    LDA RUNNING_SCORE_100s
    STA ADD_RUNNING_SCORE_DIGIT
    JSR add_running_score
    JMP check_singles    ;only singles are possible at this point

check_quads:
    ;Quads are always worth 1,000
    CMP #4              ;is it exactly 4?
    BNE check_quints
    INC QUADS_FOUND

    ;Check whether we have a pair as well
    LDA PAIRS_FOUND
    CMP #1
    BCC +:
        ;We have a quad and a pair, worth 1,500
        ;Add 1,000 to running score
        LDA #1
        STA ADD_RUNNING_SCORE_VALUE 
        LDA RUNNING_SCORE_1000s
        STA ADD_RUNNING_SCORE_DIGIT
        JSR add_running_score
        ;Add 500 to running score
        LDA #5
        STA ADD_RUNNING_SCORE_VALUE 
        LDA RUNNING_SCORE_100s
        STA ADD_RUNNING_SCORE_DIGIT
        JSR add_running_score
        RTS                    ;no other scoring is possible, GTFO

    LDA #1
    STA ADD_RUNNING_SCORE_VALUE
    LDA RUNNING_SCORE_1000s
    STA ADD_RUNNING_SCORE_DIGIT
    JSR add_running_score

check_quints:
    ;Quints are always worth 2,000
    CMP #5              ;is it exactly 5?
    BNE check_sixes

    LDA #2
    STA ADD_RUNNING_SCORE_VALUE
    LDA RUNNING_SCORE_1000s
    STA ADD_RUNNING_SCORE_DIGIT
    JSR add_running_score

check_sixes:
    ;Six of a number is always worth 3,000
    CMP #6
    BNE check_straight

    LDA #3
    STA ADD_RUNNING_SCORE_VALUE
    LDA RUNNING_SCORE_1000s
    STA ADD_RUNNING_SCORE_DIGIT
    JSR add_running_score

check_straight:
    ;Check whether we can skip checking for a straight
    LDA SKIP_STRAIGHT
    CMP #1
    BEQ check_three_pairs

    ;Preserve Y on stack
    TYA
    PHA              

    ;Loop over dice_kept checking for 1's.  If a non-1 is found, not a straight.
    LDY #0
straight_loop:
    LDA dice_kept, y 
    CMP #1              
    BNE no_straight
    INY 
    CPY #6
    BNE straight_loop

    ;If we get here, we have a straight, worth 1,500.
    ;Add 1,000 to running score
    LDA #1
    STA ADD_RUNNING_SCORE_VALUE 
    LDA RUNNING_SCORE_1000s
    STA ADD_RUNNING_SCORE_DIGIT
    JSR add_running_score
    ;Add 500 to running score
    LDA #5
    STA ADD_RUNNING_SCORE_VALUE 
    LDA RUNNING_SCORE_100s
    STA ADD_RUNNING_SCORE_DIGIT
    JSR add_running_score
    RTS                    ;no other scoring is possible, GTFO

no_straight:
    ;Set SKIP_STRAIGHT for future iterations
    LDA #1
    STA SKIP_STRAIGHT

    ;Restore Y
    PLA
    TAY

check_three_pairs:
    ;Check whether 3 pairs have already been found
    LDA PAIRS_FOUND
    CMP #3
    BNE :+
        ;We have found 3 pairs, worth 1,500.
        ;Add 1,000 to running score
        LDA #1
        STA ADD_RUNNING_SCORE_VALUE 
        LDA RUNNING_SCORE_1000s
        STA ADD_RUNNING_SCORE_DIGIT
        JSR add_running_score
        ;Add 500 to running score
        LDA #5
        STA ADD_RUNNING_SCORE_VALUE 
        LDA RUNNING_SCORE_100s
        STA ADD_RUNNING_SCORE_DIGIT
        JSR add_running_score
        RTS                    ;no other scoring is possible, GTFO
    :

    ;Preserve Y on stack   
    TYA
    PHA

    ;Loop over dice_counts
    LDY #0
three_pairs_loop:
    LDA dice_counts, y 
    CMP #2
    BNE not_a_pair  
    INC PAIRS_FOUND

not_a_pair:
    INY
    CPY #6
    BNE three_pairs_loop

    ;Restore Y from stack
    PLA
    TAY

    ;Check whether 3 pairs have been found, if so, GTFO
    LDA TRIPLES_FOUND
    CMP #3
    BNE +:
        RTS 
    :

check_quad_and_pair:


check_singles:
    ;If the die face is 1 or 5, score single dice
    CPX #0              ;are we looking at a 1?
    BNE check_five

    ;Add 100 to running score
    LDA #1
    STA ADD_RUNNING_SCORE_VALUE 
    LDA RUNNING_SCORE_10s
    STA ADD_RUNNING_SCORE_DIGIT
    JSR add_running_score
    JMP skip

check_five:
    CPX #4              ;are we looking at a 5?
    BNE skip

    ;Add 50 to running score
    LDA #5
    STA ADD_RUNNING_SCORE_VALUE 
    LDA RUNNING_SCORE_10s
    STA ADD_RUNNING_SCORE_DIGIT
    JSR add_running_score

skip:
    INX
    CPX #6
    BEQ +:
        JMP score_loop
    :
    RTS
.endproc


;*****************************************************************
; Add a value to the running score
;   Inputs: ADD_RUNNING_SCORE_VALUE = the number to add
;           ADD_RUNNING_SCORE_DIGIT = the index of the digit to add it to
;   Preserves X
;*****************************************************************
.proc add_running_score
    ;Preserve X on stack
    TXA
    PHA

start:
    ;Load inputs
    LDA ADD_RUNNING_SCORE_VALUE
    LDX ADD_RUNNING_SCORE_DIGIT

    ;Add A to the selected digit
    CLC
    ADC running_score , x   
    STA running_score, x 

check_overflow:
    CMP #10
    BCC done                ;If result < 10, no overflow.

    ;Handle overflow
    SBC #10                 ;Correct the previous addition
    STA running_score, x    ;Subract 10 from result and store it

    ;Propagate carry to next highest digit
    INX
    CPX #6                      ;Have we processed all 6 digits?
    BCS done                    ;If so, exit
    STX ADD_RUNNING_SCORE_DIGIT ;Update the digit index
    LDA #1
    STA ADD_RUNNING_SCORE_VALUE ;Store the 1 to be added on next iteration
    JMP start                   ;Move on to next digit

done:                   
    PLA                     ;Restore X and return
    TAX
    RTS
.endproc

;*****************************************************************
; Add running_score to score
;*****************************************************************
.proc add_running_score_to_score
    LDX #0                  ;digit index
add_digit:
    CLC
    LDA running_score, x 
    ADC score, x
    STA score, x 

    ;Check for overflow
    CMP #10
    BCC next_digit          ;If result < 10, no overflow.

    ;Handle overflow
    SBC #10
    STA score, x

    ;Propagate carry to next highest digit
    INX
    CPX #6                  ;Have we processed all 6 digits?
    BCS done                ;If so, we're done

    ;Add the carried 1 to the next digit
    LDA #1
    CLC
    ADC score, x 
    STA score, x 

    JMP add_digit

    ;Check whether we've processed all 6 digits and continue adding if not
next_digit:
    INX             
    CPX #6
    BCC add_digit

done:
    RTS
.endproc
