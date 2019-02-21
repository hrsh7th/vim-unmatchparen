let g:unmatchparen#is_syntax_detection_enabled = get(g:, 'unmatchparen#is_syntax_detection_enabled', 1)
let g:unmatchparen#ignore_syntaxes = get(g:, 'unmatchparen#ignore_syntaxes', ['Comment', 'String'])
let g:unmatchparen#highlight_priority = get(g:, 'unmatchparen#highlight_priority', 100)
let g:unmatchparen#disable_filetypes = get(g:, 'unmatchparen#disable_filetypes', [])
let g:unmatchparen#disable_pairs = get(g:, 'unmatchparen#disable_pairs', { '<': '>' })
let g:unmatchparen#throttle = get(g:, 'unmatchparen#throttle', 500)
let g:unmatchparen#pairs_for_filetype = get(g:, 'g:unmatchparen#pairs_for_filetype', {
      \   'vim': {
      \     'if': 'endif',
      \     'for': 'endfor',
      \     'function': 'endfunction',
      \     'while': 'endwhile'
      \   }
      \ })

let s:current_ft = ''
let s:pairs = {}
let s:opens = []
let s:closes = []
let s:pattern = ''
let s:timer_running = v:false

"
" highlight
"
function! unmatchparen#highlight(unmatches)
  if has_key(b:, 'unmatchparen_current_highlights')
    silent! call matchdelete(b:unmatchparen_current_highlights)
  endif
  let b:unmatchparen_current_highlights = matchaddpos(
        \ 'ParenUnMatch',
        \ map(a:unmatches, "[v:val['line'], v:val['col'], v:val['len']]"),
        \ g:unmatchparen#highlight_priority)

endfunction

"
" update_async
"
function! unmatchparen#update_async()
  if s:timer_running
    return
  endif
  let s:timer_running = v:true

  function! s:tick(timer)
    call unmatchparen#update()
    let s:timer_running = v:false
  endfunction
  call timer_start(g:unmatchparen#throttle, funcref('s:tick'), { 'repeat': 1 })
endfunction

"
" update
"
function! unmatchparen#update()
  let s:timer_running = v:false

  " ignore if matched disable filetypes.
  if index(g:unmatchparen#disable_filetypes, &filetype) > 0
    return
  endif

  if s:current_ft != &filetype
    call unmatchparen#setup()
  endif

  " create target texts.
  let s:start = line('w0')
  let s:end = line('w$')
  let s:lines = getbufline(bufnr('%'), s:start, s:end)
  let s:texts = type(s:lines) == v:t_list ? join(s:lines, "\n") : s:lines

  " search.
  let s:unmatches = []
  let s:scan = 0
  let s:scan_linebreak = 0
  let s:count_linebreak = 0
  let s:stack = s:Stack.new()
  while 1
    " find paren or \n.
    let s:match = matchstrpos(s:texts, '\V' . s:pattern . '\|' . "\n", s:scan, 1)
    if s:match[0] == ''
      break
    endif
    let s:match_string = s:match[0]
    let s:match_start = s:match[1]
    let s:match_end = s:match[2]
    let s:scan = s:match_end

    " if \n match.
    if s:match_string == "\n"
      let s:count_linebreak = s:count_linebreak + 1
      let s:scan_linebreak = s:scan
      continue
    endif

    " ignore comments or strings.
    if g:unmatchparen#is_syntax_detection_enabled
      let s:synID = synID(s:start + s:count_linebreak, s:match_start - s:scan_linebreak + 1, 0)
      let s:synIDtrans = synIDtrans(s:synID)
      let s:synName = synIDattr(s:synIDtrans, 'name')
      if strlen(s:synName) && index(g:unmatchparen#ignore_syntaxes, s:synName) >= 0
        continue
      endif
    endif

    " if open paren match.
    if index(s:opens, s:match_string) != -1
      call s:stack.push({
            \ 'line': s:start + s:count_linebreak,
            \ 'col': s:match_start - s:scan_linebreak + 1,
            \ 'len': len(s:match_string),
            \ 'paren': s:match_string
            \ })
      continue
    endif

    " if close paren match.
    if index(s:closes, s:match_string) != -1
      " match paren.
      if s:pairs[s:match_string] == s:stack.peek('paren')
        call s:stack.pop()
        continue
      endif

      " experimental: maybe invalid paren at top of stack if matche when skip peek item.
      if s:pairs[s:match_string] == s:stack.peek_at(1, 'paren')
        call add(s:unmatches, {
              \ 'line': s:start + s:count_linebreak,
              \ 'col': s:match_start - s:scan_linebreak + 1,
              \ 'len': len(s:match_string),
              \ 'paren': s:match_string
              \ })
        call add(s:unmatches, s:stack.pop())
        call s:stack.pop()
        continue
      endif

      " maybe invalid paren.
      if s:stack.length() != 0
        call add(s:unmatches, {
              \ 'line': s:start + s:count_linebreak,
              \ 'col': s:match_start - s:scan_linebreak + 1,
              \ 'len': len(s:match_string),
              \ 'paren': s:match_string
              \ })
        call add(s:unmatches, s:stack.pop())
      endif
      continue
    endif
  endwhile

  call unmatchparen#highlight(s:unmatches)
endfunction

"
" setup
"
function! unmatchparen#setup()
  let s:current_ft = &filetype
  let s:pairs = {}
  let s:opens = []
  let s:closes = []
  let s:pattern = ''

  for [open, closed] in map(split(&l:matchpairs, ','), 'split(v:val, ":")')
    if exists('g:unmatchparen#disable_pairs["' . open . '"]') || index(values(g:unmatchparen#disable_pairs), closed) > 0
      continue
    endif
    let s:pairs[closed] = open
  endfor


  if exists('g:unmatchparen#pairs_for_filetype["' . &filetype . '"]')
    for [open, closed] in items(g:unmatchparen#pairs_for_filetype[&filetype])
      if exists('g:unmatchparen#disable_pairs["' . open . '"]') || index(values(g:unmatchparen#disable_pairs), closed) > 0
        continue
      endif
      let s:pairs[closed] = open
    endfor
  endif

  let s:opens = values(s:pairs)
  let s:closes = keys(s:pairs)
  let s:pattern = join(map((s:opens + s:closes), { i, v -> strlen(v) == 1 ? escape(v, '[]') : '\<' . v . '\>' }), '\|')

  highlight link ParenUnMatch Error
endfunction

let s:Stack = { 'list': [] }

function! s:Stack.new()
  return deepcopy(s:Stack)
endfunction

function! s:Stack.length()
  return len(self.list)
endfunction

function! s:Stack.push(v)
  call add(self.list, a:v)
endfunction

function! s:Stack.pop()
  if len(self.list) > 0
    return remove(self.list, len(self.list) - 1)
  endif
endfunction

function! s:Stack.peek(...)
  if len(self.list) > 0
    let s:prop = len(a:000) >= 1 ? a:000[0] : v:null
    if s:prop != v:null
      return self.list[len(self.list) - 1][s:prop]
    endif
    return self.list[len(self.list) - 1]
  endif
endfunction

function! s:Stack.peek_at(offset, ...)
  let s:idx = len(self.list) - a:offset - 1
  if len(self.list) > s:idx
    let s:prop = len(a:000) >= 1 ? a:000[0] : v:null
    if s:prop != v:null
      return self.list[s:idx][s:prop]
    endif
    return self.list[s:idx]
  endif
endfunction

