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
function Get-VimRuntimeDir {
    # Windows 原生路径 (PowerShell 可直接使用)
    return Join-Path $env:USERPROFILE ".vim_runtime"
}

function Get-GitBashHome {
    # 转换 Windows 路径为 Git Bash 可识别的 Unix 路径
    param([string]$WinPath)
    return (Invoke-GitBash "cygpath -u '$($WinPath -replace '\\','/')'").Trim().Trim('"')
}

function Install-VimrcBase {
    $vimRuntime = Get-VimRuntimeDir

    if (Test-Path $vimRuntime) {
        Write-Warn "$vimRuntime 已存在，跳过基础框架安装"
        return
    }

    # 用 PowerShell 的 git 直接克隆 (不需要 Git Bash)
    # git 把进度信息输出到 stderr，PowerShell 会将其视为 NativeCommandError
    # 用 ErrorActionPreference='SilentlyContinue' + 重定向 stderr 到 stdout 解决
    $proxyUrl = "$GitHubProxy/$VimRuntimeUrl"
    Write-Info "克隆 amix/vimrc (镜像: $proxyUrl)..."
    $prevEA = $ErrorActionPreference; $ErrorActionPreference = 'SilentlyContinue'
    & git clone --depth 1 $proxyUrl $vimRuntime 2>&1 | Out-Null
    if (-not (Test-Path $vimRuntime)) {
        Write-Warn "镜像克隆失败，尝试直连..."
        & git clone --depth 1 $VimRuntimeUrl $vimRuntime 2>&1 | Out-Null
    }
    $ErrorActionPreference = $prevEA
    if (-not (Test-Path $vimRuntime)) {
        Write-Err "克隆失败"
        exit 1
    }

    Write-Info "执行安装脚本 (生成 .vimrc)..."
    # 用 Git Bash 执行 bash 脚本 (--all 参数会写入 ~/.vimrc 并克隆全部基础插件)
    $bashHome = Get-GitBashHome $vimRuntime
    Invoke-GitBash "cd '$bashHome' && bash install_awesome_parameterized.sh '$bashHome' --all" | ForEach-Object {
        Write-Host $_
    }

    Write-Ok "amix/vimrc 基础框架安装完成"
}

# ════════════════════════════════════════════════════════════
#  Phase 3: 清理无用插件
# ════════════════════════════════════════════════════════════
function Cleanup-Plugins {
    $dir = Join-Path (Get-VimRuntimeDir) "sources_non_forked"
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

    $myPluginsDir = Join-Path (Get-VimRuntimeDir) "my_plugins"

    $prevEA = $ErrorActionPreference; $ErrorActionPreference = 'SilentlyContinue'

    foreach ($p in $plugins) {
        $target = Join-Path $myPluginsDir $p.name
        if (Test-Path $target) {
            Write-Info "$($p.name) 已存在，跳过"
        } else {
            Write-Info "安装 $($p.name)..."
            $pProxyUrl = "$GitHubProxy/$($p.url)"
            & git clone --depth 1 $pProxyUrl $target 2>&1 | Out-Null
            if (-not (Test-Path $target)) {
                Write-Warn "镜像失败，直连..."
                & git clone --depth 1 $p.url $target 2>&1 | Out-Null
            }
            if (Test-Path $target) {
                Write-Ok "$($p.name) ✓"
            } else {
                Write-Err "$($p.name) 安装失败"
            }
        }
    }

    $ErrorActionPreference = $prevEA
    Write-Ok "自定义插件安装完成"
}

# ════════════════════════════════════════════════════════════
#  Phase 5: 下载 fzf Windows 二进制
# ════════════════════════════════════════════════════════════
function Install-FzfBinary {
    $fzfDir = Join-Path (Get-VimRuntimeDir) "my_plugins\fzf\bin"
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
    $target = Join-Path (Get-VimRuntimeDir) "my_configs.vim"

    Write-Info "部署 my_configs.vim..."

    if (Test-Path $source) {
        Copy-Item $source $target -Force
        Write-Ok "复制 my_configs.vim -> $target"
    } else {
        Write-Err "找不到 $source"
        exit 1
    }

    # 确认 .vimrc 存在 (install_awesome_parameterized.sh 生成)
    $homeVimrc = Join-Path $env:USERPROFILE ".vimrc"
    if (Test-Path $homeVimrc) {
        Write-Ok ".vimrc 就位: $homeVimrc"
    } else {
        Write-Warn "$homeVimrc 不存在，amix/vimrc 安装脚本可能未执行"
    }
}

# ════════════════════════════════════════════════════════════
#  Phase 7: 配置 PATH
# ════════════════════════════════════════════════════════════
function Setup-Path {
    $fzfDir = Join-Path (Get-VimRuntimeDir) "my_plugins\fzf\bin"

    # 检查是否已在用户 PATH 中
    $userPath = [System.Environment]::GetEnvironmentVariable('Path', 'User')
    if ($userPath -like "*$fzfDir*") {
        Write-Ok "PATH 已配置，跳过"
        return
    }

    Write-Info "将 fzf bin 目录加入用户 PATH..."
    $newPath = "$userPath;$fzfDir"
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
    $vimRuntime = Get-VimRuntimeDir

    # vim
    $vimExe = Get-Command vim -ErrorAction SilentlyContinue
    if ($vimExe) {
        Write-Ok "vim: $($vimExe.Source)"
    } else {
        Write-Err "vim 未找到"
        $errors++
    }

    # ripgrep - Get-Command 缓存可能过期，直接搜索 PATH
    $rgExe = (Get-Command rg -ErrorAction SilentlyContinue).Source
    if (-not $rgExe) {
        # 搜索 WinGet 常见安装路径
        $winGetLinks = Join-Path $env:LOCALAPPDATA "Microsoft\WinGet\Links\rg.exe"
        if (Test-Path $winGetLinks) { $rgExe = $winGetLinks }
    }
    if ($rgExe) {
        Write-Ok "ripgrep ✓"
    } else {
        Write-Err "ripgrep 未找到"
        $errors++
    }

    # fzf
    $fzfExe = Join-Path $vimRuntime "my_plugins\fzf\bin\fzf.exe"
    if (Test-Path $fzfExe) {
        Write-Ok "fzf.exe ✓"
    } else {
        Write-Err "fzf.exe 未找到"
        $errors++
    }

    # .vimrc
    $vimrc = Join-Path $env:USERPROFILE ".vimrc"
    if (Test-Path $vimrc) {
        $content = Get-Content $vimrc -Raw -ErrorAction SilentlyContinue
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
    $myConfigs = Join-Path $vimRuntime "my_configs.vim"
    if (Test-Path $myConfigs) {
        Write-Ok "my_configs.vim ✓"
    } else {
        Write-Err "my_configs.vim 未找到"
        $errors++
    }

    # 自定义插件
    foreach ($name in @("fzf", "fzf.vim", "vim-which-key")) {
        $p = Join-Path $vimRuntime "my_plugins\$name"
        if (Test-Path $p) {
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
