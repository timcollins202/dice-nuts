;*****************************************************************
; Draw the title screen
;*****************************************************************
title_text:
    .byte "PRESS A TO UPDATE VRAM",0

title_attributes:
    .byte %00000101,%00000101,%00000101,%00000101
    .byte %00000101,%00000101,%00000101,%00000101

.proc draw_title_screen
    JSR ppu_off
    JSR clear_nametable

    ;write title text
    vram_set_address (NAME_TABLE_0_ADDRESS + 4 * 32 + 6)
    assign_16i text_address, title_text
    JSR write_text

    ;set the title text to use the 2nd palette entries
    vram_set_address (ATTRIBUTE_TABLE_0_ADDRESS + 8)
    assign_16i paddr, title_attributes
    LDY #0
loop:
    LDA (paddr), y 
    STA PPU_DATA
    INY
    CPY #8
    BNE loop

    JSR ppu_update      ;wait til the screen has been drawn

    RTS
.endproc


;*****************************************************************
; Draw Main Game Screen
;*****************************************************************
.segment "CODE"
.proc draw_game_screen
    JSR ppu_off
    JSR clear_nametable

    vram_set_address (NAME_TABLE_0_ADDRESS)

    ;draw 2 rows of bg filler tile
    JSR draw_bg_filler_row
    JSR draw_bg_filler_row

    ;draw upper chunk of playfield tiles
    LDY #0          ;iterator
loop1:
    LDA playfield_upper_1, y
    STA PPU_DATA
    INY
    CPY #255         ;32 tiles in a row
    BNE loop1
    STA PPU_DATA     ;get that last tile in there

    ;reset iterator and draw second chunk
    INY             ;roll over
loop2:
    LDA playfield_upper_2, y
    STA PPU_DATA
    INY
    CPY #64
    BNE loop2

    ;draw 2 rows of bg filler tile
    JSR draw_bg_filler_row
    JSR draw_bg_filler_row

    ;draw lower text box
    JSR draw_lower_text_box
    
    ;draw 2 rows of bg filler tile
    JSR draw_bg_filler_row
    JSR draw_bg_filler_row

    ;load attribute table
    vram_set_address (ATTRIBUTE_TABLE_0_ADDRESS)
    LDY #0      ;iterator
loop3:
    LDA playfield_attr, y 
    STA PPU_DATA
    INY
    CPY #64
    BNE loop3

    JSR ppu_update  ;wait til screen has been drawn
    
    RTS
.endproc



;*****************************************************************
; draw_bg_filler_row  -- Draws a row of background filler tiles
;   Inputs: Set VRAM address before calling this subroutine
;*****************************************************************
.segment "CODE"
.proc draw_bg_filler_row    
    LDA #$04        ;background filler tile
    LDY #0          ;iterator
loop:
    STA PPU_DATA
    INY
    CPY #32         ;32 tiles in a row
    BNE loop

    RTS
.endproc

;*****************************************************************
; draw_lower_text_box  -- Draws the empty lower text box
;   Inputs: Set VRAM address before calling this subroutine
;*****************************************************************
.segment "CODE"
.proc draw_lower_text_box
    LDX #0          ;big iterator
    LDY #0          ;small iterator

    LDA #$04
    STA PPU_DATA
    STA PPU_DATA
    LDA #$05
    STA PPU_DATA
upper_line:
    LDA #$06
    STA PPU_DATA
    INY
    CPY #26         ;26 horiz line tiles form top of box
    BNE upper_line
    LDA #$07
    STA PPU_DATA
    LDA #$04
    STA PPU_DATA
    STA PPU_DATA

    ;draw middle rows
    LDY #0          ;reset Y, top row is done
draw_row:
    CPX #12
    BEQ row_done
    LDA #$04
    STA PPU_DATA
    STA PPU_DATA
    LDA #$0a        ;vertical line tile
    STA PPU_DATA
    LDA #0          ;blank tile
blank_space:
    STA PPU_DATA
    INY
    CPY #26
    BNE blank_space
    LDY #0          ;reset Y
    LDA #$0a        ;vertical line tile
    STA PPU_DATA
    LDA #$04        ;bg filler tile
    STA PPU_DATA
    STA PPU_DATA
    INX     
    CPX #12
    BNE draw_row
row_done:
    LDA #$04
    STA PPU_DATA
    STA PPU_DATA
    LDA #$08        ;bottom left corner
    STA PPU_DATA
    LDX #0          ;reset iterators
    LDY #0
    LDA #$06        ;horiz line tile
lower_line:
    STA PPU_DATA
    INY 
    CPY #26
    BNE lower_line
    LDA #$09        ;bottom right corner
    STA PPU_DATA
    LDA #$04        ;background filler tile
    STA PPU_DATA
    STA PPU_DATA

    RTS
.endproc


