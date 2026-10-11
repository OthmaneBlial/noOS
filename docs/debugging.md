# Debugging the actual CPU

Run `make debug`. QEMU starts paused, with a GDB stub bound to localhost:1234.
In a second terminal use `gdb` on Linux or `x86_64-elf-gdb` on macOS:

```gdb
set architecture i386
target remote 127.0.0.1:1234
hbreak *0x10000
continue
info registers
x/16i $eip
x/32hx 0xb8000
```

The hardware breakpoint fires at the first real kernel instruction. Before it
executes, CS is 08h, DS/ES/SS are 10h, CR0.PE is set and ESP is 90000h. The
automated debugger test checks those values using GNU GDB itself.

Use `delete breakpoints` and `continue` to enter the shell. Interrupt GDB with
Ctrl-C to inspect the CPU; use `info registers cr0 cr2 cr3` after paging starts.
All mapped pages are supervisor identity mappings, so physical/virtual addresses
match except that page zero is unmapped. `monitor info registers` also shows
the QEMU CPU's halt state. Kernel shutdown leaves HLT=1 with IF cleared.

This build is flat NASM output and has no DWARF source-level symbols. Read
`build/kernel.lst` for instruction offsets, add 10000h, and set an address
breakpoint. `ndisasm -b 32 -o 0x10000 build/kernel.bin` is useful for instruction
inspection; boot sectors need `-b 16 -o 0x7c00`. Do not disassemble static data
as if it were executable code. GNU objdump/readelf are useful for a future ELF
target, but this raw BIOS image does not contain ELF headers.

Stage 1/2 emit boot diagnostics to QEMU port E9h and BIOS teletype. Add
`-debugcon file:build/boot.log` to QEMU for loader logs. The kernel writes COM1;
`make run` and `make debug` show it on the host terminal. Serial input is not the
shell keyboard. Tests send QMP key events through the emulated PS/2 device.

`panic`, `panic page`, `panic gp` and `panic divide` trigger actual CPU faults.
Panic prints vector, CPU error code, EIP and CR2 for a page fault, then halts.
NMI is also tested. Reset after a panic. `make test` includes the debugger and
fault workflow.
