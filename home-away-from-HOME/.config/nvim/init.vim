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
" use spaces for C# (dotnet)
autocmd FileType cs setlocal tabstop=4 softtabstop=4 shiftwidth=4 expandtab


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

" find files (smart: git files in repo, all files otherwise)
nnoremap <c-t> <cmd>lua Snacks.picker.smart()<cr>

" find code
nnoremap <c-f> <cmd>lua Snacks.picker.grep()<cr>

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

" list open buffers, sorted by most recently used
nnoremap gb <cmd>lua Snacks.picker.buffers()<cr>
" list recently opened files
nnoremap gf <cmd>lua Snacks.picker.recent()<cr>
" list files in git status
nnoremap gc <cmd>lua Snacks.picker.git_status()<cr>
" jumplist (recently visited locations)
nnoremap gj <cmd>lua Snacks.picker.jumps()<cr>
" go to buffer last seen in this window (aka alternate file)
nnoremap <c-b> <c-^>
" delete current buffer
nnoremap <leader>bd <cmd>bdelete<cr>

" restore cursor position when opening a file
autocmd BufReadPost * if line("'\"")>0 && line("'\"")<=line("$") | exe "normal! g`\"" | endif
" restore cursor position when switching buffers
autocmd BufLeave * let b:prev_pos = getpos(".")
autocmd BufEnter * if exists("b:prev_pos") | call setpos('.', b:prev_pos) | endif

" }}}


" << EDITING >> {{{

" quick save/quit
nnoremap <leader>w <cmd>w<cr>
nnoremap <silent> <leader>q <cmd>silent! argdelete * \| q<cr>

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

" yank into system clipboard
nnoremap <leader>y "+y
vnoremap <leader>y "+y

" save as (dup file)
command! -nargs=1 DupFile execute 'saveas' expand('%:h') . '/' . <q-args>

" }}}


" << LSP >> {{{

" go to references
nnoremap gr <cmd>lua Snacks.picker.lsp_references()<cr>
" go to definition
nnoremap gd <cmd>lua Snacks.picker.lsp_definitions()<cr>
" go to type definition
nnoremap gt <cmd>lua Snacks.picker.lsp_type_definitions()<cr>
" go to implementations
nnoremap gi <cmd>lua Snacks.picker.lsp_implementations()<cr>
" go to document symbols
nnoremap gs <cmd>lua Snacks.picker.lsp_symbols()<cr>
" go to workspace symbols
nnoremap gS <cmd>lua Snacks.picker.lsp_workspace_symbols()<cr>

" code actions
nnoremap ca <cmd>lua vim.lsp.buf.code_action()<cr>

" Trouble diagnostics
nnoremap <leader>xx <cmd>Trouble diagnostics open focus=true<cr>

" show virtual text (inline diagnostic messages)
lua vim.diagnostic.config({virtual_text=true})

" }}}


" << MISC >> {{{

" quickly edit and reload this file
nnoremap <leader>ev <cmd>edit $MYVIMRC<cr>
nnoremap <leader>sv <cmd>source $MYVIMRC<cr>
" and jump to plugins
nnoremap <leader>ep <cmd>edit ~/.config/nvim/lua/plugins/init.lua<cr>

nnoremap <space> <nop>

" use c-j and c-k instead of c-n and c-p for menu navigation
cnoremap <c-j> <c-n>
cnoremap <c-k> <c-p>

" open a terminal
nnoremap <leader>t <cmd>terminal<cr>
" close terminal
tnoremap <esc> <c-\><c-n>

" quicker shell access
nnoremap ! :!
" quicker terminal access
nnoremap % <cmd>split \| terminal<cr>

" git mergetool
nnoremap <leader>[ :diffget LOCAL<cr>
nnoremap <leader>] :diffget REMOTE<cr>

" }}}