;*****************************************************************
; Put player's selector sprite on screen
;*****************************************************************
.segment "CODE"
.proc draw_selector
    ;initialize pointed_to_die to 0
    LDA #0
    STA pointed_to_die

    ;display the player's selctor on the leftmost die
    ;set Y position of all 4 parts of the selector (byte 0)
    LDA #18                 ;Y position of 24 for top 2  was 49
    STA SELECTOR_1_YPOS
    STA SELECTOR_2_YPOS     
    LDA #51                 ;Y position of 32 for bottom 2
    STA SELECTOR_3_YPOS
    STA SELECTOR_4_YPOS
    ;set the tile number used by the sprite (byte 1)
    LDA #$02                ;all 4 sprites use the same tile, just rotated
    STA SELECTOR_1_TILE
    STA SELECTOR_2_TILE
    STA SELECTOR_3_TILE
    STA SELECTOR_4_TILE
    ;set sprite attributes (byte 2)
    LDA #SPRITE_PALETTE_1  
    STA SELECTOR_1_ATTR
    LDA #SPRITE_FLIP_HORIZ|SPRITE_PALETTE_1
    STA SELECTOR_2_ATTR
    LDA #SPRITE_FLIP_VERT|SPRITE_PALETTE_1
    STA SELECTOR_3_ATTR
    LDA #SPRITE_FLIP_HORIZ|SPRITE_FLIP_VERT|SPRITE_PALETTE_1
    STA SELECTOR_4_ATTR
    ;set the X position for all 4 parts of the selector (byte 3)
    LDA #31
    STA SELECTOR_1_XPOS
    STA SELECTOR_3_XPOS
    LDA #39
    STA SELECTOR_2_XPOS
    STA SELECTOR_4_XPOS

    RTS
.endproc



;*****************************************************************
; Put something in the VRAM buffer for it to update
;*****************************************************************
;for testing, we are storing this data in RODATA but it will be dynamically generated IRL.
;format: number of bytes for update (excluding VRAM address), VRAM starting address, then data.
vram_data:
    .byte 14, $20, $A6, "YOU PRESSED A"

.proc populate_vram_buffer
    LDX #0
loop:
    LDA vram_data, x 
    STA vram_buffer, x 
    INX
    CPX #17
    BNE loop
    RTS
.endproc

.proc read_vram_buffer_horiz_run
    LDX #0
    LDY vram_buffer, x    ;load number of bytes to write into Y
    INX
    LDA PPU_STATUS
    LDA vram_buffer, x    ;load the hi byte of the starting address
    STA PPU_ADDR
    INX
    LDA vram_buffer, x    ;load low byte of starting address
    STA PPU_ADDR
    INX
loop:
    LDA vram_buffer, x      ;Y is iterator
    STA PPU_DATA
    INX
    DEY
    CPY #0
    BNE loop
    RTS
.endproc


;*****************************************************************
; draw_die  -- Draws a die to screen
;   Inputs: paddr = VRAM address pointer
;           Y = number to put on die
;*****************************************************************
.proc draw_die
    ; Load the starting index from dice_tile_offsets based on the value in Y
    LDY draw_die_number
    LDA dice_tile_offsets, y
    TAX                  ; Store the starting index in X

    ; Set the initial VRAM address from paddr
    vram_set_address_i paddr

    ; Initialize big loop iterator
    LDY #0              ; Row counter (0-3)
    STY temp            ; Initialize temp to 0

big_loop:
    ; Draw one row (4 tiles)
    LDY #0              ; Column counter (0-3)
small_loop:
    LDA dice_tiles, x
    STA PPU_DATA
    INX
    INY
    CPY #4
    BNE small_loop     ; Repeat for 4 columns

    ; Move to the start of the next row in VRAM (32 tiles ahead)
    add_16_8 paddr, #32
    vram_set_address_i paddr

    ; Increment row counter
    LDY temp
    INY
    CPY #4
    BEQ done           ; Exit after 4 rows
    STY temp            ; Store the new row counter
    JMP big_loop

done:
    ;set needdraw_die and draw_die_number back to 0
    LDA #0
    STA needdraw_die
    STA draw_die_number
    RTS

.endproc


;*****************************************************************
; Animate dice when they are rolled
;*****************************************************************
.proc animate_dice
    ;loop over dice and see if any need to animate
    LDY #0                  ;iterator
loop:
    LDA dice_timers, y 
    CMP #0                  ;if timer = 0, die is not animating
    BEQ skip
    ;animate the die here
        LDA dice_roll       ;get whatever is in dice_roll
        STA draw_die_number

        ;set starting address for draw_die
        LDA PPU_STATUS
        LDA #$20
        STA paddr + 1
        LDA dice_starting_adresses_lo, y
        STA paddr

        ;decrement animation timer
        LDA dice_timers, y
        BEQ :+
            SEC  ;don't let it go below 0
            SBC #1
            STA dice_timers, y
        :
        LDA #1
        STA needdraw_die
        
        JSR wait_frame
skip:
    INY
    CPY #6
    BNE loop
    RTS
.endproc