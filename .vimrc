
" .----------------.  .----------------.  .----------------.  .----------------.  .----------------. 
"| .--------------. || .--------------. || .--------------. || .--------------. || .--------------. |
"| | ____   ____  | || |     _____    | || | ____    ____ | || |  _______     | || |     ______   | |
"| ||_  _| |_  _| | || |    |_   _|   | || ||_   \  /   _|| || | |_   __ \    | || |   .' ___  |  | |
"| |  \ \   / /   | || |      | |     | || |  |   \/   |  | || |   | |__) |   | || |  / .'   \_|  | |
"| |   \ \ / /    | || |      | |     | || |  | |\  /| |  | || |   |  __ /    | || |  | |         | |
"| |    \ ' /     | || |     _| |_    | || | _| |_\/_| |_ | || |  _| |  \ \_  | || |  \ `.___.'\  | |
"| |     \_/      | || |    |_____|   | || ||_____||_____|| || | |____| |___| | || |   `._____.'  | |
"| |              | || |              | || |              | || |              | || |              | |
"| '--------------' || '--------------' || '--------------' || '--------------' || '--------------' |
" '----------------'  '----------------'  '----------------'  '----------------'  '----------------' 
"
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
    "Plugin 'myusuf3/numbers.vim'
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
Plugin 'adelarsq/vim-grimmjow'
Plugin 'lifepillar/vim-solarized8'
Plugin 'lifepillar/vim-wwdc16-theme'

Plugin 'mattn/emmet-vim'

Plugin 'uguu-org/vim-matrix-screensaver'
Plugin 'szw/vim-maximizer'

"multiple cursor
Plugin 'terryma/vim-multiple-cursors'
"Visualization of code indentation
"Plugin 'nathanaelkane/vim-indent-guides'

"Switch between .c and .h
Plugin 'vim-scripts/a.vim'
Plugin 'derekwyatt/vim-fswitch'

Plugin 't9md/vim-choosewin'

"mark sign
Plugin 'kshenoy/vim-signature'
"Plugin 'vim-scripts/BOOKMARKS--MARK-and-Highlight-Full-Lines'

"Find the file contents
Plugin 'yegappan/grep'
Plugin 'mileszs/ack.vim'
Plugin 'dyng/ctrlsf.vim'
Plugin 'rking/ag.vim'
Plugin 'nelstrom/vim-qargs'

"Code comments
Plugin 'scrooloose/nerdcommenter'

if has("win32") || has("win64")
    "Plugin 'fholgado/minibufexpl.vim'
endif

if has("unix")
    Plugin 'wincent/command-t'
    Plugin 'junegunn/fzf'
endif
Plugin 'ctrlpvim/ctrlp.vim'
Plugin 'Shougo/unite.vim'
if has('python') || has('python3')
    Plugin 'Yggdroot/LeaderF'
    Plugin 'FelikZ/ctrlp-py-matcher'
endif

"Programming
Plugin 'majutsushi/tagbar'
if has("unix")
    Plugin 'Valloric/YouCompleteMe'
    "Plugin 'rdnetto/YCM-Generator'
    Plugin 'scrooloose/syntastic'
    Plugin 'SirVer/ultisnips'
endif
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

Plugin 'tpope/vim-fugitive'
Plugin 'tpope/vim-surround'
if has("unix")
    "Local plugins
    "Plugin 'file:///home/genglei/.vim/bundle/indexer', {'pinned': 1}
    "Plugin 'file:///home/genglei/.vim/bundle/dfrank_util',{'pinned': 1}
    "Plugin 'file:///home/genglei/.vim/bundle/vimprj',{'pinned': 1}
    Plugin 'file:///home/genglei/.vim/bundle/gundo',{'pinned': 1}
    Plugin 'file:///home/genglei/.vim/bundle/SingleCompiler',{'pinned': 1}
    Plugin 'file:///home/genglei/.vim/bundle/vcscommand-1.99.47',{'pinned': 1}
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
map <C-x>" ""y
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
nmap <Leader>w_ <C-W>_

