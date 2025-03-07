;*****************************************************************
; constants.inc: Game-specific constants
;*****************************************************************

;*****************************************************************
; Temp memory management
;*****************************************************************
ADD_RUNNING_SCORE_VALUE = temp + 4
ADD_RUNNING_SCORE_DIGIT = temp + 5
SKIP_STRAIGHT           = temp + 6
PAIRS_FOUND             = temp + 7
TRIPLES_FOUND           = temp + 8
QUADS_FOUND             = temp + 9

;*****************************************************************
; Running score digit indices
;*****************************************************************
RUNNING_SCORE_10s   = 0
RUNNING_SCORE_100s  = 1
RUNNING_SCORE_1000s = 2

;*****************************************************************
; OAM sprite definitions
;*****************************************************************
SELECTOR_1_YPOS     = oam
SELECTOR_1_TILE     = oam + 1
SELECTOR_1_ATTR     = oam + 2
SELECTOR_1_XPOS     = oam + 3

SELECTOR_2_YPOS     = oam + 4
SELECTOR_2_TILE     = oam + 5
SELECTOR_2_ATTR     = oam + 6
SELECTOR_2_XPOS     = oam + 7

SELECTOR_3_YPOS     = oam + 8
SELECTOR_3_TILE     = oam + 9
SELECTOR_3_ATTR     = oam + 10
SELECTOR_3_XPOS     = oam + 11

SELECTOR_4_YPOS     = oam + 12
SELECTOR_4_TILE     = oam + 13
SELECTOR_4_ATTR     = oam + 14
SELECTOR_4_XPOS     = oam + 15