if exists("g:closer_autoloaded") | finish | endif
let g:closer_autoloaded=1

if maparg("<Plug>CloserClose") == ""
  inoremap <silent> <SID>CloserClose <C-R>=closer#close()<CR>
  imap <script> <Plug>CloserClose <SID>CloserClose
endif

"
" Enables closer for the current buffer.
"

function! closer#enable()
  " Based on tpope's vim-eunuch <CR> mapping function
  if ! exists('b:closer_flags') | return | endif
  let b:closer = 1
  let oldmap = maparg('<CR>', 'i', 0, 1)
  let rhs = substitute(get(oldmap, 'rhs', ''), '\c<sid>', '<SNR>' . get(oldmap, 'sid') . '_', 'g')

  if get(g:, 'closer_no_mappings') || rhs =~# '\MCloserClose\|closer#close'
    return
  endif

  if get(oldmap, 'expr')
    exe 'imap <script><silent><expr> <CR> closer#close(' . rhs . ')'
  elseif rhs =~? '^<cr>' && rhs !~? '<plug>'
    exe 'imap <silent><script> <CR>' rhs . '<SID>CloserClose'
  elseif rhs =~? '^cr'
    exe 'imap <silent> <CR>' rhs . '<SID>CloserClose'
  elseif empty(rhs)
    imap <script><silent><expr> <CR> closer#close("\r")
  endif
endfunction

"
" Adds a closing bracket if needed.
" Executed after pressing <CR>
"

function! closer#close(...)
  " tpope madness to play nicely with other plugins' <CR> mappings
  if a:0 && type(a:1) == type('')
    return a:1 . (a:1 =~# "\r" && empty(&buftype) ? "\<C-R>=closer#close()\r" : "")
  endif

  if ! get(b:, 'closer') | return '' | endif

  " supress if it broke off a line (pressed enter not at the end)
  if match(getline('.'), '^\s*$') == -1 | return '' | endif

  let ln = line('.') - 1
  let line = getline(ln)
  let indent = matchstr(line, '^\s*')

  let closetag = s:get_closing(line)
  if closetag == '' | return "" | endif

  let closetag = closetag . s:use_semicolon(ln)

  " <esc>a will go back to the 0.
  " I dont know why <esc>A is needed at the end, but it seems to fix
  " pressing escape after expansion.
  return "\<Esc>a" .indent . closetag . "\<C-O>O\<Esc>a" . indent . "\<Tab>\<Esc>A"
endfunction

"
" Returns the context of the function
" simply returns whatever's on the previous level of indentation
"

function! s:get_context()
  let ln = line('.') - 1
  let indent = strlen(matchstr(getline(ln), '^\s*'))
  while ln > 0
    let ln = prevnonblank(ln-1)
    let lntext = getline(ln)
    let nindent = strlen(matchstr(lntext, '^\s*'))
    if nindent < indent | return lntext | endif
  endwhile
  return 0
endfunction

"
" Checks if a semicolon is needed for a given line number
"

function! s:use_semicolon(ln)
  " Only add semicolons if the `;` flag is on.
  if ! exists('b:closer') | return '' | endif
  if match(b:closer_flags, ';') == -1 | return '' | endif

  " Only add semicolons if another line has a semicolon.
  let used_semi = search(';$', 'wn') > 0
  if used_semi == "0" | return '' | endif

  " Don't add semicolons for lines matching `no_semi`.
  " This allows `function(){ .. }` and `class X { .. }` to not get semicolons.
  let line = getline(a:ln)
  let topline = getline(a:ln - 1)
  if b:closer_no_semi != '0' && match(line, b:closer_no_semi) > -1
    return ''
  elseif b:closer_no_semi != '0' && b:closer_semi_check_top != '0' && match(topline, b:closer_no_semi) > -1
    return ''
  endif

  " Don't add semicolons for context lines matching `semi_ctx`.
  " This allows supressing semi's for those inside object literals
  let ctx = s:get_context()
  if ctx != '0'
    " if context is not a js function, don't semicolonize
    if b:closer_semi_ctx != '0' && match(ctx, b:closer_semi_ctx) == -1 | return '' | endif
  endif

  return ';'
endfunction

"
" Returns the closing tag for a given line
"
"     get_closing('describe(function() {')
"     => '});'
"
"     get_closing('function x() {')
"     => '}'
"

function! s:get_closing(line)
  let i = -1
  let clo = ''
  while 1
    let i = match(a:line, '[{}()\[\]]', i+1)
    if i == -1 | break | endif
    let ch = a:line[i]
    if ch == '{'
      let clo = '}' . clo
    elseif ch == '}'
      let clo = clo[1:]
    elseif ch == '('
      let clo = ')' . clo
    elseif ch == ')'
      let clo = clo[1:]
    elseif ch == '['
      let clo = ']' . clo
    elseif ch == ']'
      let clo = clo[1:]
    endif
  endwhile
  return clo
endfunction
