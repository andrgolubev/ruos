#![feature(lang_items)]
#![feature(const_fn)]
#![feature(ptr_internals)]
#![no_std]

extern crate rlibc;
extern crate volatile;
extern crate spin;

#[macro_use]
mod vga_buffer;

#[no_mangle]
pub extern fn rust_main() {
    // let mut w = vga_buffer::WRITER.lock();
    // w.write_str("Hello, World!\n");
    // use core::fmt::Write;
    // write!(w, "Numbers: {} and {}", 42, 1.0/3.0);
    vga_buffer::clear_screen();
    println!("Hello World{}", "!");
    println!("Numbers: {} and {}", 42, 1.0/3.0);
    loop{}
}

#[lang = "eh_personality"] #[no_mangle] pub extern fn eh_personality() {}
#[lang = "panic_fmt"] #[no_mangle] pub extern fn panic_fmt() -> ! { loop{} }
