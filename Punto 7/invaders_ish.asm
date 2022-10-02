;;;
;;; Space Invaders-ish game in 510 bytes (or less!) of qemu bootable real mode x86 asm
;;;

;; NOTE: Assuming direction flag is clear, SP initialized to 6EF0h, BP = 0

use16           ; (Not needed) Use 16 bit code only
;org 07C00h		; Set bootsector to be at memory location hex 7C00h (UNCOMMENT IF USING AS BOOTSECTOR)
org 8000h		; Set memory offsets to start here

;; DEFINED VARIABLES AFTER SCREEN MEMORY - 320*200 = 64000 or FA00h =========================
sprites      equ 0FA00h
alien1       equ 0FA00h
alien2       equ 0FA04h
ship         equ 0FA08h
barrierArr   equ 0FA0Ch 
alienArr     equ 0FA20h  ; 2 words (1 dblword) - 32bits/aliens
playerX      equ 0FA24h
shotsArr     equ 0FA25h  ; 4 Y/X shot values - 8 bytes, 1st shot is player
alienY       equ 0FA2Dh
alienX       equ 0FA2Eh
num_aliens   equ 0FA2Fh  ; # of aliens still alive
direction    equ 0FA30h  ; # pixels that aliens move in X direction
move_timer   equ 0FA31h  ; 2 bytes (using BP) - # of game loops/timer ticks to wait before aliens move
change_alien equ 0FA33h  ; Use alternate sprite yes/no

;; CONSTANTS =====================================
SCREEN_WIDTH        equ 320     ; Width in pixels
SCREEN_HEIGHT       equ 200     ; Height in pixels
VIDEO_MEMORY        equ 0A000h
TIMER               equ 046Ch   ; # of timer ticks since midnight
BARRIERXY           equ 1655h
BARRIERX            equ 16h
BARRIERY            equ 55h
PLAYERY             equ 93
SPRITE_HEIGHT       equ 4
SPRITE_WIDTH        equ 8       ; Width in bits/data pixels
SPRITE_WIDTH_PIXELS equ 16      ; Width in screen pixels

; Colors
ALIEN_COLOR         equ 02h   ; Green
PLAYER_COLOR        equ 07h   ; Gray
BARRIER_COLOR       equ 27h   ; Red
PLAYER_SHOT_COLOR   equ 0Bh   ; Cyan
ALIEN_SHOT_COLOR    equ 0Eh   ; Yellow

;; SETUP =========================================
;; Set up video mode - VGA mode 13h, 320x200, 256 colors, 8bpp, linear framebuffer at address A0000h
mov ax, 0013h
int 10h

;; Set up video memory
push VIDEO_MEMORY
pop es          ; ES -> A0000h

;; Move initial sprite data into memory
mov di, sprites
mov si, sprite_bitmaps
mov cl, 6
rep movsw

lodsd           ; Store 5 barriers in memory for barrierArr
mov cl, 5
rep stosd

;; Set initial variables
mov cl, 5       ; Alien array & playerX
rep movsb

xor ax, ax      ; Shots array - 8 bytes Y/X values
mov cl, 4
rep stosw

mov cl, 7       ; AlienY/X, # of aliens, direction, move_timer, change_alien
rep movsb

push es
pop ds          ; DS = ES

