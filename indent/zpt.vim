" Language:	ZPT
" Maintainer:	Dirley Rodrigues <dirleyrls@gmail.com>
" Last Change:	2013 Jun 28
" Notes:	1) Based on the indent/xml.vim script by Johannes Zellner
"               2) does not indent pure non-xml code (e.g. embedded scripts)
"		3) will be confused by unbalanced tags in comments
"		or CDATA sections.
"		2009-05-26 patch by Nikolai Weibull
" TODO: 	implement pre-like tags, see zpt_indent_open / zpt_indent_close

" Only load this indent file when no other was loaded.
if exists("b:did_indent")
    finish
endif
let b:did_indent = 1
let s:keepcpo= &cpo
set cpo&vim

" [-- local settings (must come before aborting the script) --]
setlocal indentexpr=ZptIndentGet(v:lnum,1)
setlocal indentkeys=o,O,*<Return>,<>>,<<>,/,{,}

if !exists('b:zpt_indent_open')
    let b:zpt_indent_open = '.\{-}<\a'
    " pre tag, e.g. <address>
    " let b:zpt_indent_open = '.\{-}<[/]\@!\(address\)\@!'
endif

if !exists('b:zpt_indent_close')
    let b:zpt_indent_close = '.\{-}</'
    " end pre tag, e.g. </address>
    " let b:zpt_indent_close = '.\{-}</\(address\)\@!'
endif

" [-- finish, if the function already exists --]
if exists('*ZptIndentGet') | finish | endif

fun! <SID>ZptIndentWithPattern(line, pat)
    let s = substitute('x'.a:line, a:pat, "\1", 'g')
    return strlen(substitute(s, "[^\1].*$", '', ''))
endfun

" [-- check if it's xml --]
fun! <SID>ZptIndentSynCheck(lnum)
    if '' != &syntax
	let syn1 = synIDattr(synID(a:lnum, 1, 1), 'name')
	let syn2 = synIDattr(synID(a:lnum, strlen(getline(a:lnum)) - 1, 1), 'name')
	if '' != syn1 && syn1 !~ 'xml' && '' != syn2 && syn2 !~ 'xml'
	    " don't indent pure non-xml code
	    return 0
	elseif syn1 =~ '^xmlComment' && syn2 =~ '^xmlComment'
	    " indent comments specially
	    return -1
	endif
    endif
    return 1
endfun

" [-- return the sum of indents of a:lnum --]
fun! <SID>ZptIndentSum(lnum, style, add)
    let line = getline(a:lnum)
    if a:style == match(line, '^\s*</')
	return (&sw *
	\  (<SID>ZptIndentWithPattern(line, b:zpt_indent_open)
	\ - <SID>ZptIndentWithPattern(line, b:zpt_indent_close)
	\ - <SID>ZptIndentWithPattern(line, '.\{-}/>'))) + a:add
    else
	return a:add
    endif
endfun

" [-- return a list [lnum, colnum] of the nearest xmlString start --]
fun! <SID>GetLastZptStringStart(lnum)
    let pattern = ('["' . "']")
    let slnum = prevnonblank(a:lnum - 1)

    while slnum > 0
        let line = getline(slnum)

        " search the last quote char in the line
        let i = 0
        let m = match(line, pattern, i)
        let pos = -1
        while m >= 0
            let pos = m
            let i = i + 1
            let m = match(line, pattern, i)
        endwhile

        " go backwards, searching for the start of the last
        " xmlString in the given line
        while pos >= 0
            let syn1 = synIDattr(synID(slnum, pos, 1), 'name')
            if syn1 !~ '^xmlString'
                return [slnum, pos]
                break
            endif
            let i = i - 1
            let pos = match(line, pattern, i)
        endwhile

        let slnum = prevnonblank(slnum - 1)
    endwhile
endfun

fun! ZptIndentGet(lnum, use_syntax_check)
    " Find a non-empty line above the current line.
    let lnum = prevnonblank(a:lnum - 1)

    " Hit the start of the file, use zero indent.
    if lnum == 0
	return 0
    endif

    if a:use_syntax_check
	let check_lnum = <SID>ZptIndentSynCheck(lnum)
	let check_alnum = <SID>ZptIndentSynCheck(a:lnum)
	if 0 == check_lnum || 0 == check_alnum
	    return indent(a:lnum)
	elseif -1 == check_lnum || -1 == check_alnum
	    return -1
	endif
    endif

    " special indentation for xml attribute contents (xmlString)
    " TODO maybe we should only use this for tal: and metal: tags, is there a way to do that?
    let syn1 = synIDattr(synID(a:lnum, 1, 1), 'name')
    let syn2 = synIDattr(synID(lnum, strlen(getline(lnum)) - 1, 1), 'name')
    if syn1 =~ '^xmlString' || (syn1 == '' && syn2 =~ '^xmlString')
        let [l, c] = <SID>GetLastZptStringStart(a:lnum)
        return c + 1
    endif

    " avoid using xmlString blocks as basis for indentation of other
    " syntax regions
    let syn2 = synIDattr(synID(lnum, 1, 1), 'name')
    while syn2 =~ '^xmlString'
        let lnum = prevnonblank(lnum - 1)
        let syn2 = synIDattr(synID(lnum, 1, 1), 'name')
    endwhile

    let ind = <SID>ZptIndentSum(lnum, -1, indent(lnum))
    let ind = <SID>ZptIndentSum(a:lnum, 0, ind)

    return ind
endfun

let &cpo = s:keepcpo
unlet s:keepcpo

" vim:ts=8
