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
    let ro = &readonly ? ' ' : ''
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

" 模式名称中文化
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

" ── Tabline: buffer 标签页 ──
let g:lightline.tabline = {
\   'left':  [['buffers']],
\   'right': [['close']],
\ }
let g:lightline.tabline_subseparator = { 'left': '|', 'right': '|' }

" Tab 上的 buffer 名称 (显示序号+文件名，过长截断)
let g:lightline#tabline#buffer#display_name = 'tabname'

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

" Tabline 的 buffer 组件使用自定义函数
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
        " 限制名称长度
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
    return tabpagenr('$') > 1 ? '×' : ''
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
    \ '    ds'             删除两侧单引号',
    \ '    ds(  / ds)      删除两侧小括号',
    \ '    ds[  / ds]      删除两侧中括号',
    \ '    ds{  / ds}      删除两侧大括号',
    \ '',
    \ '    cs"\'            将 "..." 改为 \'...\'',
    \ '    cs"(            将 "..." 改为 (...)',
    \ '    cs"[            将 "..." 改为 [...]',
    \ '    cs"{            将 "..." 改为 {...}',
    \ '    cs)]            将 [...] 改为 (...)',
    \ '    cs"(            将 [...] 改为 (...)',
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
