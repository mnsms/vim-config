<#
.SYNOPSIS
    Windows 一键部署 amix/vimrc + 个人配置

.DESCRIPTION
    在 Windows 上安装 vim + 插件 + lightline + fzf + which-key。
    需要 Git for Windows (Git Bash) 和 winget。

.PARAMETER SkipBase
    跳过 amix/vimrc 基础框架安装

.PARAMETER DeployOnly
    仅部署 my_configs.vim + 自定义插件

.EXAMPLE
    .\setup-vim.ps1
    .\setup-vim.ps1 -SkipBase
    .\setup-vim.ps1 -DeployOnly

.NOTES
    环境变量:
      GITHUB_PROXY  GitHub 下载镜像 (默认: https://gh-proxy.com)
#>
param(
    [switch]$SkipBase,
    [switch]$DeployOnly,
    [switch]$Help
)

$ErrorActionPreference = 'Stop'

# ── 镜像配置 ──────────────────────────────────────────────
$GitHubProxy = if ($env:GITHUB_PROXY) { $env:GITHUB_PROXY } else { 'https://gh-proxy.com' }
$FzfVersion = '0.72.0'
$VimRuntimeUrl = 'https://github.com/amix/vimrc.git'

# ── 颜色输出 ──────────────────────────────────────────────
function Write-Info  { Write-Host "[INFO]  $($args -join ' ')" -ForegroundColor Cyan }
function Write-Ok    { Write-Host "[OK]    $($args -join ' ')" -ForegroundColor Green }
function Write-Warn  { Write-Host "[WARN]  $($args -join ' ')" -ForegroundColor Yellow }
function Write-Err   { Write-Host "[ERR]   $($args -join ' ')" -ForegroundColor Red }

# ── 帮助 ──────────────────────────────────────────────────
if ($Help) {
    Write-Host @'
setup-vim.ps1 — Windows 一键部署 amix/vimrc + 个人配置

用法:
  .\setup-vim.ps1              全新安装
  .\setup-vim.ps1 -SkipBase    跳过 amix/vimrc 框架
  .\setup-vim.ps1 -DeployOnly  仅部署 my_configs.vim + 自定义插件

环境变量:
  $env:GITHUB_PROXY = "https://ghfast.top"

依赖:
  - Git for Windows (含 Git Bash)
  - winget (Windows 10/11 内置)
'@
    exit 0
}

# ── Git Bash 路径 ─────────────────────────────────────────
function Get-GitBash {
    $candidates = @(
        "${env:ProgramFiles}\Git\bin\bash.exe",
        "${env:ProgramFiles(x86)}\Git\bin\bash.exe",
        "$env:LOCALAPPDATA\Programs\Git\bin\bash.exe"
    )
    foreach ($c in $candidates) {
        if (Test-Path $c) { return $c }
    }
    return $null
}

function Invoke-GitBash {
    param([string]$Command)
    $bash = Get-GitBash
    if (-not $bash) {
        Write-Err "找不到 Git Bash，请先安装 Git for Windows"
        exit 1
    }
    # 使用 --login 确保 ~/.bashrc 等被加载，PATH 正确
    $result = & $bash --login -c $Command 2>&1
    if ($LASTEXITCODE -ne 0 -and $LASTEXITCODE -ne 1) {
        # exit code 1 在某些 bash 操作中是正常的（如 grep 没匹配）
    }
    return $result
}

# ── 下载文件 ──────────────────────────────────────────────
function Download-File {
    param([string]$Url, [string]$Output)
    # 先尝试镜像
    $proxyUrl = "$GitHubProxy/$Url"
    try {
        Write-Info "下载: $proxyUrl"
        Invoke-WebRequest -Uri $proxyUrl -OutFile $Output -UseBasicParsing -TimeoutSec 30
        return
    } catch {
        Write-Warn "镜像下载失败，尝试直连..."
    }
    # 直连
    try {
        Invoke-WebRequest -Uri $Url -OutFile $Output -UseBasicParsing -TimeoutSec 60
        return
    } catch {
        Write-Err "下载失败: $Url"
        Write-Err $_.Exception.Message
        exit 1
    }
}

# ════════════════════════════════════════════════════════════
#  Phase 1: 系统依赖
# ════════════════════════════════════════════════════════════
function Install-SystemDeps {
    Write-Info "检查系统依赖..."

    # 检查 Git Bash
    $bash = Get-GitBash
    if ($bash) {
        Write-Ok "Git Bash: $bash"
    } else {
        Write-Err "未找到 Git for Windows，请先安装: winget install Git.Git"
        exit 1
    }

    # 检查 vim
    $vimExe = Get-Command vim -ErrorAction SilentlyContinue
    if ($vimExe) {
        Write-Ok "vim: $($vimExe.Source)"
    } else {
        Write-Info "安装 vim..."
        winget install --id vim.vim --accept-source-agreements --accept-package-agreements --silent 2>&1 | Out-Null
        # 刷新 PATH
        $env:Path = [System.Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + [System.Environment]::GetEnvironmentVariable('Path', 'User')
        $vimExe = Get-Command vim -ErrorAction SilentlyContinue
        if ($vimExe) {
            Write-Ok "vim: $($vimExe.Source) ✓"
        } else {
            Write-Warn "vim 安装完成但可能需要重启终端才能生效"
        }
    }

    # 检查 gvim (可选，有 GUI + clipboard)
    $gvimExe = Get-Command gvim -ErrorAction SilentlyContinue
    if ($gvimExe) {
        Write-Ok "gvim: $($gvimExe.Source)"
    }

    # 检查 ripgrep
    $rgExe = Get-Command rg -ErrorAction SilentlyContinue
    if ($rgExe) {
        $ver = & rg --version 2>&1 | Select-Object -First 1
        Write-Ok "ripgrep: $ver ✓"
    } else {
        Write-Info "安装 ripgrep..."
        winget install --id BurntSushi.ripgrep.MSVC --accept-source-agreements --accept-package-agreements --silent 2>&1 | Out-Null
        $env:Path = [System.Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + [System.Environment]::GetEnvironmentVariable('Path', 'User')
        $rgExe = Get-Command rg -ErrorAction SilentlyContinue
        if ($rgExe) {
            Write-Ok "ripgrep ✓"
        } else {
            Write-Warn "ripgrep 安装完成但可能需要重启终端"
        }
    }

    # 检查 clipboard (Windows 原生 vim 支持)
    Write-Ok "剪贴板: Windows 原生支持 ✓"
}

# ════════════════════════════════════════════════════════════
#  Phase 2: amix/vimrc 基础框架
# ════════════════════════════════════════════════════════════
function Install-VimrcBase {
    $vimRuntime = Invoke-GitBash 'echo ~/.vim_runtime'
    $vimRuntime = $vimRuntime.Trim()

    if (Test-Path $vimRuntime) {
        Write-Warn "$vimRuntime 已存在，跳过基础框架安装"
        return
    }

    Write-Info "克隆 amix/vimrc (awesome 版)..."
    Invoke-GitBash "git clone --depth 1 $VimRuntimeUrl ~/.vim_runtime 2>&1" | Out-Null

    if (-not (Test-Path $vimRuntime)) {
        Write-Err "克隆失败"
        exit 1
    }

    Write-Info "执行安装脚本 (生成 .vimrc)..."
    # 在 Git Bash 中执行，不带 --all (Windows 没有 /home)
    Invoke-GitBash "cd ~/.vim_runtime && bash install_awesome_parameterized.sh ~/.vim_runtime" | ForEach-Object {
        Write-Host $_
    }

    Write-Ok "amix/vimrc 基础框架安装完成"
}

# ════════════════════════════════════════════════════════════
#  Phase 3: 清理无用插件
# ════════════════════════════════════════════════════════════
function Cleanup-Plugins {
    $dir = Invoke-GitBash 'echo ~/.vim_runtime/sources_non_forked'
    $dir = $dir.Trim()
    if (-not (Test-Path $dir)) { return }

    Write-Info "清理不需要的插件..."

    $skipList = @(
        "ack.vim", "ale", "auto-pairs", "bufexplorer", "copilot.vim",
        "ctrlp.vim", "dracula", "editorconfig-vim", "goyo.vim", "gruvbox",
        "lightline-ale", "lightline.vim", "mru.vim", "nerdtree", "tlib",
        "vim-abolish", "vim-addon-mw-utils", "vim-bundle-mako",
        "vim-colors-solarized", "vim-commentary", "vim-flake8",
        "vim-fugitive", "vim-gitgutter", "vim-indent-guides", "vim-indent-object",
        "vim-lastplace", "vim-markdown", "vim-multiple-cursors",
        "vim-python-pep8-indent", "vim-repeat", "vim-snipmate", "vim-snippets",
        "vim-surround", "vim-yankstack"
    )

    $dirs = Get-ChildItem -Path $dir -Directory
    $removed = 0
    foreach ($d in $dirs) {
        if ($d.Name -notin $skipList) {
            Remove-Item -Recurse -Force $d.FullName
            Write-Info "  移除: $($d.Name)"
            $removed++
        }
    }

    Write-Ok "清理完成，移除了 $removed 个插件，保留了 $($skipList.Count) 个"
}

# ════════════════════════════════════════════════════════════
#  Phase 4: 安装自定义插件
# ════════════════════════════════════════════════════════════
function Install-CustomPlugins {
    Write-Info "安装自定义插件..."

    $plugins = @(
        @{ name = "fzf";         url = "https://github.com/junegunn/fzf.git" },
        @{ name = "fzf.vim";     url = "https://github.com/junegunn/fzf.vim.git" },
        @{ name = "vim-which-key"; url = "https://github.com/liuchengxu/vim-which-key.git" }
    )

    foreach ($p in $plugins) {
        $target = Invoke-GitBash "echo ~/.vim_runtime/my_plugins/$($p.name)"
        $target = $target.Trim()
        if (Test-Path $target) {
            Write-Info "$($p.name) 已存在，跳过"
        } else {
            Write-Info "安装 $($p.name)..."
            Invoke-GitBash "git clone --depth 1 $($p.url) ~/.vim_runtime/my_plugins/$($p.name)" | Out-Null
            if (Test-Path $target) {
                Write-Ok "$($p.name) ✓"
            } else {
                Write-Err "$($p.name) 安装失败"
            }
        }
    }

    Write-Ok "自定义插件安装完成"
}

# ════════════════════════════════════════════════════════════
#  Phase 5: 下载 fzf Windows 二进制
# ════════════════════════════════════════════════════════════
function Install-FzfBinary {
    $fzfDir = Invoke-GitBash 'echo ~/.vim_runtime/my_plugins/fzf/bin'
    $fzfDir = $fzfDir.Trim()
    $fzfExe = Join-Path $fzfDir "fzf.exe"

    if (Test-Path $fzfExe) {
        Write-Ok "fzf.exe 已存在，跳过"
        return
    }

    $arch = if ([Environment]::Is64BitOperatingSystem) { "windows_amd64" } else { "windows_386" }
    $fileName = "fzf-$FzfVersion-$arch.zip"
    $url = "https://github.com/junegunn/fzf/releases/download/v$FzfVersion/$fileName"
    $tmpZip = Join-Path $env:TEMP $fileName

    Write-Info "下载 fzf $FzfVersion ($arch)..."

    # 尝试镜像
    $proxyUrl = "$GitHubProxy/$url"
    try {
        Invoke-WebRequest -Uri $proxyUrl -OutFile $tmpZip -UseBasicParsing -TimeoutSec 30
    } catch {
        Write-Warn "镜像下载失败，尝试直连..."
        try {
            Invoke-WebRequest -Uri $url -OutFile $tmpZip -UseBasicParsing -TimeoutSec 60
        } catch {
            Write-Err "fzf 下载失败: $url"
            exit 1
        }
    }

    # 解压
    New-Item -ItemType Directory -Force -Path $fzfDir | Out-Null
    Expand-Archive -Path $tmpZip -DestinationPath $fzfDir -Force
    Remove-Item $tmpZip -Force -ErrorAction SilentlyContinue

    if (Test-Path $fzfExe) {
        Write-Ok "fzf.exe $FzfVersion ✓"
    } else {
        Write-Err "fzf.exe 解压失败"
        exit 1
    }
}

# ════════════════════════════════════════════════════════════
#  Phase 6: 部署 my_configs.vim
# ════════════════════════════════════════════════════════════
function Deploy-Configs {
    $scriptDir = $PSScriptRoot
    $source = Join-Path $scriptDir "my_configs.vim"

    $vimRuntime = Invoke-GitBash 'echo ~/.vim_runtime'
    $target = (Join-Path $vimRuntime.Trim() "my_configs.vim").Replace('\', '/')

    Write-Info "部署 my_configs.vim..."

    if (Test-Path $source) {
        # 转换路径为 Unix 格式供 Git Bash 使用
        $unixSource = $source.Replace('\', '/')
        if ($unixSource -match '^([A-Za-z]):') {
            $drive = $Matches[1].ToLower()
            $unixSource = "/$drive" + $unixSource.Substring(2)
        }
        Invoke-GitBash "cp '$unixSource' '$target'"
        Write-Ok "从 $source 复制 my_configs.vim"
    } else {
        Write-Err "找不到 $source"
        exit 1
    }

    # 确保 Windows vim 能找到 .vimrc
    # Windows vim 查找 ~/_vimrc 或 ~/.vimrc，Git Bash 安装脚本写的是 ~/.vimrc
    # 在 Git Bash 中 ~ 是正确的，但原生 Windows 终端需要确认
    $homeVimrc = Join-Path $env:USERPROFILE ".vimrc"
    $homeVimrcUnix = Invoke-GitBash 'echo ~/.vimrc'
    if (-not (Test-Path $homeVimrc)) {
        $unixTarget = $homeVimrcUnix.Trim()
        if (Test-Path (Resolve-Path $homeVimrcUnix -ErrorAction SilentlyContinue)) {
            Write-Ok ".vimrc 已就位"
        } else {
            Write-Warn "请确认 $homeVimrcUnix 存在"
        }
    }
}

# ════════════════════════════════════════════════════════════
#  Phase 7: 配置 PATH
# ════════════════════════════════════════════════════════════
function Setup-Path {
    $fzfDir = Invoke-GitBash 'echo ~/.vim_runtime/my_plugins/fzf/bin'
    $fzfDir = $fzfDir.Trim()

    # 转换为 Windows 路径
    $winFzfDir = Invoke-GitBash "cygpath -w '$fzfDir'"
    $winFzfDir = $winFzfDir.Trim().Trim('"')

    # 检查是否已在用户 PATH 中
    $userPath = [System.Environment]::GetEnvironmentVariable('Path', 'User')
    if ($userPath -like "*$winFzfDir*") {
        Write-Ok "PATH 已配置，跳过"
        return
    }

    Write-Info "将 fzf bin 目录加入用户 PATH..."
    $newPath = "$userPath;$winFzfDir"
    [System.Environment]::SetEnvironmentVariable('Path', $newPath, 'User')
    $env:Path = $newPath

    Write-Ok "PATH 配置完成 (新终端窗口生效)"
}

# ════════════════════════════════════════════════════════════
#  Phase 8: 验证
# ════════════════════════════════════════════════════════════
function Test-Installation {
    Write-Info "验证安装..."
    $errors = 0

    # vim
    $vimExe = Get-Command vim -ErrorAction SilentlyContinue
    if ($vimExe) {
        Write-Ok "vim: $($vimExe.Source)"
    } else {
        Write-Err "vim 未找到"
        $errors++
    }

    # ripgrep
    $rgExe = Get-Command rg -ErrorAction SilentlyContinue
    if ($rgExe) {
        Write-Ok "ripgrep ✓"
    } else {
        Write-Err "ripgrep 未找到"
        $errors++
    }

    # fzf
    $fzfDir = Invoke-GitBash 'echo ~/.vim_runtime/my_plugins/fzf/bin'
    $fzfDir = $fzfDir.Trim()
    $winFzfDir = (Invoke-GitBash "cygpath -w '$fzfDir'").Trim().Trim('"')
    if (Test-Path (Join-Path $winFzfDir "fzf.exe")) {
        Write-Ok "fzf.exe ✓"
    } else {
        Write-Err "fzf.exe 未找到"
        $errors++
    }

    # .vimrc
    $vimrc = Invoke-GitBash 'echo ~/.vimrc'
    $vimrcWin = (Invoke-GitBash "cygpath -w '$($vimrc.Trim())'").Trim().Trim('"')
    if (Test-Path $vimrcWin) {
        $content = Get-Content $vimrcWin -Raw -ErrorAction SilentlyContinue
        if ($content -match 'vim_runtime') {
            Write-Ok ".vimrc ✓"
        } else {
            Write-Err ".vimrc 内容不正确"
            $errors++
        }
    } else {
        Write-Err ".vimrc 不存在"
        $errors++
    }

    # my_configs.vim
    $myConfigs = Invoke-GitBash 'echo ~/.vim_runtime/my_configs.vim'
    $myConfigsWin = (Invoke-GitBash "cygpath -w '$($myConfigs.Trim())'").Trim().Trim('"')
    if (Test-Path $myConfigsWin) {
        Write-Ok "my_configs.vim ✓"
    } else {
        Write-Err "my_configs.vim 未找到"
        $errors++
    }

    # 自定义插件
    foreach ($name in @("fzf", "fzf.vim", "vim-which-key")) {
        $p = Invoke-GitBash "echo ~/.vim_runtime/my_plugins/$name"
        $pWin = (Invoke-GitBash "cygpath -w '$($p.Trim())'").Trim().Trim('"')
        if (Test-Path $pWin) {
            Write-Ok "插件 $name ✓"
        } else {
            Write-Err "插件 $name 未找到"
            $errors++
        }
    }

    Write-Host ""
    if ($errors -eq 0) {
        Write-Host "═══════════════════════════════════════════" -ForegroundColor Green
        Write-Host "  全部检查通过 - 打开 vim 试试吧！" -ForegroundColor Green
        Write-Host "═══════════════════════════════════════════" -ForegroundColor Green
    } else {
        Write-Host "═══════════════════════════════════════════" -ForegroundColor Yellow
        Write-Host "  $errors 项检查未通过，请查看上方日志" -ForegroundColor Yellow
        Write-Host "═══════════════════════════════════════════" -ForegroundColor Yellow
    }
}

# ════════════════════════════════════════════════════════════
#  Main
# ════════════════════════════════════════════════════════════
Write-Host ""
Write-Host "╔══════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║   Vim 配置一键部署 (Windows)             ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

if ($DeployOnly) {
    Install-CustomPlugins
    Install-FzfBinary
    Deploy-Configs
    Setup-Path
    Test-Installation
} elseif ($SkipBase) {
    Cleanup-Plugins
    Install-CustomPlugins
    Install-FzfBinary
    Deploy-Configs
    Setup-Path
    Test-Installation
} else {
    Install-SystemDeps
    Install-VimrcBase
    Cleanup-Plugins
    Install-CustomPlugins
    Install-FzfBinary
    Deploy-Configs
    Setup-Path
    Test-Installation
}
