## ledit.asm

A 100% dependency-free terminal line editor, written in x86_64 assembly.

Highlights:
- Zero dependencies:  Not even libc/standard library -- can be dropped into any project and work immediately
- Basic navigation functionality:  Arrow keys, home/end keys (and Ctrl+A/Ctrl-E), backspace, and delete
- No dynamic memory allocation:  Works with static buffers only
- Tiny:  Static library is <2kb in size when stripped

### Demo

![Demo](https://github.com/Cubified/ledit.asm/blob/main/demo.gif)

### Compiling and Running

`ledit` depends upon `nasm`.  To compile and run the demo application, run:

     $ make demo
     $ ./demo

This will start the line editor.  Press Enter to exit.

### Using `ledit` as a `readline`-like Library

After compiling, the static library `ledit.asm.o` should be present.  To compile a program with `ledit`, add this to the compiler's list of input files.

Important!  Due to the way `ledit` is written (read: because I am an assembly newbie), any C code must be compiled with `-static`.  For example:

     $ cc my_app.c ledit.asm.o -o my_app -static

To use `ledit` within C code, define the function `ledit()` as an `extern` and define your own `syntax()` function.  The simplest usage is as follows:

```c
#include <unistd.h>  // For write()

extern void ledit(); // Tell compiler to look in ledit.asm.o for ledit

void syntax(char *inp, int inp_len){ // Can be used for syntax highlighting and other text post-processing
  write(STDOUT_FILENO, inp, inp_len);
}

int main(){
  ledit();
  return 0;
}
```

### Some Interesting Implementation Details

- I rolled my own `itoa()` in about 35 instructions for this project, see label `itoa` in [ledit.asm](https://github.com/Cubified/ledit.asm/blob/main/ledit.asm) for the annotated algorithm.
- `ledit` interfaces directly with termios (without the C standard library's `tcgetattr()` or `tcsetattr()`), see the beginning of labels `ledit` and `shutdown`.
- See [ledit.h](https://github.com/Cubified/ledit.asm/blob/main/ledit.h) for the reference C implementation.  Most features in the asm version are 1:1 with the C version, but there some changes (most notably, the lack of sscanf() and printf() in asm, which the C version uses very liberally).
