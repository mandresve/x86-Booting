;  Este es solo un bootloader demostrativo, quizas puedas aprender mas cosas aqui
;

    bits 16                                     ; Codigo de 16 bits

;---------------------------------------------------
; Demo entry-point
;---------------------------------------------------

demo:
    mov ax, cs
    mov ds, ax                                  ; Just set the segments equal to the code segment 
    mov es, ax

    xor bx, bx
    mov ah, 0x0e                                ; Teletype output
    mov al, 0x4f
    int 0x10                                    ; Video interupt
    mov al, 0x77
    mov ah, 0x0e 
    int 0x10                                    ; Video interupt
    mov al, 0x4f
    mov ah, 0x0e 
    int 0x10                                    ; Video interupt

    xor ax, ax
    int 0x16                                    ; Get a single keypress

    xor bx, bx
    mov ah, 0x0e                                ; Teletype output
    mov al, 0x0d                                ; Carriage return
    int 0x10                                    ; Video interupt
    mov al, 0x0a                                ; Line feed
    int 0x10                                    ; Video interupt
    mov al, 0x0a                                ; Line feed
    int 0x10                                    ; Video interupt

    xor ax, ax
    int 0x19                                    ; Reboot the system

    hlt
