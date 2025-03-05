let mapleader = "\<space>"

" load plugins with lua/config/lazy.lua and lua/config/plugins/*.lua
lua require("config.lazy")


" << UI >> {{{

colorscheme tokyonight
set number                  " show line number of current line...
set relativenumber          " ...and relative line number of other lines
set cursorline              " highlight current line
set linebreak               " don't break words when wrapping
set splitright              " open vertical split panes to the right

" tabs are 4 columns wide, each indentation level is one tab
set tabstop=4 softtabstop=4 shiftwidth=4 noexpandtab
" better indenting for react
autocmd FileType javascriptreact,typescriptreact setlocal tabstop=2 softtabstop=2 shiftwidth=2 expandtab

" < FOLDING > {{{
set foldlevelstart=10       " fold very nested indents by default
set foldmethod=indent       " fold based on indent level
" fold by marker for vim files
augroup filetype_vim
	autocmd!
	autocmd FileType vim setlocal foldmethod=marker
augroup END
" toggle fold
nnoremap <leader>f za
" }}}

" < GITGUTTER > {{{
" refresh on save
autocmd BufWritePost * GitGutter

" toggle number and gitgutter columns (useful for copying text to paste)
nnoremap <leader>nn <cmd>call ToggleGutter()<cr>
function! ToggleGutter()
	" if any of the gutters are enabled, disables all of them
	" else, enables all of them
	if &number || &relativenumber || g:gitgutter_enabled
		set nonumber norelativenumber
		execute 'GitGutterDisable'
	else
		set number relativenumber
		execute 'GitGutterEnable'
	endif
endfunction
" }}}

" }}}


" << SEARCH >> {{{

set ignorecase smartcase            " if search string is all lc, ignore case. else, case-sensitive.

" clear highlighted search term
nnoremap <silent> <space><space> <cmd>nohlsearch<cr>

" n always goes forward, N always goes backward
nnoremap <expr> n (v:searchforward ? 'n' : 'N')
nnoremap <expr> N (v:searchforward ? 'N' : 'n')

" search by plain text (very nomagic: only / has special meaning)
"nnoremap / /\V

" find files
nnoremap <c-t> <cmd>call ProjectFiles()<cr>
function! ProjectFiles()
	" if in a git repo, search git files
	" else search all files
	let l:git_dir = finddir('.git', '.;')
	if l:git_dir != ''
		execute 'Telescope git_files'
	else
		" show hidden files, follow symlinks, exclude some files
		execute 'Telescope find_files find_command=fd,--type,f,--hidden,--follow,--exclude,.git,--exclude,.DS_Store'
	endif
endfunction

" git grep the word under the cursor
function! GrepCword()
	" Get the word under the cursor.
	let l:searchtext = expand('<cword>')
	" Set the search pattern to match the whole word.
	let @/ = '\V\<'.l:searchtext.'\>'
	set hlsearch
	" Run git grep.
	execute 'G g '.shellescape(l:searchtext)
endfunction
nnoremap <silent> <leader>gg <cmd>call GrepCword()<cr>n


" }}}


" << NAVIGATION >> {{{

set scrolloff=3         " keep a 3-line pad above and below the cursor
set startofline         " move to first non-blank character when moving to another line

" move cursor by display lines (helps when a line is visually wrapped)
nnoremap k gk
nnoremap j gj

" don't require shift for moving to the beginning of the next line (-/+ navigation without shift)
nnoremap = +

" ctrl-movement jumps
noremap <c-h> ^
noremap <c-j> <c-d>zz
noremap <c-k> <c-u>zz
noremap <c-l> $

" use tab to move to matching bracket in modes: Normal, Visual, Select, Operator-pending
noremap <tab> %

" list open buffers
nnoremap gb <cmd>Telescope buffers sort_mru=true ignore_current_buffer=true<cr>
" jumplist (recently visited locations)
nnoremap gj <cmd>Telescope jumplist<cr>
" go to buffer last seen in this window (aka alternate file)
nnoremap <c-b> <c-^>
" delete current buffer
nnoremap <leader>bd <cmd>bdelete<cr>

" < LSP Navigation > {{{

" go to definition
nnoremap gd <cmd>Telescope lsp_definitions<cr>
" go to references
nnoremap gr <cmd>Telescope lsp_references<cr>
" diable diagnostics
"lua vim.diagnostic.enable(false)

" }}}

" }}}


" << EDITING >> {{{

" quick save/quit
nnoremap <leader>w <cmd>w<cr>
nnoremap <leader>q <cmd>q<cr>

" hit j and k (order and case don't matter) to escape insert mode
inoremap jk <esc>
inoremap Jk <esc>
inoremap jK <esc>
inoremap JK <esc>
inoremap kj <esc>
inoremap Kj <esc>
inoremap kJ <esc>
inoremap KJ <esc>

" quick indent
nnoremap < <<
nnoremap > >>
" stay in visual mode after left or right shift
vnoremap < <gv
vnoremap > >gv

" persistent undo history
set undofile

" maintain clipboard after pasting over something in visual mode
xnoremap p "_dP

" highlight last-pasted text
nnoremap <leader>v V`]

" open a new line but stay in normal mode at current position
nnoremap <leader>o m`o<esc>``
nnoremap <leader>O m`O<esc>``

" insert current datetime
inoremap <c-t> <c-r>=strftime('%Y-%m-%d %H:%M:%S')<c-m>

" Github Copilot
imap <c-j> <plug>(copilot-next)
imap <c-k> <plug>(copilot-previous)
imap <c-l> <plug>(copilot-accept-line)
imap <c-c> <plug>(copilot-suggest)
imap <c-x> <plug>(copilot-dismiss)

" }}}


" << MISC >> {{{

" quickly edit and reload this file
nnoremap <leader>ev <cmd>edit $MYVIMRC<cr>
nnoremap <leader>sv <cmd>source $MYVIMRC<cr>

" }}}
