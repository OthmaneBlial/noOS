%define PAGE_SIZE 4096
%define FRAME_LIMIT 32768      ; explicit initial 128 MiB management ceiling
%define MEMORY_LIMIT (FRAME_LIMIT*PAGE_SIZE)
%define LOW_FRAMES 256         ; reserve all low 1 MiB: loaders, kernel, heap, stack, VGA/BIOS
pmm_init:
    pushad
    cmp dword [0x4ff4], 0x534d4150
    jne .fail
    movzx ecx, word [0x4ff0]
    test ecx, ecx
    jz .fail
    cmp ecx, 128
    ja .fail
    mov edi, pmm_busy
    mov eax, -1
    push ecx
    mov ecx, FRAME_LIMIT/32
    rep stosd
    pop ecx
    mov esi, 0x5000
.usable:
    cmp dword [esi+16], 1
    jne .next_usable
    mov eax, [esi+8]
    mov edx, [esi+12]
    add [e820_usable], eax
    adc [e820_usable+4], edx
    call pmm_map_range
    jc .next_usable
    ; Only complete usable pages may be allocated.
    add eax, PAGE_SIZE-1
    shr eax, 12
    shr edx, 12
.free_page:
    cmp eax, edx
    jae .next_usable
    bts [pmm_eligible], eax
    btr [pmm_busy], eax
    inc eax
    jmp .free_page
.next_usable:
    add esi, 24
    loop .usable
    movzx ecx, word [0x4ff0]
    mov esi, 0x5000
.reserved:
    cmp dword [esi+16], 1
    je .next_reserved
    call pmm_map_range
    jc .next_reserved
    shr eax, 12
    add edx, PAGE_SIZE-1
    shr edx, 12
.reserve_page:
    cmp eax, edx
    jae .next_reserved
    btr [pmm_eligible], eax
    bts [pmm_busy], eax
    inc eax
    jmp .reserve_page
.next_reserved:
    add esi, 24
    loop .reserved
    xor eax, eax
.low:
    btr [pmm_eligible], eax
    bts [pmm_busy], eax
    inc eax
    cmp eax, LOW_FRAMES
    jb .low
    xor eax, eax
.count:
    bt [pmm_eligible], eax
    jnc .count_next
    inc dword [pmm_total]
    inc dword [pmm_free_count]
.count_next:
    inc eax
    cmp eax, FRAME_LIMIT
    jb .count
    cmp dword [pmm_free_count], 64
    jb .fail
    mov esi, pmm_ok
    call console_puts
    popad
    ret
.fail:
    mov esi, pmm_fail
    call console_puts
    int 3

; ESI=E820 record, EAX=start, EDX=clipped exclusive end; CF=outside managed range.
; Preserve EBX/ECX/ESI/EDI/EBP. Saturating 64-bit end calculation avoids wrapping.
pmm_map_range:
    cmp dword [esi+4], 0
    jne .outside
    mov eax, [esi]
    cmp eax, MEMORY_LIMIT
    jae .outside
    mov edx, [esi+8]
    cmp dword [esi+12], 0
    jne .clip
    add edx, eax
    jc .clip
    cmp edx, MEMORY_LIMIT
    jbe .valid
.clip:
    mov edx, MEMORY_LIMIT
.valid:
    clc
    ret
.outside:
    stc
    ret

; EAX=aligned physical address, CF=0; EAX=0/CF=1 on exhaustion. Others preserved.
pmm_alloc:
    push ebx
    push ecx
    cmp dword [pmm_free_count], 0
    je .empty
    mov ebx, [pmm_hint]
    mov ecx, FRAME_LIMIT
.scan:
    cmp ebx, FRAME_LIMIT
    jb .test
    mov ebx, LOW_FRAMES
.test:
    bts [pmm_busy], ebx
    jnc .found
    inc ebx
    loop .scan
.empty:
    xor eax, eax
    stc
    jmp .done
.found:
    mov eax, ebx
    inc ebx
    mov [pmm_hint], ebx
    dec dword [pmm_free_count]
    inc dword [pmm_used]
    shl eax, 12
    clc
.done:
    pop ecx
    pop ebx
    ret
; EAX=physical frame. CF=1 on misalignment, reserve, pin, bounds or double free.
pmm_free:
    push ebx
    test eax, PAGE_SIZE-1
    jnz .bad
    cmp eax, LOW_FRAMES*PAGE_SIZE
    jb .bad
    cmp eax, MEMORY_LIMIT
    jae .bad
    mov ebx, eax
    shr ebx, 12
    bt [pmm_eligible], ebx
    jnc .bad
    bt [pmm_pinned], ebx
    jc .bad
    btr [pmm_busy], ebx
    jnc .bad
    inc dword [pmm_free_count]
    dec dword [pmm_used]
    cmp ebx, [pmm_hint]
    jae .valid
    mov [pmm_hint], ebx
.valid:
    clc
    pop ebx
    ret
.bad:
    stc
    pop ebx
    ret
pmm_selftest:
    pushad
    mov eax, [pmm_free_count]
    mov [pmm_test_expected], eax
    call pmm_alloc
    jc .fail
    mov edi, eax
    call pmm_alloc
    jc .fail
    mov ebp, eax
    cmp eax, edi
    je .fail
    mov eax, edi
    inc eax
    call pmm_free
    jnc .fail
    xor eax, eax
    call pmm_free
    jnc .fail
    mov eax, MEMORY_LIMIT
    call pmm_free
    jnc .fail
    mov eax, edi
    call pmm_free
    jc .fail
    call pmm_free
    jnc .fail
    call pmm_alloc
    cmp eax, edi
    jne .fail
    call pmm_free
    jc .fail
    mov eax, ebp
    call pmm_free
    jc .fail
    xor edi, edi
.exhaust:
    call pmm_alloc
    jc .exhausted
    inc edi
    jmp .exhaust
.exhausted:
    cmp edi, [pmm_test_expected]
    jne .fail
    mov edi, LOW_FRAMES
.release:
    bt [pmm_eligible], edi
    jnc .next
    bt [pmm_pinned], edi
    jc .next
    mov eax, edi
    shl eax, 12
    call pmm_free
    jc .fail
.next:
    inc edi
    cmp edi, FRAME_LIMIT
    jb .release
    mov eax, [pmm_free_count]
    cmp eax, [pmm_test_expected]
    jne .fail
    mov esi, pmm_test_ok
    call console_puts
    popad
    ret
.fail:
    mov esi, pmm_fail
    call console_puts
    int 3
align 4
pmm_total dd 0
pmm_used dd 0
pmm_free_count dd 0
pmm_hint dd LOW_FRAMES
pmm_test_expected dd 0
e820_usable dq 0
pmm_eligible times FRAME_LIMIT/8 db 0
pmm_busy times FRAME_LIMIT/8 db 0xff
pmm_pinned times FRAME_LIMIT/8 db 0
pmm_ok db '[MEM] E820 physical memory initialized',10,0
pmm_fail db '[FAIL] Physical memory validation',10,0
pmm_test_ok db '[TEST] Frames: allocate/free/fragmentation/exhaustion/invalid PASS',10,0
