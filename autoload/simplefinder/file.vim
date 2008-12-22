"-----------------------------------------------------------------------------
" simplefinder - file
" Author: ky
" Version: 0.1
" License: The MIT License
" The MIT License {{{
"
" Copyright (C) 2008 ky
"
" Permission is hereby granted, free of charge, to any person obtaining a copy
" of this software and associated documentation files (the "Software"), to deal
" in the Software without restriction, including without limitation the rights
" to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
" copies of the Software, and to permit persons to whom the Software is
" furnished to do so, subject to the following conditions:
" 
" The above copyright notice and this permission notice shall be included in
" all copies or substantial portions of the Software.
" 
" THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
" IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
" FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
" AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
" LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
" OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
" THE SOFTWARE.
" }}}
"-----------------------------------------------------------------------------

if has('win16') || has('win32') || has('win64')
  let s:SEPARATOR_PATTERN = '[/\\]'
  let s:SEPARATOR = '\'
else
  let s:SEPARATOR_PATTERN = '/'
  let s:SEPARATOR = '/'
endif

let s:PROMPT = 'file>'
let s:DIR_PATTERN = '^.*' . s:SEPARATOR_PATTERN
let s:NO_FILENAME_PATTERN = '^.*' . s:SEPARATOR_PATTERN . '$'
let s:SHOW_DOT_FILE_PATTERN = '^.*' . s:SEPARATOR_PATTERN . '*\.$'
let s:DEFAULT_ACTION_NAME = 'open'
let s:ACTION_KEY_TABLE = {
      \ 'o' : 'open',
      \ 'O' : 'open!',
      \}
let s:ACTION_NAME_TABLE = {
      \ 'open'  : 'simplefinder#file#action_open',
      \ 'open!' : 'simplefinder#file#action_open_f',
      \}


let s:cache_filelist = []
let s:last_input_string = ''


function! simplefinder#file#init()
  let s:cache_filelist = []
  let s:last_input_string = ''
endfunction


function! simplefinder#file#get_prompt()
  return s:PROMPT
endfunction


function! simplefinder#file#get_item_list()
  return s:cache_filelist
endfunction