nmap <Leader>dd :pwd<CR>

if has("gui_running") && has("unix")
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

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
"mark-2.8.5
"Install :so %
"testtermcolor :runtime syntax/colortest.vim
"MarkPalette extended
function! SourceMarkHighlight()
    "vim7.4 patch 1770 support terminal true color
    if v:version >= 800 || has('patch-7.4.1770')
        let g:mwDefaultHighlightingPalette = 'extended'
        execute "MarkPalette extended"
    else
        if !has('gui_running')
            hi MarkWord1  ctermbg=Darkred      ctermfg=Black
            hi MarkWord2  ctermbg=Darkgreen    ctermfg=Black
            hi MarkWord3  ctermbg=Brown        ctermfg=Black
            hi MarkWord4  ctermbg=Darkblue     ctermfg=Black
            hi MarkWord5  ctermbg=Darkmagenta  ctermfg=Black
            hi MarkWord6  ctermbg=Darkcyan     ctermfg=Black
            hi MarkWord7  ctermbg=Cyan         ctermfg=Black
            hi MarkWord8  ctermbg=Green        ctermfg=Black
            hi MarkWord9  ctermbg=Yellow       ctermfg=Black
            hi MarkWord10 ctermbg=Red          ctermfg=Black
            hi MarkWord11 ctermbg=Magenta      ctermfg=Black
            hi MarkWord12 ctermbg=Blue         ctermfg=Black
            hi MarkWord13 ctermbg=Darkyellow   ctermfg=Black
            hi MarkWord14 ctermbg=lightred     ctermfg=Black
            hi MarkWord15 ctermbg=Lightgreen   ctermfg=Black
            hi MarkWord16 ctermbg=Lightblue    ctermfg=Black
            hi MarkWord17 ctermbg=Lightmagenta ctermfg=Black
            hi MarkWord18 ctermbg=Lightcyan    ctermfg=Black
        endif

        if has("gui_running")
            let g:mwDefaultHighlightingPalette = 'extended'
        endif
    endif
endfunction


nmap <unique> <C-m>n :MarkClear<CR>
nmap <unique> <C-m>m :Marks<CR>
nmap <unique> <C-m>1 <Plug>MarkSearchGroup1Next
nmap <unique> <C-x>1 <Plug>MarkSearchGroup1Prev
nmap <unique> <C-m>2 <Plug>MarkSearchGroup2Next
nmap <unique> <C-x>2 <Plug>MarkSearchGroup2Prev
nmap <unique> <C-m>3 <Plug>MarkSearchGroup3Next
nmap <unique> <C-x>3 <Plug>MarkSearchGroup3Prev
nmap <unique> <C-m>4 <Plug>MarkSearchGroup4Next
nmap <unique> <C-x>4 <Plug>MarkSearchGroup4Prev
nmap <unique> <C-m>5 <Plug>MarkSearchGroup5Next
nmap <unique> <C-x>5 <Plug>MarkSearchGroup5Prev
nmap <unique> <C-m>6 <Plug>MarkSearchGroup6Next
nmap <unique> <C-x>6 <Plug>MarkSearchGroup6Prev
nmap <unique> <C-m>7 <Plug>MarkSearchGroup7Next
nmap <unique> <C-x>7 <Plug>MarkSearchGroup7Prev
nmap <unique> <C-m>8 <Plug>MarkSearchGroup8Next
nmap <unique> <C-x>8 <Plug>MarkSearchGroup8Prev
nmap <unique> <C-m>9 <Plug>MarkSearchGroup9Next
nmap <unique> <C-x>9 <Plug>MarkSearchGroup9Prev
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

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
    autocmd ColorScheme * :call SourceMarkHighlight()
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
    colorscheme solarized8_dark_flat
