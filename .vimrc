set nocompatible              " be iMproved, required
filetype off                  " required

" set the runtime path to include Vundle and initialize
if has("unix")
    set rtp+=~/.vim/bundle/Vundle.vim
    call vundle#begin()
elseif has("win32") || has("win64")
    set rtp+=$HOME/vimfiles/bundle/Vundle.vim/
    call vundle#begin('$HOME/vimfiles/bundle/')
endif
" alternatively, pass a path where Vundle should install plugins
"call vundle#begin('~/some/path/here')

" let Vundle manage Vundle, required
Plugin 'gmarik/Vundle.vim'
if has("win32") || has("win64")
    Plugin 'myusuf3/numbers.vim'
endif
"file explorer
Plugin 'scrooloose/nerdtree'

"colorschemes
Plugin 'google/vim-colorscheme-primary'
Plugin 'tomasr/molokai'
Plugin 'altercation/vim-colors-solarized'
Plugin 'nanotech/jellybeans.vim'
Plugin 'vim-scripts/tabula.vim'
Plugin 'morhetz/gruvbox'
Plugin 'hukl/Smyck-Color-Scheme'
Plugin 'flazz/vim-colorschemes'

Plugin 'mattn/emmet-vim'


"multiple cursor
Plugin 'terryma/vim-multiple-cursors'
"Visualization of code indentation
"Plugin 'nathanaelkane/vim-indent-guides'

"Switch between .c and .h
Plugin 'vim-scripts/a.vim'

"mark sign
Plugin 'kshenoy/vim-signature'

"Find the file contents
Plugin 'yegappan/grep'
Plugin 'mileszs/ack.vim'
Plugin 'dyng/ctrlsf.vim'
Plugin 'rking/ag.vim'
Plugin 'nelstrom/vim-qargs'

"Code comments
Plugin 'scrooloose/nerdcommenter'

if has("win32") || has("win64")
    Plugin 'fholgado/minibufexpl.vim'
endif

if has("unix")
    Plugin 'wincent/command-t'
    Plugin 'junegunn/fzf'
endif
Plugin 'ctrlpvim/ctrlp.vim'

"Programming
Plugin 'majutsushi/tagbar'
if has("unix")
    Plugin 'Valloric/YouCompleteMe'
    "Plugin 'rdnetto/YCM-Generator'
    Plugin 'scrooloose/syntastic'
endif
Plugin 'SirVer/ultisnips'
" Snippets are separated from the engine. Add this if you want them:
Plugin 'honza/vim-snippets'

Plugin 'gcmt/wildfire.vim'

"comment
Plugin 'dhruvasagar/vim-table-mode'
Plugin 'vim-scripts/DrawIt'

if has("unix")
    "Status bar
    Plugin 'powerline/fonts'
    Plugin 'bling/vim-airline'
endif

Plugin 'mhinz/vim-startify'
Plugin 'itchyny/calendar.vim'

Plugin 'Lokaltog/vim-easymotion'

"Column alignment
Plugin 'junegunn/vim-easy-align'
Plugin 'godlygeek/tabular'

if has("unix")
    "markdown
    Plugin 'suan/vim-instant-markdown'
    "
    "Plugin 'lilydjwg/fcitx.vim'
endif

if has("unix")
    "Local plugins
    "Plugin 'file:///home/genglei/.vim/bundle/indexer', {'pinned': 1}
    "Plugin 'file:///home/genglei/.vim/bundle/dfrank_util',{'pinned': 1}
    "Plugin 'file:///home/genglei/.vim/bundle/vimprj',{'pinned': 1}
    Plugin 'file:///home/genglei/.vim/bundle/gundo',{'pinned': 1}
    Plugin 'file:///home/genglei/.vim/bundle/SingleCompiler',{'pinned': 1}
    "Plugin 'file:///home/genglei/.vim/bundle/CSApprox',{'pinned': 1}
    " All of your Plugins must be added before the following line
endif

if has("unix")
    call vundle#end()            " required
elseif has("win32") || has("win64")
    call vundle#end()
endif
filetype plugin indent on    " required
" To ignore plugin indent changes, instead use:
"filetype plugin on
"
" Brief help
" :PluginList       - lists configured plugins
" :PluginInstall    - installs plugins; append `!` to update or just :PluginUpdate
" :PluginSearch foo - searches for foo; append `!` to refresh local cache
" :PluginClean      - confirms removal of unused plugins; append `!` to auto-approve removal
"
" see :h vundle for more details or wiki for FAQ
" Put your non-Plugin stuff after this line
"


