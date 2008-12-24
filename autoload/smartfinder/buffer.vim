"-----------------------------------------------------------------------------
" smartfinder - buffer
" Author: ky
" Version: 0.1
" License: The MIT License
" The MIT License {{{
"
" Copyright (C) 2008 ky
"
" Permission is hereby granted, free of charge, to any person obtaining a
" copy of this software and associated documentation files (the "Software"),
" to deal in the Software without restriction, including without limitation
" the rights to use, copy, modify, merge, publish, distribute, sublicense,
" and/or sell copies of the Software, and to permit persons to whom
" the Software is furnished to do so, subject to the following conditions:
" 
" The above copyright notice and this permission notice shall be included in
" all copies or substantial portions of the Software.
" 
" THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
" IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
" FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
" AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
" LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
" ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
" OTHER DEALINGS IN THE SOFTWARE.
" }}}
"-----------------------------------------------------------------------------

if has('win16') || has('win32') || has('win64')
  let s:REGEX_SEPARATOR_PATTERN = [ '/', '\\[\\/]' ]
else
  let s:REGEX_SEPARATOR_PATTERN = []
endif

let s:PROMPT = 'buffer>'
let s:PROMPT_LEN = strlen(s:PROMPT)
let s:CANCEL_CHOOSE_ACTION_KEY = "[\<Esc>\<C-c>]"
let s:DEFAULT_ACTION_NAME = 'open'
let s:ACTION_KEY_TABLE = {
      \ 'o' : 'open',
      \ 'd' : 'delete',
      \ 'D' : 'delete!',
      \}
let s:ACTION_NAME_TABLE = {
      \ 'open'    : 'smartfinder#buffer#action_open',
      \ 'delete'  : 'smartfinder#buffer#action_delete',
      \ 'delete!' : 'smartfinder#buffer#action_delete_f',
      \}


let s:cache_buflist = []


function! smartfinder#buffer#init()
  let last_bufnr = bufnr('$')
  let width = len(last_bufnr)

  let s:cache_buflist = []

  for i in range(1, bufnr('$'))
    if bufexists(i) && buflisted(i)
      let bufname = bufname(i)
      if empty(bufname)
	let bufname = '[no name] (#' . i . ')'
      endif
      call add(s:cache_buflist, {
	    \ 'word' : bufname,
	    \ 'dup' : 1,
	    \ 'bufnr' : i
	    \})
    endif
  endfor
endfunction


function! smartfinder#buffer#get_prompt()
  return s:PROMPT
endfunction


function! smartfinder#buffer#get_item_list()
  return s:cache_buflist
endfunction


function! s:make_pattern(str)
  let re = ''
  if empty(a:str)
    let re = '*'
  else
    for c in split(a:str, '\zs')
      if c != '*' && c != '?'
	let re .= '*'
      endif
      let re .= (c != '\' ? c : '/')
    endfor
  endif

  let pair = [ [ '*', '\\.\\*' ], [ '?', '\\.' ] ]
  if !empty(s:REGEX_SEPARATOR_PATTERN)
    call add(pair, s:REGEX_SEPARATOR_PATTERN)
  endif

  for [pat, sub] in pair
    let re = substitute(re, pat, sub, 'g')
  endfor
  return '\V' . re
endfunction


function! smartfinder#buffer#map_plugin_keys()
  inoremap <buffer> <silent> <Plug>SimplefinderBufferOnCR
        \ <C-r>=smartfinder#action_handler('smartfinder#buffer#on_cr')
        \ ? '' : ''<CR>
  inoremap <buffer> <silent> <Plug>SimplefinderBufferOnTab
        \ <C-r>=smartfinder#action_handler('smartfinder#buffer#on_tab')
        \ ? '' : ''<CR>
endfunction


function! smartfinder#buffer#unmap_plugin_keys()
  call smartfinder#safe_iunmap('<Plug>SimplefinderBufferOnCR',
        \                       '<Plug>SimplefinderBufferOnTab')
endfunction


function! smartfinder#buffer#map_default_keys()
  call smartfinder#map_default_keys()
  imap <buffer> <CR>  <Plug>SimplefinderBufferOnCR
  imap <buffer> <Tab> <Plug>SimplefinderBufferOnTab
endfunction


function! smartfinder#buffer#unmap_default_keys()
  call smartfinder#safe_iunmap('<CR>', '<Tab>')
  call smartfinder#unmap_default_keys()
endfunction


function! smartfinder#buffer#omnifunc(findstart, base)
  if a:findstart
    return s:PROMPT_LEN
  else
    let pattern = s:make_pattern(a:base)
    return filter(copy(s:cache_buflist), 'v:val.word =~ ' . string(pattern))
  endif
endfunction


function! smartfinder#buffer#action_open(item)
  return ':' . a:item.bufnr . 'buffer' . "\<CR>"
endfunction


function! smartfinder#buffer#action_delete(item)
  call s:action_delete(a:item, '')
endfunction


function! smartfinder#buffer#action_delete_f(item)
  call s:action_delete(a:item, '!')
endfunction


function! s:action_delete(item, bang)
  return ':' . a:item.bufnr . 'bdelete' . a:bang . "\<CR>"
endfunction


function! smartfinder#buffer#on_cr(item)
  if empty(a:item)
    call smartfinder#error_msg('no input text')
    return
  endif

  let function_name = s:ACTION_NAME_TABLE[s:DEFAULT_ACTION_NAME]
  call smartfinder#end()
  call feedkeys("\<Esc>", 'n')
  call feedkeys(call(function_name, [a:item]), 'n')
endfunction


function! smartfinder#buffer#on_tab(item)
  if empty(a:item)
    call smartfinder#error_msg('no input text')
    return
  endif

  let keys = sort(copy(keys(s:ACTION_KEY_TABLE)))
  let action_count = len(keys)
  let key_names = map(copy(keys), 'strtrans(v:val)')
  let max_key_width = max(map(copy(key_names), 'strlen(v:val)'))
  let action_names = map(copy(keys), 's:ACTION_KEY_TABLE[v:val]')
  let max_action_width = max(map(copy(action_names), 'strlen(v:val)'))
  let spacer = repeat(' ', 2)
  let spacer_len = strlen(spacer)
  let max_column_count = max([(&columns + spacer_len) /
	\ (max_key_width + 1 + max_action_width + spacer_len), 1])
  let max_row_count = (action_count / max_column_count) +
	\ (action_count % max_column_count ? 1 : 0)

  redraw

  let i = 0

  echon a:item.word
  echon "\n"
  for row in range(max_row_count)
    for column in range(max_column_count)
      if i >= action_count
	break
      endif

      echon repeat(' ', max_key_width - strlen(keys[i]))
      echohl SpecialKey
      echon keys[i]
      echohl None
      echon ' ' . action_names[i]
      echon spacer . repeat(' ', max_action_width - strlen(action_names[i]))

      let i += 1
    endfor
    echon "\n"
  endfor

  echon 'action?'
  let key = nr2char(getchar())
  redraw

  if key =~ s:CANCEL_CHOOSE_ACTION_KEY
    return
  endif

  if has_key(s:ACTION_KEY_TABLE, key)
    let function_name = s:ACTION_NAME_TABLE[s:ACTION_KEY_TABLE[key]]
    call smartfinder#end()
    call feedkeys("\<Esc>", 'n')
    call call(function_name, [a:item])
  else
    call smartfinder#error_msg('no action')
    return
  endif
endfunction


" vim: expandtab shiftwidth=2 softtabstop=2 foldmethod=marker
