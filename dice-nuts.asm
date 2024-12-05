;*****************************************************************
; Dice Nuts: A Dice Game for the NES
;*****************************************************************

;*****************************************************************
; Define NES cartridge header
;*****************************************************************
.segment "HEADER"
INES_MAPPER = 0 ; 0 = NROM
INES_MIRROR = 0 ; 0 = horizontal mirroring, 1 = vertical mirroring
INES_SRAM   = 0 ; 1 = battery backed SRAM at $6000-7FFF

.byte 'N', 'E', 'S', $1A ; ID 
.byte $02 ; 16k PRG bank count
.byte $01 ; 8k CHR bank count
.byte INES_MIRROR | (INES_SRAM << 1) | ((INES_MAPPER & $f) << 4)
.byte (INES_MAPPER & %11110000)
.byte $0, $0, $0, $0, $0, $0, $0, $0 ; padding


;*****************************************************************
; Include CHR files
;*****************************************************************
.segment "TILES"
.incbin "chr/dice-nuts-bg.chr"
.incbin "chr/dice-nuts-sp.chr"


;*****************************************************************
; Define vectors
;*****************************************************************
.segment "VECTORS"
.word nmi
.word reset
.word irq

;*****************************************************************
; Reserve memory for variables
;*****************************************************************
.segment "ZEROPAGE"
    need_horiz_update:  .res 1      ;non-zero if we need to update VRAM during vblank
    need_draw_die:      .res 1      ;non-zero if we need to draw a die to screen
    paddr:              .res 2      ;16-bit address pointer
    dice_roll:          .res 1      ;Stores an auto-incrementing value 1-6 for dice to grab
    temp:               .res 10     ;General purpose temp space
    dice_values:        .res 6      ;Numbers on the dice faces
    dice_selected:      .res 6      ;Each byte non-zero if that die is selected
    dice_timers:        .res 6      ;Dice rolling animation timers
    dice_delay:         .res 6      ;Dice animation frame delay counters
    kept_dice:          .res 6      ;Dice that have been kept for scoring
    gamestate:          .res 1      ;0-title/intro screen 1-rolling dice 2-selecting dice 3-scoring dice 4-game over
    pointed_to_die:     .res 1      ;stores which die the selector is on
    draw_die_number:    .res 1      ;number that draw_die needs to put on the die

.segment "OAM"
    oam:                .res 256    ;OAM sprite data

.segment "BSS"
    palette:            .res 32     ;current palette buffer
    vram_buffer:        .res 256    ;VRAM update buffer, stores changes to be written during vblank


;*****************************************************************
; Include external files
;*****************************************************************
.include "lib/neslib.asm"           ;General Purpose NES Library
.include "src/constants.inc"        ;Game-specific constants
.include "src/gameplay.asm"         ;Gameplay logic
.include "src/graphics.asm"         ;Graphics drawing routines
.include "src/player_actions.asm"   ;Handle player actions
.include "src/nmi.asm"              ;NMI handler 
.include "src/reset.asm"            ;Reset handler
.include "src/ro_data.asm"          ;Read-only data


;*****************************************************************
; IRQ - Clock Interrupt Routine     (not used)
;*****************************************************************
.segment "CODE"
irq:
	RTI


;*****************************************************************
; MAIN - Main application logic section. Includes the game loop.
;*****************************************************************
.segment "CODE"
.proc main
    ;rendering is currently off

    ;initialize palette table
    LDX #0
paletteloop:
    LDA default_palette, x 
    STA palette, x 
    INX
    CPX #32
    BCC paletteloop

    ;set our game settings
    LDA #VBLANK_NMI|BG_0000|OBJ_1000
    STA ppu_ctl0
    LDA #BG_ON|OBJ_ON
    STA ppu_ctl1

    ;initialize gamestate to 0
    LDA #0
    STA gamestate

    JSR draw_title_screen

titleloop:
    JSR gamepad_poll
    LDA gamepad
    AND #PAD_START     ;check whether start is pressed
    BEQ titleloop

    LDA #1
    STA gamestate
    
    JSR draw_game_screen
    JSR draw_selector

mainloop:
    JSR player_actions
    JSR animate_dice
    JSR set_gamestate

    JMP mainloop
.endproc

