[bits 16] ; Use 16-bit mode
[org 0x7c00] ; "origin": assume that the program will be loaded starting from address 0x7c00

init:
    mov ah, 0x00 ; Set video mode (also clears the screen)
    mov al, 0x03 ; Text, 80x25, 16 fg / 8 bg colors
    int 0x10
    
main_loop:
    ; Limit framerate
    ; Read system clock ticks: increments about once every 55 ms, so we get
    ; about 18.2 ticks per second
    mov ah, 0x00
    int 0x1a
    cmp dx, [prev_tick_low]
    je main_loop
    mov [prev_tick_low], dx

; The efficient way to clear screen doesn't seem to work with QEMU, so we'll use
; a workaround for QEMU, which can be enabled by assembling with "-D QEMU".
; Without the flag we use the more efficient way.
%ifdef QEMU
    ; Clear screen by setting the video mode
    ; This is inefficient, but the recommended int10h 06h doesn't seem
    ; to work with QEMU.
    mov ah, 0x00
    mov al, 0x03
    int 0x10
    
    ; Hide the cursor
    ; This has to be done every time after setting the video mode
    mov ah, 0x01 ; Set cursor shape and size
    mov ch, 0x20
    mov cl, 0x20
    int 0x10

%else
    ; Clear screen the efficient way
    mov ah, 0x06 ; Clear screen rectangle
    mov al, 0x00 ; Blank entire rectangle
    mov bh, 0x07 ; Video attribute: white-on-black
    mov cl, 0x4f ; Rectangle lower-right x (assumes 80x25)
    mov ch, 0x18 ; Rectangle lower-right y (assumes 80x25)
    mov dx, 0x00 ; Rectangle upper-left x and y
    int 0x10
%endif

    ; Read player input
    mov ah, 0x01 ; Query keyboard status: Preview key
    int 0x16 ; Query keyboard status
    jz skip_move ; If no keys in buffer, skip blocking read
    mov ah, 0x00 ; Read and remove a keystroke from the buffer
    int 0x16

    ; Move player according to input
    cmp al, 0x61 ; 'a'
    jne skip_move_left
    mov bl, [player_x]
    sub bl, [player_vx]
    mov [player_x], bl
skip_move_left:
    cmp al, 0x64 ; 'd'
    jne skip_move_right
    mov bl, [player_x]
    add bl, [player_vx]
    mov [player_x], bl
skip_move_right:
skip_move:

    ; Check whether the ball hit the bottom
    cmp byte [ball_y], 0x18 ; max y (assumes 80x25)
    je game_over

    ; Check whether the ball bounces off player
    cmp byte [ball_y], 0x17
    jne skip_player_bounce ; The ball is too high, it can't hit player
    mov al, [player_x]
    cmp byte [ball_x], al ; Player left edge
    jl skip_player_bounce
    add al, [player_width]
    cmp byte [ball_x], al ; Player right edge
    jge skip_player_bounce
    mov byte [ball_vy], -1
skip_player_bounce:

    ; Bounce the ball off the borders
    cmp byte [ball_y], 0
    jne skip_top_bounce
    mov byte [ball_vy], 1
skip_top_bounce:
    cmp byte [ball_x], 0
    jne skip_left_bounce
    mov byte [ball_vx], 1
skip_left_bounce:
    cmp byte [ball_x], 0x4f ; max x (assumes 80x25)
    jne skip_right_bounce
    mov byte [ball_vx], -1
skip_right_bounce:

    ; Move the ball
    mov al, [ball_x]
    add al, [ball_vx]
    mov [ball_x], al
    mov al, [ball_y]
    add al, [ball_vy]
    mov [ball_y], al

    ; Draw player
    mov ah, 0x02 ; Set cursor position
    mov bh, 0x00 ; Video page 0
    mov dh, [player_y]
    mov dl, [player_x]
    int 0x10
    mov ah, 0x0a ; Write character to cursor location
    mov al, 0xfe ; Solid block character
    mov bh, 0x00 ; Video page 0
    mov cx, [player_width] ; Repeat once
    int 0x10

    ; Draw the ball
    mov ah, 0x02 ; Set cursor position
    mov bh, 0x00 ; Video page 0
    mov dh, [ball_y]
    mov dl, [ball_x]
    int 0x10
    mov ah, 0x0a ; Write character to cursor location
    mov al, 0x2a ; Character '*'
    mov bh, 0x00 ; Video page 0
    mov cx, 0x0001 ; Repeat once
    int 0x10
    
    jmp main_loop

game_over:
    hlt

prev_tick_low dw 0 ; The lower word of previous system clock tick reading

ball_x db 23
ball_y db 6

ball_vx db 1
ball_vy db 1

player_x db 40
player_y db 24
player_vx db 2
player_width db 10

times 510-($-$$) db 0 ; Zero-fill so that we have 510 bytes at this point
dw 0xaa55 ; Magic bytes which tell BIOS that the program is bootable