" An example for a vimrc file.
"
" Maintainer:	Bram Moolenaar <Bram@vim.org>
" Last change:	2011 Apr 15
"
" To use it, copy it to
"     for Unix and OS/2:  ~/.vimrc
"	      for Amiga:  s:.vimrc
"  for MS-DOS and Win32:  $VIM\_vimrc
"	    for OpenVMS:  sys$login:.vimrc

" When started as "evim", evim.vim will already have done these settings.
if v:progname =~? "evim"
    finish
endif

" Use Vim settings, rather than Vi settings (much better!).
" This must be first, because it changes other options as a side effect.
set nocompatible

" allow backspacing over everything in insert mode
set backspace=indent,eol,start

if has("vms")
    set nobackup		" do not keep a backup file, use versions instead
else
    set backup		" keep a backup file
endif
set history=50		" keep 50 lines of command line history
set ruler		" show the cursor position all the time
set showcmd		" display incomplete commands
set incsearch		" do incremental searching

" For Win32 GUI: remove 't' flag from 'guioptions': no tearoff menu entries
" let &guioptions = substitute(&guioptions, "t", "", "g")

" Don't use Ex mode, use Q for formatting
map Q gq

" CTRL-U in insert mode deletes a lot.  Use CTRL-G u to first break undo,
" so that you can undo CTRL-U after inserting a line break.
inoremap <C-U> <C-G>u<C-U>

" In many terminal emulators the mouse works just fine, thus enable it.
if has('mouse')
    set mouse=a
endif

" Switch syntax highlighting on, when the terminal has colors
" Also switch on highlighting the last used search pattern.
set t_Co=256
if &t_Co > 2 || has("gui_running")
    syntax on
    set hlsearch
endif


" Only do this part when compiled with support for autocommands.
if has("autocmd")

    " Enable file type detection.
    " Use the default filetype settings, so that mail gets 'tw' set to 72,
    " 'cindent' is on in C files, etc.
    " Also load indent files, to automatically do language-dependent indenting.
    filetype plugin indent on

    " Put these in an autocmd group, so that we can delete them easily.
    augroup vimrcEx
        au!

        " For all text files set 'textwidth' to 78 characters.
        autocmd FileType text setlocal textwidth=78

        " When editing a file, always jump to the last known cursor position.
        " Don't do it when the position is invalid or when inside an event handler
        " (happens when dropping a file on gvim).
        " Also don't do it when the mark is in the first line, that is the default
        " position when opening a file.
        autocmd BufReadPost *
                    \ if line("'\"") > 1 && line("'\"") <= line("$") |
                    \   exe "normal! g`\"" |
                    \ endif

    augroup END

else

    set autoindent		" always set autoindenting on

endif " has("autocmd")

" Convenient command to see the difference between the current buffer and the
" file it was loaded from, thus the changes you made.
" Only define it when not defined already.
if !exists(":DiffOrig")
    command DiffOrig vert new | set bt=nofile | r ++edit # | 0d_ | diffthis
                \ | wincmd p | diffthis
endif

"Shortcuts prefix <Leader>
let mapleader=";"

"Open filetype detection
filetype on
filetype plugin on

"man cmd
if has("unix")
    source $VIMRUNTIME/ftplugin/man.vim
    nmap <Leader>man :Man 3 <cword><CR>
    nmap <Leader>man2 :Man 2 <cword><CR>
endif


"定义快捷键到行首和行尾
nmap <Leader>lb 0
nmap <Leader>le $
"设置快捷键将选中文本块复制至系统剪贴板
vnoremap <Leader>y "+y
"设置快捷键将系统剪贴板内容粘贴至 vim
nmap <Leader>p "+p
"插入和命令行模式映射粘贴快捷键
map! <C-v> <C-R>+
map <C-x>0 "0y
map <C-x>1 "1y
map <C-x>2 "2y
map <C-x>3 "3y
map <C-x>4 "4y
map <C-x>5 "5y
map <C-x>6 "6y
map <C-x>7 "7y
map <C-x>8 "8y
map <C-x>9 "9y
map <C-x>" ""y
map <C-x>+ "+y
map <C-x>y "+y
map <C-x>x "+y
map <C-x>a "ay
map <C-x>A "Ay
map <C-x>b "by
map <C-x>B "By
map <C-x>c "cy
map <C-x>C "Cy
map <C-x>d "dy
map <C-x>D "Dy
map <C-x>e "ey
map <C-x>E "Ey
map <C-x>f "fy
map <C-x>F "Fy

