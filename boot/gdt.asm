align 8
gdt:
    dq 0
    dq 0x00cf9a000000ffff       ; selector 0x08: flat 32-bit code
    dq 0x00cf92000000ffff       ; selector 0x10: flat 32-bit data
gdt_end:
gdtr:
    dw gdt_end-gdt-1
    dd gdt
