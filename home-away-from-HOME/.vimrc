" Taylor Vance


" Auto-install vim-plug
if empty(glob('~/.vim/autoload/plug.vim'))
    silent !curl -fLo ~/.vim/autoload/plug.vim --create-dirs
        \ https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
    autocmd VimEnter * PlugInstall --sync | source $MYVIMRC
endif

call plug#begin('~/.vim/plugged')
Plug 'junegunn/fzf', { 'do': { -> fzf#install() } }
Plug 'junegunn/fzf.vim'
Plug 'tpope/vim-fugitive'
Plug 'airblade/vim-gitgutter'
Plug 'morhetz/gruvbox'
Plug 'preservim/nerdcommenter'
Plug 'tpope/vim-surround'
Plug 'ervandew/supertab'
call plug#end()


map <space> <leader>

set encoding=utf-8


" << UI >> {{{

colorscheme gruvbox
set background=dark         " use dark background (duh)
set number                  " show line number of current line...
set relativenumber          " ...and relative line number of other lines
set cursorline              " highlight current line
set synmaxcol=1000          " max column to syntax-highlight (for performance)
set showcmd                 " show prev cmd in bottom
set showmode                " if in Insert, Replace, or Visual mode, show in bottom left
set showmatch               " highlight matching bracket
set wrap                    " visually wrap a line if it's wider than the window
set textwidth=0             " but don't insert an actual <EOL> as I'm typing a long line
set linebreak               " don't break words when wrapping
set visualbell              " no beep
set lazyredraw              " prevents redraw for macros, registers, and non-typed cmds
set mouse=a                 " enable mouse in all modes

" < STATUSLINE > {{{
set laststatus=2                " always show the status line
set statusline=
set statusline+=%1*\ %y%*       " file type
set statusline+=%2*\ \ %f%*     " relative filepath
set statusline+=%3*\ \ %m%*     " modified flag
"set statusline+=%{(synIDattr(synID(line("."),col("."),1),"name"))}
"set statusline+=%{SynGrp()}        " TEMP syntax group under cursor
set statusline+=%4*%=%*         " switch to right side
set statusline+=%5*%c%V%*       " col num and virtual col num
set statusline+=%6*\ \ %l/%L%*  " line num and total lines
set statusline+=%7*\ (%p%%)%*   " percentage through file
" statusline coloring
highlight User1 ctermbg=0 ctermfg=8
highlight User2 ctermbg=0 ctermfg=7
highlight User3 ctermbg=0 ctermfg=9 cterm=bold
highlight User4 ctermbg=0
highlight User5 ctermbg=0 ctermfg=12
highlight User6 ctermbg=0 ctermfg=7
highlight User7 ctermbg=0 ctermfg=8
" }}}

" tabs are 4 columns wide, each indentation level is one tab
set tabstop=4 softtabstop=4 shiftwidth=4 noexpandtab

" < FOLDING > {{{
set foldenable              " enable folding
set foldlevelstart=10       " fold very nested indents by default
set foldnestmax=5           " don't let us fold too many folds
set foldmethod=indent       " fold based on indent level
" fold by marker for vim files
augroup filetype_vim
    autocmd!
    autocmd FileType vim setlocal foldmethod=marker
augroup END
" toggle fold
nnoremap <leader>f za
" }}}

" show invisible chars
"set listchars=tab:▸\ ,trail:•,eol:¬
"nnoremap <leader>l :set list!<cr>

" < GITGUTTER > {{{
" toggle number and gitgutter columns (useful for copying text to paste)
nnoremap <leader>nn :call ToggleGutter()<cr>
" if any of the gutters are enabled, disables all of them
" else, enables all of them
function! ToggleGutter()
    if &number || &relativenumber || g:gitgutter_enabled
        set nonumber norelativenumber
        :GitGutterDisable
    else
        set number relativenumber
        :GitGutterEnable
    endif
endfunction
" ignore whitespace changes
let g:gitgutter_diff_args = '-w'
" make gitgutter less of a resource hog
let g:gitgutter_realtime = 0
let g:gitgutter_eager = 0
" but make sure it updates after a write
autocmd BufWritePost * GitGutter
" }}}

" }}}


" << SEARCH >> {{{

set incsearch                       " search as chars are entered
set ignorecase smartcase            " if search string is all lc, ignore case. else, case-sensitive.
set wildmenu                        " enhance cmd-line completion
set wildmode=list:longest,full      " list matches, tab-complete to longest common string, then tab through matches
set wildignore+=*/node_modules/*,*/vendor/*

" quickly clear highlighted search terms
nnoremap <silent> <leader><space> :noh<cr>

" n always goes forward, N always goes backward
nnoremap <expr> n (v:searchforward ? 'n' : 'N')
nnoremap <expr> N (v:searchforward ? 'N' : 'n')

" search by plain text (very nomagic: only \ has special meaning)
nnoremap / /\V

" fzf
" if in git repo, search git files; else, all files
nnoremap <c-t> :execute system('git rev-parse --is-inside-work-tree') =~ 'true' ? 'GFiles' : 'Files'<cr>
" find text in open files
nnoremap <c-f> :Lines<cr>

" }}}


" << NAVIGATION >> {{{

set scrolloff=3         " keep a 3-line pad above and below the cursor

" move cursor by display lines (helps when a line is visually wrapped)
nnoremap k gk
nnoremap j gj

" center vertically when scroll jumping
noremap <c-u> <c-u>zz
noremap <c-d> <c-d>zz

" go to beginning/end of line rather than the window (horizonal rather than vertical)
noremap H ^
noremap L $

" use tab to move to matching bracket
noremap <tab> %

" list buffers
nnoremap gb :Buffers<cr>
" go to buffer last seen in this window (aka alternate file)
nnoremap <c-b> <c-^>
" unload current buffer
nnoremap <leader>bd :bd<cr>

" go to mark (ain't nobody got time for backtick)
noremap gm `

" }}}


" << EDITING >> {{{

set autoindent                          " use the current line's indent
set backspace=indent,eol,start          " allow backspacing

" quick save/quit
nnoremap <leader>w :w<cr>
nnoremap <leader>q :q<cr>

" hit j and k (order doesn't matter) to escape insert mode
inoremap jk <ESC>
inoremap kj <ESC>

" stay in visual mode after left or right shift
vnoremap < <gv
vnoremap > >gv

" make Y behave like C and D (yank from cursor to EOL)
nnoremap Y y$

" maintain clipboard after pasting over something in visual mode
xnoremap p "_dP

" highlight last-pasted text
nnoremap <leader>v V`]
" highlight last-inserted text
"nnoremap <leader>V `[v`]

" open a new line but stay in normal mode at current position
nnoremap <leader>o m`o<esc>``
nnoremap <leader>O m`O<esc>``

" If the unnamed register contains a newline, adjust indent of the pasted text to match the indent around it.
" Else, do a normal paste.
function! MyPaste(char) abort
    if a:char ==? "p"
        if matchstr(@", "\n") == "\n"
            execute "normal! " . a:char . "=']"
        else
            execute "normal! " . a:char
        endif
    endif
endfunction
nnoremap <leader>p :call MyPaste("p")<cr>
nnoremap <leader>P :call MyPaste("P")<cr>

" better line joins
if v:version > 703 || v:version == 703 && has('patch541')
    set formatoptions+=j
endif

" insert current datetime in ISO format
inoremap <c-t> <c-r>=strftime('%Y-%m-%d %H:%M:%S')<c-m>

" show git diff in a split (via fugitive)
nnoremap <leader>gd :Gvdiffsplit<cr>

" reformat associative php array
" expand into multiple lines
":'<,'>s/\[/\[\r/|s/=>/ => /g|s/, /,\r/g|s/\]/,\r\]/
" collapse into one line
":'<,'>s/\n\s*/ /g|s/ => /=>/g|s/, \]/\]/g

