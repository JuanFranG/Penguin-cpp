Penguin cpp: a native C++ project with a header and two source files.
Open Tutorial.dev, choose your native compiler configuration and use F11.
Expected output: Result: 5

The header declares add(); calculator.cpp defines it; main.cpp calls it.
Both .cpp files must be compiled and linked. The header is not compiled alone.
To debug, select Debug, rebuild and put a breakpoint inside add().

Independent build on macOS or Linux:
  c++ -std=c++17 -Wall -Wextra -g -O0 main.cpp calculator.cpp -o Tutorial
  ./Tutorial

Use a compiler configuration available on your own computer. Never add
calculator.cpp with #include: include calculator.h and compile both sources.
