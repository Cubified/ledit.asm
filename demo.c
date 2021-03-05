/*
 * demo.c: a demo for ledit
 */

#include <stdio.h>
#include <unistd.h>

extern void ledit(char *prompt, int prompt_len);

void syntax(char *inp, int inp_len){
  int color = 31;
  int ind = -1;
  printf("\x1b[%im", color);
  while(++ind < inp_len){
    if(inp[ind] == ' ') printf("\x1b[%im", ++color);
    if(color > 36) color = 31;

    putchar(inp[ind]);
  }
  fflush(stdout);
}

int main(){
  ledit("ledit$ ", 7);
  return 0;
}
