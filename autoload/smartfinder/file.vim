"-----------------------------------------------------------------------------
" smartfinder - file
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

let s:ESCAPE_KEY = '\'
let s:MODE_NAME = expand('<sfile>:t:r')

let s:SEPARATOR = '/'
let s:DIR_PATTERN = '\V\^\.\*' . s:SEPARATOR
let s:NO_FILENAME_PATTERN = '\V\^\.\*' . s:SEPARATOR . '\$'
let s:DRIVE_LETTER_PATTERN = '\V\^\.\{-}' . s:SEPARATOR

let s:cache_filelist = []
let s:last_input_string = ''


function! smartfinder#file#options()
  let ABSOLUTE_PATH_PATTERN = [ '\V\^\[$~' . s:SEPARATOR . ']' ]
  if has('win16') || has('win32') || has('win64')
    call add(ABSOLUTE_PATH_PATTERN, '\V\^\[a-zA-Z]:' . s:SEPARATOR)
  endif

  let ACTION_KEY_TABLE = {
        \ 'o' : 'open',
        \ 'O' : 'open!',
        \}

  let ACTION_NAME_TABLE = {
        \ 'open'  : 'smartfinder#file#action_open',
        \ 'open!' : 'smartfinder#file#action_open_f',
        \}

  let DEFAULT_ACTION = 'open'
  let PROMPT = 'file>'

  return {
        \ 'absolute_path_pattern' : ABSOLUTE_PATH_PATTERN,
        \ 'action_key_table'      : ACTION_KEY_TABLE,
        \ 'action_name_table'     : ACTION_NAME_TABLE,
        \ 'default_action'        : DEFAULT_ACTION,
        \ 'prompt'                : PROMPT,
        \}
endfunction


function! s:get_option()
  return g:SmartFinderOptions.Mode[s:MODE_NAME]
endfunction


function! smartfinder#file#init()
  let s:cache_filelist = []
  let s:last_input_string = ''
endfunction


function! smartfinder#file#get_item_list()
  return s:cache_filelist
endfunction