else
    "set background=dark
    colorscheme solarized8_dark_flat
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
    "resovled when use ctrlsf, youcompleteme crash
    let g:ycm_filetype_blacklist = {
                \ 'tagbar' : 1,
                \ 'qf' : 1,
                \ 'notes' : 1,
                \ 'markdown' : 1,
                \ 'unite' : 1,
                \ 'text' : 1,
                \ 'vimwiki' : 1,
                \ 'pandoc' : 1,
                \ 'infolog' : 1,
                \ 'mail' : 1,
                \ 'ctrlsf': 1
                \}

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
    map <silent> <F6> :YcmDiags<cr>
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
nmap <silent> <leader>hh :TagbarToggle<cr>
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
set fileencodings=utf-8,chinese,gb2312,gbk,gb18030 
if !has('gui_running')
    set termencoding=utf-8  
endif
"auto detect fileformats
"if has('unix')
"    set fileformats=unix  
"elseif has('win32') || has('win64')
"    set fileformats=dos
"endif
set encoding=utf-8
if has('win32') || has('win64')
    set fileencoding=chinese
elseif has('unix')
    set fileencoding=utf-8
endif
set fencs=utf-8,gbk,GB18030,ucs-bom,default,latin1
if has("gui_running")
    if has('unix')
        set guifont=YaHei\ Consolas\ Hybrid\ 11.5
    elseif has('win32') || has('win64')
        set guifont=YaHei_Consolas_Hybrid:h11.5
    endif
    source $VIMRUNTIME/delmenu.vim
    source $VIMRUNTIME/menu.vim
endif
language messages zh_CN.utf-8


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
"Open xml file fold
let g:xml_syntax_folding = 1
" 启动 vim 时关闭折叠代码
set nofoldenable

"a.vim 
"" *.cpp 和 *.h 间切换
nmap <Leader>ch :A<CR>
" 子窗口中显示 *.cpp 或 *.h
nmap <Leader>sch :AS<CR>

"ctrlsf.vim
if has('unix')
    nnoremap <Leader>sf :CtrlSF<CR>
    let g:ctrlsf_ackprg = '/usr/bin/ag'
    let g:ctrlsf_extra_backend_args = {
                \ 'ag': '--ignore "cscope.*"'
                \ }
endif

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
if has('win32') || has('win64')
    let g:ctrlp_user_command = 'dir %s /-n /b /s /a-d' " Windows
elseif has('unix')
    if executable('ag')
        let g:ctrlp_user_command = 'ag %s -l --nocolor -g "" --ignore "*.o"' 
    endif
endif
if has('unix')
    if has('python') || has('python3')
        "Vim8 windows platform when enable this, ctrlp can't find files.
        let g:ctrlp_match_func = {'match': 'pymatcher#PyMatch'}
    endif
endif
let g:ctrlp_custom_ignore = {'file': '\v\.(o|so|dll|a)$'}
if executable("ag") 
    let g:ackprg = 'ag --nogroup --nocolor --column' 
    " Use Ag over Grep 
    set grepprg=ag\ --nogroup\ --nocolor 
    " Use ag in CtrlP for listing files. Lightning fast and respects .gitignore 
    " ag is fast enough that CtrlP doesn't need to cache 
    let g:ctrlp_use_caching = 1 
    if has("unix")
        let g:ctrlp_cache_dir = $HOME.'/.cache/ctrlp'
    endif
endif

"Yggdroot/LeaderF
let g:Lf_CommandMap = {'<C-]>': ['<C-Y>']}
"nnoremap <unique> :Leaderf<CR>
"nnoremap <unique> :LeaderfBuffer<CR>
let g:Lf_ShortcutF = '<leader>gf' 
let g:Lf_ShortcutB = '<leader>gb'
nnoremap <unique> <leader>gm :LeaderfMru<CR>


