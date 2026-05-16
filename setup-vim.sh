#!/usr/bin/env bash
#
# setup-vim.sh — 一键部署 amix/vimrc + 个人配置
#
# 用法:
#   bash setup-vim.sh              # 全新安装
#   bash setup-vim.sh --skip-base  # 跳过 amix/vimrc 基础安装 (已有框架时)
#   bash setup-vim.sh --deploy-only # 仅部署 my_configs.vim 和自定义插件
#
# 适用: Ubuntu/Debian, 其他发行版需自行调整包管理器
#

set -euo pipefail

# ── 镜像配置 ──────────────────────────────────────────────
# GitHub 下载加速，可自行替换为可用的镜像
# 备选: https://ghfast.top  https://gh-proxy.com  https://mirror.ghproxy.com
GITHUB_PROXY="${GITHUB_PROXY:-https://gh-proxy.com}"
# Git clone 加速 (留空则直连)
GIT_PROXY="${GIT_PROXY:-}"

# ── 版本 ──────────────────────────────────────────────────
FZF_VERSION="0.72.0"
VIMRUNTIME_URL="https://github.com/amix/vimrc.git"

# ── 颜色 ──────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

info()  { echo -e "${CYAN}[INFO]${NC}  $*"; }
ok()    { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
err()   { echo -e "${RED}[ERR]${NC}   $*"; }

# ── 检测架构 ──────────────────────────────────────────────
detect_arch() {
    local arch
    arch=$(uname -m)
    case "$arch" in
        x86_64)  echo "linux_amd64" ;;
        aarch64) echo "linux_arm64" ;;
        *)       echo "linux_amd64" ;;  # 默认
    esac
}

# ── 带 mirror 的 git clone ────────────────────────────────
git_clone() {
    local url="$1" dest="$2"
    if [[ -n "$GIT_PROXY" ]]; then
        git clone --depth 1 "${GIT_PROXY}/${url}" "$dest"
    else
        git clone --depth 1 "$url" "$dest"
    fi
}

# ── 带 mirror 的 curl 下载 ────────────────────────────────
curl_download() {
    local url="$1" output="$2"
    curl -fSL --connect-timeout 15 -o "$output" "${GITHUB_PROXY}/${url}"
}

# ── 检查是否需要 sudo ─────────────────────────────────────
maybe_sudo() {
    if [[ $EUID -ne 0 ]]; then
        sudo "$@"
    else
        "$@"
    fi
}

# ════════════════════════════════════════════════════════════
#  Phase 1: 系统依赖
# ════════════════════════════════════════════════════════════
install_system_deps() {
    info "安装系统依赖..."

    maybe_sudo apt-get update -qq

    # vim-gtk3: +clipboard 支持
    maybe_sudo apt-get install -y -qq vim-gtk3 ripgrep git curl

    # 将 vim.gtk3 设为默认 vim
    if command -v update-alternatives &>/dev/null; then
        maybe_sudo update-alternatives --set vim /usr/bin/vim.gtk3 2>/dev/null || true
    fi

    # 验证
    if vim --version 2>/dev/null | grep -q '+clipboard'; then
        ok "剪贴板支持: +clipboard ✓"
    else
        warn "剪贴板支持未启用，部分复制粘贴功能可能不可用"
    fi

    if command -v rg &>/dev/null; then
        ok "ripgrep: $(rg --version | head -1) ✓"
    else
        err "ripgrep 安装失败"
        exit 1
    fi
}

# ════════════════════════════════════════════════════════════
#  Phase 2: amix/vimrc 基础框架
# ════════════════════════════════════════════════════════════
install_vimrc_base() {
    if [[ -d ~/.vim_runtime ]]; then
        warn "~/.vim_runtime 已存在，跳过基础框架安装"
        warn "如需重装，先执行: rm -rf ~/.vim_runtime ~/.vimrc"
        return
    fi

    info "克隆 amix/vimrc (awesome 版)..."
    git_clone "$VIMRUNTIME_URL" ~/.vim_runtime

    info "安装基础配置..."
    cd ~/.vim_runtime
    bash install_awesome_parameterized.sh 2>&1 | tail -5
    cd - > /dev/null

    ok "amix/vimrc 基础框架安装完成"
}

