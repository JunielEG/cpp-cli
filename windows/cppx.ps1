param(
    [string]$cmd1,
    [string]$cmd2,
    [string]$name
)

$FILETEMPLATES = Join-Path $PSScriptRoot "templates/files"
$ARCHTEMPLATES = Join-Path $PSScriptRoot "templates/architectures"

$REPO_URL = "https://github.com/JunielEG/cpp-cli.git"

$COMMANDS = @(
    [PSCustomObject]@{ Group = "scaffold"; Cmd = "cppx new project <n>"; Desc = "crea proyecto con CMakeLists.txt" },
    [PSCustomObject]@{ Group = "scaffold"; Cmd = "cppx new project <n>/<arch>"; Desc = "crea proyecto con arquitectura (ej: mvc, small)" },
    [PSCustomObject]@{ Group = "scaffold"; Cmd = "cppx new class <n>"; Desc = "agrega par .h/.cpp (soporta namespaces: engine/Renderer)" },
    [PSCustomObject]@{ Group = "scaffold"; Cmd = "cppx new module <n>"; Desc = "agrega modulo con su propio subdirectorio" },
    [PSCustomObject]@{ Group = "scaffold"; Cmd = "cppx new interface <n>"; Desc = "agrega solo .h para clases abstractas / interfaces puras" },
    [PSCustomObject]@{ Group = "scaffold"; Cmd = "cppx rename <old> <new>"; Desc = "renombra par .h/.cpp y actualiza #includes en el proyecto" },
    [PSCustomObject]@{ Group = "scaffold"; Cmd = "cppx list"; Desc = "lista clases y modulos registrados en cppx.json" },
    [PSCustomObject]@{ Group = "build"; Cmd = "cppx build"; Desc = "configura y compila con CMake" },
    [PSCustomObject]@{ Group = "build"; Cmd = "cppx run"; Desc = "compila y ejecuta el binario resultante" },
    [PSCustomObject]@{ Group = "build"; Cmd = "cppx dist"; Desc = "release build + empaca .exe y DLLs en dist/<proyecto>/" },
    [PSCustomObject]@{ Group = "build"; Cmd = "cppx build release"; Desc = "compila en modo release sin empaquetar" },
    [PSCustomObject]@{ Group = "build"; Cmd = "cppx clean"; Desc = "elimina directorios build/ y dist/" },
    [PSCustomObject]@{ Group = "other"; Cmd = "cppx git"; Desc = "inicia repositorio git y genera .gitignore / README.md" },
    [PSCustomObject]@{ Group = "other"; Cmd = "cppx info"; Desc = "muestra informacion del proyecto desde cppx.json" },
    [PSCustomObject]@{ Group = "other"; Cmd = "cppx credit"; Desc = "muestra la URL del repositorio de cppx" }
)

$KNOWN_FILES = @{
    "main.cpp"       = "main.cpp.tpl"
    "CMakeLists.txt" = "CMakeLists.txt.tpl"
    ".gitignore"     = ".gitignore.tpl"
    "README.md"      = "README.md.tpl"
}

$ARCHITECTURES = @(
    [PSCustomObject]@{ Name = "small"; Desc = "Estructura simple: headers en include, codigo en src." },
    [PSCustomObject]@{ Name = "mvc"; Desc = "Separa datos, interfaz y control de flujo." },
    [PSCustomObject]@{ Name = "features"; Desc = "Organiza por funcionalidad, cada modulo es autonomo." },
    [PSCustomObject]@{ Name = "layered"; Desc = "Divide en capas: UI, logica, dominio, infraestructura." },
    [PSCustomObject]@{ Name = "cleanarc"; Desc = "Capas desacopladas, dominio independiente del resto." }
)

# -- UI helpers ---------------------------------------------------------------

function Write-Header([string]$rootName, [string]$command, [string]$flags = "", [string]$extra = "") {
    $indent = "  "
    $arrow = " ->"
    $minArrowCol = 30
    $prefix = "$indent$rootName"
    $padding = [Math]::Max($minArrowCol - $prefix.Length, 1)
    $right = ($(@($command, $flags, $extra) | Where-Object { $_ }) -join "  ")
    $line = "$prefix$(' ' * $padding)$arrow  $right"
    Write-Host ""
    Write-Host $line -ForegroundColor Cyan
    Write-Host "  $('-' * ($line.Length - $indent.Length))" -ForegroundColor Cyan
    Write-Host ""
}

