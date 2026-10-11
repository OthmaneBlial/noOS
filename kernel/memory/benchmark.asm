command_bench:
    pushad
    mov edi, [timer_ticks]
    mov ebp, [pmm_free_count]
    mov ecx, 100000
.pair:
    call pmm_alloc
    jc .fail
    call pmm_free
    jc .fail
    loop .pair
    cmp ebp, [pmm_free_count]
    jne .fail
    mov eax, [timer_ticks]
    sub eax, edi
    mov esi, frame_bench_text
    call console_puts
    call print_u32
    mov esi, frame_bench_limit
    call console_puts
    popad
    ret
.fail:
    int 3
frame_bench_text db 'Frame benchmark: 100000 alloc/free pairs; elapsed PIT ticks: ',0
frame_bench_limit db 10,'PIT-quantized elapsed time includes IRQ/preemption; zero means below tick resolution.',10,0
