if exists('g:loaded_unmatchparen') || !exists('*matchaddpos')
  finish
endif
let g:loaded_unmatchparen = 1

augroup unmatchparen
  autocmd!
  autocmd CursorMoved,CursorMovedI * call unmatchparen#update()
  autocmd VimEnter,WinEnter,BufWinEnter,FileType * call unmatchparen#setup()
  autocmd OptionSet matchpairs call unmatchparen#setup()
augroup END