;; GAME LOOP =====================================
game_loop:
    xor ax, ax      ; Clear screen to black first
    xor di, di
    mov cx, SCREEN_WIDTH*SCREEN_HEIGHT
    rep stosb       ; mov [ES:DI], al cx # of times

    ;; ES:DI now points to AFA00h
    ;; Draw aliens ------------------------------------------------
    mov si, alienArr 
    mov bl, ALIEN_COLOR
    mov ax, [si+13]       ; AL = alienY, AH = alienX
    cmp byte [si+19], cl  ; Change alien? CL = 0 from above
    mov cl, 4
    jg draw_next_alien_row    ; Nope, use normal sprite  
    add di, cx                ; Yes, use alternate sprite  (CX = 4)
    draw_next_alien_row:
        pusha
        mov cl, 8             ; # of aliens to check per row      
        .check_next_alien:
            pusha
            dec cx
            bt [si], cx     ; Bit test - copy bit to carry flag
            jnc .next_alien ; Not set, skip

            mov si, di      ; SI = alien sprite to draw
            call draw_sprite

            .next_alien:
                popa
                add ah, SPRITE_WIDTH+4
        loop .check_next_alien

        popa
        add al, SPRITE_HEIGHT+2
        inc si
    loop draw_next_alien_row

    ;; Draw player ship -------------------------------------------
    ;; SI currently poins to playerX
    lodsb       ; AL = playerX
    push si
    mov si, ship
    mov ah, PLAYERY
    xchg ah, al ; Swap playerX and playerY values
    mov bl, PLAYER_COLOR
    call draw_sprite

    ;; Draw barriers ----------------------------------------------
    ;; TODO: Move this first to draw before aliens to line up with
    ;;   screen data variables better, could save bytes
    mov bl, BARRIER_COLOR
    mov ax, BARRIERXY
    mov cl, 5
    draw_barrier_loop:
        pusha
        call draw_sprite
        popa
        add ah, 25      ; # of X pixels between barriers
        add si, SPRITE_HEIGHT
    loop draw_barrier_loop

    pop si  ; SI points to shotsArr

    ;; Check if shot hit anything ---------------------------------
    mov cl, 4
    get_next_shot:
        push cx
        lodsw            ; Get Y/X values for shot in AL/AH
        cmp al, 0        ; Y value is 0, skip
        jnz check_shot

        next_shot:
            pop cx
    loop get_next_shot

    jmp create_alien_shots

    check_shot:
        call get_screen_position     ; Put shot Y/X position in DI
        mov al, [di]

        ;; Hit player
        cmp al, PLAYER_COLOR
        je game_over

        xor bx, bx                  ; Reset BX to 0 to use in multiple places below

        ;; Hit barrier
        cmp al, BARRIER_COLOR
        jne .check_hit_alien

        mov bx, barrierArr          ; Start checking at first barrier
        mov ah, BARRIERX+SPRITE_WIDTH   ; Start checking at right side of sprite
        .check_barrier_loop:
            cmp dh, ah
            ja .next_barrier              

            sub ah, SPRITE_WIDTH        ; Get starting X value of barrier
            sub dh, ah                  ; Subtract from shot X

            pusha
            sub dl, BARRIERY            ; Subtract from shot Y
            add bl, dl                  ; BX now points to pixel row of barrier
            mov al, 7
            sub al, dh                  ; Subtract X value from max bit
            cbw                         ; AH = 0
            btr [bx], ax                ; Bit test & reset, clear bit in barrier
            mov byte [si-2], ah         ; Reset shot Y value to 0
            popa
            jmp next_shot

            .next_barrier:
                add ah, 25              ; Add X offset to check next barrier
                add bl, SPRITE_HEIGHT   ; Go to next barrier in array
        jmp .check_barrier_loop

        ;; Hit alien
        .check_hit_alien:
            cmp cl, 4           ; Are we on player shot?
            jne draw_shot       ; No, go on

            cmp al, ALIEN_COLOR ; Did player shot Hit alien?
            jne draw_shot       ; No, go on

            mov bx, alienArr
            mov ax, [bx+13]         ; AL = alienY, AH = alienX
            add al, SPRITE_HEIGHT   ; Bottom of alien sprite
            .get_alien_row:
                cmp dl, al          ; Compare shot Y to current alien row Y
                jg .next_row        ; Did not hit, check next row

                ;; Get alien within row that was hit
                mov cl, 8               ; # of aliens in each row
                add ah, SPRITE_WIDTH    ; Get right side of current alien sprite
                .get_alien:
                    dec cx
                    cmp dh, ah      ; Compare shot X to alien X value
                    ja .next_alien  ; Unsigned comparison, if above, go on
                    
                    ;; Got alien in row, now erase it
                    btr [bx], cx        ; Reset bit in alien array to erase
                    mov byte [si-2], 0  ; Reset Y value of shot
                    dec byte [si+8]     ; num_aliens - 1
                    jz game_over        ; Last alien is dead, won game!
                    jmp next_shot

                    .next_alien:
                        add ah, SPRITE_WIDTH+4
                jmp .get_alien

                .next_row:
                    add al, SPRITE_HEIGHT+2
                    inc bx
            jmp .get_alien_row

    ;; Draw shots -------------------------------------------------
    draw_shot:    
        mov bh, PLAYER_SHOT_COLOR
        mov al, [si-2]      ; Get Y value of shot
        dec ax              ; Move shot up
        cmp cl, 4           ; Is shot the player shot?
        je .draw            ; Yes, go on to draw

        mov bh, ALIEN_SHOT_COLOR    ; No, this is alien shot
        inc ax
        inc ax                      ; Move shot down
        cmp al, SCREEN_HEIGHT/2     ; Did shot hit bottom of screen?
        cmovge ax, bx               ; AX = BX if so, AL = 0 from BX = 0 above

        .draw:
            mov byte [si-2], al     ; Set new Y value of shot

            mov bl, bh              ; Copy color to BL
            xchg ax, bx             ; Put color in AX
            mov [di+SCREEN_WIDTH], ax   ; Draw 2 pixels 1 row down on screen
            stosw                       ; Draw 2 pixels on current row

        jmp next_shot

    ;; Create alien shots -----------------------------------------
    create_alien_shots:
       sub si, 6            ; Go to first Y value of alien shots 
       mov cl, 3            ; 3 alien shots
       .check_shot:
            mov di, si      ; DI pointing to shot Y/X
            lodsw           ; AX = shot Y/X
            cmp al, 0       ; Is shot Y 0? Shot not in play
            jg  .next_shot

            ;; Y value is 0, create shot - "pseudo-random" number 0-7
            mov ax, [CS:TIMER]
            and ax, 0007h           ; mask off lowest 3 bits
            imul ax, ax, SPRITE_WIDTH+4 ; Get X position to spawn shot at
            xchg ah, al             ; Move X position to AH, AL = 0
            add ax, [alienY]        ; Add alien Y to AL, and add alien X to AH
            stosw                   ; Move new shot Y/X values into shot array

            jmp move_aliens         ; Go on after making 1 shot

            .next_shot:
        loop .check_shot

    ;; Move aliens ------------------------------------------------
    ;; TODO: Try to change to use leftmost/rightmost aliens for comparisons,
    ;;   don't just check the top left alien
    move_aliens:
        ;; Using BP for move_timer, Push/pop only affects SP, BP is unaffected
        mov di, alienX
        inc bp
        cmp bp, [di+3]  ; Did current moves reach move_timer?
        jl get_input    ; No, go on

        ;; Yes, move aliens
        neg byte [di+5]     ; Toggle change_alien byte between 1 & -1, use next sprite
        xor bp, bp          ; Reset move counter
        mov al, [di+2]      ; # of pixels to move aliens in X direction
        
        add byte [di], al   ; Move aliens this many pixels
        jg .check_right_side    ; Did not hit left side of screen (X = 0)

        mov byte [di], cl       ; Did hit left side, reset to 0 (CL = 0 after create_alien_shots)
        jmp .move_down
        
        .check_right_side:
            mov al, 68
            cmp [di], al        ; Hit right side of screen?
            jle get_input       ; No, go on
            stosb               ; Yes, correct
            dec di

        .move_down:
            neg byte [di+2]     ; Move in opposite X direction
            dec di
            add byte [di], 5    ; Add to alienY value to move down
            cmp byte [di], BARRIERY ; Did aliens breach the barriers?
            jg game_over            ; Yes, lost game :'(
            dec byte [di+4]         ; Aliens will get slightly faster

    ;; Get player input -------------------------------------------
    get_input:
        mov si, playerX
        mov ah, 02h         ; Get keyboard flags (some BIOS may clobber AH, QEMU does not)
        int 16h
        test al, 1          ; Check if right shift pressed
        jz .check_left_shift
        add byte [si], ah   ; Add 2 to player X, move to the right

        .check_left_shift:
            test al, 2      ; Check if left shift pressed
            jz .check_alt
            sub byte [si], ah   ; Subtract 2 to player X, move to the left

        .check_alt:
            test al, 8      ; Check if alt pressed (either left or right)
            jz delay_timer

            ;; Create player shot
            lodsb           ; AL = playerX
            xchg ah, al     ; AH = playerX, AL = 02 from AH above

            ;; AL = 02, 2 + 90(5Ah) = 92, PLAYERY - 1, which is right above player
            ;;  sprite. AH = playerX, add 3 to spawn shot in the middle_ish of 
            ;;  player sprite.
            add ax, 035Ah
            mov [si], ax    ; Set new player shot Y/X values

    ;; Delay timer - 1 tick delay (1 tick = 18.2/second)
    delay_timer:
        mov ax, [CS:TIMER] 
        inc ax
        .wait:
            cmp [CS:TIMER], ax
            jl .wait
