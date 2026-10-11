# Architecture and memory layout

noOS runs directly on emulated x86 hardware. Runtime code is NASM Assembly;
Make/Python/GDB/QMP are host tools. BIOS is used only before protected-mode
entry. No GRUB or high-level runtime is linked into the image.

## Boot sequence

1. BIOS loads LBA 0 at `0x7c00`. Stage 1 normalizes CS, initializes DS/ES/SS/SP,
   preserves DL, prints progress, checks EDD and loads eight sectors at `0x8000`.
2. Stage 2 loads the sector-rounded kernel from LBA 9 at `0x10000`, one sector
   per INT 13h AH=42 call. ES increments by 32 paragraphs, so no read crosses a
   64 KiB boundary. The builder rejects kernels that extend into the heap.
3. Port 92h enables A20, and an alias test checks it while restoring both bytes.
   BIOS INT 15h AX=2401 is a fallback. Failure halts with diagnostics.
4. E820 is collected into at most 128 validated 24-byte records. A signature,
   length checks, disabled-attribute filtering, zero-length filtering and a
   bounded continuation loop prevent silent truncation.
5. A null/code/data GDT sets up flat selectors 08h/10h. CLI precedes CR0.PE;
   a far jump reloads CS. All data segments and ESP are initialized, then a far
   jump transfers to `kernel_entry` at `0x10000`.
6. The kernel initializes serial/VGA, tests VGA, installs IDT/PIC, initializes
   and tests memory, validates paging, prepares keyboard/CPU/PIT, unmasks IRQ0/1,
   enables interrupts, tests timed delays and starts the shell.

## Physical layout

| Range / address | Owner |
| --- | --- |
| `0x0000–0x0fff` | Null page unmapped after paging |
| `0x4ff0` | E820 record count (word) |
| `0x4ff4` | E820 SMAP signature (dword) |
| `0x5000–0x5bff` | Maximum E820 map buffer |
| `0x7c00–0x7dff` | Stage 1; real-mode stack grows below 7c00h |
| `0x8000–0x8fff` | Reserved stage 2 load window |
| `0x10000–kernel end` | Flat kernel code/static data; maximum end 70000h |
| `0x70000–0x7ffff` | 64 KiB heap arena |
| `0x88000–0x8ffff` | Reserved kernel stack space; ESP begins at 90000h |
| `0xb8000–0xb8fff` | VGA text hardware; PCD/PWT identity mapping |
| `0x00000–0xfffff` | Entire low 1 MiB reserved from frame allocation |
| E820 usable pages above `0x100000` | Frame pool, clipped below 128 MiB |
| 33 allocated/pinned usable frames | One page directory and 32 page tables |

## Modules and ABI

`kernel/entry.asm` includes modules into one deterministic flat binary. NASM's
listing in `build/kernel.lst` records instruction offsets. Labels are absolute
after `org 0x10000`; a listing byte offset must add 10000h for a guest address.

| Module | Contract |
| --- | --- |
| `drivers/serial.asm` | COM1 115200/8N1; AL=character or ESI=NUL string; preserves registers |
| `drivers/vga.asm` | 80x25, 80-column rows; output preserves registers; console mirrors to COM1 |
| `lib/conversion.asm` | EAX unsigned32 or EDX:EAX unsigned64; output preserves registers |
| `lib/string.asm` | ESI/EDI strings; compare/length return EAX; copies require caller-proven capacity |
| `interrupts/idt.asm`, `isr.asm` | 256 ring-0 interrupt gates; CPU error code normalized beneath vector |
| `interrupts/pic.asm`, `irq.asm` | PIC bases 20h/28h; EOI and IRQ7/15 spurious handling |
| `drivers/keyboard.asm` | IRQ1 produces a 128-slot SPSC ring (127 usable events); consumer returns EAX/0 |
| `drivers/timer.asm` | IRQ0 maintains 64-bit ticks/seconds; ECX=ticks for interrupt-aware delay |
| `drivers/cpu.asm` | EFLAGS.ID probe precedes CPUID; vendor/family/model/stepping retained |
| `memory/physical.asm` | EAX=frame address; allocator returns EAX/CF, free returns CF; other registers preserved |
| `memory/heap.asm` | EAX=size/pointer; 16-byte alignment; CF indicates allocation/free failure |
| `memory/paging.asm` | Allocates/pins tables, validates required identity pages, enables PG/WP |
| `shell/` | Main-context command execution only; table entries contain name/function/argument rule/help |
| `fs/initrd.asm` | Validated NIRD header/40-byte entries; file reads bounded by real embedded size |