map <C-n>0 "0p
map <C-n>1 "1p
map <C-n>2 "2p
map <C-n>3 "3p
map <C-n>4 "4p
map <C-n>5 "5p
map <C-n>6 "6p
map <C-n>7 "7p
map <C-n>8 "8p
map <C-n>9 "9p
map <C-n>" ""p
map <C-n>+ "+p
map <C-n>p "+p
map <C-n>n "+p
map <C-n>a "ap
map <C-n>A "Ap
map <C-n>b "bp
map <C-n>B "Bp
map <C-n>c "cp
map <C-n>C "Cp
map <C-n>d "dp
map <C-n>D "Dp
map <C-n>e "ep
map <C-n>E "Ep
map <C-n>f "fp
map <C-n>F "Fp



nmap <Leader>e :e!<CR>
nmap <Leader>q :q<CR>
nmap <Leader>Q :qa!<CR>
nmap <Leader>ww :w<CR>
nmap <Leader>wl 10<C-W><
nmap <Leader>wh 10<C-W>>
nmap <Leader>wj 10<C-W>+
nmap <Leader>wk 10<C-W>-
nmap <Leader>wn <C-W>w
nmap <Leader>wp <C-W>W
nmap <Leader>wr <C-W>p
nmap <Leader>ws <C-W>s
nmap <Leader>wv <C-W>v
nmap <Leader>wt <C-W>T
nmap <Leader>wo <C-W>o
nmap <Leader>wf <C-W>f

nmap <Leader>dd :pwd<CR>

if has("gui_running")
    " 禁止光标闪烁
    "set gcr=a:block-blinkon0
    " " 禁止显示滚动条
    set guioptions-=l
    set guioptions-=L
    set guioptions-=r
    set guioptions-=R
    " " 禁止显示菜单和工具条
    set guioptions-=m
    set guioptions-=T
endif

if has("unix")
    " 将外部命令 wmctrl 控制窗口最大化的命令行参数封装成一个 vim 的函数
    fun! ToggleFullscreen()
        call system("wmctrl -ir " . v:windowid . " -b toggle,fullscreen")
    endf
    "     " 全屏开/关快捷键
    map <silent> <F11> :call ToggleFullscreen()<CR>
    " 启动 vim 时自动全屏
    "autocmd VimEnter * call ToggleFullscreen()
    autocmd ColorScheme * so ~/.vim/plugin/mark.vim
elseif has("win32") || has("win64")
    autocmd ColorScheme * so $HOME/vimfiles/plugin/mark.vim
endif

behave mswin
set nobackup
set nowritebackup
set noswapfile
set nowrapscan
set nu
set nobackup
set ignorecase smartcase
syntax enable
if has("gui_running")
    "light or dark
    "set background=light
    colorscheme molokai 
else
    set background=dark
    colorscheme devbox-dark-256 
endif


"taglist.vim setting
map <silent> <F9> :TlistToggle<CR>
set nocompatible
let Tlist_Show_One_File = 1
let Tlist_Exit_OnlyWindow = 1
let Tlist_Use_Right_Window = 0
"nmap <silent> <leader>tt :TlistToggle<cr>



filetype plugin indent on
set completeopt=longest,menu

" Control Tab behavior
set smartindent
set tabstop=4
set shiftwidth=4
set expandtab

" autocmd FileType make setlocal noexpandtab



"winManager setting
"let g:winManagerWindowLayout = "BufExplorer,FileExplorer|TagList"
"let g:winManagerWindowLayout = "BufExplorer,TagList"
"let g:winManagerWidth = 30
"let g:defaultExplorer = 0
"nmap <C-W><C-F> :FirstExplorerWindow<cr>
"nmap <C-W><C-B> :BottomExplorerWindow<cr>
"nmap <silent> <leader>wm :WMToggle<cr>


"autoload_cscope.vim close macros
let g:autocscope_menus = 0

" " mouse mode
set mouse=a
"
" " highlight current line or column
set cursorline
set cursorcolumn

