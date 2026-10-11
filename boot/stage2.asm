bits 16
org 0x8000
%include "build/layout.inc"
start:
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov [drive], dl
    mov bp, KERNEL_SECTORS
.load:
    mov si, dap
    mov dl, [drive]
    mov ah, 0x42
    int 0x13
    jc disk_error
    add word [dap+6], 0x20     ; one sector; never cross a 64 KiB DMA boundary
    inc dword [dap+8]
    dec bp
    jnz .load
    mov si, loaded
    call puts
    in al, 0x92
    or al, 2
    and al, 0xfe
    out 0x92, al
    call check_a20
    jnz .a20_ok
    mov ax, 0x2401
    int 0x15
    call check_a20
    jz a20_error
.a20_ok:
    mov si, a20_ok
    call puts
    cli
    lgdt [gdtr]
    mov si, gdt_ok
    call puts
    mov eax, cr0
    or eax, 1
    mov cr0, eax
    jmp 0x08:protected_entry

; Return ZF=0 if the addresses separated by 1 MiB do not alias.
check_a20:
    push ds
    push es
    xor ax, ax
    mov ds, ax
    dec ax
    mov es, ax
    mov al, [0x500]
    mov ah, [es:0x510]
    push ax
    mov byte [0x500], 0
    mov byte [es:0x510], 0xff
    cmp byte [0x500], 0xff
    pop ax
    mov [es:0x510], ah
    mov [0x500], al
    pop es
    pop ds
    ret
puts:
    lodsb
    test al, al
    jz .done
    out 0xe9, al
    mov ah, 0x0e
    xor bx, bx
    int 0x10
    jmp puts
.done:
    ret
disk_error:
    mov si, disk_msg
    jmp fail
a20_error:
    mov si, a20_msg
fail:
    call puts
    cli
.halt:
    hlt
    jmp .halt
drive db 0
loaded db '[OK] Kernel loaded',13,10,0
a20_ok db '[OK] A20 enabled (verified)',13,10,0
gdt_ok db '[OK] GDT initialized',13,10,0
disk_msg db '[BOOT ERROR] Kernel disk read failed',13,10,0
a20_msg db '[BOOT ERROR] A20 activation failed',13,10,0
align 4
dap:
    db 16,0
    dw 1,0,0x1000
    dq 9
%include "boot/gdt.asm"
bits 32
protected_entry:
    mov ax, 0x10
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax
    mov esp, 0x90000
    cld
    jmp 0x08:0x10000
