command_help:
    mov ebp, command_table
.entry:
    cmp dword [ebp], 0
    je .done
    mov esi, help_indent
    call console_puts
    mov esi, [ebp+12]
    call console_puts
    call print_newline
    add ebp, 16
    jmp .entry
.done:
    ret
command_clear:
    jmp vga_clear
command_version:
    mov esi, version_text
    jmp console_puts
command_about:
    mov esi, about_text
    jmp console_puts
command_echo:
    call console_puts
    jmp print_newline
command_history:
    xor ebp, ebp
.entry:
    cmp ebp, [history_count]
    jae .done
    mov eax, ebp
    inc eax
    call print_u32
    mov esi, help_indent
    call console_puts
    mov eax, ebp
    shl eax, 7
    lea esi, [history_lines+eax]
    call console_puts
    call print_newline
    inc ebp
    jmp .entry
.done:
    ret
command_color:
    movzx eax, byte [esi]
    call hex_digit
    jc .usage
    mov cl, al
    inc esi
    movzx eax, byte [esi]
    call hex_digit
    jc .usage
    shl al, 4
    or cl, al
    inc esi
    cmp byte [esi], 0
    jne .usage
    mov [vga_color], cl
    mov esi, color_text
    jmp console_puts
.usage:
    mov esi, color_usage
    jmp console_puts
hex_digit:
    cmp al, '0'
    jb .bad
    cmp al, '9'
    jbe .decimal
    or al, 32
    cmp al, 'a'
    jb .bad
    cmp al, 'f'
    ja .bad
    sub al, 'a'-10
    clc
    ret
.decimal:
    sub al, '0'
    clc
    ret
.bad:
    stc
    ret
command_panic:
    cmp byte [esi], 0
    je .opcode
    mov edi, panic_page
    call string_equal
    test eax, eax
    jnz .page
    mov edi, panic_gp
    call string_equal
    test eax, eax
    jnz .gp
    mov edi, panic_divide
    call string_equal
    test eax, eax
    jnz .divide
    mov esi, panic_usage
    jmp console_puts
.page:
    mov eax, [0]
    ret
.gp:
    mov ax, 0x30              ; outside the runtime kernel/user/TSS GDT
    mov ds, ax
    ret
.divide:
    xor eax, eax
    xor edx, edx
    div eax
    ret
.opcode:
    ud2                       ; real invalid-opcode exception, not a printed mock panic
command_halt:
    mov esi, halt_text
    call console_puts
    cli
.stop:
    hlt
    jmp .stop
command_reboot:
    mov esi, reboot_text
    call console_puts
    cli
    mov ecx, 65536
.wait:
    in al, 0x64
    test al, 2
    jz .reset
    loop .wait
    jmp .fallback
.reset:
    mov al, 0xfe
    out 0x64, al
    mov ecx, 65536
.settle:
    loop .settle
.fallback:
    lidt [empty_idtr]          ; triple-fault reset if PS/2 reset is unavailable
    int 3
command_mem:
    mov esi, mem_e820
    call console_puts
    mov eax, [e820_usable]
    mov edx, [e820_usable+4]
    shrd eax, edx, 10
    shr edx, 10
    call print_u64
    call print_newline
    mov esi, mem_managed
    call console_puts
    mov eax, [pmm_total]
    call print_u32
    call print_newline
    mov esi, mem_reserved
    call console_puts
    mov eax, FRAME_LIMIT
    sub eax, [pmm_total]
    call print_u32
    call print_newline
    mov esi, mem_used
    call console_puts
    mov eax, [pmm_used]
    call print_u32
    call print_newline
    mov esi, mem_free
    call console_puts
    mov eax, [pmm_free_count]
    call print_u32
    call print_newline
    mov esi, mem_heap
    call console_puts
    mov eax, [heap_used]
    call print_u32
    call print_newline
    mov esi, mem_limit
    jmp console_puts
command_cpu:
    cmp byte [cpu_available], 0
    je .unavailable
    mov esi, cpu_vendor_label
    call console_puts
    mov esi, cpu_vendor
    call console_puts
    call print_newline
    mov esi, cpu_family_label
    call console_puts
    mov eax, [cpu_family]
    call print_u32
    mov esi, cpu_model_label
    call console_puts
    mov eax, [cpu_model]
    call print_u32
    mov esi, cpu_stepping_label
    call console_puts
    mov eax, [cpu_stepping]
    call print_u32
    call print_newline
    mov esi, cpu_features_label
    call console_puts
    mov eax, [cpu_features]
    call print_hex
    jmp print_newline
.unavailable:
    mov esi, cpu_unavailable
    jmp console_puts
command_uptime:
    mov esi, ticks_label
    call console_puts
    pushfd
    cli
    mov eax, [timer_ticks]
    mov edx, [timer_ticks+4]
    popfd
    call print_u64
    call print_newline
    mov esi, seconds_label
    call console_puts
    pushfd
    cli
    mov eax, [timer_seconds]
    mov edx, [timer_seconds+4]
    popfd
    call print_u64
    call print_newline
    mov esi, pit_info
    jmp console_puts
