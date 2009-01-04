"-----------------------------------------------------------------------------
" smartfinder
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

let s:prompt = ''
let s:prompt_len = -1
let s:completeopt = ''
let s:ignorecase = ''
let s:bufnr = -1
let s:winnr = -1
let s:last_col = -1
let s:activate_flag = 0
let s:mode_name = ''
let s:loaded_mode_options = {}


function! s:do(function_name, ...)
  return call(printf('smartfinder#%s#%s', s:mode_name, a:function_name), a:000)
endfunction


function! smartfinder#start(mode_name)
  let s:mode_name = a:mode_name

  call s:init()
  call s:do('init')

  if !has_key(s:loaded_mode_options, s:mode_name)
    if !has_key(g:SmartFinderOptions.Mode, s:mode_name)
      let g:SmartFinderOptions.Mode[s:mode_name] = {}
    endif
    call extend(g:SmartFinderOptions.Mode[s:mode_name],
          \     s:do('options'), 'keep')
    let s:loaded_mode_options[s:mode_name] = 1
  endif

  let s:prompt = g:SmartFinderOptions.Mode[s:mode_name]['prompt']
  let s:prompt_len = strlen(s:prompt)

  if bufexists(s:bufnr)
    leftabove 1split
    silent execute s:bufnr . 'buffer'
  else
    leftabove 1new
    call s:init_buf()
  endif

  call smartfinder#map_plugin_keys()
  call s:do('map_default_keys')

  silent % delete _
  call feedkeys('A', 'n')
endfunction


function! smartfinder#end()
  if s:activate_flag
    call s:term()
  endif
endfunction


function! s:init()
  let s:activate_flag = 1
  let s:last_col = -1
  let s:completeopt = &completeopt
  let s:ignorecase = &ignorecase
  let s:winnr = winnr()

  set completeopt=menuone
  set ignorecase
endfunction


function! s:term()
  let s:activate_flag = 0
  let &completeopt = s:completeopt
  let &ignorecase = s:ignorecase

  call s:do('unmap_default_keys')
  call smartfinder#unmap_plugin_keys()

  close
  execute s:winnr . 'wincmd w'
  redraw
endfunction


function! s:init_buf()
  let s:bufnr = bufnr('%')

  setlocal bufhidden=hide
  setlocal nobuflisted
  setlocal buftype=nofile
  setlocal noswapfile
  setlocal omnifunc=smartfinder#omnifunc
  setlocal filetype=smartfinder

  " :help `=
  silent file `=g:SmartFinderOptions.Global.bufname`

  augroup SmartFinderAugroup
    autocmd!
    autocmd InsertLeave <buffer> nested call smartfinder#end()
    autocmd WinLeave <buffer> call smartfinder#end()
    autocmd BufLeave <buffer> call smartfinder#end()
    autocmd CursorMovedI <buffer> call s:on_cursor_moved_i()
  augroup END
endfunction


function! smartfinder#error_msg(msg)
  echohl ErrorMsg
  echomsg a:msg
  echohl None
  sleep
endfunction


function! s:exists_prompt(line)
  return strlen(a:line) >= s:prompt_len &&
        \ a:line[: s:prompt_len - 1] ==# s:prompt
endfunction


function! s:remove_prompt(line)
  return s:exists_prompt(a:line) ? a:line[s:prompt_len :] : a:line
endfunction


function! s:restore_prompt(line)
  let len = strlen(a:line)
  let i = 0
  while i < s:prompt_len && i < len && s:prompt[i] ==# a:line[i]
    let i += 1
  endwhile
  call setline(1, s:prompt . a:line[i :])
  call feedkeys(repeat("\<Right>", s:prompt_len - i), 'n')
endfunction


function! s:on_cursor_moved_i()
  let line = getline('.')
  let col = col('.')

  if !s:exists_prompt(line)
    call s:restore_prompt(line)
    return
  endif

  if col <= s:prompt_len
    call feedkeys(repeat("\<Right>", s:prompt_len - col + 1), 'n')
    return
  endif

  if col > strlen(line) && col != s:last_col
    let s:last_col = col
    call feedkeys("\<C-x>\<C-o>", 'n')
    return
  endif
