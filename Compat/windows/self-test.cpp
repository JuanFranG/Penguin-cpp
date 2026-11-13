/* SPDX-License-Identifier: MIT */
#include <windows.h>
#include <conio.h>
#include <math.h>
#include <stdlib.h>
#include <stdio.h>
#include <vector>
#include <numeric>
int main() {
    char *end = nullptr;
    long n = strtol("81", &end, 10);
    if (*end || fabs(sqrt((double)n) - 9.0) > 0.000001) return 1;
    int *values = (int *)calloc(3, sizeof(int));
    if (!values) return 2;
    values[0] = 1; values[1] = 2; values[2] = 3;
    int sum = values[0] + values[1] + values[2]; free(values);
    std::vector<int> v{1, 2, 3};
    if (sum != 6 || std::accumulate(v.begin(), v.end(), 0) != 6) return 3;
    Sleep(1); (void)_kbhit();
    HDC dc = CreateCompatibleDC(nullptr);
    if (!dc) return 4;
    BITMAPINFO bi{}; bi.bmiHeader.biSize = sizeof(BITMAPINFOHEADER);
    bi.bmiHeader.biWidth = 8; bi.bmiHeader.biHeight = -8;
    bi.bmiHeader.biPlanes = 1; bi.bmiHeader.biBitCount = 32;
    void *pixels = nullptr;
    HBITMAP bitmap = CreateDIBSection(dc, &bi, DIB_RGB_COLORS, &pixels, nullptr, 0);
    if (!bitmap) { DeleteDC(dc); return 5; }
    HGDIOBJ old = SelectObject(dc, bitmap);
    SetPixel(dc, 2, 2, RGB(255, 0, 0));
    bool drawn = GetPixel(dc, 2, 2) == RGB(255, 0, 0);
    SelectObject(dc, old); DeleteObject(bitmap); DeleteDC(dc);
    if (!drawn) return 6;
    printf("PENGUIN_WINDOWS_READY pid=%lu sum=%d\n", (unsigned long)GetCurrentProcessId(), sum);
    return 0;
}
