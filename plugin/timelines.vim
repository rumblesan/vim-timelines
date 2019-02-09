if exists("g:loaded_timelines") || &cp || v:version < 700
  finish
endif
let g:loaded_timelines = 1

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Tmux
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

function! s:TmuxSend(config, text)
  let l:prefix = "tmux -L " . shellescape(a:config["socket_name"])
  " use STDIN unless configured to use a file
  if !exists("g:timelines_paste_file")
    call system(l:prefix . " load-buffer -", a:text)
  else
    call s:WritePasteFile(a:text)
    call system(l:prefix . " load-buffer " . g:timelines_paste_file)
  end
  call system(l:prefix . " paste-buffer -d -t " . shellescape(a:config["target_pane"]))
endfunction

function! s:TmuxPaneNames(A,L,P)
  let format = '#{pane_id} #{session_name}:#{window_index}.#{pane_index} #{window_name}#{?window_active, (active),}'
  return system("tmux -L " . shellescape(b:timelines_config['socket_name']) . " list-panes -a -F " . shellescape(format))
endfunction

function! s:TmuxConfig() abort
  if !exists("b:timelines_config")
    let b:timelines_config = {"socket_name": "default", "target_pane": ":"}
  end

  let b:timelines_config["socket_name"] = input("tmux socket name: ", b:timelines_config["socket_name"])
  let b:timelines_config["target_pane"] = input("tmux target pane: ", b:timelines_config["target_pane"], "custom,<SNR>" . s:SID() . "_TmuxPaneNames")
  if b:timelines_config["target_pane"] =~ '\s\+'
    let b:timelines_config["target_pane"] = split(b:timelines_config["target_pane"])[0]
  endif
endfunction

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Helpers
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

function! s:SID()
  return matchstr(expand('<sfile>'), '<SNR>\zs\d\+\ze_SID$')
endfun

function! s:WritePasteFile(text)
  " could check exists("*writefile")
  call system("cat > " . g:timelines_paste_file, a:text)
endfunction

function! s:_EscapeText(text)
  if exists("&filetype")
    let custom_escape = "_EscapeText_" . substitute(&filetype, "[.]", "_", "g")
    if exists("*" . custom_escape)
      let result = call(custom_escape, [a:text])
    end
  end

  " use a:text if the ftplugin didn't kick in
  if !exists("result")
    let result = a:text
  end

  " return an array, regardless
  if type(result) == type("")
    return [result]
  else
    return result
  end
endfunction

function! s:TimeLinesGetConfig()
  if !exists("b:timelines_config")
    if exists("g:timelines_default_config")
      let b:timelines_config = g:timelines_default_config
    else
      call s:TimeLinesDispatch('Config')
    end
  end
endfunction

function! s:TimeLinesFlashVisualSelection()
  " Redraw to show current visual selection, and sleep
  redraw
  execute "sleep " . g:timelines_flash_duration . " m"
  " Then leave visual mode
  silent exe "normal! vv"
endfunction

function! s:TimeLinesSendOp(type, ...) abort
  call s:TimeLinesGetConfig()

  let sel_save = &selection
  let &selection = "inclusive"
  let rv = getreg('"')
  let rt = getregtype('"')

  if a:0  " Invoked from Visual mode, use '< and '> marks.
    silent exe "normal! `<" . a:type . '`>y'
  elseif a:type == 'line'
    silent exe "normal! '[V']y"
  elseif a:type == 'block'
    silent exe "normal! `[\<C-V>`]\y"
  else
    silent exe "normal! `[v`]y"
  endif

  call setreg('"', @", 'V')
  call s:TimeLinesSend(@")

  " Flash selection
  if a:type == 'line'
    silent exe "normal! '[V']"
    call s:TimeLinesFlashVisualSelection()
  endif

  let &selection = sel_save
  call setreg('"', rv, rt)

  call s:TimeLinesRestoreCurPos()
endfunction

function! s:TimeLinesSendRange() range abort
  call s:TimeLinesGetConfig()

  let rv = getreg('"')
  let rt = getregtype('"')
  silent execute a:firstline . ',' . a:lastline . 'yank'
  call s:TimeLinesSend(@")
  call setreg('"', rv, rt)
endfunction

function! s:TimeLinesSendLines(count) abort
  call s:TimeLinesGetConfig()

  let rv = getreg('"')
  let rt = getregtype('"')

  silent execute "normal! " . a:count . "yy"

  call s:TimeLinesSend(@")
  call setreg('"', rv, rt)

  " Flash lines
  silent execute "normal! V"
  if a:count > 1
    silent execute "normal! " . (a:count - 1) . "\<Down>"
  endif
  call s:TimeLinesFlashVisualSelection()
endfunction

function! s:TimeLinesStoreCurPos()
  if g:timelines_preserve_curpos == 1
    if exists("*getcurpos")
      let s:cur = getcurpos()
    else
      let s:cur = getpos('.')
    endif
  endif
endfunction

function! s:TimeLinesRestoreCurPos()
  if g:timelines_preserve_curpos == 1
    call setpos('.', s:cur)
  endif
endfunction

let s:parent_path = fnamemodify(expand("<sfile>"), ":p:h:s?/plugin??")

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Public interface
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

function! s:TimeLinesSend(text)
  call s:TimeLinesGetConfig()

  let pieces = s:_EscapeText(a:text)
  for piece in pieces
    call s:TimeLinesDispatch('Send', b:timelines_config, piece)
  endfor
endfunction

function! s:TimeLinesConfig() abort
  call inputsave()
  call s:TimeLinesDispatch('Config')
  call inputrestore()
endfunction

" delegation
function! s:TimeLinesDispatch(name, ...)
  let target = substitute(tolower(g:timelines_target), '\(.\)', '\u\1', '') " Capitalize
  return call("s:" . target . a:name, a:000)
endfunction

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Setup key bindings
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

command -bar -nargs=0 TimeLinesConfig call s:TimeLinesConfig()
command -range -bar -nargs=0 TimeLinesSend <line1>,<line2>call s:TimeLinesSendRange()
command -nargs=+ TimeLinesSend1 call s:TimeLinesSend(<q-args> . "\r")

noremap <SID>Operator :<c-u>call <SID>TimeLinesStoreCurPos()<cr>:set opfunc=<SID>TimeLinesSendOp<cr>g@

noremap <unique> <script> <silent> <Plug>TimeLinesRegionSend :<c-u>call <SID>TimeLinesSendOp(visualmode(), 1)<cr>
noremap <unique> <script> <silent> <Plug>TimeLinesLineSend :<c-u>call <SID>TimeLinesSendLines(v:count1)<cr>
noremap <unique> <script> <silent> <Plug>TimeLinesMotionSend <SID>Operator
noremap <unique> <script> <silent> <Plug>TimeLinesParagraphSend <SID>Operatorip
noremap <unique> <script> <silent> <Plug>TimeLinesConfig :<c-u>TimeLinesConfig<cr>

""
" Default options
"
if !exists("g:timelines_target")
  let g:timelines_target = "tmux"
endif

if !exists("g:timelines_paste_file")
  let g:timelines_paste_file = tempname()
endif

if !exists("g:timelines_default_config")
  let g:timelines_default_config = { "socket_name": "default", "target_pane": ":0.1" }
endif

if !exists("g:timelines_preserve_curpos")
  let g:timelines_preserve_curpos = 1
end

if !exists("g:timelines_flash_duration")
  let g:timelines_flash_duration = 150
end

if filereadable(s:parent_path . "/.dirt-samples")
  let &l:dictionary .= ',' . s:parent_path . "/.dirt-samples"
endif
