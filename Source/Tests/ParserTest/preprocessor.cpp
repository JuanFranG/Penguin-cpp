// Conditional compilation cases for parsertest.
// Every good_* symbol must be found and no bad_* symbol may appear.

// #elif chain: only the first true branch is taken (libc++ _LIBCPP_STD_VER style)
#define LEVEL 14
#if LEVEL <= 11
int bad_chain_11;
#elif LEVEL <= 14
int good_chain_14;
#elif LEVEL <= 17
int bad_chain_17;
#else
int bad_chain_else;
#endif

// #else after a taken / not taken #if
#if 1
int good_if;
#else
int bad_else;
#endif
#if 0
int bad_if0;
#else
int good_else;
#endif

// Nested conditionals inside a branch that is skipped
#if 0
#  if 1
int bad_nested_if;
#  else
int bad_nested_else;
#  endif
#elif 1
int good_after_nested;
#endif

// #ifdef / #ifndef / defined()
#define FOO
#ifdef FOO
int good_ifdef;
#endif
#ifndef FOO
int bad_ifndef;
#endif
#if defined(FOO) && !defined(BAR)
int good_defined;
#endif

// Unknown macros evaluate to 0; dividing by them must not abort the file
#if UNKNOWN_MACRO / UNKNOWN_MACRO
int bad_div;
#else
int good_div;
#endif

int good_end_of_file;
