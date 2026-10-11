bits 32
%define USER_BASE 0x40000000
%define USER_DATA (USER_BASE+0x4000)
org USER_BASE-4096
elf_header:
    db 0x7f,'ELF',1,1,1,0
    times 8 db 0
    dw 2,3
    dd 1,_start,52,0,0
    dw 52,32,PH_COUNT,0,0,0
    dd 1,4096,USER_BASE,USER_BASE
    dd text_end-_start,text_end-_start,5,4096
%if PH_COUNT == 2
    dd 1,8192,USER_DATA,USER_DATA,4,8192,6,4096
%endif
    times 4096-($-$$) db 0
