cpu_init:
    pushad
    pushfd
    pop eax
    mov ecx, eax
    xor eax, 1<<21
    push eax
    popfd
    pushfd
    pop eax
    push ecx
    popfd
    xor eax, ecx
    test eax, 1<<21
    jz .done
    mov byte [cpu_available], 1
    xor eax, eax
    cpuid
    mov [cpu_vendor], ebx
    mov [cpu_vendor+4], edx
    mov [cpu_vendor+8], ecx
    test eax, eax
    jz .done
    mov eax, 1
    cpuid
    mov [cpu_signature], eax
    mov [cpu_features], edx
    mov ebx, eax
    shr ebx, 8
    and ebx, 15
    mov [cpu_family], ebx
    cmp ebx, 15
    jne .model
    mov ecx, eax
    shr ecx, 20
    and ecx, 255
    add [cpu_family], ecx
.model:
    mov ecx, eax
    shr ecx, 4
    and ecx, 15
    cmp ebx, 6
    je .extended
    cmp ebx, 15
    jne .store
.extended:
    mov edx, eax
    shr edx, 12
    and edx, 0xf0
    or ecx, edx
.store:
    mov [cpu_model], ecx
    and eax, 15
    mov [cpu_stepping], eax
.done:
    popad
    ret
align 4
cpu_signature dd 0
cpu_features dd 0
cpu_family dd 0
cpu_model dd 0
cpu_stepping dd 0
cpu_available db 0
cpu_vendor times 13 db 0
