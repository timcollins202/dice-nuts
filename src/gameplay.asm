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
; Score selected dice
;*****************************************************************
.proc score_dice


.endproc


;*****************************************************************
; Add the value in A to the score
;*****************************************************************
.proc add_score
    CLC
    ADC score           ; See Cruise, p.162
    STA score
    CMP #99
    BCC skip

    SEC                 ; The first byte has exceeded 99, so overflow
    SBC #100
    STA score
    INC score + 1
    LDA score + 1
    CMP #99
    BCC skip

    SEC                 ; The 2nd byte has exceeded 99, so overflow
    SBC #100
    STA score + 1
    INC score + 2
    LDA score + 2
    CMP #99
    BCC skip
    SEC                 ; If the 3rd byte exceeds 99, adjust and discard the overflow
    SBC #100
    STA score + 2

skip:
    ; load score bytes into vram buffer
    

    LDA #1               ;set flag to update score on screen
    STA need_horiz_update
    RTS
.endproc