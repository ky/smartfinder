"-----------------------------------------------------------------------------
" smartfinder
" Author: ky
" Version: 0.2
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

function! smartfinder#start(mode, ...)
  let s:options.mode_name = a:mode

  call s:initialize()
  call s:invoke_args('initialize', a:000)

  call s:initialize_mode_options()
  call s:initialize_prompt()

  if bufexists(s:options.bufnr)
    leftabove 1split
    let s:options.new_window = 1
    silent execute s:options.bufnr . 'buffer'
  else
    leftabove 1new
    let s:options.new_window = 1
    call s:initialize_buffer()
  endif

  call s:map_keys()

  silent %delete _
  call setline('.', s:options.prompt)
  call feedkeys('A', 'n')
endfunction


function! smartfinder#end()
  if s:options.activate_flag
    call s:terminate()
  endif
endfunction


function! s:invoke(function_name, ...)
  return call(
        \ printf('smartfinder#%s#%s', s:options.mode_name, a:function_name),
        \ a:000
        \)
endfunction


function! s:invoke_args(function_name, args)
  return call(
        \ printf('smartfinder#%s#%s', s:options.mode_name, a:function_name),
        \ a:args
        \)
endfunction


function! s:initialize()
  let s:options.activate_flag = 1
  let s:options.last_col = -1
  let s:options.add_input_history = 1
  let s:options.show_input_history_pos = -1
  let s:options.winnr = winnr()
  let s:options.new_window = 0
  let s:options.completeopt = &completeopt
  let s:options.ignorecase = &ignorecase
  let s:options.smartcase = &smartcase

  set completeopt=menuone
  set ignorecase
  set nosmartcase
endfunction


function! s:terminate()
  call s:normalize_history()
  call s:unmap_keys()
  call s:invoke('terminate')

  let s:options.activate_flag = 0
  let &completeopt = s:options.completeopt
  let &ignorecase = s:options.ignorecase
  let &smartcase = s:options.smartcase

  if s:options.new_window
    let s:options.new_window = 0
    close
  endif
  execute s:options.winnr . 'wincmd w'
  redraw
endfunction


function! s:initialize_buffer()
  setlocal bufhidden=hide
  setlocal nobuflisted
  setlocal buftype=nofile
  setlocal noswapfile
  setlocal omnifunc=smartfinder#omnifunc
  setlocal filetype=smartfinder

  " :help `=
  file `=s:global_option('bufname')`
  let s:options.bufnr = bufnr('%')

  augroup SmartFinderAugroup
    autocmd!
    autocmd InsertLeave <buffer> nested call smartfinder#end()
    autocmd WinLeave <buffer> call smartfinder#end()
    autocmd BufLeave <buffer> call smartfinder#end()
    autocmd CursorMovedI <buffer> call s:on_cursor_moved_i()

    "autocmd CursorHold * call s:save_history()
    "autocmd CursorHoldI * call s:save_history()
    autocmd VimLeave * call s:save_history()
  augroup END
endfunction


function! s:initialize_mode_options()
  if !has_key(s:options.loaded_mode_options, s:options.mode_name)
    if !has_key(g:smartfinder_options.mode, s:options.mode_name)
      let g:smartfinder_options.mode[s:options.mode_name] = {}
    endif
    call extend(g:smartfinder_options.mode[s:options.mode_name],
          \     s:invoke('options'), 'keep')
    let s:options.loaded_mode_options[s:options.mode_name] = 1
  endif
endfunction


function! s:initialize_prompt()
  let s:options.prompt = s:mode_option('prompt')
  let s:options.prompt_len = len(s:options.prompt)
endfunction


function! smartfinder#error_message(msg)
  echohl ErrorMsg
  echomsg a:msg
  echohl None
  sleep
endfunction


function! s:global_option(key)
  return g:smartfinder_options.global[a:key]
endfunction


function! s:mode_option(key)
  let mode_option = g:smartfinder_options.mode[s:options.mode_name]
  return mode_option[a:key]
endfunction


function! s:empty_mode_option(key)
  return !has_key(g:smartfinder_options.mode[s:options.mode_name], a:key) ||
        \ empty(s:mode_option(a:key))
endfunction


function! s:exists_prompt(line)
  return len(a:line) >= s:options.prompt_len &&
        \ a:line[: s:options.prompt_len - 1] ==# s:options.prompt
endfunction


function! s:remove_prompt(line)
  return s:exists_prompt(a:line) ? a:line[s:options.prompt_len :] : a:line
endfunction


function! s:restore_prompt(line)
  let len = len(a:line)
  let i = 0
  while i < s:options.prompt_len &&
        \ i < len &&
        \ s:options.prompt[i] ==# a:line[i]
    let i += 1
  endwhile
  call setline('.', s:options.prompt . a:line[i :])
  call feedkeys(repeat("\<Right>", s:options.prompt_len - i), 'n')
