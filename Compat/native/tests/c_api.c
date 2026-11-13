/* SPDX-License-Identifier: MIT */
#include <graphics.h>
#include <conio.h>
#include <stdio.h>
int main(void) {
    int driver = DETECT, mode = 0;
    initgraph(&driver, &mode, "");
    int error = graphresult();
    if (error != grOk) {
        fprintf(stderr, "%s\n", grapherrormsg(error));
        return 1;
    }
    putpixel(10, 10, RED);
    int ok = driver == VGA && mode == VGAHI && getmaxx() == 639 &&
             getmaxy() == 479 && getpixel(10, 10) == RED;
    closegraph();
    puts(ok ? "PASS C API: initgraph, dimensions and pixel" : "FAIL C API");
    return !ok;
}
