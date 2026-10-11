# Verified roadmap

The initial stable acceptance target is an actual QEMU-booted 32-bit Assembly
OS, not a host process. Changes reach boot code, kernel modules, image builder,
headless emulated-hardware tests, docs, CI and the public showcase.

The roadmap follows this order. Each complete milestone must build and pass
its checks before its commit is pushed to main.

1. First boot: valid boot sector, preserved drive, second-stage loading, disk
   errors, A20, GDT, protected mode, kernel entry and QEMU verification.
2. Screen: 80x25 VGA, colors, wrapping, scrolling, hardware cursor, backspace,
   newlines/tabs, welcome screen and authentic screenshot.
3. Keyboard: IDT/exceptions, PIC, IRQ1, US scancodes, Shift/Caps, release
   events, Enter/Backspace/Tab/Escape/arrows and bounded interrupt-safe queue.
4. Shell: prompt, parsing, command dispatch, invalid/empty input, line editing,
   history and real implemented commands with usage checks.
5. Memory: preserved E820, reserved regions, 4 KiB frame allocation/release,
   exhaustion/invalid/double-free checks, heap, real statistics and paging.
6. Hardware: PIT IRQ0, ticks, delays, uptime, CPU detection, serial diagnostics
   and controlled exception panic.
7. Advanced kernel: read-only initrd then persistent writable filesystem;
   cooperative then preemptive tasks; ring 3/TSS/syscalls/address spaces; a
   validated ELF32 subset; a separate future x86-64 path.
8. Professional delivery: automated boot/hardware/failure tests, GitHub Actions,
   usable GDB session, documented architecture/memory/ABI, reproducible image,
   measured binary sizes and performance, contributing guide and public site.

No hardware compatibility, user isolation, persistence or performance is
claimed before direct evidence exists. No release is published before its
exact commit passes CI. Roadmap percentages will count explicit verified gates.
