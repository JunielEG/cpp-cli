param(
    [string]$cmd1,
    [string]$cmd2,
    [string]$name
)

$FILETEMPLATES = Join-Path $PSScriptRoot "templates/files"
$ARCHTEMPLATES = Join-Path $PSScriptRoot "templates/architectures"

$REPO_URL = "https://github.com/JunielEG/cpp-cli.git"

$COMMANDS = @(
    [PSCustomObject]@{ Group = "scaffold"; Cmd = "cppx new project <n>";        Desc = "crea proyecto con CMakeLists.txt" },
    [PSCustomObject]@{ Group = "scaffold"; Cmd = "cppx new project <n>/<arch>"; Desc = "crea proyecto con arquitectura (ej: mvc, small)" },
    [PSCustomObject]@{ Group = "scaffold"; Cmd = "cppx new class <n>";          Desc = "agrega par .h/.cpp (soporta namespaces: engine/Renderer)" },
    [PSCustomObject]@{ Group = "scaffold"; Cmd = "cppx new module <n>";         Desc = "agrega modulo con su propio subdirectorio" },
    [PSCustomObject]@{ Group = "build";    Cmd = "cppx build";                  Desc = "configura y compila con CMake" },
    [PSCustomObject]@{ Group = "build";    Cmd = "cppx run";                    Desc = "compila y ejecuta el binario resultante" },
    [PSCustomObject]@{ Group = "build";    Cmd = "cppx dist";                   Desc = "release build + empaca .exe y DLLs en dist/<proyecto>/" },
    [PSCustomObject]@{ Group = "other";    Cmd = "cppx git";                    Desc = "inicia repositorio git y genera .gitignore / README.md" },
    [PSCustomObject]@{ Group = "other";    Cmd = "cppx credit";                 Desc = "muestra la URL del repositorio de cppx" }
)

$KNOWN_FILES = @{
    "main.cpp"       = "main.cpp.tpl"
    "CMakeLists.txt" = "CMakeLists.txt.tpl"
    ".gitignore"     = ".gitignore.tpl"
    "README.md"      = "README.md.tpl"
}

