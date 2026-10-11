bits 32
org 0x10000
kernel_entry:
    cli
    mov esp, 0x90000
    cld
    call serial_init
    call vga_init
    mov esi, hello
    call console_puts
    call kernel_main
.halt:
    hlt
    jmp .halt
hello db '[OK] Protected mode activated | noOS kernel entry',10,0
%include "kernel/drivers/serial.asm"
%include "kernel/drivers/vga.asm"
%include "kernel/lib/conversion.asm"
%include "kernel/interrupts/idt.asm"
%include "kernel/interrupts/isr.asm"
%include "kernel/interrupts/pic.asm"
%include "kernel/interrupts/irq.asm"
%include "kernel/drivers/keyboard.asm"
%include "kernel/main.asm"
