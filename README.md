# noOS

**No Linux. No Windows. No C. Just Assembly.**

A real BIOS-booted x86 operating system, being built from its own boot sector
to a protected-mode Assembly kernel. The first boot is verified in QEMU: BIOS
disk loading, A20 checking, GDT setup and 32-bit kernel entry all work.

<!-- progress:start -->
## Roadmap — 37.5%

Progress counts verified gates, including the advanced roadmap. Planned work earns no credit.

| Milestone | Verified |
| --- | --- |
| 1. BIOS boot and protected-mode kernel | 5/5 |
| 2. VGA terminal | 5/5 |
| 3. Interrupt-driven PS/2 keyboard | 5/5 |
| 4. Interactive shell | 0/5 |
| 5. Memory management | 0/5 |
| 6. Hardware and diagnostics | 0/5 |
| 7. Advanced kernel | 0/5 |
| 8. Professional delivery | 0/5 |
<!-- progress:end -->

Runtime code will use NASM Assembly only. Make and Python are host build/test
tools. The initial supported platform is QEMU's BIOS `pc` machine, using VGA,
the legacy PIC, PIT and PS/2 keyboard. Physical machines are not yet tested.

## Development

Completed and tested milestones are committed and pushed directly to `main`.
Install NASM, QEMU, GNU Make and Python 3. Run `make`, `make run`, `make debug`,
`make test`, `make clean` and `make size`. `make run` boots the actual disk image;
the interactive shell is the next milestone. `make debug` waits for a GDB
connection at `127.0.0.1:1234`. Follow commits for measured progress.

## License

[MIT](LICENSE).