function Write-Row([string]$label, [string]$msg, [string]$status = "ok") {
    $icon = switch ($status) { "ok" { "+" } "warn" { "warn" } "skip" { "-" } "none" { " " } default { " " } }
    $color = switch ($status) { "ok" { "Green" } "warn" { "Yellow" } default { "DarkGray" } }
    Write-Host ("  {0,-10}" -f $label) -ForegroundColor DarkGray -NoNewline
    Write-Host "$icon  " -ForegroundColor $color -NoNewline
    Write-Host $msg -ForegroundColor Gray
}

function Read-Row([string]$label, [string]$prompt) {
    Write-Host ("  {0,-10}" -f $label) -ForegroundColor DarkGray -NoNewline
    Write-Host "? " -ForegroundColor Cyan -NoNewline
    $displayPrompt = if ($prompt) { $prompt } else { " " }
    return (Read-Host $displayPrompt)
}

function Write-Fail([string]$msg) {
    Write-Host ""
    Write-Host "  error  $msg" -ForegroundColor Red
    Write-Host ""
}

function Show-Advice {
    Write-Host ""
    Write-Row "tip" "Usa 'cppx help' para ver los comandos disponibles" "none"
    Write-Host ""
}

# -- Guides ------------------------------------------------------------------

function Show-Help {
    Write-Header "cppx" "help"
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
    Write-Header "cppx" "architectures"
    $ARCHITECTURES | ForEach-Object {
        Write-Host ("  {0,-12}" -f $_.Name) -ForegroundColor Cyan -NoNewline
        Write-Host $_.Desc -ForegroundColor DarkGray
    }
    Write-Host ""
    Write-Host "  uso: cppx new project <nombre>/<arch>" -ForegroundColor Yellow
    Write-Host ""
}

# -- Helpers ------------------------------------------------------------------

# -- Y/n method --
# Mandar una pregunta y recibir un bool de si le acepta
# sin implementacion por el momento
#
# implementacion:
# if (-not (Confirm "Aquí va la advertencia, ponga lo que quiera")) { return }
function Confirm([string]$msg, [string]$qst) {
    Write-Host ""
    Write-Row "" $msg "warn"
    $reply = Read-Host "  " $qst " [Y/n]"
    Write-Host ""
    return ($reply -match '^[Yy]')
}

function Test-Name([string]$n) {
    if (-not $n) {
        Write-Fail "el nombre no puede estar vacio"
        return $false
    }
    if ($n -match '(^/|/$|//|[\\:*?"<>|\s])') {
        Write-Fail "nombre invalido '$n'  -  caracteres no permitidos: / \ : * ? `" < > | <ESPACIO>"
        return $false
    }
    return $true
}

function Request-Name {
    if (Test-Name $name) { return }
    do {
        $script:name = Read-Row "nuevo nombre" " "
    } while (-not (Test-Name $script:name))
}

function Test-PascalCase([string]$n) {
    return $n -cmatch '^[A-Z][a-zA-Z0-9]*$'
}

function ConvertTo-PascalCase([string]$n) {
    if (-not $n) { return $n }
    $result = ($n -replace '[-_](.)', { $args[0].Groups[1].Value.ToUpper() })
    return ($result.Substring(0, 1).ToUpper() + $result.Substring(1))
}

function Split-SlashPair([string]$raw) {
    $parts = $raw -split "/"
    $leaf = $parts[-1]
    $head = if ($parts.Length -gt 1) { $parts[0..($parts.Length - 2)] } else { @() }
    return @{
        # para class / module: ultimo segmento es la clase, los anteriores forman el namespace (::)
        class     = $leaf
        namespace = ($head -join "::")
        # para project: primer segmento es el nombre, segundo (si existe) es la arch
        project   = $parts[0]
        arch      = if ($parts.Length -eq 2) { $parts[1] } else { "" }
        # acceso generico
        leaf      = $leaf
        head      = ($head -join "/")
    }
}

