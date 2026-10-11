; ESI/EDI=NUL strings; EAX=1 if equal, 0 otherwise. Other registers preserved.
string_equal:
    push esi
    push edi
    push ebx
.next:
    mov al, [esi]
    mov bl, [edi]
    cmp al, bl
    jne .no
    inc esi
    inc edi
    test al, al
    jnz .next
    mov eax, 1
    jmp .done
.no:
    xor eax, eax
.done:
    pop ebx
    pop edi
    pop esi
    ret
; ESI=source, EDI=destination (caller guarantees capacity); preserve registers.
string_copy:
    pushad
.next:
    lodsb
    stosb
    test al, al
    jnz .next
    popad
    ret
; ESI=NUL string; EAX=length, other registers preserved.
string_length:
    push esi
    xor eax, eax
.next:
    cmp byte [esi+eax], 0
    je .done
    inc eax
    jmp .next
.done:
    pop esi
    ret
