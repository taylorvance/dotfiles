" Vim color file
" Maintainer:	Taylor Vance <vimcolors@tvprograms.tech>
" Last Change:	2019-10-23

set background=dark
hi clear
if exists("syntax_on")
  syntax reset
endif

let g:colors_name="4bit"


"          normal  bright
"   black       0       8
"     red       1       9
"   green       2      10
"  yellow       3      11
"    blue       4      12
" magenta       5      13
"    cyan       6      14
"   white       7      15


hi Comment ctermfg=8
hi Constant ctermfg=4
hi Cursor cterm=reverse
hi CursorLine cterm=underline
hi Delimiter ctermfg=7
"hi DiffAdd
"hi DiffChange
"hi DiffDelete
"hi DiffText
hi Error ctermfg=15 ctermbg=1
hi ErrorMsg ctermfg=15 ctermbg=1 cterm=bold
hi Folded ctermfg=15 ctermbg=8
hi Identifier ctermfg=12
"hi Ignore
hi IncSearch ctermfg=0 ctermbg=3
hi LineNr ctermfg=7
hi MatchParen ctermfg=0 ctermbg=7
hi ModeMsg ctermfg=10
hi Normal ctermfg=15 ctermbg=0
hi PreProc ctermfg=6
hi Search ctermfg=0 ctermbg=3
"hi Special
hi Statement ctermfg=11
"hi StatusLine
"hi StatusLineNC
hi Todo ctermfg=13 ctermbg=0
hi Type ctermfg=14
hi Visual ctermfg=0 ctermbg=15
"hi WarningMsg
"hi WildMenu


hi! link CursorLineNr LineNr
hi! link Operator Normal
hi! link Special Normal
hi! link Title Normal


" language-specific

hi! link cssBraces Normal

hi htmlArg ctermfg=7
hi htmlBold cterm=bold
hi htmlItalic cterm=underline
hi htmlTag ctermfg=7
hi htmlTagName ctermfg=14
hi htmlUnderline cterm=underline
hi! link htmlEndTag htmlTag
hi! link htmlScriptTag htmlTag
hi! link htmlSpecialTagName htmlTagName

hi! link javaScriptBraces Normal
hi! link javaScriptFunction Type
hi! link javaScriptIdentifier Type

hi! link phpComparison Normal
hi! link phpDefine Type
hi! link phpFunctions Type
hi! link phpMemberSelector Normal
hi! link phpVarSelector Identifier

hi vimCommentTitle ctermfg=7
hi vimMapLhs ctermfg=7
hi vimMapRhs ctermfg=7
