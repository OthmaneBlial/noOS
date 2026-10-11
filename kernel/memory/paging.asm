paging_init:
    pushad
    call paging_frame
    mov [page_directory], eax
    mov edi, eax
    xor eax, eax
    mov ecx, 1024
    rep stosd
    xor ebp, ebp
.table:
    call paging_frame
    mov edi, eax
    mov ebx, [page_directory]
    or eax, 3                ; present, writable, supervisor only
    mov [ebx+ebp*4], eax
    mov eax, ebp
    shl eax, 22
    or eax, 3
    mov ecx, 1024
.page:
    stosd
    add eax, PAGE_SIZE
    loop .page
    inc ebp
    cmp ebp, MEMORY_LIMIT/(4*1024*1024)
    jb .table
    mov ebx, [page_directory]
    mov edi, [ebx]
    and edi, -PAGE_SIZE
    mov dword [edi], 0         ; explicit unmapped null page
    or dword [edi+(0xb8000/PAGE_SIZE)*4], 0x18 ; uncached VGA device mapping
    ; Check the exact mappings needed by entry, stack, E820, heap and VGA.
    mov esi, required_pages
    mov ecx, 5
.validate:
    lodsd
    mov edx, eax
    shr eax, 12
    mov eax, [edi+eax*4]
    test eax, 1
    jz .fail
    and eax, -PAGE_SIZE
    cmp eax, edx
    jne .fail
    loop .validate
    mov eax, [page_directory]
    test eax, PAGE_SIZE-1
    jnz .fail
    mov cr3, eax
    mov eax, cr0
    or eax, 0x80010000         ; paging plus supervisor write-protect
    mov cr0, eax
    jmp .active
.active:
    call pmm_alloc
    jc .fail
    mov dword [eax], 0x50414745
    cmp dword [eax], 0x50414745
    jne .fail
    call pmm_free
    jc .fail
    mov eax, [page_directory]
    call pmm_free
    jnc .fail                 ; paging structures must not be freed
    mov esi, paging_ok
    call console_puts
    popad
    ret
.fail:
    mov esi, paging_fail
    call console_puts
    int 3
paging_frame:
    push ebx
    call pmm_alloc
    jc .fail
    mov ebx, eax
    shr ebx, 12
    bts [pmm_pinned], ebx
    pop ebx
    ret
.fail:
    pop ebx
    mov esi, paging_fail
    call console_puts
    int 3
align 4
page_directory dd 0
required_pages dd 0x10000,0x8f000,0x5000,HEAP_BASE,0xb8000
paging_ok db '[MEM] Paging enabled (supervisor identity map, null guard)',10,0
paging_fail db '[FAIL] Paging validation/allocation',10,0
