// SPDX-License-Identifier: MIT
#include <bits/stdc++.h>
#include <graphics.h>
#include <conio.h>
int main(int argc, char **argv) {
    const bool verify = argc > 1 && std::string(argv[1]) == "--verify";
    initwindow(680, 420, "Penguin compatibility prototype");
    int error = graphresult();
    if (error != grOk) {
        std::cerr << grapherrormsg(error) << '\n';
        return 1;
    }
    setbkcolor(BLACK);
    cleardevice();
    setcolor(LIGHTCYAN);
    rectangle(20, 20, 659, 399);
    line(40, 85, 640, 85);
    outtextxy(40, 45, "Penguin: native graphics.h prototype");
    setcolor(YELLOW);
    circle(170, 210, 75);
    setfillstyle(SOLID_FILL, LIGHTBLUE);
    bar(310, 140, 430, 280);
    setfillstyle(SOLID_FILL, LIGHTGREEN);
    bar(460, 200, 610, 280);
    setcolor(WHITE);
    outtextxy(40, 340, "Console input and graphics use native APIs.");
    outtextxy(40, 365, "Press any ASCII key in this window to close.");
    std::cout << "renderer=" << penguin_graphics_backend() << std::endl;
    if (verify) {
        int failures = 0;
        auto check = [&](bool ok, const char *label) {std::cout << (ok ? "PASS " : "FAIL ") << label << '\n'; if (!ok)++failures;};
#ifdef __APPLE__
        check(std::string(penguin_graphics_backend()) == "metal", "Metal renderer is active");
#endif
        check(getmaxx() == 679 && getmaxy() == 419, "BGI dimensions");
        check(getpixel(320, 150) == LIGHTBLUE, "filled bar pixel");
        check(getpixel(470, 210) == LIGHTGREEN, "second bar pixel");
        check(getpixel(170, 210) == BLACK, "circle remains unfilled");
        check(getpixel(245, 210) == YELLOW, "circle boundary pixel");
        putpixel(50, 100, LIGHTRED);
        check(getpixel(50, 100) == LIGHTRED, "putpixel/getpixel");
        circle(0, 0, -1);
        check(graphresult() == grInvalidArgument, "invalid radius rejected");
        setfillstyle(99, BLUE);
        check(graphresult() == grInvalidArgument, "unsupported pattern rejected");
        check(graphresult() == grOk, "graphresult clears last error");
        closegraph();
        check(getmaxx() == -1 && graphresult() == grNoInitGraph, "calls after close rejected");
        return failures ? 1 : 0;
    }
    int key = getch();
    std::cout << "key=" << key << std::endl;
    closegraph();
    return 0;
}
