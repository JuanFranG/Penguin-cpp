/* SPDX-License-Identifier: MIT */
#include <windows.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <locale.h>
#include <wchar.h>
#ifdef __cplusplus
#include <iostream>
#include <string>
#endif
int main(int argc, char **argv) {
    HANDLE out = GetStdHandle(STD_OUTPUT_HANDLE);
    DWORD written = 0;
    int cp = argc > 1 ? atoi(argv[1]) : 65001;
    CONSOLE_SCREEN_BUFFER_INFO info;
    char input[64];
    if (GetConsoleOutputCP() != (UINT)cp || GetConsoleCP() != (UINT)cp) return 10;
    if (GetFileType(out) != FILE_TYPE_CHAR) return 11;
    {
        wchar_t converted = 0;
        int available = mbtowc(&converted, "\xc3\xb1", 2) == 2 && converted == 0x00f1;
        printf("CRT_UTF8_AVAILABLE:%d\n", available); fflush(stdout);
    }
    if (cp == 437) {
        const char box[] = { (char)218, (char)196, (char)191, ' ', (char)219, 0 };
        printf("PRINTF_BOX:%s\n", box); fflush(stdout);
        WriteConsoleA(out, box, (DWORD)strlen(box), &written, 0);
    } else if (cp == 1252) {
        const char spanish[] = { 'E','s','p','a',(char)241,'o','l',' ',(char)225,0 };
        printf("PRINTF_ANSI:%s\n", spanish); fflush(stdout);
        WriteConsoleA(out, spanish, (DWORD)strlen(spanish), &written, 0);
    } else {
        const char *spanish = "Espa\xc3\xb1ol: \xc3\xa1\xc3\xa9\xc3\xad\xc3\xb3\xc3\xba \xc3\xb1";
        printf("PRINTF_UTF8:%s\n", spanish); fflush(stdout);
        WriteConsoleA(out, spanish, (DWORD)strlen(spanish), &written, 0);
    }
    {
        const wchar_t *wide = L"\r\nWIDE: Espa\u00f1ol \u250c\u2500\u2510\r\n";
        if (!WriteConsoleW(out, wide, (DWORD)wcslen(wide), &written, 0)) return 12;
    }
    if (!GetConsoleScreenBufferInfo(out, &info)) return 13;
    {
        WORD old = info.wAttributes;
        COORD position = {7, 4};
        if (!SetConsoleCursorPosition(out, position)) return 14;
        if (!GetConsoleScreenBufferInfo(out, &info) || info.dwCursorPosition.X != 7 || info.dwCursorPosition.Y != 4) return 15;
        if (!SetConsoleTextAttribute(out, FOREGROUND_RED|FOREGROUND_INTENSITY|BACKGROUND_BLUE)) return 16;
        if (!GetConsoleScreenBufferInfo(out, &info) || info.wAttributes != 0x1c) return 17;
        WriteConsoleW(out, L"RED_ON_BLUE", 11, &written, 0);
        SetConsoleTextAttribute(out, old);
    }
    /* Explicit program settings override the initial profile. */
    SetConsoleCP(CP_UTF8); SetConsoleOutputCP(CP_UTF8); setlocale(LC_CTYPE, ".UTF-8");
    printf("\nEXPLICIT: Espa\xc3\xb1ol\nNUMBER:%.1f\nINPUT_READY\n", 1.5); fflush(stdout);
#ifdef __cplusplus
    std::cout << "CPP_UTF8:Espa\xc3\xb1ol\n" << std::flush;
    std::string line;
    if (!std::getline(std::cin, line) || line != "ni\xc3\xb1o") return 18;
    std::cout << "INPUT_OK:" << line << "\n" << std::flush;
#else
    if (!fgets(input, sizeof(input), stdin) || strcmp(input, "ni\xc3\xb1o\n")) return 18;
    printf("INPUT_OK:%s", input); fflush(stdout);
#endif
    /* Leave a style set so the launcher's restoration is observable. */
    SetConsoleTextAttribute(out, FOREGROUND_GREEN|BACKGROUND_RED);
    printf("CONSOLE_CONTRACT_OK\n"); fflush(stdout);
    return 0;
}