"cscope mapping keys
nmap <C-m>s :cs find s <C-R>=expand("<cword>")<CR><CR>	
nmap <C-m>g :cs find g <C-R>=expand("<cword>")<CR><CR>	
nmap <C-m>c :cs find c <C-R>=expand("<cword>")<CR><CR>	
nmap <C-m>t :cs find t <C-R>=expand("<cword>")<CR><CR>	
nmap <C-m>e :cs find e <C-R>=expand("<cword>")<CR><CR>	
nmap <C-m>f :cs find f <C-R>=expand("<cfile>")<CR><CR>	
nmap <C-m>i :cs find i <C-R>=expand("<cfile>")<CR><CR>
nmap <C-m>d :cs find d <C-R>=expand("<cword>")<CR><CR>	
nmap <C-m>a :cs find a <C-R>=expand("<cword>")<CR><CR>	

nmap <C-\>s :scs find s <C-R>=expand("<cword>")<CR><CR>	
nmap <C-\>g :scs find g <C-R>=expand("<cword>")<CR><CR>	
nmap <C-\>c :scs find c <C-R>=expand("<cword>")<CR><CR>	
nmap <C-\>t :scs find t <C-R>=expand("<cword>")<CR><CR>	
nmap <C-\>e :scs find e <C-R>=expand("<cword>")<CR><CR>	
nmap <C-\>f :scs find f <C-R>=expand("<cfile>")<CR><CR>	
nmap <C-\>i :scs find i <C-R>=expand("<cfile>")<CR><CR>	
nmap <C-\>d :scs find d <C-R>=expand("<cword>")<CR><CR>	
nmap <C-\>a :scs find a <C-R>=expand("<cword>")<CR><CR>	

nmap <C-\><C-\>s :vert scs find s <C-R>=expand("<cword>")<CR><CR>
nmap <C-\><C-\>g :vert scs find g <C-R>=expand("<cword>")<CR><CR>
nmap <C-\><C-\>c :vert scs find c <C-R>=expand("<cword>")<CR><CR>
nmap <C-\><C-\>t :vert scs find t <C-R>=expand("<cword>")<CR><CR>
nmap <C-\><C-\>e :vert scs find e <C-R>=expand("<cword>")<CR><CR>
nmap <C-\><C-\>f :vert scs find f <C-R>=expand("<cfile>")<CR><CR>	
nmap <C-\><C-\>i :vert scs find i <C-R>=expand("<cfile>")<CR><CR>	
nmap <C-\><C-\>d :vert scs find d <C-R>=expand("<cword>")<CR><CR>
nmap <C-\><C-\>a :vert scs find a <C-R>=expand("<cword>")<CR><CR>

nmap <C-m>q :set cscopequickfix=s-,c-,d-,i-,t-,e-,a-<CR>
nmap <C-m>Q :set cscopequickfix=<CR>


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

if has("unix") || has('win32') || has('win64')
    if !has('gui_running')
        "fzf
        nmap <leader>zz :FZF . <CR>
    else
        nnoremap <silent> <leader>zz :CtrlP .<CR>
    endif
endif

"autocmd BufWritePost $MYVIMRC source $MYVIMRC

"Replace function Parameter Description：
"confirm:   Confirm whether to replace one by one before
"wholeword: whole-word match
"replace:   replace string
"projectrange:     project range or only current file
function! Replace(projectrange, confirm, wholeword, replace)
    wa
    let flag = ''
    if a:confirm
        let flag .= 'gIec'
    else
        let flag .= 'gIe'
    endif
    let search = ''
    if a:wholeword
        let search .= '\<' . escape(expand('<cword>'), '/\.*$^~[') . '\>'
    else
        let search .= expand('<cword>')
    endif
    let replace = escape(a:replace, '/\&~')

    if a:projectrange
        "vim7.4 patch 858 support cdo cfdo ldo lfdo command
        if v:version >= 800 || has('patch-7.4.858')
            execute 'cfdo %s/' . search . '/' . replace . '/' . flag . '| update'
        else
            execute 'Qargs | argdo %s/' . search . '/' . replace . '/' . flag . '| update'
        endif
    else
        if has("unix")
            execute bufnr('%') . 'bufdo %s/' . search . '/' . replace . '/' . flag . '| update'
        elseif has("win32") || has("win64")
            "Has some thing wrong, Ctrl-C and Esc replace string with null string.
            execute 'args ' . bufname('%') . '|' . 'argdo %s/' . search . '/' . replace . '/' . flag . '| update'
        endif
    endif
