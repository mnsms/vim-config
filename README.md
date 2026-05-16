# Vim 配置方案

基于 [amix/vimrc](https://github.com/amix/vimrc) (awesome 版) + 个人配置。

## 结构

```
vim-config/
├── setup-vim.sh        # Linux/macOS 一键安装 (bash)
├── setup-vim.ps1       # Windows 一键安装 (PowerShell)
├── setup-vim.bat       # Windows 双击运行包装器
├── my_configs.vim      # 个人配置 (被脚本部署到 ~/.vim_runtime/)
└── README.md
```

## Linux / macOS

```bash
cd vim-config
bash setup-vim.sh              # 全新安装 (系统依赖 + 框架 + 插件 + 配置)
bash setup-vim.sh --skip-base  # 已有框架时 (只装插件+配置)
bash setup-vim.sh --deploy-only # 仅部署配置 (不装系统包)
```

## Windows

**前置条件**: [Git for Windows](https://git-scm.com/download/win) (含 Git Bash)

```powershell
cd vim-config

# 方式 1: 双击 setup-vim.bat (会自动打开 PowerShell)

# 方式 2: PowerShell 手动运行
.\setup-vim.ps1                  # 全新安装 (winget 装 vim + ripgrep)
.\setup-vim.ps1 -SkipBase        # 已有框架时
.\setup-vim.ps1 -DeployOnly      # 仅部署配置

# 方式 3: 自定义镜像
$env:GITHUB_PROXY = "https://ghfast.top"
.\setup-vim.ps1
```

> 如果 PowerShell 提示执行策略错误，先运行：
> `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned`

## 包含功能

### 编辑增强
- **fzf** — 模糊文件查找 (`Ctrl-P`) + 内容搜索 (`Ctrl-F`) + buffer 切换
- **vim-surround** — 括号/引号快速操作 (`cs"(`, `ds"`, `yss"`)
- **vim-commentary** — 注释切换 (`gcc`, `gcip`)
- **vim-multiple-cursors** — 多光标编辑
- **auto-pairs** — 自动括号配对
- **vim-snipmate + vim-snippets** — 代码片段
- **vim-yankstack** — 粘贴历史 (`Alt-p` / `Alt-n`)

### 界面
- **lightline** — 底部状态栏 (模式/Git分支/文件名/行号) + 顶部标签栏
- **NERDTree** — 文件树
- **vim-indent-guides** — 缩进参考线
- **Dracula / Gruvbox / Solarized** — 配色方案

### 搜索 & 导航
- **ack.vim + ripgrep** — 项目级搜索 (`:Ack` 或 `,g`)
- **fzf.vim** — 模糊查找 (文件/内容/buffer/历史)
- **bufexplorer** — buffer 列表
- **vim-which-key** — 按下 `,` 弹出快捷键面板
- **,?** — 打开完整速查表

### Git
- **vim-fugitive** — Git 命令集成
- **vim-gitgutter** — 实时 diff 标记

### 代码
- **ALE** — 异步 lint (默认仅 Python flake8，手动触发)
- **vim-flake8** — Python 检查
- **vim-python-pep8-indent** — Python 缩进

### 其他
- 系统剪贴板集成 (vim-gtk3)
- 中文编辑优化
- 插入模式缩写 (`$1` → `()`, `$e` → `""`, `xdate` → 日期)
- Goyo 专注模式

## 配色主题

修改 `my_configs.vim` 中 `g:lightline.colorscheme` 的值，可选：

`deus` (默认) · `wombat` · `solarized` · `seoul256` · `nord` · `molokai` · `one` · `material`

## 网络加速

```bash
GITHUB_PROXY=https://ghfast.top bash setup-vim.sh
```

## 适用环境

- Ubuntu / Debian (apt 包管理器)
- x86_64 / aarch64
- 需要网络访问 (GitHub，可用镜像加速)