IRQ entry uses PUSHAD, clears DF, invokes a handler, restores registers and
IRETD. Handlers do not print, allocate or invoke the shell. Keyboard consumption
masks interrupts and restores original flags; idle uses CLI/check followed by
STI/HLT so a pending key cannot be lost before sleep. Memory managers are
main-context APIs, not reentrant IRQ APIs. Output is main-context only;
panic runs with interrupts disabled.

## Memory rules

Frames are eligible only when their complete 4 KiB page is usable in E820.
Any overlapping non-usable record reserves all partially covered pages,
regardless of record order. Separate eligibility, busy and pin bitmaps prevent
reserved, invalid, double and paging-structure frees. Higher detected memory is
reported but never allocated above the documented 128 MiB ceiling.

The heap uses first fit with 16-byte headers, splits when another header and
payload fit, and coalesces adjacent free blocks. Free searches actual block
headers before accepting a pointer, rejecting interior and arbitrary pointers.
It is a fixed reserved arena, not a growing virtual allocator.

Paging is supervisor-only identity mapping of the managed 128 MiB window,
excluding address zero. Page tables are live allocated frames. PG and WP are
enabled only after checking kernel, stack, map, heap and VGA pages. Kernel code
and data currently share writable supervisor mappings; this is not userspace
isolation. Large pages, PAE, SMP, APIC, UEFI and long mode are not implemented.

## References

The read-only initrd is a genuine embedded filesystem, packed from `initrd/`
into `build/initrd.bin` by a host tool and interpreted entirely in Assembly.
Its header records magic/version/count/total length. Each entry is a 32-byte
terminated ASCII name plus offset/length. Metadata is checked for bounds,
overflow, overlap, duplicate names and unsupported paths before use. `ls`,
`cat`, `pwd` and `cd /` operate on this flat root. This is read-only image
content, not writable disk persistence.

## Persistent noFS

The primary IDE slave is a separate 1024-sector volume. ATA IDENTIFY requires
LBA support and adequate size. Bounded PIO reads/writes use ports 1f0h–1f7h,
slave selection and a 400 ns alternate-status delay. No operation addresses
the boot master. `data/noos-data.img` survives clean builds.

Two metadata banks occupy LBAs 0–4 and 5–9. Each has a versioned header,
generation, full-metadata FNV-1a checksum and 32 fixed 64-byte entries. Entries
validate type, parent chains, name/duplicates, mount collisions, size and data
bank. Directories are bounded to three levels. Bad metadata leaves media
untouched; one valid bank can mount even when the other is corrupt.

File slot N uses LBAs `16 + N*16 + bank*8`, with two 4 KiB data banks. Write
fills/flushed the inactive data bank, then writes/flushed inactive metadata
entries, and finally writes/flushed its header as a commit record. Each file
has a data checksum, verified before printing. Failure before metadata commit
leaves the active reference intact; uncertain metadata I/O disables writes
until reboot/remount. This is a small experimental filesystem, not a universal
crash-consistency guarantee or secure erase implementation.

`mkdir`, `touch`, `write` and `rm` act in the current noFS directory. Names
contain 1–31 printable ASCII characters without whitespace/slash. `write`
replaces an existing file with remaining line text. `rm` refuses nonempty
directories. `/initrd` remains read-only and does not consume a noFS slot.

## Cooperative and preemptive tasks

Three ring-0 task control blocks track saved interrupt-frame ESP, ready state,
work, switches, IRQ ticks and name. The shell uses its original kernel stack;
each worker has a distinct reserved 4 KiB kernel stack. Software INT 30h enters
the same normalized context layout as hardware interrupts. With IF masked,
round robin stores the current ESP and restores a ready task's saved frame
through IRETD. Worker termination clears its ready bit before yielding.

The boot test runs two independent workers to completion and checks counters,
register preservation and return to the shell. `ps` reports the real blocks.
This is kernel threading; there is no user privilege or address-space isolation.
After cooperative switching passes, a second boot check runs non-yielding
workers with a two-tick PIT quantum. IRQ0 updates time and acknowledges the PIC
before scheduling at the saved interrupt-frame boundary. `tasks on` starts the
workers; `tasks off` stops them without stopping the shell. Tests verify both
work counters, switches and IRQ ticks advance while keyboard commands execute.

- [Intel system programming manuals](https://www.intel.com/content/www/us/en/developer/articles/technical/intel-sdm.html)
- [QEMU system invocation](https://www.qemu.org/docs/master/system/qemu-manpage.html)
- [QMP reference](https://www.qemu.org/docs/master/interop/qemu-qmp-ref.html)

The separate future x86-64 path needs PAE-compatible paging, a long-mode GDT,
64-bit entry/interrupt frames and a new ABI; keep the tested 32-bit target intact.