endfunction
"Current file, no confirm, whole word
nmap <unique> <C-x>r :call Replace(0, 0, 1, input('Replace '.expand('<cword>').' with: '))<CR>
"Current file, confirm, whole word
nmap <unique> <C-x>R :call Replace(0, 1, 1, input('Replace '.expand('<cword>').' with: '))<CR>
"Current file, no confirm, no whole word
nmap <unique> <C-x>s :call Replace(0, 0, 0, input('Replace '.expand('<cword>').' with: '))<CR>
"Current file, confirm, no whole word
nmap <unique> <C-x>S :call Replace(0, 1, 0, input('Replace '.expand('<cword>').' with: '))<CR>
"Project range, no confirm, whole word
nmap <unique> <c-x>m :call Replace(1, 0, 1, input('Replace '.expand('<cword>').' with: '))<cr>
"Project range, confirm, whole word
nmap <unique> <C-x>M :call Replace(1, 1, 1, input('Replace '.expand('<cword>').' with: '))<CR>
"Project range, no confirm, no whole word
nmap <unique> <c-x>n :call Replace(1, 0, 0, input('Replace '.expand('<cword>').' with: '))<cr>
"Project range, confirm, no whole word
nmap <unique> <c-x>N :call Replace(1, 1, 0, input('Replace '.expand('<cword>').' with: '))<cr>