function Test-CMake {
    if (-not (Test-Path "CMakeLists.txt")) {
        Write-Fail "CMakeLists.txt no encontrado"
        return $false
    }
    return $true
}

function Get-ProjectName {
    $cmakeContent = Get-Content "CMakeLists.txt" -Raw
    if ($cmakeContent -match 'project\(\s*(\w+)') { return $Matches[1] }
    Write-Fail "no se pudo leer el nombre del proyecto desde CMakeLists.txt"
    return $null
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
    if (Get-Command cl -ErrorAction SilentlyContinue) { return "MSVC" }
    if (Get-Command g++ -ErrorAction SilentlyContinue) { return "GCC" }
    if (Get-Command clang++ -ErrorAction SilentlyContinue) { return "CLANG" }
    return "UNKNOWN"
}

# -- YAML parser --------------------------------------------------------------
# Soporta el subset usado en los archivos de arquitectura:
#   - Listas con "- key:" (nodos directorio)
#   - Listas con "- file.ext" (nodos archivo conocido)
#   - Indentacion con espacios (2 o 4 por nivel)
# Devuelve un arbol de objetos @{ name; type; children }

function Import-ArchYaml([string]$yamlPath) {
    if (-not (Test-Path $yamlPath)) {
        Write-Fail "arquitectura no encontrada: $yamlPath"
        return $null
    }

    $lines = Get-Content $yamlPath
    $tokens = [System.Collections.Generic.List[hashtable]]::new()

    foreach ($line in $lines) {
        if ($line -match '^\s*$' -or $line -match '^\s*#') { continue }

        if ($line -notmatch '^(\s*)-\s+(.+)$') { continue }

        $indent = $Matches[1].Length
        $content = $Matches[2].Trim()

        if ($content -match '^([A-Za-z0-9_./-]+):$') {
            $tokens.Add(@{ indent = $indent; name = $Matches[1]; isDir = $true })
        } elseif ($content -match '^([A-Za-z0-9_./-]+)$') {
            $tokens.Add(@{ indent = $indent; name = $content; isDir = $false })
        }
    }

    $root = @{ name = "root"; isDir = $true; children = [System.Collections.Generic.List[hashtable]]::new() }
    $stack = [System.Collections.Generic.Stack[hashtable]]::new()
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
    $meta = [ordered]@{
        name      = $projectName
        arch      = $arch
        repo      = $repo
        createdAt = (Get-Date -Format "yyyy-MM-ddTHH:mm:ss")
        compiler  = (Find-Compiler)
        class     = @()
        module    = @()
    }
    $meta | ConvertTo-Json | Set-Content "cppx.json"
    Write-Row "meta" "cppx.json  (name=$projectName, arch=$arch)"
}

function Read-CppxMeta {
    if (-not (Test-Path "cppx.json")) { return $null }
    return (Get-Content "cppx.json" -Raw | ConvertFrom-Json)
}

function Request-CppxMeta {
    $meta = Read-CppxMeta
    if (-not $meta) {
        Write-Fail "cppx.json no encontrado"
        return $null
    }
    if (-not $meta.name) {
        Write-Fail "cppx.json no tiene campo 'name'"
        return $null
    }
    return $meta
}

function Update-CppxMeta([hashtable]$fields) { # Escribe campos parciales sin pisar el resto
    $meta = Read-CppxMeta
    if (-not $meta) { return }
    foreach ($key in $fields.Keys) {
        $val = $fields[$key]
        if ($val -is [array]) { $val = [array]$val }
        $meta | Add-Member -MemberType NoteProperty -Name $key -Value $val -Force
    }
    $meta | ConvertTo-Json | Set-Content "cppx.json"
}

# -- Commands -----------------------------------------------------------------

