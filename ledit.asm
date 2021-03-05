;
; ledit.asm: a dependency-free line editor in x86_64 assembly
;

;
; PREPROCESSOR
;
%define MAXLEN 255

;
; TERMIOS STRUCT
;
struc termios
  .c_iflag: resd 1  ; input mode flags
  .c_oflag: resd 1  ; output mode flags
  .c_cflag: resd 1  ; control mode flags
  .c_lflag: resd 1  ; local mode flags
  .c_line:  resb 1  ; line discipline
  .c_cc:    resb 19 ; control characters
endstruc

;
; MEMORY INITIALIZATION
;
section .data
prompt db "ledit$ ", 0x0
prompt_len equ $-prompt

reset db 0x1b, "[0m", 0x1b, "[0G", 0x1b, "[2K", 0x0
reset_len equ $-reset

set_cursor_prologue db 0x1b, "["
set_cursor_prologue_len equ $-set_cursor_prologue

set_cursor_epilogue db "G", 0x0
set_cursor_epilogue_len equ $-set_cursor_epilogue

tio: istruc termios iend

segment .bss
out: resb MAXLEN
buf: resb MAXLEN

out_len: resd 1
nread: resd 1

char: resb 1

spacer: resq 1 ; TODO: Why do I need this? cur overlaps with char otherwise

cur: resd 1

section .text
;
; ITOA IMPLEMENTATION
;
; r15 = input (positive integer)
;
itoa:
  mov r12, 1  ; Temporary version of r14
  mov r13, 10 ; Constant value of 10
  mov r14, 1  ; Current digit of number (ones place, tens place, etc.)
  .len:
    cmp  r15, 9   ; If input is a single digit, no need to determine length
    jle  .loop    ; ^
    cmp  r12, r15 ; If the number of digits is larger than the input, exit
    jg   .conv    ; ^
    imul r12, r13 ; Multiply the current number of digits by 10 (add a digit)
    jmp  .len     ; Continue looping
  .conv:
    mov rax, r12  ; Because the .len loop adds one more place than is correct,
    xor rdx, rdx  ;   divide r12 by 10 (remove one digit) and store the proper
    div r13       ;   value in r14
    mov r14, rax  ;   ^
  .loop:
    mov rax, r15  ; Get single digit in input value
    xor rdx, rdx  ; (Clear remainder, otherwise fills up with garbage)
    div r14       ; / power of 10
    xor rdx, rdx  ; (See above)
    div r13       ; % 10
    add rdx, 48   ; + '0'
    mov [char], rdx ; Store digit (now as an ASCII character)
    
    mov rax, 1    ; Write character to stdout
    mov rdi, 1
    mov rsi, char
    mov rdx, 1
    syscall

    xor  rdx, rdx ; Move right within number (i.e. move towards one place)
    mov  rax, r14 ;   by dividing by 10
    idiv r13      ;   ^
    mov  r14, rax ; Store new place being evaluated
    test r14, r14 ; If new place is 0, exit loop
    je  .done
    jmp .loop
  .done:
    ret

;
; MEMMOVE IMPLEMENTATION
;
memmove:
  cmp rdi, rsi
  je .done
  jb .fast
  mov rcx, rsi
  add rcx, rdx
  cmp rdi, rcx
  jae .fast
  .slow:
    std
    mov rcx, rdx
    dec rdx
    add rsi, rdx
    add rdi, rdx
    rep movsb
    cld
    ret
  .fast:
    mov rcx, rdx
    rep movsb
  .done:
    ret

;
; RENDERING
;
set_cursor:
  mov rax, 1
  mov rdi, 1
  mov rsi, set_cursor_prologue
  mov rdx, set_cursor_prologue_len
  syscall

  mov r15d, prompt_len
  add r15d, [cur]
  call itoa

  mov rax, 1
  mov rdi, 1
  mov rsi, set_cursor_epilogue
  mov rdx, set_cursor_epilogue_len
  syscall

  ret

extern syntax
redraw:
  mov rax, 1
  mov rdi, 1
  mov rsi, reset
  mov rdx, reset_len
  syscall

  mov rax, 1
  mov rdi, 1
  mov rsi, prompt
  mov rdx, prompt_len
  syscall

  mov rdi, out
  mov esi, [out_len]
  call syntax

