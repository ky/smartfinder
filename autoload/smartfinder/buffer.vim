"-----------------------------------------------------------------------------
" smartfinder - buffer
" Author: ky
" Version: 0.1.1
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

let s:MODE_NAME = expand('<sfile>:t:r')


let s:cache_buflist = []


function! smartfinder#buffer#options()
  let ACTION_KEY_TABLE = {
        \ 'o' : 'open',
        \ 'd' : 'delete',
        \ 'D' : 'delete!',
        \}
  let ACTION_NAME_TABLE = {
        \ 'open'    : 'smartfinder#buffer#action_open',
        \ 'delete'  : 'smartfinder#buffer#action_delete',
        \ 'delete!' : 'smartfinder#buffer#action_delete_f',
        \}
  let DEFAULT_ACTION = 'open'
  let PROMPT = 'buffer>'

  return {
        \ 'action_key_table'  : ACTION_KEY_TABLE,
        \ 'action_name_table' : ACTION_NAME_TABLE,
        \ 'default_action'    : DEFAULT_ACTION,
        \ 'prompt'            : PROMPT,
        \}
endfunction


function! s:get_option()
  return g:SmartFinderOptions.Mode[s:MODE_NAME]
endfunction


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
  inoremap <buffer> <silent> <Plug>SmartFinderBufferOnCR
        \ <C-r>=smartfinder#action_handler('smartfinder#buffer#on_cr')
        \ ? '' : ''<CR>
  inoremap <buffer> <silent> <Plug>SmartFinderBufferOnTab
        \ <C-r>=smartfinder#action_handler('smartfinder#buffer#on_tab')
        \ ? '' : ''<CR>
endfunction


function! smartfinder#buffer#unmap_plugin_keys()
  call smartfinder#safe_iunmap('<Plug>SmartFinderBufferOnCR',
        \                       '<Plug>SmartFinderBufferOnTab')
endfunction


function! smartfinder#buffer#map_default_keys()
  call smartfinder#map_default_keys()
  imap <buffer> <CR>  <Plug>SmartFinderBufferOnCR
  imap <buffer> <Tab> <Plug>SmartFinderBufferOnTab
endfunction


function! smartfinder#buffer#unmap_default_keys()
  call smartfinder#safe_iunmap('<CR>', '<Tab>')
  call smartfinder#unmap_default_keys()
endfunction


function! smartfinder#buffer#omnifunc(findstart, base)
  if a:findstart
    return 0
  else
    let prompt_len = strlen(s:get_option()['prompt'])
    let pattern = s:make_pattern(a:base[prompt_len :])
    let result = filter(copy(s:cache_buflist), 'v:val.word =~ ' . string(pattern))
    let format = '%' . (prompt_len > 2 ? prompt_len - 2 : '') . 'd: %s'
    let num = 0
    for item in result
      let num += 1
      let item.abbr = printf(format, num, item.word)
    endfor
    return result
  endif
endfunction


function! smartfinder#buffer#action_open(item)
  return ':' . a:item.bufnr . 'buffer' . "\<CR>"
endfunction


function! smartfinder#buffer#action_delete(item)
  return s:action_delete(a:item, '')
endfunction


function! smartfinder#buffer#action_delete_f(item)
  return s:action_delete(a:item, '!')
endfunction


function! s:action_delete(item, bang)
  return ':' . a:item.bufnr . 'bdelete' . a:bang . "\<CR>"
endfunction


function! smartfinder#buffer#on_cr(item)
  if empty(a:item)
    call smartfinder#error_msg('no input text')
    return
  endif

  let option = s:get_option()
  let function_name = option['action_name_table'][option['default_action']]
  call smartfinder#end()
  call feedkeys("\<Esc>", 'n')
  call feedkeys(call(function_name, [a:item]), 'n')
endfunction


function! smartfinder#buffer#on_tab(item)
  if empty(a:item)
    call smartfinder#error_msg('no input text')
    return
  endif

  let option = s:get_option()
  let action_key_table = option['action_key_table']
  let keys = sort(copy(keys(action_key_table)))
  let action_count = len(keys)
  let key_names = map(copy(keys), 'strtrans(v:val)')
  let max_key_width = max(map(copy(key_names), 'strlen(v:val)'))
  let action_names = map(copy(keys), 'action_key_table[v:val]')
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

  if key == "\<Esc>" || key == "\<C-c>"
    return
  endif

  if has_key(action_key_table, key)
    let action_name_table = option['action_name_table']
    let function_name = action_name_table[action_key_table[key]]
    call smartfinder#end()
    call feedkeys("\<Esc>", 'n')
    call feedkeys(call(function_name, [a:item]), 'n')
  else
    call smartfinder#error_msg('no action')
    return
  endif
endfunction


" vim: expandtab shiftwidth=2 softtabstop=2 foldmethod=marker
