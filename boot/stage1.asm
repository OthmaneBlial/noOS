bits 16
org 0x7c00

; BIOS entry is normalized before using any labels. DL is the boot drive.
jmp 0:start
start:
    cli
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7c00
    cld
    sti
    mov [drive], dl
    mov si, banner
    call puts
    mov bx, 0x55aa
    mov ah, 0x41
    int 0x13
    jc disk_error
    cmp bx, 0xaa55
    jne disk_error
    test cx, 1
    jz disk_error
    mov si, dap
    mov dl, [drive]
    mov ah, 0x42
    int 0x13
    jc disk_error
    mov dl, [drive]
    jmp 0:0x8000
disk_error:
    mov si, error
    call puts
    cli
.halt:
    hlt
    jmp .halt
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
drive db 0
banner db 'noOS Bootloader v0.1',13,10,'[OK] Boot sector loaded',13,10,0
error db '[BOOT ERROR] BIOS EDD disk read failed',13,10,0
align 4
dap:
    db 16, 0
    dw 8
    dw 0x8000, 0
    dq 1
times 510-($-$$) db 0
dw 0xaa55