endfunction


function! s:on_cursor_moved_i()
  let line = getline('.')
  let col = col('.')

  if !s:exists_prompt(line)
    call s:restore_prompt(line)
    return
  endif

  call s:add_history(s:remove_prompt(line))

  if col <= s:options.prompt_len
    call feedkeys(repeat("\<Right>", s:options.prompt_len - col + 1), 'n')
    return
  endif

  if col > len(line) && col != s:options.last_col
    let s:options.last_col = col
    call feedkeys("\<C-x>\<C-o>", 'n')
    return
  endif
endfunction


function! s:history_file_name()
  return expand(s:global_option('history_file'))
endfunction


function! s:normalize_history()
  if !s:empty_history()
    let history_list = s:options.user_input_history[s:options.mode_name]
    if empty(history_list[0])
      call remove(history_list, 0)
    endif
    let max_mode_history = s:global_option('max_mode_history')
    if len(history_list) > max_mode_history
      call remove(history_list, max_mode_history, -1)
    endif
  endif
endfunction


function! s:add_history(input_string)
  if s:empty_history()
    let s:options.user_input_history[s:options.mode_name] = []
  endif
  let history_list = s:options.user_input_history[s:options.mode_name]
  if s:options.show_input_history_pos < 0 ||
        \ history_list[s:options.show_input_history_pos] != a:input_string
    if s:options.add_input_history
      call insert(history_list, a:input_string, 0)
      let s:options.add_input_history = 0
    else
      let history_list[0] = a:input_string
    endif
  endif
endfunction


function! s:load_history()
  let result = {}
  let filename = s:history_file_name()

  try
    if filereadable(filename)
      for line in readfile(filename, '')
        let columns = split(line, '\t')

        if !has_key(result, columns[0])
          let result[columns[0]] = []
        endif

        call add(result[columns[0]], columns[1]) 
      endfor
    endif
  catch /.*/
    let result = {}
  endtry

  return result
endfunction


function! s:save_history()
  let filename = s:history_file_name()

  try
    let lines = []
    for mode_name in
          \ sort(keys(s:options.user_input_history),
          \      'smartfinder#compare_string')
      for hist in s:options.user_input_history[mode_name]
        call add(lines, mode_name . "\t" . hist)
      endfor
    endfor

    call writefile(lines, filename)
  catch /.*/
  endtry
endfunction


function! s:empty_history()
  return !has_key(s:options.user_input_history, s:options.mode_name) ||
        \ empty(s:options.user_input_history[s:options.mode_name])
endfunction


function! smartfinder#switch_mode(mode_name, pattern)
  call s:unmap_keys()
  call s:invoke('terminate')

  if s:options.mode_name !=# a:mode_name
    call s:normalize_history()
    let s:options.mode_name = a:mode_name
    let s:options.add_input_history = 1
    let s:options.show_input_history_pos = -1
  endif
  let s:options.last_col = -1

  call s:invoke('initialize')
  call s:initialize_mode_options()
  call s:initialize_prompt()
  call s:map_keys()
  call setline('.', s:options.prompt . a:pattern)

  call feedkeys("\<End>\<C-x>\<C-o>", 'n')
endfunction


function! smartfinder#compare_string(lhs, rhs)
  let lhsl = char2nr(tolower(a:lhs))
  let rhsl = char2nr(tolower(a:rhs))
  return lhsl != rhsl ? (lhsl > rhsl ? 1 : -1)
        \         : (char2nr(a:lhs) > char2nr(a:rhs) ? -1 : 1)
endfunction


function! smartfinder#previous_history()
  if s:empty_history() ||
        \ s:options.show_input_history_pos >=
        \   len(s:options.user_input_history[s:options.mode_name]) - 1
    return
  endif
  let history_list = s:options.user_input_history[s:options.mode_name]
  let s:options.show_input_history_pos +=
        \ (s:options.show_input_history_pos < 0 && len(history_list) > 1)
        \ ? 2 : 1
  call smartfinder#switch_mode(
        \ s:options.mode_name,
        \ history_list[s:options.show_input_history_pos])
endfunction


function! smartfinder#next_history()
  if s:empty_history() || s:options.show_input_history_pos < 0
    return
  endif
  let s:options.show_input_history_pos -= 1
  if s:options.show_input_history_pos >= 0
    let history_list = s:options.user_input_history[s:options.mode_name]
    call smartfinder#switch_mode(
          \ s:options.mode_name,
          \ history_list[s:options.show_input_history_pos])
  endif
endfunction


function! smartfinder#on_bs()
  if !empty(s:remove_prompt(getline('.')))
    call feedkeys((pumvisible() ? "\<C-e>" : '') . "\<BS>", 'n')
  endif
endfunction


