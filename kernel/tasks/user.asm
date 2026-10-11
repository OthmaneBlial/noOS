%define USER_BASE 0x40000000
%define USER_CODE_LIMIT (USER_BASE+65536)
%define USER_STACK (USER_BASE+0x1f000)
%define USER_STACK_TOP (USER_STACK+4096)
%define USER_MAX_FRAMES 20
user_init:
    pushad
    mov eax, user_tss
    mov word [user_gdt+40], 103
    mov [user_gdt+42], ax
    shr eax, 16
    mov [user_gdt+44], al
    mov byte [user_gdt+45], 0x89
    mov byte [user_gdt+46], 0
    mov [user_gdt+47], ah
    mov dword [user_tss+4], user_trap_top
    mov word [user_tss+8], 0x10
    mov word [user_tss+102], 104 ; no I/O bitmap inside TSS; CPL3 port I/O denied
    lgdt [user_gdtr]
    mov ax, 0x28
    ltr ax
    mov esi, user_ready
    call console_puts
    popad
    ret
; Fresh address space shares supervisor kernel mappings; user PDE is outside them.
user_prepare:
    pushad
    mov dword [user_frame_count], 0
    call user_frame
    jc .bad
    mov [user_directory], eax
    mov edi, eax
    mov esi, [page_directory]
    mov ecx, 1024
    rep movsd
    call user_frame
    jc .bad
    mov [user_table], eax
    mov edi, [user_directory]
    or eax, 7
    mov [edi+(USER_BASE >> 22)*4], eax
    call user_frame
    jc .bad
    mov edi, [user_table]
    or eax, 7
    mov [edi+((USER_STACK-USER_BASE)/4096)*4], eax
    popad
    clc
    ret
.bad:
    call user_cleanup
    popad
    stc
    ret
; EAX=zeroed frame, CF=exhaustion; all other registers preserved.
user_frame:
    push ecx
    push edi
    cmp dword [user_frame_count], USER_MAX_FRAMES
    jae .bad
    call pmm_alloc
    jc .bad
    mov ecx, [user_frame_count]
    mov [user_frames+ecx*4], eax
    inc dword [user_frame_count]
    push eax
    mov edi, eax
    xor eax, eax
    mov ecx, 1024
    rep stosd
    pop eax
    pop edi
    pop ecx
    clc
    ret
.bad:
    pop edi
    pop ecx
    stc
    ret
user_cleanup:
    pushad
.frame:
    cmp dword [user_frame_count], 0
    je .done
    dec dword [user_frame_count]
    mov ecx, [user_frame_count]
    mov eax, [user_frames+ecx*4]
    call pmm_free
    jc .fail
    jmp .frame
.done:
    popad
    ret
.fail:
    int 3
; user_entry is validated/mapped by caller. Returns EAX=exit code or -1 for fault.
user_enter:
    pushad
    pushfd
    cli
    mov [user_saved_esp], esp
    mov al, [task_preempt]
    mov [user_saved_preempt], al
    mov byte [task_preempt], 0 ; one synchronous user process; PIT/keyboard stay live
    mov byte [user_active], 1
    mov byte [user_seen], 0
    mov eax, [user_directory]
    mov cr3, eax
    mov ax, 0x23
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    push dword 0x23
    push dword USER_STACK_TOP
    push dword 0x202          ; IF=1, IOPL=0, NT=0
    push dword 0x1b
    push dword [user_entry]
    mov eax, [user_mode]
    iretd
syscall_dispatch:
    test byte [esp+60], 3
    jz .bad
    cmp byte [user_active], 1
    jne .bad
    cmp esp, user_trap_stack
    jb .bad
    cmp esp, user_trap_top-76
    ja .bad
    cmp byte [user_seen], 1
    je .dispatch
    mov byte [user_seen], 1
    mov esi, user_cpl
    call console_puts
.dispatch:
    mov eax, [esp+44]
    cmp eax, 1
    je .write
    cmp eax, 2
    je .exit
    cmp eax, 3
    je .ticks
    mov dword [esp+44], -38
    jmp isr_restore
.ticks:
    mov eax, [timer_ticks]
    mov [esp+44], eax
    jmp isr_restore
.write:
    mov ebx, [esp+32]
    mov ecx, [esp+40]
    cmp ecx, 1024
    ja .pointer
    test ecx, ecx
    jz .written
    cmp ebx, USER_BASE
    jb .pointer
    mov edx, ebx
    add edx, ecx
    jc .pointer
    cmp edx, USER_STACK_TOP
    ja .pointer
    dec edx
    sub edx, USER_BASE
    shr edx, 12
    mov eax, ebx
    sub eax, USER_BASE
    shr eax, 12
    mov edi, [user_table]
.page:
    mov esi, [edi+eax*4]
    and esi, 5
    cmp esi, 5
    jne .pointer
    cmp eax, edx
    je .valid
    inc eax
    jmp .page
