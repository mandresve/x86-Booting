# Bootstrap

Este es nuestro intento de acceder al hardware x86 sin interferencia del SO moderno, como en los viejos tiempos :)
Aquí está el sistema operativo MVOS, especial para esta clase. Podrías hacerlo funcionar en tu sistema? necesitas compilarlo con GCC.
Wow otra pista de como esta funcionando esto: http://3zanders.co.uk/2017/10/18/writing-a-bootloader3/

## Lo que funciona

- Arrancar en nuestro propio kernel de modo protegido de 32 bits a través de GRUB. Ahora no hay nada entre nosotros y el hardware :).
- Imprimir caracteres en la consola de texto escribiendo en la dirección de memoria 0xB8000.
- Acceder a la interrupción 0x10 de la BIOS para entrar en el modo de gráficos VGA, cambiando temporalmente al modo real (no se puede acceder a la BIOS
  acceder en modo protegido).
    - Dibujar un píxel en los gráficos VGA escribiendo en la dirección de memoria 0xA0000.
    - Cambiar el color de la paleta escribiendo en el puerto I/O 0x3C8 y 0x3C9.
- Configurar el temporizador del PIC para llamar a nuestra función en intervalos regulares (para propósitos de sincronización) vía IRQ 0. Necesito manejar GDT, IDT, y
  IRQ para esto.
- Manejar los eventos de pulsación del teclado a través de la IRQ 1:
    - Cambiar la ubicación del cursor en la consola de texto escribiendo el puerto I/O 0x3D4 y 0x3D5.
    - Implementar kbhit() a través del buffer circular.
- Animación de campo estelar:
    - Escribir píxeles en un buffer antes de dibujar en la dirección de memoria VGA para una animación suave.
    - Debemos escribir nuestras propias funciones rand(), cos() y sin(), ya que no se puede utilizar la librería C estándar.
- Escribir el archivo .iso y arrancar en la unidad USB en mi moderno PC i7-10510U y monitor 4K.


## Documentación

- GCC no puede generar código de 16 bits desafortunadamente para el Modo Real, así que estamos forzados a usar el Modo Protegido de 32 bits para
  nuestro kernel.
- GDT: Una tabla (8 bytes por entrada de segmento) que describe: la ubicación real de un segmento (es decir, su memoria base), su
  tamaño, y su permiso si puede ejecutar/leer o leer/escribir. A diferencia del modo real de 16 bits, en el que DS, ES y SS apuntan a
  la dirección superior de 16 bits de los 20 bits, en el Modo Protegido de 32 bits DS, ES, FS, GS, SS se refieren a esta entrada de la tabla. GDT
  se activa ejecutando el comando de ensamblaje "lgdt".
- IDT: Una tabla (8 bytes por interrupción) que describe la ubicación en memoria de la función a ejecutar para la interrupción.
  Hay 256 interrupciones (ISR). Las ISR 0 - 31 están reservadas para las excepciones de la CPU, las ISR 32 - 47 son normalmente para las interrupciones de hardware
  IRQ 0 - 15, y el resto se puede utilizar para las interrupciones del sistema operativo. La tabla IDT se activa ejecutando el comando
  comando "lidt".
- IRQ: La IRQ 0 es activada por el temporizador del PIC (después de activar el temporizador escribiendo en los puertos de E/S específicos) y la función
  es llamada n-ésima vez por segundo. La IRQ 1 es activada por el teclado.
- No se puede acceder a las interrupciones del BIOS Legacy mientras se está en Modo Protegido. Podemos cambiar temporalmente al Modo Real para acceder a
  interrupción de la BIOS 0x10 para cambiar a gráficos VGA 320 x 200 por ejemplo.
  
## Build

 1. Build machine: Debian 10 x86_64 OS
       ```
       parallels@debian-gnu-linux-10:~$ uname -a
       Linux debian-gnu-linux-10 4.19.0-20-amd64 #1 SMP Debian 4.19.235-1 (2022-03-17) x86_64 GNU/Linux
       parallels@debian-gnu-linux-10:~$ cat /etc/issue
       Debian GNU/Linux 10 \n \l
       ```


 2. Build GCC Cross-Compiler (i686-elf):
       - Ref: https://wiki.osdev.org/GCC_Cross-Compiler
         Why do we need: https://wiki.osdev.org/Why_do_I_need_a_Cross_Compiler

       - Pre:
            ```
            $ mkdir -p ~/opt/cross
            $ mkdir -p ~/src
            ```

       - Download GNU Binutils:
            - Browse to: https://www.gnu.org/software/binutils/
              On "Obtaining binutils", check the latest version, for example: 2.38.

            - Browse to: https://ftp.gnu.org/gnu/binutils/
              Copy the link to the latest version, for example: https://ftp.gnu.org/gnu/binutils/binutils-2.38.tar.gz

       - Install dependencies:
            ```
            $ sudo apt install -y texinfo
            ```

       - Build GNU Binutils:
            ```
            $ cd ~/src/
            $ wget https://ftp.gnu.org/gnu/binutils/binutils-2.38.tar.gz
            $ tar xvzf binutils-2.38.tar.gz > /dev/null

            $ mkdir build-binutils
            $ cd build-binutils/
            $ ../binutils-2.38/configure --target=i686-elf --prefix="/home/parallels/opt/cross" --with-sysroot --disable-nls --disable-werror
            $ make
            $ make install

            $ ls -al ~/opt/cross/bin/
            $ ~/opt/cross/bin/i686-elf-as --version
            GNU assembler (GNU Binutils) 2.38
            This assembler was configured for a target of `i686-elf`.
            ```

       - Download GCC:
            - Browse to: https://www.gnu.org/software/gcc/
              On "Supported Releases", check the latest version, for example: GCC 11.3.

            - Browse to: https://ftp.gnu.org/gnu/gcc/
              Copy the link to the latest version, for example: https://ftp.gnu.org/gnu/gcc/gcc-11.3.0/gcc-11.3.0.tar.gz

       - Install dependencies:
            ```
            $ sudo apt install -y libgmp-dev libmpfr-dev libmpc-dev
            ```

       - Build GCC:
            ```
            $ cd ~/src/
            $ wget https://ftp.gnu.org/gnu/gcc/gcc-11.3.0/gcc-11.3.0.tar.gz
            $ tar xvzf gcc-11.3.0.tar.gz > /dev/null

            $ export PATH="/home/parallels/opt/cross/bin:$PATH"
            $ which -- i686-elf-as || echo i686-elf-as is not in the PATH
            /home/parallels/opt/cross/bin/i686-elf-as

            $ mkdir build-gcc
            $ cd build-gcc
            $ ../gcc-11.3.0/configure --target=i686-elf --prefix="/home/parallels/opt/cross" --disable-nls --enable-languages=c,c++ --without-headers
            $ make all-gcc
            $ make all-target-libgcc
            $ make install-gcc
            $ make install-target-libgcc

            $ ls -al ~/opt/cross/bin/
            $ ~/opt/cross/bin/i686-elf-gcc --version
            i686-elf-gcc (GCC) 11.3.0
            ```


 3. Compile the code:
       - Install dependencies:
            ```
            $ sudo apt install -y nasm xorriso
            ```

       - Compile:
            ```
            $ cd bootstrap/src/
            $ sh compile.sh
            ```


 4. Test using QEMU:
       - Test:
            ```
            $ qemu-system-i386 -cdrom myos.iso
            ```

## Prueba REAL
- Use Rufus o Balena Etcher para pasar el MVOS a una unidad USB
- Si ejecuta, usted es el ganador de 5.0 en el laboratorio!!
