// src/vga_vuffer.rs
use spin::Mutex;
// global writer for other modules usage
pub static WRITER: Mutex<VgaWriter> = Mutex::new(VgaWriter {
    column_pos: 0,
    color_code: ColorCode::new(VgaColor::LightGreen, VgaColor::Black),
    buffer: unsafe{ Unique::new_unchecked(0xb8000 as *mut _) }
});

// custom printing
macro_rules! print {
    ($($arg:tt)*) => ({
        $crate::vga_buffer::print(format_args!($($arg)*));
    })
}
macro_rules! println {
    ($fmt:expr) => (print!(concat!($fmt, "\n")));
    ($fmt:expr, $($arg:tt)*) => (print!(concat!($fmt, "\n"), $($arg)*));
}

pub fn print(args: fmt::Arguments) {
    use core::fmt::Write;
    WRITER.lock().write_fmt(args).unwrap();
}

const BUFFER_HEIGTH: usize = 25;
const BUFFER_WIDTH: usize = 80;

pub fn clear_screen() {
    for _ in 0..BUFFER_HEIGTH {
        println!("");
    }
}


#[allow(dead_code)]
#[derive(Debug, Clone, Copy)]
#[repr(u8)]  // uint8 as an underlying type
pub enum VgaColor {
    Black      = 0,
    Blue       = 1,
    Green      = 2,
    Cyan       = 3,
    Red        = 4,
    Magenta    = 5,
    Brown      = 6,
    LightGray  = 7,
    DarkGray   = 8,
    LightBlue  = 9,
    LightGreen = 10,
    LightCyan  = 11,
    LightRed   = 12,
    Pink       = 13,
    Yellow     = 14,
    White      = 15
}

#[derive(Debug, Clone, Copy)]
struct ColorCode(u8);

impl ColorCode {
    const fn new(foreground: VgaColor, background: VgaColor) -> ColorCode {
        ColorCode((background as u8) << 4 | (foreground as u8))
    }
}

#[derive(Debug, Clone, Copy)]
#[repr(C)]  // guarantee field ordering
struct ScreenChar {
    ascii_char: u8,
    color_code: ColorCode
}


use volatile::Volatile;
struct Buffer {
    chars: [[Volatile<ScreenChar>; BUFFER_WIDTH]; BUFFER_HEIGTH]
}

use core::ptr::Unique;

pub struct VgaWriter {
    column_pos: usize,
    color_code: ColorCode,
    buffer: Unique<Buffer>
}

impl VgaWriter {
    pub fn write_byte(&mut self, byte: u8) {
        match byte {
            b'\n' => self.new_line(),
            byte => {
                if self.column_pos >= BUFFER_WIDTH {
                    self.new_line()
                }

                let row = BUFFER_HEIGTH - 1;
                let col = self.column_pos;
                let color_code = self.color_code;

                self.buffer().chars[row][col].write(ScreenChar {
                    ascii_char: byte,
                    color_code: color_code
                });
                self.column_pos += 1;
            }
        }
    }

    pub fn write_str(&mut self, s: &str) {
        for byte in s.bytes() {
            self.write_byte(byte)
        }
    }

    fn buffer(&mut self) -> &mut Buffer {
        unsafe{ self.buffer.as_mut() }
    }

    fn new_line(&mut self) {
        for row in 1..BUFFER_HEIGTH {
            for col in 0..BUFFER_WIDTH {
                let buffer = self.buffer();
                let character = buffer.chars[row][col].read();
                buffer.chars[row-1][col].write(character);
            }
        }
        self.clear_row(BUFFER_HEIGTH-1);
        self.column_pos = 0;
    }

    fn clear_row(&mut self, row: usize) {
        let blank = ScreenChar {
            ascii_char: b' ',
            color_code: self.color_code
        };

        for col in 0..BUFFER_WIDTH {
            self.buffer().chars[row][col].write(blank);
        }
    }
}

// support for printing built-in types
use core::fmt;
impl fmt::Write for VgaWriter {
    fn write_str(&mut self, s: &str) -> fmt::Result {
        for byte in s.bytes() {
            self.write_byte(byte)
        }
        Ok(())
    }
}