if has("unix")
    "YouCompleteMe
    "let g:ycm_extra_conf_globlist = ['/home/genglei/*']
    let g:ycm_key_list_select_completion=['<TAB>', '<Down>', '<C-j>', '<C-n>']
    let g:ycm_key_list_previous_completion=['<S-TAB>', '<Up>', '<C-k>', '<C-p>']
    " YCM 补全菜单配色
    " 菜单
    "highlight Pmenu ctermfg=2 ctermbg=3 guifg=#005f87 guibg=#EEE8D5
    " 选中项
    "highlight PmenuSel ctermfg=2 ctermbg=3 guifg=#AFD700 guibg=#106900
    " 补全功能在注释中同样有效
    "let g:ycm_complete_in_comments=1
    " 允许 vim 加载 .ycm_extra_conf.py 文件，不再提示
    let g:ycm_confirm_extra_conf=0
    " 开启 YCM 标签补全引擎
    "let g:ycm_collect_identifiers_from_tags_files=1
    "引入C标准头文件tags
    set tags+=/usr/include/sys.tags
    set tags+=/home/genglei/work/x360/360_project/system/kernel/TAGS
    " 引入 C++ 标准库tags
    "set tags+=/data/misc/software/misc./vim/stdcpp.tags
    " YCM 集成 OmniCppComplete 补全引擎，设置其快捷键
    inoremap <leader>; <C-x><C-o>
    " 补全内容不以分割子窗口形式出现，只显示补全列表
    "set completeopt-=preview
    " 从第一个键入字符就开始罗列匹配项
    "let g:ycm_min_num_of_chars_for_completion=1
    " 禁止缓存匹配项，每次都重新生成匹配项
    "let g:ycm_cache_omnifunc=0
    " 语法关键字补全         
    let g:ycm_seed_identifiers_with_syntax=1
    map <silent> <F5> :YcmForceCompileAndDiagnostics<cr>
endif

"NERDTree
let g:NERDTreeWinPos="right"
nmap <silent> <leader>nn :NERDTreeToggle<cr>


"Command-T
"nmap <silent> <leader>cc :CommandT<cr>
"nmap <silent> <leader>cb :CommandTBuffer<cr>
"nmap <silent> <leader>cm :CommandTMRU<cr>

"airline
"let g:airline_powerline_fonts = 1
"let g:airline#extensions#tabline#enabled = 1
"let g:airline_mode_map = {
"            \ '__' : '-',
"            \ 'n'  : 'N',
"            \ 'i'  : 'I',
"            \ 'R'  : 'R',
"            \ 'c'  : 'C',
"            \ 'v'  : 'V',
"            \ 'V'  : 'V',
"            \ '' : 'V',
"            \ 's'  : 'S',
"            \ 'S'  : 'S',
"            \ '' : 'S',
"            \ }
""设置状态主题风格
"let g:Powerline_colorscheme='solarized256'
"set t_Co=256
"set laststatus=2
"set ttimeoutlen=50

"TagBar
nmap <silent> <leader>tb :TagbarToggle<cr>
" 设置 tagbar 子窗口的位置出现在主编辑区的左边 
let tagbar_left=1 
let g:tagbar_sort = 0

"UltiSnips
" Trigger configuration. Do not use <tab> if you use
" https://github.com/Valloric/YouCompleteMe.
" let g:UltiSnipsExpandTrigger="<tab>"
" let g:UltiSnipsJumpForwardTrigger="<c-b>"
" let g:UltiSnipsJumpBackwardTrigger="<c-z>"
" If you want :UltiSnipsEdit to split your window.
" let g:UltiSnipsEditSplit="vertical"

"Emmet-vim
let g:user_emmet_install_global = 0
autocmd FileType html,css EmmetInstall


"language
"set fileencodings=utf-8,gb2312,gbk,gb18030 
"set termencoding=utf-8  
"set fileformats=unix  
"set encoding=prc
set fencs=utf-8,GB18030,ucs-bom,default,latin1
if has("gui_running")
    set guifont=YaHei\ Consolas\ Hybrid\ 11.5
endif


"可视化代码缩进关联
let g:indent_guides_enable_on_vim_startup=1
" 从第二层开始可视化显示缩进
let g:indent_guides_start_level=2
" 色块宽度
let g:indent_guides_guide_size=1
" 快捷键 i 开/关缩进可视化
:nmap <silent> <Leader>i <Plug>IndentGuidesToggle


" 基于缩进或语法进行代码折叠
"set foldmethod=indent
set foldmethod=syntax
" 启动 vim 时关闭折叠代码
set nofoldenable