jmp game_loop

;; END GAME LOOP =====================================

;; End game & reset
game_over:
    xor ax, ax      ; Get a keystroke
    int 16h

    int 19h         ; Reload bootsector

;; Draw a sprite to the screen
;; Input parameters:
;;   SI = address of sprite to draw
;;   AL = Y value of sprite
;;   AH = X value of sprite
;;   BL = color
;; Clobbers:
;;   DX
;;   DI
draw_sprite:
    call get_screen_position    ; Get X/Y position in DI to draw at
    mov cl, SPRITE_HEIGHT
    .next_line:
        push cx
        lodsb                   ; AL = next byte of sprite data
        xchg ax, dx             ; save off sprite data
        mov cl, SPRITE_WIDTH    ; # of pixels to draw in sprite
        .next_pixel:
            xor ax, ax          ; If drawing blank/black pixel
            dec cx
            bt dx, cx           ; Is bit in sprite set? Copy to carry
            cmovc ax, bx        ; Yes bit is set, move BX into AX (BL = color)
            mov ah, al          ; Copy color to fill out AX
            mov [di+SCREEN_WIDTH], ax
            stosw                   
        jnz .next_pixel                               

        add di, SCREEN_WIDTH*2-SPRITE_WIDTH_PIXELS
        pop cx
    loop .next_line

    ret

