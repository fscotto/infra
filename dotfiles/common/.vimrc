" ==========================================================
"  Vim configuration - Sysdev Portable
"  Optimized for Linux kernel development
" ==========================================================

set nocompatible
set encoding=utf-8
scriptencoding utf-8

" --- leader MUST be set before any mapping
let mapleader=" "
let maplocalleader="\\"

" ----------------------------------------------------------
" UI
" ----------------------------------------------------------

set number
set relativenumber
set ruler
set showcmd
set nowrap
set splitbelow
set splitright
set signcolumn=yes
set laststatus=2
set scrolloff=4
set sidescrolloff=8

set wildmenu
set wildmode=longest:full,full

set mouse=
set ttyfast
set lazyredraw

" ----------------------------------------------------------
" Editing
" ----------------------------------------------------------

set hidden
set backspace=indent,eol,start

set tabstop=8
set shiftwidth=8
set softtabstop=8
set noexpandtab

set autoindent
" NOTE: cindent supersedes smartindent — smartindent removed (obsolete + redundant)
set cindent
set cinoptions=:0,l1,g0,t0,(0,Ws,m1

set textwidth=80
set colorcolumn=81

" j: remove comment leader when joining lines (Vim >= 7.4)
set formatoptions+=croqnj
set formatoptions-=t

" C syntax tweaks (kernel-friendly)
let c_comment_strings=1
let c_no_curly_error=1

" ----------------------------------------------------------
" Whitespace (OFF by default, toggle with <leader>l)
" ----------------------------------------------------------

set nolist
set listchars=tab:>-,trail:·,extends:»,precedes:«,nbsp:␣

nnoremap <silent> <leader>l :set list!<CR>

" ----------------------------------------------------------
" Search
" ----------------------------------------------------------

set incsearch
set hlsearch
set ignorecase
set smartcase
" NOTE: gdefault removed — it breaks muscle memory and is
"       confusing when reading others' vimrc. Use /g explicitly.

nnoremap <silent> <leader>h :set hlsearch!<CR>

" ----------------------------------------------------------
" Performance
" ----------------------------------------------------------

set updatetime=250
set timeoutlen=800
set ttimeoutlen=10
set shortmess+=c

" ----------------------------------------------------------
" Undo (XDG-aware, robust)
" ----------------------------------------------------------

set undofile
set undolevels=1000

if has("unix")
  if exists("$XDG_CACHE_HOME") && !empty($XDG_CACHE_HOME)
    let s:cache=$XDG_CACHE_HOME
  else
    let s:cache=expand("~/.cache")
  endif

  let s:undodir=s:cache . "/vim/undo//"
  if !isdirectory(s:undodir)
    silent! call mkdir(s:undodir, "p")
  endif
  execute "set undodir=" . fnameescape(s:undodir)
endif

" ----------------------------------------------------------
" Swap files (centralized — no .swp in source trees)
" ----------------------------------------------------------

if has("unix")
  if exists("$XDG_CACHE_HOME") && !empty($XDG_CACHE_HOME)
    let s:cache2=$XDG_CACHE_HOME
  else
    let s:cache2=expand("~/.cache")
  endif

  let s:swpdir=s:cache2 . "/vim/swap//"
  if !isdirectory(s:swpdir)
    silent! call mkdir(s:swpdir, "p")
  endif
  execute "set directory=" . fnameescape(s:swpdir)
  set nobackup
  set nowritebackup
endif

" ----------------------------------------------------------
" Grep integration
" ----------------------------------------------------------

if executable("rg")
  set grepprg=rg\ --vimgrep\ --no-heading\ --smart-case
  set grepformat=%f:%l:%c:%m
elseif executable("grep")
  set grepprg=grep\ -nH\ $*
  set grepformat=%f:%l:%m
endif

nnoremap <silent> <leader>g :silent grep! <C-R><C-W> .<CR>:copen<CR>
nnoremap          <leader>/ :silent grep!<Space>

" ----------------------------------------------------------
" Optional plugins
" ----------------------------------------------------------

" Plugins are installed out-of-band by Ansible when available.  Keep this
" vimrc usable as a standalone onefile: load optional packages only when they
" exist and keep builtin fallbacks for the mappings below.
let s:fzf_min_version = [0, 54, 0]

function! s:PackAdd(package) abort
  silent! execute "packadd " . a:package
endfunction

function! s:PackAddForCommand(package, command) abort
  if exists(":" . a:command) == 2
    return 1
  endif

  call s:PackAdd(a:package)
  return exists(":" . a:command) == 2
endfunction

function! s:PackAddByRuntimeFile(runtime_file, command) abort
  if exists(":" . a:command) == 2
    return 1
  endif

  " Distro packages and source installs do not always use the same Vim package
  " directory name.  Look for a package containing the expected runtime file and
  " load it by its actual directory name.
  for l:packpath in split(&packpath, ",")
    let l:packages = glob(l:packpath . "/pack/*/opt/*", 0, 1)
          \ + glob(l:packpath . "/pack/*/start/*", 0, 1)
    for l:package_dir in l:packages
      if filereadable(l:package_dir . "/" . a:runtime_file)
        call s:PackAdd(fnamemodify(l:package_dir, ":t"))
        if exists(":" . a:command) == 2
          return 1
        endif
      endif
    endfor
  endfor

  return 0
endfunction

let s:has_fzf = s:PackAddForCommand("fzf", "FZF")
      \ || s:PackAddByRuntimeFile("plugin/fzf.vim", "FZF")
let s:has_fzf_vim = s:has_fzf
      \ && (s:PackAddForCommand("fzf.vim", "Files")
      \     || s:PackAddByRuntimeFile("autoload/fzf/vim.vim", "Files"))
let s:has_vim_fugitive = s:PackAddForCommand("vim-fugitive", "Git")
      \ || s:PackAddByRuntimeFile("autoload/fugitive.vim", "Git")

function! s:FzfExecutable() abort
  if executable("fzf")
    return "fzf"
  endif

  return ""
endfunction

function! s:FzfVersionOk() abort
  let l:fzf = s:FzfExecutable()
  if empty(l:fzf)
    return 0
  endif

  let l:version = matchstr(get(systemlist(l:fzf . " --version"), 0, ""), '^\d\+\.\d\+\.\d\+')
  if empty(l:version)
    return 0
  endif

  let l:parts = map(split(l:version, '\.'), 'str2nr(v:val)')
  return l:parts[0] > s:fzf_min_version[0]
        \ || (l:parts[0] == s:fzf_min_version[0] && l:parts[1] > s:fzf_min_version[1])
        \ || (l:parts[0] == s:fzf_min_version[0] && l:parts[1] == s:fzf_min_version[1]
        \     && l:parts[2] >= s:fzf_min_version[2])
endfunction

if s:has_fzf_vim && s:FzfVersionOk()
  let g:fzf_layout = {"down": "40%"}
  let g:fzf_vim = get(g:, "fzf_vim", {})
  let g:fzf_vim.preview_window = ["right,50%", "ctrl-/"]
endif

function! s:FzfCommand(command) abort
  if s:has_fzf_vim && s:FzfVersionOk() && exists(":" . a:command) == 2
    execute a:command
  elseif a:command ==# "Files" || a:command ==# "GFiles" || a:command ==# "GitFiles"
    edit .
  elseif a:command ==# "Buffers"
    ls
  elseif a:command ==# "Rg"
    silent grep! <cword> .
    copen
  endif
endfunction

function! s:GitStatus() abort
  if s:has_vim_fugitive && exists(":Git") == 2
    Git
  elseif executable("git")
    botright new
    setlocal buftype=nofile bufhidden=wipe noswapfile nobuflisted
    silent read !git status --short --branch
    1delete _
    file git-status
  else
    echohl WarningMsg | echom "git executable not found" | echohl None
  endif
endfunction

nnoremap <silent> <leader>ff :call <SID>FzfCommand("Files")<CR>
nnoremap <silent> <leader>fg :call <SID>FzfCommand("GFiles")<CR>
nnoremap <silent> <leader>fb :call <SID>FzfCommand("Buffers")<CR>
nnoremap <silent> <leader>fr :call <SID>FzfCommand("Rg")<CR>
nnoremap <silent> <leader>gs :call <SID>GitStatus()<CR>

" ----------------------------------------------------------
" Quickfix / location list
" ----------------------------------------------------------

nnoremap <silent> ]q :cnext<CR>
nnoremap <silent> [q :cprev<CR>
nnoremap <silent> <leader>qo :copen<CR>
nnoremap <silent> <leader>qc :cclose<CR>

nnoremap <silent> ]l :lnext<CR>
nnoremap <silent> [l :lprev<CR>
nnoremap <silent> <leader>lo :lopen<CR>
nnoremap <silent> <leader>lc :lclose<CR>

" ----------------------------------------------------------
" Window navigation
" ----------------------------------------------------------

nnoremap <C-h> <C-w>h
nnoremap <C-j> <C-w>j
nnoremap <C-k> <C-w>k
nnoremap <C-l> <C-w>l

" ----------------------------------------------------------
" Basic shortcuts
" ----------------------------------------------------------

nnoremap <silent> <leader>w :w<CR>
nnoremap <silent> <leader>q :q<CR>
nnoremap <silent> <leader>x :x<CR>

" Fold toggle
nnoremap <silent> <leader>z za

" Diff helpers
set diffopt=filler,internal,algorithm:histogram,indent-heuristic
nnoremap <silent> <leader>df :windo diffthis<CR>
nnoremap <silent> <leader>do :windo diffoff<CR>

" ----------------------------------------------------------
" Folding
" ----------------------------------------------------------

set foldmethod=syntax
set foldlevelstart=99   " start with all folds open
set foldnestmax=3

" ----------------------------------------------------------
" Tags (ctags)
" ----------------------------------------------------------

set tags=./tags;,tags;

if filereadable(expand('~/.tags'))
  set tags+=~/.tags
endif

nnoremap <silent> <leader>t  :tag <C-R><C-W><CR>
nnoremap <silent> <leader>pt :ptag <C-R><C-W><CR>
nnoremap <silent> <leader>po :popen<CR>
nnoremap <silent> <leader>pc :pclose<CR>

" ----------------------------------------------------------
" cscope (essential for kernel navigation)
" ----------------------------------------------------------

if has("cscope")
  set cscopetag       " use cscope for :tag and <C-]>
  set cscoperelative  " use cscope.out location as prefix
  set cscopeverbose

  " Auto-load cscope.out walking up the directory tree
  function! s:LoadCscope() abort
    let l:db=findfile("cscope.out", ".;")
    if !empty(l:db)
      let l:path=strpart(l:db, 0, match(l:db, "/cscope.out$"))
      if empty(l:path) | let l:path="." | endif
      silent! execute "cs add " . l:db . " " . l:path
    endif
  endfunction
  autocmd BufEnter /* call s:LoadCscope()

  " cscope query mappings
  " s: symbol   g: definition   d: called-by   c: callers
  " t: text      e: egrep        f: file         i: #includes
  nnoremap <silent> <leader>cs :cs find s <C-R>=expand("<cword>")<CR><CR>
  nnoremap <silent> <leader>cg :cs find g <C-R>=expand("<cword>")<CR><CR>
  nnoremap <silent> <leader>cd :cs find d <C-R>=expand("<cword>")<CR><CR>
  nnoremap <silent> <leader>cc :cs find c <C-R>=expand("<cword>")<CR><CR>
  nnoremap <silent> <leader>ct :cs find t <C-R>=expand("<cword>")<CR><CR>
  nnoremap <silent> <leader>ce :cs find e <C-R>=expand("<cword>")<CR><CR>
  nnoremap <silent> <leader>cf :cs find f <C-R>=expand("<cfile>")<CR><CR>
  nnoremap <silent> <leader>ci :cs find i <C-R>=expand("<cfile>")<CR><CR>
endif

" ----------------------------------------------------------
" Man page (K over word)
" ----------------------------------------------------------

function! s:Man() abort
  let l:word=expand("<cword>")
  if exists(":Man")
    execute "Man " . l:word
  else
    execute "!man " . l:word
  endif
endfunction

nnoremap <silent> K :call <SID>Man()<CR>

" ----------------------------------------------------------
" ClangFormat
" ----------------------------------------------------------

function! s:ClangFormatRange(line1, line2) abort
  if !executable("clang-format")
    echohl WarningMsg | echo "clang-format not found in PATH" | echohl None
    return
  endif
  let l:view=winsaveview()
  silent execute a:line1 . "," . a:line2 . "!clang-format"
  call winrestview(l:view)
endfunction

command! -range=% ClangFormat call <SID>ClangFormatRange(<line1>, <line2>)

nnoremap <silent> <leader>cf :ClangFormat<CR>
xnoremap <silent> <leader>cf :ClangFormat<CR>

" ----------------------------------------------------------
" Project root detection
" ----------------------------------------------------------

function! s:GitRoot() abort
  if executable("git")
    let l:r=systemlist("git rev-parse --show-toplevel 2>/dev/null")
    if v:shell_error==0 && len(l:r)>0
      return l:r[0]
    endif
  endif
  return ""
endfunction

function! s:FindProjectRoot() abort
  let l:root=s:GitRoot()
  return !empty(l:root) ? l:root : getcwd()
endfunction

" ----------------------------------------------------------
" Smart build (ninja > cmake > make)
" ----------------------------------------------------------

function! s:SmartMake() abort
  let l:root=s:FindProjectRoot()
  if filereadable(l:root . "/build.ninja")
    let &makeprg="ninja -C " . fnameescape(l:root)
  elseif filereadable(l:root . "/CMakeLists.txt")
    let &makeprg="cmake --build build"
  elseif filereadable(l:root . "/Makefile")
    let &makeprg="make -C " . fnameescape(l:root)
  else
    let &makeprg="make"
  endif
  silent make!
  copen
endfunction

command! Make call <SID>SmartMake()

nnoremap <silent> <leader>m :Make<CR>

" ----------------------------------------------------------
" Run single file (errors in quickfix, output in terminal)
" ----------------------------------------------------------

function! s:Run() abort
  write
  if &filetype=="c"
    let l:src=expand("%")
    let l:exe=expand("%:r")
    let l:saved=&makeprg
    execute "set makeprg=cc\\ -std=c11\\ -Wall\\ -Wextra\\ -g\\ "
      \ . fnameescape(l:src) . "\\ -o\\ " . fnameescape(l:exe)
    silent make!
    let &makeprg=l:saved
    " Run only if no errors
    if empty(filter(getqflist(), 'v:val.valid'))
      execute "!" . fnameescape(l:exe)
    else
      copen
    endif
  elseif &filetype=="python"
    execute "!python3 " . fnameescape(expand("%"))
  elseif &filetype=="sh"
    execute "!sh " . fnameescape(expand("%"))
  else
    echohl WarningMsg | echo "Run not supported for filetype: " . &filetype | echohl None
  endif
endfunction

command! Run call <SID>Run()

nnoremap <silent> <leader>r :Run<CR>

" ----------------------------------------------------------
" Filetypes + syntax
" ----------------------------------------------------------

filetype plugin indent on
syntax on

" ----------------------------------------------------------
" Autocommands
" ----------------------------------------------------------

augroup sysdev_ft
  autocmd!

  " Trim trailing whitespace on save
  autocmd BufWritePre * silent! %s/\s\+$//e

  " Restore last cursor position
  autocmd BufReadPost *
    \ if line("'\"")>0 && line("'\"")<=line("$") |
    \   execute "normal! g`\"" |
    \ endif

  " C/C++: kernel style, no list (tabs are intentional)
  autocmd FileType c,cpp
    \ setlocal tabstop=8 shiftwidth=8 softtabstop=8 noexpandtab
    \ textwidth=80 colorcolumn=81 cindent
    \ cinoptions=:0,l1,g0,t0,(0,Ws,m1 nolist

  " Makefiles: tabs are mandatory
  autocmd FileType make setlocal noexpandtab tabstop=8 shiftwidth=8

  " Assembly: kernel asm style
  autocmd FileType asm,s
    \ setlocal tabstop=8 shiftwidth=8 noexpandtab nolist

  " Kconfig / Kbuild
  autocmd BufRead,BufNewFile Kconfig*,Kbuild*
    \ setlocal filetype=kconfig noexpandtab tabstop=8

  " Patch/diff: never touch whitespace
  autocmd FileType diff,patch setlocal nolist

  " Python: PEP8 (scripts/tooling)
  autocmd FileType python
    \ setlocal tabstop=4 shiftwidth=4 softtabstop=4 expandtab textwidth=79

  " Highlight TODO/FIXME/HACK/BUG/XXX/NOTE in all files
  autocmd Syntax *
    \ call matchadd('Todo', '\v\c<(TODO|FIXME|HACK|BUG|XXX|NOTE|WARN|WARNING)>')

augroup END

" ----------------------------------------------------------
" Statusline (no plugins)
" ----------------------------------------------------------

set statusline=
set statusline+=%#PmenuSel#
set statusline+=\ %f\
set statusline+=%#LineNr#
set statusline+=\ %m%r%h%w\
set statusline+=%=
set statusline+=\ %{&filetype}\
set statusline+=\ %{&fileencoding?&fileencoding:&encoding}\
set statusline+=\ %{&fileformat}\
set statusline+=\ %l:%c\
set statusline+=\ %p%%\

" ==========================================================
"  Embedded colorscheme: sysdev_black
"  Self-contained — no external files needed
" ==========================================================

if &t_Co>=256

  highlight clear
  if exists("syntax_on")
    syntax reset
  endif

  let g:colors_name="sysdev_black"
  set background=dark

  " Base
  hi Normal         ctermfg=252  ctermbg=NONE
  hi Comment        ctermfg=244
  hi Constant       ctermfg=173
  hi String         ctermfg=150
  hi Identifier     ctermfg=81
  hi Function       ctermfg=110
  hi Statement      ctermfg=161
  hi Type           ctermfg=149
  hi PreProc        ctermfg=179
  hi Special        ctermfg=215
  hi Operator       ctermfg=252

  " Selection / search
  hi Visual         ctermbg=238
  hi Search         ctermfg=16   ctermbg=220
  hi IncSearch      ctermfg=16   ctermbg=214

  " Diff
  hi DiffAdd        ctermfg=150  ctermbg=22
  hi DiffDelete     ctermfg=203  ctermbg=52
  hi DiffChange     ctermfg=110  ctermbg=17
  hi DiffText       ctermfg=255  ctermbg=24  cterm=bold

  " UI chrome
  hi LineNr         ctermfg=240
  hi CursorLineNr   ctermfg=220
  hi CursorLine     ctermbg=236  cterm=NONE
  hi ColorColumn    ctermbg=235
  hi SignColumn     ctermfg=240  ctermbg=NONE
  hi VertSplit      ctermfg=238  ctermbg=NONE
  hi StatusLine     ctermfg=252  ctermbg=238  cterm=NONE
  hi StatusLineNC   ctermfg=240  ctermbg=234  cterm=NONE
  hi Folded         ctermfg=244  ctermbg=234
  hi MatchParen     ctermfg=220  ctermbg=NONE cterm=bold,underline

  " Completion menu
  hi Pmenu          ctermfg=252  ctermbg=236
  hi PmenuSel       ctermfg=16   ctermbg=220
  hi PmenuSbar      ctermbg=238
  hi PmenuThumb     ctermbg=244

  " Errors / warnings / todos
  hi Error          ctermfg=255  ctermbg=160  cterm=bold
  hi ErrorMsg       ctermfg=255  ctermbg=160
  hi WarningMsg     ctermfg=214
  hi Todo           ctermfg=16   ctermbg=220  cterm=bold

endif
