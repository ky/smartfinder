"-----------------------------------------------------------------------------
" smartfinder - file mode
" Author: ky
" Version: 0.2.1
" Requirements: Vim 7.0 or later, smartfinder.vim 0.2 or later
" License: The MIT License {{{
" The MIT License
"
" Copyright (C) 2008-2009 ky
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
  let MRU_FILE = '$HOME/.smartfinder_file_mru'
  let KEY_MAPPINGS = 'smartfinder#file#map_mode_keys'
  let KEY_UNMAPPINGS = 'smartfinder#file#unmap_mode_keys'
  let MAX_MRU = 50
  let PROMPT = 'file>'

  return {
        \ 'absolute_path_pattern' : ABSOLUTE_PATH_PATTERN,
        \ 'action_key_table'      : ACTION_KEY_TABLE,
        \ 'action_name_table'     : ACTION_NAME_TABLE,
        \ 'default_action'        : DEFAULT_ACTION,
        \ 'mru_file'              : MRU_FILE,
        \ 'key_mappings'          : KEY_MAPPINGS,
        \ 'key_unmappings'        : KEY_UNMAPPINGS,
        \ 'max_mru'               : MAX_MRU,
        \ 'prompt'                : PROMPT,
        \}
endfunction


function! s:get_option()
  return g:smartfinder_options.mode[s:MODE_NAME]
endfunction


function! smartfinder#file#initialize(...)
  let s:completion_list = []
  let s:last_input_string = ''
  let s:mru_show = 0
  let s:update_filelist = 1

  if !exists('s:mru_list')
    let s:mru_list = s:load_mru()
  endif

  augroup SmartFinderFileAugroup
    autocmd!
    autocmd VimLeave * call s:save_mru()
  augroup END

  if a:0 > 0
    for o in a:000
      if o == '--cache-clear'
        let s:completion_cache = {}
      elseif o == '--mru'
        let s:mru_show = 1
      endif
    endfor
  endif

  if s:mru_show
    let s:mru_completion_list = []
    for fname in s:mru_list
      if filereadable(fname)
        let completion_item =
              \ { 'word' : fnamemodify(fname, ':~:.'), 'dup' : 0 }
        call add(s:mru_completion_list, completion_item) 
      endif
    endfor
  endif
endfunction


function! smartfinder#file#terminate()
  let s:completion_list = []
  let s:mru_completion_list = []
endfunction


function! smartfinder#file#completion_list()
  if s:mru_show
    return s:mru_completion_list
  else
    return s:completion_list
  endif
endfunction


