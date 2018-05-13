global start

section .text
bits 32
start:
    mov esp, stack_top

    call check_multiboot                ; check that kernel was really loaded with multiboot compliant bootloader
    call check_cpuid                    ; check that cpuid instruction is supported
    call check_long_mode                ; check if long mode can be used

    mov dword [0xb8000], 0x2f4b2f4f     ; print 'OK' to screen
    hlt                                 ; halt the cpu

check_multiboot:
    cmp eax, 0x36d76289                 ; check for magic value in `eax`
    jne .no_multiboot                   ; jump to error if not equal
    ret
.no_multiboot:
    mov al, "0"
    jmp error

; from OSDev Wiki:
check_cpuid:
    ; Check if CPUID is supported by attempting to flip the ID bit (bit 21)
    ; in the FLAGS register. If we can flip it, CPUID is available.

    ; Copy FLAGS in to EAX via stack
    pushfd
    pop eax

    ; Copy to ECX as well for comparing later on
    mov ecx, eax

    ; Flip the ID bit
    xor eax, 1 << 21

    ; Copy EAX to FLAGS via the stack
    push eax
    popfd

    ; Copy FLAGS back to EAX (with the flipped bit if CPUID is supported)
    pushfd
    pop eax

    ; Restore FLAGS from the old version stored in ECX (i.e. flipping the
    ; ID bit back if it was ever flipped).
    push ecx
    popfd

    ; Compare EAX and ECX. If they are equal then that means the bit
    ; wasn't flipped, and CPUID isn't supported.
    cmp eax, ecx
    je .no_cpuid
    ret
.no_cpuid:
    mov al, "1"
    jmp error

; from OSDev Wiki:
check_long_mode:
    ; test if extended processor info is available
    ; this is due to the fact that cpuid was functionally extended over time
    ; thus, some features might not be available in old CPUs (including long mode check)
    mov eax, 0x80000000                 ; Set the A-register to 0x80000000.
    cpuid                               ; CPU identification.
    cmp eax, 0x80000001                 ; Compare the A-register with 0x80000001.
    jb .no_long_mode                    ; It is less, there is no long mode.

    ; use extended info to test if long mode is available
    ; actual long mode check
    mov eax, 0x80000001                 ; Set the A-register to 0x80000001.
    cpuid                               ; CPU identification.
    test edx, 1 << 29                   ; Test if the LM-bit, which is bit 29, is set in the D-register.
    jz .no_long_mode                    ; They aren't, there is no long mode.
    ret
.no_long_mode:
    mov al, "2"
    jmp error

; Print 'ERR: ' and the given error code to screen and hang.
; parameter: error code (in ascii) in al
error:
    ; VGA text buffer begins at 0xb8000:
    ; 4f (color code) - white text on red background
    ; characters are all ASCII
    mov dword [0xb8000], 0x4f524f45     ; 52 - R   | 45 - E
    mov dword [0xb8004], 0x4f3a4f52     ; 3a - ':' | 52 - R
    mov dword [0xb8008], 0x4f204f20     ; 20 - ' '
    mov byte  [0xb800a], al             ; al - overrides last space with given error code
    hlt                                 ; halt the cpu

; reserve bytes for stack
section .bss
stack_bottom:
    resb 64
stack_top: