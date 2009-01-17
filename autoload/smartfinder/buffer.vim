"-----------------------------------------------------------------------------
" smartfinder - buffer mode
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

function! smartfinder#buffer#options()
  let ACTION_KEY_TABLE = {
        \ ':' : 'ex',
        \ 'd' : 'bdelete',
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
        \ 'bdelete'         : s:SID . 'action_bdelete',
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
  let MAP_KEYS_FUNCTION = 'smartfinder#buffer#map_default_keys'
  let UNMAP_KEYS_FUNCTION = 'smartfinder#buffer#unmap_default_keys'
  let PROMPT = 'buffer>'

  return {
        \ 'action_key_table'    : ACTION_KEY_TABLE,
        \ 'action_name_table'   : ACTION_NAME_TABLE,
        \ 'default_action'      : DEFAULT_ACTION,
        \ 'map_keys_function'   : MAP_KEYS_FUNCTION,
        \ 'unmap_keys_function' : UNMAP_KEYS_FUNCTION,
        \ 'prompt'              : PROMPT,
        \}
endfunction


function! s:get_option()
  return g:smartfinder_options.mode[s:MODE_NAME]
endfunction


function! smartfinder#buffer#initialize()
  let last_bufnr = bufnr('$')
  let width = len(last_bufnr)

  let s:buffer_completion_list = []

  for i in range(1, bufnr('$'))
    if bufexists(i) && buflisted(i)
      let bufname = bufname(i)
      if empty(bufname)
	let bufname = '[no name] (#' . i . ')'
      endif
      call add(s:buffer_completion_list, {
	    \ 'word' : bufname,
	    \ 'dup' : 1,
	    \ 'bufnr' : i
	    \})
    endif
  endfor
endfunction


function! smartfinder#buffer#terminate()
  let s:buffer_completion_list = []
endfunction


function! smartfinder#buffer#completion_list()
  return s:buffer_completion_list
endfunction


function! smartfinder#buffer#map_plugin_keys()
  inoremap <buffer> <Plug>SmartFinderBufferSelected
        \ <C-r>=smartfinder#select_completion(
        \ 'smartfinder#buffer#default_action') ? '' : ''<CR>
endfunction


function! smartfinder#buffer#unmap_plugin_keys()
  call smartfinder#safe_iunmap(['<Plug>SmartFinderBufferSelected'])
endfunction


function! smartfinder#buffer#map_default_keys()
  call smartfinder#map_default_keys()
  imap <buffer> <CR>  <Plug>SmartFinderBufferSelected
endfunction


function! smartfinder#buffer#unmap_default_keys()
  call smartfinder#safe_iunmap(['<CR>'])
  call smartfinder#unmap_default_keys()
endfunction


function! smartfinder#buffer#omnifunc(findstart, base)
  if a:findstart
    return 0
  else
    let prompt_len = strlen(s:get_option()['prompt'])
    let pattern = smartfinder#make_pattern(a:base[prompt_len :])
    let result = filter(copy(s:buffer_completion_list),
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


function! smartfinder#buffer#default_action(item)
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
  return printf(":%s #%d\<CR>", a:open_cmd, a:item.bufnr)
endfunction


function! s:create_action(info)
  let function_name = printf('action_%s', a:info.name)
  let template  = "function! s:%s(item)\n"
  let template .= "  return %s\n"
  let template .= "endfunction"
  execute printf(template, function_name, a:info.action)
endfunction


function! s:create_buffer_actions()
  let tbl = [
        \
        \ {
        \   'name'   : 'ex',
        \   'action' : 'printf(": %s\<C-b>",' .
        \                     'smartfinder#fnameescape(a:item.word))'
        \ },
        \ {
        \   'name'   : 'bdelete',
        \   'action' : 'printf(":%dbdelete\<CR>", a:item.bufnr)',
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
        \   'action' : 'printf(":%dbuffer\<CR>", a:item.bufnr)'
        \ },
        \]

  for v in tbl
    call s:create_action(v)
  endfor
endfunction


let s:buffer_completion_list = []

let s:MODE_NAME = expand('<sfile>:t:r')
let s:SID = s:sid_prefix()
call s:create_buffer_actions()




" vim: expandtab shiftwidth=2 softtabstop=2 foldmethod=marker