function! smartfinder#select_action(item)
  if empty(a:item)
    call smartfinder#error_message('no input text')
    return
  endif

  if s:empty_mode_option('action_key_table') ||
        \ s:empty_mode_option('action_name_table')
    return
  endif

  let action_key_table = s:mode_option('action_key_table')
  let keys = sort(copy(keys(action_key_table)), 'smartfinder#compare_string')
  let action_count = len(keys)
  let key_names = map(copy(keys), 'strtrans(v:val)')
  let max_key_width = max(map(copy(key_names), 'len(v:val)'))
  let action_names = map(copy(keys), 'action_key_table[v:val]')
  let max_action_width = max(map(copy(action_names), 'len(v:val)'))
  let spacer_len = 2
  let spacer = repeat(' ', spacer_len)
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

      echon repeat(' ', max_key_width - len(keys[i]))
      echohl SpecialKey
      echon keys[i]
      echohl None
      echon ' ' . action_names[i]
      echon spacer . repeat(' ', max_action_width - len(action_names[i]))

      let i += 1
    endfor
    echon "\n"
  endfor

  echon 'select an action: '
  let key = nr2char(getchar())
  redraw

  if key == "\<Esc>" || key == "\<C-c>"
    return
  endif

  if has_key(action_key_table, key)
    let action_name_table = s:mode_option('action_name_table')
    let function_name = action_name_table[action_key_table[key]]
    call smartfinder#end()
    call feedkeys("\<Esc>", 'n')
    call feedkeys(call(function_name, [a:item]), 'n')
  else
    call smartfinder#error_message('no action')
    return
  endif
endfunction


function! s:map_keys()
  call smartfinder#map_plugin_keys()
  call s:invoke('map_plugin_keys')

  let function_name = s:global_option('key_mappings')
  if !empty(function_name)
    call call(function_name, [])
  else
    call s:map_global_keys()
  endif

  if !s:empty_mode_option('key_mappings')
    call call(s:mode_option('key_mappings'), [])
  else
    call s:invoke('map_mode_keys')
  endif
endfunction


function! s:unmap_keys()
  if !s:empty_mode_option('key_unmappings')
    call call(s:mode_option('key_unmappings'), [])
  else
    call s:invoke('unmap_mode_keys')
  endif

  let function_name = s:global_option('key_unmappings')
  if !empty(function_name)
    call call(function_name, [])
  else
    call s:unmap_global_keys()
  endif

  call s:invoke('unmap_plugin_keys')
  call smartfinder#unmap_plugin_keys()
endfunction


function! smartfinder#safe_iunmap(key)
  execute 'inoremap <buffer> ' . a:key . ' <Nop>'
  execute 'iunmap <buffer> ' . a:key
endfunction


function! smartfinder#map_plugin_keys()
  inoremap <buffer> <Plug>SmartFinderDeleteChar
        \ <C-r>=smartfinder#on_bs() ? '' : ''<CR>
  inoremap <buffer> <Plug>SmartFinderPreviousHistory
        \ <C-r>=smartfinder#previous_history() ? '' : ''<CR>
  inoremap <buffer> <Plug>SmartFinderNextHistory
        \ <C-r>=smartfinder#next_history() ? '' : ''<CR>
  inoremap <buffer> <Plug>SmartFinderSelectAction
        \ <C-r>=smartfinder#select_completion('smartfinder#select_action')
        \ ? '' : ''<CR>
  inoremap <buffer> <Plug>SmartFinderCancel <Esc>
endfunction


function! smartfinder#unmap_plugin_keys()
  for key in [
        \ '<Plug>SmartFinderDeleteChar',
        \ '<Plug>SmartFinderPreviousHistory',
        \ '<Plug>SmartFinderNextHistory',
        \ '<Plug>SmartFinderSelectAction',
        \ '<Plug>SmartFinderCancel',
        \]
    call smartfinder#safe_iunmap(key)
  endfor
endfunction


function! s:map_global_keys()
  imap <buffer> <BS> <Plug>SmartFinderDeleteChar
  imap <buffer> <C-c> <Plug>SmartFinderCancel
  imap <buffer> <C-h> <Plug>SmartFinderDeleteChar
  imap <buffer> <C-j> <Plug>SmartFinderNextHistory
  imap <buffer> <C-k> <Plug>SmartFinderPreviousHistory
  imap <buffer> <C-l> <Plug>SmartFinderSelectAction
endfunction


function! s:unmap_global_keys()
  for key in [
        \ '<BS>', '<C-c>', '<C-h>', '<C-i>',
        \ '<C-j>', '<C-k>', '<C-l>', '<Tab>',
        \]
    call smartfinder#safe_iunmap(key)
  endfor
endfunction


