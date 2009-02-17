"-----------------------------------------------------------------------------
" smartfinder
" Author: ky
" Version: 0.2
" License: The MIT License
" The MIT License {{{
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

if &compatible || v:version < 700
  finish
endif

if (exists('g:loaded_smartfinder') && g:loaded_smartfinder)
  finish
endif

let s:cpoptions = &cpoptions
set cpoptions&vim

let g:loaded_smartfinder = 1


" commands
command! -nargs=+ -complete=custom,smartfinder#command_complete SmartFinder
      \ call smartfinder#start(<f-args>)


let &cpoptions = s:cpoptions
unlet s:cpoptions


" vim: expandtab shiftwidth=2 softtabstop=2 foldmethod=marker
