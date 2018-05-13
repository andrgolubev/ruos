global start
extern long_mode_start

section .text
bits 32
start:
    mov esp, stack_top

    call check_multiboot                ; check that kernel was really loaded with multiboot compliant bootloader
    call check_cpuid                    ; check that cpuid instruction is supported
    call check_long_mode                ; check if long mode can be used

    call set_up_page_tables
    call enable_paging

    lgdt [gdt64.pointer]                ; load 64-bit GDT (Global Descriptor Table)
    jmp gdt64.code:long_mode_start      ; far jump to reload `cs` (code selector)

    ; no code here is executed after far jump | 32-bit instructions are considered invalid ;

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


set_up_page_tables:
    ; map first P4 entry to P3 table
    mov eax, p3_table
    or eax, 0b11                        ; present + writable
    mov [p4_table], eax

    ; map first P3 entry to P2 table
    mov eax, p2_table
    or eax, 0b11                        ; present + writable
    mov [p3_table], eax

    ; map each P2 entry to a huge 2MiB page
    mov ecx, 0                          ; counter variable

.map_p2_table:
    ; max ecx-th P2 entry to a huge page that starts at 2MiB*ecx
    mov eax, 0x200000                   ; 2 MiB
    mul ecx                             ; start address of ecx-th page
    or eax, 0b10000011                  ; present + writable + huge
    mov [p2_table + ecx*8], eax         ; map ecx-th entry | each entry is 8 bytes

    inc ecx                             ; ecx++
    cmp ecx, 512                        ; if ecx == 512: the whole P2 table is mapped
    jne .map_p2_table                   ; else:          map next entry in P2 table

    ret


enable_paging:
    ; load P4 to cr3 register (it is used by CPU to access P4)
    mov eax, p4_table
    mov cr3, eax

    ; enable PAE-flag in cr4 (Physical Address Extension)
    mov eax, cr4
    or eax, 1 << 5
    mov cr4, eax

    ; set the long mode bit in EFER MSR
    mov ecx, 0xC0000080
    rdmsr
    or eax, 1 << 8
    wrmsr

    ; enable paging in the cr0 register
    mov eax, cr0
    or eax, 1 << 31
    mov cr0, eax

    ret


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


section .rodata
gdt64:
    dq 0                                ; zero entry
.code: equ $ - gdt64                    ; calculate offset and store it in gdt64.code
    dq (1<<43)|(1<<44)|(1<<47)|(1<<53)  ; executable|code segment|present|64-bit
.pointer:
    dw $ - gdt64 - 1
    dq gdt64


; reserve bytes for stack
section .bss
align 4096
p4_table:
    resb 4096
p3_table:
    resb 4096
p2_table:
    resb 4096
stack_bottom:
    resb 64
stack_top: