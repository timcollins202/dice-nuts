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
    STA running_score
    STA running_score + 1
    STA running_score + 2
    STA running_score + 3
    STA running_score + 4
    STA running_score + 5
    STA SKIP_STRAIGHT
    STA PAIRS_FOUND
    STA TRIPLES_FOUND
    STA QUADS_FOUND

    ;Count occurrences of each die value in dice_kept and update dice_counts.
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

    ;If it isn't a 1, we can rule out a straight
    CMP #1              
    BEQ :+
        INC SKIP_STRAIGHT
    :

    ;If it is a 1, check for single die scoring
    BNE :++
        ;If the face value is 1 or 5, score single die
        ;X contains the face value - 1
        ;Check for a 1
        CPX #0
        BNE :+
            ;Add 100 to running score
            LDA #1
            STA ADD_RUNNING_SCORE_VALUE 
            LDA #RUNNING_SCORE_100s
            STA ADD_RUNNING_SCORE_DIGIT
            JSR add_running_score
            JMP continue
        :
        ;Check for a 5
        CPX #4
        BNE :+
            ;Add 50 to running score
            LDA #5
            STA ADD_RUNNING_SCORE_VALUE 
            LDA #RUNNING_SCORE_10s
            STA ADD_RUNNING_SCORE_DIGIT
            JSR add_running_score
            JMP continue
        :
    :

    ;Check for a pair
    CMP #2
    BNE :+
        INC PAIRS_FOUND ;Pairs aren't scored unless there are 3, or with a quad
        JMP continue
    :

    ;Check for a triple
    CMP #3
    BNE :+
        INC TRIPLES_FOUND   ;Trips score differently for 1 or 2 of them, handled later
        JMP continue
    :

    ;Check for a quad
    CMP #4
    BNE :+
        INC QUADS_FOUND
        JMP continue
    :

    ;Check for a quint
    CMP #5
    BNE :+
        ;Add 2,000 to running score
        LDA #2
        STA ADD_RUNNING_SCORE_VALUE
        LDA #RUNNING_SCORE_1000s
        STA ADD_RUNNING_SCORE_DIGIT
        JSR add_running_score
        JMP continue
    :

    ;Check for a sextet
    CMP #6
    BNE :+
        ;Add 3,000 to running score
        LDA #3
        STA ADD_RUNNING_SCORE_VALUE
        LDA #RUNNING_SCORE_1000s
        STA ADD_RUNNING_SCORE_DIGIT
        JSR add_running_score
        RTS               ;no further scoring is possible, GTFO
    :

continue:
    INX
    CPX #6
    BNE score_loop

    ;Check flags and score accordingly
    ;Check for straight
    LDA SKIP_STRAIGHT     ;If SKIP_STRAIGHT was not set in loop, we have a straight
    BNE :+
        JSR add_1500_running_score
        RTS               ;no other scoring is possible, GTFO
    :

    ;Check for three pairs
    LDA PAIRS_FOUND
    CMP #3
    BNE :+
        JSR add_1500_running_score
        RTS               ;no other scoring is possible, GTFO        
    :

    ;Check for quads
    LDA QUADS_FOUND
    BEQ :++
        ;If we have a quad, do we also have a pair?
        LDA PAIRS_FOUND
        CMP #1
        BNE :+
            ;Score a quad and a pair
            JSR add_1500_running_score
            RTS           ;no other scoring is possible, GTFO           
        :
        ;Score just a quad
        LDA #1
        STA ADD_RUNNING_SCORE_VALUE
        LDA #RUNNING_SCORE_1000s
        STA ADD_RUNNING_SCORE_DIGIT
        JSR add_running_score
        RTS               ;no other scoring is possible, GTFO
    :

    ;Check for triples
    ;Check for a single triple first
    LDA TRIPLES_FOUND
    CMP #1
    BNE :+
        ;Put the index of the 3 in dice_counts in A
        JSR find_triple_value
        ;Score that * 100 points
        STA ADD_RUNNING_SCORE_VALUE
        LDA #RUNNING_SCORE_100s
        STA ADD_RUNNING_SCORE_DIGIT
        JSR add_running_score
    :
    ;Check for two triples
    CMP #2
    BNE :+
        ;Score 2,500 for two triples
        ;Add 2,000 to running score
        LDA #2
        STA ADD_RUNNING_SCORE_VALUE 
        LDA #RUNNING_SCORE_1000s
        STA ADD_RUNNING_SCORE_DIGIT
        JSR add_running_score
        ;Add 500 to running score
        LDA #5
        STA ADD_RUNNING_SCORE_VALUE 
        LDA #RUNNING_SCORE_100s
        STA ADD_RUNNING_SCORE_DIGIT
        JSR add_running_score
    :

    RTS
.endproc

.proc add_1500_running_score
    ;Add 1,000 to running score
    LDA #1
    STA ADD_RUNNING_SCORE_VALUE 
    LDA #RUNNING_SCORE_1000s
    STA ADD_RUNNING_SCORE_DIGIT
    JSR add_running_score
    ;Add 500 to running score
    LDA #5
    STA ADD_RUNNING_SCORE_VALUE 
    LDA #RUNNING_SCORE_100s
    STA ADD_RUNNING_SCORE_DIGIT
    JSR add_running_score
    RTS
.endproc

.proc find_triple_value
    ;find the index of the first 3 in dice_count, add 1 and return it in A   
    TYA
    PHA

    LDY #0
loop:
    LDA dice_counts, y 
    CMP #3
    BEQ found
    INY
    CPY #6
    BNE loop

    LDA #$ff     ;if no 3 is found, return $ff.  this should never happen,
    PLA          ;but we need to be able to tell if it did just in case, 
    TAY          ;otherwise fails will always return 6.
    RTS

found:
    STY temp
    PLA
    TAY
    LDA temp
    CLC
    ADC #1       ;convert from index to face value
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
