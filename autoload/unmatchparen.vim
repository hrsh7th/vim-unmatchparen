let g:unmatchparen#stopline = get(g:, 'unmatchparen#stopline', 50)
let g:unmatchparen#highlight_priority = get(g:, 'unmatchparen#highlight_priority', 50)
let g:unmatchparen#debug = get(g:, 'unmatchparen#debug', 0)
let g:unmatchparen#disable_filetypes = get(g:, 'unmatchparen#disable_filetypes', [])
let g:unmatchparen#skip_open_paren_if_unmatch = get(g:, 'unmatchparen#skip_open_paren_if_unmatch', 1)
let g:unmatchparen#is_open_paren_check = get(g:, 'unmatchparen#is_open_paren_check', 1)
let g:unmatchparen#pairs_for_filetype = get(g:, 'g:unmatchparen#pairs_for_filetype', {
      \   'vim': {
      \     'if': 'endif',
      \     'for': 'endfor',
      \     'function': 'endfunction',
      \     'while': 'endwhile'
      \   }
      \ })

let s:pairs = {}
let s:opens = []
let s:closes = []
let s:all_pattern = ''

function! unmatchparen#highlight(unmatches)
  if has_key(b:, 'unmatchparen_current_highlights')
    silent! call matchdelete(b:unmatchparen_current_highlights)
  endif

  let b:unmatchparen_current_highlights = matchaddpos(
        \ 'ParenUnMatch',
        \ map(a:unmatches, "[v:val['line'], v:val['col'], v:val['len']]"),
        \ g:unmatchparen#highlight_priority)
endfunction

function! unmatchparen#update()
  " ignore if matched disable filetypes.
  if index(g:unmatchparen#disable_filetypes, &filetype) > 0
    return
  endif

  if g:unmatchparen#debug
    echomsg " "
    echomsg 'start traverse...'
  endif

  " create target texts.
  let s:start = max([line('.') - g:unmatchparen#stopline * 2, 0])
  let s:end = min([line('.') + g:unmatchparen#stopline, line('$')])
  let s:lines = getbufline(bufnr('%'), s:start, s:end)
  let s:texts = type(s:lines) == v:t_list ? join(s:lines, "\n") : s:lines

  " search.
  let s:unmatches = []
  let s:count_maxlength = len(s:texts)
  let s:count_linebreak = 0
  let s:scan = 0
  let s:scan_linebreak = 0
  let s:stack = s:Stack.new()
  while 1
    " finish.
    if s:count_maxlength <= s:scan
      break
    endif

    " find paren or \n.
    let s:match = matchstrpos(s:texts, s:all_pattern . '\|' . "\n", s:scan, 1)
    if s:match[0] == ''
      break
    endif
    let s:scan = s:match[2]

    " if \n match.
    if s:match[0] == "\n"
      let s:count_linebreak = s:count_linebreak + 1
      let s:scan_linebreak = s:scan
      continue
    endif

    " ignore comments or strings.
    let s:synName = synIDattr(synIDtrans(synID(s:start + s:count_linebreak + 1, s:match[1] - s:scan_linebreak + 1, 0)), 'name')
    if g:unmatchparen#debug
      echomsg 's:synId: ' . s:synName
    endif
    if index(['Comment', 'String'], s:synName) >= 0
      continue
    endif

    " if open paren match.
    if index(s:opens, s:match[0]) != -1
      if g:unmatchparen#debug
        echomsg 'push: ' . s:match[0]
      endif
      call s:stack.push({
            \ 'line': s:start + s:count_linebreak + 1,
            \ 'col': s:match[1] - s:scan_linebreak + 1,
            \ 'len': len(s:match[0]),
            \ 'paren': s:match[0]
            \ })
      continue
    endif

    " if close paren match.
    if index(s:closes, s:match[0]) != -1
      " collect paren.
      if s:stack.length() > 0
        if s:pairs[s:match[0]] == s:stack.peek()['paren']
          if g:unmatchparen#debug
            echomsg 'pop: ' . s:match[0]
          endif
          call s:stack.pop()
          continue
        endif
      endif

      " invalid paren.
      call add(s:unmatches, {
            \ 'line': s:start + s:count_linebreak + 1,
            \ 'col': s:match[1] - s:scan_linebreak + 1,
            \ 'len': len(s:match[0]),
            \ 'paren': s:match[0]
            \ })

      " maybe invalid open paren.
      if g:unmatchparen#is_open_paren_check
        if g:unmatchparen#skip_open_paren_if_unmatch
          call add(s:unmatches, s:stack.pop())
        else
          call add(s:unmatches, s:stack.peek())
        endif
      endif
      continue
    endif
  endwhile

  if g:unmatchparen#debug
    echomsg json_encode(s:unmatches)
  endif

  call unmatchparen#highlight(s:unmatches)
endfunction

function! unmatchparen#setup()
  for [open, closed] in map(split(&l:matchpairs, ','), 'split(v:val, ":")')
    let s:pairs[closed] = open
  endfor

  if exists('g:unmatchparen#pairs_for_filetype["' . &filetype . '"]')
    for [open, closed] in items(g:unmatchparen#pairs_for_filetype[&filetype])
      let s:pairs[closed] = open
    endfor
  endif

  let s:opens = values(s:pairs)
  let s:closes = keys(s:pairs)
  let s:all_pattern = join(map((s:opens + s:closes), '"\\<" . escape(v:val, "[]"). "\\>"'), '\|')

  if g:unmatchparen#debug
    echomsg ' '
    echomsg 'setup...'
    echomsg 's:all_pattern: ' . s:all_pattern
    echomsg 's:pairs: ' . json_encode(s:pairs)
  endif

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

function! s:Stack.peek()
  if len(self.list) > 0
    return self.list[len(self.list) - 1]
  endif
endfunction

