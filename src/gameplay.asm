;*****************************************************************
; increment_dice_roll:  Increments dice_roll during vblank, 
;   keeping it between 1 and 6
;*****************************************************************
.proc increment_dice_roll
    LDY dice_roll
    CPY #6
    BNE :+
        LDA #1
        STA dice_roll
        RTS
    :
    INY
    STY dice_roll

    RTS
.endproc

;*****************************************************************
; Get a value from dice_rolls and draw that number on the selected die
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

    ;set needdraw_die to 1 for NMI to pick up
    LDA #1
    STA needdraw_die
    RTS
.endproc