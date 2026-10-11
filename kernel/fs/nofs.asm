%define FS_META_BYTES 2560
%define FS_ENTRIES 32
%define FS_ENTRY_SIZE 64
%define FS_FILE_SIZE 4096
%define FS_DATA_LBA 16
%define FS_TYPE_FILE 1
%define FS_TYPE_DIR 2
nofs_init:
    pushad
    call ata_init
    cmp byte [ata_available], 1
    jne .offline
    xor eax, eax
    mov edi, fs_meta
    call fs_read_metadata
    jc .bank1
    mov esi, fs_meta
    call fs_validate
    jc .bank1
    mov byte [fs_online], 1
.bank1:
    mov eax, 5
    mov edi, fs_candidate
    call fs_read_metadata
    jc .choose
    mov esi, fs_candidate
    call fs_validate
    jc .choose
    cmp byte [fs_online], 0
    je .use_candidate
    mov eax, [fs_candidate+8]
    sub eax, [fs_meta+8]
    jle .choose
.use_candidate:
    mov esi, fs_candidate
    mov edi, fs_meta
    mov ecx, FS_META_BYTES/4
    rep movsd
    mov byte [fs_active_bank], 1
    mov byte [fs_online], 1
.choose:
    cmp byte [fs_online], 1
    jne .offline
    mov esi, fs_ready
    call console_puts
    popad
    ret
.offline:
    mov esi, fs_offline
    call console_puts
    popad
    ret
fs_read_metadata:
    push ecx
    mov ecx, 5
.sector:
    call ata_read
    jc .done
    inc eax
    add edi, 512
    loop .sector
.done:
    pop ecx
    ret
; ESI=metadata buffer. FNV-1a over all metadata, with checksum bytes treated as zero.
fs_checksum:
    push esi
    push ecx
    push edx
    push ebx
    mov ebx, esi
    add ebx, 12
    mov ecx, FS_META_BYTES
    mov eax, 2166136261
.byte:
    xor edx, edx
    cmp esi, ebx
    jb .load
    lea edx, [ebx+4]
    cmp esi, edx
    jb .zero
.load:
    movzx edx, byte [esi]
    jmp .mix
.zero:
    xor edx, edx
.mix:
    xor eax, edx
    imul eax, 16777619
    inc esi
    loop .byte
    pop ebx
    pop edx
    pop ecx
    pop esi
    ret
fs_data_checksum:
    push esi
    push ecx
    push edx
    mov esi, fs_data
    mov ecx, FS_FILE_SIZE
    mov eax, 2166136261
.byte:
    movzx edx, byte [esi]
    xor eax, edx
    imul eax, 16777619
    inc esi
    loop .byte
    pop edx
    pop ecx
    pop esi
    ret
fs_validate:
    pushad
    mov ebp, esi
    cmp dword [ebp], 0x53464f4e
    jne .bad
    cmp dword [ebp+4], 1
    jne .bad
    cmp dword [ebp+16], 1024
    jne .bad
    cmp dword [ebp+20], FS_ENTRIES
    jne .bad
    call fs_checksum
    cmp eax, [ebp+12]
    jne .bad
    lea edi, [ebp+512]
    mov ebx, FS_ENTRIES
.entry:
    mov eax, [edi]
    test eax, eax
    jz .next
    cmp eax, FS_TYPE_DIR
    ja .bad
    cmp dword [edi+8], FS_FILE_SIZE
    ja .bad
    cmp dword [edi+12], 1
    ja .bad
    cmp eax, FS_TYPE_DIR
    jne .name
    cmp dword [edi+8], 0
    jne .bad
.name:
    lea esi, [edi+16]
    call fs_valid_name
    jc .bad
    cmp dword [edi+4], 0
    jne .check_parent
    push edi
    mov edi, initrd_name
    call string_equal
    pop edi
    test eax, eax
    jnz .bad
.check_parent:
    mov edx, [edi+4]
    mov ecx, 3
    cmp dword [edi], FS_TYPE_DIR
    jne .parent
    dec ecx                  ; directories have at most three path components
.parent:
    test edx, edx
    jz .duplicates
    cmp edx, FS_ENTRIES
    ja .bad
    test ecx, ecx
    jz .bad
    dec edx
    shl edx, 6
    lea edx, [ebp+edx+512]
    cmp dword [edx], FS_TYPE_DIR
    jne .bad
    mov edx, [edx+4]
    dec ecx
    jmp .parent
