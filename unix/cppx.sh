#!/usr/bin/env bash
# cppx.sh — C++ project scaffold tool (Bash port of cppx.ps1)

#//TODO: hay que cambiar todo para que tenga las novedades implementadas en el .bat, pedir a una IA y despues resolver bugs 6hrs
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATES="$SCRIPT_DIR/templates"

cmd1="${1:-}"
cmd2="${2:-}"
name="${3:-}"

# -------------------------
# HELP
# -------------------------
show_help() {
    echo ""
    echo "  Scaffold"
    printf "  %-38s %s\n" "cppx new project <name>" "Crea proyecto con src/, include/, build/ y CMakeLists.txt"
    printf "  %-38s %s\n" "cppx new class <name>"   "Agrega par .h/.cpp (soporta namespaces: engine/Renderer)"
    printf "  %-38s %s\n" "cppx new module <name>"  "Agrega módulo con su propio subdirectorio"
    echo ""
    echo "  Build"
    printf "  %-38s %s\n" "cppx build" "Configura y compila con CMake"
    printf "  %-38s %s\n" "cppx run"   "Compila y ejecuta el binario resultante"
    printf "  %-38s %s\n" "cppx dist"  "Build Release + empaca binario y libs en dist/<proyecto>/"
    echo ""
}

# -------------------------
# UTILS
# -------------------------
test_name() {
    local n="$1"
    [[ -n "$n" ]] && [[ "$n" =~ ^[A-Za-z_][A-Za-z0-9_/]*$ ]]
}

request_name() {
    while ! test_name "$name"; do
        read -rp "Name: " name
    done
}