# ════════════════════════════════════════════════════════════
#  Phase 3: 清理无用插件
# ════════════════════════════════════════════════════════════
cleanup_plugins() {
    local dir="$HOME/.vim_runtime/sources_non_forked"
    [[ -d "$dir" ]] || return

    info "清理不需要的插件..."

    local removed=0
    local skip_list=(
        # 保留的核心插件
        "ack.vim" "ale" "auto-pairs" "bufexplorer" "copilot.vim"
        "ctrlp.vim" "dracula" "editorconfig-vim" "goyo.vim" "gruvbox"
        "lightline-ale" "lightline.vim" "mru.vim" "nerdtree" "tlib"
        "vim-abolish" "vim-addon-mw-utils" "vim-bundle-mako"
        "vim-colors-solarized" "vim-commentary" "vim-flake8"
        "vim-fugitive" "vim-gitgutter" "vim-indent-guides" "vim-indent-object"
        "vim-lastplace" "vim-markdown" "vim-multiple-cursors"
        "vim-python-pep8-indent" "vim-repeat" "vim-snipmate" "vim-snippets"
        "vim-surround" "vim-yankstack"
    )

    for d in "$dir"/*/; do
        local name
        name=$(basename "$d")
        local should_skip=false
        for s in "${skip_list[@]}"; do
            if [[ "$name" == "$s" ]]; then
                should_skip=true
                break
            fi
        done
        if [[ "$should_skip" == "false" ]]; then
            rm -rf "$d"
            info "  移除: $name"
            ((removed++))
        fi
    done

    ok "清理完成，移除了 $removed 个插件，保留了 ${#skip_list[@]} 个"
}

# ════════════════════════════════════════════════════════════
#  Phase 4: 安装自定义插件
# ════════════════════════════════════════════════════════════
install_custom_plugins() {
    local my_plugins="$HOME/.vim_runtime/my_plugins"
    mkdir -p "$my_plugins"

    # ── fzf (核心 Vim 插件) ──
    if [[ ! -d "$my_plugins/fzf" ]]; then
        info "安装 junegunn/fzf (Vim 插件)..."
        git_clone "https://github.com/junegunn/fzf.git" "$my_plugins/fzf"
    else
        info "junegunn/fzf 已存在，跳过"
    fi

    # ── fzf.vim ──
    if [[ ! -d "$my_plugins/fzf.vim" ]]; then
        info "安装 junegunn/fzf.vim..."
        git_clone "https://github.com/junegunn/fzf.vim.git" "$my_plugins/fzf.vim"
    else
        info "junegunn/fzf.vim 已存在，跳过"
    fi

    # ── vim-which-key ──
    if [[ ! -d "$my_plugins/vim-which-key" ]]; then
        info "安装 liuchengxu/vim-which-key..."
        git_clone "https://github.com/liuchengxu/vim-which-key.git" "$my_plugins/vim-which-key"
    else
        info "liuchengxu/vim-which-key 已存在，跳过"
    fi

    ok "自定义插件安装完成"
}

# ════════════════════════════════════════════════════════════
#  Phase 5: 下载 fzf 二进制 (镜像加速)
# ════════════════════════════════════════════════════════════
install_fzf_binary() {
    local fzf_bin="$HOME/.vim_runtime/my_plugins/fzf/bin/fzf"
    local arch
    arch=$(detect_arch)
    local tar_name="fzf-${FZF_VERSION}-${arch}.tar.gz"
    local url="https://github.com/junegunn/fzf/releases/download/v${FZF_VERSION}/${tar_name}"
    local tmp_file="/tmp/fzf.tar.gz"

    # 检查是否已有足够版本
    if [[ -x "$fzf_bin" ]]; then
        local ver
        ver=$("$fzf_bin" --version 2>/dev/null | grep -oP '[\d.]+' | head -1)
        if [[ "$ver" == "$FZF_VERSION" ]]; then
            ok "fzf binary $FZF_VERSION 已存在，跳过"
            return
        fi
        info "fzf binary 版本 $ver，需要升级到 $FZF_VERSION"
    fi

    info "下载 fzf $FZF_VERSION ($arch) via ${GITHUB_PROXY}..."
    mkdir -p "$HOME/.vim_runtime/my_plugins/fzf/bin"

    # 尝试镜像
    if curl_download "$url" "$tmp_file" 2>&1; then
        tar --no-same-owner -xzf "$tmp_file" -C "$HOME/.vim_runtime/my_plugins/fzf/bin/" 2>/dev/null
        rm -f "$tmp_file"
    else
        warn "镜像下载失败，尝试直连 GitHub..."
        rm -f "$tmp_file"
        curl -fSL --connect-timeout 30 -o "$tmp_file" "$url"
        tar --no-same-owner -xzf "$tmp_file" -C "$HOME/.vim_runtime/my_plugins/fzf/bin/" 2>/dev/null
        rm -f "$tmp_file"
    fi

    if [[ -x "$fzf_bin" ]]; then
        ok "fzf binary: $("$fzf_bin" --version) ✓"
    else
        err "fzf binary 下载失败，请手动下载: $url"
        exit 1
    fi
}

# ════════════════════════════════════════════════════════════
#  Phase 6: 部署 my_configs.vim
# ════════════════════════════════════════════════════════════
deploy_configs() {
    local target="$HOME/.vim_runtime/my_configs.vim"

    info "部署 my_configs.vim..."

    # 脚本所在目录
    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local source="${script_dir}/my_configs.vim"

    if [[ -f "$source" ]]; then
        cp "$source" "$target"
        ok "从 $source 复制 my_configs.vim"
    else
        # 内联写入 (脚本自包含模式)
        cat > "$target" << 'VIMCONFIG'
" ===================================================================
" my_configs.vim — 个人自定义配置 (自动被 ~/.vimrc 加载)
" 编辑后保存即生效，或用 ,ev 快速打开
" ===================================================================


" ===================================================================
" => 剪贴板 (vim-gtk3 编译支持 +clipboard)
" ===================================================================
set clipboard=unnamedplus
" 无图形界面时也能用系统剪贴板
if has('unnamedplus')
    set clipboard=unnamedplus
else
    set clipboard=unnamed
endif


" ===================================================================
" => ack.vim 改用 ripgrep
" ===================================================================
if executable('rg')
    let g:ackprg = 'rg --vimgrep --smart-case'
endif


" ===================================================================
" => fzf 配置 (替代 CtrlP)
" ===================================================================
" 文件查找: Ctrl-P
nmap <C-p> :Files<CR>
" 内容搜索: Ctrl-F ( rg 模糊搜索内容 )
nmap <C-f> :Rg<CR>
" Buffer 列表
nmap <leader>b :Buffers<CR>
" 历史命令
nmap <leader>h :History:<CR>
" fzf 窗口布局: 下方40%
let g:fzf_layout = { 'down': '~40%' }
" 预览窗口 (需要 bat 或 highlight, 没有也正常工作)
let g:fzf_preview_window = ['right:50%', 'ctrl-/']
" 默认选项
let g:fzf_buffers_jump = 1


" ===================================================================
" => 行号 & 光标
" ===================================================================
set number
set relativenumber
set cursorline
set scrolloff=5


" ===================================================================
" => 中文编辑优化
" ===================================================================
set ambiwidth=double
set formatoptions+=mB
" 禁用折叠列 (减少视觉干扰)
set foldcolumn=0


" ===================================================================
" => 签名列常驻 (避免 ALE/sign 切换时宽度抖动)
" ===================================================================
set signcolumn=yes


" ===================================================================
" => lightline: Statusbar + Tabline
" ===================================================================

" ── 禁用简陋的 set_tabline，由 lightline 接管 ──
let g:set_tabline_loaded = 1  " 阻止 set_tabline 加载

" ── Statusline 组件 ──
let g:lightline = {
\   'colorscheme': 'deus',
\   'active': {
\     'left':  [['mode', 'paste'],
\               ['gitbranch', 'readonly', 'filename', 'modified']],
\     'right': [['lineinfo', 'percent'],
\               ['fileformat', 'fileencoding', 'filetype']],
\   },
\   'inactive': {
\     'left':  [['filename', 'modified']],
\     'right': [['lineinfo']],
\   },
\   'component': {
\     'lineinfo':    '㏑ %3l:%-2v',
\     'percent':     '%3p%%',
\     'fileformat':  '[%{&ff}]',
\     'fileencoding':'[%{&fenc!=#""?&fenc:&enc}]',
\     'paste':       '%{&paste?"PASTE":""}',
\   },
\   'component_function': {
\     'filename':  'LightlineFilename',
\     'gitbranch': 'LightlineGitBranch',
\     'mode':      'LightlineMode',
\   },
\   'component_visible_condition': {
\     'readonly':  '&readonly',
\     'modified':  '&modified',
\     'paste':     '&paste',
\   },
\   'separator':    { 'left': '', 'right': '' },
\   'subseparator': { 'left': '|', 'right': '|' },
\ }

" 文件名: 相对路径 + 修改/只读标记
function! LightlineFilename()
    let fname = expand('%:t')
    if fname ==# ''
        return '[No Name]'
    endif
    let ro = &readonly ? '  ' : ''
    let mod = &modified ? ' +' : ''
    let path = expand('%:h')
    if path !=# '.' && path !=# expand('%:p:h:~')
        let fname = expand('%:~:.')
    endif
    return fname . ro . mod
endfunction

" Git 分支 (依赖 fugitive)
function! LightlineGitBranch()
    if exists('*fugitive#head')
        let branch = fugitive#head()
        return branch !=# '' ? '  ' . branch : ''
    endif
    return ''
endfunction

" 模式名称大写
function! LightlineMode()
    let l:mode_map = {
        \ 'n':      'NORMAL',
        \ 'i':      'INSERT',
        \ 'R':      'REPLACE',
        \ 'v':      'VISUAL',
        \ 'V':      'V-LINE',
        \ "\<C-v>": 'V-BLOCK',
        \ 'c':      'COMMAND',
        \ 's':      'SELECT',
        \ 'S':      'S-LINE',
        \ "\<C-s>": 'S-BLOCK',
        \ 't':      'TERMINAL',
        \ }
    let l:mode = get(l:mode_map, mode(), mode())
    return l:mode
endfunction

" ── Tabline: tab 标签页 ──
let g:lightline.tabline = {
\   'left':  [['buffers']],
\   'right': [['close']],
\ }
let g:lightline.tabline_subseparator = { 'left': '|', 'right': '|' }

function! TabName(n)
    let buflist = tabpagebuflist(a:n)
    let winnr = tabpagewinnr(a:n)
    let fname = bufname(buflist[winnr - 1])
    let fname = fnamemodify(fname, ':t')
    if fname ==# ''
        let fname = '[No Name]'
    endif
    return a:n . ':' . fname
endfunction

let g:lightline.tabline_component_function = {
\   'buffers': 'LightlineBuffers',
\   'close':   'LightlineClose',
\ }

function! LightlineBuffers()
    let b = ''
    let n = tabpagenr('$')
    let i = 1
    while i <= n
        let buf = tabpagebuflist(i)
        let win = tabpagewinnr(i)
        let name = bufname(buf[win-1])
        if name ==# ''
            let name = '[No Name]'
        else
            let name = fnamemodify(name, ':t')
        endif
        if len(name) > 20
            let name = strpart(name, 0, 17) . '...'
        endif
        let mod = getbufvar(buf[win-1], '&modified') ? '+' : ''
        let sep = i < n ? ' ' : ''
        let b .= i . ':' . name . mod . sep
        let i += 1
    endwhile
    return b
endfunction

function! LightlineClose()
    return tabpagenr('$') > 1 ? 'X' : ''
endfunction

" 始终显示 tabline
set showtabline=2


" ===================================================================
" => Markdown / Text 自动折行
" ===================================================================
autocmd FileType markdown setlocal wrap linebreak nolist
autocmd FileType text setlocal wrap linebreak nolist
autocmd FileType gitcommit setlocal wrap linebreak nolist


" ===================================================================
" => 粘贴模式快捷键
" ===================================================================
set pastetoggle=<F2>


" ===================================================================
" => auto-pairs 改进: 跳过右括号
" ===================================================================
let g:AutoPairsFlyMode = 1


" ===================================================================
" => 窗口大小
" ===================================================================
set winwidth=84
set winheight=5
set winminheight=5
set winminwidth=10
set helpheight=15


" ===================================================================
" => 快捷键
" ===================================================================
" 快速编辑本配置文件
nnoremap <leader>ev :e ~/.vim_runtime/my_configs.vim<CR>
autocmd! bufwritepost ~/.vim_runtime/my_configs.vim source %

" 快速退出
nnoremap <leader>q :q<CR>
nnoremap <leader>Q :qa!<CR>

" 取消高亮 (替代原来的 ,<CR>)
nnoremap <leader>ch :nohlsearch<CR>

" 重新加载 .vimrc
nnoremap <leader>sv :source ~/.vimrc<CR>


" ===================================================================
" => YankStack 保留 Ctrl-P/Ctrl-N (与 fzf 冲突, 改用 Alt)
" ===================================================================
" fzf 占用了 Ctrl-P, YankStack 改用 Alt-p/Alt-n
let g:yankstack_yank_keys = ['y', 'd']
" 注释掉原有 Ctrl-p/Ctrl-N 映射，改用 Alt
nunmap <C-p>
nunmap <C-n>
nmap <A-p> <Plug>yankstack_substitute_older_paste
nmap <A-n> <Plug>yankstack_substitute_newer_paste


" ===================================================================
" => ALE 精简: 日常编辑不需要实时 lint
" ===================================================================
" 只保留 Python lint
let g:ale_linters = {
\   'python': ['flake8'],
\}
let g:ale_set_highlights = 0
let g:ale_lint_on_text_changed = 'never'
let g:ale_lint_on_enter = 0
let g:ale_virtualtext_cursor = 'disabled'


" ===================================================================
" => which-key: 按 leader 键后弹出快捷键提示
" ===================================================================
set timeoutlen=500

let g:which_key_map = {}

" --- 查找 & 搜索 ---
let g:which_key_map.f = {
      \ 'name': '+find',
      \ 'f': ['Files',        'fzf 文件查找'],
      \ 'b': ['Buffers',      'fzf buffer 列表'],
      \ 'h': ['History:',     '命令历史'],
      \ }

" --- NERDTree ---
let g:which_key_map.n = {
      \ 'name': '+NERDTree',
      \ 'n': ['NERDTreeToggle',  '切换文件树'],
      \ 'f': ['NERDTreeFind',    '定位当前文件'],
      \ }

" --- Tab 管理 ---
let g:which_key_map.t = {
      \ 'name': '+tab',
      \ 'n': ['tabnew',        '新建 tab'],
      \ 'c': ['tabclose',      '关闭 tab'],
      \ 'o': ['tabonly',       '只保留当前 tab'],
      \ 'm': ['tabmove',       '移动 tab'],
      \ }

" --- Git ---
let g:which_key_map.d = ['GitGutterToggle', 'Git diff 标记开关']
let g:which_key_map.v = ['GBrowse!', '复制 GitHub 链接']

" --- 搜索 & 替换 ---
let g:which_key_map.g = ['Ack ', '项目搜索 (rg)']
let g:which_key_map.c = {
      \ 'name': '+quickfix',
      \ 'c': ['botright cope', '打开结果面板'],
      \ 'n': ['cn',            '下一个结果'],
      \ 'p': ['cp',            '上一个结果'],
      \ }

" --- 拼写检查 ---
let g:which_key_map.s = {
      \ 'name': '+spell',
      \ 's': ['setlocal spell!', '开关拼写检查'],
      \ 'n': [']s',               '下一个错误'],
      \ 'p': ['[s',               '上一个错误'],
      \ 'a': ['zg',               '添加到词典'],
      \ '?': ['z=',               '建议替换'],
      \ }

" --- 工具 & 杂项 ---
let g:which_key_map.z = ['Goyo', '专注模式']
let g:which_key_map.pp = ['setlocal paste!', '粘贴模式']
let g:which_key_map.a = ['ale_next_wrap', '下一个 ALE 错误']

" --- 编辑配置 ---
let g:which_key_map.e = {
      \ 'name': '+edit-config',
      \ 'v': ['e ~/.vim_runtime/my_configs.vim', '编辑 my_configs.vim'],
      \ }

" --- 退出 ---
let g:which_key_map.q = ['q', '退出']
let g:which_key_map.Q = ['qa!', '强制退出所有']

" --- 其他单键 ---
let g:which_key_map.w = ['w!', '保存']
let g:which_key_map.o = ['BufExplorer', 'Buffer 列表']
let g:which_key_map['<CR>'] = ['nohlsearch', '取消搜索高亮']

call which_key#register(',', 'g:which_key_map')

" leader 键触发 which-key (普通 & 可视模式)
nnoremap <silent> <leader> :<c-u>WhichKey ','<CR>
vnoremap <silent> <leader> :<c-u>WhichKeyVisual ','<CR>


" ===================================================================
" => 速查表: ,? 打开完整功能参考
" ===================================================================
nnoremap <leader>? :call <SID>OpenCheatsheet()<CR>

function! s:OpenCheatsheet() abort
    " 在新 tab 中打开速查表
    tabnew
    setlocal buftype=nofile bufhidden=wipe noswapfile nobuflisted
    setlocal modifiable
    setlocal nonumber norelativenumber

    " 定义内容
    let lines = [
    \ '',
    \ '  ╔══════════════════════════════════════════════════════════════╗',
    \ '  ║              Vim 配置速查表 (my_configs.vim)                ║',
    \ '  ║              按 q 关闭 | 按 ,? 随时重新打开                ║',
    \ '  ╚══════════════════════════════════════════════════════════════╝',
    \ '',
    \ '',
    \ '  ━━ 基础操作 ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━',
    \ '',
    \ '    Ctrl-P          fzf 文件查找',
    \ '    Ctrl-F          fzf 内容搜索 (rg)',
    \ '    ,b              fzf Buffer 列表',
    \ '    ,h              命令历史 (fzf)',
    \ '    Space           进入搜索 (/)',
    \ '    ,ch             取消搜索高亮',
    \ '',
    \ '    Ctrl-h/j/k/l    窗口间跳转',
    \ '    0               跳到行首非空字符',
    \ '    Alt-j / Alt-k   上下移动当前行',
    \ '',
    \ '    ,w              保存',
    \ '    ,q              退出',
    \ '    ,Q              强制退出所有',
    \ '    ,sv             重新加载 .vimrc',
    \ '',
    \ '    F2              切换粘贴模式',
    \ '    F5              编译运行当前文件',
    \ '',
    \ '',
    \ '  ━━ surround (括号/引号操作) ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━',
    \ '',
    \ '    ds"             删除两侧双引号',
    \ '    ds''             删除两侧单引号',
    \ '    ds(  / ds)      删除两侧小括号',
    \ '    ds[  / ds]      删除两侧中括号',
    \ '    ds{  / ds}      删除两侧大括号',
    \ '',
    \ '    cs"''            将 "..." 改为 ''...''',
    \ '    cs"(            将 "..." 改为 (...)',
    \ '    cs"[            将 "..." 改为 [...]',
    \ '    cs"{            将 "..." 改为 {...}',
    \ '    cs)]            将 [...] 改为 (...)',
    \ '    cst<            将 HTML tag 改为 <...>',
    \ '',
    \ '    ysiw"           给当前单词加双引号: "word"',
    \ '    ysiw(           给当前单词加括号: (word)',
    \ '    yss"            给整行加双引号',
    \ '    yss(            给整行加括号',
    \ '    ysiw]           给当前单词加中括号: [word]',
    \ '',
    \ '    Visual 选中后:',
    \ '      S"            包裹为 "..."',
    \ '      S(            包裹为 (...)',
    \ '      S[            包裹为 [...]',
    \ '      S{            包裹为 {...}',
    \ '',
    \ '',
    \ '  ━━ 插入模式缩写 ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━',
    \ '',
    \ '    $1  →  ()       $2  →  []       $3  →  {}',
    \ '    $4  →  {\n}     $q  →  ''       $e  →  ""',
    \ '    xdate → 当前日期时间',
    \ '',
    \ '',
    \ '  ━━ 多光标 ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━',
    \ '',
    \ '    Ctrl-S          选中下一个相同单词 (开始多光标)',
    \ '    Alt-S           选中所有相同单词',
    \ '    Ctrl-X          跳过当前匹配',
    \ '    Esc             退出多光标',
    \ '',
    \ '',
    \ '  ━━ YankStack (粘贴历史) ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━',
    \ '',
    \ '    Alt-p           粘贴上一个 yank 历史',
    \ '    Alt-n           粘贴下一个 yank 历史',
    \ '',
    \ '',
    \ '  ━━ 项目搜索 ack (rg) ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━',
    \ '',
    \ '    ,g {query}      搜索关键词',
    \ '    Visual + gv     用选中文字搜索',
    \ '    Visual + ,r     用选中文字替换',
    \ '    ,cc             打开结果面板 (quickfix)',
    \ '    ,n / ,p         下一个/上一个结果',
    \ '',
    \ '',
    \ '  ━━ NERDTree 文件树 ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━',
    \ '',
    \ '    ,nn             切换文件树',
    \ '    ,nf             定位当前文件',
    \ '',
    \ '',
    \ '  ━━ Tab 管理 ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━',
    \ '',
    \ '    ,tn             新建 tab',
    \ '    ,tc             关闭 tab',
    \ '    ,to             只保留当前 tab',
    \ '    ,tm             移动 tab',
    \ '    ,t<Tab>         下一个 tab',
    \ '    ,tl             上一个 tab',
    \ '    ,te             在当前目录新 tab',
    \ '',
    \ '',
    \ '  ━━ 拼写检查 ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━',
    \ '',
    \ '    ,ss             开关拼写检查',
    \ '    ,sn / ,sp       下一个/上一个拼写错误',
    \ '    ,sa             添加到词典',
    \ '    ,s?             建议替换',
    \ '',
    \ '',
    \ '  ━━ Git ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━',
    \ '',
    \ '    ,d              切换 Git diff 标记',
    \ '    ,v              复制当前行 GitHub 链接',
    \ '',
    \ '',
    \ '  ━━ 注释 (vim-commentary) ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━',
    \ '',
    \ '    gcc             注释/取消注释当前行',
    \ '    gc{motion}      注释选中区域 (如 gcip 注释整个段落)',
    \ '    Visual + gc     注释选中区域',
    \ '',
    \ '',
    \ '  ━━ 专注 & 其他 ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━',
    \ '',
    \ '    ,z              Goyo 专注模式',
    \ '    ,a              下一个 ALE 错误',
    \ '    ,o              bufExplorer (buffer 列表)',
    \ '    :W              sudo 保存',
    \ '',
    \ '',
    \ '  ━━ Python 特有 ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━',
    \ '',
    \ '    $r → return     $i → import    $p → print',
    \ '    $f → # ---      ,1 → /class    ,2 → /def',
    \ '',
    \ '',
    \ '  ━━ 命令行缩写 ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━',
    \ '',
    \ '    $h  →  e ~/                 $d  →  e ~/Desktop/',
    \ '    $j  →  e ./                 $c  →  e <当前目录>/',
    \ '    $q  →  删除到最后一个 /     Ctrl-A/E  →  行首/行尾',
    \ '',
    \ '',
    \ '  ━━ 速查表操作 ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━',
    \ '',
    \ '    q               关闭速查表',
    \ '    ,?              重新打开速查表',
    \ '    /{关键词}       在速查表中搜索',
    \ '',
    \ ]

    call setline(1, lines)
    setlocal nomodifiable readonly

    " 映射 q 关闭
    nnoremap <buffer> <silent> q :tabclose<CR>
    " 映射 ,? 关闭并重新打开
    nnoremap <buffer> <silent> ,? :tabclose<CR>:call <SID>OpenCheatsheet()<CR>

    " 高亮标题
    syntax match CheatsheetTitle '  ╔.*╗'  contains=@NoSpell
    syntax match CheatsheetTitle '  ╚.*╝'  contains=@NoSpell
    syntax match CheatsheetSection '  ━━.*━━━'  contains=@NoSpell
    highlight default CheatsheetTitle ctermfg=214 cterm=bold
    highlight default CheatsheetSection ctermfg=111 cterm=bold
endfunction
VIMCONFIG
        ok "已内联写入 my_configs.vim"
    fi
}

# ════════════════════════════════════════════════════════════
#  Phase 7: 配置 PATH
# ════════════════════════════════════════════════════════════
setup_path() {
    local fzf_bin_dir="$HOME/.vim_runtime/my_plugins/fzf/bin"
    local marker='fzf binary (vim plugin bundled)'

    # 检查是否已在 PATH / bashrc 中
    if [[ -f "$HOME/.bashrc" ]] && grep -q "$marker" "$HOME/.bashrc"; then
        ok "PATH 已配置，跳过"
        return
    fi

    info "将 fzf bin 目录加入 PATH..."

    # 写入所有支持的 shell 配置
    for rc in "$HOME/.bashrc" "$HOME/.zshrc" "$HOME/.profile"; do
        if [[ -f "$rc" ]]; then
            echo "" >> "$rc"
            echo "# $marker" >> "$rc"
            echo "export PATH=\"$fzf_bin_dir:\$PATH\"" >> "$rc"
        fi
    done

    # 当前 session 也生效
    export PATH="$fzf_bin_dir:$PATH"

    ok "PATH 配置完成 (重启 shell 后全局生效)"
}

# ════════════════════════════════════════════════════════════
#  Phase 8: 验证
# ════════════════════════════════════════════════════════════
verify() {
    info "验证安装..."
    local errors=0

    # vim + clipboard
    if vim --version 2>/dev/null | grep -q '+clipboard'; then
        ok "vim +clipboard"
    else
        warn "vim 无 clipboard 支持"
        ((errors++))
    fi

    # ripgrep
    if command -v rg &>/dev/null; then
        ok "ripgrep $(rg --version | head -1)"
    else
        err "ripgrep 未找到"
        ((errors++))
    fi

    # fzf binary
    local fzf_bin="$HOME/.vim_runtime/my_plugins/fzf/bin/fzf"
    if [[ -x "$fzf_bin" ]]; then
        ok "fzf $($fzf_bin --version)"
    else
        err "fzf binary 未找到"
        ((errors++))
    fi

    # vimrc 框架
    if [[ -f "$HOME/.vimrc" ]]; then
        ok "~/.vimrc 存在"
    else
        err "~/.vimrc 不存在"
        ((errors++))
    fi

    # my_configs.vim
    if [[ -f "$HOME/.vim_runtime/my_configs.vim" ]]; then
        ok "my_configs.vim 已部署"
    else
        err "my_configs.vim 未找到"
        ((errors++))
    fi

    # 插件目录
    for p in fzf fzf.vim vim-which-key; do
        if [[ -d "$HOME/.vim_runtime/my_plugins/$p" ]]; then
            ok "插件 $p"
        else
            err "插件 $p 未找到"
            ((errors++))
        fi
    done

    # vim 启动测试
    if vim -N -es -u ~/.vimrc -c 'echo "test"' -c 'qa!' 2>/dev/null; then
        ok "vim 启动无错误"
    else
        err "vim 启动有错误，请运行 vim 查看详情"
        ((errors++))
    fi

    echo ""
    if [[ $errors -eq 0 ]]; then
        echo -e "${GREEN}═══════════════════════════════════════════════${NC}"
        echo -e "${GREEN}  全部检查通过 ✓  打开 vim 试试吧！${NC}"
        echo -e "${GREEN}═══════════════════════════════════════════════${NC}"
    else
        echo -e "${YELLOW}═══════════════════════════════════════════════${NC}"
        echo -e "${YELLOW}  $errors 项检查未通过，请查看上方日志${NC}"
        echo -e "${YELLOW}═══════════════════════════════════════════════${NC}"
    fi
}

# ════════════════════════════════════════════════════════════
#  帮助
# ════════════════════════════════════════════════════════════
usage() {
    cat << 'EOF'
setup-vim.sh — 一键部署 amix/vimrc + 个人配置

用法:
  bash setup-vim.sh              全新安装 (系统依赖 + 框架 + 插件 + 配置)
  bash setup-vim.sh --skip-base  跳过 amix/vimrc 框架安装 (已有时)
  bash setup-vim.sh --deploy-only 仅部署 my_configs.vim + 自定义插件

环境变量:
  GITHUB_PROXY  GitHub 下载镜像 (默认: https://gh-proxy.com)
  GIT_PROXY     Git clone 镜像前缀 (默认: 空，直连)
                设置示例: export GIT_PROXY=https://ghfast.top

镜像备选:
  https://gh-proxy.com
  https://ghfast.top
  https://mirror.ghproxy.com
EOF
}

# ════════════════════════════════════════════════════════════
#  Main
# ════════════════════════════════════════════════════════════
main() {
    local mode="full"

    case "${1:-}" in
        --help|-h)
            usage
            exit 0
            ;;
        --skip-base)
            mode="skip-base"
            ;;
        --deploy-only)
            mode="deploy-only"
            ;;
        "")
            mode="full"
            ;;
        *)
            err "未知参数: $1"
            usage
            exit 1
            ;;
    esac

    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║   Vim 配置一键部署                      ║${NC}"
    echo -e "${CYAN}║   模式: $mode                              ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════╝${NC}"
    echo ""

    case "$mode" in
        full)
            install_system_deps
            install_vimrc_base
            cleanup_plugins
            install_custom_plugins
            install_fzf_binary
            deploy_configs
            setup_path
            verify
            ;;
        skip-base)
            cleanup_plugins
            install_custom_plugins
            install_fzf_binary
            deploy_configs
            setup_path
            verify
            ;;
        deploy-only)
            install_custom_plugins
            install_fzf_binary
            deploy_configs
            setup_path
            verify
            ;;
    esac
}

main "$@"