function New-CppFile([string]$type) {
    Request-Name

    $info = Split-SlashPair $name
    $class = $info.class

    if (-not (Test-PascalCase $class)) {
        $suggested = ConvertTo-PascalCase $class
        if (Confirm "'$class' no sigue el formato PascalCase." "Transformar a '$suggested'?") {
            $class = $suggested
            $script:name = if ($info.head) { "$($info.head)/$class" } else { $class }
            $info = Split-SlashPair $script:name
        }
    }
    Write-Header "new $type" $class $(if ($info.namespace) { $info.namespace } else { "" })
    
    $isModule = $type -eq "modul"
    
    $ns        = if ($isModule) { ($name -replace "/", "::") } else { $info.namespace }
    $ns        = if ($ns -eq $class) { "" } else { $ns }
    $nsOpen    = if ($ns) { "namespace $ns {" }     else { "" }
    $nsClose   = if ($ns) { "} // namespace $ns" }  else { "" }
    $includeDir = if ($isModule) { "include/$name" } else { if ($info.head) { "include/$($info.head)" } else { "include" } }
    $srcDir     = if ($isModule) { "src/$name" }     else { if ($info.head) { "src/$($info.head)" }     else { "src" } }
    $includePath = if ($isModule) { "$name/$class" } else { if ($info.head) { "$($info.head)/$class" } else { $class } }

    $null = New-Item -ItemType Directory -Force -Path $includeDir
    $null = New-Item -ItemType Directory -Force -Path $srcDir

    $repl = @{
        NAME            = $class
        INCLUDE_PATH    = $includePath
        NAMESPACE       = $ns
        NAMESPACE_OPEN  = $nsOpen
        NAMESPACE_CLOSE = $nsClose
    }

    Set-Content "$includeDir/$class.h"   (Get-Template "$type.h.tpl"   $repl)
    Set-Content "$srcDir/$class.cpp"     (Get-Template "$type.cpp.tpl" $repl)

    Write-Row "header" "$includeDir/$class.h"
    Write-Row "source" "$srcDir/$class.cpp"
    if ($ns) { Write-Row "namespace" $ns }

    $meta = Read-CppxMeta
    if ($meta -and $meta.arch -ne "small") {
        Write-Row "arch" "proyecto usa '$($meta.arch)' - verifica que el subdirectorio sea correcto" "warn"
    }

    $existing = @($meta.$type | Where-Object { $_ })
    Update-CppxMeta @{ $type = [array]($existing + $class | Select-Object -Unique) }
}

function New-Class  { New-CppFile "class" }
function New-Module { New-CppFile "module" }

function New-Project {
    Request-Name
    
    $parsed = Split-SlashPair $name
    $projectName = $parsed.project
    $archName = $parsed.arch
    Write-Header "new project" $projectName $archName

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

    $tree = Import-ArchYaml $yamlPath
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
    if (-not (Test-CMake)) { return $false }
    $meta = Request-CppxMeta
    if (-not $meta) { return $false }
    Write-Header "build" $meta.name "debug"
    
    Write-Row "project" $meta.name

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

    $projectName = Get-ProjectName
    if (-not $projectName) { return }

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

    $exeFullPath = (Resolve-Path $exe).Path

    $script = @"
Write-Host ''
Write-Host '  $('-' * 40) -ForegroundColor DarkGray
Write-Host '  $projectName' -ForegroundColor Green
Write-Host '  $('-' * 40) -ForegroundColor DarkGray
Write-Host ''
& '$exeFullPath'
Write-Host ''
Write-Host '  $('-' * 40) -ForegroundColor DarkGray
Write-Host '  exit' -ForegroundColor DarkGray
Write-Host ''
"@

    Start-Process powershell -ArgumentList "-Command", $script
}

