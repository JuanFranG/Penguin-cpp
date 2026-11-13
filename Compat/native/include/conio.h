/* SPDX-License-Identifier: MIT */
#ifndef PENGUIN_CONIO_H
#define PENGUIN_CONIO_H
#ifdef __cplusplus
extern "C" {
#endif
int getch(void);
int _getch(void);
int kbhit(void);
int _kbhit(void);
int getche(void);
void clrscr(void);
void gotoxy(int column, int row);
void textcolor(int color);
void textbackground(int color);
#ifdef __cplusplus
}
#endif
#endif
