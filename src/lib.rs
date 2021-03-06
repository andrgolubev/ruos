#![feature(lang_items)]
#![feature(const_fn)]
#![feature(ptr_internals)]
#![no_std]

// standard crates
extern crate rlibc;
extern crate volatile;
extern crate spin;
extern crate multiboot2;

#[macro_use]
mod vga_buffer;
mod memory;
use memory::FrameAllocator;

#[no_mangle]
pub extern fn rust_main(multiboot_info_addr: usize) {
    vga_buffer::clear_screen();
    let boot_info = unsafe { multiboot2::load(multiboot_info_addr) };
    let memory_map_tag = boot_info.memory_map_tag()
        .expect("Memory map tag required");
    println!("memory areas:");
    for area in memory_map_tag.memory_areas() {
        println!("    start: 0x{:x}, length: 0x{:x}",
            area.base_addr, area.length);
    }

    let elf_section_tag = boot_info.elf_sections_tag()
        .expect("Elf-section tag required");
    println!("kernel sections:");
    for section in elf_section_tag.sections() {
        println!("    addr: 0x{:x}, size: 0x{:x}, flags: 0x{:x}",
            section.addr, section.size, section.flags);
    }

    let kernel_start = elf_section_tag.sections().map(|s| s.addr)
        .min().unwrap();
    let kerned_end = elf_section_tag.sections().map(|s| s.addr)
        .max().unwrap();
    let multiboot_start = multiboot_info_addr;
    let multiboot_end = multiboot_start + (boot_info.total_size as usize);

    println!("kernel start: 0x{:x}, kernel end: 0x{:x}",
        kernel_start, kerned_end);
    println!("multiboot start: 0x{:x}, multiboot end: 0x{:x}",
        multiboot_start, multiboot_end);

    let mut frame_allocator = memory::AreaFrameAllocator::new(
        kernel_start as usize, kerned_end as usize,
        multiboot_start as usize, multiboot_end as usize,
        memory_map_tag.memory_areas()
    );
    println!("{:?}", frame_allocator.allocate_frame());

    for i in 0.. {
        if let None = frame_allocator.allocate_frame() {
            println!("allocated {} frames", i);
            break;
        }
    }
    frame_allocator.deallocate_frame();

    loop{}
}

#[lang = "eh_personality"] #[no_mangle] pub extern fn eh_personality() {}

#[lang = "panic_fmt"]
#[no_mangle]
pub extern fn panic_fmt(
    fmt: core::fmt::Arguments,
    file: &'static str,
    line: u32) -> ! {
    println!("\n\nPANIC in {} at line {}:", file, line);
    println!("    {}", fmt);
    loop{}
}
