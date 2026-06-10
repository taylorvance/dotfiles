" Vim color file
" Maintainer:	Taylor Vance <vimcolors@tvprograms.tech>
" Last Change:	2018-06-15

set background=dark
hi clear
if exists("syntax_on")
  syntax reset
endif

let g:colors_name="colortv"


" Custom color names {{{

" Grays
let s:black=232
let s:verydarkgray=235
let s:darkgray=239
let s:gray=243
let s:lightgray=247
let s:verylightgray=251
let s:white=255
" Colors
let s:red=196
let s:orange=202
let s:yellow=11
let s:green=47
let s:cyan=45
let s:blue=33
let s:lightblue=75
let s:purple=129
let s:pink=200

" }}}


" Variables for categories of syntax groups
let s:basecolor="blue"
if s:basecolor ==? "blue"
	let s:keywords=s:cyan
	let s:variables=s:lightblue
	let s:constants=s:blue
	let s:control=s:yellow
elseif s:basecolor ==? "purple"
	let s:keywords=s:green
	let s:variables=s:lightblue
	let s:constants=s:purple
	let s:control=s:pink
endif


" Grays
exe 'hi Normal ctermfg='.s:white.' ctermbg='.s:black
hi! link Operator Normal
hi! link Special Normal
hi! link Title Normal
hi! link javaScriptBraces Normal
hi! link cssBraces Normal
exe 'hi Comment ctermfg='.s:gray
exe 'hi Delimiter ctermfg='.s:lightgray
exe 'hi Visual ctermfg='.s:black.' ctermbg='.s:white
exe 'hi Folded ctermfg='.s:white.' ctermbg='.s:verydarkgray

" Red
exe 'hi Error ctermfg='.s:white.' ctermbg='.s:red
exe 'hi ErrorMsg ctermfg='.s:white.' ctermbg='.s:red.' cterm=bold'

" Orange
exe 'hi Todo ctermfg='.s:white.' ctermbg='.s:orange

" Yellow
exe 'hi Statement ctermfg='.s:control
exe 'hi Search ctermfg='.s:black.' ctermbg='.s:yellow
exe 'hi IncSearch ctermfg='.s:black.' ctermbg='.s:yellow

" Green

" Blue
exe 'hi Constant ctermfg='.s:constants
exe 'hi Identifier ctermfg='.s:variables
exe 'hi Type ctermfg='.s:keywords
hi! link javaScriptIdentifier Type
hi! link javaScriptFunction Type


" GUI
hi Cursor cterm=reverse
hi CursorLine cterm=underline
exe 'hi LineNr ctermfg='.s:gray
hi! link CursorLineNr LineNr
exe 'hi MatchParen ctermfg='.s:black.' ctermbg='.s:lightgray


" Filetypes {{{

" Vim
exe 'hi vimMapLhs ctermfg='.s:lightgray
exe 'hi vimMapRhs ctermfg='.s:verylightgray
exe 'hi vimCommentTitle ctermfg='.s:lightgray

" HTML
exe 'hi htmlTag ctermfg='.s:lightgray
hi! link htmlEndTag htmlTag
hi! link htmlScriptTag htmlTag
exe 'hi htmlArg ctermfg='.s:lightgray
exe 'hi htmlTagName ctermfg='.s:keywords
hi! link htmlSpecialTagName htmlTagName
hi htmlBold cterm=bold
hi htmlUnderline cterm=underline
hi htmlItalic cterm=underline

" PHP
hi! link phpComparison Normal
hi! link phpMemberSelector Normal
hi! link phpVarSelector Identifier
hi! link phpFunctions Type
hi! link phpDefine Type

" }}}
