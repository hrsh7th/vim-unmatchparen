let g:unmatchparen#stopline = get(g:, 'unmatchparen#stopline', 100)
let g:unmatchparen#highlight_priority = get(g:, 'unmatchparen#highlight_priority', 100)
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
let s:pattern = ''

function! unmatchparen#highlight(unmatches)
  if has_key(b:, 'unmatchparen_current_highlights')
    silent! call matchdelete(b:unmatchparen_current_highlights)
  endif
  let s:start = line('w0')
  let s:end = line('w$')
  let s:unmatches = filter(s:unmatches, "s:start <= v:val['line'] && v:val['line'] <= s:end")

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

  call unmatchparen#log('start traverse', '...')

  " create target texts.
  let s:start = max([line('.') - g:unmatchparen#stopline, 1])
  let s:end = min([line('.') + g:unmatchparen#stopline, line('$')])
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
    let s:scan = s:match[2]

    " if \n match.
    if s:match[0] == "\n"
      let s:count_linebreak = s:count_linebreak + 1
      let s:scan_linebreak = s:scan
      continue
    endif

    call unmatchparen#log('s:match[0]', s:match[0])

    " ignore comments or strings.
    let s:synID = synID(s:start + s:count_linebreak, s:match[1] - s:scan_linebreak + 1, 0)
    let s:synIDtrans = synIDtrans(s:synID)
    let s:synName = synIDattr(s:synIDtrans, 'name')
    if strlen(s:synName) && index(['Comment', 'String'], s:synName) >= 0
      continue
    endif

    " if open paren match.
    if index(s:opens, s:match[0]) != -1
      call unmatchparen#log('push', s:match[0])
      call s:stack.push({
            \ 'line': s:start + s:count_linebreak,
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
          call unmatchparen#log('pop', s:match[0])
          call s:stack.pop()
          continue
        endif
      endif

      " invalid paren.
      call add(s:unmatches, {
            \ 'line': s:start + s:count_linebreak,
            \ 'col': s:match[1] - s:scan_linebreak + 1,
            \ 'len': len(s:match[0]),
            \ 'paren': s:match[0]
            \ })

      " maybe invalid open paren.
      if s:stack.length() > 0
        if g:unmatchparen#is_open_paren_check
          if g:unmatchparen#skip_open_paren_if_unmatch
            call add(s:unmatches, s:stack.pop())
          else
            call add(s:unmatches, s:stack.peek())
          endif
        endif
      endif
      continue
    endif
  endwhile

  if len(s:unmatches) | call unmatchparen#log('s:unmatches', s:unmatches) | endif
  call unmatchparen#highlight(s:unmatches)
endfunction

function! unmatchparen#setup()
  let s:pairs = {}
  let s:opens = []
  let s:closes = []
  let s:pattern = ''

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
  let s:pattern = join(map((s:opens + s:closes), { i, v -> strlen(v) == 1 ? escape(v, '[]') : '\<' . v . '\>' }), '\|')

  call unmatchparen#log('setup', '...')
  call unmatchparen#log('s:pattern', s:pattern)
  call unmatchparen#log('s:pairs', s:pairs)

  highlight link ParenUnMatch Error
endfunction

function! unmatchparen#log(name, txt)
  if g:unmatchparen#debug
    echomsg printf('%s: %s', a:name, json_encode(a:txt))
  endif
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