"a.vim 
"" *.cpp 和 *.h 间切换
nmap <Leader>ch :A<CR>
" 子窗口中显示 *.cpp 或 *.h
nmap <Leader>sch :AS<CR>

"ctrlsf.vim
nnoremap <Leader>sf :CtrlSF<CR>

"Ag.vim
nnoremap <Leader>aa :Ag<CR>
if has("unix")
    let g:ag_prg='ag --vimgrep --smart-case --ignore "cscope.*" --ignore "*.o"'
endif

"Grep.vim
"nnoremap <silent> <F3> :Grep<CR>
nnoremap <Leader>gr :Grep<CR>
let Grep_Default_Options = '-rnI --exclude-dir=.svn --exclude=cscope.*' 

"Ack.vim
nnoremap <Leader>ac :Ack!<CR>

let NERD_c_alt_style=1

" 显示/隐藏 MiniBufExplorer 窗口
map <Leader>bl :MBEToggle<cr>
"map <Leader>j :MBEbn<cr>
"map <Leader>k :MBEbp<cr>
map <silent> <F7> :MBEbn<cr>
map <silent> <F8> :MBEbp<cr>

if has("unix")
    " 设置插件 indexer 调用 ctags 的参数
    " 默认 --c++-kinds=+p+l，重新设置为 --c++-kinds=+p+l+x+c+d+e+f+g+m+n+s+t+u+v
    " 默认 --fields=+iaS 不满足 YCM 要求，需改为 --fields=+iaSl
    let g:indexer_ctagsCommandLineOptions="--c-kinds=+p+l+x+c+d+e+f+g+m+n+s+t+u+v --fields=+fkstliaSn --extra=+f --language-force=c"
    "let g:indexer_ctagsCommandLineOptions="--c++-kinds=+p+l+x+c+d+e+f+g+m+n+s+t+u+v --fields=+iaSl --extra=+q"
endif


" ctags 
" 正向遍历同名标签
nmap <Leader>tn :tnext<CR>
" 反向遍历同名标签
nmap <Leader>tp :tprevious<CR>
"到第一个匹配
nmap <Leader>tf :tfirst<CR>
"到最后一个匹配
nmap <Leader>tl :tlast<CR>
map <silent> <F9> :tnext<cr>
map <silent> <F10> :tprevious<cr>
"查找标签栈
nmap <Leader><Leader>n :tags<cr>
"跳到最新的标签 tfrist
"nmap <Leader><Leader>f :tag<cr>
"在分隔窗口打开
nmap <Leader><Leader>s :stag<cr>
"预览函数定义
nmap <Leader><Leader>p :ptag<cr>
"列出标签的所有引用
nmap <Leader><Leader>t :tjump<cr>
"查看函数原型
nmap <Leader><Leader>d :psearch<cr>

if has("unix")
    "syntastic 
    let g:syntastic_error_symbol = "✗"
    let g:syntastic_warning_symbol = "⚠"
endif

if has("unix")
    "环境恢复
    " 设置环境保存项
    set sessionoptions="blank,buffers,globals,localoptions,tabpages,sesdir,folds,help,options,resize,winpos,winsize"
    " 保存 undo 历史
    set undodir=~/.undo_history/
    set undofile
    " 保存快捷键
    map <leader>ss :mksession! my.vim<cr> :wviminfo! my.viminfo<cr>
    " 恢复快捷键
    map <leader>rs :source my.vim<cr> :rviminfo my.viminfo<cr>
endif

"快速匹配对结符
" This selects the next closest text object.
map <SPACE> <Plug>(wildfire-fuel)
" This selects the previous closest text object.
vmap <C-SPACE> <Plug>(wildfire-water)

" 调用 gundo 树
nnoremap <Leader>ud :GundoToggle<CR>


if has("unix")
    "SingleCompiler
    nnoremap <Leader>sc :SCCompile<cr>
    nnoremap <Leader>sr :SCCompileRun<cr>
    let g:SingleCompile_showquickfixiferror = 1
endif

if has("unix")
    "Dictionary
    function! Mydict()
        let expl=system('sdcv -n ' .
                    \  expand("<cword>"))
        windo if
                    \ expand("%")=="diCt-tmp" |
                    \ q!|endif
        25vsp diCt-tmp
        setlocal buftype=nofile bufhidden=hide noswapfile
        1s/^/\=expl/
        1
    endfunction
    nmap <Leader>f :call Mydict()<CR>