command_sysinfo:
    call command_version
    mov esi, sys_mode
    call console_puts
    call command_cpu
    call command_mem
    call command_uptime
    mov esi, irq_label
    call console_puts
    mov eax, [keyboard_irqs]
    call print_u32
    mov esi, dropped_label
    call console_puts
    mov eax, [keyboard_dropped]
    call print_u32
    jmp print_newline
command_table:
    dd help_name, command_help, 0, help_name
    dd clear_name, command_clear, 0, clear_name
    dd version_name, command_version, 0, version_name
    dd about_name, command_about, 0, about_name
    dd echo_name, command_echo, 1, echo_usage
    dd history_name, command_history, 0, history_name
    dd color_name, command_color, 1, color_help
    dd reboot_name, command_reboot, 0, reboot_name
    dd halt_name, command_halt, 0, halt_name
    dd panic_name, command_panic, 1, panic_help
    dd mem_name, command_mem, 0, mem_name
    dd cpu_name, command_cpu, 0, cpu_name
    dd uptime_name, command_uptime, 0, uptime_name
    dd sysinfo_name, command_sysinfo, 0, sysinfo_name
    dd ls_name, command_ls, 0, ls_name
    dd cat_name, command_cat, 1, cat_help
    dd pwd_name, command_pwd, 0, pwd_name
    dd cd_name, command_cd, 1, cd_help
    dd mkdir_name, command_mkdir, 1, mkdir_help
    dd touch_name, command_touch, 1, touch_help
    dd write_name, command_write, 1, write_help
    dd rm_name, command_rm, 1, rm_help
    dd ps_name, command_ps, 0, ps_name
    dd tasks_name, command_tasks, 1, tasks_help
    dd user_name, command_user, 1, user_help
    dd run_name, command_run, 1, run_help
    dd 0,0,0,0
help_name db 'help',0
clear_name db 'clear',0
version_name db 'version',0
about_name db 'about',0
echo_name db 'echo',0
history_name db 'history',0
color_name db 'color',0
reboot_name db 'reboot',0
halt_name db 'halt',0
panic_name db 'panic',0
panic_page db 'page',0
panic_gp db 'gp',0
panic_divide db 'divide',0
panic_help db 'panic [page|gp|divide]',0
panic_usage db 'Usage: panic [page|gp|divide]',10,0
mem_name db 'mem',0
cpu_name db 'cpu',0
uptime_name db 'uptime',0
sysinfo_name db 'sysinfo',0
ls_name db 'ls',0
cat_name db 'cat',0
pwd_name db 'pwd',0
cd_name db 'cd',0
cat_help db 'cat FILE',0
cd_help db 'cd DIR (/, /initrd, .. or child name)',0
mkdir_name db 'mkdir',0
touch_name db 'touch',0
write_name db 'write',0
rm_name db 'rm',0
ps_name db 'ps',0
tasks_name db 'tasks',0
tasks_help db 'tasks on|off (PIT-preempted workers)',0
user_name db 'user',0
user_help db 'user demo|fault|write|stack|io|spin (ring 3)',0
run_name db 'run',0
run_help db 'run NAME.elf (static ELF32 in /initrd)',0
mkdir_help db 'mkdir NAME',0
touch_help db 'touch NAME',0
write_help db 'write FILE [TEXT] (replace)',0
rm_help db 'rm NAME (file or empty directory)',0
cpu_vendor_label db 'CPU vendor: ',0
cpu_family_label db 'Family: ',0
cpu_model_label db ' Model: ',0
cpu_stepping_label db ' Stepping: ',0
cpu_features_label db 'CPUID leaf 1 EDX: ',0
cpu_unavailable db 'CPUID is unavailable on this CPU.',10,0
ticks_label db 'PIT ticks: ',0
seconds_label db 'Uptime seconds: ',0
pit_info db 'PIT clock: 1193182 Hz; divisor: 11932; nominal rate: ~100 Hz',10,0
sys_mode db 'Mode: 32-bit protected; paging: supervisor identity map',10,0
irq_label db 'Keyboard IRQs: ',0
dropped_label db ' Dropped events: ',0
mem_e820 db 'E820 usable KiB: ',0
mem_managed db 'Managed usable frames: ',0
mem_reserved db 'Reserved/unavailable frames in managed window: ',0
mem_used db 'Allocated frames: ',0
mem_free db 'Free frames: ',0
mem_heap db 'Heap used bytes: ',0
mem_limit db 'Page size: 4096 bytes; managed window: 128 MiB; heap arena: 64 KiB',10,0
echo_usage db 'echo [text]',0
color_help db 'color FB (hex foreground/background)',0
color_usage db 'Usage: color FB (two hex digits, foreground then background)',10,0
help_indent db '  ',0
color_text db 'Terminal color updated.',10,0
version_text db 'noOS 0.1.0 / x86 / NASM Assembly',10,0
about_text db 'No Linux. No Windows. No C. Just Assembly.',10
    db 'A BIOS-booted operating system with its own protected-mode kernel.',10,0
halt_text db 'System halted.',10,0
reboot_text db 'Rebooting noOS...',10,0
empty_idtr dw 0
    dd 0