function! SearchStringFromCurrentFile(ignorecase, context)
    let filename = escape(expand('%'), '() \')
    if a:context
        execute 'CtrlSF ' . expand('<cword>')  . ' ' . filename 
    else
        if has('win32') || has('win64')
            execute 'vimgrep /' . expand('<cword>') . '/gj ' . filename
            execute 'copen'
        else
            execute 'Ag ' . expand('<cword>') . ' ' . filename
        endif
    endif
endfunction
nmap <unique> s :call SearchStringFromCurrentFile(0, 0)<CR>
nmap <unique> S :call SearchStringFromCurrentFile(0, 1)<CR>

"search string in visual mode
function! SearchStringFromCurrentFileInVisualMode(ignorecase, context)
    let search = ''
    let search .= '"' . getline("'<")[getpos("'<")[2]-1:getpos("'>")[2]-1] . '"'
    if a:context
        execute 'CtrlSF ' . search . ' ' .expand('%')
    else
        execute 'Ag ' . search . ' ' . expand('%')
    endif
endfunction
vmap <unique> <C-n>v :call SearchStringFromCurrentFileInVisualMode(0, 0)<CR>
vmap <unique> <C-n>V :call SearchStringFromCurrentFileInVisualMode(0, 1)<CR>

"search string with input
function! SearchStringFromCurrentFileWithInput(ignorecase, context, searchstring)
    let searchstring = escape(a:searchstring, '/\&~')
    if a:context
        execute 'CtrlSF ' . searchstring  . ' ' .expand('%')
    else
        execute 'Ag ' . searchstring . ' ' . expand('%')
    endif
endfunction
nmap <unique> <C-n>s :call SearchStringFromCurrentFileWithInput(0, 0, input('Search string: '))<CR>
nmap <unique> <C-n>S :call SearchStringFromCurrentFileWithInput(0, 1, input('Search string: '))<CR>

function! HighighlightColumn(flag)
    if a:flag
        execute 'set colorcolumn+=' . col('.')
    else
        execute 'set colorcolumn='
    endif
endfunction
map <C-x>h :call HighighlightColumn(1)<CR>
map <C-x>H :call HighighlightColumn(0)<CR>

"Remap s keyword for myself used.
"map s :registers<CR>
"map S :display<CR>


map gz :display<CR>
"Align
vmap g<Space> :'<,'>EasyAlign\<CR>
vmap g1 :'<,'>EasyAlign2\<CR>
vmap g= :'<,'>EasyAlign=<CR>
vmap g2 :'<,'>EasyAlign2=<CR>
vmap g3 :'<,'>EasyAlign\<CR> gv :'<,'>EasyAlign=<CR>
"sudo write
"nmap gy :w !sudo tee %<CR>
"Remove highlighting of search matches
nmap gl :nohlsearch<CR>
"source .vimrc
nmap gx :so ~/.vimrc<CR>

nmap <unique> gc :marks<CR>
"vim-signature
let g:SignatureMap = {
            \ 'Leader'             :  "m",
            \ 'PlaceNextMark'      :  "m,",
            \ 'ToggleMarkAtLine'   :  "m.",
            \ 'PurgeMarksAtLine'   :  "m-",
            \ 'DeleteMark'         :  "dm",
            \ 'PurgeMarks'         :  "m<Space>",
            \ 'PurgeMarkers'       :  "m<BS>",
            \ 'GotoNextLineAlpha'  :  "']",
            \ 'GotoPrevLineAlpha'  :  "'[",
            \ 'GotoNextSpotAlpha'  :  "sn",
            \ 'GotoPrevSpotAlpha'  :  "sm",
            \ 'GotoNextLineByPos'  :  "]'",
            \ 'GotoPrevLineByPos'  :  "['",
            \ 'GotoNextSpotByPos'  :  "sj",
            \ 'GotoPrevSpotByPos'  :  "sk",
            \ 'GotoNextMarker'     :  "ss",
            \ 'GotoPrevMarker'     :  "SS",
            \ 'GotoNextMarkerAny'  :  "sf",
            \ 'GotoPrevMarkerAny'  :  "sb",
            \ 'ListLocalMarks'     :  "m/",
            \ 'ListLocalMarkers'   :  "m?"
            \ }

if has('unix')
    "vcscommand
    let g:VCSCommandMapPrefix = '<C-s>'
endif

nmap <unique> <C-j> :normal @:<CR>
"quickfix mapping
"nmap <unique> <C-h>qo :copen<CR>
"nmap <unique> <C-h>qc :cclose<CR>
"nmap <unique> <C-h>qj :cnext<CR>
"nmap <unique> <C-h>qk :cprevious<CR>
"nmap <unique> <C-h>qf :cfirst<CR>
"nmap <unique> <C-h>ql :clast<CR>

"Add file search path
function! SetSearchFilePath(mode)
    if a:mode
        execute 'set path+=' . getcwd() . '/**'
    else
        execute 'set path-=' . getcwd() . '/**'
    endif
endfunction
nmap <unique> <C-x>p :call SetSearchFilePath(1)<CR>
nmap <unique> <C-x>P :call SetSearchFilePath(0)<CR>

"Copy current filename
nmap <unique> <C-x>g :let @+ = expand("%:t")<CR>
nmap <unique> <C-x>G :let @+ = expand("%")<CR>
nmap <unique> g<C-x> :let @+ = expand("%:p")<CR>
nmap <unique> gy :let @+ = expand('<cword>')<CR>
nmap <unique> gY :let @+ = expand('<cWORD>')<CR>

"vim7.4 patch 1770 support terminal true color
if v:version >= 800 || has('patch-7.4.1770')
    set termguicolors
    execute "set t_8f=\e[38;2;%lu;%lu;%lum"
    execute "set t_8b=\e[48;2;%lu;%lu;%lum"
endif

map <unique><silent> <F2> :Matrix<cr>

"choosewin plugin
nmap  -  <Plug>(choosewin)
nmap <Leader>wc <Plug>(choosewin)
let g:choosewin_overlay_enable = 1

"toggle window
nmap <Leader>wz :MaximizerToggle!<CR>