function! s:make_relative_dir_pattern(dir)
  let wi = ''
  let escape = 0
  let star = 0
  let sep = 1

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
      if c == '*' || c == '?' || (c == '.' && sep)
        let wi .= c
        if c == '*'
          let star = 1
        else
          let star = 0
        endif
      else
        if star
          let star = 0
        else
          let wi .= '*'
        endif
        let wi .= (c =~ '\V\[a-zA-Z_/()-]'
              \    ? c
              \    : '[' . (c !~ '\V\[`{}]' ? c : '\' . c) . ']')
      endif

      if c == '/'
        let sep = 1
      else
        let sep = 0
      endif
    endif
  endfor

  return wi
endfunction


function! s:make_absolute_dir_pattern(dir)
  let drive = matchstr(a:dir, s:DRIVE_LETTER_PATTERN)
  return drive . s:make_relative_dir_pattern(a:dir[len(drive) :])
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
  inoremap <buffer> <Plug>SmartFinderFileToggleMRU
        \ <C-r>=smartfinder#file#toggle_mru() ? '' : ''<CR>
endfunction


function! smartfinder#file#unmap_plugin_keys()
  call smartfinder#safe_iunmap('<Plug>SmartFinderFileSelected')
  call smartfinder#safe_iunmap('<Plug>SmartFinderFileToggleMRU')
endfunction


function! smartfinder#file#map_mode_keys()
  imap <buffer> <CR>  <Plug>SmartFinderFileSelected
  imap <buffer> <Tab>  <Plug>SmartFinderFileToggleMRU
endfunction


function! smartfinder#file#unmap_mode_keys()
  call smartfinder#safe_iunmap('<CR>')
  call smartfinder#safe_iunmap('<Tab>')
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
  if s:mru_show
    return s:mru_omnifunc(a:findstart, a:base)
  else
    return s:file_omnifunc(a:findstart, a:base)
endfunction


function! s:file_omnifunc(findstart, base)
  if a:findstart
    return 0
  else
    let option = s:get_option()
    let prompt_len = len(option['prompt'])
    let base = a:base[prompt_len :]
    let dir = matchstr(base, s:DIR_PATTERN)
    let fname = base[len(dir) :]
    let show_dot_files = fname =~ '\V\^.'
    let cache_key = show_dot_files . ':' . fnamemodify('.', ':p') . ':' . dir

    if has_key(s:completion_cache, cache_key)
      let s:completion_list = s:completion_cache[cache_key]
    else
      if s:update_filelist ||
            \ show_dot_files ||
            \ empty(base) ||
            \ base =~ s:NO_FILENAME_PATTERN ||
            \ s:last_input_string[len(base) :] =~ s:NO_FILENAME_PATTERN
        let s:update_filelist = 0
        let s:completion_list = []

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
            call add(s:completion_list,
                  \  {
                  \    'word' : substitute(i, '\', s:SEPARATOR, 'g'),
                  \    'dup' : 0
                  \  }
                  \)
          endfor
        else
          for i in items
            call add(s:completion_list, { 'word' : i, 'dup' : 0 })
          endfor
        endif
      endif

      let s:completion_cache[cache_key] = s:completion_list
    endif

    if empty(s:completion_list)
      return []
    endif

    let s:last_input_string = base

    let fname_pattern = s:make_regex_pattern(fname)
    let result = filter(copy(s:completion_list),
          \ 's:extract_filename(v:val.word) =~? ' . string(fname_pattern))
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


function! s:mru_omnifunc(findstart, base)
  if a:findstart
    return 0
  else
    let prompt_len = len(s:get_option()['prompt'])
    let pattern = smartfinder#make_pattern(a:base[prompt_len :])
    let result = filter(copy(s:mru_completion_list),
          \             'v:val.word =~ ' . string(pattern))
    let format = '%' . (prompt_len > 2 ? prompt_len - 2 : '') . 'd: %s'
    let num = 0
    for item in result
      let num += 1
      let item.abbr = printf(format, num, item.word)
    endfor
    return result
  endif
endfunction


function! smartfinder#file#toggle_mru()
  if s:mru_show
    call smartfinder#switch_mode('file', '')
  else
    call smartfinder#switch_mode('file', '', '--mru')
  endif
endfunction


function! s:mru_file_name()
  return expand(s:get_option()['mru_file'])
endfunction


function! s:load_mru()
  let result = []
  let filename = s:mru_file_name()

  try
    if filereadable(filename)
      for fname in readfile(filename, '')
        if filereadable(fname)
          call add(result, fname) 
        endif
      endfor
    endif
  catch /.*/
    let result = []
  endtry

  return result
endfunction


function! s:save_mru()
  try
    call writefile(s:mru_list, s:mru_file_name())
  catch /.*/
  endtry
endfunction


function! s:add_mru(filename)
  if has('win16') || has('win32') || has('win64')
    let fullpath = fnamemodify(a:filename, ':p:gs?\\?' . s:SEPARATOR . '?')
  else
    let fullpath = fnamemodify(a:filename, ':p')
  endif

  call filter(s:mru_list, 'v:val !=# fullpath')
  call insert(s:mru_list, fullpath, 0)

  let max_mru = s:get_option()['max_mru']
  if len(s:mru_list) > max_mru
    call remove(s:mru_list, max_mru, -1)
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
  call s:add_mru(a:item.word)
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

  call map(tbl, 's:create_action(v:val)')
endfunction


if !exists('s:completion_cache')
  let s:completion_cache = {}
endif
let s:completion_list = []
let s:mru_completion_list = []
let s:last_input_string = ''
let s:mru_show = 0
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
