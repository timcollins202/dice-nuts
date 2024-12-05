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

done:
    RTS
.endproc


;*****************************************************************
; increment_dice_roll:  Increments dice_roll during vblank,
;   keeping it between 1 and 6
;*****************************************************************
.proc increment_dice_roll   
    LDA dice_roll
    CLC              ; Clear carry for addition
    ADC #1           ; Increment
    CMP #7           ; Check if it exceeds 6
    BCC :+           ; If less than 7, skip reset
    LDA #1           ; Reset to 1
    :
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