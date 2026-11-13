/* SPDX-License-Identifier: MIT
 * Penguin native compatibility prototype. See ../README.md for coverage. */
#ifndef PENGUIN_GRAPHICS_H
#define PENGUIN_GRAPHICS_H
#ifdef __cplusplus
extern "C" {
#endif
enum { BLACK, BLUE, GREEN, CYAN, RED, MAGENTA, BROWN, LIGHTGRAY,
       DARKGRAY, LIGHTBLUE, LIGHTGREEN, LIGHTCYAN, LIGHTRED, LIGHTMAGENTA, YELLOW, WHITE
     };
enum { DETECT = 0, VGA = 9, VGAHI = 2, EMPTY_FILL = 0, SOLID_FILL = 1,
       grOk = 0, grNoInitGraph = -1, grInvalidArgument = -11, grBackendError = -100
     };
#ifdef __cplusplus
int initwindow(int width, int height, const char *title = "Penguin graphics");
#else
int initwindow(int width, int height, const char *title);
#endif
void initgraph(int *driver, int *mode, const char *legacy_path);
void closegraph(void);
int graphresult(void);
const char *grapherrormsg(int error);
int getmaxx(void);
int getmaxy(void);
void setcolor(int color);
int getcolor(void);
void setbkcolor(int color);
int getbkcolor(void);
void setfillstyle(int pattern, int color);
void cleardevice(void);
void line(int x1, int y1, int x2, int y2);
void rectangle(int left, int top, int right, int bottom);
void bar(int left, int top, int right, int bottom);
void circle(int x, int y, int radius);
void putpixel(int x, int y, int color);
int getpixel(int x, int y);
void outtextxy(int x, int y, const char *text);
void delay(unsigned milliseconds);
/* Diagnostics for tests; not a BGI API. */
const char *penguin_graphics_backend(void);
#ifdef __cplusplus
}
#endif
#endif