.duplicates:
    push edi
    lea edx, [ebp+512]
.compare:
    cmp edx, edi
    je .unique
    cmp dword [edx], 0
    je .compare_next
    mov eax, [edx+4]
    cmp eax, [edi+4]
    jne .compare_next
    lea esi, [edi+16]
    push edi
    lea edi, [edx+16]
    call string_equal
    pop edi
    test eax, eax
    jnz .duplicate_bad
.compare_next:
    add edx, FS_ENTRY_SIZE
    jmp .compare
.unique:
    pop edi
    jmp .next
.duplicate_bad:
    pop edi
    jmp .bad
.next:
    add edi, FS_ENTRY_SIZE
    dec ebx
    jnz .entry
    popad
    clc
    ret
.bad:
    popad
    stc
    ret
; ESI=name, 1..31 printable ASCII characters, no slash/space/dot path components.
fs_valid_name:
    pushad
    mov edi, esi
    xor ecx, ecx
.byte:
    lodsb
    test al, al
    jz .end
    cmp al, 33
    jb .bad
    cmp al, 127
    jae .bad
    cmp al, '/'
    je .bad
    inc ecx
    cmp ecx, 31
    ja .bad
    jmp .byte
.end:
    test ecx, ecx
    jz .bad
    cmp byte [edi], '.'
    jne .ok
    cmp ecx, 1
    je .bad
    cmp ecx, 2
    jne .ok
    cmp byte [edi+1], '.'
    je .bad
.ok:
    popad
    clc
    ret
.bad:
    popad
    stc
    ret
fs_begin:
    pushad
    mov esi, fs_meta
    mov edi, fs_backup
    mov ecx, FS_META_BYTES/4
    rep movsd
    popad
    ret
fs_commit:
    pushad
    inc dword [fs_meta+8]
    mov esi, fs_meta
    call fs_checksum
    mov [fs_meta+12], eax
    call fs_validate
    jc .rollback
    movzx ebp, byte [fs_active_bank]
    xor ebp, 1
    imul ebp, 5
    lea eax, [ebp+1]
    mov edi, fs_meta+512
    mov ecx, 4
.directory:
    call ata_write
    jc .io_fail
    inc eax
    add edi, 512
    loop .directory
    call ata_flush
    jc .io_fail
    mov eax, ebp             ; header is the commit record, written last
    mov edi, fs_meta
    call ata_write
    jc .io_fail
    call ata_flush
    jc .io_fail
    xor byte [fs_active_bank], 1
    popad
    clc
    ret
.io_fail:
    mov byte [fs_online], 0   ; uncertain media state: refuse further writes until remount
.rollback:
    mov esi, fs_backup
    mov edi, fs_meta
    mov ecx, FS_META_BYTES/4
    rep movsd
    popad
    stc
    ret
; ESI=current-directory name -> EAX=entry or zero, EBX=slot. Others preserved.
fs_find:
    push edi
    push ecx
    push edx
    mov edi, fs_meta+512
    xor ebx, ebx
.entry:
    cmp dword [edi], 0
    je .next
    mov edx, [fs_dir]
    cmp [edi+4], edx
    jne .next
    push edi
    add edi, 16
    call string_equal
    pop edi
    test eax, eax
    jnz .found
.next:
    add edi, FS_ENTRY_SIZE
    inc ebx
    cmp ebx, FS_ENTRIES
    jb .entry
    xor eax, eax
    jmp .done
.found:
    mov eax, edi
.done:
    pop edx
    pop ecx
    pop edi
    ret
fs_write_allowed:
    cmp byte [fs_mount_initrd], 0
    jne .bad
    cmp byte [fs_online], 1
    jne .bad
    clc
    ret
.bad:
    mov esi, fs_write_error
    call console_puts
    stc
    ret
align 4
fs_dir dd 0
fs_online db 0
fs_active_bank db 0
fs_mount_initrd db 0
align 4
fs_meta times FS_META_BYTES db 0
fs_candidate times FS_META_BYTES db 0
fs_backup times FS_META_BYTES db 0
fs_data times FS_FILE_SIZE db 0
fs_ready db '[FS] Persistent noFS mounted on IDE slave',10,0
fs_offline db '[FS] noFS unavailable; disk left untouched, /initrd is readable',10,0
fs_write_error db 'Write unavailable: read-only initrd or invalid/missing data disk.',10,0
fs_io_error db 'noFS I/O/validation failed. If disk is offline, reboot to remount.',10,0