endif

if has("unix")
    set path+=/usr/include/**
endif


"mark.vim
if has("gui_running")
    let g:mwDefaultHighlightingPalette = 'extended'
endif


"nmap <C-N> :cnext<cr>
"nmap <C-P> :cprevious<cr>

if has("unix")
    "commandT  enconding issue
    let g:CommandTEncoding = 'UTF-8'
    nnoremap <silent> <leader>mr :CommandTMRU<CR>
endif

" use 256 colors in terminal
if !has("gui_running")
    set t_Co=256
    set term=screen-256color
endif

"Ctrlp
nnoremap <silent> <leader>ct :CtrlP .<CR>
let g:ctrlp_match_window = 'bottom,order:ttb,min:1,max:20,results:200'
"let g:ctrlp_prompt_mappings = { 'PrtHistory(-1)': ['<c-p>'] }
"let g:ctrlp_prompt_mappings = { 'PrtHistory(1)': ['<c-n>'] }
"let g:ctrlp_max_history = 0
let g:ctrlp_map = '<F12>'
let g:ctrlp_custom_ignore = {'file': '\v\.(o|so|dll|a)$'}
if executable("ag") 
    let g:ackprg = 'ag --nogroup --nocolor --column' 
    " Use Ag over Grep 
    set grepprg=ag\ --nogroup\ --nocolor 
    " Use ag in CtrlP for listing files. Lightning fast and respects .gitignore 
    let g:ctrlp_user_command = 'ag %s -l --nocolor -g "" --ignore "*.o"' 
    " ag is fast enough that CtrlP doesn't need to cache 
    let g:ctrlp_use_caching = 1 
    if has("unix")
        let g:ctrlp_cache_dir = $HOME.'/.cache/ctrlp'
    endif
endif


"cscope mapping keys
nmap <C-m>s :cs find s <C-R>=expand("<cword>")<CR><CR>	
nmap <C-m>g :cs find g <C-R>=expand("<cword>")<CR><CR>	
nmap <C-m>c :cs find c <C-R>=expand("<cword>")<CR><CR>	
nmap <C-m>t :cs find t <C-R>=expand("<cword>")<CR><CR>	
nmap <C-m>e :cs find e <C-R>=expand("<cword>")<CR><CR>	
nmap <C-m>f :cs find f <C-R>=expand("<cfile>")<CR><CR>	
nmap <C-m>i :cs find i <C-R>=expand("<cfile>")<CR><CR>
nmap <C-m>d :cs find d <C-R>=expand("<cword>")<CR><CR>	


"multiple cursors
let g:multi_cursor_use_default_mapping=0
let g:multi_cursor_start_key='g<C-d>'
let g:multi_cursor_start_word_key='<C-d>'
let g:multi_cursor_next_key='<C-d>'
let g:multi_cursor_prev_key='<C-u>'
let g:multi_cursor_skip_key='<C-x>'
let g:multi_cursor_quit_key='<Esc>'
if has("gui_running")
    set selection=inclusive
endif

if has("unix")
    "fzf
    nmap <leader>zz :FZF . <CR>
endif

"autocmd BufWritePost $MYVIMRC source $MYVIMRC

"Replace function Parameter Description：
"confirm：Confirm whether to replace one by one before
"wholeword：whole-word match
"replace：replace string
function! Replace(confirm, wholeword, replace)
    wa
    let flag = ''
    if a:confirm
        let flag .= 'gec'
    else
        let flag .= 'ge'
    endif
    let search = ''
    if a:wholeword
        let search .= '\<' . escape(expand('<cword>'), '/\.*$^~[') . '\>'
    else
        let search .= expand('<cword>')
    endif
    let replace = escape(a:replace, '/\&~')
    execute bufnr('%') . 'bufdo %s/' . search . '/' . replace . '/' . flag . '| update'
endfunction
"No confirm, no whole word
map <C-x>r :call Replace(0, 0, input('Replace '.expand('<cword>').' with: '))<CR>
"Confirm, no whole word
map <C-x>R :call Replace(1, 0, input('Replace '.expand('<cword>').' with: '))<CR>
"No confirm, whole word
map <C-x>s :call Replace(0, 1, input('Replace '.expand('<cword>').' with: '))<CR>
"Confirm, whole word
map <C-x>S :call Replace(1, 1, input('Replace '.expand('<cword>').' with: '))<CR>
