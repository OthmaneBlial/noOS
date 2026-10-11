%define PIT_CLOCK 1193182
%define PIT_DIVISOR 11932      ; approximately 100 Hz; account using the real divisor
timer_init:
    pushad
    mov al, 0x36
    out 0x43, al
    mov ax, PIT_DIVISOR
    out 0x40, al
    mov al, ah
    out 0x40, al
    mov al, 0xfc              ; IRQ0 and IRQ1 only, after both handlers are installed
    out 0x21, al
    popad
    ret
timer_irq:
    add dword [timer_ticks], 1
    adc dword [timer_ticks+4], 0
    add dword [timer_cycles], PIT_DIVISOR
    cmp dword [timer_cycles], PIT_CLOCK
    jb .done
    sub dword [timer_cycles], PIT_CLOCK
    add dword [timer_seconds], 1
    adc dword [timer_seconds+4], 0
.done:
    ret
; ECX=number of ticks (<2^31); CF=1 if interrupts are disabled or request invalid.
; Preserve registers and original IF. STI/HLT closes the lost-wakeup window.
timer_delay:
    pushad
    pushfd
    pop ebx
    test ebx, 0x200
    jz .bad
    test ecx, 0x80000000
    jnz .bad
    mov edx, [timer_ticks]
.check:
    cli
    mov eax, [timer_ticks]
    sub eax, edx
    cmp eax, ecx
    jae .done
    sti
    hlt
    jmp .check
.done:
    push ebx
    popfd
    popad
    clc
    ret
.bad:
    popad
    stc
    ret
timer_selftest:
    pushad
    mov eax, [timer_ticks]
    mov [timer_test_start], eax
    mov ecx, 2
    call timer_delay
    jc .fail
    mov eax, [timer_ticks]
    sub eax, [timer_test_start]
    cmp eax, 2
    jb .fail
    mov ecx, 0x80000000
    call timer_delay
    jnc .fail
    cli
    mov ecx, 1
    call timer_delay
    jnc .fail
    sti
    mov esi, timer_ok
    call console_puts
    popad
    ret
.fail:
    int 3
align 4
timer_ticks dq 0
timer_seconds dq 0
timer_cycles dd 0
timer_test_start dd 0
timer_ok db '[TEST] PIT IRQ0 and tick-based delay PASS',10,0
