NASM ?= nasm
QEMU ?= qemu-system-i386
PYTHON ?= python3
QEMU_FLAGS = -machine pc -m 128M -drive format=raw,file=build/noos.img -serial stdio -no-shutdown

.PHONY: all run debug test clean size
all: build/noos.img

build:
	mkdir -p build

build/kernel.bin: $(shell find kernel -name '*.asm') | build
	$(NASM) -f bin -I ./ -l build/kernel.lst kernel/entry.asm -o $@

build/layout.inc: build/kernel.bin tools/image.py
	$(PYTHON) tools/image.py layout

build/stage1.bin: boot/stage1.asm | build
	$(NASM) -f bin $< -o $@

build/stage2.bin: boot/stage2.asm boot/gdt.asm build/layout.inc
	$(NASM) -f bin -I ./ $< -o $@

build/noos.img: build/stage1.bin build/stage2.bin build/kernel.bin tools/image.py
	$(PYTHON) tools/image.py build

run: all
	$(QEMU) $(QEMU_FLAGS)

debug: all
	$(QEMU) $(QEMU_FLAGS) -S -gdb tcp:127.0.0.1:1234

test: all
	$(PYTHON) tests/test_boot.py
	$(PYTHON) tests/test_vga.py
	$(PYTHON) tests/test_keyboard.py
	$(PYTHON) tests/test_shell.py

size: all
	$(PYTHON) tools/image.py size

clean:
	rm -rf build
