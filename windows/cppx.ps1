param(
    [string]$cmd1,
    [string]$cmd2,
    [string]$name
)

$TEMPLATES = Join-Path $PSScriptRoot "templates"

$COMMANDS = @(
    [PSCustomObject]@{ Group = "scaffold"; Cmd = "cppx new project <name>"; Desc = "crea proyecto con src/, include/, build/ y CMakeLists.txt" },
    [PSCustomObject]@{ Group = "scaffold"; Cmd = "cppx new class <name>";   Desc = "agrega par .h/.cpp (soporta namespaces: engine/Renderer)" },
    [PSCustomObject]@{ Group = "scaffold"; Cmd = "cppx new module <name>";  Desc = "agrega módulo con su propio subdirectorio" },
    [PSCustomObject]@{ Group = "build";    Cmd = "cppx build";              Desc = "configura y compila con CMake" },
    [PSCustomObject]@{ Group = "build";    Cmd = "cppx run";                Desc = "compila y ejecuta el binario resultante" },
    [PSCustomObject]@{ Group = "build";    Cmd = "cppx dist";               Desc = "release build + empaca .exe y DLLs en dist/<proyecto>/" }
)

# -- UI helpers ---------------------------------------------------------------

function Write-Header([string]$title) {
    Write-Host ""
    Write-Host "  $title" -ForegroundColor Cyan
    Write-Host "  $('-' * 40)" -ForegroundColor DarkGray
    Write-Host ""
}

function Write-Row([string]$label, [string]$msg, [string]$status = "ok") {
    $icon  = switch ($status) { "ok" { "+" } "warn" { "!" } "skip" { "-" } "none" { "." } default { " " } }
    $color = switch ($status) { "ok" { "Green" } "warn" { "Yellow" } default { "DarkGray" } }
    Write-Host ("  {0,-10}" -f $label) -ForegroundColor DarkGray -NoNewline
    Write-Host "$icon  " -ForegroundColor $color -NoNewline
    Write-Host $msg -ForegroundColor Gray
}

function Write-Fail([string]$msg) {
    Write-Host ""
    Write-Host "  error  $msg" -ForegroundColor Red
    Write-Host ""
}

# -- Helpers ------------------------------------------------------------------

function Show-Help {
    Write-Header "cppx"
    $groups = $COMMANDS | Select-Object -ExpandProperty Group -Unique
    foreach ($g in $groups) {
        Write-Host "  $g" -ForegroundColor DarkGray
        $COMMANDS | Where-Object { $_.Group -eq $g } | ForEach-Object {
            Write-Host ("  {0,-28}" -f $_.Cmd) -ForegroundColor Cyan -NoNewline
            Write-Host $_.Desc -ForegroundColor DarkGray
        }
        Write-Host ""
    }
}

function Test-Name([string]$n) {
    if (-not $n) { return $false }
    if ($n -notmatch '^[A-Za-z_][A-Za-z0-9_/]*$') {
        Write-Fail "nombre inválido: '$n'"
        return $false
    }
    return $true
}

function Request-Name {
    while (-not (Test-Name $name)) {
        $script:name = Read-Host "  name"
    }
}

function Split-Path-Name {
    $parts = $name -split "/"
    $class = $parts[-1]
    $ns    = if ($parts.Length -gt 1) { ($parts[0..($parts.Length - 2)] -join "::") } else { "" }
    return @{ class = $class; namespace = $ns }
}

function Test-CMake {
    if (-not (Test-Path "CMakeLists.txt")) {
        Write-Fail "CMakeLists.txt no encontrado"
        return $false
    }
    return $true
}

function Get-Template([string]$file, [hashtable]$replacements) {
    $path = Join-Path $TEMPLATES $file
    if (-not (Test-Path $path)) {
        Write-Fail "template no encontrado: $file"
        return ""
    }
    $content = Get-Content $path -Raw
    foreach ($key in $replacements.Keys) {
        $content = $content -replace "{{${key}}}", $replacements[$key]
    }
    return $content
}

function Find-Compiler {
    if (Get-Command cl     -ErrorAction SilentlyContinue) { return "MSVC"  }
    if (Get-Command g++    -ErrorAction SilentlyContinue) { return "GCC"   }
    if (Get-Command clang++ -ErrorAction SilentlyContinue) { return "CLANG" }
    return "UNKNOWN"
}

# -- Commands -----------------------------------------------------------------

function New-Class {
    Request-Name
    Write-Header "new class  ->  $name"

    $info = Split-Path-Name
    $class = $info.class
    $ns    = $info.namespace

    $nsOpen  = if ($ns) { "namespace $ns {" }    else { "" }
    $nsClose = if ($ns) { "} // namespace $ns" } else { "" }
    $dir     = if ($ns) { ($name -replace "/$class$", "") } else { "" }

    $includeDir = if ($dir) { "include/$dir" } else { "include" }
    $srcDir     = if ($dir) { "src/$dir" }     else { "src" }

    $null = New-Item -ItemType Directory -Force -Path $includeDir
    $null = New-Item -ItemType Directory -Force -Path $srcDir

    $includePath = if ($dir) { "$dir/$class" } else { $class }

    $repl = @{
        NAME            = $class
        INCLUDE_PATH    = $includePath
        NAMESPACE       = $ns
        NAMESPACE_OPEN  = $nsOpen
        NAMESPACE_CLOSE = $nsClose
    }

    Set-Content "$includeDir/$class.h"   (Get-Template "class.h.tpl"   $repl)
    Set-Content "$srcDir/$class.cpp"     (Get-Template "class.cpp.tpl" $repl)

    Write-Row "header"  "$includeDir/$class.h"
    Write-Row "source"  "$srcDir/$class.cpp"
    if ($ns) { Write-Row "namespace" $ns }
}

