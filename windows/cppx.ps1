
param(
    [string]$cmd1,
    [string]$cmd2,
    [string]$name
)

# -------------------------
# CONFIG
# -------------------------
$TEMPLATES = Join-Path $PSScriptRoot "templates"

# -------------------------
# HELP DATA 
# -------------------------
$COMMANDS = @(
    [PSCustomObject]@{ Group = "Scaffold"; Cmd = "cppx new project <name>"; Desc = "Crea proyecto con src/, include/, build/ y CMakeLists.txt" },
    [PSCustomObject]@{ Group = "Scaffold"; Cmd = "cppx new class <name>";   Desc = "Agrega par .h/.cpp (soporta namespaces: engine/Renderer)" },
    [PSCustomObject]@{ Group = "Scaffold"; Cmd = "cppx new module <name>";  Desc = "Agrega módulo con su propio subdirectorio" },
    [PSCustomObject]@{ Group = "Build";    Cmd = "cppx build";              Desc = "Configura y compila con CMake" },
    [PSCustomObject]@{ Group = "Build";    Cmd = "cppx run";                Desc = "Compila y ejecuta el binario resultante" },
    [PSCustomObject]@{ Group = "Build";    Cmd = "cppx dist";               Desc = "Build Release + empaca .exe y DLLs en dist/<proyecto>/" }
)

# -------------------------
# UTILS
# -------------------------
function Show-Help {
    $groups = $COMMANDS | Select-Object -ExpandProperty Group -Unique
    foreach ($g in $groups) {
        Write-Host "`n  $g" -ForegroundColor DarkGray
        $COMMANDS | Where-Object { $_.Group -eq $g } | ForEach-Object {
            Write-Host ("  {0,-30}" -f $_.Cmd) -ForegroundColor Cyan -NoNewline
            Write-Host $_.Desc -ForegroundColor Gray
        }
    }
    Write-Host ""
}

function Test-Name {
    param([string]$n)
    if (-not $n) { return $false }
    if ($n -notmatch '^[A-Za-z_][A-Za-z0-9_/]*$') {
        Write-Host "Nombre inválido." -ForegroundColor Red
        return $false
    }
    return $true
}

function Request-Name {
    while (-not (Test-Name $name)) {
        $script:name = Read-Host "Name"
    }
}

function Split-Path-Name {
    $parts = $name -split "/"
    $class = $parts[-1]
    if ($parts.Length -gt 1) {
        $ns = ($parts[0..($parts.Length - 2)] -join "::")
    }
    else {
        $ns = ""
    }
    return @{ class = $class; namespace = $ns }
}

function Test-CMake {
    if (-not (Test-Path "CMakeLists.txt")) {
        Write-Host "No CMakeLists.txt" -ForegroundColor Red
        return $false
    }
    return $true
}

function Get-Template {
    param($file, $replacements)

    $path = Join-Path $TEMPLATES $file
    if (-not (Test-Path $path)) {
        Write-Host "Template no encontrado: $file" -ForegroundColor Red
        return ""
    }

    $content = Get-Content $path -Raw
    foreach ($key in $replacements.Keys) {
        $content = $content -replace "{{${key}}}", $replacements[$key]
    }
    return $content
}

function Find-Compiler {
    if (Get-Command cl -ErrorAction SilentlyContinue) { return "MSVC" }
    if (Get-Command g++ -ErrorAction SilentlyContinue) { return "GCC" }
    if (Get-Command clang++ -ErrorAction SilentlyContinue) { return "CLANG" }
    return "UNKNOWN"
}

# -------------------------
# COMMANDS
# -------------------------
function New-Class {
    Request-Name

    $info = Split-Path-Name
    $class = $info.class
    $ns = $info.namespace

    if ($ns) {
        $nsOpen = "namespace $ns {"
        $nsClose = "} // namespace $ns"
    }
    else {
        $nsOpen = ""
        $nsClose = ""
    }

    if ($ns) {
        $dir = ($name -replace "/$class$", "")
    }
    else {
        $dir = ""
    }

    $includeDir = if ($dir) { "include/$dir" } else { "include" }
    $srcDir = if ($dir) { "src/$dir" }     else { "src" }

    New-Item -ItemType Directory -Force -Path $includeDir | Out-Null
    New-Item -ItemType Directory -Force -Path $srcDir | Out-Null

    $includePath = if ($dir) { "$dir/$class" } else { $class }

    $repl = @{
        NAME            = $class
        INCLUDE_PATH    = $includePath
        NAMESPACE       = $ns
        NAMESPACE_OPEN  = $nsOpen
        NAMESPACE_CLOSE = $nsClose
    }

    $header = Get-Template "class.h.tpl" $repl
    $source = Get-Template "class.cpp.tpl" $repl

    Set-Content "$includeDir/$class.h" $header
    Set-Content "$srcDir/$class.cpp" $source

    $cmakePath = if ($dir) { "src/$dir/$class.cpp" } else { "src/$class.cpp" }

    Write-Host "Clase $name creada." -ForegroundColor Green
}

