# noOS

**No Linux. No Windows. No C. Just Assembly.**

A real BIOS-booted x86 operating system, being built from its own boot sector
to a protected-mode Assembly kernel. This repository is at the project setup
milestone: bootable code has not yet been implemented or verified.

## Roadmap — 0%

Progress counts verified acceptance gates, never planned or untested features.

| Milestone | Status |
| --- | --- |
| 1. BIOS boot and protected-mode kernel | Planned |
| 2. VGA terminal | Planned |
| 3. Interrupt-driven PS/2 keyboard | Planned |
| 4. Interactive shell and history | Planned |
| 5. E820 memory, frames, heap and paging | Planned |
| 6. PIT, CPU information and diagnostics | Planned |
| 7. Filesystem, tasks and user mode | Planned |
| 8. Automated tests, documentation and release image | Planned |

Runtime code will use NASM Assembly only. Make and Python are host build/test
tools. The initial supported platform is QEMU's BIOS `pc` machine, using VGA,
the legacy PIC, PIT and PS/2 keyboard. Physical machines are not yet tested.

## Development

Completed and tested milestones are committed and pushed directly to `main`.
The first delivery will provide `make`, `make run`, `make debug`, `make test`,
`make clean` and `make size`. Follow commits for measured progress.

## License

[MIT](LICENSE).