$ARCHITECTURES = @(
    [PSCustomObject]@{ Name = "small";    Desc = "Estructura simple: headers en include, codigo en src." },
    [PSCustomObject]@{ Name = "mvc";      Desc = "Separa datos, interfaz y control de flujo." },
    [PSCustomObject]@{ Name = "features"; Desc = "Organiza por funcionalidad, cada modulo es autonomo." },
    [PSCustomObject]@{ Name = "layered";  Desc = "Divide en capas: UI, logica, dominio, infraestructura." },
    [PSCustomObject]@{ Name = "cleanarc"; Desc = "Capas desacopladas, dominio independiente del resto." }
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

# -- Guides ------------------------------------------------------------------

function Show-Help {
    Write-Header "cppx"
    $groups = $COMMANDS | Select-Object -ExpandProperty Group -Unique
    foreach ($g in $groups) {
        Write-Host "  $g" -ForegroundColor DarkGray
        $COMMANDS | Where-Object { $_.Group -eq $g } | ForEach-Object {
            Write-Host ("  {0,-36}" -f $_.Cmd) -ForegroundColor Cyan -NoNewline
            Write-Host $_.Desc -ForegroundColor DarkGray
        }
        Write-Host ""
    }
}

function Show-Architectures {
    Write-Host ""
    Write-Host "  arquitecturas disponibles" -ForegroundColor Cyan
    Write-Host "  $('-' * 40)" -ForegroundColor DarkGray
    Write-Host ""
    $ARCHITECTURES | ForEach-Object {
        Write-Host ("  {0,-12}" -f $_.Name) -ForegroundColor Cyan -NoNewline
        Write-Host $_.Desc -ForegroundColor DarkGray
    }
    Write-Host ""
    Write-Host "  uso: cppx new project <nombre>/<arch>" -ForegroundColor Yellow
    Write-Host ""
}

# -- Helpers ------------------------------------------------------------------

function Test-Name([string]$n) {
    if (-not $n) { return $false }
    if ($n -notmatch '^[A-Za-z_][A-Za-z0-9_/]*$') {
        Write-Fail "nombre invalido: '$n'"
        return $false
    }
    return $true
}

function Request-Name {
    while (-not (Test-Name $name)) {
        $script:name = Read-Host "  name"
    }
}

function Split-SlashPair([string]$raw) {
    $parts = $raw -split "/"
    $leaf  = $parts[-1]
    $head  = if ($parts.Length -gt 1) { $parts[0..($parts.Length - 2)] } else { @() }
    return @{
        # para class / module: ultimo segmento es la clase, los anteriores forman el namespace (::)
        class     = $leaf
        namespace = ($head -join "::")
        # para project: primer segmento es el nombre, segundo (si existe) es la arch
        project   = $parts[0]
        arch      = if ($parts.Length -eq 2) { $parts[1] } else { "" }
        # acceso generico
        head      = ($head -join "/")
        leaf      = $leaf
    }
}

function Test-CMake {
    if (-not (Test-Path "CMakeLists.txt")) {
        Write-Fail "CMakeLists.txt no encontrado"
        return $false
    }
    return $true
}

function Get-Template([string]$file, [hashtable]$replacements) {
    $path = Join-Path $FILETEMPLATES $file
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
    if (Get-Command cl      -ErrorAction SilentlyContinue) { return "MSVC"  }
    if (Get-Command g++     -ErrorAction SilentlyContinue) { return "GCC"   }
    if (Get-Command clang++ -ErrorAction SilentlyContinue) { return "CLANG" }
    return "UNKNOWN"
}

# -- YAML parser --------------------------------------------------------------
# Soporta el subset usado en los archivos de arquitectura:
#   - Listas con "- key:" (nodos directorio)
#   - Listas con "- file.ext" (nodos archivo conocido)
#   - Indentacion con espacios (2 o 4 por nivel)
# Devuelve un arbol de objetos @{ name; type; children }

function Parse-ArchYaml([string]$yamlPath) {
    if (-not (Test-Path $yamlPath)) {
        Write-Fail "arquitectura no encontrada: $yamlPath"
        return $null
    }

    $lines = Get-Content $yamlPath
    $tokens = [System.Collections.Generic.List[hashtable]]::new()

    foreach ($line in $lines) {
        if ($line -match '^\s*$' -or $line -match '^\s*#') { continue }

        if ($line -notmatch '^(\s*)-\s+(.+)$') { continue }

        $indent  = $Matches[1].Length
        $content = $Matches[2].Trim()

        if ($content -match '^([A-Za-z0-9_./-]+):$') {
            $tokens.Add(@{ indent = $indent; name = $Matches[1]; isDir = $true })
        } elseif ($content -match '^([A-Za-z0-9_./-]+)$') {
            $tokens.Add(@{ indent = $indent; name = $content;    isDir = $false })
        }
    }

    $root     = @{ name = "root"; isDir = $true; children = [System.Collections.Generic.List[hashtable]]::new() }
    $stack    = [System.Collections.Generic.Stack[hashtable]]::new()
    $indStack = [System.Collections.Generic.Stack[int]]::new()

    $stack.Push($root)
    $indStack.Push(-1)

    foreach ($tok in $tokens) {
        while ($indStack.Count -gt 1 -and $tok.indent -le $indStack.Peek()) {
            $null = $stack.Pop()
            $null = $indStack.Pop()
        }

        $node = @{
            name     = $tok.name
            isDir    = $tok.isDir
            children = [System.Collections.Generic.List[hashtable]]::new()
        }

        $stack.Peek().children.Add($node)

        if ($tok.isDir) {
            $stack.Push($node)
            $indStack.Push($tok.indent)
        }
    }

    return $root
}

function Build-TreeFromYaml($node, [string]$basePath, [string]$projectName) {
    foreach ($child in $node.children) {
        $childPath = Join-Path $basePath $child.name

        if ($child.isDir) {
            $null = New-Item -ItemType Directory -Force -Path $childPath
            Write-Row "dir" $childPath.Replace((Get-Location).Path + "\", "")
            Build-TreeFromYaml $child $childPath $projectName
        } else {
            # Archivo conocido -> genera desde template
            if ($KNOWN_FILES.ContainsKey($child.name)) {
                $tplName = $KNOWN_FILES[$child.name]
                $content = Get-Template $tplName @{ NAME = $projectName }
                Set-Content $childPath $content
                Write-Row "file" $childPath.Replace((Get-Location).Path + "\", "")
            } else {
                # Archivo desconocido -> crea vacio con advertencia
                Set-Content $childPath ""
                Write-Row "file" $childPath.Replace((Get-Location).Path + "\", "") "warn"
            }
        }
    }
}

function Write-CppxMeta([string]$projectName, [string]$arch, [string]$repo = "") {
    $lines = @("NAME=$projectName", "ARCH=$arch")
    if ($repo) { $lines += "REPO=$repo" }
    Set-Content ".cppx" ($lines -join "`n")
    $summary = "NAME=$projectName, ARCH=$arch"
    if ($repo) { $summary += ", REPO=$repo" }
    Write-Row "meta" ".cppx  ($summary)"
}

function Read-CppxMeta {
    if (-not (Test-Path ".cppx")) { return @{} }
    $meta = @{}
    Get-Content ".cppx" | ForEach-Object {
        if ($_ -match '^([A-Z]+)=(.*)$') {
            $meta[$Matches[1]] = $Matches[2]
        }
    }
    return $meta
}

function Require-CppxMeta {
    $meta = Read-CppxMeta
    if ($meta.Count -eq 0) {
        Write-Fail ".cppx no encontrado - ejecuta 'cppx new project' primero"
        return $null
    }
    if (-not $meta["NAME"]) {
        Write-Fail ".cppx no tiene campo NAME"
        return $null
    }
    return $meta
}

# -- Commands -----------------------------------------------------------------

function New-Class {
    Request-Name
    Write-Header "new class  ->  $name"

    $info = Split-SlashPair $name
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

    $meta = Read-CppxMeta
    if ($meta.ContainsKey("ARCH") -and $meta["ARCH"]) {
        Write-Row "arch" "proyecto usa '$($meta["ARCH"])' - verifica que el subdirectorio sea correcto" "warn"
    }
}

function New-Module {
    Request-Name
    Write-Header "new module  ->  $name"

    $info  = Split-SlashPair $name
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

    $parsed      = Split-SlashPair $name
    $projectName = $parsed.project
    $archName    = $parsed.arch

    if ($projectName -notmatch '^[A-Za-z_][A-Za-z0-9_]*$') {
        Write-Fail "nombre de proyecto invalido: '$projectName'"
        return
    }
    
    if (Test-Path $projectName) {
        Write-Fail "el directorio '$projectName' ya existe"
        return
    }

    if (-not $archName) {
        Write-Fail "debes especificar una arquitectura"
        Show-Architectures
        return
    }
    $yamlPath = Join-Path $ARCHTEMPLATES "$archName.yaml"

    $tree = Parse-ArchYaml $yamlPath
    if (-not $tree) { return }

    $null = New-Item -ItemType Directory -Path $projectName -ErrorAction Stop
    Set-Location $projectName

    Write-Row "arch" "$archName  ($yamlPath)"
    Write-Host ""

    Build-TreeFromYaml $tree (Get-Location).Path $projectName

    Write-Host ""

    Write-CppxMeta $projectName $archName

    code . 2>$null
}

function Build {
    Write-Header "build"

    if (-not (Test-CMake)) { return $false }
    $meta = Require-CppxMeta
    if (-not $meta) { return $false }

    Write-Row "project" $meta["NAME"]

    $compiler = Find-Compiler
    if ($compiler -eq "UNKNOWN") {
        Write-Fail "no se encontro ningun compilador (cl g++ clang)"
        return $false
    }
    if (-not (Get-Command cmake -ErrorAction SilentlyContinue)) {
        Write-Fail "cmake no esta instalado o no esta en el PATH" 
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
    $meta = Require-CppxMeta
    if (-not $meta) { return }
    Write-Header "dist"

    $cmakeContent = Get-Content "CMakeLists.txt" -Raw
    if ($cmakeContent -match 'project\(\s*(\w+)') {
        $projectName = $Matches[1]
    } else {
        Write-Fail "no se pudo leer el nombre del proyecto en CMakeLists.txt"
        return
    }
    Write-Row "mode" "release"

    cmake -S . -B build/release -DCMAKE_BUILD_TYPE=Release
    cmake --build build/release --config Release

    $exe = Get-ChildItem "build/release" -Filter "*.exe" -Recurse | Where-Object { $_.Name -notlike "CompilerId*" } | Select-Object -First 1

    if (-not $exe) {
        Write-Fail "no se encontro .exe tras compilar"
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

function Show-Credit {
    Write-Host ""
    Write-Host "  cppx" -ForegroundColor Cyan -NoNewline
    Write-Host "  -  cpp project scaffold tool" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  repo  " -ForegroundColor DarkGray -NoNewline
    Write-Host $REPO_URL -ForegroundColor Cyan
    Write-Host ""
}

function Init-Git {
    Write-Header "git init"

    $meta = Require-CppxMeta
    if (-not $meta) { return }
    $projectName = $meta["NAME"]

    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        Write-Fail "git no esta instalado o no esta en el PATH"
        return
    }

    if (Test-Path ".git") {
        Write-Fail "ya existe un repositorio git en este directorio"
        return
    }

    git init | Out-Null
    Write-Row "git" "repositorio inicializado" "ok"

    $gitignoreContent = Get-Template ".gitignore.tpl" @{ NAME = $projectName }
    if ($gitignoreContent) {
        Set-Content ".gitignore" $gitignoreContent
        Write-Row "file" ".gitignore" "ok"
    }

    $readmeContent = Get-Template "README.md.tpl" @{ NAME = $projectName; ARCH = $meta["ARCH"] }
    if ($readmeContent) {
        Set-Content "README.md" $readmeContent
        Write-Row "file" "README.md" "ok"
    }

    Write-Host ""
    $repoUrl = Read-Host "  remote url (Enter para omitir)"
    $repoUrl = $repoUrl.Trim()

    if ($repoUrl) {
        git remote add origin $repoUrl 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Row "remote" $repoUrl "ok"
        } else {
            Write-Row "remote" "no se pudo agregar el remote" "warn"
            $repoUrl = ""
        }
    }

    $arch = if ($meta["ARCH"]) { $meta["ARCH"] } else { "" }
    Write-CppxMeta $projectName $arch $repoUrl

    Write-Host ""
    Write-Row "done" "listo - usa 'git add .' y 'git commit' para tu primer commit" "ok"
    Write-Host ""
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
    "build"  { Build | Out-Null }
    "run"    { Run }
    "dist"   { Dist }
    "git"    { Init-Git }
    "credit" { Show-Credit }
    default  { Show-Help }
}