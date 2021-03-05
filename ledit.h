/*
 * ledit.c: a line editor
 *
 * Reference implementation -- this was written
 * before ledit.asm
 *
 * Basic usage:
 *
 * #define LEDIT_HIGHLIGHT syntax
 * #include "ledit.h"
 *
 * void syntax(char *inp, int is_final){
 *   printf("%s", inp);
 *   fflush(stdout);
 * }
 *
 * int main(){
 *   ledit("ledit$ ", 7);
 *   return 0;
 * }
 */

#ifndef __LEDIT_H
#define __LEDIT_H

#include <stdio.h>
#include <unistd.h>
#include <stdlib.h>
#include <string.h>
#include <termios.h>

#define LEDIT_MAXLEN 255
#define LEDIT_HIST_INITIALSIZE 16

#define LENGTH(x) (sizeof(x)/sizeof(x[0]))

/* Fancy pseudo-closure C idiom */
#define set_cursor() \
  do { \
    printf("\x1b[%iG", prompt_len+cur+nread+1); \
    fflush(stdout); \
  } while(0)
#define redraw(is_final) \
  do { \
    printf("\x1b[0m\x1b[0G\x1b[2K%s", prompt); \
    LEDIT_HIGHLIGHT(out, is_final); \
    printf("\x1b[%iG", prompt_len+cur+nread+1); \
    fflush(stdout); \
  } while(0)
#define move_word(dir) \
  do { \
    int pos = cur, \
        lim = (dir==1 ? strlen(out) : 0); \
    while((dir==1 ? pos < lim : pos > lim)){ \
      pos += dir; \
      if(out[pos] == ' ' || \
         out[pos] == '_' || \
         out[pos] == '-'){ \
        break; \
      } \
    } \
    cur = pos; \
    set_cursor(); \
  } while(0)

struct termios tio, raw;
char **history = NULL;
int history_len = 1, /* Size of allocated array */
    history_ind = 0, /* Current entry in array */
    history_pos = 0; /* Current entry while scrolling through history */

void LEDIT_HIGHLIGHT();

char *ledit(char *prompt, int prompt_len){
  char *out = malloc(LEDIT_MAXLEN),
       buf[LEDIT_MAXLEN];
  int cur = 0,
      nread;

  /* Enter terminal raw mode */
  tcgetattr(STDIN_FILENO, &tio);
  raw = tio;
  raw.c_lflag &= ~(ECHO | ICANON);
  tcsetattr(STDIN_FILENO, TCSAFLUSH, &raw);

  memset(out, '\0', LEDIT_MAXLEN);
  memset(buf, '\0', LEDIT_MAXLEN);

  if(history == NULL) history = malloc(sizeof(char*)*history_len);
  history_pos = history_len-1;

  /* Clear line, print prompt */
  redraw(0);
  
  /* Main loop */
  while((nread=read(STDIN_FILENO, buf, LEDIT_MAXLEN)) > 0){
    switch(buf[0]){
      case '\n':
      case '\r':
        goto shutdown;
      case '\x1b':
        nread = 0;
        if(buf[1] == '['){
          switch(buf[2]){
            case 'A': /* Up arrow */
              if(history_pos > 0){
                history_pos--;
                strcpy(out, history[history_pos]);
                cur = strlen(out);
                redraw(0);
              }
              break;
            case 'B': /* Down arrow */
              if(history_pos+1 == history_ind){
                memset(out, '\0', LEDIT_MAXLEN);
                cur = 0;
                redraw(0);
                break;
              }

              if(history_pos < history_len){
                history_pos++;
                strcpy(out, history[history_pos]);
                cur = strlen(out);
                redraw(0);
              }
              break;
            case 'C': /* Right arrow */
              if(cur < strlen(out)){
                cur++;
                set_cursor();
              }
              break;
            case 'D': /* Left arrow */
              if(cur > 0){
                cur--;
                set_cursor();
              }
              break;
            case '1':
              if(buf[3] == '~'){ /* Home */
                cur = 0;
                set_cursor();
              } else if(buf[3] == ';'){ /* Ctrl+... */
                if(buf[5] == 'C'){ /* ...Right */
                  move_word(1);
                } else if(buf[5] == 'D'){ /* ...Left */
                  move_word(-1);
                }
              }
              break;
            case '3': /* Delete */
              if(cur < strlen(out)){
                memmove(out+cur, out+cur+1, strlen(out)-cur);
                redraw(0);
              }
              break;
            case '4': /* End */
              cur = strlen(out);
              set_cursor();
              break;
          }
        }
        break;
      case 0x7f: /* Backspace */
        if(strlen(out) > 0 &&
           cur > 0){
          nread = 0;
          cur--;
          memmove(out+cur, out+cur+1, strlen(out)-cur);
          redraw(0);
        }
        break;
      case 0x01: /* Ctrl+A (same as home key) */
        nread = 0;
        cur = 0;
        set_cursor();
        break;
      case 0x05: /* Ctrl+E (same as end key) */
        nread = 0;
        cur = strlen(out);
        set_cursor();
        break;
      default:
        buf[nread] = '\0';
        memmove(out+cur+nread, out+cur, strlen(out)-cur);
        strncpy(out+cur, buf, nread);

        redraw(0);

        cur+=nread;
        break;
    }
  }

shutdown:;
  redraw(1);
  history[history_ind++] = strdup(out);
  if(history_ind == history_len){
    history_len++;
    history = realloc(history, sizeof(char*)*history_len);
  }
  printf("\x1b[0m\n");
  tcsetattr(STDIN_FILENO, TCSAFLUSH, &tio);

  return out;
}

#endif /* __LEDIT_H */
