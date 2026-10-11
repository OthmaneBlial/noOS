%define HEAP_BASE 0x70000
%define HEAP_SIZE 65536
%define HEAP_HEADER 16
%define HEAP_MAGIC 0x4e484541
heap_init:
    mov dword [HEAP_BASE], HEAP_SIZE-HEAP_HEADER
    mov dword [HEAP_BASE+4], 0
    mov dword [HEAP_BASE+8], 0
    mov dword [HEAP_BASE+12], HEAP_MAGIC
    ret
; EAX=size -> EAX=16-byte-aligned pointer/CF=0, EAX=0/CF=1 on failure.
heap_alloc:
    pushad
    test eax, eax
    jz .fail
    cmp eax, HEAP_SIZE-HEAP_HEADER
    ja .fail
    add eax, 15
    and eax, -16
    mov edx, eax
    mov ebx, HEAP_BASE
.scan:
    cmp dword [ebx+12], HEAP_MAGIC
    jne .fail
    cmp dword [ebx+4], 0
    jne .next
    mov ecx, [ebx]
    cmp ecx, edx
    jae .found
.next:
    mov ebx, [ebx+8]
    test ebx, ebx
    jnz .scan
.fail:
    mov dword [esp+28], 0
    popad
    stc
    ret
.found:
    sub ecx, edx
    cmp ecx, HEAP_HEADER+16
    jb .whole
    lea edi, [ebx+edx+HEAP_HEADER]
    sub ecx, HEAP_HEADER
    mov [edi], ecx
    mov dword [edi+4], 0
    mov eax, [ebx+8]
    mov [edi+8], eax
    mov dword [edi+12], HEAP_MAGIC
    mov [ebx+8], edi
    mov [ebx], edx
.whole:
    mov dword [ebx+4], 1
    mov eax, [ebx]
    add [heap_used], eax
    inc dword [heap_allocations]
    lea eax, [ebx+HEAP_HEADER]
    mov [esp+28], eax
    popad
    clc
    ret
; EAX=exact live allocation pointer; CF=1 on invalid/interior/double free.
heap_free:
    pushad
    test eax, 15
    jnz .bad
    cmp eax, HEAP_BASE+HEAP_HEADER
    jb .bad
    cmp eax, HEAP_BASE+HEAP_SIZE
    jae .bad
    mov ebx, HEAP_BASE
    xor ebp, ebp
.scan:
    cmp dword [ebx+12], HEAP_MAGIC
    jne .bad
    lea edx, [ebx+HEAP_HEADER]
    cmp eax, edx
    je .found
    mov ebp, ebx
    mov ebx, [ebx+8]
    test ebx, ebx
    jnz .scan
.bad:
    popad
    stc
    ret
.found:
    cmp dword [ebx+4], 1
    jne .bad
    mov dword [ebx+4], 0
    mov eax, [ebx]
    sub [heap_used], eax
    dec dword [heap_allocations]
    mov edi, [ebx+8]
    test edi, edi
    jz .previous
    cmp dword [edi+4], 0
    jne .previous
    mov eax, [edi]
    add eax, HEAP_HEADER
    add [ebx], eax
    mov eax, [edi+8]
    mov [ebx+8], eax
.previous:
    test ebp, ebp
    jz .done
    cmp dword [ebp+4], 0
    jne .done
    mov eax, [ebx]
    add eax, HEAP_HEADER
    add [ebp], eax
    mov eax, [ebx+8]
    mov [ebp+8], eax
.done:
    popad
    clc
    ret
heap_selftest:
    pushad
    xor eax, eax
    call heap_alloc
    jnc .fail
    mov eax, -1
    call heap_alloc
    jnc .fail
    mov eax, 31
    call heap_alloc
    jc .fail
    test eax, 15
    jnz .fail
    mov edi, eax
    mov eax, 80
    call heap_alloc
    jc .fail
    mov ebp, eax
    mov eax, edi
    inc eax
    call heap_free
    jnc .fail
    mov eax, edi
    call heap_free
    jc .fail
    call heap_free
    jnc .fail
    mov eax, 32
    call heap_alloc
    cmp eax, edi
    jne .fail
    call heap_free
    jc .fail
    mov eax, ebp
    call heap_free
    jc .fail
    mov eax, HEAP_SIZE-HEAP_HEADER
    call heap_alloc
    jc .fail
    mov edi, eax
    mov eax, 1
    call heap_alloc
    jnc .fail
    mov eax, edi
    call heap_free
    jc .fail
    cmp dword [HEAP_BASE], HEAP_SIZE-HEAP_HEADER
    jne .fail
    cmp dword [heap_used], 0
    jne .fail
    mov esi, heap_ok
    call console_puts
    popad
    ret
.fail:
    mov esi, heap_fail
    call console_puts
    int 3
align 4
heap_used dd 0
heap_allocations dd 0
heap_ok db '[TEST] Heap: split/coalesce/exhaustion/invalid PASS',10,0
heap_fail db '[FAIL] Heap validation',10,0
