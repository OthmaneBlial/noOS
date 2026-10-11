command_ls:
    cmp byte [fs_mount_initrd], 1
    je initrd_ls
    mov esi, fs_listing
    call console_puts
    cmp dword [fs_dir], 0
    jne .entries
    mov esi, initrd_listing
    call console_puts
.entries:
    mov ebp, fs_meta+512
    mov ecx, FS_ENTRIES
.entry:
    cmp dword [ebp], 0
    je .next
    mov eax, [fs_dir]
    cmp [ebp+4], eax
    jne .next
    lea esi, [ebp+16]
    call console_puts
    cmp dword [ebp], FS_TYPE_DIR
    jne .file
    mov al, '/'
    call console_putc
    jmp .newline
.file:
    mov esi, help_indent
    call console_puts
    mov eax, [ebp+8]
    call print_u32
    mov esi, initrd_bytes
    call console_puts
    jmp .next
.newline:
    call print_newline
.next:
    add ebp, FS_ENTRY_SIZE
    loop .entry
    ret
command_cat:
    cmp byte [fs_mount_initrd], 1
    je initrd_cat
    mov edi, initrd_prefix
    mov ecx, 8
    push esi
    repe cmpsb
    pop esi
    jne .file
    add esi, 8
    jmp initrd_cat
.file:
    call fs_find
    test eax, eax
    jz fs_not_found
    cmp dword [eax], FS_TYPE_FILE
    jne fs_not_found
    mov ebp, [eax+8]
    test ebp, ebp
    jz .newline
    mov edx, [eax+48]
    mov [fs_read_checksum], edx
    mov edx, [eax+12]
    shl ebx, 4
    shl edx, 3
    lea eax, [ebx+edx+FS_DATA_LBA]
    mov edi, fs_data
    mov ecx, 8
.sector:
    call ata_read
    jc fs_io_failed
    inc eax
    add edi, 512
    loop .sector
    call fs_data_checksum
    cmp eax, [fs_read_checksum]
    jne .corrupt
    mov ecx, ebp
    mov esi, fs_data
    test ecx, ecx
    jz .newline
.byte:
    lodsb
    call console_putc
    loop .byte
.newline:
    jmp print_newline
.corrupt:
    mov esi, fs_corrupt_data
    jmp console_puts
command_pwd:
    cmp byte [fs_mount_initrd], 1
    je .initrd
    mov ebp, [fs_dir]
    xor ecx, ecx
.chain:
    test ebp, ebp
    jz .print
    mov [fs_path_ids+ecx*4], ebp
    inc ecx
    dec ebp
    shl ebp, 6
    mov ebp, [fs_meta+ebp+512+4]
    jmp .chain
.print:
    mov al, '/'
    call console_putc
    test ecx, ecx
    jz print_newline
.component:
    dec ecx
    mov eax, [fs_path_ids+ecx*4]
    dec eax
    shl eax, 6
    lea esi, [fs_meta+eax+512+16]
    call console_puts
    test ecx, ecx
    jz print_newline
    mov al, '/'
    call console_putc
    jmp .component
.initrd:
    mov esi, initrd_path
    jmp console_puts
command_cd:
    mov edi, slash_name
    call string_equal
    test eax, eax
    jnz .root
    mov edi, initrd_path_name
    call string_equal
    test eax, eax
    jnz .initrd
    mov edi, dot_name
    call string_equal
    test eax, eax
    jnz .done
    mov edi, dotdot_name
    call string_equal
    test eax, eax
    jnz .parent
    cmp dword [fs_dir], 0
    jne .lookup
    mov edi, initrd_name
    call string_equal
    test eax, eax
    jnz .initrd
.lookup:
    cmp byte [fs_mount_initrd], 1
    je fs_not_found
    call fs_find
    test eax, eax
    jz fs_not_found
    cmp dword [eax], FS_TYPE_DIR
    jne fs_not_found
    inc ebx
    mov [fs_dir], ebx
    ret
.parent:
    cmp byte [fs_mount_initrd], 1
    je .root
    mov eax, [fs_dir]
    test eax, eax
    jz .done
    dec eax
    shl eax, 6
    mov eax, [fs_meta+eax+512+4]
    mov [fs_dir], eax
.done:
    ret
.root:
    mov dword [fs_dir], 0
    mov byte [fs_mount_initrd], 0
    ret
.initrd:
    mov dword [fs_dir], 0
    mov byte [fs_mount_initrd], 1
    ret
command_mkdir:
    mov edx, FS_TYPE_DIR
    jmp fs_create
command_touch:
    mov edx, FS_TYPE_FILE
fs_create:
    call fs_write_allowed
    jc .done
    call fs_valid_name
    jc .usage
    cmp dword [fs_dir], 0
    jne .find
    mov edi, initrd_name
    call string_equal
    test eax, eax
    jnz .exists