function! s:make_relative_dir_pattern(dir)
  let wi = ''
  let escape = 0
  let star = 0

  for c in split(a:dir, '\zs')
    if escape
      let wi .= c
      let escape = 0
      continue
    endif

    if c == s:ESCAPE_KEY
      if star
        let star = 0
      else
        let wi .= '*'
      endif
      let wi .= s:ESCAPE_KEY
      let escape = 1
    else
      if c != '*' && c != '?' && c != '.'
        if star
          let star = 0
        else
          let wi .= '*'
        endif
        let wi .= (c =~ '\V\[a-zA-Z_/()-]'
              \    ? c
              \    : '[' . (c != '`' ? c : '\' . c) . ']')
      else
        let wi .= c
        if c == '*'
          let star = 1
        else
          let star = 0
        endif
      endif
    endif
  endfor

  return wi
endfunction


function! s:make_absolute_dir_pattern(dir)
  let drive = matchstr(a:dir, s:DRIVE_LETTER_PATTERN)
  return drive . s:make_relative_dir_pattern(a:dir[strlen(drive) :])
endfunction


function! s:make_regex_pattern(str)
  if empty(a:str)
    return '\V\.\*'
  endif

  let re = ''

  let escape = 0
  for c in split(a:str, '\zs')
    if escape
      let re .= (c != '\' ? c : '\\')
      let escape = 0
      continue
    endif

    if c == s:ESCAPE_KEY
      let escape = 1
    else
      if c == '?'
        let re .= '\.'
      else
        let re .= '\.\*'
        if c != '*'
          let re .= c
        endif
      endif
    endif
  endfor

  if escape
    let re .= '\\'
  endif

  return '\V' . re
endfunction


function! smartfinder#file#map_plugin_keys()
  inoremap <buffer> <Plug>SmartFinderFileOnCR
        \ <C-r>=smartfinder#action_handler('smartfinder#file#on_cr')
        \ ? '' : ''<CR>
  inoremap <buffer> <Plug>SmartFinderFileOnTab
        \ <C-r>=smartfinder#action_handler('smartfinder#file#on_tab')
        \ ? '' : ''<CR>
endfunction


function! smartfinder#file#unmap_plugin_keys()
  call smartfinder#safe_iunmap('<Plug>SmartFinderFileOnCR',
        \                      '<Plug>SmartFinderFileOnTab')
endfunction


function! smartfinder#file#map_default_keys()
  call smartfinder#map_default_keys()
  imap <buffer> <CR>  <Plug>SmartFinderFileOnCR
  imap <buffer> <Tab> <Plug>SmartFinderFileOnTab
endfunction


function! smartfinder#file#unmap_default_keys()
  call smartfinder#safe_iunmap('<CR>', '<Tab>')
  call smartfinder#unmap_default_keys()
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


function! smartfinder#file#omnifunc(findstart, base)
  let prompt_len = strlen(s:get_option()['prompt'])

  if a:findstart
    return 0
  else
    let base = a:base[prompt_len :]
    let dir = matchstr(base, s:DIR_PATTERN)
    let fname = base[strlen(dir) :]
    let show_dot_files = fname =~ '\V\^.\$'
    let diff_str = s:last_input_string[strlen(base) :]

    if show_dot_files ||
          \ strlen(base) < 1 ||
          \ base =~ s:NO_FILENAME_PATTERN ||
          \ diff_str =~ s:NO_FILENAME_PATTERN
      let s:cache_filelist = []
      
      let abs = 0
      for absolute_path_pattern in s:get_option()['absolute_path_pattern']
        if base =~ absolute_path_pattern
          let abs = 1
          break
        endif
      endfor
      if abs
        let pattern = s:make_absolute_dir_pattern(dir)
      else
        let pattern = s:make_relative_dir_pattern(dir)
      endif
      let items = s:create_filename_list(pattern, show_dot_files)

      if has('win16') || has('win32') || has('win64')
        for i in items
          call add(s:cache_filelist,
                \  {
                \    'word' : substitute(i, '\', s:SEPARATOR, 'g'),
                \    'dup' : 0
                \  }
                \)
        endfor
      else
        for i in items
          call add(s:cache_filelist, { 'word' : i, 'dup' : 0 })
        endfor
      endif
    endif

    let s:last_input_string = base

    let fname_pattern = s:make_regex_pattern(fname)
    let filter_cond =
          \ 's:extract_filename(v:val.word) =~? ' . string(fname_pattern)
    let result = filter(copy(s:cache_filelist), filter_cond)
    let num = 0
    let format = '%' . (prompt_len > 2 ? prompt_len - 2 : '') . 'd: %s%s'
    for item in result
      let num += 1
      let item.abbr = printf(format, num, item.word,
            \ isdirectory(item.word) ? s:SEPARATOR : '')
    endfor
    return result
  endif
endfunction


function! s:fnameescape(fname)
  let fname = ''

  if has('win16') || has('win32') || has('win64')
    if exists('*fnameescape')
      let fname = fnameescape(a:fname)
    else
      let fname = escape(a:fname, " \t\n*?`%#'\"|!<")
    endif

    let fname = substitute(fname, '\\!', '!', 'g')
    if fname =~ '\V\^\[+~]'
      let fname = '.\' . fname
    endif
  else
    if exists('*fnameescape')
      let fname = fnameescape(a:fname)
    else
      let fname = escape(a:fname, " \t\n*?[{`$\\%#'\"|!<>")
    endif

    if fname =~ '\V\^\[+~]'
      let fname = '\' . fname
    endif
  endif

  return fname
endfunction


function! s:action_open(item, bang)
  return ':edit' . a:bang . ' ' . s:fnameescape(a:item.word) . "\<CR>"
endfunction


function! smartfinder#file#action_open(item)
  return s:action_open(a:item, '')
endfunction


function! smartfinder#file#action_open_f(item)
  return s:action_open(a:item, '!')
endfunction


function! smartfinder#file#on_cr(item)
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


" test
function! smartfinder#file#on_tab(item)
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
