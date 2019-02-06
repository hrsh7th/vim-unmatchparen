# vim-unmatchparen

highlights unmatched paren.

# options

### g:unmatchparen#stopline (default: 50)
Settings for range to check line count.

### g:unmatchparen#highlight_priority (default: 10)
Settings for highlight priority. `help matchaddpos`

### g:unmatchparen#skip_open_paren_if_unmatch (default: 1)
Settings for pop out open paren if unmatched.

### g:unmatchparen#disable_filetypes (default: [])
Settings for disable specific filetypes.

### g:unmatchparen#is_open_paren_check (default: 1)
Settings for check open paren.

### g:unmatchparen#pairs_for_filetype (default: { 'vim': { ... } })
Settings for pairs for specific filetype.

```VimL
let g:unmatchparen#pairs_for_filetype = {
  \   'vim': {
  \     'if': 'endif',
  \     'for': 'endfor'
  \   }
  \ }
```

### g:unmatchparen#debug (default: 0)

# demo

![demo](https://user-images.githubusercontent.com/629908/52343727-41c07300-2a5c-11e9-811a-20e09af04a42.png)


# note

implementation is heavyly inspired by itchny/vim-parenmatch. thanks.

