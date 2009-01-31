"-----------------------------------------------------------------------------
" smartfinder - bookmark mode
" Author: ky
" Version: 0.1
" Requirements: Vim 7.0 or later, smartfinder.vim 0.2 or later
" License: The MIT License {{{
" The MIT License
"
" Copyright (C) 2009 ky
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

function! smartfinder#bookmark#initialize(...)
  let list = s:get_option()['bookmark_list']
  if empty(list)
    call smartfinder#error_message(
          \ 'g:smartfinder_options.bookmark.bookmark_list is empty.')
    return
  endif

  for [name, path] in list
    call add(s:completion_list,
          \  { 'word' : name, 'dup' : 0, 'path' : path })
  endfor
endfunction


function! smartfinder#bookmark#terminate()
  let s:completion_list = []
endfunction


function! smartfinder#bookmark#options()
  return {
        \ 'key_mappings'   : 'smartfinder#bookmark#map_mode_keys',
        \ 'key_unmappings' : 'smartfinder#bookmark#unmap_mode_keys',
        \ 'bookmark_list'  : [],
        \ 'prompt'         : 'bookmark>',
        \}
endfunction


function! smartfinder#bookmark#completion_list()
  return s:completion_list
endfunction


function! smartfinder#bookmark#map_plugin_keys()
  inoremap <buffer> <Plug>SmartFinderBookmarkSelected
        \ <C-r>=smartfinder#select_completion(
        \ 'smartfinder#bookmark#default_action') ? '' : ''<CR>
endfunction


function! smartfinder#bookmark#unmap_plugin_keys()
  call smartfinder#safe_iunmap('<Plug>SmartFinderBookmarkSelected')
endfunction


function! smartfinder#bookmark#map_mode_keys()
  imap <buffer> <CR> <Plug>SmartFinderBookmarkSelected
endfunction


function! smartfinder#bookmark#unmap_mode_keys()
  call smartfinder#safe_iunmap('<CR>')
endfunction


function! smartfinder#bookmark#default_action(item)
  if empty(a:item)
    call smartfinder#eror_message('no input text')
    return
  endif

  call smartfinder#switch_mode(
        \ 'file', substitute(expand(a:item.path), '\', s:SEPARATOR, 'g'))
endfunction


function! smartfinder#bookmark#omnifunc(findstart, base)
  if a:findstart
    return 0
  else
    let prompt_len = len(s:get_option()['prompt'])
    let pattern = smartfinder#make_pattern(a:base[prompt_len :])
    let result = filter(copy(s:completion_list),
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


function! s:get_option()
  return g:smartfinder_options.mode[s:MODE_NAME]
endfunction


let s:completion_list =  []
let s:MODE_NAME = expand('<sfile>:t:r')
let s:SEPARATOR = '/'




" vim: expandtab shiftwidth=2 softtabstop=2 foldmethod=marker