" }}}


" << MISC >> {{{

set hidden                              " hide buffers instead of closing them
set ttyfast                             " indicates fast terminal connection
set history=1000                        " cmd-line history

" centralized swap files
if !isdirectory($HOME."/.vim/swapfiles")
    call mkdir($HOME."/.vim/swapfiles", "p")
endif
" ^= prepends, so it's the highest priority
" // stores the path in the filename, to avoid conflicts
set directory^=$HOME/.vim/swapfiles//

" centralized persistent undo files
if !isdirectory($HOME."/.vim/undodir")
    call mkdir($HOME."/.vim/undodir", "p")
endif
set undodir^=$HOME/.vim/undodir//
set undofile

" quickly edit and reload vimrc
nnoremap <leader>ev :e $MYVIMRC<cr>
nnoremap <leader>sv :source $MYVIMRC<cr>

" open help docs in vertical split
cnoreabbrev vh vert h


"COLORSCHEME TESTING
" show highlight groups under cursor
function! SynGrp() abort
    let l:synid = synID(line("."), col("."), 1)
    return "hi<" . synIDattr(l:synid,"name") . "> "
        \ . "trans<" . synIDattr(synID(line("."),col("."),0),"name") . "> "
        \ . "lo<" . synIDattr(synIDtrans(l:synid),"name") . "> "
        \ . "FG:" . synIDattr(synIDtrans(l:synid),"fg#")
endfunc
" TEMP set colorscheme to mine
"nnoremap <leader>c :color colortv<cr>

" }}}
