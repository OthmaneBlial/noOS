shell_execute:
    mov esi, shell_line
.leading:
    cmp byte [esi], ' '
    je .skip_leading
    cmp byte [esi], 9
    jne .command
.skip_leading:
    inc esi
    jmp .leading
.command:
    cmp byte [esi], 0
    je .done
    mov [shell_command], esi
.scan:
    mov al, [esi]
    test al, al
    jz .args
    cmp al, ' '
    je .terminate
    cmp al, 9
    je .terminate
    inc esi
    jmp .scan
.terminate:
    mov byte [esi], 0
    inc esi
.args:
    cmp byte [esi], ' '
    je .skip_arg
    cmp byte [esi], 9
    jne .lookup
.skip_arg:
    inc esi
    jmp .args
.lookup:
    mov [shell_args], esi
    mov ebx, command_table
.entry:
    cmp dword [ebx], 0
    je .unknown
    mov esi, [shell_command]
    mov edi, [ebx]
    call string_equal
    test eax, eax
    jnz .found
    add ebx, 16
    jmp .entry
.found:
    mov esi, [shell_args]
    cmp dword [ebx+8], 0
    jne .call
    cmp byte [esi], 0
    jne .usage
.call:
    call [ebx+4]
.done:
    ret
.usage:
    mov esi, usage_prefix
    call console_puts
    mov esi, [ebx+12]
    call console_puts
    call print_newline
    ret
.unknown:
    mov esi, unknown_prefix
    call console_puts
    mov esi, [shell_command]
    call console_puts
    call print_newline
    ret
shell_command dd 0
shell_args dd 0
usage_prefix db 'Usage: ',0
unknown_prefix db 'Unknown command: ',0
