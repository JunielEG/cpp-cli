# cppx — C++ Project Scaffolding CLI

`cppx` is a Windows command-line tool that generates C++ project boilerplate in one command. Instead of manually creating folders, writing `CMakeLists.txt`, and setting up `main.cpp` every time, `cppx` handles it instantly from any terminal.

> [!IMPORTANT]
> `cppx` is **Windows only**. Linux and macOS are not supported.

---

## Requirements

Before installing, make sure you have the following tools available in your system:

- **CMake** — [cmake.org/download](https://cmake.org/download/)
- **C++ compiler** — either [MSVC (Visual Studio)](https://visualstudio.microsoft.com/) or [MinGW (g++)](https://www.mingw-w64.org/) or [Clang](https://clang.llvm.org/)

`cppx` will auto-detect which compiler is available at build time.

---

## Installation

> [!NOTE]
> You only need `Install.bat` — cloning the repository is just the easiest way to get it.

**1. Clone the repository:**
```bash
git clone https://github.com/JunielEG/cpp-cli.git
```

**2. Run `Install.bat` as Administrator.**

This script will:
- Copy the tool files to `%USERPROFILE%\ScaffoldingTools\cpp-cli\`
- Register `cppx` in your system PATH so it works from any terminal

**3. Open a new terminal window** (existing ones won't have the updated PATH yet) and verify:
```bash
cppx help
```

---

## Commands

| Command | Description |
|---|---|
| `cppx new project <name>` | Creates a new C++ project with full folder structure |
| `cppx new class <name>` | Adds a `.h`/`.cpp` pair to the current project |
| `cppx new module <name>` | Adds a module with its own subdirectory inside `src/` and `include/` |
| `cppx build` | Configures and compiles the project using CMake |
| `cppx run` | Builds and runs the compiled executable |
| `cppx dist` | Builds in Release mode and packages the `.exe` + DLLs into `dist/<project>/` |
| `cppx help` | Lists all available commands |

---

## What each command generates

### `cppx new project <name>`

Creates the following structure in a new folder:

```
<name>/
├── src/
│   └── main.cpp
├── include/
├── build/
└── CMakeLists.txt
```

- `main.cpp` includes a ready-to-compile entry point.
- `CMakeLists.txt` is pre-configured with C++17 and the project name.

### `cppx new class <name>`

Adds a `.h`/`.cpp` pair to an existing project. Must be run from the project root (where `CMakeLists.txt` is).

```
include/<name>.h
src/<name>.cpp
```

Supports namespace paths using `/` as separator:

```bash
cppx new class engine/Renderer
# generates: include/engine/Renderer.h
#            src/engine/Renderer.cpp
# namespace:  engine::Renderer
```

The new `.cpp` file is automatically added to the `SOURCES` list in `CMakeLists.txt`.

### `cppx new module <name>`

Similar to `new class`, but creates a dedicated subdirectory for the module under both `src/` and `include/`:

```bash
cppx new module audio/Mixer
# generates: include/audio/Mixer/Mixer.h
#            src/audio/Mixer/Mixer.cpp
```

Use this for self-contained components that deserve their own folder.

### `cppx dist`

Builds the project in Release mode and collects the output into a distributable folder:

```
dist/<project>/
├── <project>.exe
└── *.dll  (any DLLs found next to the executable)
```

---

## Quick start

```bash
# Create a new project
cppx new project myapp

# Move into the project folder
cd myapp

# Add a class
cppx new class Game

# Build and run
cppx run
```

---

## Installed file location

After running `Install.bat`, the tool files live at:

```
%USERPROFILE%\ScaffoldingTools\cpp-cli\
```

You don't need to interact with this folder directly.