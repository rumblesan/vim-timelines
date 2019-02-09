""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Functions
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

let s:not_prefixable_keywords = [ "import", "data", "instance", "class", "{-#", "type", "case", "do", "let", "default", "foreign", "--"]

" guess correct number of spaces to indent
" (tabs are not allowed)
function! Get_indent_string()
    return repeat(" ", 4)
endfunction

" replace tabs by spaces
function! Tab_to_spaces(text)
    return substitute(a:text, "	", Get_indent_string(), "g")
endfunction

" Check if line is commented out
function! Is_comment(line)
    return (match(a:line, "^[ \t]*--.*") >= 0)
endfunction

" Remove commented out lines
function! Remove_line_comments(lines)
    let l:i = 0
    let l:len = len(a:lines)
    let l:ret = []
    while l:i < l:len
        if !Is_comment(a:lines[l:i])
            call add(l:ret, a:lines[l:i])
        endif
        let l:i += 1
    endwhile
    return l:ret
endfunction

" remove block comments
function! Remove_block_comments(text)
    return substitute(a:text, "{-.*-}", "", "g")
endfunction

" remove line comments
" todo: fix this! it only removes one occurence whilst it should remove all.
" function! Remove_line_comments(text)
"     return substitute(a:text, "^[ \t]*--[^\n]*\n", "", "g")
" endfunction

" Wrap in :{ :} if there's more than one line
function! Wrap_if_multi(lines)
    if len(a:lines) > 1
        return [":{"] + a:lines + [":}"]
    else
        return a:lines
    endif
endfunction

" change string into array of lines
function! Lines(text)
    return split(a:text, "\n")
endfunction

" change lines back into text
function! Unlines(lines)
    return join(a:lines, "\n") . "\n"
endfunction

" vim slime handler
function! _EscapeText_timelines(text)
    let l:text  = Remove_block_comments(a:text)
    let l:lines = Lines(Tab_to_spaces(l:text))
    let l:lines = Remove_line_comments(l:lines)
    let l:lines = Wrap_if_multi(l:lines)
    return Unlines(l:lines)
endfunction

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Mappings
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

if !exists("g:timelines_no_mappings") || !g:timelines_no_mappings
  if !hasmapto('<Plug>TimeLinesConfig', 'n')
    nmap <buffer> <localleader>c <Plug>TimeLinesConfig
  endif

  if !hasmapto('<Plug>TimeLinesRegionSend', 'x')
    xmap <buffer> <localleader>s  <Plug>TimeLinesRegionSend
    xmap <buffer> <c-e> <Plug>TimeLinesRegionSend
  endif

  if !hasmapto('<Plug>TimeLinesLineSend', 'n')
    nmap <buffer> <localleader>s  <Plug>TimeLinesLineSend
  endif

  if !hasmapto('<Plug>TimeLinesParagraphSend', 'n')
    nmap <buffer> <localleader>ss <Plug>TimeLinesParagraphSend
    nmap <buffer> <c-e> <Plug>TimeLinesParagraphSend
  endif

  imap <buffer> <c-e> <Esc><Plug>TimeLinesParagraphSend<Esc>i<Right>

endif
