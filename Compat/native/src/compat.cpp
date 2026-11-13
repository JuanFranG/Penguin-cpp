// SPDX-License-Identifier: MIT
#include "graphics.h"
#include "conio.h"
#include <SDL3/SDL.h>
#include <algorithm>
#include <cctype>
#include <cstdio>
#include <deque>
#include <poll.h>
#include <string>
#include <termios.h>
#include <unistd.h>
#include <vector>

namespace {
SDL_Window *window = nullptr;
SDL_Renderer *renderer = nullptr;
SDL_Texture *canvas = nullptr;
int width = 0, height = 0, pen = WHITE, background = BLACK, fill = WHITE, pattern = SOLID_FILL;
int error_code = grOk;
bool closed = false, owns_video = false;
std::string backend_error;
std::deque<int> keys;
const SDL_Color palette[16] = {
    {0, 0, 0, 255}, {0, 0, 170, 255}, {0, 170, 0, 255}, {0, 170, 170, 255},
    {170, 0, 0, 255}, {170, 0, 170, 255}, {170, 85, 0, 255}, {170, 170, 170, 255},
    {85, 85, 85, 255}, {85, 85, 255, 255}, {85, 255, 85, 255}, {85, 255, 255, 255},
    {255, 85, 85, 255}, {255, 85, 255, 255}, {255, 255, 85, 255}, {255, 255, 255, 255}
};
void failed() {
    backend_error = SDL_GetError();
    error_code = grBackendError;
}
bool valid_color(int c) {
    if (c >= 0 && c < 16) {
        return true;
    }
    error_code = grInvalidArgument;
    return false;
}
bool ready() {
    if (renderer && canvas) {
        return true;
    }
    error_code = grNoInitGraph;
    return false;
}
bool color(int c) {
    const auto p = palette[c];
    if (SDL_SetRenderDrawColor(renderer, p.r, p.g, p.b, p.a)) {
        return true;
    }
    failed();
    return false;
}
void events() {
    SDL_Event event;
    while (SDL_PollEvent(&event)) {
        if (event.type == SDL_EVENT_QUIT || event.type == SDL_EVENT_WINDOW_CLOSE_REQUESTED) {
            closed = true;
        }
        if (event.type == SDL_EVENT_KEY_DOWN && !event.key.repeat) {
            int key = event.key.key;
            if (key >= 32 && key <= 126) {
                if (event.key.mod & SDL_KMOD_SHIFT) {
                    key = std::toupper(static_cast<unsigned char>(key));
                }
                keys.push_back(key);
            } else if (key == SDLK_ESCAPE) {
                keys.push_back(27);
            } else if (key == SDLK_RETURN) {
                keys.push_back(13);
            } else if (key == SDLK_BACKSPACE) {
                keys.push_back(8);
            }
        }
    }
}
void present() {
    if (!ready()) {
        return;
    }
    if (!SDL_SetRenderTarget(renderer, nullptr)) {
        failed();
        return;
    }
    if (!SDL_RenderTexture(renderer, canvas, nullptr, nullptr) || !SDL_RenderPresent(renderer)) {
        failed();
    }
    if (!SDL_SetRenderTarget(renderer, canvas)) {
        failed();
    }
    events();
}
struct TerminalMode {
    termios original{};
    bool changed = false;
    TerminalMode() {
        if (isatty(STDIN_FILENO) && tcgetattr(STDIN_FILENO, &original) == 0) {
            termios raw = original;
            raw.c_lflag &= ~(ICANON | ECHO);
            raw.c_cc[VMIN] = 1;
            raw.c_cc[VTIME] = 0;
            changed = tcsetattr(STDIN_FILENO, TCSANOW, &raw) == 0;
        }
    }
    ~TerminalMode() {
        if (changed) {
            tcsetattr(STDIN_FILENO, TCSANOW, &original);
        }
    }
};
int ansi_color(int c) {
    static const int map[] = {0, 4, 2, 6, 1, 5, 3, 7};
    return map[c % 8];
}
}
extern "C" {
    void closegraph() {
        if (canvas) {
            SDL_DestroyTexture(canvas);
        }
        if (renderer) {
            SDL_DestroyRenderer(renderer);
        }
        if (window) {
            SDL_DestroyWindow(window);
        }
        canvas = nullptr;
        renderer = nullptr;
        window = nullptr;
        width = height = 0;
        keys.clear();
        closed = false;
        if (owns_video) {
            SDL_QuitSubSystem(SDL_INIT_VIDEO);
        }
        owns_video = false;
    }
    int initwindow(int w, int h, const char *title) {
        closegraph();
        error_code = grOk;
        backend_error.clear();
        if (w < 1 || h < 1||w>8192 || h > 8192) {
            error_code = grInvalidArgument;
            return -1;
        }
        owns_video = (SDL_WasInit(SDL_INIT_VIDEO) == 0);
        if (owns_video && !SDL_InitSubSystem(SDL_INIT_VIDEO)) {
            failed();
            closegraph();
            return -1;
        }
        window = SDL_CreateWindow(title ? title : "Penguin graphics", w, h, 0);
        if (!window) {
            failed();
            closegraph();
            return -1;
        }
#ifdef __APPLE__
        renderer = SDL_CreateRenderer(window, "metal");
#else
        renderer = SDL_CreateRenderer(window, nullptr);
#endif
        if (!renderer) {
            failed();
            closegraph();
            return -1;
        }
        canvas = SDL_CreateTexture(renderer, SDL_PIXELFORMAT_RGBA8888, SDL_TEXTUREACCESS_TARGET, w, h);
        if (!canvas || !SDL_SetRenderTarget(renderer, canvas)) {
            failed();
            closegraph();
            return -1;
        }
        width = w;
        height = h;
        pen = WHITE;
        background = BLACK;
        fill = WHITE;
        pattern = SOLID_FILL;
        cleardevice();
        return 1;
    }
    void initgraph(int *driver, int *mode, const char *) {
        if (initwindow(640, 480, "Penguin graphics") > 0) {
            if (driver) {
                *driver = VGA;
            }
            if (mode) {
                *mode = VGAHI;
            }
        }
    }
    int graphresult() {
        int result = error_code;
        error_code = grOk;
        return result;
    }
    const char *grapherrormsg(int code) {
        switch (code) {
        case grOk:
            return "No error";
        case grNoInitGraph:
            return "Graphics not initialized";
        case grInvalidArgument:
            return "Argument or feature not supported by this prototype";
        case grBackendError:
            return backend_error.c_str();
        default:
            return "Unknown graphics error";
        }
    }
    const char *penguin_graphics_backend() {
        return renderer ? SDL_GetRendererName(renderer) : "none";
    }
    int getmaxx() {
        return ready() ? width - 1 : -1;
    }
    int getmaxy() {
        return ready() ? height - 1 : -1;
    }
    void setcolor(int c) {
        if (valid_color(c)) {
            pen = c;
        }
    }
    int getcolor() {
        return pen;
    }
    void setbkcolor(int c) {
        if (valid_color(c)) {
            background = c;
        }
    }
    int getbkcolor() {
        return background;
    }
    void setfillstyle(int p, int c) {
        if (p != EMPTY_FILL && p != SOLID_FILL) {
            error_code = grInvalidArgument;
            return;
        }
        if (valid_color(c)) {
            pattern = p;
            fill = c;
        }
    }
    void cleardevice() {
        if (ready() && color(background)) {
            if (!SDL_RenderClear(renderer)) {
                failed();
            }
            present();
        }
    }
    void line(int x1, int y1, int x2, int y2) {
        if (ready() && color(pen)) {
            if (!SDL_RenderLine(renderer, float(x1), float(y1), float(x2), float(y2))) {
                failed();
            }
            present();
        }
    }
    void rectangle(int l, int t, int r, int b) {
        if (!ready()) {
            return;
        }
        if (r < l || b < t) {
            error_code = grInvalidArgument;
            return;
        }
        SDL_FRect rect{float(l), float(t), float(r - l + 1), float(b - t + 1)};
        if (color(pen) && !SDL_RenderRect(renderer, &rect)) {
            failed();
        }
        present();
    }
    void bar(int l, int t, int r, int b) {
        if (!ready()) {
            return;
        }
        if (r < l || b < t) {
            error_code = grInvalidArgument;
            return;
        }
        SDL_FRect rect{float(l), float(t), float(r - l + 1), float(b - t + 1)};
        if (color(pattern == EMPTY_FILL ? background : fill) && !SDL_RenderFillRect(renderer, &rect)) {
            failed();
        }
        present();
    }
    void circle(int cx, int cy, int radius) {
        if (!ready()) {
            return;
        }
        if (radius < 0 || radius > 32767) {
            error_code = grInvalidArgument;
            return;
        }
        std::vector<SDL_FPoint> points;
        for (int x = radius, y = 0, d = 1 - radius; x >= y; ++y) {
            const int dx[] = {x, y, -y, -x, -x, -y, y, x}, dy[] = {y, x, x, y, -y, -x, -x, -y};
            for (int i = 0; i < 8; ++i)
                points.push_back({float(cx + dx[i]), float(cy + dy[i])});
            if (d < 0) {
                d += 2 * y + 3;
            } else {
                d += 2 * (y - x) +5;
                --x;
            }
        }
        if (color(pen) && !SDL_RenderPoints(renderer, points.data(), int(points.size()))) {
            failed();
        }
        present();
    }
    void putpixel(int x, int y, int c) {
        if (ready() && valid_color(c) && color(c)) {
            if (!SDL_RenderPoint(renderer, float(x), float(y))) {
                failed();
            }
            present();
        }
    }
    int getpixel(int x, int y) {
        if (!ready()) {
            return -1;
        }
        if (x < 0 || y < 0||x>=width || y >= height) {
            error_code = grInvalidArgument;
            return -1;
        }
        SDL_Rect rect{x, y, 1, 1};
        SDL_Surface* surface = SDL_RenderReadPixels(renderer, &rect);
        if (!surface) {
            failed();
            return -1;
        }
        Uint8 r = 0, g = 0, b = 0, a = 0;
        bool ok = SDL_ReadSurfacePixel(surface, 0, 0, &r, &g, &b, &a);
        SDL_DestroySurface(surface);
        if (!ok) {
            failed();
            return -1;
        }
        for (int i = 0; i < 16; ++i)
            if (palette[i].r == r && palette[i].g == g && palette[i].b == b) {
                return i;
            }
        return -1;
    }
    void outtextxy(int x, int y, const char *text) {
        if (!text) {
            error_code = grInvalidArgument;
            return;
        }
        if (ready() && color(pen)) {
            if (!SDL_RenderDebugText(renderer, float(x), float(y), text)) {
                failed();
            }
            present();
        }
    }
    void delay(unsigned ms) {
        if (!window) {
            SDL_Delay(ms);
            return;
        }
        Uint64 end = SDL_GetTicks() + ms;
        do {
            events();
            if (closed) {
                return;
            }
            SDL_Delay(1);
        } while (SDL_GetTicks() < end);
    }
    int kbhit() {
        if (window) {
            events();
            return !keys.empty();
        }
        TerminalMode mode;
        pollfd p{STDIN_FILENO, POLLIN, 0};
        return poll(&p, 1, 0) > 0 && (p.revents & POLLIN);
    }
    int _kbhit() {
        return kbhit();
    }
    int getch() {
        if (window) {
            while (!closed && keys.empty()) {
                events();
                SDL_Delay(1);
            }
            if (keys.empty()) {
                return EOF;
            }
            int key = keys.front();
            keys.pop_front();
            return key;
        }
        TerminalMode mode;
        unsigned char c = 0;
        return read(STDIN_FILENO, &c, 1) == 1 ? c : EOF;
    }
    int _getch() {
        return getch();
    }
    int getche() {
        int c = getch();
        if (c != EOF && !window) {
            putchar(c);
            fflush(stdout);
        }
        return c;
    }
    void clrscr() {
        fputs("\033[2J\033[H", stdout);
        fflush(stdout);
    }
    void gotoxy(int col, int row) {
        if (col > 0 && row > 0) {
            printf("\033[%d;%dH", row, col);
            fflush(stdout);
        }
    }
    void textcolor(int c) {
        if (valid_color(c)) {
            printf("\033[%dm", (c >= 8 ? 90 : 30) + ansi_color(c));
            fflush(stdout);
        }
    }
    void textbackground(int c) {
        if (valid_color(c)) {
            printf("\033[%dm", (c >= 8 ? 100 : 40) + ansi_color(c));
            fflush(stdout);
        }
    }
}
