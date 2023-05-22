" Taylor Vance


" Auto-install vim-plug
if empty(glob('~/.vim/autoload/plug.vim'))
    silent !curl -fLo ~/.vim/autoload/plug.vim --create-dirs
        \ https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
    autocmd VimEnter * PlugInstall --sync | source $MYVIMRC
endif

call plug#begin('~/.vim/plugged')
"Plug 'neoclide/coc.nvim', {'branch': 'release'}
Plug 'Exafunction/codeium.vim'
"Plug 'github/copilot.vim'
Plug 'junegunn/fzf', {'do': { -> fzf#install() }}
Plug 'junegunn/fzf.vim'
Plug 'tpope/vim-fugitive'
Plug 'airblade/vim-gitgutter'
Plug 'morhetz/gruvbox'
Plug 'preservim/nerdcommenter'
Plug 'tpope/vim-repeat'
Plug 'andrewradev/splitjoin.vim'
Plug 'tpope/vim-surround'
Plug 'posva/vim-vue'
call plug#end()


map <space> <leader>

set encoding=utf-8


" << UI >> {{{

colorscheme gruvbox
set background=dark         " dark mode
set number                  " show line number of current line...
set relativenumber          " ...and relative line number of other lines
set cursorline              " highlight current line
set synmaxcol=1000          " max column to syntax-highlight (impacts performance)
set showcmd                 " show prev cmd in bottom
set showmode                " if in Insert, Replace, or Visual mode, show in bottom left
set showmatch               " highlight matching bracket
set wrap                    " visually wrap a line if it's wider than the window
set textwidth=0             " but don't insert an actual <EOL> as I'm typing a long line
set linebreak               " don't break words when wrapping
set visualbell              " no beep
set lazyredraw              " prevents redraw for macros, registers, and non-typed cmds
set mouse=a                 " enable mouse in all modes
set splitright				" open vertical split panes to the right

" < STATUSLINE > {{{
set laststatus=2	" always show the status line
set statusline=
set statusline+=%2*%y%*									" file type
set statusline+=%1*\ \ %f%*								" relative filepath
set statusline+=%3*\ \ %{codeium#GetStatusString()}%*	" Codeium status
set statusline+=%4*\ \ %m%*								" modified flag
set statusline+=%1*%=%*									" switch to right side
set statusline+=%1*%c%V%*								" col num and virtual col num
set statusline+=%1*\ \ %l/%L%*							" line num and total lines
set statusline+=%1*\ \ (%p%%)%*							" percentage through file
" statusline coloring
highlight User1 ctermbg=0 ctermfg=7					" silver
highlight User2 ctermbg=0 ctermfg=8					" gray
highlight User3 ctermbg=0 ctermfg=6					" cyan
highlight User4 ctermbg=0 ctermfg=9 cterm=bold		" red
" make the warning message more noticeable
highlight WarningMsg ctermbg=167 ctermfg=235 cterm=bold
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

set hlsearch						" highlight search
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
nnoremap <c-t> :execute system('git rev-parse --is-inside-work-tree') =~ 'true' ? 'GFiles --cached --others --exclude-standard' : 'Files'<cr>
" find text in open files
nnoremap <c-f> :Lines<cr>

" }}}


" << NAVIGATION >> {{{

set scrolloff=3         " keep a 3-line pad above and below the cursor

" move cursor by display lines (helps when a line is visually wrapped)
nnoremap k gk
nnoremap j gj

" don't require shift for moving to the beginning of the next line (-/+ navigation without shift)
nnoremap = +

" center vertically when scroll jumping
noremap <c-u> <c-u>zz
noremap <c-d> <c-d>zz

" go to beginning/end of line rather than the window (horizonal rather than vertical)
noremap H ^
noremap L $

" use tab to move to matching bracket in modes: Normal, Visual, Select, Operator-pending
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
vnoremap [ <gv
vnoremap ] >gv

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
    "set formatoptions+=j
endif

" insert current datetime in ISO format
inoremap <c-t> <c-r>=strftime('%Y-%m-%d %H:%M:%S')<c-m>

" reformat associative php array
" expand into multiple lines
":'<,'>s/\[/\[\r/|s/=>/ => /g|s/, /,\r/g|s/\]/,\r\]/
" collapse into one line
":'<,'>s/\n\s*/ /g|s/ => /=>/g|s/, \]/\]/g

" splitjoin settings
let g:splitjoin_split_mapping = ''
let g:splitjoin_join_mapping = ''
" gj splits down and gk joins up
nnoremap gj :SplitjoinSplit<cr>
nnoremap gk :SplitjoinJoin<cr>
let g:splitjoin_curly_brace_padding = 0
let g:splitjoin_trailing_comma = 1
let g:splitjoin_python_brackets_on_separate_lines = 1
let g:splitjoin_html_attributes_bracket_on_new_line = 1
let g:splitjoin_php_method_chain_full = 1

" CoC: enable github copilot
"let g:coc_global_extensions = ['coc-copilot']
" CoC: use j/k instead of n/p to navigate options - https://github.com/neoclide/coc.nvim/wiki/Completion-with-sources#use-tab-and-s-tab-to-navigate-the-completion-list
"inoremap <expr> <c-j> coc#pum#visible() ? coc#pum#next(1) : "\<c-j>"
"inoremap <expr> <c-k> coc#pum#visible() ? coc#pum#prev(1) : "\<c-k>"
" CoC: tab selects and confirms the first option - https://github.com/neoclide/coc.nvim/wiki/Completion-with-sources#use-cr-to-confirm-completion
"inoremap <silent><expr> <tab> coc#pum#visible() ? coc#_select_confirm() : "\<c-g>u\<tab>"

"let g:copilot_filetypes = {'yaml': v:true, 'yml': v:true}

" Codeium
imap <script><silent><nowait><expr> <C-g> codeium#Accept()
imap <c-j> <Cmd>call codeium#CycleCompletions(1)<CR>
imap <c-k> <Cmd>call codeium#CycleCompletions(-1)<CR>
imap <c-x> <Cmd>call codeium#Clear()<CR>

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

" disable keyword lookup
nnoremap K <Nop>


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