function New-Module {
    Request-Name
    Write-Header "new module  ->  $name"

    $info  = Split-Path-Name
    $class = $info.class
    $ns    = ($name -replace "/", "::")

    if ($ns -eq $class) { $ns = "" }
    $nsOpen  = if ($ns) { "namespace $ns {" }    else { "" }
    $nsClose = if ($ns) { "} // namespace $ns" } else { "" }

    $includeDir  = "include/$name"
    $srcDir      = "src/$name"

    $null = New-Item -ItemType Directory -Force -Path $includeDir
    $null = New-Item -ItemType Directory -Force -Path $srcDir

    $repl = @{
        NAME            = $class
        INCLUDE_PATH    = "$name/$class"
        NAMESPACE       = $ns
        NAMESPACE_OPEN  = $nsOpen
        NAMESPACE_CLOSE = $nsClose
    }

    Set-Content "$includeDir/$class.h"  (Get-Template "module.h.tpl"   $repl)
    Set-Content "$srcDir/$class.cpp"    (Get-Template "module.cpp.tpl" $repl)

    Write-Row "header"  "$includeDir/$class.h"
    Write-Row "source"  "$srcDir/$class.cpp"
    if ($ns) { Write-Row "namespace" $ns }
}

function New-Project {
    Request-Name
    Write-Header "new project  ->  $name"

    $null = New-Item -ItemType Directory -Path $name
    Set-Location $name
    $null = mkdir src, include, build

    Set-Content "src/main.cpp"    (Get-Template "main.cpp.tpl"       @{ NAME = $name })
    Set-Content "CMakeLists.txt"  (Get-Template "CMakeLists.txt.tpl" @{ NAME = $name })

    Write-Row "dirs"    "src/  include/  build/"
    Write-Row "cmake"   "CMakeLists.txt"
    Write-Row "entry"   "src/main.cpp"

    code . 2>$null
}

function Build {
    Write-Header "build"

    $compiler = Find-Compiler
    if ($compiler -eq "UNKNOWN") {
        Write-Fail "no se encontró ningún compilador (cl, g++, clang++)"
        return $false
    }
    if (-not (Get-Command cmake -ErrorAction SilentlyContinue)) {
        Write-Fail "cmake no está instalado o no está en el PATH"
        return $false
    }

    Write-Row "compiler" $compiler
    Write-Host ""

    cmake -S . -B build
    cmake --build build --config Debug

    Write-Host ""
    Write-Row "build" "debug  ->  build/" "ok"
    return $true
}

function Run {
    if (-not (Build)) { return }

    $cmakeContent = Get-Content "CMakeLists.txt" -Raw
    if ($cmakeContent -notmatch 'project\((\w+)') {
        Write-Fail "no se pudo leer el nombre del proyecto desde CMakeLists.txt"
        return
    }
    $projectName = $Matches[1]

    $searchPaths = @(
        "build/Debug/$projectName.exe",
        "build/$projectName.exe",
        "build/Debug/$projectName",
        "build/$projectName"
    )

    $exe = $searchPaths | Where-Object { Test-Path $_ } | Select-Object -First 1

    if (-not $exe) {
        Write-Fail "ejecutable '$projectName' no encontrado"
        Write-Host "  buscado en:" -ForegroundColor DarkGray
        $searchPaths | ForEach-Object { Write-Host "    $_" -ForegroundColor DarkGray }
        return
    }

    Write-Host ""
    Write-Host "  ----------------------------------------" -ForegroundColor DarkGray
    Write-Host "  $projectName" -ForegroundColor Green
    Write-Host "  ----------------------------------------" -ForegroundColor DarkGray
    Write-Host ""

    & (Resolve-Path $exe)

    Write-Host ""
    Write-Host "  ----------------------------------------" -ForegroundColor DarkGray
    Write-Host "  exit" -ForegroundColor DarkGray
    Write-Host ""
}

function Dist {
    if (-not (Test-CMake)) { return }
    Write-Header "dist"

    $cmakeContent = Get-Content "CMakeLists.txt" -Raw
    $null = $cmakeContent -match 'project\((\w+)\)'
    $projectName = $Matches[1]

    Write-Row "mode" "release"

    cmake -S . -B build/release -DCMAKE_BUILD_TYPE=Release
    cmake --build build/release --config Release

    $exe = Get-ChildItem "build/release" -Filter "*.exe" -Recurse | Select-Object -First 1
    if (-not $exe) {
        Write-Fail "no se encontró .exe tras compilar"
        return
    }

    $distDir = "dist/$projectName"
    $null = New-Item -ItemType Directory -Force -Path $distDir

    Copy-Item $exe.FullName "$distDir/$($exe.Name)" -Force
    Write-Row "exe" $exe.Name

    Get-ChildItem $exe.DirectoryName -Filter "*.dll" | ForEach-Object {
        Copy-Item $_.FullName "$distDir/$($_.Name)" -Force
        Write-Row "dll" $_.Name
    }
}

# -- Router -------------------------------------------------------------------

switch ($cmd1) {
    "new" {
        switch ($cmd2) {
            "class"   { New-Class }
            "module"  { New-Module }
            "project" { New-Project }
            default   { Show-Help }
        }
    }
    "build" { Build | Out-Null }
    "run"   { Run }
    "dist"  { Dist }
    default { Show-Help }
}