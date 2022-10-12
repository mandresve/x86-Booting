;  Este es un bootloader de "Hola Mundo!"
;

;---------------------------------------------------
; Especificaciones iniciales
;---------------------------------------------------

bits 16 			; especificamos a NASM que este es un codigo de 16 bits
org 0x7c00 			; especificamos a NASM iniciar a colocar cosas en el BIOS Interrupt call 0x7c00

;---------------------------------------------------
; Boot
;---------------------------------------------------

boot:

    mov si,saludo 	; apuntar el registro %si a la posición de memoria de la etiqueta saludo
    mov ah,0x0e 	; 0x0e significa 'Escribir caracteres por consola (TTY)'
    
    ; Emulación de un Diskette (Floppy 3 1/4) sobre el sector de arranque del ISO/USB
    OEMname:           db    "mkfs.fat"  ; mkfs.fat is what OEMname mkdosfs uses
    bytesPerSector:    dw    512
    sectPerCluster:    db    1
    reservedSectors:   dw    1
    numFAT:            db    2
    numRootDirEntries: dw    224
    numSectors:        dw    2880
    mediaType:         db    0xf0
    numFATsectors:     dw    9
    sectorsPerTrack:   dw    18
    numHeads:          dw    2
    numHiddenSectors:  dd    0
    numSectorsHuge:    dd    0
    driveNum:          db    0
    reserved:          db    0
    signature:         db    0x29
    volumeID:          dd    0x2d7e5a1a
    volumeLabel:       db    "NO NAME    "
    fileSysType:       db    "FAT12   "
	;resb 0x50
    
.loop:
    lodsb
    or al,al		; al == 0 ?
    jz halt  		; si (al == 0) entonces salte a 'halt' -> detener el prog porque se acabaron los caracteres
    int 0x10 		; si no, ejecuta la interrupcion de la BIOS 0x10 - Servicio de Video
    jmp .loop		; ejecute loop de nuevo
    
halt:
    cli 			; borra la bandera de interrupción
    hlt 			; detiene el programa
    
;---------------------------------------------------
; Main
;---------------------------------------------------
    
saludo: 

	db "Hola Mundo desde el Kernel!",0

times 510 - ($-$$) db 0 	; rellenar los 510 bytes restantes con ceros en el MBR
dw 0xAA55 					; numero magico de bootloader - ¡marca este sector de 512 bytes como arrancable!
