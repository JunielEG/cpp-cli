# cpp-cli

CLI scaffolding tool for C++ projects using CMake.
Generates classes, modules, and full project structures from templates.

## Requirements

- Windows (PowerShell 5+)
- CMake 3.10+
- One of: MSVC, GCC, or Clang on PATH

## Installation

1. Add the cpp-cli/ folder to your system PATH
2. Open a new terminal and run "cgen" to verify

## Commands

```
cgen new project <name>          Creates a new project with CMake setup
cgen new class <path/Name>       Generates a .h and .cpp for a class
cgen new module <path/Name>      Generates a module with an init() function
cgen build                        Compiles the project with CMake
cgen run                          Builds and runs the executable
cgen dist                         Builds in Release mode and packages the .exe
```

## Usage examples

```bash
cgen new project MyGame
cgen new class engine/Player     # creates include/engine/Player.h and src/engine/Player.cpp
cgen new module graphics/Render  # creates a module under namespace graphics::Render
cgen build
cgen run
cgen dist                        # outputs distributable to dist/MyGame/
```

Namespaces are derived from the path automatically.
engine/Player → namespace engine, class Player.
Omitting the path creates the file without a namespace.

## Project structure

```
MyProject/
├── CMakeLists.txt
├── include/
├── src/
├── build/
└── dist/          (generated only by "cgen dist")
```