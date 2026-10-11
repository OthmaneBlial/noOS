# Verification evidence

Run `make test` from a clean checkout. Tests boot the disk image in system-mode
QEMU; they never execute Assembly as a host program. Python drives QMP, reads
serial/debug logs, inspects emulated physical memory and invokes GNU GDB.

## Initial stable acceptance

| Requirement | Evidence |
| --- | --- |
| `make` produces BIOS disk | Image builder validates sector/signature/layout; QEMU consumes that image |
| `make run` boots | Actual Make target run locally through prompt; harness uses same configuration |
| Bootloader loads real kernel | Boot test checks messages and rejects stage2/kernel truncation |
| 32-bit protected mode | GDB hardware entry breakpoint checks CS, CR0 and ESP |
| Authentic VGA welcome | VGA test reads B8000h characters/attributes and captures screendump |
| Emulated PS/2 input | Keyboard test sends make/break/modifier keys through IRQ1 |
| Multiple real commands | Shell/hardware tests exercise all 14 initial commands |
| Invalid commands survive | Unknown, argument, empty and overflow cases followed by valid commands |
| Hardware interrupts | IRQ1 keys, IRQ0 ticks, keyboard IRQ counter and NMI |
| Actual timer ticks | Hardware test observes advancing PIT ticks and validates tick-aware delays |
| Detected usable RAM | Memory test compares raw E820 independently at 16/64/128/256 MiB |
| Frames allocate/release | Assembly self-test covers fragmentation, exhaustion and invalid free |
| Real system information | sysinfo/mem/cpu/uptime reflect actual tracked state |
| Reboot/halt | New kernel boot after reset; HLT=1 and no keyboard output after halt |
| Usable QEMU/GDB | Actual GNU GDB breakpoint, register checks and instruction inspection |
| Accurate README | Roadmap sync gate and explicit limits; reviewed against modules |
| Automated subsystems | Ten focused hardware suites, assembly self-checks and CI |
| Entire runtime Assembly | All boot/kernel sources NASM; no high-level runtime linked |

## Additional checks

VGA self-check tests tabs, CR/LF, backspace, scrolling, attributes, cursor
visibility and CRTC ports. The keyboard ring self-check fills 127 events,
rejects overflow and checks FIFO order. Heap tests check alignment,
split/reuse/coalesce, full-arena exhaustion and invalid frees.

Paging tests inspect CR0/CR3, all 32 tables and 32,768 mappings; validate
supervisor permissions, the null guard, uncached VGA and zero unused PDEs.
Fault tests check #UD, #PF/CR2, #GP error code, #DE and NMI.

Initrd tests read actual files and boot six corrupt image variants: magic,
count, offset, size, missing name terminator and duplicate name. All are
rejected with a diagnostic before file access.

CI compares two clean images byte for byte. Binary sizes are separate from
padded disk size. `make benchmark` measures host-observed QEMU samples.

## Limits of evidence

Tests cover QEMU BIOS pc. Physical PCs, UEFI, alternative PS/2 controllers,
IRQ storms, SMP, APIC and arbitrary firmware maps are not verified. The host
recomputes the expected frame map from QEMU E820; that does not prove support
for every buggy BIOS. Exception output assumes a usable kernel stack and
UART/VGA mapping; there is no alternate double-fault stack yet. Time accounting
uses the PIT nominal oscillator.

Persistent storage tests inspect actual raw IDE sectors, close QEMU and boot a
new process against the same volume. They verify replacement, directories,
deletion, full-table exhaustion/reuse, read-only mounts, bad data checksums,
one-bank recovery and six structurally invalid volumes with valid checksums.
Invalid volumes remain byte-identical after attempted writes. Power-loss timing
at every write is not yet exhaustively tested. Userspace isolation remains pending.

Task tests first check cooperative register restoration and worker completion,
then enable two non-yielding workers. Both real work/switch/IRQ-tick counters
advance across `ps` calls while PS/2 commands remain responsive. Stopping workers
returns both to DONE. The quantum is two actual PIT interrupts.