;; Get X/Y screen position in DI
;; Input parameters:
;;   AL = Y value
;;   AH = X value
;; Clobbers: 
;;   DX
;;   DI
get_screen_position:
    mov dx, ax      ; Save Y/X values
    cbw             ; Convert byte to word - sign extend AL into AH, AH = 0 if AL < 128
    imul di, ax, SCREEN_WIDTH*2  ; DI = Y value
    mov al, dh      ; AX = X value
    shl ax, 1       ; X value * 2
    add di, ax      ; DI = Y value + X value or X/Y position

    ret

;; CODE SEGMENT DATA =================================
sprite_bitmaps:
    db 10011001b    ; Alien 1 bitmap
    db 01011010b
    db 00111100b
    db 01000010b

    db 00011000b    ; Alien 2 bitmap
    db 01011010b
    db 10111101b
    db 00100100b

    db 00011000b    ; Player ship bitmap
    db 00111100b
    db 00100100b
    db 01100110b

    db 00111100b    ; Barrier bitmap
    db 01111110b
    db 11100111b
    db 11100111b

    ;; Initial variable values
    dw 0FFFFh       ; Alien array
    dw 0FFFFh
    db 70           ; PlayerX
    ;; times 8 db 0 ; Shots array
    dw 230Ah        ; alienY & alien X | 10 = Y, 35 = X
    db 20h          ; # of aliens = 32 TODO: Remove & check if alienArr = 0, 
                    ;   This is probably not needed, can save some bytes
    db 0FBh         ; Direction -5
    dw 18           ; Move timer
    db 1            ; Change alien - toggle between 1 & -1

;; Boot signature ===================================
times 510-($-$$) db 0
dw 0AA55h