split_path_name() {
    IFS='/' read -ra parts <<< "$name"
    CLASS="${parts[-1]}"
    if (( ${#parts[@]} > 1 )); then
        NAMESPACE=$(IFS='::'; echo "${parts[*]:0:${#parts[@]}-1}")
    else
        NAMESPACE=""
    fi
}

test_cmake() {
    if [[ ! -f "CMakeLists.txt" ]]; then
        echo "No CMakeLists.txt" >&2
        return 1
    fi
}

add_to_cmake() {
    local file="$1"
    if ! grep -qF "$file" CMakeLists.txt; then
        sed -i "s|set(SOURCES|set(SOURCES\n    $file|" CMakeLists.txt
    fi
}

get_template() {
    local file="$1"
    local path="$TEMPLATES/$file"
    if [[ ! -f "$path" ]]; then
        echo "Template no encontrado: $file" >&2
        echo ""
        return
    fi
    cat "$path"
}

# apply_template <template_file> [KEY=VALUE ...]
apply_template() {
    local file="$1"; shift
    local content
    content=$(get_template "$file")
    for pair in "$@"; do
        local key="${pair%%=*}"
        local val="${pair#*=}"
        # Escape special chars in val for sed
        val_escaped=$(printf '%s\n' "$val" | sed 's/[&/\]/\\&/g; s/$/\\n/' | tr -d '\n' | sed 's/\\n$//')
        content=$(echo "$content" | sed "s/{{${key}}}/${val_escaped}/g")
    done
    echo "$content"
}

find_compiler() {
    if command -v g++ &>/dev/null;     then echo "GCC";   return; fi
    if command -v clang++ &>/dev/null; then echo "CLANG"; return; fi
    echo "UNKNOWN"
}

# -------------------------
# COMMANDS
# -------------------------
new_class() {
    request_name
    split_path_name  # sets $CLASS, $NAMESPACE

    local ns_open="" ns_close=""
    if [[ -n "$NAMESPACE" ]]; then
        ns_open="namespace $NAMESPACE {"
        ns_close="} // namespace $NAMESPACE"
    fi

    local dir=""
    if [[ -n "$NAMESPACE" ]]; then
        dir="${name%/$CLASS}"
    fi

    local include_dir="include${dir:+/$dir}"
    local src_dir="src${dir:+/$dir}"

    mkdir -p "$include_dir" "$src_dir"

    apply_template "class.h.tpl" \
        "NAME=$CLASS" \
        "NAMESPACE=$NAMESPACE" \
        "NAMESPACE_OPEN=$ns_open" \
        "NAMESPACE_CLOSE=$ns_close" \
        > "$include_dir/$CLASS.h"

    apply_template "class.cpp.tpl" \
        "NAME=$CLASS" \
        "NAMESPACE=$NAMESPACE" \
        "NAMESPACE_OPEN=$ns_open" \
        "NAMESPACE_CLOSE=$ns_close" \
        > "$src_dir/$CLASS.cpp"

    local cmake_path="src${dir:+/$dir}/$CLASS.cpp"
    add_to_cmake "$cmake_path"

    echo "Clase $name creada."
}

new_module() {
    request_name
    split_path_name  # sets $CLASS, $NAMESPACE

    local ns="${name//\//::}"
    local ns_open="" ns_close=""
    if [[ -n "$ns" && "$ns" != "$CLASS" ]]; then
        ns_open="namespace $ns {"
        ns_close="} // namespace $ns"
    else
        ns=""
    fi

    local include_dir="include/$name"
    local src_dir="src/$name"

    mkdir -p "$include_dir" "$src_dir"

    apply_template "module.h.tpl" \
        "NAME=$CLASS" \
        "NAMESPACE=$ns" \
        "NAMESPACE_OPEN=$ns_open" \
        "NAMESPACE_CLOSE=$ns_close" \
        > "$include_dir/$CLASS.h"

    apply_template "module.cpp.tpl" \
        "NAME=$CLASS" \
        "NAMESPACE=$ns" \
        "NAMESPACE_OPEN=$ns_open" \
        "NAMESPACE_CLOSE=$ns_close" \
        > "$src_dir/$CLASS.cpp"

    add_to_cmake "src/$name/$CLASS.cpp"

    echo "Módulo $name creado."
}

new_project() {
    request_name

    mkdir -p "$name"/{src,include,build}
    cd "$name" || return

    apply_template "main.cpp.tpl" "NAME=$name" > "src/main.cpp"
    apply_template "CMakeLists.txt.tpl" "NAME=$name" > "CMakeLists.txt"

    echo "Proyecto $name creado."
    code . 2>/dev/null || true
}

cmd_build() {
    local compiler
    compiler=$(find_compiler)
    echo "Compilador: $compiler"

    cmake -S . -B build
    cmake --build build
}

cmd_run() {
    cmd_build
    local exe
    exe=$(find build -maxdepth 3 -type f -executable ! -name "*.so" | head -n1)
    if [[ -n "$exe" ]]; then
        "$exe"
    else
        echo "No se encontró ejecutable." >&2
        exit 1
    fi
}

cmd_dist() {
    test_cmake

    local project_name
    project_name=$(grep -oP '(?<=project\()[\w]+' CMakeLists.txt | head -n1)

    echo "Compilando en modo Release..."
    cmake -S . -B build/release -DCMAKE_BUILD_TYPE=Release
    cmake --build build/release --config Release

    local exe
    exe=$(find build/release -maxdepth 3 -type f -executable ! -name "*.so" | head -n1)
    if [[ -z "$exe" ]]; then
        echo "No se encontró ejecutable tras compilar." >&2
        exit 1
    fi

    local dist_dir="dist/$project_name"
    mkdir -p "$dist_dir"

    cp "$exe" "$dist_dir/"

    # Copy shared libs (.so) from the same directory
    local exe_dir
    exe_dir="$(dirname "$exe")"
    find "$exe_dir" -maxdepth 1 -name "*.so*" | while read -r lib; do
        cp "$lib" "$dist_dir/"
        echo "  + $(basename "$lib")"
    done

    echo ""
    echo "Distribuible generado en: $dist_dir"
    echo "Ejecutable: $(basename "$exe")"
}

# -------------------------
# ROUTER
# -------------------------
case "$cmd1" in
    new)
        case "$cmd2" in
            class)   new_class   ;;
            module)  new_module  ;;
            project) new_project ;;
            *)       show_help   ;;
        esac
        ;;
    build) cmd_build ;;
    run)   cmd_run   ;;
    dist)  cmd_dist  ;;
    *)     show_help ;;
esac