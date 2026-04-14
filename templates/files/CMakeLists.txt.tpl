cmake_minimum_required(VERSION 3.16)

project({{NAME}} VERSION 1.0)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# -------------------------
# Sources
# -------------------------
file(GLOB_RECURSE SOURCES CONFIGURE_DEPENDS
    src/*.cpp
)

# -------------------------
# Executable
# -------------------------
add_executable(${PROJECT_NAME} ${SOURCES})

# -------------------------
# Includes
# -------------------------
target_include_directories(${PROJECT_NAME}
    PUBLIC include
    PRIVATE src
)