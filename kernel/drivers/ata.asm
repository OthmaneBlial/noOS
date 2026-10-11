; Primary IDE slave only. Never write the boot disk (primary master).
%define ATA_DATA 0x1f0
%define ATA_STATUS 0x1f7
ata_init:
    pushad
    mov dx, 0x1f6
    mov al, 0xb0
    out dx, al
    call ata_settle
    mov dx, ATA_STATUS
    in al, dx
    test al, al
    jz .absent
    cmp al, 0xff
    je .absent
    mov al, 0xec
    out dx, al
    call ata_drq
    jc .absent
    mov dx, ATA_DATA
    mov edi, ata_identify
    mov ecx, 256
    rep insw
    ; noOS uses a bounded 1024-sector data volume, independent of boot-drive DL.
    test word [ata_identify+49*2], 1<<9
    jz .absent
    mov eax, [ata_identify+60*2]
    cmp eax, 1024
    jb .absent
    mov byte [ata_available], 1
.absent:
    popad
    ret
ata_settle:
    push eax
    push edx
    mov dx, 0x3f6
    in al, dx
    in al, dx
    in al, dx
    in al, dx
    pop edx
    pop eax
    ret
ata_drq:
    push ecx
    push edx
    mov dx, ATA_STATUS
    mov ecx, 1000000
.poll:
    in al, dx
    test al, 0x80
    jnz .next
    test al, 0x21
    jnz .fail
    test al, 8
    jnz .ok
.next:
    loop .poll
.fail:
    stc
    jmp .done
.ok:
    clc
.done:
    pop edx
    pop ecx
    ret
ata_idle:
    push ecx
    push edx
    mov dx, ATA_STATUS
    mov ecx, 1000000
.poll:
    in al, dx
    test al, 0x80
    jnz .next
    test al, 0x21
    jnz .fail
    test al, 0x40
    jnz .ok
.next:
    loop .poll
.fail:
    stc
    jmp .done
.ok:
    clc
.done:
    pop edx
    pop ecx
    ret
; EAX=LBA (<1024), EDI=512-byte buffer; all registers preserved; CF=I/O failure.
ata_read:
    pushad
    mov ebx, eax
    mov ebp, 0x20
    jmp ata_transfer
ata_write:
    pushad
    mov ebx, eax
    mov ebp, 0x30
ata_transfer:
    cmp byte [ata_available], 1
    jne .fail
    cmp ebx, 1024
    jae .fail
    mov dx, 0x1f6
    mov al, 0xf0              ; LBA28, primary slave; all used LBAs fit the low 10 bits
    out dx, al
    call ata_settle
    call ata_idle
    jc .fail
    mov dx, 0x1f2
    mov al, 1
    out dx, al
    inc dx
    mov eax, ebx
    out dx, al
    inc dx
    shr eax, 8
    out dx, al
    inc dx
    xor al, al
    out dx, al
    mov dx, ATA_STATUS
    mov eax, ebp
    out dx, al
    call ata_drq
    jc .fail
    mov dx, ATA_DATA
    mov ecx, 256
    cmp ebp, 0x20
    je .read
    mov esi, edi
    rep outsw
    jmp .complete
.read:
    rep insw
.complete:
    call ata_settle
    call ata_idle
    jc .fail
    popad
    clc
    ret
.fail:
    popad
    stc
    ret
ata_flush:
    pushad
    call ata_idle
    jc .fail
    mov dx, ATA_STATUS
    mov al, 0xe7
    out dx, al
    call ata_settle
    call ata_idle
    jc .fail
    popad
    clc
    ret
.fail:
    popad
    stc
    ret
ata_available db 0
align 4
ata_identify times 512 db 0
