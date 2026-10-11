%assign vector 0
%rep 256
isr_%+vector:
%if vector != 8 && vector != 10 && vector != 11 && vector != 12 && vector != 13 && vector != 14 && vector != 17 && vector != 21 && vector != 29 && vector != 30
    push dword 0
%endif
    push dword vector
    jmp isr_common
%assign vector vector+1
%endrep
isr_common:
    cld
    pushad
    push ds
    push es
    push fs
    push gs
    mov ax, 0x10
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov eax, [esp+48]
    cmp eax, 128
    je syscall_dispatch
    cmp eax, 48
    je task_schedule
    cmp eax, 32
    jb isr_exception
    cmp eax, 47
    ja isr_exception
    call irq_dispatch
    cmp dword [esp+48], 32
    jne isr_restore
    cmp byte [task_preempt], 1
    jne isr_restore
    mov ebx, [task_current]
    imul ebx, 24              ; PCB stride; scheduler defines appear later
    inc dword [task_blocks+ebx+16]
    inc dword [task_quantum]
    cmp dword [task_quantum], 2
    jae task_schedule         ; IRQ dispatcher already acknowledged the PIC
isr_restore:
    pop gs
    pop fs
    pop es
    pop ds
    popad
    add esp, 8
    iretd
isr_exception:
    mov ebx, [esp+52]
    mov edx, [esp+56]
    test byte [esp+60], 3
    jnz user_fault
    jmp panic_exception
isr_table:
%assign vector 0
%rep 256
    dd isr_%+vector
%assign vector vector+1
%endrep
panic_exception:
    cli
    mov byte [vga_color], 0x4f
    mov ecx, eax
    mov esi, exception_msg
    call console_puts
    call print_u32
    mov esi, error_msg
    call console_puts
    mov eax, ebx
    call print_hex
    mov esi, eip_msg
    call console_puts
    mov eax, edx
    call print_hex
    cmp ecx, 14
    jne .stop
    mov esi, cr2_msg
    call console_puts
    mov eax, cr2
    call print_hex
.stop:
    call print_newline
    mov esi, stopped_msg
    call console_puts
.halt:
    hlt
    jmp .halt
exception_msg db 10,'KERNEL PANIC: exception ',0
error_msg db ' error=',0
eip_msg db ' EIP=',0
cr2_msg db ' CR2=',0
stopped_msg db 'CPU halted. Reset required.',10,0