endfunction


function! smartfinder#on_bs()
  if strlen(s:remove_prompt(getline('.'))) > 0
    call feedkeys((pumvisible() ? "\<C-e>" : '') . "\<BS>", 'n')
  endif
endfunction


function! smartfinder#map_plugin_keys()
  inoremap <buffer> <Plug>SmartFinderOnBS
        \ <C-r>=smartfinder#on_bs() ? '' : ''<CR>
  inoremap <buffer> <Plug>SmartFinderCancel <Esc>

  call s:do('map_plugin_keys')
endfunction


function! smartfinder#unmap_plugin_keys()
  call s:do('unmap_plugin_keys')
  call smartfinder#safe_iunmap('<Plug>SmartFinderOnBS',
        \                       '<Plug>SmartFinderCancel')
endfunction


function! smartfinder#map_default_keys()
  imap <buffer> <Esc> <Plug>SmartFinderCancel
  imap <buffer> <C-c> <Plug>SmartFinderCancel
  imap <buffer> <BS> <Plug>SmartFinderOnBS
  imap <buffer> <C-h> <Plug>SmartFinderOnBS
  inoremap <buffer> <C-l> <Nop>
endfunction


function! smartfinder#safe_iunmap(...)
  for key in a:000
    execute 'inoremap <buffer> ' . key . ' <Nop>'
    execute 'iunmap <buffer> ' . key
  endfor
endfunction


function! smartfinder#unmap_default_keys()
  call smartfinder#safe_iunmap('<Esc>', '<C-c>', '<BS>', '<C-h>', '<C-l>')
endfunction


function! smartfinder#omnifunc(findstart, base)
  if a:findstart
    return s:do('omnifunc', a:findstart, a:base)
  endif

  let result = s:do('omnifunc', a:findstart, a:base)

  "syntax clear
  if empty(result)
    syntax match Error /^.*$/
  else
    execute printf('syntax match Statement /^\V%s/', escape(s:prompt, '\'))
    call feedkeys("\<C-p>\<Down>", 'n')
  endif
  return result
endfunction


function! s:get_user_input_string(function_name, args)
  if pumvisible()
    let str = printf("\<C-y>\<C-r>=%s(%s) ? '' : ''\<CR>",
	  \ a:function_name, string(a:args))
    call feedkeys(str , 'n')
    return 0
  else
    let s:user_input_string = s:remove_prompt(getline('.'))
    return 1
  endif
endfunction


function! s:get_select_item(str)
  let result = {}
  for item in s:do('get_item_list')
    if item.word ==# a:str
      let result = item
      break
    endif
  endfor

  return result
endfunction


function! smartfinder#action_handler(function_name)
  if !s:get_user_input_string('smartfinder#action_handler', a:function_name)
    return
  endif

  if !exists('s:user_input_string')
    return
  endif

  try
    let item = s:get_select_item(s:user_input_string)

    call call(a:function_name, [item])
  finally
    unlet s:user_input_string
  endtry
endfunction


function! smartfinder#command_complete(arglead, cmdline, cursorpos)
  return join(
        \  sort(
        \    map(
        \      split(
        \        globpath(
        \          &runtimepath,
        \          'autoload/smartfinder/*.vim'
        \        ),
        \        "\n"
        \      ),
        \      'fnamemodify(v:val, ":t:r")'
        \    )
        \  ),
        \  "\n"
        \)
endfunction


" global options
if exists('g:SmartFinderOptions')
  call extend(g:SmartFinderOptions, { 'Global' : {}, 'Mode' : {} }, 'keep')
else
  let g:SmartFinderOptions = { 'Global' : {}, 'Mode' : {} }
endif

let s:DefaultOptions = { 'Global' : {} }
let s:DefaultOptions.Global.bufname = '[smartfinder]'
call map(s:DefaultOptions,
      \ 'extend(g:SmartFinderOptions[v:key], v:val, "keep")')


" vim: expandtab shiftwidth=2 softtabstop=2 foldmethod=marker
