;*****************************************************************
; Handle player actions
;*****************************************************************
.proc player_actions
    JSR gamepad_poll                ;read button state
    LDA gamepad
    CMP gamepad_last                ;make sure button state has changed
    BNE :+
        RTS                         ;if not, GTFO
    :

    AND #PAD_R
    BEQ not_pressing_right
    ;we are pressing right. Make sure we aren't already on right edge
    LDA SELECTOR_1_XPOS         ;get X position of top left selector sprite
    CMP #111                    ;can't go any farther right than this
    BEQ not_pressing_right
        ;we are not on right edge.  Move selector to the next die to the right
        JSR move_selector_right
        JSR set_pointed_to_die

not_pressing_right:
    LDA gamepad
    AND #PAD_L
    BEQ not_pressing_left
        ;we are pressing left.  Make sure we aren't already at left edge.
        LDA SELECTOR_1_XPOS
        CMP #31                    ;starting X pos is 24 for top right sprite
        BEQ not_pressing_left
            ;we are not on left edge.  Move selector the next die to the left
            JSR move_selector_left
            JSR set_pointed_to_die


not_pressing_left:
    LDA gamepad
    AND #PAD_D
    BEQ not_pressing_down
        ;we are pressing down.  Make sure we're not already on bottom row.
        LDA SELECTOR_1_YPOS
        CMP #50
        BEQ not_pressing_down
            ;we are pressing down. Move selector down.
            JSR move_selector_down
            JSR set_pointed_to_die

not_pressing_down:
    LDA gamepad 
    AND #PAD_U
    BEQ not_pressing_up
        ;we are pressing up.  Make sure we're not already on top row.
        LDA SELECTOR_1_YPOS
        CMP #18
        BEQ not_pressing_up 
            ;we are not on top row.  Move selector to top row.
            JSR move_selector_up
            JSR set_pointed_to_die

not_pressing_up:
    LDA gamepad
    AND #PAD_A
    BEQ not_pressing_a
        ;we are pressing A.  See if we are rolling dice
        LDA gamestate ;gamestate 1 = rolling dice
        CMP #1
        BNE :+
            ;we are pressing A.  Roll em!            
            JSR roll_die
        ;next, check for gamestate=2 and select dice
        :
        CMP #2
        BNE not_pressing_a
            JSR select_die

not_pressing_a:
    LDA gamepad
    AND #PAD_B
    BEQ not_pressing_b
        ;we are pressing B.  See if we are selecting dice
        LDA gamestate       ;gamestate 2 = selecting dice
        CMP #2
        BNE not_pressing_b
            LDA #3
            STA gamestate   ;gamestate 3 = scoring dice
            ;JSR score_dice

not_pressing_b:

    RTS
.endproc

.proc move_selector_right
    CLC
    ADC #40
    STA SELECTOR_1_XPOS     ;move top left sprite
    LDA SELECTOR_2_XPOS     ;get top right sprite's X position
    CLC
    ADC #40
    STA SELECTOR_2_XPOS    ;move top right sprite
    LDA SELECTOR_3_XPOS    ;get bottom left sprite's X position
    CLC 
    ADC #40
    STA SELECTOR_3_XPOS    ;move bottom left sprite
    LDA SELECTOR_4_XPOS    ;get bottom right sprite's X position
    CLC 
    ADC #40
    STA SELECTOR_4_XPOS    ;move bottom right sprite

    RTS
.endproc

.proc move_selector_left
    SEC
    SBC #40
    STA SELECTOR_1_XPOS
    LDA SELECTOR_2_XPOS
    SEC
    SBC #40
    STA SELECTOR_2_XPOS
    LDA SELECTOR_3_XPOS
    SEC
    SBC #40
    STA SELECTOR_3_XPOS
    LDA SELECTOR_4_XPOS
    SEC
    SBC #40
    STA SELECTOR_4_XPOS

    RTS
.endproc

.proc move_selector_down
    CLC
    ADC #32
    STA SELECTOR_1_YPOS 
    LDA SELECTOR_2_YPOS
    CLC
    ADC #32
    STA SELECTOR_2_YPOS
    LDA SELECTOR_3_YPOS
    CLC 
    ADC #32
    STA SELECTOR_3_YPOS
    LDA SELECTOR_4_YPOS
    CLC 
    ADC #32
    STA SELECTOR_4_YPOS    

    RTS
.endproc

.proc move_selector_up
    SEC
    SBC #32
    STA SELECTOR_1_YPOS
    LDA SELECTOR_2_YPOS
    SEC
    SBC #32
    STA SELECTOR_2_YPOS
    LDA SELECTOR_3_YPOS
    SEC
    SBC #32
    STA SELECTOR_3_YPOS
    LDA SELECTOR_4_YPOS
    SEC
    SBC #32
    STA SELECTOR_4_YPOS

    RTS
.endproc

.proc set_pointed_to_die
    LDA SELECTOR_1_YPOS
    CMP #$12
    BNE bottom_row
        LDA SELECTOR_1_XPOS
        CMP #$1f
        BNE :+
            LDA #0
            JMP done
        :
        CMP #$47
        BNE :+
            LDA #1
            JMP done
        :
        CMP #$6f
        BNE :+
            LDA #2
            JMP done
bottom_row:
        LDA SELECTOR_1_XPOS
        CMP #$1f
        BNE :+
            LDA #3
            JMP done
        :
        CMP #$47
        BNE :+
            LDA #4
            JMP done
        :
        CMP #$6f
        BNE :+
            LDA #5
            JMP done
done:
    STA pointed_to_die
    RTS
.endproc