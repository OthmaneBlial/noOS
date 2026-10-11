%define KEY_UP 0x100
%define KEY_DOWN 0x101
%define KEY_LEFT 0x102
%define KEY_RIGHT 0x103
%define KEY_HOME 0x104
%define KEY_END 0x105
%define KEY_DELETE 0x106
%define KEY_CAPACITY 128
keyboard_init:
    pushad
    call keyboard_queue_selftest
    mov ecx, 65536
.ready:
    in al, 0x64
    test al, 2
    jz .enable
    loop .ready
    mov esi, keyboard_fail
    call console_puts
    cli
.stop:
    hlt
    jmp .stop
.enable:
    mov al, 0xae             ; enable first PS/2 port; BIOS supplies set-1 translation
    out 0x64, al
    mov al, 0xfd             ; only IRQ1; PIT is enabled at its later milestone
    out 0x21, al
    popad
    ret
keyboard_irq:
    inc dword [keyboard_irqs]
    in al, 0x64
    test al, 1
    jz .done
    test al, 0x20            ; ignore auxiliary/mouse data
    jnz .drain
    in al, 0x60
    cmp al, 0xe0
    je .extended
    cmp byte [keyboard_extended], 0
    jne .extended_key
    cmp al, 0x2a
    je .left_on
    cmp al, 0x36
    je .right_on
    cmp al, 0xaa
    je .left_off
    cmp al, 0xb6
    je .right_off
    test al, 0x80
    jnz .done
    cmp al, 0x3a
    je .caps
    movzx ebx, al
    movzx eax, byte [key_normal+ebx]
    cmp al, 'a'
    jb .symbol
    cmp al, 'z'
    ja .symbol
    mov cl, [keyboard_shift]
    test cl, cl
    setnz cl
    xor cl, [keyboard_caps]
    test cl, cl
    jz .enqueue
    sub al, 32
    jmp .enqueue
.symbol:
    cmp byte [keyboard_shift], 0
    je .enqueue
    movzx eax, byte [key_shifted+ebx]
.enqueue:
    jmp keyboard_enqueue
.done:
    ret
.drain:
    in al, 0x60
    ret
.extended:
    mov byte [keyboard_extended], 1
    ret
.extended_key:
    mov byte [keyboard_extended], 0
    test al, 0x80
    jnz .done
    mov ebx, KEY_UP
    cmp al, 0x48
    je .virtual
    inc ebx
    cmp al, 0x50
    je .virtual
    inc ebx
    cmp al, 0x4b
    je .virtual
    inc ebx
    cmp al, 0x4d
    je .virtual
    inc ebx
    cmp al, 0x47
    je .virtual
    inc ebx
    cmp al, 0x4f
    je .virtual
    inc ebx
    cmp al, 0x53
    jne .done
.virtual:
    mov eax, ebx
    jmp .enqueue
.left_on:
    or byte [keyboard_shift], 1
    ret
.right_on:
    or byte [keyboard_shift], 2
    ret
.left_off:
    and byte [keyboard_shift], 0xfe
    ret
.right_off:
    and byte [keyboard_shift], 0xfd
    ret
.caps:
    xor byte [keyboard_caps], 1
    ret
keyboard_enqueue:
    test eax, eax
    jz .done
    mov ebx, [key_head]
    lea ecx, [ebx+1]
    and ecx, KEY_CAPACITY-1
    cmp ecx, [key_tail]
    je .overflow
    mov [key_queue+ebx*2], ax
    mov [key_head], ecx
.done:
    ret
.overflow:
    inc dword [keyboard_dropped]
    ret
keyboard_queue_selftest:
    mov edi, 1
.fill:
    mov eax, edi
    call keyboard_enqueue
    inc edi
    cmp edi, KEY_CAPACITY+1
    jne .fill
    cmp dword [keyboard_dropped], 1
    jne .fail
    mov edi, 1
.drain:
    call keyboard_get
    cmp eax, edi
    jne .fail
    inc edi
    cmp edi, KEY_CAPACITY
    jne .drain
    call keyboard_get
    test eax, eax
    jnz .fail
    mov dword [keyboard_dropped], 0
    mov esi, queue_ok
    call serial_puts
    ret
.fail:
    int 3
queue_ok db '[TEST] Bounded keyboard queue PASS',10,0
; Return EAX=event or zero, preserving other registers and prior IF state.
keyboard_get:
    pushfd
    cli
    push ebx
    mov ebx, [key_tail]
    xor eax, eax
    cmp ebx, [key_head]
    je .done
    movzx eax, word [key_queue+ebx*2]
    inc ebx
    and ebx, KEY_CAPACITY-1
    mov [key_tail], ebx
.done:
    pop ebx
    popfd
    ret
align 4
keyboard_irqs dd 0
keyboard_dropped dd 0
key_head dd 0
key_tail dd 0
key_queue times KEY_CAPACITY dw 0
keyboard_shift db 0
keyboard_caps db 0
keyboard_extended db 0
keyboard_fail db '[FAIL] PS/2 controller timeout',10,0
key_normal:
    db 0,27,'1234567890-=',8,9
    db 'qwertyuiop[]',10,0,'asdfghjkl;',39,96,0,92
    db 'zxcvbnm,./',0,'*',0,' '
    times 128-($-key_normal) db 0
key_shifted:
    db 0,27,'!@#$%^&*()_+',8,9
    db 'QWERTYUIOP{}',10,0,'ASDFGHJKL:',34,'~',0,'|'
    db 'ZXCVBNM<>?',0,'*',0,' '
    times 128-($-key_shifted) db 0
