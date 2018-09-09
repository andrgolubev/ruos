BUILD_DIR = .build

arch ?= x86_64
kernel := $(BUILD_DIR)/kernel-$(arch).bin
iso := $(BUILD_DIR)/ruos-$(arch).iso
target ?= $(arch)-ruos
rust_os := target/$(target)/debug/libruos.a

linker_script := src/arch/$(arch)/linker.ld
grub_cfg := src/arch/$(arch)/grub.cfg
asm_src_files := $(wildcard src/arch/$(arch)/*.asm)
asm_obj_files := $(patsubst src/arch/$(arch)/%.asm, \
	$(BUILD_DIR)/arch/$(arch)/%.o, $(asm_src_files))

.PHONY: all clean run iso kernel

all: $(kernel)

clean:
	@rm -rf $(BUILD_DIR)

run: $(iso)
	@qemu-system-x86_64 -cdrom $(iso)

iso: $(iso)

$(iso): $(kernel) $(grub_cfg)
	@mkdir -p $(BUILD_DIR)/isofiles/boot/grub
	@cp $(kernel) $(BUILD_DIR)/isofiles/boot/kernel.bin
	@cp $(grub_cfg) $(BUILD_DIR)/isofiles/boot/grub/grub.cfg
	@grub-mkrescue -o $(iso) $(BUILD_DIR)/isofiles  # 2> /dev/null
	@rm -rf $(BUILD_DIR)/isofiles

$(kernel): kernel $(rust_os) $(asm_obj_files) $(linker_script)
	@ld -n --gc-sections -T $(linker_script) -o $(kernel) $(asm_obj_files) $(rust_os)

kernel:
	@RUST_TARGET_PATH=$(shell pwd) xargo build --target $(target)

# compile asm files
$(BUILD_DIR)/arch/$(arch)/%.o: src/arch/$(arch)/%.asm
	@mkdir -p $(shell dirname $@)
	@nasm -f elf64 $< -o $@
