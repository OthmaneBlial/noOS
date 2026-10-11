# Changelog

## 0.1.0 — foundation, unreleased

- Own BIOS sector and second-stage loader, A20 verification, E820 and 32-bit entry.
- Modular all-Assembly kernel with VGA/COM1, IDT/PIC, PS/2 keyboard and PIT.
- Editing shell, eight-entry history and fourteen initial commands.
- E820 frame allocator, coalescing heap and supervisor paging with null guard.
- Real fault diagnostics, QEMU hardware tests and usable GDB debugging.
- Reproducible build CI, authentic screenshot and computed roadmap.
- Validated read-only initrd with real ls/cat/pwd/cd and corruption tests.
- Public showcase and field manual at https://othmaneblial.github.io/noOS/.
- Persistent IDE PIO noFS, directories and bounded file writes, dual checked
  metadata/data banks, raw-sector/persistence/corruption tests and clean-safe data.
- Cooperative ring-0 tasks with saved interrupt contexts, separate stacks,
  round-robin switching, controlled completion and ps status.

Foundation measurement: stage1 512 bytes, stage2 641 bytes, kernel 27,704 bytes,
raw sector-padded image 32,768 bytes. Run `make size` for current source.
No release tag is published. Advanced features are tracked separately.
