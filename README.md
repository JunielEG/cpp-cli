# cppx — C++ Project Scaffolding CLI

`cppx` is a command-line tool that generates C++ project boilerplate in one command. Instead of manually creating folders, writing `CMakeLists.txt`, and setting up `main.cpp` every time, `cppx` handles it instantly from any terminal.

---

## Requirements

- **CMake** — [cmake.org/download](https://cmake.org/download/)
- **C++ compiler** — [MSVC](https://visualstudio.microsoft.com/), [MinGW (g++)](https://www.mingw-w64.org/), or [Clang](https://clang.llvm.org/)

`cppx` will auto-detect which compiler is available at build time.

---

## Installation

> [!NOTE]
> You only need the install script — cloning the repository is just the easiest way to get it.

**1. Clone the repository:**
```bash
git clone https://github.com/JunielEG/cpp-cli.git
cd cpp-cli
```

**2. Run the install script for your platform:**

**Windows** — run `Install.bat` as Administrator:
```bat
Install.bat
```

**Linux / macOS** — run `install.sh`:
```bash
chmod +x install.sh
./install.sh
```

Both scripts will:
- Copy the tool files to `~/ScaffoldingTools/cpp-cli/`
- Add `cppx` to your PATH

On Unix, the PATH entry is added to the first profile file found: `.zshrc`, `.bashrc`, `.bash_profile`, or `.profile`.

**3. Open a new terminal** and verify:
```bash
cppx
```

---

## Commands

| Command | Description |
|---|---|
| `cppx new project <name>/<arch>` | Creates a new C++ project with the specified architecture |
| `cppx new class <name>` | Adds a `.h`/`.cpp` pair to the current project |
| `cppx new module <name>` | Adds a module with its own subdirectory inside `src/` and `include/` |
| `cppx build` | Configures and compiles the project using CMake |
| `cppx run` | Builds and runs the compiled executable |
| `cppx dist` | Builds in Release mode and packages the `.exe` + DLLs into `dist/<project>/` |
| `cppx git` | Creates an repository with a generic `.gitignore` and a simple `README.md` |
| `cppx credit` | Shows the tool's name and the repo to get it [C++ Scaffolding Tool](https://github.com/JunielEG/cpp-cli.git) |

---

## Architectures

Every project requires an architecture. Run `cppx new project` without arguments to see the full list. Available architectures:

| Name | Description | Structure |
|---|---|---|
| `small` | src / include | Minimal layout for small projects |
| `mvc` | Model - View - Controller | Separates data, presentation, and logic |
| `features` | Feature-based | One folder per feature, self-contained |
| `layered` | Por capas | Horizontal layers (presentation, domain, data) |
| `cleanarc` | Clean Architecture | Entities, use cases, interfaces, infrastructure |

---

## What each command generates

### `cppx new project <name>/<arch>`

Creates a new folder named `<name>` with the folder structure defined by the chosen architecture.

```bash
cppx new project myapp/mvc
```

```
myapp/
├── src/
│   ├── model/
│   ├── view/
│   ├── controller/
│   └── main.cpp
├── build/
├── CMakeLists.txt
└── .cppx
```

- `main.cpp` includes a ready-to-compile entry point.
- `CMakeLists.txt` is pre-configured with C++17, `file(GLOB_RECURSE)` over `src/`, and includes for both `include/` and `src/`.
- `.cppx` stores project metadata (name and architecture). It is used by other commands to stay consistent with the project layout.

### `cppx new class <name>`

Adds a `.h`/`.cpp` pair to an existing project. Must be run from the project root.

```
include/<name>.h
src/<name>.cpp
```

Supports namespace paths using `/` as separator:

```bash
cppx new class engine/Renderer
# generates: include/engine/Renderer.h
#            src/engine/Renderer.cpp
# namespace:  engine
```

If the project has an architecture defined in `.cppx`, cppx will remind you to verify that the target subdirectory matches the architecture conventions.

### `cppx new module <name>`

Similar to `new class`, but creates a dedicated subdirectory for the module:

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
└── *.dll
```

---

## Quick start

```bash
cppx new project myapp/small

cppx new class Game

cppx run
```

---

## Installed file location

| Platform | Path |
|---|---|
| Windows | `%USERPROFILE%\ScaffoldingTools\cpp-cli\` |
| Linux / macOS | `~/ScaffoldingTools/cpp-cli/` |