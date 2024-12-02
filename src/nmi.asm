;*****************************************************************
; NMI - called every vBlank
;*****************************************************************
.segment "CODE"
.proc nmi
    ;save registers
    PHA
    TXA
    PHA
    TYA
    PHA

    BIT PPU_STATUS
    ;transfer sprite OAM data using DMA
    LDA #>oam
    STA SPRITE_DMA

    ;do we need to update vram?
    LDA needupdate
    BEQ :+
        JSR read_vram_buffer_horiz_run
    :

    ;do we need to draw a die?
    LDA needdraw_die
    BEQ :+
        JSR draw_die
    :

    ;transfer current palette to PPU
    vram_set_address $3f00
    LDX #0      ;transfer the 32 bytes to VRAM
@loop:
    LDA palette, x
    STA PPU_DATA
    INX
    CPX #32
    BCC @loop

    ;write current scroll and control settings to PPU
    LDA #0
    STA PPU_SCROLL
    STA PPU_SCROLL
    LDA ppu_ctl0
    STA PPU_CONTROL
    LDA ppu_ctl1
    STA PPU_MASK

    JSR increment_dice_roll

    ;reset nmi_ready to 0
    LDA #0
    STA nmi_ready

    ;restore registers and return
    PLA
    TAY
    PLA
    TAX
    PLA

    RTI
.endproc

