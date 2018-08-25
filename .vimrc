call plug#begin('~/.local/share/nvim/plugged')
Plug 'Shougo/neobundle.vim'
Plug 'fatih/vim-go'
Plug 'scrooloose/nerdtree'
Plug 'simeji/winresizer'
Plug 'nanotech/jellybeans.vim'
Plug 'buoto/gotests-vim'
call plug#end()

colorscheme jellybeans

set list
set background=dark
set bs=indent,eol,start
set viminfo=%,'100,<500,h
set history=100
set nobackup
set noswapfile
set ruler
set number
set showmatch
set autoread
set tabstop=2
set shiftwidth=2
set expandtab
set ai
set smartindent
syntax on
set foldmethod=marker
set title
set tags=.tags,tags
filetype plugin on
let g:netrw_liststyle = 3
let g:netrw_altv = 1
let g:netrw_auto = 1
let g:molokai_original = 1

" HighLight for Golang
"autocmd FileType go :highlight goErr cterm=bold ctermfg=232
"autocmd FileType go :match goErr /\<err\>/
autocmd FileType go :match goExtraType /\<err\>/
"autocmd BufWritePre *.go :GoImports

"NERDTree
nnoremap <silent><C-n> :NERDTreeToggle<CR>

:command Gb GoBuild
:command Gr GoRun
:command Gi GoImports
:command Gt GoTest

:command Copy !cat % | xsel --input --clipboard
let g:go_gocode_unimported_packages = 1

"Json
command! -nargs=? Jq call s:Jq(<f-args>)
function! s:Jq(...)
  if 0 == a:0
    let l:arg = "."
  else
    let l:arg = a:1
  endif
  execute "%! jq \"" . l:arg . "\""
endfunction

set rtp+=~/.fzf
:command Bq Buffers

