# Makefile for competitive programming algorithms
# Usage:
#   make                 # debug build (default)
#   make BUILD=opt       # optimized build (-O3)
#   make clean

CXX      = g++
CXXFLAGS = -std=c++23
LDFLAGS  =

# Algo include directory (adjust if needed)
ALGO_MISC_DIR = /home/ishraq/competitive-programming/lib/algo/misc

# Source files (all .cpp in current directory)
SOURCES = $(wildcard *.cpp)
TARGETS = $(SOURCES:.cpp=)

# ------------------------------------------------------------------
# Debug configuration  (matches plugin's DEBUG mode)
# ------------------------------------------------------------------
DEBUG_CXXFLAGS = -O2 -g -Wall -Wextra -pedantic -Wshadow -Wformat=2 \
                 -Wfloat-equal -Wconversion -Wlogical-op -Wshift-overflow=2 \
                 -Wduplicated-cond -Wcast-qual -Wcast-align \
                 -fsanitize=address -fsanitize=undefined -fno-sanitize-recover \
                 -fstack-protector -D_GLIBCXX_DEBUG -D_GLIBCXX_DEBUG_PEDANTIC \
                 -D_FORTIFY_SOURCE=2 -DDEBUG
DEBUG_LDFLAGS  = -fsanitize=address -fsanitize=undefined -fno-sanitize-recover

# ------------------------------------------------------------------
# Optimized configuration (matches plugin's OPTIMIZED mode)
# ------------------------------------------------------------------
OPT_CXXFLAGS = -O3

# ------------------------------------------------------------------
# Build type selection
# ------------------------------------------------------------------
ifeq ($(BUILD),opt)
    CXXFLAGS += $(OPT_CXXFLAGS)
else
    CXXFLAGS += $(DEBUG_CXXFLAGS)
    LDFLAGS  += $(DEBUG_LDFLAGS)
endif

# Add the algo include directory
CXXFLAGS += -I$(ALGO_MISC_DIR)

# ------------------------------------------------------------------
# Targets
# ------------------------------------------------------------------
.PHONY: all clean

all: $(TARGETS)

%: %.cpp
	$(CXX) $(CXXFLAGS) $< -o $@ $(LDFLAGS)

clean:
	rm -f $(TARGETS)