;  mov rax, 1
;  mov rdi, 1
;  mov rsi, out
;  mov edx, [out_len]
;  syscall

  call set_cursor

  ret

;
; ENTRY POINT
;
global ledit
ledit:
  ; Get termios
  mov rax, 16
  xor rdi, rdi
  mov rsi, 0x5401 ; TCGETS
  mov rdx, tio
  syscall

  ; Enable raw mode
  and dword [tio+termios.c_lflag], -11 ; ~(ECHO | ICANON)
  mov rax, 16
  mov rsi, 0x5402 ; TCSETS
  mov rdx, tio
  syscall

  call redraw

loop:
  ; Blocking read
  xor rax, rax
  xor rdi, rdi
  mov rsi, buf
  mov rdx, MAXLEN
  syscall
  mov [nread], rax

  cmp byte [buf], 0x0a ; \n
  je shutdown

  cmp byte [buf], 0x0d ; \r
  je shutdown

  cmp byte [buf], 0x1b ; \x1b
  je escape_seq

  cmp byte [buf], 0x7f ; Backspace
  je backspace

  cmp byte [buf], 0x01 ; Ctrl+A
  je home_key

  cmp byte [buf], 0x05 ; Ctrl+E
  je end_key

  ; None of the above, print character
  ; TODO: Maybe macro-ify the memmove call
  mov rdi, out       ; Dest = start of string
  add edi, [cur]     ;        + cursor
  add edi, [nread]   ;        + # of bytes read
  mov rsi, out       ; Src  = start of string
  add esi, [cur]     ;        + cursor
  mov edx, [out_len] ; Implicit zero-extension
  sub edx, [cur]     ; ^
  call memmove

  mov rdi, out       ; Dest = start of string
  add edi, [cur]     ;      + cursor
  mov rsi, buf       ; Src  = buffer from read
  mov ecx, [nread]   ; Implicit zero-extension
  rep movsb          ; Byte-by-byte copy

  mov edx, [nread]
  add dword [cur], edx
  add dword [out_len], edx
  call redraw
  jmp loop

escape_seq:
  cmp byte [buf+1], 0x5b ; [
  jne loop
  cmp byte [buf+3], 0x33 ; 3
  je  delete
  cmp byte [buf+2], 0x44 ; D
  je  left_arrow
  cmp byte [buf+2], 0x43 ; C
  je  right_arrow

;  TODO: History
;  cmp byte [buf+2], 0x42 ; B
;  je  down_arrow
;  cmp byte [buf+2], 0x41 ; A
;  je  up_arrow

  cmp byte [buf+2], 0x31 ; 1
  je  home_key
  cmp byte [buf+2], 0x34 ; 4
  je  end_key

delete:
  mov eax, dword [cur]
  cmp eax, dword [out_len]
  je  loop
  mov rdi, out
  add edi, [cur]
  mov rsi, out
  add esi, [cur]
  inc esi
  mov edx, [out_len]
  sub edx, [cur]
  call memmove
  mov dword [nread], 0
  dec dword [out_len]
  call redraw
  jmp loop

left_arrow:
  cmp dword [cur], 0
  jle loop
  dec dword [cur]
  call set_cursor
  jmp loop

right_arrow:
  mov ebx, [out_len]
  cmp [cur], ebx
  jge loop
  inc dword [cur]
  call set_cursor
  jmp loop

; down_arrow:
;   jmp loop

; up_arrow:
;   jmp loop

backspace:
  mov ebx, [cur]
  test ebx, ebx
  je  loop
  mov rdi, out
  add edi, [cur]
  dec edi
  mov rsi, out
  add esi, [cur]
  mov edx, [out_len]
  sub edx, [cur]
  call memmove
  mov dword [nread], 0
  dec dword [out_len]
  dec dword [cur]
  call redraw
  jmp loop

home_key:
  mov dword [cur], 0
  call set_cursor
  jmp loop

end_key:
  mov ebx, dword [out_len]
  mov dword [cur], ebx
  call set_cursor
  jmp loop

shutdown:
  ; Enable cooked mode
  xor dword [tio+termios.c_lflag], -11
  mov rax, 16
  xor rdi, rdi
  mov rsi, 0x5402
  mov rdx, tio
  syscall

  mov rax, 60
  syscall