function! smartfinder#omnifunc(findstart, base)
  if a:findstart
    return s:invoke('omnifunc', a:findstart, a:base)
  endif

  let result = s:invoke('omnifunc', a:findstart, a:base)

  syntax clear
  if empty(result)
    syntax match Error /^.*$/
  else
    execute printf('syntax match Statement /^\V%s/',
          \        escape(s:options.prompt, '\'))
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


function! s:get_selected_completion_item(str)
  let result = {}
  for item in s:invoke('completion_list')
    if item.word ==# a:str
      let result = item
      break
    endif
  endfor

  return result
endfunction


function! smartfinder#select_completion(function_name)
  if !s:get_user_input_string('smartfinder#select_completion',
        \                     a:function_name)
    return
  endif

  if !exists('s:user_input_string')
    return
  endif

  try
    let item = s:get_selected_completion_item(s:user_input_string)

    call call(a:function_name, [item])
  finally
    unlet s:user_input_string
  endtry
endfunction


function! smartfinder#fnameescape(fname)
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


function! smartfinder#make_pattern(str)
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


function! s:mode_list()
  return sort(
        \  map(
        \    split(
        \      globpath(
        \        &runtimepath,
        \        'autoload/smartfinder/*.vim'
        \      ),
        \      "\n"
        \    ),
        \    'fnamemodify(v:val, ":t:r")'
        \  ),
        \  'smartfinder#compare_string'
        \)
endfunction


function! s:parse_cmdline(cmdline, cursorpos)
  let arglist = []
  let pos = -1
  let arg = ''
  let i = 0
  let bslash = 0

  for s in split(a:cmdline, '\zs')
    if i == a:cursorpos
      let pos = empty(arglist) ? 0 : len(arglist) - 1
    else
      let i += 1
    endif
    if s == '\'
      if bslash
        let arg .= '\'
        let bslash = 0
      else
        let bslash = 1
      endif
    elseif s =~ '\s'
      if bslash
        let arg .= s
        let bslash = 0
      elseif !empty(arg)
        call add(arglist, arg)
        let arg = ''
      endif
    else
      if bslash
        let arg .= '\'
        let bslash = 0
      endif
      let arg .= s
    endif
  endfor
  call add(arglist, arg)

  return {
        \ 'pos' : (pos >= 0 ? pos : len(arglist) - 1),
        \ 'cmdline' : arglist,
        \}
endfunction


function! smartfinder#command_complete(arglead, cmdline, cursorpos)
  let cmdline = s:parse_cmdline(a:cmdline, a:cursorpos)
  if cmdline.pos == 1
    return join(s:mode_list(), "\n")
  else
    return ''
  endif
endfunction


function! smartfinder#get_option(key)
  return s:global_option(a:key)
endfunction


function! smartfinder#get_mode_option(mode, key)
  let options = g:smartfinder_options.mode[a:mode]
  return options[a:key]
endfunction


function! smartfinder#set_global_option(key, value)
  let g:smartfinder.global[a:key] = a:value
endfunction


function! smartfinder#set_mode_option(mode, key, value)
  if !has_key(g:smartfinder_options.mode, a:mode)
    let g:smartfinder_options.mode[a:mode] = {}
  endif

  let options = g:smartfinder_options.mode[a:mode]
  let options[a:key] = a:value
endfunction


" global options
if exists('g:smartfinder_options')
  call extend(g:smartfinder_options, { 'global' : {}, 'mode' : {} }, 'keep')
else
  let g:smartfinder_options = { 'global' : {}, 'mode' : {} }
endif
let s:default_options = {
      \ 'global' : {
      \   'bufname'         : '[smartfinder]',
      \   'history_file'    : '$HOME/.smartfinder_history',
      \   'key_mappings'    : '',
      \   'key_unmappings'  : '',
      \   'max_mode_history': 20,
      \ }
      \}
call map(s:default_options,
      \ 'extend(g:smartfinder_options[v:key], v:val, "keep")')
unlet s:default_options


" local options
if has('win16') || has('win32') || has('win64')
  let s:REGEX_SEPARATOR_PATTERN = [ '/', '\\[\\/]' ]
else
  let s:REGEX_SEPARATOR_PATTERN = []
endif
if !exists('s:options')
  let s:options = {}
  let s:options.prompt = ''
  let s:options.prompt_len = -1
  let s:options.completeopt = ''
  let s:options.ignorecase = ''
  let s:options.smartcase = ''
  let s:options.bufnr = -1
  let s:options.winnr = -1
  let s:options.new_window = 0
  let s:options.last_col = -1
  let s:options.activate_flag = 0
  let s:options.mode_name = ''
  let s:options.loaded_mode_options = {}
  let s:options.user_input_history = s:load_history()
  let s:options.add_input_history = -1
  let s:options.show_input_history_pos = -1
endif




" vim: expandtab shiftwidth=2 softtabstop=2 foldmethod=marker
