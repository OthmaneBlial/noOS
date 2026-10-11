%define TASK_BYTES 24
%define TASK_COUNT 3
%define TASK_STACK_SIZE 4096
; PCB: saved ESP, ready state, work counter, switches, IRQ ticks, name pointer.
task_prepare:
    pushad
    pushfd
    cli
    mov dword [task_current], 0
    mov dword [task_quantum], 0
    mov dword [task_blocks+4], 1
    mov ebx, 1
.worker:
    mov ebp, ebx
    imul ebp, TASK_BYTES
    mov edi, ebx
    shl edi, 12
    add edi, task_stacks
    sub edi, 68               ; segments + PUSHAD + vector/error + ring-0 IRET frame
    mov [task_blocks+ebp], edi
    mov dword [task_blocks+ebp+4], 1
    mov dword [task_blocks+ebp+8], 0
    mov dword [task_blocks+ebp+12], 0
    mov dword [task_blocks+ebp+16], 0
    mov ecx, 17
    xor eax, eax
    push edi
    rep stosd
    pop edi
    mov dword [edi], 0x10
    mov dword [edi+4], 0x10
    mov dword [edi+8], 0x10
    mov dword [edi+12], 0x10
    mov [edi+44], ebx
    mov dword [edi+48], 48
    mov dword [edi+56], task_worker
    mov dword [edi+60], 0x08
    mov dword [edi+64], 0x202
    inc ebx
    cmp ebx, TASK_COUNT
    jb .worker
    mov byte [task_ready], 1
    popfd
    popad
    ret
task_yield:
    int 0x30
    ret
; Called only with interrupts masked, at the common interrupt-frame boundary.
task_schedule:
    cmp byte [task_ready], 1
    jne isr_restore
    mov ebx, [task_current]
    imul eax, ebx, TASK_BYTES
    mov [task_blocks+eax], esp
    mov ecx, TASK_COUNT
.next:
    inc ebx
    cmp ebx, TASK_COUNT
    jb .candidate
    xor ebx, ebx
.candidate:
    imul eax, ebx, TASK_BYTES
    cmp dword [task_blocks+eax+4], 1
    je .switch
    loop .next
    jmp isr_restore
.switch:
    mov dword [task_quantum], 0
    mov [task_current], ebx
    inc dword [task_blocks+eax+12]
    mov esp, [task_blocks+eax]
    jmp isr_restore
task_worker:
    imul ebp, eax, TASK_BYTES
.work:
    inc dword [task_blocks+ebp+8]
    mov eax, [task_blocks+ebp+8]
    cmp dword [task_quota], 0
    je .continue
    cmp eax, [task_quota]
    jae .exit
.continue:
    cmp byte [task_cooperative], 0
    je .work
    call task_yield
    jmp .work
.exit:
    cli
    mov dword [task_blocks+ebp+4], 0
    int 0x30
    ud2
task_selftest:
    pushad
    call task_prepare
    mov ebx, 0xdeadbeef
    mov edi, 0x13579bdf
    mov ecx, 8
.yield:
    call task_yield
    loop .yield
    cmp ebx, 0xdeadbeef
    jne .fail
    cmp edi, 0x13579bdf
    jne .fail
    cmp dword [task_current], 0
    jne .fail
    cmp dword [task_blocks+TASK_BYTES+8], 3
    jne .fail
    cmp dword [task_blocks+TASK_BYTES*2+8], 3
    jne .fail
    cmp dword [task_blocks+TASK_BYTES+4], 0
    jne .fail
    cmp dword [task_blocks+TASK_BYTES*2+4], 0
    jne .fail
    mov esi, task_test_ok
    call console_puts
    popad
    ret
.fail:
    int 3
task_preemption_selftest:
    pushad
    cli
    mov byte [task_cooperative], 0
    mov dword [task_quota], 0
    call task_prepare
    mov byte [task_preempt], 1
    sti
    mov ecx, 12
    call timer_delay
    cli
    mov byte [task_preempt], 0
    mov dword [task_blocks+TASK_BYTES+4], 0
    mov dword [task_blocks+TASK_BYTES*2+4], 0
    sti
    cmp dword [task_current], 0
    jne .fail
    cmp dword [task_blocks+TASK_BYTES+8], 0
    je .fail
    cmp dword [task_blocks+TASK_BYTES*2+8], 0
    je .fail
    cmp dword [task_blocks+TASK_BYTES+16], 0
    je .fail
    cmp dword [task_blocks+TASK_BYTES*2+16], 0
    je .fail
    mov esi, task_preempt_ok
    call console_puts
    popad
    ret
.fail:
    int 3
command_tasks:
    mov edi, task_on
    call string_equal
    test eax, eax
    jnz .on
    mov edi, task_off
    call string_equal
    test eax, eax
    jnz .off
    mov esi, task_usage
    jmp console_puts
.on:
    cli
    mov byte [task_preempt], 0
    call task_prepare
    mov byte [task_cooperative], 0
    mov dword [task_quota], 0
    mov byte [task_preempt], 1
    sti
    mov esi, task_started
    jmp console_puts
.off:
    cli
    mov byte [task_preempt], 0
    mov dword [task_blocks+TASK_BYTES+4], 0
    mov dword [task_blocks+TASK_BYTES*2+4], 0
    sti
    mov esi, task_stopped
    jmp console_puts
command_ps:
    mov esi, task_heading
    call console_puts
    xor ebp, ebp
.task:
    mov eax, ebp
    call print_u32
    mov esi, help_indent
    call console_puts
    imul ebx, ebp, TASK_BYTES
    mov esi, [task_blocks+ebx+20]
    call console_puts
    mov esi, task_done
    cmp dword [task_blocks+ebx+4], 0
    je .state
    mov esi, task_running
    cmp ebp, [task_current]
    je .state
    mov esi, task_ready_text
.state:
    call console_puts
    mov esi, task_work_text
    call console_puts
    mov eax, [task_blocks+ebx+8]
    call print_u32
    mov esi, task_switch_text
    call console_puts
    mov eax, [task_blocks+ebx+12]
    call print_u32
    mov esi, task_ticks_text
    call console_puts
    mov eax, [task_blocks+ebx+16]
    call print_u32
    call print_newline
    inc ebp
    cmp ebp, TASK_COUNT
    jb .task
    ret
align 16
task_current dd 0
task_quota dd 3
task_quantum dd 0
task_ready db 0
task_preempt db 0
task_cooperative db 1
align 4
task_blocks:
    dd 0,1,0,0,0,task_shell_name
    dd 0,0,0,0,0,task_a_name
    dd 0,0,0,0,0,task_b_name
align 16
task_stacks times TASK_STACK_SIZE*2 db 0
task_shell_name db 'shell',0
task_a_name db 'worker-a',0
task_b_name db 'worker-b',0
task_test_ok db '[TEST] Cooperative tasks: contexts/stacks/round-robin PASS',10,0
task_heading db 'Ring-0 tasks (no userspace isolation)',10,0
task_running db ' RUNNING',0
task_ready_text db ' READY',0
task_done db ' DONE',0
task_work_text db ' work=',0
task_switch_text db ' switches=',0
task_ticks_text db ' ticks=',0
task_preempt_ok db '[TEST] PIT preemption: non-yielding workers/context restoration PASS',10,0
task_on db 'on',0
task_off db 'off',0
task_usage db 'Usage: tasks on|off',10,0
task_started db 'PIT preemption enabled (2-tick quantum).',10,0
task_stopped db 'Workers stopped; shell remains running.',10,0
