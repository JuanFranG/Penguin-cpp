/* SPDX-License-Identifier: MIT
 * Copyright (c) 2026 Penguin cpp contributors. See Compat/windows/LICENSE.
 * Keep the C runtime and the Windows console on the same initial code page.
 * This runs once before main; explicit settings made by the program take over.
 */
#include <windows.h>
#include <locale.h>
#include <stdio.h>
#include <stdlib.h>
#ifndef PENGUIN_CONSOLE_CP
#define PENGUIN_CONSOLE_CP 65001
#endif
static UINT original_input, original_output;
static HANDLE console_output;
static WORD original_attributes;
static int have_attributes;
static void penguin_console_restore(void)
{
    fflush(NULL);
    if (have_attributes) SetConsoleTextAttribute(console_output, original_attributes);
    if (original_input && GetConsoleCP() == PENGUIN_CONSOLE_CP) SetConsoleCP(original_input);
    if (original_output && GetConsoleOutputCP() == PENGUIN_CONSOLE_CP) SetConsoleOutputCP(original_output);
}
static void __attribute__((constructor(101))) penguin_console_startup(void)
{
#if PENGUIN_CONSOLE_CP == 437
    const char *locale = ".437";
#elif PENGUIN_CONSOLE_CP == 1252
    const char *locale = ".1252";
#else
    const char *locale = ".UTF-8";
#endif
    CONSOLE_SCREEN_BUFFER_INFO info;
    if (atexit(penguin_console_restore)) return;
    original_input = GetConsoleCP(); original_output = GetConsoleOutputCP();
    console_output = GetStdHandle(STD_OUTPUT_HANDLE);
    have_attributes = GetConsoleScreenBufferInfo(console_output, &info);
    if (have_attributes) original_attributes = info.wAttributes;
    /* Keep numeric formatting and all other locale categories unchanged. */
    if (setlocale(LC_CTYPE, locale)) {
        SetConsoleCP(PENGUIN_CONSOLE_CP);
        SetConsoleOutputCP(PENGUIN_CONSOLE_CP);
    }
}