function New-Module {
    Request-Name

    $info = Split-Path-Name
    $class = $info.class
    $ns = ($name -replace "/", "::")

    if ($ns -and $ns -ne $class) {
        $nsOpen = "namespace $ns {"
        $nsClose = "} // namespace $ns"
    }
    else {
        $ns = ""
        $nsOpen = ""
        $nsClose = ""
    }

    $includeDir = "include/$name"
    $srcDir = "src/$name"

    New-Item -ItemType Directory -Force -Path $includeDir | Out-Null
    New-Item -ItemType Directory -Force -Path $srcDir | Out-Null

    $includePath = $name  # ejemplo: program/test

    $repl = @{
        NAME            = $class
        INCLUDE_PATH    = "$includePath/$class"
        NAMESPACE       = $ns
        NAMESPACE_OPEN  = $nsOpen
        NAMESPACE_CLOSE = $nsClose
    }

    $header = Get-Template "module.h.tpl" $repl
    $source = Get-Template "module.cpp.tpl" $repl

    Set-Content "$includeDir/$class.h" $header
    Set-Content "$srcDir/$class.cpp" $source

    Write-Host "Módulo $name creado." -ForegroundColor Green
}

function New-Project {
    Request-Name

    New-Item -ItemType Directory -Path $name | Out-Null
    Set-Location $name

    mkdir src, include, build | Out-Null

    $main = Get-Template "main.cpp.tpl" @{ NAME = $name }
    Set-Content "src/main.cpp" $main

    $cmake = Get-Template "CMakeLists.txt.tpl" @{ NAME = $name }
    Set-Content "CMakeLists.txt" $cmake

    Write-Host "Proyecto $name creado." -ForegroundColor Green
    code . 2>$null
}

function Build {
    $compiler = Find-Compiler
    if ($compiler -eq "UNKNOWN") {
        Write-Host "No se encontró ningún compilador (cl, g++, clang++)." -ForegroundColor Red
        return $false
    }

    if (-not (Get-Command cmake -ErrorAction SilentlyContinue)) {
        Write-Host "cmake no está instalado o no está en el PATH." -ForegroundColor Red
        return $false
    }

    Write-Host "Compilador: $compiler"
    cmake -S . -B build
    cmake --build build --config Debug
    return $true
}

function Run {
    if (-not (Build)) { return }

    $cmakeContent = Get-Content "CMakeLists.txt" -Raw
    if ($cmakeContent -match 'project\((\w+)') {
        $projectName = $Matches[1]
    } else {
        Write-Host "No se pudo leer el nombre del proyecto desde CMakeLists.txt." -ForegroundColor Red
        return
    }

    $searchPaths = @(
        "build/Debug/$projectName.exe",   # MSVC
        "build/$projectName.exe",         # GCC / Clang (Unix Makefiles)
        "build/Debug/$projectName",       # GCC en Linux/Mac (sin extensión)
        "build/$projectName"
    )

    $exe = $searchPaths | Where-Object { Test-Path $_ } | Select-Object -First 1

    if ($exe) {
        Write-Host "`nRunning: $(Split-Path $exe -Leaf)`n" -ForegroundColor Green
        & (Resolve-Path $exe)
        Write-Host "`n`t---   End   ---`n" -ForegroundColor DarkGray
    } else {
        Write-Host "No se encontró el ejecutable '$projectName'." -ForegroundColor Red
        Write-Host "Rutas buscadas:" -ForegroundColor DarkGray
        $searchPaths | ForEach-Object { Write-Host "  - $_" -ForegroundColor DarkGray }
    }
}

function Dist {
    if (-not (Test-CMake)) { return }

    $projectName = (Get-Content "CMakeLists.txt" -Raw) -match 'project\((\w+)\)' | Out-Null
    $projectName = $Matches[1]

    Write-Host "Compilando en modo Release..." -ForegroundColor Cyan
    cmake -S . -B build/release -DCMAKE_BUILD_TYPE=Release
    cmake --build build/release --config Release

    $exe = Get-ChildItem "build/release" -Filter "*.exe" -Recurse | Select-Object -First 1
    if (-not $exe) {
        Write-Host "No se encontró .exe tras compilar." -ForegroundColor Red
        return
    }

    $distDir = "dist/$projectName"
    New-Item -ItemType Directory -Force -Path $distDir | Out-Null

    Copy-Item $exe.FullName "$distDir/$($exe.Name)" -Force

    $dllSource = $exe.DirectoryName
    Get-ChildItem $dllSource -Filter "*.dll" | ForEach-Object {
        Copy-Item $_.FullName "$distDir/$($_.Name)" -Force
        Write-Host "  + $($_.Name)" -ForegroundColor DarkGray
    }

    Write-Host ""
    Write-Host "Distribuible generado en: $distDir" -ForegroundColor Green
    Write-Host "Ejecutable: $($exe.Name)"
}

# -------------------------
# AUTOCOMPLETE
# -------------------------
Register-ArgumentCompleter -CommandName cpp.ps1 -ScriptBlock {
    param($wordToComplete, $commandAst)
    "new", "build", "run" | Where-Object { $_ -like "$wordToComplete*" }
}

# -------------------------
# ROUTER
# -------------------------
switch ($cmd1) {
    "new" {
        switch ($cmd2) {
            "class"   { New-Class }
            "module"  { New-Module }
            "project" { New-Project }
            default   { Show-Help }
        }
    }
    "build"   { Build }
    "run"     { Run }
    "dist"    { Dist }
    default   { Show-Help }
}