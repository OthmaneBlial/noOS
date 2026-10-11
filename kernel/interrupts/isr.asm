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
    mov eax, [esp+32]
    cmp eax, 32
    jb .exception
    cmp eax, 47
    ja .exception
    call irq_dispatch
    popad
    add esp, 8
    iretd
.exception:
    mov ebx, [esp+36]
    mov edx, [esp+40]
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
