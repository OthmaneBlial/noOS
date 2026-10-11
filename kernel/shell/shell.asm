%define LINE_CAPACITY 128
%define HISTORY_CAPACITY 8
shell_start:
    mov esi, shell_ready
    call console_puts
.prompt:
    mov esi, prompt
    call console_puts
    movzx eax, word [vga_position]
    mov [shell_origin], eax
    mov dword [shell_length], 0
    mov dword [shell_cursor], 0
    mov dword [shell_drawn], 0
    mov byte [shell_line], 0
    mov eax, [history_count]
    mov [history_index], eax
.input:
    cli
    call keyboard_get
    test eax, eax
    jnz .event
    sti
    hlt
    jmp .input
.event:
    sti
    cmp eax, 10
    je .enter
    cmp eax, 8
    je .backspace
    cmp eax, 27
    je .escape
    cmp eax, 9
    je .tab
    cmp eax, KEY_UP
    je .up
    cmp eax, KEY_DOWN
    je .down
    cmp eax, KEY_LEFT
    je .left
    cmp eax, KEY_RIGHT
    je .right
    cmp eax, KEY_HOME
    je .home
    cmp eax, KEY_END
    je .end
    cmp eax, KEY_DELETE
    je .delete
    cmp eax, 32
    jb .input
    cmp eax, 127
    jae .input
.insert:
    cmp dword [shell_length], LINE_CAPACITY-1
    jae .input
    push eax
    mov esi, shell_line
    add esi, [shell_length]
    lea edi, [esi+1]
    mov ecx, [shell_length]
    sub ecx, [shell_cursor]
    inc ecx                  ; include trailing NUL
    std
    rep movsb
    cld
    pop eax
    mov ebx, [shell_cursor]
    mov [shell_line+ebx], al
    inc dword [shell_cursor]
    inc dword [shell_length]
    call serial_putc
    jmp .redraw
.tab:
    mov al, ' '
    jmp .insert
.escape:
    mov byte [shell_line], 0
    mov dword [shell_length], 0
    mov dword [shell_cursor], 0
    jmp .redraw
.backspace:
    cmp dword [shell_cursor], 0
    je .input
    dec dword [shell_cursor]
.delete:
    mov ebx, [shell_cursor]
    cmp ebx, [shell_length]
    jae .input
    lea edi, [shell_line+ebx]
    lea esi, [edi+1]
    mov ecx, [shell_length]
    sub ecx, ebx
    rep movsb
    dec dword [shell_length]
    jmp .redraw
.left:
    cmp dword [shell_cursor], 0
    je .input
    dec dword [shell_cursor]
    jmp .redraw
.right:
    mov eax, [shell_cursor]
    cmp eax, [shell_length]
    jae .input
    inc dword [shell_cursor]
    jmp .redraw
.home:
    mov dword [shell_cursor], 0
    jmp .redraw
.end:
    mov eax, [shell_length]
    mov [shell_cursor], eax
    jmp .redraw
.up:
    cmp dword [history_index], 0
    je .input
    mov eax, [history_index]
    cmp eax, [history_count]
    jne .previous
    mov esi, shell_line
    mov edi, history_draft
    call string_copy
.previous:
    dec dword [history_index]
    mov eax, [history_index]
    shl eax, 7
    lea esi, [history_lines+eax]
    jmp .recall
.down:
    mov eax, [history_index]
    cmp eax, [history_count]
    jae .input
    inc eax
    mov [history_index], eax
    cmp eax, [history_count]
    je .draft
    shl eax, 7
    lea esi, [history_lines+eax]
    jmp .recall
.draft:
    mov esi, history_draft
.recall:
    mov edi, shell_line
    call string_copy
    mov esi, shell_line
    call string_length
    mov [shell_length], eax
    mov [shell_cursor], eax
.redraw:
    call shell_redraw
    jmp .input
.enter:
    mov eax, [shell_origin]
    add eax, [shell_length]
    mov [vga_position], ax
    call print_newline
    call history_save
    call shell_execute
    jmp .prompt

shell_redraw:
    pushad
    mov ebp, [vga_scrolls]
    mov eax, [shell_origin]
    mov [vga_position], ax
    mov esi, shell_line
.character:
    lodsb
    test al, al
    jz .erase
    call vga_putc
    jmp .character
.erase:
    mov ecx, [shell_drawn]
    sub ecx, [shell_length]
    jle .position
.blank:
    mov al, ' '
    call vga_putc
    loop .blank
.position:
    mov eax, [vga_scrolls]
    sub eax, ebp
    imul eax, VGA_COLS
    sub [shell_origin], eax
    mov eax, [shell_length]
    mov [shell_drawn], eax
    mov eax, [shell_origin]
    add eax, [shell_cursor]
    mov [vga_position], ax
    call vga_cursor
    popad
    ret

history_save:
    mov esi, shell_line
.skip:
    cmp byte [esi], ' '
    je .next
    cmp byte [esi], 9
    jne .valid
.next:
    inc esi
    jmp .skip
.valid:
    cmp byte [esi], 0
    je .done
    mov eax, [history_count]
    cmp eax, HISTORY_CAPACITY
    jb .space
    mov esi, history_lines+LINE_CAPACITY
    mov edi, history_lines
    mov ecx, (HISTORY_CAPACITY-1)*LINE_CAPACITY
    rep movsb
    dec eax
    jmp .copy
.space:
    inc dword [history_count]
.copy:
    shl eax, 7
    lea edi, [history_lines+eax]
    mov esi, shell_line
    call string_copy
.done:
    ret
align 4
shell_length dd 0
shell_cursor dd 0
shell_drawn dd 0
shell_origin dd 0
history_count dd 0
history_index dd 0
shell_line times LINE_CAPACITY db 0
history_draft times LINE_CAPACITY db 0
history_lines times HISTORY_CAPACITY*LINE_CAPACITY db 0
prompt db 'noOS> ',0
shell_ready db '[SH] Shell initialized. Type help to explore.',10,10,0
