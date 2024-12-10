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
    CMP #0              ; Check if die value is still 0
    BEQ done            ; If any die value is 0, stay in current gamestate
    INY
    CPY #6              ; Check all 6 dice (0 to 5)
    BNE check_values    ; Continue checking if not done

    ; All dice have rolled, update gamestate to 2 = selecting dice
    LDA #2
    STA gamestate
    ;TODO - update textbox to explain selecting dice

done:
    RTS
.endproc


;*****************************************************************
; Increments dice_roll during vblank, keeping it between 1 and 6
;*****************************************************************
.proc increment_dice_roll
    LDY dice_roll
    CPY #6
    BNE :+
        LDA #1             ; Reset to 1 after 6
        STA dice_roll
        RTS
    :
    INY
    CPY #6                 ; Prevent incrementing to the "X" face
    BEQ reset
    STY dice_roll
    RTS
reset:
    LDA #1
    STA dice_roll
    RTS
.endproc


;*****************************************************************
; Get a value from dice_roll and draw that number on the selected die
;*****************************************************************
.proc roll_die
    ;store whatever's in dice_roll to dice_values[pointed_to_die]
    LDX pointed_to_die
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
    RTS
.endproc


;*****************************************************************
; Select a die for scoring
;*****************************************************************
.proc select_die
    ;get the value on the selected die and store it to temp
    LDA pointed_to_die
    TAX
    LDA dice_values, x 
    STA temp

    ;find the first 0 in kept_dice, where we will store the value
    LDY #255             ;iterator, will roll over to 0 
loop:
    INY
    LDA kept_dice, y 
    BNE loop

    ;store value at kept_dice, y
    LDA temp
    STA kept_dice, y 

    ; Set starting address for draw_die
    LDA PPU_STATUS       ; Reset PPU status (required before VRAM updates)
    LDA #$20
    STA paddr + 1
    LDA dice_starting_adresses_lo, x
    STA paddr

    ;draw an X on the die we selected
    LDA #6               ;7 is the index for the X'ed out die
    STA draw_die_number
    LDA #1
    STA need_draw_die
    RTS
.endproc