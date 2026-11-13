/* SPDX-License-Identifier: MIT
 * Convenience includes, not GCC's internal header or a libstdc++ replacement.
 * GNU extensions such as ext/pb_ds are not supplied. */
#pragma once
#if defined(__has_include_next) && __has_include_next(<bits/stdc++.h>)
#include_next <bits/stdc++.h>
#else
#include <algorithm>
#include <array>
#include <bitset>
#include <cassert>
#include <cctype>
#include <cerrno>
#include <chrono>
#include <cmath>
#include <complex>
#include <cstddef>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <deque>
#include <exception>
#include <fstream>
#include <functional>
#include <iomanip>
#include <iostream>
#include <iterator>
#include <limits>
#include <list>
#include <map>
#include <memory>
#include <mutex>
#include <numeric>
#include <queue>
#include <random>
#include <regex>
#include <set>
#include <sstream>
#include <stack>
#include <stdexcept>
#include <string>
#include <thread>
#include <tuple>
#include <type_traits>
#include <unordered_map>
#include <unordered_set>
#include <utility>
#include <vector>
#if __cplusplus >= 201703L
#include <filesystem>
#include <optional>
#include <string_view>
#include <variant>
#endif

#endif // use the toolchain header when available