.valid:
    mov esi, ebx
    push ecx
.byte:
    lodsb
    call console_putc
    loop .byte
    pop ecx
.written:
    mov [esp+44], ecx
    jmp isr_restore
.pointer:
    mov dword [esp+44], -14
    jmp isr_restore
.exit:
    mov eax, [esp+32]
    jmp user_finish
.bad:
    mov eax, 13
    xor ebx, ebx
    mov edx, [esp+56]
    jmp panic_exception
user_fault:
    mov ecx, eax
    mov esi, user_fault_text
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
    jne .done
    mov esi, cr2_msg
    call console_puts
    mov eax, cr2
    call print_hex
.done:
    call print_newline
    mov eax, -1
user_finish:
    cli
    mov edx, eax
    mov eax, [page_directory]
    mov cr3, eax
    mov ax, 0x10
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov byte [user_active], 0
    mov al, [user_saved_preempt]
    mov [task_preempt], al
    mov esp, [user_saved_esp]
    mov [esp+32], edx
    popfd
    popad
    ret
command_user:
    mov edi, user_options
    xor ebp, ebp
.option:
    call string_equal
    test eax, eax
    jnz .run
    add edi, 8
    inc ebp
    cmp ebp, 6
    jb .option
    mov esi, user_usage
    jmp console_puts
.run:
    mov [user_mode], ebp
    call user_prepare
    jc .memory
    call user_frame
    jc .cleanup
    mov edi, [user_table]
    mov ebx, eax
    or eax, 5                ; read-only user code page, CR0.WP remains enabled
    mov [edi], eax
    mov edi, ebx
    mov esi, user_blob
    mov ecx, user_blob_end-user_blob
    rep movsb
    mov dword [user_entry], USER_BASE
    call user_enter
    call user_cleanup
    mov esi, user_returned
    call console_puts
    call print_hex
    jmp print_newline
.cleanup:
    call user_cleanup
.memory:
    mov esi, user_no_memory
    jmp console_puts
align 8
user_gdt:
    dq 0,0x00cf9a000000ffff,0x00cf92000000ffff
    dq 0x00cffa000000ffff,0x00cff2000000ffff,0
user_gdtr dw 48-1
    dd user_gdt
align 16
user_tss times 104 db 0
user_trap_stack times 8192 db 0
user_trap_top:
user_directory dd 0
user_table dd 0
user_frame_count dd 0
user_frames times USER_MAX_FRAMES dd 0
user_saved_esp dd 0
user_entry dd 0
user_mode dd 0
user_active db 0
user_seen db 0
user_saved_preempt db 0
user_ready db '[USER] GDT/TSS ready; INT 80h DPL3; I/O denied',10,0
user_cpl db '[USER] CPL=3; syscall entered on TSS kernel stack',10,0
user_fault_text db '[USER FAULT] exception ',0
user_returned db '[USER] Returned to shell, status=',0
user_no_memory db '[USER ERROR] Frame allocation failed',10,0
user_usage db 'Usage: user demo|fault|write|stack|io|spin',10,0
user_options db 'demo',0,0,0,0,'fault',0,0,0,'write',0,0,0
    db 'stack',0,0,0,'io',0,0,0,0,0,0,'spin',0,0,0,0
; Position-independent demo copied into a separate read-only user frame.
user_blob:
    cmp eax, 1
    je .fault
    cmp eax, 2
    je .write
    cmp eax, 3
    je .stack
    cmp eax, 4
    je .io
    cmp eax, 5
    je .spin
    mov eax, 1
    mov ebx, USER_BASE+(.message-user_blob)
    mov ecx, .message_end-.message
    int 0x80
    cmp eax, .message_end-.message
    jne .bad
    mov eax, 1
    mov ebx, 0x10000
    mov ecx, 10
    int 0x80
    cmp eax, -14
    jne .bad
    mov eax, 1234
    int 0x80
    cmp eax, -38
    jne .bad
    xor ebx, ebx
.exit:
    mov eax, 2
    int 0x80
    ud2
.bad:
    mov ebx, 1
    jmp .exit
.fault:
    mov eax, [0x10000]
    jmp .bad
.write:
    mov byte [USER_BASE], 0
    jmp .bad
.stack:
    mov eax, [USER_STACK-4096]
    jmp .bad
.io:
    in al, 0x60
    jmp .bad
.spin:
    mov eax, 3
    int 0x80
    mov ebp, eax
.wait:
    mov ecx, 200000           ; visible non-syscall work; elapsed time still uses PIT
.work:
    loop .work
    mov eax, 3
    int 0x80
    sub eax, ebp
    cmp eax, 30
    jb .wait
    xor ebx, ebx
    jmp .exit
.message db 'Hello from real ring 3. Checked pointer and syscall ABI.',10
.message_end:
user_blob_end:
