// SPDX-License-Identifier: MIT
#include <bits/stdc++.h>
#include <conio.h>
int main() {
    std::vector<int> values{3, 1, 2};
    std::sort(values.begin(), values.end());
    if (values[0] != 1) {
        return 1;
    }
    std::cout << "READY " << kbhit() << std::endl;
    while (!kbhit()) {
        std::this_thread::sleep_for(std::chrono::milliseconds(1));
    }
    int key = _getch();
    std::cout << "KEY " << key << std::endl;
    return key == 'Q' ? 0 : 1;
}
