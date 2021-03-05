#!/usr/bin/tcc -run

#include <stdio.h>
#include <unistd.h>
#include <termios.h>

int main(){
  int i;
  size_t nread;
  char buf[255];
  struct termios raw;
  tcgetattr(0, &raw);
  raw.c_lflag &= ~(ECHO | ICANON);
  tcsetattr(0, TCSAFLUSH, &raw);
  while((nread=read(0, buf, 255)) > 0){
    for(i=0;i<nread;i++){
      printf("%x ", buf[i]);
    }
    printf("\n");
  }
  return 0;
}