function! s:make_relative_dir_pattern(dir)
  let wi = ''
  for c in split(a:dir, '\zs')
    if c != '*' && c != '?' && c != '.'
      let wi .= '*'
    endif
    let wi .= (c != '\' ? c : '/')
  endfor
  return wi
endfunction


function! s:make_absolute_dir_pattern(dir)
  let head = matchstr(a:dir, '^.\{-}' . s:SEPARATOR_PATTERN)
  return head . s:make_relative_dir_pattern(a:dir[strlen(head) :])
endfunction


function! s:make_regex_pattern(str)
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
  let re = escape(re, '\')
  for [pat, sub] in [
        \ [ '\', '\\[\\/]' ],
        \ [ '*', '\\.\\*' ],
        \ [ '?', '\\.' ]
        \]
    let re = substitute(re, pat, sub, 'g')
  endfor
  return '\V' . re
endfunction


function! simplefinder#file#map_plugin_keys()
  inoremap <buffer> <Plug>SimplefinderFileOnCR
        \ <C-r>=simplefinder#action_handler('simplefinder#file#on_cr')
        \ ? '' : ''<CR>
  inoremap <buffer> <Plug>SimplefinderFileOnTab
        \ <C-r>=simplefinder#action_handler('simplefinder#file#on_tab')
        \ ? '' : ''<CR>
endfunction


function! simplefinder#file#unmap_plugin_keys()
  call simplefinder#safe_iunmap('<Plug>SimplefinderFileOnCR',
        \                      '<Plug>SimplefinderFileOnTab')
endfunction


function! simplefinder#file#map_default_keys()
  call simplefinder#map_default_keys()
  imap <buffer> <CR>  <Plug>SimplefinderFileOnCR
  imap <buffer> <Tab> <Plug>SimplefinderFileOnTab
  "inoremap <buffer> <silent> <CR> <C-r>=simplefinder#action_handler('simplefinder#file#on_cr') ? '' : ''<CR>
  "inoremap <buffer> <silent> <Tab> <C-r>=simplefinder#action_handler('simplefinder#file#on_tab') ? '' : ''<CR>
endfunction


function! simplefinder#file#unmap_default_keys()
  call simplefinder#safe_iunmap('<CR>', '<Tab>')
  call simplefinder#unmap_default_keys()
endfunction


function! s:extract_filename(file_path)
  let num = matchend(a:file_path, s:DIR_PATTERN)
  return a:file_path[(num < 0 ? 0 : num) :]
endfunction


function! s:create_filename_list(dir_wi, dot_files_flag)
  let items = []
  if a:dot_files_flag
    let items += split(glob(a:dir_wi . '.*'), "\n")
  endif
  let items += split(glob(a:dir_wi . '*'), "\n")
  return items
endfunction


function! simplefinder#file#omnifunc(findstart, base)
  if a:findstart
    return strlen(s:PROMPT)
  else
    let dir = matchstr(a:base, s:DIR_PATTERN)
    let fname = a:base[strlen(dir) :]
    let show_dot_files = (a:base =~ s:SHOW_DOT_FILE_PATTERN
          \               ? 1
          \               : (fname =~ '^.'))
    let diff_str = s:last_input_string[strlen(a:base) :]

    if show_dot_files ||
          \ strlen(a:base) < 1 ||
          \ a:base =~ s:NO_FILENAME_PATTERN ||
          \ diff_str =~ s:NO_FILENAME_PATTERN
      let s:cache_filelist = []
      
      let items = s:create_filename_list(s:make_absolute_dir_pattern(dir),
            \                            show_dot_files)
      if empty(items)
        let items = s:create_filename_list(s:make_relative_dir_pattern(dir),
              \                            show_dot_files)
      endif

      for i in items
        call add(s:cache_filelist, { 'word' : i, 'dup' : 0 })
      endfor
      call map(s:cache_filelist,
            \ 'extend(v:val,' .
            \        'isdirectory(v:val.word) ' .
            \        '? { "abbr" : v:val.word . s:SEPARATOR } ' .
            \        ': {})')
    endif

    let s:last_input_string = a:base

    let fname_pattern = s:make_regex_pattern(fname)
    let filter_cond =
          \ 's:extract_filename(v:val.word) =~? ' . string(fname_pattern)
    return filter(copy(s:cache_filelist), filter_cond)
  endif
endfunction


function! s:action_open(item, bang)
  return ':edit' . a:bang . ' ' . fnameescape(a:item.word) . "\<CR>"
endfunction


function! simplefinder#file#action_open(item)
  return s:action_open(a:item, '')
endfunction


function! simplefinder#file#action_open_f(item)
  return s:action_open(a:item, '!')
endfunction


function! simplefinder#file#on_cr(item)
  if empty(a:item)
    call simplefinder#error_msg('no input text')
    return
  endif

  let function_name = s:ACTION_NAME_TABLE[s:DEFAULT_ACTION_NAME]
  call simplefinder#end()
  call feedkeys("\<Esc>", 'n')
  call feedkeys(call(function_name, [a:item]), 'n')
endfunction


function! simplefinder#file#on_tab(item)
  if empty(a:item)
    call simplefinder#error_msg('no input text')
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

  if key != "\<Esc>" && key != "\<C-c>"
    if has_key(s:ACTION_KEY_TABLE, key)
      let function_name = s:ACTION_NAME_TABLE[s:ACTION_KEY_TABLE[key]]
      call simplefinder#end()
      call feedkeys("\<Esc>", 'n')
      call call(function_name, [a:item])
    else
      call simplefinder#error_msg('no action')
      return
    endif
  endif
endfunction


" vim: expandtab shiftwidth=2 softtabstop=2 foldmethod=marker