.find:
    call fs_find
    test eax, eax
    jnz .exists
    mov edi, fs_meta+512
    mov ecx, FS_ENTRIES
.slot:
    cmp dword [edi], 0
    je .create
    add edi, FS_ENTRY_SIZE
    loop .slot
    mov esi, fs_full
    jmp console_puts
.create:
    call fs_begin
    mov ebp, edi
    xor eax, eax
    mov ecx, FS_ENTRY_SIZE/4
    rep stosd
    mov [ebp], edx
    mov eax, [fs_dir]
    mov [ebp+4], eax
    lea edi, [ebp+16]
    call string_copy
    call fs_commit
    jc fs_io_failed
    mov esi, fs_created
    jmp console_puts
.exists:
    mov esi, fs_exists
    jmp console_puts
.usage:
    mov esi, fs_name_usage
    jmp console_puts
.done:
    ret
command_write:
    call fs_write_allowed
    jc .done
    mov edi, esi
.filename:
    mov al, [edi]
    test al, al
    jz .text
    cmp al, ' '
    je .split
    inc edi
    jmp .filename
.split:
    mov byte [edi], 0
    inc edi
.text:
    mov ebp, edi
    call fs_find
    test eax, eax
    jz fs_not_found
    cmp dword [eax], FS_TYPE_FILE
    jne fs_not_found
    mov [fs_write_entry], eax
    mov edx, [eax+12]
    xor edx, 1
    mov [fs_write_bank], edx
    shl ebx, 4
    shl edx, 3
    lea eax, [ebx+edx+FS_DATA_LBA]
    mov [fs_write_lba], eax
    mov esi, ebp
    call string_length
    cmp eax, LINE_CAPACITY-1
    ja .usage
    mov [fs_write_size], eax
    mov edi, fs_data
    xor eax, eax
    mov ecx, FS_FILE_SIZE/4
    rep stosd
    mov edi, fs_data
    call string_copy
    mov eax, [fs_write_lba]
    mov ecx, 8
.sector:
    call ata_write
    jc fs_io_failed
    inc eax
    add edi, 512
    loop .sector
    call ata_flush
    jc fs_io_failed
    call fs_begin
    mov ebp, [fs_write_entry]
    mov eax, [fs_write_size]
    mov [ebp+8], eax
    mov eax, [fs_write_bank]
    mov [ebp+12], eax
    call fs_data_checksum
    mov [ebp+48], eax
    call fs_commit
    jc fs_io_failed
    mov esi, fs_written
    jmp console_puts
.usage:
    mov esi, fs_write_usage
    jmp console_puts
.done:
    ret
command_rm:
    call fs_write_allowed
    jc .done
    call fs_find
    test eax, eax
    jz fs_not_found
    mov ebp, eax
    cmp dword [ebp], FS_TYPE_DIR
    jne .remove
    inc ebx
    mov edi, fs_meta+512
    mov ecx, FS_ENTRIES
.children:
    cmp dword [edi], 0
    je .next
    cmp [edi+4], ebx
    je .not_empty
.next:
    add edi, FS_ENTRY_SIZE
    loop .children
.remove:
    call fs_begin
    mov edi, ebp
    xor eax, eax
    mov ecx, FS_ENTRY_SIZE/4
    rep stosd
    call fs_commit
    jc fs_io_failed
    mov esi, fs_removed
    jmp console_puts
.not_empty:
    mov esi, fs_not_empty
    jmp console_puts
.done:
    ret
fs_io_failed:
    mov esi, fs_io_error
    jmp console_puts
fs_not_found:
    mov esi, fs_missing
    jmp console_puts
align 4
fs_path_ids times 3 dd 0
fs_write_entry dd 0
fs_write_bank dd 0
fs_write_lba dd 0
fs_write_size dd 0
fs_read_checksum dd 0
fs_listing db 'noFS directory',10,0
initrd_listing db 'initrd/  (read-only boot image)',10,0
initrd_name db 'initrd',0
initrd_prefix db '/initrd/',0
initrd_path_name db '/initrd',0
initrd_path db '/initrd',10,0
slash_name db '/',0
dot_name db '.',0
dotdot_name db '..',0
fs_created db 'Created.',10,0
fs_written db 'Written and flushed to disk.',10,0
fs_removed db 'Removed.',10,0
fs_missing db 'File or directory not found.',10,0
fs_exists db 'Name already exists.',10,0
fs_full db 'noFS directory table is full (32 entries).',10,0
fs_not_empty db 'Directory is not empty.',10,0
fs_name_usage db 'Usage: mkdir/touch NAME (1..31 ASCII characters, no spaces or slash)',10,0
fs_write_usage db 'Usage: write FILE [TEXT] (replaces existing file contents)',10,0
fs_corrupt_data db 'noFS file checksum mismatch; contents not displayed.',10,0
