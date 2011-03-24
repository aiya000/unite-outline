"=============================================================================
" File    : autoload/unite/source/outline/_cache.vim
" Author  : h1mesuke <himesuke@gmail.com>
" Updated : 2011-03-24
" Version : 0.3.2
" License : MIT license {{{
"
"   Permission is hereby granted, free of charge, to any person obtaining
"   a copy of this software and associated documentation files (the
"   "Software"), to deal in the Software without restriction, including
"   without limitation the rights to use, copy, modify, merge, publish,
"   distribute, sublicense, and/or sell copies of the Software, and to
"   permit persons to whom the Software is furnished to do so, subject to
"   the following conditions:
"   
"   The above copyright notice and this permission notice shall be included
"   in all copies or substantial portions of the Software.
"   
"   THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
"   OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
"   MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
"   IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
"   CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
"   TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
"   SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
" }}}
"=============================================================================

function! unite#sources#outline#modules#cache#module()
  return s:Cache
endfunction

function! s:Cache_has(path) dict
  return (has_key(self.data, a:path) || s:exists_cache_file(a:path))
endfunction

function! s:exists_cache_file(path)
  return (s:check_cache_dir() && filereadable(s:cache_file_path(a:path)))
endfunction

function! s:check_cache_dir()
  if isdirectory(s:Cache.dir)
    return 1
  else
    try
      call mkdir(s:Cache.dir, 'p')
    catch
      call unite#util#print_error("unite-outline: Couldn't create the cache directory.")
    endtry
    return isdirectory(s:Cache.dir)
  endif
endfunction

function! s:cache_file_path(path)
    return s:Cache.dir . '/' . s:encode_file_path(a:path)
endfunction

" Original source from Shougo' neocomplcache
" https://github.com/Shougo/neocomplcache
"
function! s:encode_file_path(path)
  if len(s:Cache.dir) + len(a:path) < 150
    " encode the path to a base name
    return substitute(substitute(a:path, ':', '=-', 'g'), '[/\\]', '=+', 'g')
  else
    " simple hash
    let sum = 0
    for idx in range(len(a:path))
      let sum += char2nr(a:path[idx]) * (idx + 1)
    endfor
    return printf('%X', sum)
  endif
endfunction

function! s:Cache_get(path) dict
  if !has_key(self.data, a:path) && s:exists_cache_file(a:path)
    let self.data[a:path] = s:load_cache_file(a:path)
  endif
  let item = self.data[a:path]
  let item.touched = localtime()
  return item.candidates
endfunction

function! s:load_cache_file(path)
  try
    let cache_file = s:cache_file_path(a:path)
    let dumped_data = readfile(cache_file)[0]
    call unite#sources#outline#util#print_debug("[LOADED] cache file: " . cache_file)
    " update the timestamp of the file
    call writefile([dumped_data], cache_file)
    call unite#sources#outline#util#print_debug("[TOUCHED] cache file: " . cache_file)
    sandbox let data = eval(dumped_data)
    return data
  catch
    call unite#util#print_error("unite-outline: Couldn't load the cache file: " . cache_file)
    return []
  endtry
endfunction

function! s:Cache_set(path, cands, should_serialize) dict
  let self.data[a:path] = {
        \ 'candidates': a:cands,
        \ 'touched'   : localtime(),
        \ }
  let cache_items = items(self.data)
  let num_deletes = len(cache_items) - g:unite_source_outline_cache_buffers
  if num_deletes > 0
    call map(cache_items, '[v:key, v:val.timestamp]')
    call sort(cache_items, 's:compare_timestamp')
    let delete_keys = map(cache_items[0 : num_deletes - 1], 'v:val[0]')
    for path in delete_keys
      unlet self.data[path]
    endfor
  endif
  if a:should_serialize && s:check_cache_dir()
    call s:save_cache_file(a:path, self.data[a:path])
  elseif s:exists_cache_file(a:path)
    call s:remove_file(s:cache_file_path(a:path))
  endif
endfunction

function! s:save_cache_file(path, data)
  try
    let cache_file = s:cache_file_path(a:path)
    let dumped_data = string(a:data)
    call writefile([dumped_data], cache_file)
    call unite#sources#outline#util#print_debug("[SAVED] cache file: " . cache_file)
  catch
    call unite#util#print_error("unite-outline: Couldn't save the cache to: " . cache_file)
    return
  endtry
  call s:cleanup_old_cache_files()
endfunction

function! s:Cache_remove(path) dict
  call remove(self.data, a:path)
  if s:exists_cache_file(a:path)
    call s:remove_file(s:cache_file_path(a:path))
  endif
endfunction

function! s:remove_file(path)
  try
    call delete(a:path)
    call unite#sources#outline#util#print_debug("[DELETED] cache file: " . a:path)
  catch
    call unite#util#print_error("unite-outline: Couldn't delete the cache file: " . a:path)
  endtry
endfunction

function! s:Cache_clear()
  if s:check_cache_dir()
    call s:cleanup_all_cache_files()
    echomsg "unite-outline: Deleted all cache files."
  else
    call unite#util#print_error("unite-outline: Cache directory doesn't exist.")
  endif
endfunction

function! s:cleanup_old_cache_files()
  let cache_files = split(globpath(s:Cache.dir, '*'), "\<NL>")
  let num_deletes = len(cache_files) - g:unite_source_outline_cache_buffers
  if num_deletes > 0
    call map(cache_files, '[v:val, getftime(v:val)]')
    call sort(cache_files, 's:compare_timestamp')
    let old_files = map(cache_files[0 : num_deletes - 1], 'v:val[0]')
    for path in old_files
      call s:remove_file(path)
    endfor
  endif
endfunction

function! s:cleanup_all_cache_files()
  let cache_files = split(globpath(s:Cache.dir, '*'), "\<NL>")
  for path in cache_files
    call s:remove_file(path)
  endfor
endfunction

function! s:compare_timestamp(pair1, pair2)
  let t1 = a:pair1[1]
  let t2 = a:pair2[1]
  return t1 == t2 ? 0 : t1 > t2 ? 1 : -1
endfunction

"-----------------------------------------------------------------------------

function! s:get_SID()
  return str2nr(matchstr(expand('<sfile>'), '<SNR>\zs\d\+\ze_'))
endfunction

let s:Cache = unite#sources#outline#define_module(s:get_SID(), 'Cache')

let s:Cache.dir  = g:unite_data_directory . '/.outline'
let s:Cache.data = {}

" vim: filetype=vim