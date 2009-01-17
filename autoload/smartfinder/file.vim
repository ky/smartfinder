"-----------------------------------------------------------------------------
" smartfinder - file mode
" Author: ky
" Version: 0.2
" Requirements: Vim 7.0 or later, smartfinder.vim 0.2 or later
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

function! smartfinder#file#options()
  let ABSOLUTE_PATH_PATTERN = [ '\V\^\[$~' . s:SEPARATOR . ']' ]
  if has('win16') || has('win32') || has('win64')
    call add(ABSOLUTE_PATH_PATTERN, '\V\^\[a-zA-Z]:' . s:SEPARATOR)
  endif

  let ACTION_KEY_TABLE = {
        \ ':' : 'ex',
        \ 'h' : 'vert aboveleft',
        \ 'H' : 'vert topleft',
        \ 'j' : 'belowright',
        \ 'J' : 'botright',
        \ 'k' : 'aboveleft',
        \ 'K' : 'topleft',
        \ 'l' : 'vert belowright',
        \ 'L' : 'vert botright',
        \ 'o' : 'open',
        \}
  let ACTION_NAME_TABLE = {
        \ 'ex'              : s:SID . 'action_ex',
        \ 'vert aboveleft'  : s:SID . 'action_vert_aboveleft',
        \ 'vert topleft'    : s:SID . 'action_vert_topleft',
        \ 'belowright'      : s:SID . 'action_belowright',
        \ 'botright'        : s:SID . 'action_botright',
        \ 'aboveleft'       : s:SID . 'action_aboveleft',
        \ 'topleft'         : s:SID . 'action_topleft',
        \ 'vert belowright' : s:SID . 'action_vert_belowright',
        \ 'vert botright'   : s:SID . 'action_vert_botright',
        \ 'open'            : s:SID . 'action_open',
        \}
  let DEFAULT_ACTION = 'open'
  let KEY_MAPPING_FUNCTION = 'smartfinder#file#map_default_keys'
  let KEY_UNMAPPING_FUNCTION = 'smartfinder#file#unmap_default_keys'
  let PROMPT = 'file>'

  return {
        \ 'absolute_path_pattern'  : ABSOLUTE_PATH_PATTERN,
        \ 'action_key_table'       : ACTION_KEY_TABLE,
        \ 'action_name_table'      : ACTION_NAME_TABLE,
        \ 'default_action'         : DEFAULT_ACTION,
        \ 'key_mapping_function'   : KEY_MAPPING_FUNCTION,
        \ 'key_unmapping_function' : KEY_UNMAPPING_FUNCTION,
        \ 'prompt'                 : PROMPT,
        \}
endfunction


function! s:get_option()
  return g:smartfinder_options.mode[s:MODE_NAME]
endfunction


function! smartfinder#file#initialize()
  let s:file_completion_list = []
  let s:last_input_string = ''
  let s:update_filelist = 1
endfunction


function! smartfinder#file#terminate()
  let s:file_completion_list = []
endfunction


function! smartfinder#file#completion_list()
  return s:file_completion_list
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
              \    : '[' . (c !~ '\V\[`{}]' ? c : '\' . c) . ']')
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
  inoremap <buffer> <Plug>SmartFinderFileSelected
        \ <C-r>=smartfinder#select_completion(
        \ 'smartfinder#file#default_action') ? '' : ''<CR>
endfunction


function! smartfinder#file#unmap_plugin_keys()
  call smartfinder#safe_iunmap(['<Plug>SmartFinderFileSelected'])
endfunction


function! smartfinder#file#map_default_keys()
  call smartfinder#map_default_keys()
  imap <buffer> <CR>  <Plug>SmartFinderFileSelected
endfunction


