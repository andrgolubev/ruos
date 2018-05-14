global long_mode_start

section .text
bits 64                                 ; 64-bit instructions are expected since
long_mode_start:
    ; load 0 to all data segment registers
    mov ax, 0
    mov ss, ax
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax

    ; call Rust code
    extern rust_main
    call rust_main

    ; print 'OKAY' to screen
    mov rax, 0x2f592f412f4b2f4f         ; `rax` - extended `eax`
    mov qword [0xb8000], rax
    hlt