function Dist {
    if (-not (Build-Release)) { return }

    $projectName = Get-ProjectName
    if (-not $projectName) { return }

    $exe = Get-ChildItem "build/release" -Filter "*.exe" -Recurse | Where-Object { $_.Name -notlike "CompilerId*" } | Select-Object -First 1
    if (-not $exe) { Write-Fail "no se encontro .exe tras compilar"; return }

    $distDir = "dist/$projectName"
    $null = New-Item -ItemType Directory -Force -Path $distDir

    Copy-Item $exe.FullName "$distDir/$($exe.Name)" -Force
    Write-Host ""
    Write-Host "  $('-' * 40)" -ForegroundColor DarkGray
    Write-Row "exe" $exe.Name
    Write-Host "  $('-' * 40)" -ForegroundColor DarkGray
    Write-Host ""

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

function Initialize-Git {    
    $meta = Request-CppxMeta
    if (-not $meta) { return }
    Write-Header "git" $meta.name "init"

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

    $gitignoreContent = Get-Template ".gitignore.tpl" @{ NAME = $meta.name }
    if ($gitignoreContent) {
        Set-Content ".gitignore" $gitignoreContent
        Write-Row "file" ".gitignore" "ok"
    }

    $readmeContent = Get-Template "README.md.tpl" @{ NAME = $meta.name; ARCH = $meta.arch }
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

    Update-CppxMeta @{ repo = $repoUrl }

    Write-Host ""
    Write-Row "done" "listo - usa 'git add .' y 'git commit' para tu primer commit" "ok"
    Write-Host ""
}

function Build-Release {
    if (-not (Test-CMake)) { return $false }
    $meta = Request-CppxMeta
    if (-not $meta) { return $false }
    Write-Header "build" $meta.name "release"

    $compiler = Find-Compiler
    if ($compiler -eq "UNKNOWN") { Write-Fail "no se encontro ningun compilador (cl g++ clang)"; return $false }
    if (-not (Get-Command cmake -ErrorAction SilentlyContinue)) { Write-Fail "cmake no esta instalado o no esta en el PATH"; return $false }

    Write-Row "compiler" $compiler
    Write-Host ""

    cmake -S . -B build/release -DCMAKE_BUILD_TYPE=Release
    cmake --build build/release --config Release

    Write-Host ""
    Write-Row "build" "release  ->  build/release/" "ok"
    return $true
}

function Clear-Dist {
    $meta = Request-CppxMeta
    if (-not $meta) { return }
    Write-Header "clean" $meta.name

    foreach ($dir in @("build", "dist")) {
        if (Test-Path $dir) {
            Remove-Item $dir -Recurse -Force
            Write-Row $dir "eliminado" "ok"
        } else {
            Write-Row $dir "no existe" "skip"
        }
    }
}

function Show-Info {
    $meta = Request-CppxMeta
    if (-not $meta) { return }
    Write-Header "info" $meta.name

    Write-Row "name"      $meta.name
    Write-Row "arch"      $meta.arch
    Write-Row "compiler"  $meta.compiler
    Write-Row "created"   $meta.createdAt
    if ($meta.repo) { Write-Row "repo" $meta.repo }

    $classes = @($meta.classes | Where-Object { $_ })
    $modules = @($meta.modules | Where-Object { $_ })

    Write-Host ""
    Write-Host "  classes" -ForegroundColor DarkGray
    if ($classes.Count) { $classes | ForEach-Object { Write-Row "" $_ "none" } }
    else                { Write-Row "" "(ninguna)" "skip" }

    Write-Host ""
    Write-Host "  modules" -ForegroundColor DarkGray
    if ($modules.Count) { $modules | ForEach-Object { Write-Row "" $_ "none" } }
    else                { Write-Row "" "(ninguno)" "skip" }

    Write-Host ""
}

function Show-List {
    $meta = Request-CppxMeta
    if (-not $meta) { return }
    Write-Header "list" $meta.name

    $classes = @($meta.classes | Where-Object { $_ })
    $modules = @($meta.modules | Where-Object { $_ })

    Write-Host "  classes" -ForegroundColor DarkGray
    if ($classes.Count) { $classes | ForEach-Object { Write-Row "class" $_ } }
    else                { Write-Row "class" "(ninguna)" "skip" }

    Write-Host ""
    Write-Host "  modules" -ForegroundColor DarkGray
    if ($modules.Count) { $modules | ForEach-Object { Write-Row "module" $_ } }
    else                { Write-Row "module" "(ninguno)" "skip" }

    Write-Host ""
}

function New-Interface {
    Request-Name

    $info = Split-SlashPair $name
    $class = $info.class

    if (-not (Test-PascalCase $class)) {
        $suggested = ConvertTo-PascalCase $class
        if (Confirm "'$class' no sigue el formato PascalCase." "Transformar a '$suggested'?") {
            $class = $suggested
            $script:name = if ($info.head) { "$($info.head)/$class" } else { $class }
            $info = Split-SlashPair $script:name
        }
    }

    Write-Header "new interface" $class $(if ($info.namespace) { $info.namespace } else { "" })

    $ns         = $info.namespace
    $nsOpen     = if ($ns) { "namespace $ns {" }    else { "" }
    $nsClose    = if ($ns) { "} // namespace $ns" } else { "" }
    $includeDir = if ($info.head) { "include/$($info.head)" } else { "include" }
    $includePath = if ($info.head) { "$($info.head)/$class" } else { $class }

    $null = New-Item -ItemType Directory -Force -Path $includeDir

    $repl = @{
        NAME            = $class
        INCLUDE_PATH    = $includePath
        NAMESPACE       = $ns
        NAMESPACE_OPEN  = $nsOpen
        NAMESPACE_CLOSE = $nsClose
    }

    Set-Content "$includeDir/$class.h" (Get-Template "interface.h.tpl" $repl)
    Write-Row "header" "$includeDir/$class.h"
    if ($ns) { Write-Row "namespace" $ns }

    $existing = @($meta.classes | Where-Object { $_ })
    Update-CppxMeta @{ classes = [array]($existing + $class | Select-Object -Unique) }
}

function Rename-CppFile {
    if (-not $cmd2 -or -not $name) {
        Write-Fail "uso: cppx rename <old> <new>"
        return
    }
    $oldName = $cmd2
    $newName = $name

    Write-Header "rename" $oldName $newName

    $oldFiles = @(
        (Get-ChildItem -Recurse -Filter "$oldName.h"   | Select-Object -First 1),
        (Get-ChildItem -Recurse -Filter "$oldName.cpp" | Select-Object -First 1)
    ) | Where-Object { $_ }

    if (-not $oldFiles.Count) {
        Write-Fail "no se encontro '$oldName.h' ni '$oldName.cpp' en el proyecto"
        return
    }

    foreach ($f in $oldFiles) {
        $ext     = $f.Extension
        $newPath = Join-Path $f.DirectoryName "$newName$ext"
        Rename-Item $f.FullName $newPath
        Write-Row "rename" "$($f.Name)  ->  $newName$ext" "ok"
    }

    $affected = 0
    Get-ChildItem -Recurse -Include "*.h","*.cpp" | ForEach-Object {
        $content = Get-Content $_.FullName -Raw
        if ($content -match [regex]::Escape($oldName)) {
            $updated = $content -replace [regex]::Escape($oldName), $newName
            Set-Content $_.FullName $updated
            Write-Row "updated" $_.Name "ok"
            $affected++
        }
    }
    if (-not $affected) { Write-Row "includes" "ninguno afectado" "skip" }

    $meta = Read-CppxMeta
    if ($meta) {
        $classes = [array]($meta.classes | ForEach-Object { if ($_ -eq $oldName) { $newName } else { $_ } })
        $modules = [array]($meta.modules | ForEach-Object { if ($_ -eq $oldName) { $newName } else { $_ } })
        Update-CppxMeta @{ classes = $classes; modules = $modules }
        Write-Row "meta" "cppx.json actualizado" "ok"
    }
}



# -- Router -------------------------------------------------------------------

switch ($cmd1) {
    "new" {
        switch ($cmd2) {
            "class"     { New-Class }
            "module"    { New-Module }
            "interface" { New-Interface }
            "project"   { New-Project }
            default     { Show-Advice }
        }
    }
    "build" {
        switch ($cmd2) {
            "release" { Build-Release | Out-Null }
            default   { Build | Out-Null }
        }
    }
    "rename" { Rename-CppFile }
    "list"   { Show-List }
    "info"   { Show-Info }
    "clean"  { Clear-Dist }
    "run"    { Run }
    "dist"   { Dist }
    "git"    { Initialize-Git }
    "credit" { Show-Credit }
    "help"   { Show-Help }
    default  { Show-Advice }
}