function! smartfinder#file#unmap_default_keys()
  call smartfinder#safe_iunmap(['<CR>'])
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
  if a:findstart
    return 0
  else
    let option = s:get_option()
    let prompt_len = strlen(option['prompt'])
    let base = a:base[prompt_len :]
    let dir = matchstr(base, s:DIR_PATTERN)
    let fname = base[strlen(dir) :]
    let show_dot_files = fname =~ '\V\^.\$'
    let diff_str = s:last_input_string[strlen(base) :]

    if s:update_filelist ||
          \ show_dot_files ||
          \ strlen(base) < 1 ||
          \ base =~ s:NO_FILENAME_PATTERN ||
          \ diff_str =~ s:NO_FILENAME_PATTERN
      let s:update_filelist = 0
      let s:file_completion_list = []
      
      let abs = 0
      for absolute_path_pattern in option['absolute_path_pattern']
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
          call add(s:file_completion_list,
                \  {
                \    'word' : substitute(i, '\', s:SEPARATOR, 'g'),
                \    'dup' : 0
                \  }
                \)
        endfor
      else
        for i in items
          call add(s:file_completion_list, { 'word' : i, 'dup' : 0 })
        endfor
      endif
    endif

    if empty(s:file_completion_list)
      return []
    endif

    let s:last_input_string = base

    let fname_pattern = s:make_regex_pattern(fname)
    let filter_cond =
          \ 's:extract_filename(v:val.word) =~? ' . string(fname_pattern)
    let result = filter(copy(s:file_completion_list), filter_cond)
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


function! smartfinder#file#default_action(item)
  if empty(a:item)
    call smartfinder#error_message('no input text')
    return
  endif

  let option = s:get_option()
  let function_name = option['action_name_table'][option['default_action']]
  call smartfinder#end()
  call feedkeys("\<Esc>", 'n')
  call feedkeys(call(function_name, [a:item]), 'n')
endfunction


function! s:sid_prefix()
  return matchstr(expand('<sfile>'), '<SNR>\d\+_')
endfunction


function! s:do_open(open_cmd, item)
  return printf(":%s %s\<CR>",
        \       a:open_cmd, smartfinder#fnameescape(a:item.word))
endfunction


function! s:create_action(info)
  let function_name = printf('action_%s', a:info.name)
  let template  = "function! s:%s(item)\n"
  let template .= "  return %s\n"
  let template .= "endfunction"
  execute printf(template, function_name, a:info.action)
endfunction


function! s:create_file_actions()
  let tbl = [
        \ {
        \   'name'   : 'ex',
        \   'action' : 'printf(": %s\<C-b>",' .
        \                     'smartfinder#fnameescape(a:item.word))'
        \ },
        \ {
        \   'name'   : 'vert_aboveleft',
        \   'action' : 's:do_open("vertical aboveleft split", a:item)'
        \ },
        \ {
        \   'name'   : 'vert_topleft',
        \   'action' : 's:do_open("vertical topleft split", a:item)'
        \ },
        \ {
        \   'name'   : 'belowright',
        \   'action' : 's:do_open("belowright split", a:item)'
        \ },
        \ {
        \   'name'   : 'botright',
        \   'action' : 's:do_open("botright split", a:item)'
        \ },
        \ {
        \   'name'   : 'aboveleft',
        \   'action' : 's:do_open("aboveleft split", a:item)'
        \ },
        \ {
        \   'name'   : 'topleft',
        \   'action' : 's:do_open("topleft split", a:item)'
        \ },
        \ {
        \   'name'   : 'vert_belowright',
        \   'action' : 's:do_open("vertical belowright split", a:item)'
        \ },
        \ {
        \   'name'   : 'vert_botright',
        \   'action' : 's:do_open("vertical botright split", a:item)'
        \ },
        \ {
        \   'name'   : 'open',
        \   'action' : 's:do_open("edit", a:item)'
        \ },
        \]

  for v in tbl
    call s:create_action(v)
  endfor
endfunction


let s:file_completion_list = []
let s:last_input_string = ''
let s:update_filelist = -1

let s:ESCAPE_KEY = '\'
let s:MODE_NAME = expand('<sfile>:t:r')
let s:SEPARATOR = '/'
let s:DIR_PATTERN = '\V\^\.\*' . s:SEPARATOR
let s:NO_FILENAME_PATTERN = '\V\^\.\*' . s:SEPARATOR . '\$'
let s:DRIVE_LETTER_PATTERN = '\V\^\.\{-}' . s:SEPARATOR
let s:SID = s:sid_prefix()
call s:create_file_actions()




" vim: expandtab shiftwidth=2 softtabstop=2 foldmethod=marker
