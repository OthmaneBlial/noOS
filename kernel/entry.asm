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
%include "kernel/lib/string.asm"
%include "kernel/interrupts/idt.asm"
%include "kernel/interrupts/isr.asm"
%include "kernel/interrupts/pic.asm"
%include "kernel/interrupts/irq.asm"
%include "kernel/drivers/keyboard.asm"
%include "kernel/drivers/timer.asm"
%include "kernel/drivers/cpu.asm"
%include "kernel/shell/shell.asm"
%include "kernel/shell/parser.asm"
%include "kernel/memory/physical.asm"
%include "kernel/memory/heap.asm"
%include "kernel/memory/paging.asm"
%include "kernel/shell/commands.asm"
%include "kernel/fs/initrd.asm"
%include "kernel/main.asm"
