" Vimball Archiver by Charles E. Campbell
UseVimball
finish
autoload/ingo/actions.vim	[[[1
129
" ingo/actions.vim: Functions for flexible action execution.
"
" DEPENDENCIES:
"
" Copyright: (C) 2012-2014 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
"
" REVISION	DATE		REMARKS
"   1.020.009	08-Jun-2014	Expose ingo#actions#GetValExpr().
"   1.019.008	15-May-2014	In ingo#actions#EvaluateWithValOrFunc(), remove
"				any occurrence of "v:val" instead of passing an
"				empty list or empty string. This is useful for
"				invoking functions (an expression, not Funcref)
"				with optional arguments.
"   1.015.007	18-Nov-2013	CHG: Pass _all_ additional arguments of
"				ingo#actions#ValueOrFunc(),
"				ingo#actions#NormalOrFunc(),
"				ingo#actions#ExecuteOrFunc(),
"				ingo#actions#EvaluateOrFunc() instead of only
"				the first (interpreted as a List of arguments)
"				when passed a Funcref as a:Action.
"   1.014.006	05-Nov-2013	Add ingo#actions#ValueOrFunc().
"   1.011.005	01-Aug-2013	Add ingo#actions#EvaluateWithValOrFunc().
"   1.010.004	04-Jul-2013	Add ingo#actions#EvaluateWithVal().
"   1.010.003	03-Jul-2013	Move into ingo-library.
"				Allow to specify Funcref arguments.
"	002	17-Jan-2013	Add ingoactions#EvaluateOrFunc(), used by
"				autoload/ErrorFix.vim.
"	001	23-Oct-2012	file creation

function! ingo#actions#ValueOrFunc( Action, ... )
    if type(a:Action) == type(function('tr'))
	return call(a:Action, a:000)
    else
	return a:Action
    endif
endfunction
function! ingo#actions#NormalOrFunc( Action, ... )
    if type(a:Action) == type(function('tr'))
	return call(a:Action, a:000)
    else
	execute 'normal!' a:Action
	return ''
    endif
endfunction
function! ingo#actions#ExecuteOrFunc( Action, ... )
    if type(a:Action) == type(function('tr'))
	return call(a:Action, a:000)
    else
	execute a:Action
	return ''
    endif
endfunction
function! ingo#actions#EvaluateOrFunc( Action, ... )
"******************************************************************************
"* PURPOSE:
"   Evaluate a:Action; a Funcref is passed all arguments, else it is eval()ed.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:Action    Either a Funcref or an expression to be eval()ed.
"   a:arguments Value(s) to be passed to the a:Action Funcref (but not the
"		expression; use ingo#actions#EvaluateWithValOrFunc() for that).
"* RETURN VALUES:
"   Result of evaluating a:Action.
"******************************************************************************
    if type(a:Action) == type(function('tr'))
	return call(a:Action, a:000)
    else
	return eval(a:Action)
    endif
endfunction
function! ingo#actions#EvaluateWithVal( expression, val )
"******************************************************************************
"* PURPOSE:
"   Evaluate a:expression; each occurrence of "v:val" is replaced with a:val,
"   just like in |map()|.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:expression    An expression to be eval()ed.
"   a:val           Value to be used for occurrences of "v:val" inside
"		    a:expression.
"* RETURN VALUES:
"   Result of evaluating a:expression.
"******************************************************************************
    return get(map([a:val], a:expression), 0, '')
endfunction
function! ingo#actions#GetValExpr()
    return '\w\@<!v:val\w\@!'
endfunction
function! ingo#actions#EvaluateWithValOrFunc( Action, ... )
"******************************************************************************
"* PURPOSE:
"   Evaluate a:Action; a Funcref is passed all arguments, else each occurrence
"   of "v:val" is replaced with the single argument / a List of the passed
"   arguments.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:Action    Either a Funcref or an expression to be eval()ed.
"   a:arguments Value(s) to be passed to the a:Action Funcref or used for
"		occurrences of "v:val" inside the a:Action expression.
"* RETURN VALUES:
"   Result of evaluating a:Action.
"******************************************************************************
    if type(a:Action) == type(function('tr'))
	return call(a:Action, a:000)
    elseif a:0 == 0
	" No arguments have been specified. Remove any occurrence of "v:val"
	" instead of passing an empty list or empty string. This is useful for
	" invoking functions (an expression, not Funcref) with optional
	" arguments.
	return eval(substitute(a:Action, '\C' . ingo#actions#GetValExpr(), '', 'g'))
    else
	let l:val = (a:0 == 1 ? a:1 : a:000)
	return get(map([l:val], a:Action), 0, '')
    endif
endfunction

" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
autoload/ingo/actions/iterations.vim	[[[1
339
" ingo/actions/iterations.vim: Repeated action execution over several targets.
"
" DEPENDENCIES:
"   - ingo/actions.vim autoload script
"   - ingo/escape/file.vim autoload script
"
" Copyright: (C) 2016 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
"
" REVISION	DATE		REMARKS
"   1.025.001	29-Jul-2016	file creation

function! ingo#actions#iterations#WinDo( alreadyVisitedBuffers, ... )
"******************************************************************************
"* PURPOSE:
"   Invoke a:Action on each window in the current tab page, unless the buffer is
"   in a:alreadyVisitedBuffers.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:alreadyVisitedBuffers     Dictionary with already visited buffer numbers
"				as keys. Will be added to, and the same buffers
"				in other windows will be skipped. Pass 0 to
"				visit _all_ windows, regardless of the buffers
"				they display.
"   a:Action                    Either a Funcref or Ex commands to be executed
"				in each window.
"   ...                         Arguments passed to an a:Action Funcref.
"* RETURN VALUES:
"   None.
"******************************************************************************
    let l:originalWinNr = winnr()
    let l:previousWinNr = winnr('#') ? winnr('#') : 1

    " By entering a window, its height is potentially increased from 0 to 1 (the
    " minimum for the current window). To avoid any modification, save the window
    " sizes and restore them after visiting all windows.
    let l:originalWindowLayout = winrestcmd()
    let l:didSwitchWindows = 0

    try
	for l:winNr in range(1, winnr('$'))
	    let l:bufNr = winbufnr(l:winNr)
	    if a:alreadyVisitedBuffers is# 0 || ! has_key(a:alreadyVisitedBuffers, l:bufNr)
		if l:winNr != winnr()
		    execute 'noautocmd' l:winNr . 'wincmd w'
		    let l:didSwitchWindows = 1
		endif
		if type(a:alreadyVisitedBuffers) == type({}) | let a:alreadyVisitedBuffers[bufnr('')] = 1 | endif

		call call(function('ingo#actions#ExecuteOrFunc'), a:000)
	    endif
	endfor
    finally
	if l:didSwitchWindows
	    noautocmd execute l:previousWinNr . 'wincmd w'
	    noautocmd execute l:originalWinNr . 'wincmd w'
	    silent! execute l:originalWindowLayout
	endif
    endtry
endfunction

function! ingo#actions#iterations#TabWinDo( alreadyVisitedTabPages, alreadyVisitedBuffers, ... )
"******************************************************************************
"* PURPOSE:
"   Invoke a:Action on each window in each tab page, unless the buffer is in
"   a:alreadyVisitedBuffers.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:alreadyVisitedTabPages    Dictionary with already visited tabpage numbers
"				as keys. Will be added to, those tab pages will
"				be skipped. Pass empty Dictionary to visit _all_
"				tab pages.
"   a:alreadyVisitedBuffers     Dictionary with already visited buffer numbers
"				as keys. Will be added to, and the same buffers
"				in other windows / tab pages will be skipped.
"				Pass 0 to visit _all_ windows and tab pages,
"				regardless of the buffers they display.
"   a:Action                    Either a Funcref or Ex commands to be executed
"				in each window.
"   ...                         Arguments passed to an a:Action Funcref.
"* RETURN VALUES:
"   None.
"******************************************************************************
    let l:originalTabNr = tabpagenr()
    let l:didSwitchTabs = 0
    try
	for l:tabNr in range(1, tabpagenr('$'))
	    if ! has_key(a:alreadyVisitedTabPages, l:tabNr)
		let a:alreadyVisitedTabPages[l:tabNr] = 1
		if ! empty(a:alreadyVisitedBuffers) && ingo#collections#differences#ContainsLoosely(keys(a:alreadyVisitedBuffers), tabpagebuflist(l:tabNr))
		    " All buffers of that tab page have already been visited; no
		    " need to go there.
		    continue
		endif

		if l:tabNr != tabpagenr()
		    execute 'noautocmd' l:tabNr . 'tabnext'
		    let l:didSwitchTabs = 1
		endif

		let l:originalWinNr = winnr()
		let l:previousWinNr = winnr('#') ? winnr('#') : 1
		" By entering a window, its height is potentially increased from 0 to 1 (the
		" minimum for the current window). To avoid any modification, save the window
		" sizes and restore them after visiting all windows.
		let l:originalWindowLayout = winrestcmd()
		let l:didSwitchWindows = 0

		try
		    for l:winNr in range(1, winnr('$'))
			let l:bufNr = winbufnr(l:winNr)
			if a:alreadyVisitedBuffers is# 0 || ! has_key(a:alreadyVisitedBuffers, l:bufNr)
			    execute 'noautocmd' l:winNr . 'wincmd w'

			    let l:didSwitchWindows = 1
			    if type(a:alreadyVisitedBuffers) == type({}) | let a:alreadyVisitedBuffers[bufnr('')] = 1 | endif

			    call call(function('ingo#actions#ExecuteOrFunc'), a:000)
			endif
		    endfor
		finally
		    if l:didSwitchWindows
			noautocmd execute l:previousWinNr . 'wincmd w'
			noautocmd execute l:originalWinNr . 'wincmd w'
			silent! execute l:originalWindowLayout
		    endif
		endtry
	    endif
	endfor
    finally
	if l:didSwitchTabs
	    noautocmd execute l:originalTabNr . 'tabnext'
	endif
    endtry
endfunction

function! s:GetNextArgNr( argNr, alreadyVisitedBuffers )
    let l:argNr = a:argNr + 1   " Try next argument.
    while l:argNr <= argc()
	let l:bufNr = bufnr(ingo#escape#file#bufnameescape(argv(a:argNr - 1)))
	if l:bufNr == -1 || type(a:alreadyVisitedBuffers) != type({}) || ! has_key(a:alreadyVisitedBuffers, l:bufNr)
	    return l:argNr
	endif

	" That one was already visited; continue searching.
	let l:argNr += 1
    endwhile
    return -1
endfunction
function! ingo#actions#iterations#ArgDo( alreadyVisitedBuffers, ... )
"******************************************************************************
"* PURPOSE:
"   Invoke a:Action on each argument in the argument list, unless the buffer is
"   in a:alreadyVisitedBuffers.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   Prints any Vim exception as error message.
"* INPUTS:
"   a:alreadyVisitedBuffers     Dictionary with already visited buffer numbers
"				as keys. Will be added to, and the same buffers
"				in other arguments will be skipped. Pass 0 to
"				visit _all_ arguments.
"   a:Action                    Either a Funcref or Ex commands to be executed
"				in each window.
"   ...                         Arguments passed to an a:Action Funcref.
"* RETURN VALUES:
"   Number of Vim exceptions raised while iterating through the argument list
"   (e.g. errors when loading buffers) or from executing a:Action.
"******************************************************************************
    let l:originalBufNr = bufnr('')
    let l:originalWindowLayout = winrestcmd()
    let l:originalWinNr = winnr()
    let l:previousWinNr = winnr('#') ? winnr('#') : 1

    let l:nextArgNr = s:GetNextArgNr(0, a:alreadyVisitedBuffers)
    if l:nextArgNr == -1
	return | " No arguments left.
    endif

    let l:didSplit = 0
    let l:failureCnt = 0
    try
	try
	    execute 'noautocmd silent keepalt leftabove' l:nextArgNr . 'sargument'
	    let l:didSplit = 1
	catch
	    call ingo#msg#VimExceptionMsg()
	    let l:failureCnt += 1
	    if bufnr('') == l:originalBufNr
		" We failed to split to the target buffer; bail out, as we need
		" the split.
		return l:failureCnt
	    endif
	endtry

	while 1
	    let l:bufNr = bufnr('')
	    if type(a:alreadyVisitedBuffers) == type({}) | let a:alreadyVisitedBuffers[bufnr('')] = 1 | endif

	    try
		call call(function('ingo#actions#ExecuteOrFunc'), a:000)
	    catch
		call ingo#msg#VimExceptionMsg()
		let l:failureCnt += 1
	    endtry

	    let l:nextArgNr = s:GetNextArgNr(l:nextArgNr, a:alreadyVisitedBuffers)
	    if l:nextArgNr == -1
		break
	    endif

	    try
		execute 'noautocmd silent keepalt' l:nextArgNr . 'argument'
	    catch
		call ingo#msg#VimExceptionMsg()
		let l:failureCnt += 1
	    endtry
	endwhile
    finally
	if l:didSplit
	    noautocmd silent! close!
	    noautocmd execute l:previousWinNr . 'wincmd w'
	    noautocmd execute l:originalWinNr . 'wincmd w'
	    silent! execute l:originalWindowLayout
	endif
    endtry

    return l:failureCnt
endfunction

function! s:GetNextBufNr( bufNr, alreadyVisitedBuffers )
    let l:bufNr = a:bufNr + 1   " Try next buffer.
    let l:lastBufNr = bufnr('$')
    while l:bufNr <= l:lastBufNr
	if buflisted(l:bufNr) && (type(a:alreadyVisitedBuffers) != type({}) || ! has_key(a:alreadyVisitedBuffers, l:bufNr))
	    return l:bufNr
	endif

	" That one was already visited; continue searching.
	let l:bufNr += 1
    endwhile
    return -1
endfunction
function! ingo#actions#iterations#BufDo( alreadyVisitedBuffers, ... )
"******************************************************************************
"* PURPOSE:
"   Invoke a:Action on each listed buffer, unless the buffer is in
"   a:alreadyVisitedBuffers.
"* SEE ALSO:
"   To execute an Action in a single visible buffer, use
"   ingo#buffer#visible#Execute() / ingo#buffer#visible#Call().
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   Prints any Vim exception as error message.
"* INPUTS:
"   a:alreadyVisitedBuffers     Dictionary with already visited buffer numbers
"				as keys. Will be added to. Pass 0 or {} to visit
"				_all_ buffers.
"   a:Action                    Either a Funcref or Ex commands to be executed
"				in each buffer.
"   ...                         Arguments passed to an a:Action Funcref.
"* RETURN VALUES:
"   Number of Vim exceptions raised while iterating through the buffer list
"   (e.g. errors when loading buffers) or from executing a:Action.
"******************************************************************************
    let l:originalWindowLayout = winrestcmd()
    let l:originalWinNr = winnr()
    let l:previousWinNr = winnr('#') ? winnr('#') : 1

    let l:nextBufNr = s:GetNextBufNr(0, a:alreadyVisitedBuffers)
    if l:nextBufNr == -1
	return | " No buffers left.
    endif

    let l:didSplit = 0
    let l:failureCnt = 0
    let l:save_switchbuf = &switchbuf | set switchbuf= | " :sbuffer should always open a new split (so we can :close it without checking).
    try
	try
	    execute 'noautocmd silent keepalt leftabove' l:nextBufNr . 'sbuffer'
	catch
	    call ingo#msg#VimExceptionMsg()
	    let l:failureCnt += 1
	    if bufnr('') != l:nextBufNr
		" We failed to split to the target buffer; bail out, as we need
		" the split.
		return l:failureCnt
	    endif
	finally
	    let &switchbuf = l:save_switchbuf
	endtry

	let l:didSplit = 1
	while 1
	    let l:bufNr = bufnr('')
	    if type(a:alreadyVisitedBuffers) == type({}) | let a:alreadyVisitedBuffers[bufnr('')] = 1 | endif

	    try
		call call(function('ingo#actions#ExecuteOrFunc'), a:000)
	    catch
		call ingo#msg#VimExceptionMsg()
		let l:failureCnt += 1
	    endtry

	    let l:nextBufNr = s:GetNextBufNr(l:nextBufNr, a:alreadyVisitedBuffers)
	    if l:nextBufNr == -1
		break
	    endif

	    try
		execute 'noautocmd silent keepalt' l:nextBufNr . 'buffer'
	    catch
		call ingo#msg#VimExceptionMsg()
		let l:failureCnt += 1
	    endtry
	endwhile
    finally
	if l:didSplit
	    noautocmd silent! close!
	    noautocmd execute l:previousWinNr . 'wincmd w'
	    noautocmd execute l:originalWinNr . 'wincmd w'
	    silent! execute l:originalWindowLayout
	endif
    endtry

    return l:failureCnt
endfunction

" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
autoload/ingo/actions/special.vim	[[[1
51
" ingo/actions/special.vim: Action execution within special environments.
"
" DEPENDENCIES:
"   - ingo/actions.vim autoload script
"   - ingo/compat.vim autoload script
"   - ingo/workingdir.vim autoload script
"
" Copyright: (C) 2016-2018 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>

function! ingo#actions#special#NoAutoChdir( ... )
"******************************************************************************
"* PURPOSE:
"   Execute a:Action with :set noautochdir.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:Action    Either a Funcref or Ex commands to be executed.
"   ...         Arguments passed to an a:Action Funcref.
"* RETURN VALUES:
"   Result of Funcref, or empty string in case of Ex commands.
"******************************************************************************
    " Unfortunately, restoring the 'autochdir' option clobbers any temporary CWD
    " override. So we may have to restore the CWD, too.
    let l:save_cwd = getcwd()
    let l:chdirCommand = ingo#workingdir#ChdirCommand()

    " The 'autochdir' option adapts the CWD, so any (relative) filepath to the
    " filename in the other window would be omitted. Temporarily turn this off;
    " may be a little bit faster, too.
    if exists('+autochdir')
	let l:save_autochdir = &autochdir
	set noautochdir
    endif
    try
	return call(function('ingo#actions#ExecuteOrFunc'), a:000)
    finally
	if exists('l:save_autochdir')
	    let &autochdir = l:save_autochdir
	endif
	if getcwd() !=# l:save_cwd
	    execute l:chdirCommand ingo#compat#fnameescape(l:save_cwd)
	endif
    endtry
endfunction

" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
autoload/ingo/area.vim	[[[1
41
" ingo/area.vim: Functions to deal with areas.
"
" DEPENDENCIES:
"
" Copyright: (C) 2017-2019 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>

function! ingo#area#IsEmpty( area )
"******************************************************************************
"* PURPOSE:
"   Test whether a:area is empty (or even invalid, with the end before the
"   start). Does not check whether the positions actually exist in the current
"   buffer.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:area  [[startLnum, startCol], [endLnum, endCol]]
"* RETURN VALUES:
"   1 if area is valid and covers at least one character, 0 otherwise.
"******************************************************************************
    if empty(a:area)
	return 1
    elseif a:area[0][0] == 0 || a:area[1][0] == 0
	return 1
    elseif a:area[0][0] > a:area[1][0]
	return 1
    elseif a:area[0][0] == a:area[1][0] && a:area[0][1] > a:area[1][1]
	return 1
    endif
    return 0
endfunction

function! ingo#area#EmptyArea( pos ) abort
    return [a:pos, ingo#pos#Before(a:pos)]
endfunction

" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
autoload/ingo/area/frompattern.vim	[[[1
135
" ingo/area/frompattern.vim: Functions to determine an area in the current buffer.
"
" DEPENDENCIES:
"   - ingo/text.vim autoload script
"   - ingo/text/frompattern.vim autoload script
"
" Copyright: (C) 2017-2019 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>

function! ingo#area#frompattern#GetHere( pattern, ... )
"******************************************************************************
"* PURPOSE:
"   Extract the positions of the match of a:pattern starting from the current
"   cursor position.
"* SEE ALSO:
"   - ingo#text#frompattern#GetHere() returns the match, not the positions.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:pattern       Regular expression to search. 'ignorecase', 'smartcase' and
"		    'magic' applies. When empty, the last search pattern |"/| is
"		    used.
"   a:lastLine      End line number to search for the start of the pattern.
"		    Optional; defaults to the current line.
"   a:returnValueOnNoSelection  Optional return value if there's no match. If
"				omitted, [[0, 0], [0, 0]] will be returned.
"* RETURN VALUES:
"   [[startLnum, startCol], [endLnum, endCol]], or a:returnValueOnNoSelection.
"   endCol points to the last character, not beyond it!
"******************************************************************************
    let l:startPos = getpos('.')[1:2]
    let l:endPos = searchpos(a:pattern, 'cenW', (a:0 ? a:1 : line('.')))
    if l:endPos == [0, 0]
	return (a:0 >= 2 ? a:2 : [[0, 0], [0, 0]])
    endif
    return [l:startPos, l:endPos]
endfunction
function! ingo#area#frompattern#GetAroundHere( pattern, ... )
"******************************************************************************
"* PURPOSE:
"   Extract the positions of the match of a:pattern starting the match from the
"   current cursor position, but (unlike ingo#area#frompattern#GetHere()), also
"   include matched characters _before_ the current position.
"* SEE ALSO:
"   - ingo#text#frompattern#GetAroundHere() returns the match, not the positions.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:pattern       Regular expression to search. 'ignorecase', 'smartcase' and
"		    'magic' applies. When empty, the last search pattern |"/| is
"		    used.
"   a:lastLine      End line number to search for the start of the pattern.
"		    Optional; defaults to the current line.
"   a:firstLine     First line number to search for the start of the pattern.
"		    Optional; defaults to the current line.
"   a:returnValueOnNoSelection  Optional return value if there's no match. If
"				omitted, [[0, 0], [0, 0]] will be returned.
"* RETURN VALUES:
"   [[startLnum, startCol], [endLnum, endCol]], or a:returnValueOnNoSelection.
"   endCol points to the last character, not beyond it!
"******************************************************************************
    let l:startPos = searchpos(a:pattern, 'bcnW', (a:0 >= 2 ? a:2 : line('.')))
    if l:startPos == [0, 0]
	return (a:0 >= 3 ? a:3 : [[0, 0], [0, 0]])
    endif
    let l:endPos = searchpos(a:pattern, 'cenW', (a:0 ? a:1 : line('.')))
    if l:endPos == [0, 0]
	return (a:0 >= 3 ? a:3 : [[0, 0], [0, 0]])
    endif
    return [l:startPos, l:endPos]
endfunction


function! ingo#area#frompattern#Get( firstLine, lastLine, pattern, isOnlyFirstMatch, isUnique )
"******************************************************************************
"* PURPOSE:
"   Extract all non-overlapping positions of matches of a:pattern in the
"   a:firstLine, a:lastLine range and return them as a List.
"* SEE ALSO:
"   - ingo#text#frompattern#Get() returns the matches, not the positions.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:firstLine     Start line number to search.
"   a:lastLine      End line number to search.
"   a:pattern       Regular expression to search. 'ignorecase', 'smartcase' and
"		    'magic' applies. When empty, the last search pattern |"/| is
"		    used.
"   a:isOnlyFirstMatch  Flag whether to include only the first match in every
"			line.
"   a:isUnique          Flag whether duplicate matches are omitted from the
"			result. When set, the result will consist of areas with
"			unique content.
"* RETURN VALUES:
"   [[[startLnum, startCol], [endLnum, endCol]], ...], or [].
"   endCol points to the last character, not beyond it!
"******************************************************************************
    let l:save_view = winsaveview()
	let l:areas = []
	let l:matches = {}
	call cursor(a:firstLine, 1)
	let l:isFirst = 1
	while 1
	    let l:startPos = searchpos(a:pattern, (l:isFirst ? 'c' : '') . 'W', a:lastLine)
	    let l:isFirst = 0
	    if l:startPos == [0, 0] | break | endif
	    let l:endPos = searchpos(a:pattern, 'ceW', a:lastLine)
	    if l:endPos == [0, 0] | break | endif
	    if a:isUnique
		let l:match = ingo#text#Get(l:startPos, l:endPos)
		if has_key(l:matches, l:match)
		    continue
		endif
		let l:matches[l:match] = 1
	    endif

	    call add(l:areas, [l:startPos, l:endPos])
"****D echomsg '****' string(l:startPos) string(l:endPos)
	    if a:isOnlyFirstMatch
		normal! $
	    endif
	endwhile
    call winrestview(l:save_view)
    return l:areas
endfunction

" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
autoload/ingo/avoidprompt.vim	[[[1
252
" ingo/avoidprompt.vim: Functions for echoing text without the hit-enter prompt.
"
" DESCRIPTION:
"   When using the :echo or :echomsg commands with a long text, Vim will show a
"   'Hit ENTER' prompt (|hit-enter|), so that the user has a chance to actually
"   read the entire text. In most cases, this is good; however, some mappings
"   and custom commands just want to echo additional, secondary information
"   without disrupting the user. Especially for mappings that are usually
"   repeated quickly "/foo<CR>, n, n, n", a hit-enter prompt would be highly
"   irritating.
"   This script provides an :echo replacement which truncates lines so that the
"   hit-enter prompt doesn't happen. The echoed line is too long if it is wider
"   than the width of the window, minus cmdline space taken up by the ruler and
"   showcmd features. The non-standard widths of <Tab>, unprintable (e.g. ^M)
"   and double-width characters (e.g. Japanese Kanji) are taken into account.

" DEPENDENCIES:
"   - ingo/compat.vim autoload script
"   - ingo/strdisplaywidth.vim autoload script
"
" TODO:
"   - Consider 'cmdheight', add argument isSingleLine.
"
" Copyright: (C) 2008-2018 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>

function! ingo#avoidprompt#MaxLength()
    let l:maxLength = &columns

    " Account for space used by elements in the command-line to avoid
    " 'Hit ENTER' prompts.
    " If showcmd is on, it will take up 12 columns.
    " If the ruler is enabled, but not displayed in the status line, it
    " will in its default form take 17 columns.  If the user defines
    " a custom &rulerformat, they will need to specify how wide it is.
    if has('cmdline_info')
	if &showcmd == 1
	    let l:maxLength -= 12
	else
	    let l:maxLength -= 2 " Ruler does not occupy the last cell, and there has to be one empty cell between ruler and message.
	endif
	if &ruler == 1 && has('statusline') && ((&laststatus == 0) || (&laststatus == 1 && winnr('$') == 1))
	    if &rulerformat == ''
		" Default ruler is 17 chars wide.
		let l:maxLength -= 17
	    elseif exists('g:rulerwidth')
		" User specified width of custom ruler.
		let l:maxLength -= g:rulerwidth
	    else
		" Don't know width of custom ruler, make a conservative
		" guess.
		let l:maxLength -= &columns / 2
	    endif
	endif
    else
	let l:maxLength -= 1 " Cannot occupy the last cell in the line.
    endif
    return l:maxLength
endfunction

if ! exists('g:IngoLibrary_TruncateEllipsis')
    let g:IngoLibrary_TruncateEllipsis = (&encoding ==# 'utf-8' ? "\u2026" : '...')
endif
function! ingo#avoidprompt#TruncateTo( text, length, ... )
"*******************************************************************************
"* PURPOSE:
"   Truncate a:text to a maximum of a:length virtual columns by dropping text in
"   the middle of a:text if necessary. This is based on what Vim does when for
"   example echoing a very long search pattern during n/N.
"* SEE ALSO:
"   - ingo#strdisplaywidth#TruncateTo() does something similar, but truncates at
"     the end, and doesn't account for buffer-local tabstop values.
"* ASSUMPTIONS / PRECONDITIONS:
"   The ellipsis can be configured by g:IngoLibrary_TruncateEllipsis.
"* EFFECTS / POSTCONDITIONS:
"   none
"* INPUTS:
"   a:text	Text which may be truncated to fit.
"   a:length	Maximum virtual columns for a:text.
"   a:reservedColumns	Optional number of columns that are already taken in the
"			line (before a:text, this matters for tab rendering); if
"			specified, a:text will be truncated to (MaxLength() -
"			a:reservedColumns).
"   a:truncationIndicator   Optional text to be appended when truncation
"			    appears. a:text is further reduced to account for
"			    its width. Default is "..." or the single-char UTF-8
"			    variant if the encoding also is UTF-8.
"* RETURN VALUES:
"   Truncated a:text.
"*******************************************************************************
    if a:length <= 0
	return ''
    endif
    let l:reservedColumns = (a:0 > 0 ? a:1 : 0)
    let l:reservedPadding = repeat(' ', l:reservedColumns)
    let l:truncationIndicator = (a:0 >= 2 ? a:2 : g:IngoLibrary_TruncateEllipsis)

    " The \%<23v regexp item uses the local 'tabstop' value to determine the
    " virtual column. As we want to echo with default tabstop 8, we need to
    " temporarily set it up this way.
    let l:save_ts = &l:tabstop
    setlocal tabstop=8

    let l:text = a:text
    try
	if ingo#strdisplaywidth#HasMoreThan(l:reservedPadding . l:text, a:length + l:reservedColumns)
	    let l:ellipsisLength = ingo#compat#strchars(l:truncationIndicator)

	    " Handle pathological cases.
	    if a:length == l:ellipsisLength
		return l:truncationIndicator
	    elseif a:length < l:ellipsisLength
		return ingo#compat#strcharpart(l:truncationIndicator, 0, a:length)
	    endif

	    " Consider the length of the (configurable) "..." ellipsis.
	    " 1 must be added because columns start at 1, not 0.
	    let l:length = a:length - l:ellipsisLength + 1
	    let l:frontCol = l:length / 2
	    let l:backCol  = (l:length % 2 == 0 ? (l:frontCol - 1) : l:frontCol)
"**** echomsg '**** ' a:length ':' l:frontCol '-' l:backCol
	    while 1
		let l:fullText =
		\   ingo#strdisplaywidth#strleft(l:reservedPadding . l:text, l:frontCol) .
		\   l:truncationIndicator .
		\   ingo#strdisplaywidth#strright(l:text, l:backCol)

		" The strright() cannot precisely account for the rendering of
		" tab widths. Check the result, and if necessary, remove further
		" characters until we go below the limit.
		if ! ingo#strdisplaywidth#HasMoreThan(l:fullText, a:length + l:reservedColumns)
		    let l:text = strpart(l:fullText, l:reservedColumns)
		    break
		endif
		if l:backCol > 0
		    let l:backCol -= 1
		else
		    let l:frontCol -= 1
		endif
	    endwhile
	endif
    finally
	let &l:tabstop = l:save_ts
    endtry
    return l:text
endfunction
function! ingo#avoidprompt#Truncate( text, ... )
"*******************************************************************************
"* PURPOSE:
"   Truncate a:text so that it can be echoed to the command line without causing
"   the "Hit ENTER" prompt (if desired by the user through the 'shortmess'
"   option). Truncation will only happen in (the middle of) a:text.
"* ASSUMPTIONS / PRECONDITIONS:
"   none
"* EFFECTS / POSTCONDITIONS:
"   none
"* INPUTS:
"   a:text	Text which may be truncated to fit.
"   a:reservedColumns	Optional number of columns that are already taken in the
"			line (before a:text, this matters for tab rendering); if
"			specified, a:text will be truncated to (MaxLength() -
"			a:reservedColumns).
"   a:truncationIndicator   Optional text to be appended when truncation
"			    appears. a:text is further reduced to account for
"			    its width. Default is "..." or the single-char UTF-8
"			    variant if the encoding also is UTF-8.
"* RETURN VALUES:
"   Truncated a:text.
"*******************************************************************************
    if &shortmess !~# 'T'
	" People who have removed the 'T' flag from 'shortmess' want no
	" truncation.
	return a:text
    endif

    let l:reservedColumns = (a:0 > 0 ? a:1 : 0)
    let l:maxLength = ingo#avoidprompt#MaxLength() - l:reservedColumns

    return call('ingo#avoidprompt#TruncateTo', [a:text, l:maxLength] + a:000)
endfunction

function! ingo#avoidprompt#TranslateLineBreaks( text )
"*******************************************************************************
"* PURPOSE:
"   Translate embedded line breaks in a:text into a printable characters to
"   avoid that a single-line string is split into multiple lines (and thus
"   broken over multiple lines or mostly obscured) by the :echo command and
"   ingo#avoidprompt#Echo() functions.
"
"   For the :echo command, strtrans() is not necessary; unprintable characters
"   are automatically translated (and shown in a different highlighting, an
"   advantage over indiscriminate preprocessing with strtrans()). However, :echo
"   observes embedded line breaks (in contrast to :echomsg), which would mess up
"   a single-line message that contains embedded \n = <CR> = ^M or <LF> = ^@.
"
"   For the :echomsg and :echoerr commands, neither strtrans() nor this function
"   are necessary; all translation is done by the built-in command.
"
"* LIMITATIONS:
"   When :echo'd, the translated line breaks are not rendered with the typical
"   'SpecialKey' highlighting.
"
"* ASSUMPTIONS / PRECONDITIONS:
"	? List of any external variable, control, or other element whose state affects this procedure.
"* EFFECTS / POSTCONDITIONS:
"	? List of the procedure's effect on each external variable, control, or other element.
"* INPUTS:
"   a:text	Text.
"* RETURN VALUES:
"   Text with translated line breaks; the text will :echo into a single line.
"*******************************************************************************
    return substitute(a:text, "[\<CR>\<LF>]", '\=strtrans(submatch(0))', 'g')
endfunction

function! ingo#avoidprompt#Echo( text )
    echo ingo#avoidprompt#Truncate(a:text)
endfunction
function! ingo#avoidprompt#EchoMsg( text )
"******************************************************************************
"* PURPOSE:
"   Echo as much as can be viewed in the command-line area of a:text, while
"   saving the full message in the message history. This way, there's no
"   hit-enter prompt, but the user can still recall the message history to see
"   the full message (in case important bits were truncated).
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   Echos a:text and saves it in the message history. May redraw the window.
"* INPUTS:
"   a:text	Text which may be truncated to fit.
"* RETURN VALUES:
"   None.
"******************************************************************************
    let l:truncatedText = ingo#avoidprompt#Truncate(a:text)
    echomsg a:text
    if l:truncatedText !=# a:text
	" Need to overwrite the overly long message (it's still in full in the
	" message history).
	redraw  " This avoids the hit-enter prompt.
	echo l:truncatedText    | " Use :echo because the full text already is in the message history.
    endif
endfunction
function! ingo#avoidprompt#EchoAsSingleLine( text )
    echo ingo#avoidprompt#Truncate(ingo#avoidprompt#TranslateLineBreaks(a:text))
endfunction
function! ingo#avoidprompt#EchoMsgAsSingleLine( text )
    call ingo#avoidprompt#EchoMsg(ingo#avoidprompt#TranslateLineBreaks(a:text))
endfunction

" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
autoload/ingo/binary.vim	[[[1
67
" ingo/binary.vim: Functions for working with binary numbers.
"
" DEPENDENCIES:
"   - nary.vim autoload script
"
" Copyright: (C) 2016-2017 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
"
" REVISION	DATE		REMARKS
"   1.030.002	14-May-2017	Generalize functions into ingo/nary.vim and
"				delegate ingo#binary#...() functions to those.
"   1.029.001	28-Dec-2016	file creation

function! ingo#binary#FromNumber( number, ... )
"******************************************************************************
"* PURPOSE:
"   Turn the integer a:number into a (little-endian) List of boolean values.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:number    Positive integer.
"   a:bitNum    Optional number of bits to use. If specified and a:number cannot
"		be represented by it, a exception is thrown. If a:bitNum is
"		negative, only the lower bits will be returned. If omitted, the
"		minimal amount of bits is used.
"* RETURN VALUES:
"   List of [b0, b1, b2, ...] boolean values; lowest bits come first.
"******************************************************************************
    return call('ingo#nary#FromNumber', [2, a:number] + a:000)
endfunction
function! ingo#binary#ToNumber( bits )
"******************************************************************************
"* PURPOSE:
"   Turn the (little-endian) List of boolean values into a number.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:bits  List of [b0, b1, b2, ...] boolean values; lowest bits come first.
"* RETURN VALUES:
"   Positive integer represented by a:bits.
"******************************************************************************
    return call('ingo#nary#ToNumber', [2, a:bits] + a:000)
endfunction

function! ingo#binary#BitsRequired( number )
"******************************************************************************
"* PURPOSE:
"   Determine the number of bits required to represent a:number.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:number    Positive integer.
"* RETURN VALUES:
"   Number of bits required to represent numbers between 0 and a:number.
"******************************************************************************
    return ingo#nary#ElementsRequired(2, a:number)
endfunction

" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
autoload/ingo/buffer.vim	[[[1
81
" ingo/buffer.vim: Functions for buffer information.
"
" DEPENDENCIES:
"
" Copyright: (C) 2013-2017 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
"
" REVISION	DATE		REMARKS
"   1.030.006	25-May-2017	Add ingo#buffer#VisibleList().
"   1.025.005	29-Jul-2016	Add ingo#buffer#ExistOtherLoadedBuffers().
"   1.015.004	18-Nov-2013	Make buffer argument of ingo#buffer#IsBlank()
"				optional, defaulting to the current buffer.
"				Allow use of ingo#buffer#IsEmpty() with other
"				buffers.
"   1.014.003	07-Oct-2013	Add ingo#buffer#IsPersisted(), taken from
"				autoload/ShowTrailingWhitespace/Filter.vim.
"   1.010.002	08-Jul-2013	Add ingo#buffer#IsEmpty().
"   1.006.001	29-May-2013	file creation
let s:save_cpo = &cpo
set cpo&vim

function! ingo#buffer#IsEmpty( ... )
    if a:0
	return (getbufline(a:1, 2) == [] && empty(get(getbufline(a:1, 1), 0, '')))
    else
	return (line('$') == 1 && empty(getline(1)))
    endif
endfunction

function! ingo#buffer#IsBlank( ... )
    let l:bufNr = (a:0 ? a:1 : '')
    return (empty(bufname(l:bufNr)) &&
    \ getbufvar(l:bufNr, '&modified') == 0 &&
    \ empty(getbufvar(l:bufNr, '&buftype'))
    \)
endfunction

function! ingo#buffer#IsPersisted( ... )
    let l:bufType = (a:0 ? getbufvar(a:1, '&buftype') : &l:buftype)
    return (empty(l:bufType) || l:bufType ==# 'acwrite')
endfunction

function! ingo#buffer#ExistOtherBuffers( targetBufNr )
    return ! empty(filter(range(1, bufnr('$')), 'buflisted(v:val) && v:val != a:targetBufNr'))
endfunction
function! ingo#buffer#ExistOtherLoadedBuffers( targetBufNr )
    return ! empty(filter(range(1, bufnr('$')), 'buflisted(v:val) && bufloaded(v:val) && v:val != a:targetBufNr'))
endfunction

function! ingo#buffer#IsEmptyVim()
    let l:currentBufNr = bufnr('')
    return ingo#buffer#IsBlank(l:currentBufNr) && ! ingo#buffer#ExistOtherBuffers(l:currentBufNr)
endfunction

function! ingo#buffer#VisibleList()
"******************************************************************************
"* PURPOSE:
"   The result is a List, where each item is the number of the buffer associated
"   with each window in all tab pages. Like |tabpagebuflist()|, but for all tab
"   pages.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   None.
"* RETURN VALUES:
"   List of buffer numbers; may contain duplicates.
"******************************************************************************
    let l:buflist = []
    for l:i in range(tabpagenr('$'))
	call extend(l:buflist, tabpagebuflist(l:i + 1))
    endfor
    return l:buflist
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo
" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
autoload/ingo/buffer/ephemeral.vim	[[[1
144
" ingo/buffer/ephemeral.vim: Functions to execute stuff in the buffer that won't persist after the call.
"
" DEPENDENCIES:
"   - ingo/lines.vim autoload script
"   - ingo/undo.vim autoload script
"
" Copyright: (C) 2018-2019 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>

function! ingo#buffer#ephemeral#Call( Funcref, arguments, ... )
"******************************************************************************
"* PURPOSE:
"   Invoke a:Funcref with a:arguments on the current buffer without persisting the changes.
"   Any modifications to the text (but not side effects like changing buffer
"   settings!) will be undone afterwards, as if nothing happened. Therefore, you
"   probably want to :return something about the buffer from a:Funcref.
"
"* ASSUMPTIONS / PRECONDITIONS:
"   Current buffer is modifiable.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:Funcref   Funcref to be executed. Will be passed a:arguments.
"   a:arguments Arguments to be passed.
"   a:undoCnt   Optional number of changes that a:command will do. If this is a
"		fixed number and you know it, passing this is slightly more
"		efficient.
"* RETURN VALUES:
"   Return value of a:Funcref
"******************************************************************************
    let l:save_view = winsaveview()
    let l:save_modified = &l:modified
    let l:save_lines = getline(1, line('$'))
    let [l:save_change_begin, l:save_change_end] = [getpos("'["), getpos("']")]

    if ! a:0
	let l:undoChangeNumber = ingo#undo#GetChangeNumber()
    endif

    try
	return call(a:Funcref, a:arguments)
    finally
	try
	    " Using :undo to roll back the actions doesn't pollute the undo
	    " history. Only explicitly restore the saved lines as a fallback.
	    if a:0
		for l:i in range(a:1)
		    silent undo
		endfor
	    else
		if l:undoChangeNumber < 0
		    throw 'CannotUndo'
		endif
		" XXX: Inside a function invocation, no separate change is created.
		if changenr() > l:undoChangeNumber
		    silent execute 'undo' l:undoChangeNumber
"****D else | echomsg '**** no new undo change number'
		endif
	    endif

	    if line('$') != len(l:save_lines) || l:save_lines !=# getline(1, line('$'))
		" Fallback in case the undo somehow failed.
		throw 'CannotUndo'
	    endif
	catch /^CannotUndo$\|^Vim\%((\a\+)\)\=:E/
"****D echomsg '**** falling back to replace'
	    silent %delete _
	    silent call ingo#lines#PutBefore(1, l:save_lines)
	    silent $delete _

	    let &l:modified = l:save_modified
	endtry

	call ingo#change#Set(l:save_change_begin, l:save_change_end)
	call winrestview(l:save_view)
    endtry
endfunction

function! s:Executor( command )
    execute a:command
endfunction
function! ingo#buffer#ephemeral#Execute( command, ... )
"******************************************************************************
"* PURPOSE:
"   Invoke an Ex command on the current buffer without persisting the changes.
"   Any modifications to the text (but not side effects like changing buffer
"   settings!) will be undone afterwards, as if nothing happened. Therefore, you
"   probably want to do something like :keepalt write TEMPFLE to store the
"   changes somewhere else.
"
"* ASSUMPTIONS / PRECONDITIONS:
"   Current buffer is modifiable.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:lines     List of lines (or String of a single line) to be temporarily
"		processed by a:command.
"   a:command	Ex command to be invoked.
"   a:undoCnt   Optional number of changes that a:command will do. If this is a
"		fixed number and you know it, passing this is slightly more
"		efficient.
"* RETURN VALUES:
"   None.
"******************************************************************************
    call call('ingo#buffer#ephemeral#Call', [function('s:Executor'), [a:command]] + a:000)
endfunction

function! ingo#buffer#ephemeral#CallForceModifiable( ... )
"******************************************************************************
"* PURPOSE:
"   Like ingo#buffer#ephemeral#Call(), but additionally make the buffer
"   modifiable by clearing 'nomodifiable' and 'readonly' temporarily.
"
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:Funcref   Funcref to be executed. Will be passed a:arguments.
"   a:arguments Arguments to be passed.
"   a:undoCnt   Optional number of changes that a:command will do. If this is a
"		fixed number and you know it, passing this is slightly more
"		efficient.
"* RETURN VALUES:
"   Return value of a:Funcref
"******************************************************************************
    let l:save_modifiable = &l:modifiable
    let l:save_readonly = &l:readonly
    setlocal modifiable noreadonly

    try
	return call('ingo#buffer#ephemeral#Call', a:000)
    finally
	let &l:readonly = l:save_readonly
	let &l:modifiable = l:save_modifiable
    endtry
endfunction
function! ingo#buffer#ephemeral#ExecuteForceModifiable( command, ...)
    call call('ingo#buffer#ephemeral#CallForceModifiable', [function('s:Executor'), [a:command]] + a:000)
endfunction

" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
autoload/ingo/buffer/generate.vim	[[[1
221
" ingo/buffer/generate.vim: Functions for creating buffers.
"
" DEPENDENCIES:
"   - ingo/compat.vim autoload script
"   - ingo/escape/file.vim autoload script
"   - ingo/fs/path.vim autoload script
"
" Copyright: (C) 2009-2019 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>

function! ingo#buffer#generate#NextBracketedFilename( filespec, template )
"******************************************************************************
"* PURPOSE:
"   Based on the current format of a:filespec, return a successor according to
"   a:template. The sequence is:
"	1. name [template]
"	2. name [template1]
"	3. name [template2]
"	4. ...
"   The "name" part may be omitted.
"   This does not check for actual occurrences in loaded buffers, etc.; it just
"   performs text manipulation!
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:filespec  Filename on which to base the result.
"   a:template  Identifier to be used inside the bracketed counted addendum.
"* RETURN VALUES:
"   filename
"******************************************************************************
    let l:templateExpr = '\V\C'. escape(a:template, '\') . '\m'
    if a:filespec !~# '\%(^\| \)\[' . l:templateExpr . ' \?\d*\]$'
	return a:filespec . (empty(a:filespec) ? '' : ' ') . '['. a:template . ']'
    elseif a:filespec !~# '\%(^\| \)\[' . l:templateExpr . ' \?\d\+\]$'
	return substitute(a:filespec, '\]$', '1]', '')
    else
	let l:number = matchstr(a:filespec, '\%(^\| \)\[' . l:templateExpr . ' \?\zs\d\+\ze\]$')
	return substitute(a:filespec, '\d\+\]$', (l:number + 1) . ']', '')
    endif
endfunction
function! s:Bufnr( dirspec, filename, isFile )
    if empty(a:dirspec) && ! a:isFile
	" This buffer does not behave like a file and is not tethered to a
	" particular directory; there should be only one buffer with this name
	" in the Vim session.
	" Do a partial search for the buffer name matching any file name in any
	" directory.
	return bufnr(ingo#escape#file#bufnameescape(a:filename, 1, 0))
    else
	return bufnr(
	\   ingo#escape#file#bufnameescape(
	\	fnamemodify(
	\	    ingo#fs#path#Combine(a:dirspec, a:filename),
	\	    '%:p'
	\	)
	\   )
	\)
    endif
endfunction
function! ingo#buffer#generate#GetUnusedBracketedFilename( dirspec, baseFilename, isFile, template )
"******************************************************************************
"* PURPOSE:
"   Determine the next available bracketed filename that does not exist as a Vim
"   buffer yet.
"* ASSUMPTIONS / PRECONDITIONS:
"	? List of any external variable, control, or other element whose state affects this procedure.
"* EFFECTS / POSTCONDITIONS:
"	? List of the procedure's effect on each external variable, control, or other element.
"* INPUTS:
"   a:dirspec   Working directory for the buffer. Pass empty string to maintain
"		the current CWD as-is.
"   a:baseFilename  Filename to base the bracketed filename on; can be empty if
"		    you don't want any prefix before the brackets.
"   a:isFile    Flag whether the buffer should behave like a file (i.e. adapt to
"		changes in the global CWD), or not. If false and a:dirspec is
"		empty, there will be only one buffer with the same filename,
"		regardless of the buffer's directory path.
"   a:template  Identifier to be used inside the bracketed counted addendum.
"* RETURN VALUES:
"   filename
"******************************************************************************
    let l:bracketedFilename = a:baseFilename
    while 1
	let l:bracketedFilename = ingo#buffer#generate#NextBracketedFilename(l:bracketedFilename, a:template)
	if s:Bufnr(a:dirspec, l:bracketedFilename, a:isFile) == -1
	    return l:bracketedFilename
	endif
    endwhile
endfunction
function! s:ChangeDir( dirspec )
    if empty( a:dirspec )
	return
    endif
    execute 'lchdir' ingo#compat#fnameescape(a:dirspec)
endfunction
function! ingo#buffer#generate#BufType( isFile )
    return (a:isFile ? 'nowrite' : 'nofile')
endfunction
function! ingo#buffer#generate#Create( dirspec, filename, isFile, contentsCommand, windowOpenCommand, NextFilenameFuncref )
"*******************************************************************************
"* PURPOSE:
"   Create (or re-use an existing) buffer (i.e. doesn't correspond to a file on
"   disk, but can be saved as such).
"   To keep the buffer (and create a new buffer on the next invocation), rename
"   the current buffer via ':file <newname>', or make it a normal buffer via
"   ':setl buftype='.
"
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   Creates or opens buffer and loads it in a window (as specified by
"   a:windowOpenCommand) and activates that window.
"* INPUTS:
"   a:dirspec	        Local working directory for the buffer (important for :!
"			commands). Pass empty string to maintain the current CWD
"			as-is. Pass '.' to maintain the CWD but also fix it via
"			:lcd. (Attention: ':set autochdir' will reset any CWD
"			once the current window is left!)
"			Pass the getcwd() output if maintaining the current CWD
"			is important for a:contentsCommand.
"   a:filename	        The name for the buffer, so it can be saved via either
"			:w! or :w <newname>.
"   a:isFile	        Flag whether the buffer should behave like a file (i.e.
"			adapt to changes in the global CWD), or not. If false
"			and a:dirspec is empty, there will be only one buffer
"			with the same a:filename, regardless of the buffer's
"			directory path.
"   a:contentsCommand	Ex command(s) to populate the buffer, e.g.
"			":1read myfile". Use ":1read" so that the first empty
"			line will be kept (it is deleted automatically), and
"			there will be no trailing empty line.
"			Pass empty string if you want to populate the buffer
"			yourself.
"			Pass a List of lines to set the buffer contents directly
"			to the lines.
"   a:windowOpenCommand	Ex command to open the window, e.g. ":vnew" or
"			":topleft new".
"   a:NextFilenameFuncref   Funcref that is invoked (with a:filename) to
"			    generate file names for the generated buffer should
"			    the desired one (a:filename) already exist but not
"			    be a generated buffer.
"* RETURN VALUES:
"   Indicator whether the buffer has been opened:
"   0	Failed to open buffer.
"   1	Already in buffer window.
"   2	Jumped to open buffer window.
"   3	Loaded existing buffer in new window.
"   4	Created buffer in new window.
"   Note: To handle errors caused by a:contentsCommand, you need to put this
"   method call into a try..catch block and :close the buffer when an exception
"   is thrown.
"*******************************************************************************
    let l:currentWinNr = winnr()
    let l:status = 0

    let l:bufnr = s:Bufnr(a:dirspec, a:filename, a:isFile)
    let l:winnr = bufwinnr(l:bufnr)
"****D echomsg '**** bufnr=' . l:bufnr 'winnr=' . l:winnr
    if l:winnr == -1
	if l:bufnr == -1
	    execute a:windowOpenCommand
	    " Note: The directory must already be changed here so that the :file
	    " command can set the correct buffer filespec.
	    call s:ChangeDir(a:dirspec)
	    execute 'silent keepalt file' ingo#compat#fnameescape(a:filename)
	    let l:status = 4
	elseif getbufvar(l:bufnr, '&buftype') ==# ingo#buffer#generate#BufType(a:isFile)
	    execute a:windowOpenCommand
	    execute l:bufnr . 'buffer'
	    let l:status = 3
	else
	    " A buffer with the filespec is already loaded, but it contains an
	    " existing file, not a generated file. As we don't want to jump to
	    " this existing file, try again with the next filename.
	    return ingo#buffer#generate#Create(a:dirspec, call(a:NextFilenameFuncref, [a:filename]), a:isFile, a:contentsCommand, a:windowOpenCommand, a:NextFilenameFuncref)
	endif
    else
	if getbufvar(l:bufnr, '&buftype') !=# ingo#buffer#generate#BufType(a:isFile)
	    " A window with the filespec is already visible, but its buffer
	    " contains an existing file, not a generated file. As we don't want
	    " to jump to this existing file, try again with the next filename.
	    return ingo#buffer#generate#Create(a:dirspec, call(a:NextFilenameFuncref, [a:filename]), a:isFile, a:contentsCommand, a:windowOpenCommand, a:NextFilenameFuncref)
	elseif l:winnr == l:currentWinNr
	    let l:status = 1
	else
	    execute l:winnr . 'wincmd w'
	    let l:status = 2
	endif
    endif

    call s:ChangeDir(a:dirspec)
    setlocal noreadonly
    silent %delete _
    " Note: ':silent' to suppress the "--No lines in buffer--" message.

    if ! empty(a:contentsCommand)
	if type(a:contentsCommand) == type([])
	    call setline(1, a:contentsCommand)
	    call cursor(1, 1)
	    call ingo#change#Set([1, 1], [line('$'), 1])
	else
	    execute a:contentsCommand
	    " ^ Keeps the existing line at the top of the buffer, if :1{cmd} is used.
	    " v Deletes it.
	    if empty(getline(1))
		let l:save_cursor = getpos('.')
		    silent 1delete _    " Note: ':silent' to suppress deletion message if ':set report=0'.
		call cursor(l:save_cursor[1] - 1, l:save_cursor[2])
	    endif
	endif

    endif

    return l:status
endfunction

" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
autoload/ingo/buffer/locate.vim	[[[1
187
" ingo/buffer/locate.vim: Functions to locate a buffer.
"
" DEPENDENCIES:
"
" Copyright: (C) 2016-2018 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
"
" REVISION	DATE		REMARKS
"   1.028.002	19-Nov-2016	Also prefer current / previous window in other
"				tab pages.
"   1.028.001	18-Nov-2016	file creation

function! s:FindBufferOnTabPage( isConsiderNearest, tabPageNr, bufNr )
    let l:bufferNumbers = tabpagebuflist(a:tabPageNr)

    if a:isConsiderNearest
	let l:currentIdx = tabpagewinnr(a:tabPageNr) - 1
	if l:bufferNumbers[l:currentIdx] == a:bufNr
	    return l:currentIdx + 1
	endif
	let l:previousIdx = tabpagewinnr(a:tabPageNr, '#') - 1
	if l:previousIdx >= 0 && l:bufferNumbers[l:previousIdx] == a:bufNr
	    return l:previousIdx + 1
	endif
    endif

    for l:i in range(len(l:bufferNumbers))
	if l:bufferNumbers[l:i] == a:bufNr
	    return l:i + 1
	endif
    endfor
    return 0
endfunction

function! ingo#buffer#locate#BufTabPageWinNr( bufNr )
"******************************************************************************
"* PURPOSE:
"   Locate the first window that contains a:bufNr, in this tab page (like
"   bufwinnr()), or in other tab pages. Can be used to emulate the behavior of
"   :sbuffer with 'switchbuf' containing "useopen,usetab".
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:bufNr                 Buffer number of the target buffer.
"* RETURN VALUES:
"   [tabpagenr, winnr] if the buffer is on a different tab page
"   [0, winnr] if the buffer is on the current tab page
"   [0, 0] if a:bufNr is not found in other windows
"******************************************************************************
    let l:winNr = bufwinnr(a:bufNr)
    if l:winNr > 0
	return [0, l:winNr]
    endif

    for l:tabPageNr in filter(range(1, tabpagenr('$')), 'v:val != ' . tabpagenr())
	let l:winNr = s:FindBufferOnTabPage(0, l:tabPageNr, a:bufNr)
	if l:winNr != 0
	    return [l:tabPageNr, l:winNr]
	endif
    endfor

    return [0, 0]
endfunction

function! ingo#buffer#locate#OtherWindowWithSameBuffer()
"******************************************************************************
"* PURPOSE:
"   Locate the first window that contains the same buffer as the current window,
"   but is not identical to the current window.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   None.
"* RETURN VALUES:
"   winnr or 0 if there's no windows split on this tab page that contains the
"   same buffer
"******************************************************************************
    let [l:currentWinNr, l:currentBufNr] = [winnr(), bufnr('')]

    for l:winNr in range(1, winnr('$'))
	if l:winNr != l:currentWinNr && winbufnr(l:winNr) == l:currentBufNr
	    return l:winNr
	endif
    endfor

    return 0
endfunction

function! ingo#buffer#locate#NearestWindow( isSearchOtherTabPages, bufNr )
"******************************************************************************
"* PURPOSE:
"   Locate the window closest to the current one that contains a:bufNr. Like
"   bufwinnr() with different precedences, and optionally looking into other tab
"   pages.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:isSearchOtherTabPages Flag whether windows in other tab pages should also
"			    be considered.
"   a:bufNr                 Buffer number of the target buffer.
"* RETURN VALUES:
"   [tabpagenr, winnr] if a:isSearchOtherTabPages and the buffer is on a
"	different tab page
"   [0, winnr] if the buffer is on the current tab page
"   [0, 0] if a:bufNr is not found in other windows
"******************************************************************************
    let l:lastWinNr = winnr('#')
    if l:lastWinNr != 0 && winbufnr(l:lastWinNr) == a:bufNr
	return [tabpagenr(), l:lastWinNr]
    endif

    let [l:currentWinNr, l:lastWinNr] = [winnr(), winnr('$')]
    let l:offset = 1
    while l:currentWinNr - l:offset > 0 || l:currentWinNr + l:offset <= l:lastWinNr
	if winbufnr(l:currentWinNr - l:offset) == a:bufNr
	    return [tabpagenr(), l:currentWinNr - l:offset]
	elseif winbufnr(l:currentWinNr + l:offset) == a:bufNr
	    return [tabpagenr(), l:currentWinNr + l:offset]
	endif
	let l:offset += 1
    endwhile

    if ! a:isSearchOtherTabPages
	return [0, 0]
    endif

    let [l:currentTabPageNr, l:lastTabPageNr] = [tabpagenr(), tabpagenr('$')]
    let l:offset = 1
    while l:currentTabPageNr - l:offset > 0 || l:currentTabPageNr + l:offset <= l:lastTabPageNr
	let l:winNr = s:FindBufferOnTabPage(1, l:currentTabPageNr - l:offset, a:bufNr)
	if l:winNr != 0
	    return [l:currentTabPageNr - l:offset, l:winNr]
	endif
	let l:winNr = s:FindBufferOnTabPage(1, l:currentTabPageNr + l:offset, a:bufNr)
	if l:winNr != 0
	    return [l:currentTabPageNr + l:offset, l:winNr]
	endif
	let l:offset += 1
    endwhile

    return [0, 0]
endfunction

function! ingo#buffer#locate#Window( strategy, isSearchOtherTabPages, bufNr )
"******************************************************************************
"* PURPOSE:
"   Locate a window that contains a:bufNr, with a:strategy to determine
"   precedences. Similar to bufwinnr() with configurable precedences, and
"   optionally looking into other tab pages.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:strategy              One of "first" or "nearest".
"   a:isSearchOtherTabPages Flag whether windows in other tab pages should also
"			    be considered.
"   a:bufNr                 Buffer number of the target buffer.
"* RETURN VALUES:
"   [tabpagenr, winnr] if a:isSearchOtherTabPages and the buffer is on a
"	different tab page
"   [0, winnr] if the buffer is on the current tab page
"   [0, 0] if a:bufNr is not found in other windows
"******************************************************************************
    if a:strategy ==# 'first'
	if a:isSearchOtherTabPages
	    return ingo#buffer#locate#BufTabPageWinNr(a:bufNr)
	else
	    let l:winNr = bufwinnr(a:bufNr)
	    return (l:winNr > 0 ? [0, l:winNr] : [0, 0])
	endif
    elseif a:strategy ==# 'nearest'
	return ingo#buffer#locate#NearestWindow(a:isSearchOtherTabPages, a:bufNr)
    else
	throw 'ASSERT: Unknown strategy ' . string(a:strategy)
    endif
endfunction

" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
autoload/ingo/buffer/scratch.vim	[[[1
79
" ingo/buffer/scratch.vim: Functions for creating scratch buffers.
"
" DEPENDENCIES:
"   - ingo/buffer/generate.vim autoload script
"
" Copyright: (C) 2009-2017 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>

function! ingo#buffer#scratch#NextFilename( filespec )
    return ingo#buffer#generate#NextBracketedFilename(a:filespec, 'Scratch')
endfunction
function! ingo#buffer#scratch#Create( scratchDirspec, scratchFilename, scratchIsFile, scratchCommand, windowOpenCommand )
"*******************************************************************************
"* PURPOSE:
"   Create (or re-use an existing) scratch buffer (i.e. doesn't correspond to a
"   file on disk, but can be saved as such).
"   To keep the scratch buffer (and create a new scratch buffer on the next
"   invocation), rename the current scratch buffer via ':file <newname>', or
"   make it a normal buffer via ':setl buftype='.
"
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   Creates or opens scratch buffer and loads it in a window (as specified by
"   a:windowOpenCommand) and activates that window.
"* INPUTS:
"   a:scratchDirspec	Local working directory for the scratch buffer
"			(important for :! scratch commands). Pass empty string
"			to maintain the current CWD as-is. Pass '.' to maintain
"			the CWD but also fix it via :lcd.
"			(Attention: ':set autochdir' will reset any CWD once the
"			current window is left!) Pass the getcwd() output if
"			maintaining the current CWD is important for
"			a:scratchCommand.
"   a:scratchFilename	The name for the scratch buffer, so it can be saved via
"			either :w! or :w <newname>.
"   a:scratchIsFile	Flag whether the scratch buffer should behave like a
"			file (i.e. adapt to changes in the global CWD), or not.
"			If false and a:scratchDirspec is empty, there will be
"			only one scratch buffer with the same a:scratchFilename,
"			regardless of the scratch buffer's directory path.
"   a:scratchCommand	Ex command(s) to populate the scratch buffer, e.g.
"			":1read myfile". Use :1read so that the first empty line
"			will be kept (it is deleted automatically), and there
"			will be no trailing empty line.
"			Pass empty string if you want to populate the scratch
"			buffer yourself.
"			Pass a List of lines to set the scratch buffer contents
"			directly to the lines.
"   a:windowOpenCommand	Ex command to open the scratch window, e.g. :vnew or
"			:topleft new.
"* RETURN VALUES:
"   Indicator whether the scratch buffer has been opened:
"   0	Failed to open scratch buffer.
"   1	Already in scratch buffer window.
"   2	Jumped to open scratch buffer window.
"   3	Loaded existing scratch buffer in new window.
"   4	Created scratch buffer in new window.
"   Note: To handle errors caused by a:scratchCommand, you need to put this
"   method call into a try..catch block and :close the scratch buffer when an
"   exception is thrown.
"*******************************************************************************
    let l:status = ingo#buffer#generate#Create(a:scratchDirspec, a:scratchFilename, a:scratchIsFile, a:scratchCommand, a:windowOpenCommand, function('ingo#buffer#scratch#NextFilename'))
    if l:status != 0
	call ingo#buffer#scratch#SetLocal(a:scratchIsFile, ! empty(a:scratchCommand))
    endif
    return l:status
endfunction
function! ingo#buffer#scratch#SetLocal( isFile, isInitialized )
    execute 'setlocal buftype=' . ingo#buffer#generate#BufType(a:isFile)
    setlocal bufhidden=wipe nobuflisted noswapfile
    if a:isInitialized
	setlocal readonly
    endif
endfunction

" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
autoload/ingo/buffer/temp.vim	[[[1
128
" ingo/buffer/temp.vim: Functions to execute stuff in a temp buffer.
"
" DEPENDENCIES:
"
" Copyright: (C) 2011-2017 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
"
" REVISION	DATE		REMARKS
"   1.028.006	16-Nov-2016	FIX: Correct delegation in
"				ingo#buffer#temp#Execute(); wrong recursive call
"				was used (after 1.027).
"				ENH: Add optional a:isSilent argument to
"				ingo#buffer#temp#Execute().
"   1.027.005	20-Aug-2016	Add ingo#buffer#temp#ExecuteWithText() and
"				ingo#buffer#temp#CallWithText() variants that
"				pre-initialize the buffer (a common use case).
"   1.025.004	29-Jul-2016	FIX: Temporarily reset 'switchbuf' in
"				ingo#buffer#temp#Execute(), to avoid that
"				"usetab" switched to another tab page.
"   1.023.003	07-Nov-2014	ENH: Add optional a:isReturnAsList flag to
"				ingo#buffer#temp#Execute() and
"				ingo#buffer#temp#Call().
"   1.013.002	05-Sep-2013	Name the temp buffer for
"				ingo#buffer#temp#Execute() and re-use previous
"				instances to avoid increasing the buffer numbers
"				and output of :ls!.
"   1.008.001	11-Jun-2013	file creation from ingobuffer.vim

function! s:SetBuffer( text )
    if empty(a:text) | return | endif
    call append(1, (type(a:text) == type([]) ? a:text : split(a:text, '\n', 1)))
    silent 1delete _
endfunction
let s:tempBufNr = 0
function! ingo#buffer#temp#Execute( ... )
"******************************************************************************
"* PURPOSE:
"   Invoke an Ex command in an empty temporary scratch buffer and return the
"   contents of the buffer after the execution.
"* ASSUMPTIONS / PRECONDITIONS:
"   - a:command should have no side effects to the buffer (other than changing
"     its contents), as it will be reused on subsequent invocations. If you
"     change any buffer-local option, also undo the change!
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:command	Ex command to be invoked.
"   a:isIgnoreOutput	Flag whether to skip capture of the scratch buffer
"			contents and just execute a:command for its side
"			effects.
"   a:isReturnAsList	Flag whether to return the contents as a List of lines.
"   a:isSilent          Flag whether a:command is executed silently (default:
"			true).
"* RETURN VALUES:
"   Contents of the buffer, by default as one newline-delimited string, with
"   a:isReturnAsList as a List, like getline() does.
"******************************************************************************
    return call('ingo#buffer#temp#ExecuteWithText', [''] + a:000)
endfunction
function! ingo#buffer#temp#ExecuteWithText( text, command, ... )
"******************************************************************************
"* PURPOSE:
"   Invoke an Ex command in a temporary scratch buffer filled with a:text and
"   return the contents of the buffer after the execution.
"* ASSUMPTIONS / PRECONDITIONS:
"   - a:command should have no side effects to the buffer (other than changing
"     its contents) that "survive" a buffer deletion, as the buffer will be
"     reused on subsequent invocations. Setting 'filetype', buffer-local
"     mappings and custom commands seem to be fine, but beware of buffer-local
"     autocmds!
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:text      List of lines, or String with newline-delimited lines.
"   a:command	Ex command to be invoked.
"   a:isIgnoreOutput	Flag whether to skip capture of the scratch buffer
"			contents and just execute a:command for its side
"			effects.
"   a:isReturnAsList	Flag whether to return the contents as a List of lines.
"   a:isSilent          Flag whether a:command is executed silently (default:
"			true).
"* RETURN VALUES:
"   Contents of the buffer, by default as one newline-delimited string, with
"   a:isReturnAsList as a List, like getline() does.
"******************************************************************************
    let l:isSilent = (a:0 >= 3 ? a:3 : 1)
    " It's hard to create a temp buffer in a safe way without side effects.
    " Switching the buffer can change the window view, may have a noticable
    " delay even with autocmds suppressed (maybe due to 'autochdir', or just a
    " sync in syntax highlighting), or even destroy the buffer ('bufhidden').
    " Splitting changes the window layout; there may not be room for another
    " window or tab. And autocmds may do all sorts of uncontrolled changes.
    let l:originalWindowLayout = winrestcmd()
	if s:tempBufNr && bufexists(s:tempBufNr)
	    let l:save_switchbuf = &switchbuf | set switchbuf= | " :sbuffer should always open a new split / must not apply "usetab" (so we can :close it without checking).
	    try
		noautocmd silent keepalt leftabove execute s:tempBufNr . 'sbuffer'
	    finally
		let &switchbuf = l:save_switchbuf
	    endtry
	    " The :bdelete got rid of the buffer contents and any buffer-local
	    " options; no need to clean the revived buffer.
	else
	    noautocmd silent keepalt leftabove 1new IngoLibraryTempBuffer
	    let s:tempBufNr = bufnr('')
	endif
    try
	call s:SetBuffer(a:text)
	execute (l:isSilent ? 'silent' : '') a:command
	if ! a:0 || ! a:1
	    let l:lines = getline(1, line('$'))
	    return (a:0 >= 2 && a:2 ? l:lines : join(l:lines, "\n"))
	endif
    finally
	noautocmd silent execute s:tempBufNr . 'bdelete!'
	silent! execute l:originalWindowLayout
    endtry
endfunction
function! ingo#buffer#temp#Call( Funcref, arguments, ... )
    return call('ingo#buffer#temp#ExecuteWithText', ['', 'call call(' . string(a:Funcref) . ',' . string(a:arguments) . ')'] + a:000)
endfunction
function! ingo#buffer#temp#CallWithText( text, Funcref, arguments, ... )
    return call('ingo#buffer#temp#ExecuteWithText', [a:text, 'call call(' . string(a:Funcref) . ',' . string(a:arguments) . ')'] + a:000)
endfunction

" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
autoload/ingo/buffer/temprange.vim	[[[1
103
" ingo/buffer/temprange.vim: Functions to execute stuff in a temp area in the same buffer.
"
" DEPENDENCIES:
"   - ingo/undo.vim autoload script
"
" Copyright: (C) 2014 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
"
" REVISION	DATE		REMARKS
"   1.021.005	17-Jun-2014	Simplify ingo#buffer#temprange#Execute() by
"				using changenr(). Keep using
"				ingo#undo#GetChangeNumber() because we need to
"				create a new no-op change when there was a
"				previous :undo.
"   1.019.003	25-Apr-2014	Factor out ingo#undo#GetChangeNumber().
"   1.018.002	12-Apr-2014	Add optional a:undoCnt argument.
"	001	09-Apr-2014	file creation from visualrepeat.vim

function! ingo#buffer#temprange#Execute( lines, command, ... )
"******************************************************************************
"* PURPOSE:
"   Invoke an Ex command on temporarily added lines in the current buffer.
"   Some transformations need to operate in the context of the current buffer
"   (so that the buffer settings apply), but should not directly modify the
"   buffer. This functions temporarily inserts the lines at the end of the
"   buffer, applies the command from the beginning of those lines, then removes
"   the temporary range and returns it.
"
"* ASSUMPTIONS / PRECONDITIONS:
"   Current buffer is modifiable.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:lines     List of lines (or String of a single line) to be temporarily
"		processed by a:command.
"   a:command	Ex command to be invoked. The cursor will be positioned on the
"		first column of the first line of a:lines. The command should
"		ensure that no lines above that line are modified! In
"		particular, the number of existing lines must not be changed (or
"		the line capture will return the wrong lines).
"   a:undoCnt   Optional number of changes that a:command will do. If this is a
"		fixed number and you know it, passing this is slightly more
"		efficient.
"* RETURN VALUES:
"   a:lines, as modified by a:command.
"******************************************************************************
    " Save the view; the command execution / :delete of the temporary
    " range later modifies the cursor position.
    let l:save_view = winsaveview()
    let l:finalLnum = line('$')
    if ! a:0
	let l:undoChangeNumber = ingo#undo#GetChangeNumber()
    endif

    let l:tempRange = (l:finalLnum + 1) . ',$'
    call append(l:finalLnum, a:lines)

    " The cursor is set to the first column of the first temp line.
    call cursor(l:finalLnum + 1, 1)
    try
	execute a:command
	let l:result = getline(l:finalLnum + 1, '$')
	return l:result
    finally
	try
	    " Using :undo to roll back the append and command is safer, because
	    " any potential modification outside the temporary range is also
	    " eliminated. And this doesn't pollute the undo history. Only
	    " explicitly delete the temporary range as a fallback.
	    if a:0
		for l:i in range(a:1)
		    silent undo
		endfor
	    else
		if l:undoChangeNumber < 0
		    throw 'CannotUndo'
		endif
		" XXX: Inside a function invocation, no separate change is created.
		if changenr() > l:undoChangeNumber
		    silent execute 'undo' l:undoChangeNumber
"****D else | echomsg '**** no new undo change number'
		endif
	    endif

	    if line('$') > l:finalLnum
		" Fallback in case the undo somehow failed.
		throw 'CannotUndo'
	    endif
	catch /^CannotUndo$\|^Vim\%((\a\+)\)\=:E/
	    silent! execute l:tempRange . 'delete _'
"****D echomsg '**** falling back to delete'
	endtry

	call winrestview(l:save_view)
    endtry
endfunction
function! ingo#buffer#temprange#Call( lines, Funcref, arguments, ... )
    return call('ingo#buffer#temprange#Execute', [a:lines, 'call call(' . string(a:Funcref) . ',' . string(a:arguments) . ')'] + a:000)
endfunction

" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
autoload/ingo/buffer/visible.vim	[[[1
87
" ingo/buffer/visible.vim: Functions to execute stuff in a visible buffer.
"
" DEPENDENCIES:
"
" Copyright: (C) 2011-2017 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
"
" REVISION	DATE		REMARKS
"   1.025.004	29-Jul-2016	FIX: Temporarily reset 'switchbuf' in
"				ingo#buffer#visible#Execute(), to avoid that
"				"usetab" switched to another tab page.
"   1.024.003	17-Mar-2015	ingo#buffer#visible#Execute(): Restore the
"				window layout when the buffer is visible but in
"				a window with 0 height / width. And restore the
"				previous window when the buffer isn't visible
"				yet. Add a check that the command hasn't
"				switched to another window (and go back if true)
"				before closing the split window.
"   1.023.002	07-Feb-2015	Use :close! in ingo#buffer#visible#Execute() to
"				handle modified buffers when :set nohidden, too.
"				ENH: Keep previous (last accessed) window on
"				ingo#buffer#visible#Execute().
"   1.008.001	11-Jun-2013	file creation from ingobuffer.vim

function! ingo#buffer#visible#Execute( bufnr, command )
"******************************************************************************
"* PURPOSE:
"   Invoke an Ex command in a visible buffer.
"   Some commands (e.g. :update) operate in the context of the current buffer
"   and must therefore be visible in a window to be invoked. This function
"   ensures that the passed command is executed in the context of the passed
"   buffer number.
"* SEE ALSO:
"   To execute an Action in all buffers (temporarily made visible), use
"   ingo#actions#iterations#BufDo().
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   The current window and buffer loaded into it remain the same.
"* INPUTS:
"   a:bufnr Buffer number of an existing buffer where the function should be
"   executed in.
"   a:command	Ex command to be invoked.
"* RETURN VALUES:
"   None.
"******************************************************************************
    let l:winnr = bufwinnr(a:bufnr)
    let l:originalWindowLayout = winrestcmd()
    let l:currentWinNr = winnr()
    let l:previousWinNr = winnr('#') ? winnr('#') : 1

    try
	if l:winnr == -1
	    " The buffer is hidden. Make it visible to execute the passed function.
	    " Use a temporary split window as ingo#buffer#temp#Execute() does, for
	    " all the reasons outlined there.
	    let l:save_switchbuf = &switchbuf | set switchbuf= | " :sbuffer should always open a new split / must not apply "usetab" (so we can :close it without checking).
		execute 'noautocmd silent keepalt leftabove sbuffer' a:bufnr
	    let &switchbuf = l:save_switchbuf | unlet l:save_switchbuf
	    let l:newWinNr = winnr()
	    try
		execute a:command
	    finally
		if winnr() != l:newWinNr
		    noautocmd silent execute l:newWinNr . 'wincmd w'
		endif
		noautocmd silent close!
	    endtry
	else
	    " The buffer is visible in at least one window on this tab page.
	    execute l:winnr . 'wincmd w'
	    execute a:command
	endif
    finally
	if exists('l:save_switchbuf') | let &switchbuf = l:save_switchbuf | endif
	silent execute l:previousWinNr . 'wincmd w'
	silent execute l:currentWinNr . 'wincmd w'
	silent! execute l:originalWindowLayout
    endtry
endfunction
function! ingo#buffer#visible#Call( bufnr, Funcref, arguments )
    return ingo#buffer#visible#Execute(a:bufnr, 'return call(' . string(a:Funcref) . ',' . string(a:arguments) . ')')
endfunction

" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
autoload/ingo/change.vim	[[[1
152
" ingo/change.vim: Functions around the last changed text.
"
" DEPENDENCIES:
"   - ingo/cursor/move.vim autoload script
"   - ingo/pos.vim autoload script
"   - ingo/str/split.vim autoload script
"   - ingo/text.vim autoload script
"   - ingo/undo.vim autoload script
"
" Copyright: (C) 2018-2019 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>

function! ingo#change#IsLastAnInsertion( ... )
    let l:lastChangedText = (a:0 ? a:1 : ingo#text#Get(getpos("'[")[1:2], getpos("']")[1:2], 1))
    return (l:lastChangedText ==# @.)
endfunction

function! ingo#change#Get()
"******************************************************************************
"* PURPOSE:
"   Get the last inserted / changed text (between marks '[,']).
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   None.
"* RETURN VALUES:
"   Last changed text, or empty string if there was no change yet or the last
"   change was a deletion.
"******************************************************************************
    let [l:startPos, l:endPos] = [getpos("'[")[1:2], getpos("']")[1:2]]

    " If the change was an insertion, the end of change mark is set _after_ the
    " last inserted character. For other changes (e.g. gU), the end of change
    " mark is _on_ the last changed character. We need to compare with register
    " . contents.
    let l:lastInsertedText = ingo#text#Get(l:startPos, l:endPos, 1)
    if ingo#change#IsLastAnInsertion(l:lastInsertedText)
	return l:lastInsertedText
    endif

    let l:lastChangedText = ingo#text#Get(l:startPos, l:endPos, 0)
    return l:lastChangedText
endfunction

function! ingo#change#IsCursorOnPreviousChange()
"******************************************************************************
"* PURPOSE:
"   Test whether the cursor is inside the area marked by the '[,'] marks.
"   (Depending on the type of change, it can be at the beginning, end, or
"   shortly before the end.)
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   None.
"* RETURN VALUES:
"   1 if cursor is on previous change, 0 if not.
"******************************************************************************
    let [l:currentPos, l:startPos, l:endPos] = [getpos('.')[1:2], getpos("'[")[1:2], getpos("']")[1:2]]
    if ! ingo#pos#IsInside(l:currentPos, l:startPos, l:endPos)
	return 0
    endif

    if l:currentPos == l:endPos && ingo#change#IsLastAnInsertion()
	return 0    " Special case: After an insertion, the change mark is positioned one after the last inserted character.
    endif

    return 1
endfunction

function! ingo#change#JumpAfterEndOfChange()
    normal! g`]
    if ! ingo#change#IsLastAnInsertion()
	call ingo#cursor#move#Right()
    endif
endfunction

function! ingo#change#GetOverwrittenText()
"******************************************************************************
"* PURPOSE:
"   Get the text that was overwritten by the last change.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   None.
"* RETURN VALUES:
"   Overwritten text, or empty string.
"******************************************************************************
    let l:save_view = winsaveview()
    let [l:startPos, l:endPos] = [getpos("'["), getpos("']")]
    let [l:startLnum, l:endLnum] = [l:startPos[1], l:endPos[1]]
    let l:lastLnum = line('$')

    let l:textBeforeChange = ingo#text#Get([l:startLnum, 1], l:startPos[1:2], 1)
    let l:textAfterChange = ingo#text#Get(l:endPos[1:2], [l:endLnum, len(getline(l:endLnum))], 0)

    if ! ingo#change#IsLastAnInsertion() | let l:textAfterChange = matchstr(l:textAfterChange, '^.\zs.*') | endif
"****D echomsg string(l:textBeforeChange) string(l:textAfterChange)

    let l:undoChangeNumber = ingo#undo#GetChangeNumber()
    if l:undoChangeNumber < 0 | return '' | endif " Without undo, the overwritten text cannot be determined.
    try
	silent undo

	let l:changeOffset = l:lastLnum - line('$')
	let l:changedArea = join(getline(l:startLnum, l:endLnum - l:changeOffset), "\n")

	let l:startOfOverwritten = ingo#str#split#AtPrefix(l:changedArea, l:textBeforeChange)
	let l:overwritten = ingo#str#split#AtSuffix(l:startOfOverwritten, l:textAfterChange)

	return l:overwritten
    finally
	silent execute 'undo' l:undoChangeNumber

	" The :undo clobbered the change marks; restore them.
	call ingo#change#Set(l:startPos, l:endPos)

	" The :undo also affected the cursor position.
	call winrestview(l:save_view)
    endtry
endfunction

function! ingo#change#Set( startPos, endPos ) abort
"******************************************************************************
"* PURPOSE:
"   Sets the change marks to the passed area.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   Sets the change marks.
"* INPUTS:
"   a:startPos  [lnum, col] or [0, lnum, col, 0] of the start ('[) of the last
"               change.
"   a:endPos    [lnum, col] or [0, lnum, col, 0] of the end (']) of the last
"               change.
"* RETURN VALUES:
"   1 if successful, 0 if one position could not be set.
"******************************************************************************
    let l:result = 0
    let l:result += setpos("'[", ingo#pos#Make4(a:startPos))
    let l:result += setpos("']", ingo#pos#Make4(a:endPos))
    return (l:result == 0)
endfunction

" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
autoload/ingo/cmdargs.vim	[[[1
90
" ingo/cmdargs.vim: Functions for parsing of command arguments.
"
" DEPENDENCIES:
"
" Copyright: (C) 2012-2015 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
"
" REVISION	DATE		REMARKS
"   1.024.008	22-Apr-2015	FIX: ingo#cmdargs#GetStringExpr(): Escape
"				(unescaped) double quotes when the argument
"				contains backslashes; else, the expansion of \x
"				will silently fail.
"				Add ingo#cmdargs#GetUnescapedExpr(); when
"				there's no need for empty expressions, the
"				removal of the (single / double) quotes may be
"				unexpected.
"   1.007.007	01-Jun-2013	Move functions from ingo/cmdargs.vim to
"				ingo/cmdargs/pattern.vim and
"				ingo/cmdargs/substitute.vim.
"   1.006.006	29-May-2013	Again change
"				ingo#cmdargs#ParseSubstituteArgument() interface
"				to parse the :substitute [flags] [count] by
"				default.
"   1.006.005	28-May-2013	BUG: ingo#cmdargs#ParseSubstituteArgument()
"				mistakenly returns a:defaultFlags when full
"				/pat/repl/ or a literal pat is passed. Only
"				return a:defaultFlags when the passed
"				a:arguments is really empty.
"				CHG: Redesign
"				ingo#cmdargs#ParseSubstituteArgument() interface
"				to the existing use cases. a:defaultReplacement
"				should only be used when a:arguments is really
"				empty, too. Introduce an optional options
"				Dictionary and preset replacement / flags
"				defaults of "~" and "&" resp. for when
"				a:arguments is really empty, which makes sense
"				for use with :substitute. Allow submatches for
"				a:flagsExpr via a:options.flagsMatchCount, to
"				avoid further parsing in the client.
"				ENH: Also parse lone {flags} (if a:flagsExpr is
"				given) by default, and allow to turn this off
"				via a:options.isAllowLoneFlags.
"				ENH: Allow to pass a:options.emptyPattern, too.
"   1.001.004	21-Feb-2013	Move to ingo-library.
"	003	29-Jan-2013	Add ingocmdargs#ParseSubstituteArgument() for
"				use in PatternsOnText/Except.vim and
"				ExtractMatchesToReg.vim.
"				Change ingocmdargs#UnescapePatternArgument() to
"				take the result of
"				ingocmdargs#ParsePatternArgument() instead of
"				invoking that function itself. And make it
"				handle an empty separator.
"	002	21-Jan-2013	Add ingocmdargs#ParsePatternArgument() and
"				ingocmdargs#UnescapePatternArgument() from
"				PatternsOnText.vim.
"	001	25-Nov-2012	file creation from CaptureClipboard.vim.

function! ingo#cmdargs#GetUnescapedExpr( argument )
    try
	if a:argument =~# '\\'
	    " The argument contains escape characters, evaluate them.
	    execute 'let l:expr = "' . substitute(a:argument, '\%(\%(^\|[^\\]\)\%(\\\\\)*\\\)\@<!"', '\\"', 'g') . '"'
	else
	    let l:expr = a:argument
	endif
    catch /^Vim\%((\a\+)\)\=:/
	let l:expr = a:argument
    endtry
    return l:expr
endfunction
function! ingo#cmdargs#GetStringExpr( argument )
    try
	if a:argument =~# '^\([''"]\).*\1$'
	    " The argument is quoted, evaluate it.
	    execute 'let l:expr =' a:argument
	elseif a:argument =~# '\\'
	    " The argument contains escape characters, evaluate them.
	    execute 'let l:expr = "' . substitute(a:argument, '\%(\%(^\|[^\\]\)\%(\\\\\)*\\\)\@<!"', '\\"', 'g') . '"'
	else
	    let l:expr = a:argument
	endif
    catch /^Vim\%((\a\+)\)\=:/
	let l:expr = a:argument
    endtry
    return l:expr
endfunction

" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
autoload/ingo/cmdargs/command.vim	[[[1
130
" ingo/cmdargs/command.vim: Functions for parsing of Ex commands.
"
" DEPENDENCIES:
"   - ingo/cmdargs/range.vim autoload script
"
" Copyright: (C) 2012-2019 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
"
" REVISION	DATE		REMARKS
"   1.010.006	08-Jul-2013	Move into ingo-library.
"   	005	14-Jun-2013	Minor: Make matchlist() robust against
"				'ignorecase'.
"	004	31-May-2013	Add ingoexcommands#ParseRange().
"				FIX: :* is also a valid range: shortcut for
"				'<,'>.
"	003	30-Dec-2012	Add missing ":help" and ":command" to
"				s:builtInCommandCommands.
"	002	19-Jun-2012	Return all parsed fragments in
"				ingoexcommands#ParseCommand() so that the
"				command can be re-assembled again.
"				Allow parsing of whitespace-separated arguments,
"				too, by passing in an optional regexp for them.
"	001	15-Jun-2012	file creation
let s:save_cpo = &cpo
set cpo&vim

" Commands are usually <Space>-delimited, but can also be directly followed by
" an argument (like :substitute, :ijump, etc.). According to :help E146, the
" delimiter can be almost any single-byte character.
" Note: We use branches, not a (better performing?) single /[...]/ atom, because
" of the uncertainties of escaping these characters.
function! s:IsCmdDelimiter(char)
    " Note: <Space> must not be included in the set of delimiters; otherwise, the
    " detection of commands that take other commands
    " (ingo#cmdargs#commandcommands#GetExpr()) won't work any more (because the
    " combination of "command<Space>alias" is matched as commandUnderCursor).
    " There's no need to include <Space> anyway; since this is our mapped trigger
    " key, any alias expansion should already have happened earlier.
    return (len(a:char) == 1 && a:char =~# '\p' && a:char !~# '[ [:alpha:][:digit:]\\"|]')
endfunction
let s:cmdDelimiterExpr = '\V\C\%(' .
\ join(
\   filter(
\     map(
\       range(0, 255),
\       'nr2char(v:val)'
\     ),
\     's:IsCmdDelimiter(v:val)'
\   ),
\   '\|'
\ ). '\)\m'
function! ingo#cmdargs#command#DelimiterExpr()
    return s:cmdDelimiterExpr
endfunction

function! ingo#cmdargs#command#Parse( commandLine, ... )
"******************************************************************************
"* PURPOSE:
"   Parse a:commandLine into Ex command fragments. When the command line
"   contains multiple commands, the last one is parsed. Arguments that directly
"   follow the command (e.g. ":%s/foo/bar/") are handled, but no
"   whitespace-separated arguments must follow.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:commandLine   Ex command line containing a command.
"   a:argumentExpr  Regular expression for matching arguments; probably should
"                   be anchored to the end via /$/. When not given, no
"                   whitespace-separated arguments must follow the command for
"                   the parsing to succeed; it will only parse no-argument
"                   commands then!
"                   To parse |:bar| commands that see | as their argument, use
"                   '.*$'
"                   To parse any regular commands (without -bar), use a pattern
"                   that excludes the | command separator, e.g.
"                   '\%([^|]\|\\|\)*$'. You can also supply the special argument
"                   value "*" for that.
"   a:directArgumentExpr    Regular expression for matching direct arguments.
"			    Defaults to parsing of arbitrary direct arguments.
"* RETURN VALUES:
"   List of [fullCommandUnderCursor, combiner, range, commandCommands, commandName, commandBang, commandDirectArgs, commandArgs]
"   where:
"	fullCommandUnderCursor  The entire command, potentially starting with
"				"|" when there's a command chain.
"	combiner    Empty, white space, or something with "|" that joins the
"		    command to the previous one.
"	commandCommands Empty or any prepended commands take another Ex command
"			as an argument.
"	range       The single or double line address(es), e.g. "42,'b".
"	commandName Name of the command.
"	bang        Optional "!" following the command.
"	commandDirectArgs   Any arguments directly following the command, e.g.
"			    "/foo/b a r/".
"	commandArgs         Any normal, whitespace-delimited arguments,
"			    including the leading delimiter. Will be empty when
"			    a:argumentExpr is not given or when
"			    commandDirectArgs is not empty.
"   Or: [] if no match.
"
"   To reassemble, you can concatenate [1:7] together; originally, that's the
"   same as [0].
"   To get the cut-off previous command(s), you can use >
"	strpart(a:commandLine, 0, len(a:commandLine) - len(l:parse[0]))
"   <
"******************************************************************************
    let l:commandPattern =
    \	'\(' . ingo#cmdargs#commandcommands#GetExpr() . '\)\?' .
    \	'\(' . ingo#cmdargs#range#RangeExpr() . '\)\s*' .
    \	'\(\h\w*\)\(!\?\)\(' . ingo#cmdargs#command#DelimiterExpr() . (a:0 > 1 ? a:2 : '.*') . '\)\?' .
    \   '\(' . (a:0 && ! empty(a:1) ? '$\|\s\+' . (a:1 ==# '*' ? '\%([^|]\|\\|\)*$' : a:1) : '$') . '\)'

    for l:anchor in ['\s*\\\@<!|\s*', '^\s*']
	let l:parse = matchlist(a:commandLine,
	\   printf('\C\(%s\)', l:anchor) . l:commandPattern
	\)
	if ! empty(l:parse)
	    break
	endif
    endfor

    return l:parse[0:7]
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo
" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
autoload/ingo/cmdargs/commandcommands.vim	[[[1
47
" ingo/cmdargs/commandcommands.vim: Functions for parsing of Ex commands that take other Ex commands.
"
" DEPENDENCIES:
"
" Copyright: (C) 2012-2013 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
"
" REVISION	DATE		REMARKS
"   1.010.006	08-Jul-2013	Move into ingo-library.
"   	005	14-Jun-2013	Minor: Make matchlist() robust against
"				'ignorecase'.
"	004	31-May-2013	Add ingoexcommands#ParseRange().
"				FIX: :* is also a valid range: shortcut for
"				'<,'>.
"	003	30-Dec-2012	Add missing ":help" and ":command" to
"				s:builtInCommandCommands.
"	002	19-Jun-2012	Return all parsed fragments in
"				ingoexcommands#ParseCommand() so that the
"				command can be re-assembled again.
"				Allow parsing of whitespace-separated arguments,
"				too, by passing in an optional regexp for them.
"	001	15-Jun-2012	file creation
let s:save_cpo = &cpo
set cpo&vim

" These built-in commands take an Ex command as an argument.
" You can add your own custom commands to the list via g:commandCommands.
let s:builtInCommandCommands = 'h\%[elp] com\%[mand] verb\%[ose] debug sil\%[ent] redi\%[r] vert\%[ical] lefta\%[bove] abo\%[veleft] rightb\%[elow] bel\%[owright] to\%[pleft] bo\%[tright] argdo bufdo tab tabd\%[o] windo'
let s:builtInCommandCommandsExpr = '\%(' .
\   join(
\       map(
\           split(s:builtInCommandCommands) + (exists('g:commandCommands') ? split(g:commandCommands) : []),
\           'v:val . ''!\?\s\+'''
\       ),
\       '\|'
\   ) .
\   '\)\+'

function! ingo#cmdargs#commandcommands#GetExpr()
    return s:builtInCommandCommandsExpr
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo
" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
autoload/ingo/cmdargs/file.vim	[[[1
188
" ingo/cmdargs/file.vim: Functions for handling file arguments to commands.
"
" DEPENDENCIES:
"
" Copyright: (C) 2012-2018 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>

let s:fileOptionsExpr = '++\%(ff\|fileformat\|enc\|encoding\|bin\|binary\|nobin\|nobinary\|bad\|edit\)\%(=\S*\)\?'

function! ingo#cmdargs#file#FilterEscapedFileOptionsAndCommands( arguments )
"*******************************************************************************
"* PURPOSE:
"   Strip off the optional ++opt +cmd file options and commands.
"
"   (In Vim 7.2,) options and commands can only appear at the beginning of the
"   file list; there can be multiple options, but only one command. They are
"   only applied to the first (opened) file, not to any other passed file.
"
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:arguments Original file argument(s), derived e.g. via <q-args>.
"		If you need unescaped file arguments later anyway, use
"		ingo#cmdargs#file#FilterFileOptionsAndCommands() instead.
"* RETURN VALUES:
"   [fileOptionsAndCommands, filename]	First element is a string containing all
"   removed file options and commands. This includes any trailing whitespace, so
"   it can be directly concatenated with filename, the second argument.
"*******************************************************************************
    return matchlist(a:arguments,
    \   '\C^\(' .
    \       '\%(' . s:fileOptionsExpr . '\s\+\)*' .
    \	    '\%(+.\{-}\%(\%(^\|[^\\]\)\%(\\\\\)*\\\)\@<! \s*\)\?' .
    \   '\)\(.*\)$'
    \)[1:2]
endfunction


function! ingo#cmdargs#file#FileOptionsAndCommandsToEscapedExCommandLine( fileOptionsAndCommands )
    return join(map(copy(a:fileOptionsAndCommands), "escape(v:val, '\\ ')"))
endfunction
function! ingo#cmdargs#file#FilterFileOptions( fileglobs )
"*******************************************************************************
"* PURPOSE:
"   Strip off the optional ++opt file options that can be given to :write and
"   :saveas.
"
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   (Potentially) removes options from a:fileglobs.
"* INPUTS:
"   a:fileglobs Raw list of file patterns. To get this from a <q-args> string,
"		use ingo#cmdargs#file#SplitAndUnescape().
"* RETURN VALUES:
"   [a:fileglobs, fileOptions]	First element is the passed list, with any file
"   options removed. Second element is a List containing all removed file
"   options.
"   Note: If the file arguments were obtained through
"   ingo#cmdargs#file#SplitAndUnescape(), these must be re-escaped for use
"   in another Ex command via
"   ingo#cmdargs#file#FileOptionsAndCommandsToEscapedExCommandLine(). Or just
"   use ingo#cmdargs#file#FilterFileOptionsToEscaped().
"*******************************************************************************
    return [a:fileglobs, ingo#list#split#RemoveFromStartWhilePredicate(a:fileglobs, 'v:val =~# ' . string('^' . s:fileOptionsExpr . '$'))]
endfunction
function! ingo#cmdargs#file#FilterFileOptionsToEscaped( fileglobs )
"*******************************************************************************
"* PURPOSE:
"   Strip off the optional ++opt file options that can be given to :write and
"   :saveas.
"
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   (Potentially) removes options from a:fileglobs.
"* INPUTS:
"   a:fileglobs Raw list of file patterns. To get this from a <q-args> string,
"		use ingo#cmdargs#file#SplitAndUnescape().
"* RETURN VALUES:
"   [a:fileglobs, exFileOptions]    First element is the passed list, with any file
"   options removed. Second element is a String with all removed file
"   options joined together and escaped for use in an Ex command.
"*******************************************************************************
    let [l:fileglobs, l:fileOptions] = ingo#cmdargs#file#FilterFileOptions(a:fileglobs)
    return [l:fileglobs, (empty(l:fileOptions) ? '' : ingo#cmdargs#file#FileOptionsAndCommandsToEscapedExCommandLine(l:fileOptions))]
endfunction
function! ingo#cmdargs#file#FilterFileOptionsAndCommands( fileglobs )
"*******************************************************************************
"* PURPOSE:
"   Strip off the optional ++opt +cmd file options and command that can be given
"   to :edit, :split, etc.
"
"   (In Vim 7.2,) options and commands can only appear at the beginning of the
"   file list; there can be multiple options, followed by only one command. They
"   are only applied to the first (opened) file, not to any other passed file.
"
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   (Potentially) removes options and commands from a:fileglobs.
"* INPUTS:
"   a:fileglobs Raw list of file patterns. To get this from a <q-args> string,
"		use ingo#cmdargs#file#SplitAndUnescape(). Or alternatively
"		use ingo#cmdargs#file#FilterEscapedFileOptionsAndCommands().
"* RETURN VALUES:
"   [a:fileglobs, fileOptionsAndCommands]	First element is the passed
"   list, with any file options and commands removed. Second element is a List
"   containing all removed file options and commands.
"   Note: If the file arguments were obtained through
"   ingo#cmdargs#file#SplitAndUnescape(), these must be re-escaped for use
"   in another Ex command via
"   ingo#cmdargs#file#FileOptionsAndCommandsToEscapedExCommandLine(). Or just
"   use ingo#cmdargs#file#FilterFileOptionsAndCommandsToEscaped().
"*******************************************************************************
    let [l:fileglobs, l:fileOptionsAndCommands] = ingo#cmdargs#file#FilterFileOptions(a:fileglobs)

    if get(l:fileglobs, 0, '') =~# '^++\@!'
	call add(l:fileOptionsAndCommands, remove(l:fileglobs, 0))
    endif

    return [l:fileglobs, l:fileOptionsAndCommands]
endfunction
function! ingo#cmdargs#file#FilterFileOptionsAndCommandsToEscaped( fileglobs )
"*******************************************************************************
"* PURPOSE:
"   Strip off the optional ++opt +cmd file options and command that can be given
"   to :edit, :split, etc.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   (Potentially) removes options and commands from a:fileglobs.
"* INPUTS:
"   a:fileglobs Raw list of file patterns. To get this from a <q-args> string,
"		use ingo#cmdargs#file#SplitAndUnescape(). Or alternatively
"		use ingo#cmdargs#file#FilterEscapedFileOptionsAndCommands().
"* RETURN VALUES:
"   [a:fileglobs, exFileOptionsAndCommands]	First element is the passed
"   list, with any file options and commands removed. Second element is a String with all removed file
"   options joined together and escaped for use in an Ex command.
"*******************************************************************************
    let [l:fileglobs, l:fileOptionsAndCommands] = ingo#cmdargs#file#FilterFileOptionsAndCommands(a:fileglobs)
    return [l:fileglobs, (empty(l:fileOptionsAndCommands) ? '' : ingo#cmdargs#file#FileOptionsAndCommandsToEscapedExCommandLine(l:fileOptionsAndCommands))]
endfunction


function! ingo#cmdargs#file#Unescape( fileArgument )
"******************************************************************************
"* PURPOSE:
"   Unescape spaces in a:fileArgument for use with glob().
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:fileArgument  Single raw filespec passed from :command -nargs=+
"		    -complete=file ... <q-args>
"* RETURN VALUES:
"   Fileglob with unescaped spaces.
"******************************************************************************
    return substitute(a:fileArgument, '\%(\%(^\|[^\\]\)\%(\\\\\)*\\\)\@<!\\ ', ' ', 'g')
endfunction
function! ingo#cmdargs#file#SplitAndUnescape( fileArguments )
"******************************************************************************
"* PURPOSE:
"   Split <q-args> filespec arguments into a list of elements, which can then be
"   used with glob().
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:fileArguments Raw filespecs passed from :command -nargs=+ -complete=file
"		    ... <q-args>
"* RETURN VALUES:
"   List of fileglobs with unescaped spaces.
"   Note: If the file arguments can start with optional ++opt +cmd file options
"   and commands, these can be extracted via
"   ingo#cmdargs#file#FilterFileOptionsAndCommands().
"******************************************************************************
    return map(split(a:fileArguments, '\%(\%(^\|[^\\]\)\%(\\\\\)*\\\)\@<!\s\+'), 'ingo#cmdargs#file#Unescape(v:val)')
endfunction

" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
autoload/ingo/cmdargs/glob.vim	[[[1
153
" ingo/cmdargs/glob.vim: Functions for expanding file glob arguments.
"
" DEPENDENCIES:
"   - ingo/cmdargs/file.vim autoload script
"   - ingo/compat.vim autoload script
"   - ingo/os.vim autoload script
"
" Copyright: (C) 2012-2016 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
"
" REVISION	DATE		REMARKS
"   1.025.004	08-Jul-2016	ENH: Add second optional flag
"				a:isKeepDirectories to
"				ingo#cmdargs#glob#Expand() /
"				ingo#cmdargs#glob#ExpandSingle().
"   1.022.003	22-Sep-2014	Use ingo#compat#glob().
"   1.013.002	13-Sep-2013	Use operating system detection functions from
"				ingo/os.vim.
"   1.007.001	01-Jun-2013	file creation from ingofileargs.vim

function! ingo#cmdargs#glob#ExpandSingle( fileglob, ... )
"******************************************************************************
"* PURPOSE:
"   Expand any file wildcards in a:fileglob to a list of normal filespecs.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:fileglob  File glob (already processed by
"		ingo#cmdargs#file#Unescape()).
"   a:isKeepNoMatch Optional flag that lets globs that have no matches be kept
"		    and returned as-is, instead of being removed. Set this when
"		    you want to support creating new files.
"   a:isKeepDirectories Optional flag that keeps directories in the list.
"* RETURN VALUES:
"   List of normal filespecs; globs have been expanded. To consume this in
"   another Vim command, use:
"	join(map(l:filespecs, 'fnameescape(v:val)))
"******************************************************************************
    " XXX: Special Vim variables are expanded by -complete=file, but (in Vim
    " 7.3), escaped special names are _not_ correctly re-escaped, and a
    " following glob() or expand() will mistakenly expand them. Because of the
    " auto-expansion, any unescaped special Vim variable that gets here is in
    " fact a literal special filename. We don't even need to re-escape and
    " glob() it, just return it verbatim.
    if a:fileglob =~# '^\%(%\|#\d\?\)\%(:\a\)*$\|^<\%(cfile\|cword\|cWORD\)>\%(:\a\)*$'
	return [a:fileglob]
    else
	" Filter out directories; we're usually only interested in files.
	let l:specs = (a:0 && a:1 ? split(expand(a:fileglob), '\n') : ingo#compat#glob(a:fileglob, 0, 1))
	return (a:0 >= 2 && a:2 ? l:specs : filter(l:specs, '! isdirectory(v:val)'))
    endif
endfunction
function! ingo#cmdargs#glob#Expand( fileglobs, ... )
"******************************************************************************
"* PURPOSE:
"   Expand any file wildcards in a:fileglobs to a list of normal filespecs.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:fileglobs Either space-separated arguments string (from a :command
"		-complete=file ... <q-args> custom command), or a list of
"		fileglobs (already processed by
"		ingo#cmdargs#file#Unescape()).
"   a:isKeepNoMatch Optional flag that lets globs that have no matches be kept
"		    and returned as-is, instead of being removed. Set this when
"		    you want to support creating new files.
"   a:isKeepDirectories Optional flag that keeps directories in the list.
"* RETURN VALUES:
"   List of filespecs; globs have been expanded. To consume this in another Vim
"   command, use:
"	join(map(l:filespecs, 'fnameescape(v:val)))
"******************************************************************************
    let l:fileglobs = (type(a:fileglobs) == type([]) ? a:fileglobs : ingo#cmdargs#file#SplitAndUnescape(a:fileglobs))

    let l:filespecs = []
    for l:fileglob in l:fileglobs
	call extend(l:filespecs, call('ingo#cmdargs#glob#ExpandSingle', [l:fileglob] + a:000))
    endfor
    return l:filespecs
endfunction

function! s:ContainsNoWildcards( fileglob )
    " Note: This is only an empirical approximation; it is not perfect.
    if ingo#os#IsWinOrDos()
	return a:fileglob !~ '[*?]'
    else
	return a:fileglob !~ '\\\@<![*?{[]'
    endif
endfunction
function! ingo#cmdargs#glob#Resolve( fileglobs )
"*******************************************************************************
"* PURPOSE:
"   Expand any file wildcards in a:fileglobs, convert to normal filespecs
"   and assemble file statistics. Like ingo#cmdargs#glob#Expand(), but
"   additionally returns statistics.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:fileglobs Raw list of file patterns.
"* RETURN VALUES:
"   [l:filespecs, l:statistics]	First element is a list of the resolved
"   filespecs (in normal, not Ex syntax), second element is a dictionary
"   containing the file statistics.
"*******************************************************************************
    let l:statistics = { 'files': 0, 'removed': 0, 'nonexisting': 0 }
    let l:filespecs = []
    for l:fileglob in a:fileglobs
	let l:resolvedFilespecs = ingo#cmdargs#glob#ExpandSingle(l:fileglob)
	if empty(l:resolvedFilespecs)
	    " To treat the file pattern as a filespec, we must emulate one
	    " effect of glob(): It removes superfluous escaping of spaces in the
	    " filespec (but leaves other escaped characters like 'C:\\foo'
	    " as-is). Without this substitution, the filereadable() check won't
	    " work.
	    let l:normalizedPotentialFilespec = substitute(l:fileglob, '\\\@<!\\ ', ' ', 'g')

	    " The globbing yielded no files; however:
	    if filereadable(l:normalizedPotentialFilespec)
		" a) The file pattern itself represents an existing file. This
		"    happens if a file is passed that matches one of the
		"    'wildignore' patterns. In this case, as the file has been
		"    explicitly passed to us, we include it.
		let l:filespecs += [l:normalizedPotentialFilespec]
	    elseif s:ContainsNoWildcards(l:fileglob)
		" b) The file pattern contains no wildcards and represents a
		"    to-be-created file.
		let l:filespecs += [l:fileglob]
		let l:statistics.nonexisting += 1
	    else
		" Nothing matched this file pattern, or whatever matched is
		" covered by the 'wildignore' patterns and not a file itself.
		let l:statistics.removed += 1
	    endif
	else
	    " We include whatever the globbing returned; 'wildignore' patterns
	    " are filtered out.
	    let l:filespecs += l:resolvedFilespecs
	endif
    endfor

    let l:statistics.files = len(l:filespecs)
    return [l:filespecs, l:statistics]
endfunction

" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
autoload/ingo/cmdargs/pattern.vim	[[[1
237
" ingo/cmdargs/pattern.vim: Functions for parsing of pattern arguments of commands.
"
" DEPENDENCIES:
"   - ingo/escape.vim autoload script
"
" Copyright: (C) 2013-2019 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>

function! ingo#cmdargs#pattern#PatternExpr( ... ) abort
    return '\([[:alnum:]\\"|]\@![\x00-\xFF]\)\(.\{-}\)\%(\%(^\|[^\\]\)\%(\\\\\)*\\\)\@<!\' . (a:0 ? a:1 : 1)
endfunction
function! s:Parse( arguments, ... )
    return matchlist(a:arguments, '^' . ingo#cmdargs#pattern#PatternExpr() . (a:0 ? a:1 : '') . '$')
endfunction
function! ingo#cmdargs#pattern#RawParse( arguments, returnValueOnNoMatch, ... )
"******************************************************************************
"* PURPOSE:
"   Parse a:arguments as a pattern delimited by non-optional /.../ (or similar)
"   characters, and with optional following flags match.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:arguments Command arguments to parse.
"   a:returnValueOnNoMatch  Value that will be returned when a:arguments are not
"			    a delimited pattern.
"   a:flagsExpr Pattern that captures any optional part after the pattern.
"   a:flagsMatchCount Number of capture groups returned from a:flagsExpr.
"* RETURN VALUES:
"   a:returnValueOnNoMatch if no match
"   [separator, escapedPattern]; if a:flagsExpr is given
"   [separator, escapedPattern, flags, ...].
"******************************************************************************
    let l:match = call('s:Parse', [a:arguments] + a:000)
    if empty(l:match)
	return a:returnValueOnNoMatch
    else
	return l:match[1: (a:0 ? (a:0 >= 2 ? a:2 + 2 : 3) : 2)]
    endif
endfunction
function! ingo#cmdargs#pattern#Parse( arguments, ... )
"******************************************************************************
"* PURPOSE:
"   Parse a:arguments as a pattern delimited by optional /.../ (or similar)
"   characters, and with optional following flags match.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:arguments Command arguments to parse.
"   a:flagsExpr Pattern that captures any optional part after the pattern.
"   a:flagsMatchCount Number of capture groups returned from a:flagsExpr.
"* RETURN VALUES:
"   [separator, escapedPattern]; if a:flagsExpr is given
"   [separator, escapedPattern, flags, ...].
"   In a:escapedPattern, the a:separator is consistently escaped (i.e. also when
"   the original arguments haven't been enclosed in such).
"******************************************************************************
    " Note: We could delegate to ingo#cmdargs#pattern#RawParse(), but let's
    " duplicate this for now to avoid another redirection.
    let l:match = call('s:Parse', [a:arguments] + a:000)
    if empty(l:match)
	return ['/', escape(a:arguments, '/')] + (a:0 ? repeat([''], a:0 >= 2 ? a:2 : 1) : [])
    else
	return l:match[1: (a:0 ? (a:0 >= 2 ? a:2 + 2 : 3) : 2)]
    endif
endfunction
function! ingo#cmdargs#pattern#ParseWithLiteralWholeWord( arguments, ... )
"******************************************************************************
"* PURPOSE:
"   Parse a:arguments as a pattern delimited by optional /.../ (or similar)
"   characters, and with optional following flags match. When the pattern isn't
"   delimited by /.../, the returned pattern is modified so that only literal
"   whole words are matched. Built-in commands like |:djump| also have this
"   behavior: |:search-args|
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:arguments Command arguments to parse.
"   a:flagsExpr Pattern that captures any optional part after the pattern.
"   a:flagsMatchCount Number of capture groups returned from a:flagsExpr.
"* RETURN VALUES:
"   [separator, escapedPattern]; if a:flagsExpr is given
"   [separator, escapedPattern, flags, ...].
"   In a:escapedPattern, the a:separator is consistently escaped (i.e. also when
"   the original arguments haven't been enclosed in such).
"******************************************************************************
    " Note: We could delegate to ingo#cmdargs#pattern#RawParse(), but let's
    " duplicate this for now to avoid another redirection.
    let l:match = call('s:Parse', [a:arguments] + a:000)
    if empty(l:match)
	let l:pattern = ingo#regexp#FromLiteralText(a:arguments, 1, '/')
	return ['/', l:pattern] + (a:0 ? repeat([''], a:0 >= 2 ? a:2 : 1) : [])
    else
	return l:match[1: (a:0 ? (a:0 >= 2 ? a:2 + 2 : 3) : 2)]
    endif
endfunction
function! ingo#cmdargs#pattern#ParseUnescaped( arguments, ... )
"******************************************************************************
"* PURPOSE:
"   Parse a:arguments as a pattern delimited by optional /.../ (or similar)
"   characters, and with optional following flags match.
"   You can use this function to check for delimiting /.../ characters, and then
"   either react on the (unescaped) pattern, or take the literal original
"   string:
"	let l:pattern = ingo#cmdargs#pattern#ParseUnescaped(a:argument)
"	if l:pattern !=# a:argument
"	    " Pattern-based processing with l:pattern.
"	else
"	    " Literal processing with a:argument
"	endif
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:arguments Command arguments to parse.
"   a:flagsExpr Pattern that captures any optional part after the pattern.
"   a:flagsMatchCount Number of capture groups returned from a:flagsExpr.
"* RETURN VALUES:
"   unescapedPattern (String); if a:flagsExpr is given instead List of
"   [unescapedPattern, flags, ...]. In a:unescapedPattern, any separator used in
"   a:arguments is unescaped.
"******************************************************************************
    let l:match = call('s:Parse', [a:arguments] + a:000)
    if empty(l:match)
	return (a:0 ? [a:arguments] + repeat([''], a:0 >= 2 ? a:2 : 1) : a:arguments)
    else
	let l:unescapedPattern = ingo#escape#Unescape(l:match[2], l:match[1])
	return (a:0 ? [l:unescapedPattern] + l:match[3: (a:0 >= 2 ? a:2 + 2 : 3)] : l:unescapedPattern)
    endif
endfunction
function! ingo#cmdargs#pattern#ParseUnescapedWithLiteralWholeWord( arguments, ... )
"******************************************************************************
"* PURPOSE:
"   Parse a:arguments as a pattern delimited by optional /.../ (or similar)
"   characters, and with optional following flags match. When the pattern isn't
"   delimited by /.../, the returned pattern is modified so that only literal
"   whole words are matched. Built-in commands like |:djump| also have this
"   behavior: |:search-args|
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:arguments Command arguments to parse.
"   a:flagsExpr Pattern that captures any optional part after the pattern.
"   a:flagsMatchCount Number of capture groups returned from a:flagsExpr.
"* RETURN VALUES:
"   unescapedPattern (String); if a:flagsExpr is given instead List of
"   [unescapedPattern, flags, ...]. In a:unescapedPattern, any separator used in
"   a:arguments is unescaped.
"******************************************************************************
    let l:match = call('s:Parse', [a:arguments] + a:000)
    if empty(l:match)
	let l:unescapedPattern = ingo#regexp#FromLiteralText(a:arguments, 1, '')
	return (a:0 ? [l:unescapedPattern] + repeat([''], a:0 >= 2 ? a:2 : 1) : l:unescapedPattern)
    else
	let l:unescapedPattern = ingo#escape#Unescape(l:match[2], l:match[1])
	return (a:0 ? [l:unescapedPattern] + l:match[3: (a:0 >= 2 ? a:2 + 2 : 3)] : l:unescapedPattern)
    endif
endfunction

function! ingo#cmdargs#pattern#Unescape( parsedArguments )
"******************************************************************************
"* PURPOSE:
"   Unescape the use of the separator from the parsed pattern to yield a plain
"   regular expression, e.g. for use in search().
"* ASSUMPTIONS / PRECONDITIONS:
"	? List of any external variable, control, or other element whose state affects this procedure.
"* EFFECTS / POSTCONDITIONS:
"	? List of the procedure's effect on each external variable, control, or other element.
"* INPUTS:
"   a:parsedArguments   List with at least two elements: [separator, pattern].
"			separator may be empty; in that case; pattern is
"			returned as-is.
"			You're meant to directly pass the output of
"			ingo#cmdargs#pattern#Parse() in here.
"* RETURN VALUES:
"   If a:parsedArguments contains exactly two arguments: unescaped pattern.
"   Else a List where the first element is the unescaped pattern, and all
"   following elements are taken from the remainder of a:parsedArguments.
"******************************************************************************
    " We don't need the /.../ separation here.
    let l:separator = a:parsedArguments[0]
    let l:unescapedPattern = (empty(l:separator) ?
    \   a:parsedArguments[1] :
    \   ingo#escape#Unescape(a:parsedArguments[1], l:separator)
    \)

    return (len(a:parsedArguments) > 2 ? [l:unescapedPattern] + a:parsedArguments[2:] : l:unescapedPattern)
endfunction

function! ingo#cmdargs#pattern#IsDelimited( arguments, ... )
"******************************************************************************
"* PURPOSE:
"   Test whether a:arguments is delimited by pattern separators (and optionally
"   appended flags).
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:arguments Command arguments to parse.
"   a:flagsExpr Pattern that captures any optional part after the pattern.
"* RETURN VALUES:
"   1 if delimited by suitable, identical characters (plus any flags as
"   specified by a:flagsExpr), else 0.
"******************************************************************************
    let l:match = call('s:Parse', [a:arguments] + a:000)
    return (! empty(l:match))
endfunction

function! ingo#cmdargs#pattern#Render( arguments )
"******************************************************************************
"* PURPOSE:
"   Create a single string from the parsed pattern arguments.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:arguments Return value from any of the ...#Parse... methods defined here.
"* RETURN VALUES:
"   String with separator-delimited pattern, followed by any additional flags,
"   etc.
"******************************************************************************
    return a:arguments[0] . a:arguments[1] . a:arguments[0] . join(a:arguments[2:], '')
endfunction

" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
autoload/ingo/cmdargs/range.vim	[[[1
124
" ingo/cmdargs/range.vim: Functions for parsing Ex command ranges.
"
" DEPENDENCIES:
"   - ingo/cmdargs/commandcommands.vim autoload script
"
" Copyright: (C) 2012-2019 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
let s:save_cpo = &cpo
set cpo&vim

let s:singleRangeExpr = '\%(\d*\|[.$*%]\|''\S\|\\[/?&]\|/.\{-}/\|?.\{-}?\)\%([+-]\d*\)\?'
let s:rangeExpr = s:singleRangeExpr . '\%([,;]' . s:singleRangeExpr . '\)\?'
function! ingo#cmdargs#range#SingleRangeExpr()
    return s:singleRangeExpr
endfunction
function! ingo#cmdargs#range#RangeExpr()
    return s:rangeExpr
endfunction

function! ingo#cmdargs#range#Parse( commandLine, ... )
"******************************************************************************
"* PURPOSE:
"   Parse a:commandLine into the range and the remainder. When the command line
"   contains multiple commands, the last one is parsed.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:commandLine   Ex command line containing a command.
"   a:options.isAllowEmptyCommand   Flag whether a sole range should be matched.
"				    True by default.
"   a:options.commandExpr           Custom pattern for matching commands /
"				    anything that follows the range. Mutually
"				    exclusive with
"				    a:options.isAllowEmptyCommand.
"   a:options.isParseFirstRange     Flag whether the first range should be
"				    parsed. False by default.
"   a:options.isOnlySingleAddress   Flag whether only a single address should be
"                                   allowed, and double line addresses are not
"                                   recognized as valid. False by default.
"* RETURN VALUES:
"   List of [fullCommandUnderCursor, combiner, commandCommands, range, remainder]
"	fullCommandUnderCursor  The entire command, potentially starting with
"				"|" when there's a command chain.
"	combiner    Empty, white space, or something with "|" that joins the
"		    command to the previous one.
"	commandCommands Empty or any prepended commands take another Ex command
"			as an argument.
"	range       The single or double line address(es), e.g. "42,'b".
"	remainder   The command; possibly empty (when a:isAllowEmptyCommand is
"		    true).
"   Or: [] if no match.
"******************************************************************************
    let l:options = (a:0 ? a:1 : {})
    let l:isAllowEmptyCommand = get(l:options, 'isAllowEmptyCommand', 1)
    let l:isParseFirstRange = get(l:options, 'isParseFirstRange', 0)
    let l:rangeExpr = (get(l:options, 'isOnlySingleAddress', 0) ?
    \   ingo#cmdargs#range#SingleRangeExpr() :
    \   ingo#cmdargs#range#RangeExpr()
    \)
    let l:commandExpr = get(l:options, 'commandExpr', (l:isAllowEmptyCommand ? '\(\h\w*.*\|$\)' : '\(\h\w*.*\)'))

    let l:parseExpr =
    \	(l:isParseFirstRange ? '\C^\(\s*\)' : '\C^\(.*\\\@<!|\)\?\s*') .
    \	'\(' . ingo#cmdargs#commandcommands#GetExpr() . '\)\?' .
    \	'\(' . l:rangeExpr . '\)\s*' .
    \   l:commandExpr
    return matchlist(a:commandLine, l:parseExpr)[0:4]
endfunction

function! ingo#cmdargs#range#ParsePrependedRange( arguments, ... )
"******************************************************************************
"* PURPOSE:
"   Parse a:arguments into a range at the beginning, and any following stuff,
"   separated by non-alphanumeric character or whitespace (or the optional
"   a:directSeparator).
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:arguments Command arguments to parse.
"   a:options.directSeparator   Optional regular expression for the separator
"                               (parsed into text) between the text and range
"                               (with optional whitespace in between; mandatory
"                               whitespace is always an alternative). Defaults
"                               to any whitespace. If empty: there must be
"                               whitespace between text and register.
"   a:options.isPreferText      Optional flag that if the arguments consist
"                               solely of an range, whether this is counted as
"                               text (1, default) or as a sole range (0).
"   a:options.isOnlySingleAddress   Flag whether only a single address should be
"                                   allowed, and double line addresses are not
"                                   recognized as valid. False by default.
"* RETURN VALUES:
"   [address, text], or ['', a:arguments] if no address could be parsed.
"******************************************************************************
    let l:options = (a:0 ? a:1 : {})
    let l:rangeExpr = (get(l:options, 'isOnlySingleAddress', 0) ?
    \   ingo#cmdargs#range#SingleRangeExpr() :
    \   ingo#cmdargs#range#RangeExpr()
    \)
    let l:directSeparator = (empty(get(l:options, 'directSeparator', '')) ?
    \   '\%$\%^' :
    \   get(l:options, 'directSeparator', '')
    \)
    let l:isPreferText = get(l:options, 'isPreferText', 1)

    let l:matches = matchlist(a:arguments, '^\(' . l:rangeExpr . '\)\%(\%(\s*' . l:directSeparator . '\)\@=\|\s\+\)\(.*\)$')
    return (empty(l:matches) ?
    \   (! l:isPreferText && a:arguments =~# '^' . l:rangeExpr . '$' ?
    \       [a:arguments , ''] :
    \       ['', a:arguments]
    \   ) :
    \   l:matches[1:2]
    \)
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo
" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
autoload/ingo/cmdargs/register.vim	[[[1
93
" ingo/cmdargs/register.vim: Functions for parsing a register name.
"
" DEPENDENCIES:
"
" Copyright: (C) 2014-2019 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
let s:save_cpo = &cpo
set cpo&vim

let s:writableRegisterExpr = '\([-a-zA-Z0-9"*+_/]\)'
function! s:GetDirectSeparator( optionalArguments )
    return (len(a:optionalArguments) > 0 ?
    \   (empty(a:optionalArguments[0]) ?
    \       '\%$\%^' :
    \       a:optionalArguments[0]
    \   ) :
    \   '[[:alnum:][:space:]\\"|]\@![\x00-\xFF]'
    \)
endfunction

function! ingo#cmdargs#register#ParseAppendedWritableRegister( arguments, ... )
"******************************************************************************
"* PURPOSE:
"   Parse a:arguments into any stuff and a writable register at the end,
"   separated by non-alphanumeric character or whitespace (or the optional
"   a:directSeparator).
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:arguments Command arguments to parse.
"   a:directSeparator   Optional regular expression for the separator (parsed
"			into text) between the text and register (with optional
"			whitespace in between; mandatory whitespace is always an
"			alternative). Defaults to any non-alphanumeric
"			character. If empty: there must be whitespace between
"			text and register.
"   a:isPreferText      Optional flag that if the arguments consist solely of a
"                       register, whether this is counted as text (1, default)
"                       or as a sole register (0).
"* RETURN VALUES:
"   [text, register], or [a:arguments, ''] if no register could be parsed.
"******************************************************************************
    let l:matches = matchlist(a:arguments, '^\(.\{-}\)\%(\%(\%(' . s:GetDirectSeparator(a:000) . '\)\@<=\s*\|\s\+\)' . s:writableRegisterExpr . '\)$')
    return (empty(l:matches) ?
    \   (a:0 >= 2 && ! a:2 && a:arguments =~# '^' . s:writableRegisterExpr . '$' ?
    \       ['', a:arguments] :
    \       [a:arguments , '']
    \   ) :
    \   l:matches[1:2]
    \)
endfunction

function! ingo#cmdargs#register#ParsePrependedWritableRegister( arguments, ... )
"******************************************************************************
"* PURPOSE:
"   Parse a:arguments into a writable register at the beginning, and any
"   following stuff, separated by non-alphanumeric character or whitespace (or
"   the optional a:directSeparator).
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:arguments Command arguments to parse.
"   a:directSeparator   Optional regular expression for the separator (parsed
"			into text) between the text and register (with optional
"			whitespace in between; mandatory whitespace is always an
"			alternative). Defaults to any non-alphanumeric
"			character. If empty: there must be whitespace between
"			text and register.
"   a:isPreferText      Optional flag that if the arguments consist solely of a
"                       register, whether this is counted as text (1, default)
"                       or as a sole register (0).
"* RETURN VALUES:
"   [register, text], or ['', a:arguments] if no register could be parsed.
"******************************************************************************
    let l:matches = matchlist(a:arguments, '^' . s:writableRegisterExpr . '\%(\%(\s*' . s:GetDirectSeparator(a:000) . '\)\@=\|\s\+\)\(.*\)$')
    return (empty(l:matches) ?
    \   (a:0 >= 2 && ! a:2 && a:arguments =~# '^' . s:writableRegisterExpr . '$' ?
    \       [a:arguments , ''] :
    \       ['', a:arguments]
    \   ) :
    \   l:matches[1:2]
    \)
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo
" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
autoload/ingo/cmdargs/substitute.vim	[[[1
127
" ingo/cmdargs/substitute.vim: Functions for parsing of :substitute arguments.
"
" DEPENDENCIES:
"   - ingo/list.vim autoload script
"
" Copyright: (C) 2012-2018 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>

function! s:ApplyEmptyFlags( emptyFlags, parsedFlags)
    return (empty(filter(copy(a:parsedFlags), '! empty(v:val)')) ? a:emptyFlags : a:parsedFlags)
endfunction
function! ingo#cmdargs#substitute#GetFlags( ... )
    return '&\?[cegiInp#lr' . (a:0 ? a:1 : '') . ']*'
endfunction

function! ingo#cmdargs#substitute#Parse( arguments, ... )
"******************************************************************************
"* PURPOSE:
"   Parse the arguments of a custom command that works like :substitute.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:arguments The command's raw arguments; usually <q-args>.
"   a:options.flagsExpr             Pattern that captures any optional part
"				    after the replacement (usually some
"				    substitution flags). By default, captures
"				    the known :substitute |:s_flags| and
"				    optional [count]. Pass an empty string to
"				    disallow any flags.
"   a:options.additionalFlags       Flags that will be recognized in addition to
"				    the default |:s_flags|; default none. Modify
"				    this instead of passing a:options.flagsExpr
"				    if you want to recognize additional flags.
"   a:options.flagsMatchCount       Optional number of submatches captured by
"				    a:options.flagsExpr. Defaults to 2 with the
"				    default a:options.flagsExpr, to 1 with a
"				    non-standard non-empty a:options.flagsExpr,
"				    and 0 if a:options.flagsExpr is empty.
"   a:options.defaultReplacement    Replacement to use when the replacement part
"				    is omitted. Empty by default.
"   a:options.emptyPattern          Pattern to use when no arguments at all are
"				    given. Defaults to "", which automatically
"				    uses the last search pattern in a
"				    :substitute. You need to escape this
"				    yourself (to be able to pass in @/, which
"				    already is escaped).
"   a:options.emptyReplacement      Replacement to use when no arguments at all
"				    are given. Defaults to "~" to use the
"				    previous replacement in a :substitute.
"   a:options.emptyFlags            Flags to use when a:options.flagsExpr is not
"				    empty, but no arguments at all are given.
"				    Defaults to ["&", ""] to use the previous
"				    flags of a :substitute. Provide a List if
"				    a:options.flagsMatchCount is larger than 1.
"   a:options.isAllowLoneFlags      Allow to omit /pat/repl/, and parse a
"				    stand-alone a:options.flagsExpr (assuming
"				    one is passed). On by default.
"* RETURN VALUES:
"   A list of [separator, pattern, replacement, flags, count] (default)
"   A list of [separator, pattern, replacement] when a:options.flagsExpr is
"   empty or a:options.flagsMatchCount is 0.
"   A list of [separator, pattern, replacement, submatch1, ...];
"   elements added depending on a:options.flagsMatchCount.
"   flags and count are meant to be directly concatenated; count therefore keeps
"   leading whitespace, but be aware that this is optional with :substitute,
"   too!
"   The replacement part is always escaped for use inside separator, also when
"   the default is taken.
"******************************************************************************
    let l:options = (a:0 ? a:1 : {})
    let l:additionalFlags = get(l:options, 'additionalFlags', '')
    let l:flagsExpr = get(l:options, 'flagsExpr', '\(' . ingo#cmdargs#substitute#GetFlags(l:additionalFlags) . '\)\(\s*\d*\)')
    let l:isParseFlags = (! empty(l:flagsExpr))
    let l:flagsMatchCount = get(l:options, 'flagsMatchCount', (has_key(l:options, 'flagsExpr') ? (l:isParseFlags ? 1 : 0) : 2))
    let l:defaultFlags = (l:isParseFlags ? repeat([''], l:flagsMatchCount) : [])
    let l:defaultReplacement = get(l:options, 'defaultReplacement', '')
    let l:emptyPattern = get(l:options, 'emptyPattern', '')
    let l:emptyReplacement = get(l:options, 'emptyReplacement', '~')
    let l:emptyFlags = get(l:options, 'emptyFlags', ['&'] + repeat([''], l:flagsMatchCount - 1))
    let l:isAllowLoneFlags = get(l:options, 'isAllowLoneFlags', 1)

    let l:matches = matchlist(a:arguments, '\C^\([[:alnum:]\\"|]\@![\x00-\xFF]\)\(.\{-}\)\%(\%(^\|[^\\]\)\%(\\\\\)*\\\)\@<!\1\(.\{-}\)\%(\%(^\|[^\\]\)\%(\\\\\)*\\\)\@<!\1' . l:flagsExpr . '$')
    if ! empty(l:matches)
	" Full /pat/repl/[flags].
	return l:matches[1:3] + (l:isParseFlags ? l:matches[4:(4 + l:flagsMatchCount - 1)] : [])
    endif

    let l:matches = matchlist(a:arguments, '\C^\([[:alnum:]\\"|]\@![\x00-\xFF]\)\(.\{-}\)\%(\%(^\|[^\\]\)\%(\\\\\)*\\\)\@<!\1\(.\{-}\)$')
    if ! empty(l:matches)
	" Partial /pat/[repl].
	return l:matches[1:2] + [(empty(l:matches[3]) ? escape(l:defaultReplacement, l:matches[1]) : l:matches[3])] + l:defaultFlags
    endif

    let l:matches = matchlist(a:arguments, '\C^\([[:alnum:]\\"|]\@![\x00-\xFF]\)\(.\{-}\)$')
    if ! empty(l:matches)
	" Minimal /[pat].
	return l:matches[1:2] + [escape(l:defaultReplacement, l:matches[1])] + l:defaultFlags
    endif

    if ! empty(a:arguments)
	if l:isParseFlags && l:isAllowLoneFlags
	    let l:matches = matchlist(a:arguments, '\C^' . l:flagsExpr . '$')
	    if ! empty(l:matches)
		" Special case of {flags} without /pat/string/.
		return ['/', l:emptyPattern, escape(l:emptyReplacement, '/')] + s:ApplyEmptyFlags(ingo#list#Make(l:emptyFlags), l:matches[1:(l:flagsMatchCount)])
	    endif
	endif

	" Literal pat.
	if ! empty(l:defaultReplacement)
	    " Clients cannot concatentate the results without a separator, so
	    " use one.
	    return ['/', escape(a:arguments, '/'), escape(l:defaultReplacement, '/')] + l:defaultFlags
	else
	    return ['', a:arguments, l:defaultReplacement] + l:defaultFlags
	endif
    else
	" Nothing.
	return ['/', l:emptyPattern, escape(l:emptyReplacement, '/')] + (l:isParseFlags ? ingo#list#Make(l:emptyFlags) : [])
    endif
endfunction

" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
autoload/ingo/cmdline/showmode.vim	[[[1
65
" ingo/cmdline/showmode.vim: Functions for the 'showmode' option.
"
" DEPENDENCIES:
"
" Copyright: (C) 2013-2019 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
"
" REVISION	DATE		REMARKS
"   1.025.003	26-Jan-2016	Add ingo#cmdline#showmode#TemporaryNoShowMode()
"				variant of
"				ingo#cmdline#showmode#OneLineTemporaryNoShowMode().
"   1.009.002	20-Jun-2013	Indicate activation with return code.
"   1.009.001	18-Jun-2013	file creation from SnippetComplete.vim

let s:record = []
function! ingo#cmdline#showmode#TemporaryNoShowMode()
"******************************************************************************
"* PURPOSE:
"   An active 'showmode' setting may prevent the user from seeing the message in
"   a command line. Thus, we temporarily disable the 'showmode' setting.
"   Sometimes, this only happens in a single-line command line, but :echo'd text
"   is visible when 'cmdline' is larger than 1. For that, use
"   ingo#cmdline#showmode#OneLineTemporaryNoShowMode().
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   None.
"* RETURN VALUES:
"   Boolean flag whether the temporary mode has been activated.
"******************************************************************************
    if ! &showmode || &cmdheight > 1
	return 0
    endif

    set noshowmode
    let s:record = ingo#record#Position(0)
    let s:record[2] += 1

    " Use a single-use autocmd to restore the 'showmode' setting when the cursor
    " is moved or insert mode is left.
    augroup IngoLibraryNoShowMode
	autocmd!

	" XXX: After a cursor move, the mode message doesn't instantly appear
	" again. A jump with scrolling or another mode change has to happen.
	" Neither :redraw nor :redrawstatus will do, but apparently :echo
	" triggers an update.
	autocmd CursorMovedI * if s:record != ingo#record#Position(0) | set showmode | echo '' | execute 'autocmd! IngoLibraryNoShowMode' | endif

	autocmd InsertLeave  * if s:record != ingo#record#Position(0) | set showmode |           execute 'autocmd! IngoLibraryNoShowMode' | endif
    augroup END
    return 1
endfunction
function! ingo#cmdline#showmode#OneLineTemporaryNoShowMode()
    if &cmdheight > 1
	return 0
    endif
    return ingo#cmdline#showmode#TemporaryNoShowMode()
endfunction

" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
autoload/ingo/cmdrange.vim	[[[1
37
" ingo/cmdrange.vim: Functions for working with command ranges.
"
" DEPENDENCIES:
"
" Copyright: (C) 2019 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
let s:save_cpo = &cpo
set cpo&vim

function! ingo#cmdrange#FromCount( ... )
"******************************************************************************
"* PURPOSE:
"   Convert the passed a:count / v:count into a command-line range, defaulting
"   to the current line / a:defaultRange if count is 0.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:defaultRange  Optional default range when count is 0.
"   a:count         Optional given count.
"* RETURN VALUES:
"   Command-line range to be prepended to an Ex command.
"******************************************************************************
    let l:defaultRange = (a:0 && a:1 isnot# '' ? a:1 : '.')
    let l:count = (a:0 >= 2 ? a:2 : v:count)
    return (l:count ?
    \   (l:count == 1 ? '.' : '.,.+' . (l:count - 1)) :
    \   l:defaultRange
    \)
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo
" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
autoload/ingo/cmdrangeconverter.vim	[[[1
84
" ingo/cmdrangeconverter.vim: Functions to convert :command ranges.
"
" DEPENDENCIES:
"   - ingo/err.vim autoload script
"
" Copyright: (C) 2010-2019 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
"
" REVISION	DATE		REMARKS
"   1.006.002	17-Apr-2013	Add ingo#cmdrangeconverter#LineToBufferRange().
"   1.006.001	17-Apr-2013	file creation from ingointegration.vim

function! ingo#cmdrangeconverter#BufferToLineRange( cmd ) range
"******************************************************************************
"* MOTIVATION:
"   You want to invoke a command :Foo in a line-wise mapping <Leader>foo; the
"   command has a default range=%. The simplest solution is
"	nnoremap <Leader>foo :<C-u>.Foo<CR>
"   but that doesn't support a [count]. You cannot use
"	nnoremap <Leader>foo :Foo<CR>
"   neither, because then the mapping will work on the entire buffer if no
"   [count] is given. This utility function wraps the Foo command, passes the
"   given range, and falls back to the current line when no [count] is given:
"	:nnoremap <Leader>foo :call ingo#cmdrangeconverter#BufferToLineRange('Foo')<Bar>if ingo#err#IsSet()<Bar>echoerr ingo#err#Get()<Bar>endif<CR>
"
"* PURPOSE:
"   Always pass the line-wise range to a:cmd.
"
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:cmd   Ex command which has a default range=%.
"* RETURN VALUES:
"   True if successful; False when a Vim error or exception occurred.
"******************************************************************************
    call ingo#err#Clear()
    try
	execute a:firstline . ',' . a:lastline . a:cmd
	return 1
    catch
	call ingo#err#SetVimException()
	return 0
    endtry
endfunction

function! ingo#cmdrangeconverter#LineToBufferRange( cmd, ... )
"******************************************************************************
"* MOTIVATION:
"   You want to invoke a command that defaults to the current line (e.g. :s) in
"   a mapping <Leader>foo that defaults to the whole buffer, unless [count] is
"   given.
"   This utility function wraps the command, passes the given range, and falls
"   back to % when no [count] is given:
"	:nnoremap <Leader>foo :<C-u>if ! ingo#cmdrangeconverter#LineToBufferRange('s///g')<Bar>echoerr ingo#err#Get()<Bar>endif<CR>
"
"* PURPOSE:
"   Convert a line-range command to default to the entire buffer.
"
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:cmd   Ex command which has a default range=.
"   a:count Optional [count], pass this when v:count has been clobbered.
"* RETURN VALUES:
"   True if successful; False when a Vim error or exception occurred.
"   Get the error message via ingo#err#Get().
"******************************************************************************
    call ingo#err#Clear()
    try
	execute call('ingo#cmdrange#FromCount', ['%'] + a:000) . a:cmd
	return 1
    catch
	call ingo#err#SetVimException()
	return 0
    endtry
endfunction

" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
autoload/ingo/codec/URL.vim	[[[1
48
" ingo/codec/URL.vim: URL encoding / decoding.
"
" DEPENDENCIES:
"   - ingo/collections/fromsplit.vim autoload script
"
" Copyright: (C) 2012-2016 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Source:
"   Encoding / decoding algorithms taken from unimpaired.vim (vimscript #1590)
"   by Tim Pope.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
"
" REVISION	DATE		REMARKS
"   1.028.004	10-Oct-2016	ingo#codec#URL#Decode(): Also convert the
"				character set to UTF-8 to properly handle
"				non-ASCII characters. For example, %C3%9C should
"				decode to "Ü", not to "É".
"   1.019.003	20-May-2014	Move into ingo library, because this is now used
"				by multiple plugins.
"	002	09-May-2012	Add subs#URL#FilespecEncode() that does not
"				encoding the path separator "/". This is useful
"				for encoding normal filespecs.
"	001	30-Mar-2012	file creation

function! s:Encode( chars, text )
    return substitute(a:text, a:chars, '\="%" . printf("%02X", char2nr(submatch(0)))', 'g')
endfunction
function! ingo#codec#URL#Encode( text )
    return s:Encode('[^A-Za-z0-9_.~-]', a:text)
endfunction
function! ingo#codec#URL#FilespecEncode( text )
    return s:Encode('[^A-Za-z0-9_./~-]', substitute(a:text, '\\', '/', 'g'))
endfunction

function! ingo#codec#URL#DecodeAndConvertCharset( urlEscapedText )
    let l:decodedText = substitute(a:urlEscapedText, '%\(\x\x\)', '\=nr2char(''0x'' . submatch(1))', 'g')
    "let l:convertedText = subs#Charset#LatinToUtf8(l:decodedText)
    let l:convertedText = iconv(l:decodedText, 'utf-8', 'latin1')
    return l:convertedText
endfunction
function! ingo#codec#URL#Decode( text )
    let l:text = substitute(substitute(substitute(a:text, '%0[Aa]\n$', '%0A', ''), '%0[Aa]', '\n', 'g'), '+', ' ', 'g')
    return join(ingo#collections#fromsplit#MapSeparators(l:text, '\%(%\x\x\)\+', 'ingo#codec#URL#DecodeAndConvertCharset(v:val)'), '')
endfunction

" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
autoload/ingo/collections.vim	[[[1
552
" ingo/collections.vim: Functions to operate on collections.
"
" DEPENDENCIES:
"   - ingo/actions.vim autoload script
"   - ingo/compat.vim autoload script
"   - ingo/dict.vim autoload script
"   - ingo/dict/count.vim autoload script
"   - ingo/list.vim autoload script
"   - ingocollections.vim autoload script
"
" Copyright: (C) 2011-2019 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>

function! ingo#collections#ToDict( list, ... )
"******************************************************************************
"* PURPOSE:
"   Convert a:list to a Dictionary, with each list element becoming a key (and
"   the unimportant value is 1).
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:list  List of keys.
"   a:emptyValue    Optional value for items in a:list that yield an empty
"		    string, which (in Vim versions prior to 7.4.1707) cannot be
"		    used as a Dictionary key.
"		    If omitted, empty values are not included in the Dictionary.
"* RETURN VALUES:
"   A new Dictionary with keys taken from a:list.
"* SEE ALSO:
"   ingo#dict#FromKeys() allows to specify a default value (here hard-coded to
"   1), but doesn't handle empty keys.
"   ingo#dict#count#Items() also creates a Dict from a List, and additionally
"   counts the unique values.
"******************************************************************************
    let l:dict = {}
    for l:item in a:list
	let l:key = '' . l:item
	if l:key ==# ''
	    if a:0
		let l:dict[a:1] = 1
	    endif
	else
	    let l:dict[l:key] = 1
	endif
    endfor
    return l:dict
endfunction

function! ingo#collections#Unique( list, ... )
"******************************************************************************
"* PURPOSE:
"   Return a list where each element from a:list is contained only once.
"   Equality check is done on the string representation, always case-sensitive.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:list  List of elements; does not need to be sorted.
"   a:emptyValue    Optional value for items in a:list that yield an empty
"		    string. Default is <Nul>.
"* RETURN VALUES:
"   Return the string representation of the unique elements of a:list. The order
"   of returned elements is undetermined. To maintain the original order, use
"   ingo#collections#UniqueStable(). To keep the original elements, use
"   ingo#collections#UniqueSorted(). But this is the fastest function.
"******************************************************************************
    let l:emptyValue = (a:0 ? a:1 : "\<Nul>")
    return map(keys(ingo#collections#ToDict(a:list, l:emptyValue)), 'v:val == l:emptyValue ? "" : v:val')
endfunction
function! ingo#collections#UniqueSorted( list )
"******************************************************************************
"* PURPOSE:
"   Filter the sorted a:list so that each element is contained only once.
"   Equality check is done on the list elements, always case-sensitive.
"* SEE ALSO:
"   - ingo#compat#uniq() is a compatibility wrapper around the uniq() function
"     introduced in Vim 7.4.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:list  Sorted list of elements.
"* RETURN VALUES:
"   The order of returned elements is kept.
"******************************************************************************
    if len(a:list) < 2
	return a:list
    endif

    let l:previousItem = a:list[0]
    let l:result = [a:list[0]]
    for l:item in a:list[1:]
	if l:item !=# l:previousItem
	    call add(l:result, l:item)
	    let l:previousItem = l:item
	endif
    endfor
    return l:result
endfunction
function! ingo#collections#UniqueStable( list, ... )
"******************************************************************************
"* PURPOSE:
"   Filter a:list so that each element is contained only once (in its first
"   occurrence).
"   Equality check is done on the string representation, always case-sensitive.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:list  List of elements; does not need to be sorted.
"   a:emptyValue    Optional value for items in a:list that yield an empty
"		    string. Default is <Nul>.
"* RETURN VALUES:
"   The order of returned elements is kept.
"******************************************************************************
    let l:emptyValue = (a:0 ? a:1 : "\<Nul>")
    let l:itemDict = {}
    let l:result = []
    for l:item in a:list
	let l:key = '' . (l:item ==# '' ? l:emptyValue : l:item)
	if ! has_key(l:itemDict, l:key)
	    let l:itemDict[l:key] = 1
	    call add(l:result, l:item)
	endif
    endfor
    return l:result
endfunction

function! s:add( list, expr, keepempty )
    if ! a:keepempty && empty(a:expr)
	return
    endif
    return add(a:list, a:expr)
endfunction
function! ingo#collections#SplitKeepSeparators( expr, pattern, ... )
"******************************************************************************
"* PURPOSE:
"   Like the built-in |split()|, but keep the separators matched by a:pattern as
"   individual items in the result. Also supports zero-width separators like
"   \zs. (Though for an unconditional zero-width match, this special function
"   would not provide anything that split() doesn't yet provide.)
"
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:expr	Text to be split.
"   a:pattern	Regular expression that specifies the separator text that
"		delimits the items.
"   a:keepempty	When the first or last item is empty it is omitted, unless the
"		{keepempty} argument is given and it's non-zero.
"		Other empty items are kept when {pattern} matches at least one
"		character or when {keepempty} is non-zero.
"* RETURN VALUES:
"   List of items: [item1, sep1, item2, sep2, item3, ...]
"******************************************************************************
    let l:keepempty = (a:0 ? a:1 : 0)
    let l:prevIndex = 0
    let l:index = 0
    let l:separator = ''
    let l:items = []

    while ! empty(a:expr)
	let l:index = match(a:expr, a:pattern, l:prevIndex)
	if l:index == -1
	    call s:add(l:items, strpart(a:expr, l:prevIndex), l:keepempty)
	    break
	endif
	let l:item = strpart(a:expr, l:prevIndex, (l:index - l:prevIndex))
	call s:add(l:items, l:item, (l:keepempty || ! empty(l:separator)))

	let l:prevIndex = matchend(a:expr, a:pattern, l:prevIndex)
	let l:separator = strpart(a:expr, l:index, (l:prevIndex - l:index))

	if empty(l:item) && empty(l:separator)
	    " We have a zero-width separator; consume at least one character to
	    " avoid the endless loop.
	    let l:prevIndex = matchend(a:expr, '\_.', l:index)
	    if l:prevIndex == -1
		break
	    endif
	    call add(l:items, strpart(a:expr, l:index, (l:prevIndex - l:index)))
	else
	    call s:add(l:items, l:separator, l:keepempty)
	endif
    endwhile

    return l:items
endfunction
function! ingo#collections#SeparateItemsAndSeparators( expr, pattern, ... )
"******************************************************************************
"* PURPOSE:
"   Like the built-in |split()|, but return both items and the separators
"   matched by a:pattern as two separate Lists.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   If a:keepempty (and {pattern} matches at least one character),
"   len(items) == len(separators) + 1
"* INPUTS:
"   a:expr	Text to be split.
"   a:pattern	Regular expression that specifies the separator text that
"		delimits the items.
"   a:keepempty	When the first or last item is empty it is omitted, unless the
"		{keepempty} argument is given and it's non-zero.
"		Other empty items are kept when {pattern} matches at least one
"		character or when {keepempty} is non-zero.
"* RETURN VALUES:
"   List of [items, separators]: [[item1, item2, item3, ...], [sep1, sep2, ...]]
"******************************************************************************
    let l:keepempty = (a:0 ? a:1 : 0)
    let l:prevIndex = 0
    let l:index = 0
    let l:separator = ''
    let l:items = []
    let l:separators = []

    while ! empty(a:expr)
	let l:index = match(a:expr, a:pattern, l:prevIndex)
	if l:index == -1
	    call s:add(l:items, strpart(a:expr, l:prevIndex), l:keepempty)
	    break
	endif
	let l:item = strpart(a:expr, l:prevIndex, (l:index - l:prevIndex))
	call s:add(l:items, l:item, (l:keepempty || ! empty(l:separator)))

	let l:prevIndex = matchend(a:expr, a:pattern, l:prevIndex)
	let l:separator = strpart(a:expr, l:index, (l:prevIndex - l:index))

	if empty(l:item) && empty(l:separator)
	    " We have a zero-width separator; consume at least one character to
	    " avoid the endless loop.
	    let l:prevIndex = matchend(a:expr, '\_.', l:index)
	    if l:prevIndex == -1
		break
	    endif
	    call add(l:items, strpart(a:expr, l:index, (l:prevIndex - l:index)))
	else
	    call s:add(l:separators, l:separator, l:keepempty)
	endif
    endwhile

    return [l:items, l:separators]
endfunction
function! ingo#collections#SplitIntoMatches( expr, pattern, ... )
"******************************************************************************
"* PURPOSE:
"   Like the built-in |split()|, but only return the separators matched by
"   a:pattern, and discard the text in between (what is normally returned by
"   split()). Optionally it checks that the discarded text only matches
"   a:allowedDiscardPattern, and throws an exception if something else would be
"   discarded.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:expr	Text to be split.
"   a:pattern	Regular expression that specifies the separator text that
"		delimits the items to be discarded.
"   a:allowedDiscardPattern Optional regular expression that if given checks all
"                           discarded text in between separators for match. If
"                           one does not match, a "SplitIntoMatches: Cannot
"                           discard TEXT" exception is thrown. To ensure that
"                           everything matches as separators, and all items are
"                           empty, pass "" or "^$".
"* RETURN VALUES:
"   List of separators matching a:pattern: [sep1, ...].
"******************************************************************************
    let l:allowedDiscardPattern = (a:0 ? (empty(a:1) ? '^$' : a:1) : '')
    let l:prevIndex = 0
    let l:index = 0
    let l:separator = ''
    let l:separators = []

    while ! empty(a:expr)
	let l:index = match(a:expr, a:pattern, l:prevIndex)
	if l:index == -1
	    let l:remainder = strpart(a:expr, l:prevIndex)
	    if ! empty(l:allowedDiscardPattern) && matchstr(l:remainder, '\C' . l:allowedDiscardPattern) !=# l:remainder
		throw 'SplitIntoMatches: Cannot discard ' . string(l:remainder)
	    endif

	    break
	endif
	let l:item = strpart(a:expr, l:prevIndex, (l:index - l:prevIndex))
	if ! empty(l:allowedDiscardPattern) && matchstr(l:item, '\C' . l:allowedDiscardPattern) !=# l:item
	    throw 'SplitIntoMatches: Cannot discard ' . string(l:item)
	endif

	let l:prevIndex = matchend(a:expr, a:pattern, l:prevIndex)
	let l:separator = strpart(a:expr, l:index, (l:prevIndex - l:index))

	if empty(l:item) && empty(l:separator)
	    " We have a zero-width separator; consume at least one character to
	    " avoid the endless loop.
	    let l:prevIndex = matchend(a:expr, '\_.', l:index)
	    if l:prevIndex == -1
		break
	    endif
	else
	    call s:add(l:separators, l:separator, 1)
	endif
    endwhile

    return l:separators
endfunction

function! ingo#collections#isort( i1, i2 )
"******************************************************************************
"* PURPOSE:
"   Case-insensitive sort function for strings; lowercase comes before
"   uppercase.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   i1, i2  Strings.
"* RETURN VALUES:
"   -1, 0 or 1, as specified by the sort() function.
"******************************************************************************
    if a:i1 ==# a:i2
	return 0
    elseif a:i1 ==? a:i2
	" If only differ in case, choose lowercase before uppercase.
	return a:i1 < a:i2 ? 1 : -1
    else
	" ASCII-ascending while ignoring case.
	return tolower(a:i1) > tolower(a:i2) ? 1 : -1
    endif
endfunction

function! ingo#collections#numsort( i1, i2, ... )
"******************************************************************************
"* PURPOSE:
"   Numerical (through str2nr()) sort function for numbers; text after the
"   number is silently ignored.
"* ALTERNATIVE:
"   Since Vim 7.4.341, the built-in sort() function supports a special {func}
"   value of "n" for numerical sorting.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   i1, i2  Elements (that are converted to numbers).
"   a:base  Optional base for conversion.
"* RETURN VALUES:
"   -1, 0 or 1, as specified by the sort() function.
"******************************************************************************
    let l:base = (a:0 ? a:1 : 10)
    let [l:i1, l:i2] = [str2nr(a:i1, l:base), str2nr(a:i2, l:base)]
    return l:i1 == l:i2 ? 0 : l:i1 > l:i2 ? 1 : -1
endfunction

function! ingo#collections#FileModificationTimeSort( i1, i2 )
"******************************************************************************
"* PURPOSE:
"   Sort by modification time (|getftime()|); recently modifified files first.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   i1, i2  Elements (assumed to be existing filespecs).
"* RETURN VALUES:
"   -1, 0 or 1, as specified by the sort() function.
"******************************************************************************
    return -1 * ingo#collections#memoized#Mapsort('getftime(v:val)', a:i1, a:i2, {'cacheTimeInSeconds': 10})
endfunction

function! ingo#collections#mapsort( string, i1, i2 )
"******************************************************************************
"* PURPOSE:
"   Helper sort function for map()ped values. As Vim doesn't have real closures,
"   you still need to define your own (two-argument) sort function, but you can
"   use this to make that a simple stub.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:string  Vimscript expression to be evaluated over [a:i1, a:i2] via map().
"   i1, i2  Elements
"* RETURN VALUES:
"   -1, 0 or 1, as specified by the sort() function.
"   Note: To reverse the sort order, just multiply this function's return value
"   with -1.
"******************************************************************************
    let [l:i1, l:i2] = map([a:i1, a:i2], a:string)
    return l:i1 == l:i2 ? 0 : l:i1 > l:i2 ? 1 : -1
endfunction
function! ingo#collections#SortOnOneAttribute( attribute, o1, o2, ... )
    let l:defaultValue = (a:0 ? a:1 : 0)
    let l:a1 = get(a:o1, a:attribute, l:defaultValue)
    let l:a2 = get(a:o2, a:attribute, l:defaultValue)
    return (l:a1 ==# l:a2 ? 0 : l:a1 ># l:a2 ? 1 : -1)
endfunction
function! ingo#collections#PrioritySort( o1, o2, ... )
    return call('ingo#collections#SortOnOneAttribute', ['priority', a:o1, a:o2] + a:000)
endfunction
function! ingo#collections#SortOnTwoAttributes( firstAttribute, secondAttribute, o1, o2, ... )
"******************************************************************************
"* PURPOSE:
"   Helper sort function for objects that sort on a:firstAttribute first; if
"   that is equal or does not exist on both, sort on a:secondAttribute.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:firstAttribute    Primary attribute to sort on.
"   a:secondAttribute   Secondary attribute to sort on; is used when two objects
"                       don't have the primary attribute or it is equal.
"   a:o1, a:o2          Objects to be compared.
"   a:firstDefaultValue Optional default value if a:firstAttribute does not
"                       exist. Default is 0.
"   a:secondDefaultValue
"* RETURN VALUES:
"   -1, 0 or 1, as specified by the sort() function.
"******************************************************************************
    let l:firstDefaultValue = (a:0 ? a:1 : 0)
    if has_key(a:o1, a:firstAttribute) || has_key(a:o2, a:firstAttribute)
	let l:first1 = get(a:o1, a:firstAttribute, l:firstDefaultValue)
	let l:first2 = get(a:o2, a:firstAttribute, l:firstDefaultValue)
	if l:first1 !=# l:first2
	    return (l:first1 ># l:first2 ? 1 : -1)
	endif
    endif

    let l:secondDefaultValue = (a:0 >= 2 ? a:2 : l:firstDefaultValue)
    let l:second1 = get(a:o1, a:secondAttribute, l:secondDefaultValue)
    let l:second2 = get(a:o2, a:secondAttribute, l:secondDefaultValue)
    return (l:second1 ==# l:second2 ? 0 : l:second1 ># l:second2 ? 1 : -1)
endfunction
function! ingo#collections#SortOnOneListElement( index, l1, l2, ... )
    let l:defaultValue = (a:0 ? a:1 : 0)
    let l:i1 = get(a:l1, a:index, l:defaultValue)
    let l:i2 = get(a:l2, a:index, l:defaultValue)
    return (l:i1 ==# l:i2 ? 0 : l:i1 ># l:i2 ? 1 : -1)
endfunction

function! ingo#collections#Flatten1( list )
    let l:result = []
    for l:item in a:list
	call ingo#list#AddOrExtend(l:result, l:item)
	unlet l:item
    endfor
    return l:result
endfunction
function! ingo#collections#Flatten( list )
    let l:result = []
    for l:item in a:list
	if type(l:item) == type([])
	    call extend(l:result, ingo#collections#Flatten(l:item))
	else
	    call add(l:result, l:item)
	endif
	unlet l:item
    endfor
    return l:result
endfunction

function! ingo#collections#Partition( list, Predicate )
"******************************************************************************
"* PURPOSE:
"   Separate a List / Dictionary into two, depending on whether a:Predicate is
"   true for each member of the collection.
"* SEE ALSO:
"   - If you want to split off only elements from the start of a List while
"     a:Predicate matches (not elements from anywhere in a:list), use
"     ingo#list#split#RemoveFromStartWhilePredicate() instead.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:list      List or Dictionary.
"   a:Predicate Either a Funcref or an expression to be eval()ed.
"* RETURN VALUES:
"   List of [in, out], which are disjunct sub-Lists / sub-Dictionaries
"   containing the items where a:Predicate is true / is false.
"******************************************************************************
    if type(a:list) == type([])
	let [l:in, l:out] = [[], []]
	for l:item in a:list
	    if ingo#actions#EvaluateWithValOrFunc(a:Predicate, l:item)
		call add(l:in, l:item)
	    else
		call add(l:out, l:item)
	    endif
	endfor
    elseif type(a:list) == type({})
	let [l:in, l:out] = [{}, {}]
	for l:item in items(a:list)
	    if ingo#actions#EvaluateWithValOrFunc(a:Predicate, l:item)
		let l:in[l:item[0]] = l:item[1]
	    else
		let l:out[l:item[0]] = l:item[1]
	    endif
	endfor
    else
	throw 'ASSERT: Invalid type for list'
    endif

    return [l:in, l:out]
endfunction

function! ingo#collections#Reduce( list, Callback, initialValue )
"******************************************************************************
"* PURPOSE:
"   Reduce a List / Dictionary into a single value by repeatedly applying
"   a:Callback to the accumulator (as v:val[0]) and a List element / [key,
"   value] Dictionary element (as v:val[1]). Also known as "fold left".
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:list          List or Dictionary.
"   a:Callback      Either a Funcref or an expression to be eval()ed.
"   a:initialValue  Initial value for the accumulator.
"* RETURN VALUES:
"   Accumulated value.
"******************************************************************************
    let l:accumulator = a:initialValue

    if type(a:list) == type([])
	for l:item in a:list
	    let l:accumulator = ingo#actions#EvaluateWithValOrFunc(a:Callback, l:accumulator, l:item)
	endfor
    elseif type(a:list) == type({})
	for l:item in items(a:list)
	    let l:accumulator = ingo#actions#EvaluateWithValOrFunc(a:Callback, l:accumulator, l:item)
	endfor
    else
	throw 'ASSERT: Invalid type for list'
    endif

    return l:accumulator
endfunction

" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
autoload/ingo/collections/differences.vim	[[[1
91
" ingo/collections/differences.vim: Functions to obtain the differences between lists.
"
" DEPENDENCIES:
"
" Copyright: (C) 2015-2016 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
"
" REVISION	DATE		REMARKS
"   1.025.002	29-Jul-2016	Add
"				ingo#collections#differences#ContainsLoosely()
"				and
"				ingo#collections#differences#ContainsStrictly().
"   1.024.001	13-Feb-2015	file creation

function! s:GetMissing( list1, list2 )
    " Note: We assume there are far less differences than common elements, so we
    " don't copy() and filter() the original list, and instead iterate.
    let l:notIn2 = []
    for l:item in a:list1
	if index(a:list2, l:item) == -1
	    call add(l:notIn2, l:item)
	endif
    endfor
    return l:notIn2
endfunction
function! ingo#collections#differences#Get( list1, list2 )
"******************************************************************************
"* PURPOSE:
"   Determine the elements missing in the other list.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:list1 A list.
"   a:list2 A list.
"* RETURN VALUES:
"   Two lists: [ notIn2, notIn1 ] that contain the elements (in the same order)
"   not found in the other list. If the passed lists are equal, both are empty.
"******************************************************************************
    let l:notIn2 = s:GetMissing(a:list1, a:list2)
    let l:notIn1 = s:GetMissing(a:list2, a:list1)
    return [l:notIn2, l:notIn1]
endfunction

function! ingo#collections#differences#ContainsLoosely( list1, list2 )
"******************************************************************************
"* PURPOSE:
"   Test whether all elements in a:list2 are also contained in a:list1. Each
"   equal element need only be contained once.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:list1 A list that may contain all elements from a:list2.
"   a:list2 List where all elements may also be contained in a:list1.
"* RETURN VALUES:
"   1 if all elements from a:list2 are also contained in a:list1, 0 otherwise.
"******************************************************************************
    return empty(s:GetMissing(a:list2, a:list1))
endfunction
function! ingo#collections#differences#ContainsStrictly( list1, list2 )
"******************************************************************************
"* PURPOSE:
"   Test whether all elements in a:list2 are also contained in a:list1. Each
"   equal element must be contained at least as often.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:list1 A list that may contain all elements from a:list2.
"   a:list2 List where all elements may also be contained in a:list1.
"* RETURN VALUES:
"   1 if all elements from a:list2 are also contained in a:list1, 0 otherwise.
"******************************************************************************
    let l:copy = copy(a:list1)
    for l:item in a:list2
	let l:idx = index(l:copy, l:item)
	if l:idx == -1
	    return 0
	endif
	call remove(l:copy, l:idx)
    endfor
    return 1
endfunction

" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
autoload/ingo/collections/find.vim	[[[1
103
" ingo/collections/find.vim: Functions for finding values in collections.
"
" DEPENDENCIES:
"
" Copyright: (C) 2017 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>

function! ingo#collections#find#Extremes( expr1, Expr2 )
"******************************************************************************
"* PURPOSE:
"   Evaluate a:Expr2 on each item of a:expr1 into a number, and return those
"   element(s) that have the lowest and highest numbers.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:expr1 List or Dictionary to be searched.
"   a:Expr  Expression to be evaluated; v:val has the value of the current item.
"	    v:key is the key (Dictionary) / index (List) of the current item.
"	    If a:Expr is a Funcref it is called with the key / index and the
"	    value of the current item. (Like |map()|.)
"	    Should return a number.
"* RETURN VALUES:
"   [[lowestItem1, ...], [highestItem1, ...]
"******************************************************************************
    let l:evaluation = map(copy(a:expr1), a:Expr2)
    let [l:min, l:max] = [min(l:evaluation), max(l:evaluation)]

    if type(a:expr1) == type([])
	let [l:minList, l:maxList] = [[], []]
	let l:idx = 0
	while l:idx < len(a:expr1)
	    if l:evaluation[l:idx] == l:min
		call add(l:minList, a:expr1[l:idx])
	    endif
	    if l:evaluation[l:idx] == l:max
		call add(l:maxList, a:expr1[l:idx])
	    endif
	    let l:idx += 1
	endwhile
	return [l:minList, l:maxList]
    elseif type(a:expr1) == type({})
	let [l:minDict, l:maxDict] = [{}, {}]
	for l:key in keys(a:expr1)
	    if l:evaluation[l:key] == l:min
		let l:minDict[l:key] = a:expr1[l:key]
	    endif
	    if l:evaluation[l:key] == l:max
		let l:maxDict[l:key] = a:expr1[l:key]
	    endif
	endfor
	return [l:minDict, l:maxDict]
    else
	throw 'ASSERT: a:expr1 must be either List or Dictionary'
    endif
endfunction
function! ingo#collections#find#Lowest( expr1, Expr2 )
"******************************************************************************
"* PURPOSE:
"   Evaluate a:Expr2 on each item of a:expr1 into a number, and return those
"   element(s) that have the lowest numbers.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:expr1 List or Dictionary to be searched.
"   a:Expr  Expression to be evaluated; v:val has the value of the current item.
"	    v:key is the key (Dictionary) / index (List) of the current item.
"	    If a:Expr is a Funcref it is called with the key / index and the
"	    value of the current item. (Like |map()|.)
"	    Should return a number.
"* RETURN VALUES:
"   [lowestItem1, ...]
"******************************************************************************
    return ingo#collections#find#Extremes(a:expr1, a:Expr2)[0]
endfunction
function! ingo#collections#find#Highest( expr1, Expr2 )
"******************************************************************************
"* PURPOSE:
"   Evaluate a:Expr2 on each item of a:expr1 into a number, and return those
"   element(s) that have the lowest numbers.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:expr1 List or Dictionary to be searched.
"   a:Expr  Expression to be evaluated; v:val has the value of the current item.
"	    v:key is the key (Dictionary) / index (List) of the current item.
"	    If a:Expr is a Funcref it is called with the key / index and the
"	    value of the current item. (Like |map()|.)
"	    Should return a number.
"* RETURN VALUES:
"   [highestItem1, ...]
"******************************************************************************
    return ingo#collections#find#Extremes(a:expr1, a:Expr2)[1]
endfunction

" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
autoload/ingo/collections/fromsplit.vim	[[[1
102
" ingo/collections/fromsplit.vim: Functions to split a string and operate on the results.
"
" DEPENDENCIES:
"   - ingo/collections.vim autoload script
"   - ingo/list.vim autoload script
"
" Copyright: (C) 2016-2019 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>

function! ingo#collections#fromsplit#MapOne( isItems, expr, pattern, Expr2 )
"******************************************************************************
"* PURPOSE:
"   Split a:expr on a:pattern, then apply a:Expr2 over the List of items or
"   separators, depending on a:isItems, and return a List of [ item1,
"   delimiter1, item2, delimiter2, ...]
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:isItems   Flag whether separators (0) or items (1) are to be mapped.
"   a:expr	Text to be split.
"   a:pattern	Regular expression that specifies the separator text that
"		delimits the items.
"   a:Expr2     String or Funcref argument to |map()|.
"* RETURN VALUES:
"   Single list of split items and separators interspersed.
"******************************************************************************
    let l:result = ingo#collections#SeparateItemsAndSeparators(a:expr, a:pattern, 1)
    call map(l:result[! a:isItems], a:Expr2)
    return ingo#list#Join(l:result[0], l:result[1])
endfunction
function! ingo#collections#fromsplit#MapItems( expr, pattern, Expr2 )
"******************************************************************************
"* PURPOSE:
"   Split a:expr on a:pattern, then apply a:Expr2 over the List of items (i.e.
"   the elements in between the a:pattern matches), and return a List of [
"   mapped-item1, delimiter1, mapped-item2, delimiter2, ...]
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:expr	Text to be split.
"   a:pattern	Regular expression that specifies the separator text that
"		delimits the items.
"   a:Expr2     String or Funcref argument to |map()|.
"* RETURN VALUES:
"   Single list of split items and separators interspersed.
"******************************************************************************
    return ingo#collections#fromsplit#MapOne(1, a:expr, a:pattern, a:Expr2)
endfunction
function! ingo#collections#fromsplit#MapSeparators( expr, pattern, Expr2 )
"******************************************************************************
"* PURPOSE:
"   Split a:expr on a:pattern, then apply a:Expr2 over the List of separators
"   (i.e. the a:pattern matches), and return a List of [ item1,
"   mapped-delimiter1, item2, mapped-delimiter2, ...]
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:expr	Text to be split.
"   a:pattern	Regular expression that specifies the separator text that
"		delimits the items.
"   a:Expr2     String or Funcref argument to |map()|.
"* RETURN VALUES:
"   Single list of split items and separators interspersed.
"******************************************************************************
    return ingo#collections#fromsplit#MapOne(0, a:expr, a:pattern, a:Expr2)
endfunction
function! ingo#collections#fromsplit#MapItemsAndSeparators( expr, pattern, ItemExpr2, SeparatorExpr2 )
"******************************************************************************
"* PURPOSE:
"   Split a:expr on a:pattern, then apply a:ItemExpr2 over the List of items
"   (i.e. the elements in between the a:pattern matches) and apply
"   a:SeparatorExpr2 over the List of separators (i.e. the a:pattern matches),
"   and return a List of [ mapped-item1, mapped-delimiter1, mapped-item2,
"   mapped-delimiter2, ...]
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:expr	Text to be split.
"   a:pattern	Regular expression that specifies the separator text that
"		delimits the items.
"   a:ItemExpr2         String or Funcref argument to |map()|.
"   a:SeparatorExpr2    String or Funcref argument to |map()|.
"* RETURN VALUES:
"   Single list of split items and separators interspersed.
"******************************************************************************
    let l:result = ingo#collections#SeparateItemsAndSeparators(a:expr, a:pattern, 1)
    call map(l:result[0], a:ItemExpr2)
    call map(l:result[1], a:SeparatorExpr2)
    return ingo#list#Join(l:result[0], l:result[1])
endfunction

" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
autoload/ingo/collections/memoized.vim	[[[1
65
" ingo/collections/memoized.vim: Functions to operate on memoized collections.
"
" DEPENDENCIES:
"
" Copyright: (C) 2014 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
"
" REVISION	DATE		REMARKS
"	001	22-Oct-2014	file creation

let s:memoizedI = {}
let s:memoizedTime = -1
function! ingo#collections#memoized#Mapsort( string, i1, i2, ... )
"******************************************************************************
"* PURPOSE:
"   Like ingo#collections#mapsort(), but caches the mapped result in a temporary
"   Dictionary. This can speed up expensive maps (like using getftime()).
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:string  Vimscript expression to be evaluated over [a:i1, a:i2] via map().
"   i1, i2  Elements
"   a:options.cacheTimeInSeconds    Number of seconds until the cache is
"				    cleared. To make the cache apply only to the
"				    current sort(), choose a value that's
"				    slightly larger than the largest expected
"				    running time for a comparison.
"   a:options.maxCacheSize          Maximum number of items in the cache before
"				    it is cleared.
"* RETURN VALUES:
"   -1, 0 or 1, as specified by the sort() function.
"   Note: To reverse the sort order, just multiply this function's return value
"   with -1.
"******************************************************************************
    let l:options = (a:0 ? a:1 : {})

    if has_key(l:options, 'cacheTimeInSeconds') && localtime() - s:memoizedTime > l:options.cacheTimeInSeconds
	let s:memoizedI = {}
    elseif has_key(l:options, 'maxCacheSize') && len(s:memoizedI) > l:options.maxCacheSize
	let s:memoizedI = {}
    endif

    if has_key(s:memoizedI, a:i1)
	let l:i1 = s:memoizedI[a:i1]
    else
	let l:i1 = map([a:i1], a:string)[0]
	let s:memoizedI[a:i1] = l:i1
    endif
    if has_key(s:memoizedI, a:i2)
	let l:i2 = s:memoizedI[a:i2]
    else
	let l:i2 = map([a:i2], a:string)[0]
	let s:memoizedI[a:i2] = l:i2
    endif

    let s:memoizedTime = localtime()

    return l:i1 == l:i2 ? 0 : l:i1 > l:i2 ? 1 : -1
endfunction

" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
autoload/ingo/collections/permute.vim	[[[1
32
" ingo/collections/permute.vim: Functions to permute a List.
"
" DEPENDENCIES:
"
" Copyright: (C) 2014 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
"
" REVISION	DATE		REMARKS
"   1.021.001	27-Jun-2014	file creation

function! ingo#collections#permute#Shuffle( list, Rand )
    " Fisher-Yates shuffle
    let [l:list, l:len] = [a:list, len(a:list)]

    let i = l:len
    while i > 0
        let i -= 1
        let j = a:Rand() * i % l:len
        if i == j
            continue
        endif
        let l:swap = l:list[i]
        let l:list[i] = list[j]
        let l:list[j] = l:swap
    endwhile

    return l:list
endfunction

" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
autoload/ingo/collections/recursive.vim	[[[1
29
" ingo/collections/recursive.vim: Recursively map a data structure.
"
" DEPENDENCIES:
"
" Copyright: (C) 2019 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>

function! ingo#collections#recursive#map( expr1, expr2 )
    return s:Map(0, a:expr1, a:expr2)
endfunction
function! ingo#collections#recursive#MapWithCopy( expr1, expr2 )
    return s:Map(1, copy(a:expr1), a:expr2)
endfunction
function! s:Map( isCopy, expr1, expr2 )
    return map(a:expr1, 's:RecursiveMap(a:isCopy, v:val, a:expr2)')
endfunction
function! s:RecursiveMap( isCopy, value, expr2 )
    let l:value = (a:isCopy ? copy(a:value) : a:value)

    if type(a:value) == type([]) || type(a:value) == type({})
	return s:Map(a:isCopy, l:value, a:expr2)
    else
	return map([l:value], a:expr2)[0]
    endif
endfunction

" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
autoload/ingo/collections/rotate.vim	[[[1
20
" ingo/collections/rotate.vim: Functions to rotate items in a List.
"
" DEPENDENCIES:
"
" Copyright: (C) 2013 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
"
" REVISION	DATE		REMARKS
"   1.006.001	25-May-2013	file creation

function! ingo#collections#rotate#Right( list )
    return insert(a:list, remove(a:list, -1))
endfunction
function! ingo#collections#rotate#Left( list )
    return add(a:list, remove(a:list, 0))
endfunction

" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
autoload/ingo/collections/unique.vim	[[[1
141
" ingo/collections/unique.vim: Functions to create and operate on unique collections.
"
" DEPENDENCIES:
"
" Copyright: (C) 2013-2016 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
"
" REVISION	DATE		REMARKS
"   1.025.003	17-Feb-2016	Add ingo#collections#unique#Insert() and
"				ingo#collections#unique#Add().
"   1.010.002	03-Jul-2013	Add ingo#collections#unique#AddNew() and
"				ingo#collections#unique#InsertNew().
"   1.009.001	25-Jun-2013	file creation

function! ingo#collections#unique#MakeUnique( memory, expr )
"******************************************************************************
"* PURPOSE:
"   Based on the a:memory lookup, create a unique String from a:expr by
"   appending a running counter to it.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   Adds the unique returned result to a:memory.
"* INPUTS:
"   a:memory    Dictionary holding the existing values as keys.
"   a:expr      String that is made unique with regards to a:memory and
"		returned.
"* RETURN VALUES:
"   a:expr (when it's not yet contained in the a:memory), or a unique version of
"   it.
"******************************************************************************
    let l:result = a:expr
    let l:counter = 0
    while has_key(a:memory, l:result)
	let l:counter += 1
	let l:result = printf('%s%s(%d)', a:expr, (empty(a:expr) ? '' : ' '), l:counter)
    endwhile

    let a:memory[l:result] = 1
    return l:result
endfunction

function! ingo#collections#unique#AddNew( list, expr )
"******************************************************************************
"* PURPOSE:
"   Append a:expr to a:list when it's not already contained.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:list  List to be modified.
"   a:expr  Item to be added.
"* RETURN VALUES:
"   a:list
"******************************************************************************
    return ingo#collections#unique#InsertNew(a:list, a:expr, len(a:list))
endfunction
function! ingo#collections#unique#InsertNew( list, expr, ... )
"******************************************************************************
"* PURPOSE:
"   Insert a:expr at the start of a:list when it's not already contained.
"   If a:idx is specified insert a:expr before the item with index a:idx.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:list  List to be modified.
"   a:expr  Item to be added.
"   a:idx   Optional index before which a:expr is inserted.
"* RETURN VALUES:
"   a:list
"******************************************************************************
    if index(a:list, a:expr) == -1
	return call('insert', [a:list, a:expr] + a:000)
    else
	return a:list
    endif
endfunction

function! ingo#collections#unique#ExtendWithNew( expr1, expr2, ... )
"******************************************************************************
"* PURPOSE:
"   Append all items from a:expr2 that are not yet contained in a:expr1 to it.
"   If a:expr3 is given insert the items of a:expr2 before item a:expr3 in
"   a:expr1. When a:expr3 is zero insert before the first item.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"* RETURN VALUES:
"   Returns the modified a:expr1.
"******************************************************************************
    let l:newItems = filter(copy(a:expr2), 'index(a:expr1, v:val) == -1')
    return call('extend', [a:expr1, l:newItems] + a:000)
endfunction

function! ingo#collections#unique#Insert( list, expr, ... )
"******************************************************************************
"* PURPOSE:
"   Insert a:expr at the start of a:list (if a:idx is specified before the item
"   with index a:idx), and remove any other elements equal to a:expr from the
"   list (which effectively moves a:expr to the front).
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:list  List to be modified.
"   a:expr  Item to be added.
"   a:idx   Optional index before which a:expr is inserted.
"* RETURN VALUES:
"   a:list
"******************************************************************************
    call filter(a:list, 'v:val isnot# a:expr')
    return call('insert', [a:list, a:expr] + a:000)
endfunction
function! ingo#collections#unique#Add( list, expr )
"******************************************************************************
"* PURPOSE:
"   Append a:expr to a:list, and remove any other elements equal to a:expr from
"   the list (which effectively moves a:expr to the back).
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:list  List to be modified.
"   a:expr  Item to be added.
"* RETURN VALUES:
"   a:list
"******************************************************************************
    call filter(a:list, 'v:val isnot# a:expr')
    return add(a:list, a:expr)
endfunction

" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
autoload/ingo/comments.vim	[[[1
366
" ingo/comments.vim: Functions around comment handling.
"
" DEPENDENCIES:
"   - ingo/compat.vim autoload script
"
" Copyright: (C) 2011-2019 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>

function! s:CommentDefinitions()
    return map(split(&l:comments, ','), 'matchlist(v:val, ''\([^:]*\):\(.*\)'')[1:2]')
endfunction

function! s:IsPrefixMatch( string, prefix )
    return strpart(a:string, 0, len(a:prefix)) ==# a:prefix
endfunction

function! ingo#comments#CheckComment( text, ... )
"******************************************************************************
"* PURPOSE:
"   Check whether a:text is a comment according to 'comments' definitions.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:text	The text to be checked. If the "b" flag is contained in
"		'comments', the proper whitespace must exist.
"   a:options.isIgnoreIndent	Flag; unless set (the default), there must
"				either be no leading whitespace or exactly the
"				amount mandated by the indent of a three-piece
"				comment.
"   a:options.isStripNonEssentialWhiteSpaceFromCommentString
"				Flag; if set (the default), any trailing
"				whitespace in the returned commentstring (e.g.
"				often indent in the middle part of a
"				three-piece) is stripped.
"* RETURN VALUES:
"   [] if a:text is not a comment.
"   [commentstring, type, nestingLevel, isBlankRequired] if a:text is a comment.
"	commentstring is the found comment prefix; if an offset was defined,
"	this is included.
"	type is empty for a normal comment leader, and either "s", "m" or "e"
"	for a three-piece comment.
"	nestingLevel is > 0 if the "n" flag is contained in 'comments' and
"	indicates the number of nested comments. Only repetitive same comments
"	are counted for nesting.
"	isBlankRequired is a boolean flag
"******************************************************************************
    let l:options = (a:0 ? a:1 : {})
    let l:isIgnoreIndent = get(l:options, 'isIgnoreIndent', 1)
    let l:isStripNonEssentialWhiteSpaceFromCommentString = get(l:options, 'isStripNonEssentialWhiteSpaceFromCommentString', 1)

    let l:text = (l:isIgnoreIndent ? substitute(a:text, '^\s*', '', '') : a:text)

    for [l:flags, l:string] in s:CommentDefinitions()
	if l:flags =~# '[se]'
	    if l:flags =~# '[se].*\d' && l:flags !~# '-\d'
		if l:isIgnoreIndent
		    let l:threePieceOffset = ''
		else
		    " Consider positive offset for the middle of a three-piece
		    " comment when matching with a:text.
		    let l:threePieceOffset = repeat(' ', matchstr(l:flags, '\d\+'))
		endif
	    elseif l:flags =~# 's'
		" Clear any offset from previous three-piece comment.
		let l:threePieceOffset = ''
	    endif
	endif
	" TODO: Handle "r" right-align flag through offset, too.

	let l:commentstring = ''
	if s:IsPrefixMatch(l:text, l:string)
	    let l:commentstring = l:string
	elseif (l:flags =~# '[me]' && ! empty(l:threePieceOffset) && s:IsPrefixMatch(l:text, l:threePieceOffset . l:string))
	    let l:commentstring = l:threePieceOffset . l:string
	endif
	if ! empty(l:commentstring)
	    let l:isBlankRequired = (l:flags =~# 'b')
	    if l:isBlankRequired && l:text[stridx(l:text, l:string) + len(l:string)] !~# '\s'
		" The whitespace after the comment is missing.
		continue
	    endif

	    let l:nestingLevel = 0
	    if l:flags =~# 'n'
		let l:comments = matchstr(l:text, '\V\C\^\s\*\zs\%(' . escape(l:string, '\') . '\s' . (l:isBlankRequired ? '\+' : '\*') . '\)\+')
		let l:nestingLevel = strlen(substitute(l:comments, '\V\C' . escape(l:string, '\') . '\s\*', 'x', 'g'))
	    endif

	    if l:isStripNonEssentialWhiteSpaceFromCommentString
		let l:commentstring = substitute(l:commentstring, '\s*$', '', '')
	    endif
	    return [l:commentstring, matchstr(l:flags, '\C[sme]'), l:nestingLevel, l:isBlankRequired]
	endif
    endfor

    return []
endfunction

function! s:AvoidDuplicateIndent( commentstring, text )
    " When the text starts with indent identical to what 'commentstring' would
    " render, avoid having duplicate indent.
    let l:renderedIndent = matchstr(a:commentstring, '\s\+\ze%s')
    return (a:text =~# '^\V' . l:renderedIndent ? strpart(a:text, len(l:renderedIndent)) : a:text)
endfunction
function! ingo#comments#RenderComment( text, checkComment )
"******************************************************************************
"* PURPOSE:
"   Render a:text as a comment.
"* ASSUMPTIONS / PRECONDITIONS:
"   Uses comment format from 'commentstring', if defined.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:text  The text to be rendered.
"   a:checkComment  Comment information returned by ingo#comments#CheckComment().
"* RETURN VALUES:
"   Returns a:text unchanged if a:checkComment is empty.
"   Otherwise, returns a:text rendered as a comment (as good as it can).
"******************************************************************************
    if empty(a:checkComment)
	return a:text
    endif

    let [l:commentprefix, l:type, l:nestingLevel, l:isBlankRequired] = a:checkComment

    if &commentstring =~# '\V\C' . escape(l:commentprefix, '\') . (l:isBlankRequired ? '\s' : '')
	" The found comment is the same as 'commentstring' will generate.
	" Generate with the proper nesting.
	let l:render = s:AvoidDuplicateIndent(&commentstring, a:text)
	for l:ii in range(max([1, l:nestingLevel]))
	    let l:render = printf(&commentstring, l:render)
	endfor
	return l:render
    elseif ! empty(&commentstring)
	" No match, just use 'commentstring'.
	return printf(&commentstring, s:AvoidDuplicateIndent(&commentstring, a:text))
    else
	" No 'commentstring' defined, use same comment prefix.
	return repeat(l:commentprefix . (l:isBlankRequired ? ' ' : ''), max([1, l:nestingLevel])) . (l:isBlankRequired ? '' : ' ') . s:AvoidDuplicateIndent(' %s', a:text)
    endif
endfunction

function! ingo#comments#RemoveCommentPrefix( line )
"******************************************************************************
"* PURPOSE:
"   Remove the comment prefix from a:line while keeping the overall indent.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:line  The text of the line to be rendered comment-less.
"* RETURN VALUES:
"   Return a:line rendered with the comment prefix erased and replaced by the
"   appropriate whitespace.
"******************************************************************************
    let l:checkComment = ingo#comments#CheckComment(a:line)
    if empty(l:checkComment)
	return a:line
    endif

    let [l:indentWithCommentPrefix, l:text] = s:SplitIndentAndText(a:line, l:checkComment)
    let l:indentNum = ingo#compat#strdisplaywidth(l:indentWithCommentPrefix)

    let l:indent = repeat(' ', l:indentNum)
    if ! &l:expandtab
	let l:indent = substitute(l:indent, ' \{' . &l:tabstop . '}', '\t', 'g')
    endif
    return l:indent . l:text
endfunction
function! ingo#comments#GetSplitIndentPattern( minNumberOfCommentPrefixesExpr, lineOrStartLnum, ... )
"******************************************************************************
"* PURPOSE:
"   Analyze a:line (or the a:startLnum, a:endLnum range of lines in the current
"   buffer) and generate a regular expression that matches possible indent with
"   comment prefix. If there's no comment, just match indent.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:minNumberOfCommentPrefixesExpr    Number of comment prefixes (if any are
"                                       detected) that must exist. If empty, the
"                                       exact number of detected (nested)
"                                       comment prefixes has to exist. If 1, at
"                                       least one comment prefix has to exist.
"                                       If 0, indent and comment prefixes are
"                                       purely optional; the returned pattern
"                                       may match nothing at all at the
"                                       beginning of a line.
"   a:line  The line to be analyzed for splitting, or:
"   a:startLnum First line number in the current buffer to be analyzed.
"   a:endLnum   Last line number in the current buffer to be analyzed; the first
"               line in the range that has a comment prefix is used.
"* RETURN VALUES:
"   Regular expression matching the indent plus potential comment prefix,
"   anchored to the start of a line.
"******************************************************************************
    if a:0
	for l:lnum in range(a:lineOrStartLnum, a:1)
	    let l:checkComment = ingo#comments#CheckComment(getline(l:lnum))
	    if ! empty(l:checkComment)
		return s:GetSplitIndentPattern(l:checkComment, a:minNumberOfCommentPrefixesExpr)
	    endif
	endfor
	return s:GetSplitIndentPattern([], a:minNumberOfCommentPrefixesExpr)
    else
	return s:GetSplitIndentPattern(ingo#comments#CheckComment(a:lineOrStartLnum), a:minNumberOfCommentPrefixesExpr)
    endif
endfunction
function! ingo#comments#SplitIndentAndText( line )
"******************************************************************************
"* PURPOSE:
"   Split the line into any leading indent before the comment prefix plus the
"   prefix itself plus indent after it, and the text after it. If there's no
"   comment, split indent from text.
"* SEE ALSO:
"   ingo#indent#Split() directly takes a line number and does not consider
"   comment prefixes.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:line  The line to be split.
"* RETURN VALUES:
"   Returns [indent, text].
"******************************************************************************
    return s:SplitIndentAndText(a:line, ingo#comments#CheckComment(a:line))
endfunction
function! s:GetSplitIndentPattern( checkComment, ... )
    let l:minNumberOfCommentPrefixesExpr = (a:0 && a:1 isnot# '' ? a:1 . ',' : '')
    if empty(a:checkComment)
	return '^\%(\s*\)'
    endif

    let [l:commentprefix, l:type, l:nestingLevel, l:isBlankRequired] = a:checkComment

    return '\V\C\^' .
    \   '\s\*\%(' . escape(l:commentprefix, '\') . (l:isBlankRequired ? '\s\+' : '\s\*'). '\)\{' . l:minNumberOfCommentPrefixesExpr . max([1, l:nestingLevel]) . '}' .
    \   '\m'
endfunction
function! s:GetSplitIndentAndTextPattern( checkComment )
    return '\(' . s:GetSplitIndentPattern(a:checkComment) . '\)\(.*\)$'
endfunction
function! s:SplitIndentAndText( line, checkComment )
    return matchlist(a:line, s:GetSplitIndentAndTextPattern(a:checkComment))[1:2]
endfunction
function! ingo#comments#SplitAll( line )
"******************************************************************************
"* PURPOSE:
"   Split the line into any leading indent before the comment prefix, the prefix
"   (-es, if nested) itself, indent after it, and the text after it. If there's
"   no comment, split indent from text.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:line  The line to be split.
"* RETURN VALUES:
"   Returns [indentBefore, commentPrefix, indentAfter, text, isBlankRequired].
"******************************************************************************
    let l:checkComment = ingo#comments#CheckComment(a:line)
    if empty(l:checkComment)
	let l:split = matchlist(a:line, '^\(\s*\)\(.*\)$')[1:2]
	return [l:split[0], '', '', l:split[1], 0]
    endif

    let [l:commentprefix, l:type, l:nestingLevel, l:isBlankRequired] = l:checkComment

    return matchlist(
    \   a:line,
    \   '\V\C\^\(\s\*\)\(' .
    \       (l:nestingLevel > 1 ?
    \           '\%(' . escape(l:commentprefix, '\') . (l:isBlankRequired ? '\s\+' : '\s\*') . '\)\{' . l:nestingLevel . '}\)' :
    \           ''
    \       ) . escape(l:commentprefix, '\') . '\)' .
    \       '\(\s\*\)' .
    \       '\(\.\*\)\$'
    \)[1:4] + [l:isBlankRequired]
endfunction

function! ingo#comments#GetCommentPrefixType( prefix )
"******************************************************************************
"* PURPOSE:
"   Check whether a:prefix is a comment leader as defined in 'comments'.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:prefix	Text to be checked for being a comment prefix. There must either
"		be no leading whitespace or exactly the amount mandated by the
"		indent of a three-piece comment. No blank is required in
"		a:prefix, even if the "b" flag is contained in 'comments', so
"		this function can be used for checking as-you-type.
"* RETURN VALUES:
"   [] if a:prefix is not a comment leader.
"   [type, isBlankRequired] if a:prefix is a comment leader.
"	type is empty for a normal comment leader, and either "s", "m" or "e"
"	for a three-piece comment.
"	isBlankRequired is a boolean flag
"******************************************************************************
    for [l:flags, l:string] in s:CommentDefinitions()
	if l:flags =~# '[se]'
	    if l:flags =~# '[se].*\d' && l:flags !~# '-\d'
		" Consider positive offset for the middle of a three-piece
		" comment when matching with a:prefix.
		let l:threePieceOffset = repeat(' ', matchstr(l:flags, '\d\+'))
	    elseif l:flags =~# 's'
		" Clear any offset from previous three-piece comment.
		let l:threePieceOffset = ''
	    endif
	endif
	" TODO: Handle "r" right-align flag through offset, too.

	if a:prefix ==# l:string || (l:flags =~# '[me]' && a:prefix ==# (l:threePieceOffset . l:string))
	    return [matchstr(l:flags, '\C[sme]'), (l:flags =~# 'b')]
	endif
    endfor

    return []
endfunction

function! ingo#comments#GetThreePieceIndent( prefix )
"******************************************************************************
"* PURPOSE:
"   Check whether a:prefix is a comment leader of a three-piece comment as
"   defined in 'comments', and return the indent in case of a middle or end
"   comment prefix.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:prefix	Text that may be a comment prefix. Must not include leading or
"		trailing whitespace, only the actual comment characters.
"* RETURN VALUES:
"   Indent, or 0.
"******************************************************************************
    let l:threePieceOffset = 0
    for [l:flags, l:string] in s:CommentDefinitions()
	if l:flags =~# '[se]'
	    if l:flags =~# '[se].*\d' && l:flags !~# '-\d'
		" Extract positive offset for the middle or end of a three-piece
		" comment.
		let l:threePieceOffset = matchstr(l:flags, '\d\+')
	    elseif l:flags =~# 's'
		" Clear any offset from previous three-piece comment.
		let l:threePieceOffset = 0
	    endif
	endif
	if l:flags =~# '[me]' && a:prefix ==# l:string
	    return l:threePieceOffset
	endif
    endfor

    return 0
endfunction

" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
autoload/ingo/comments/indent.vim	[[[1
56
" ingo/comments/indent.vim: Functions for indents around commented lines.
"
" DEPENDENCIES:
"
" Copyright: (C) 2019 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>

function! ingo#comments#indent#Total( line ) abort
"******************************************************************************
"* PURPOSE:
"   Returns the sum of leading indent, the width of the comment prefix plus the
"   indent after it (counted in screen cells). Like indent(), but considers a
"   comment prefix as well. If there's no comment, just returns the ordinary
"   indent.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:line  The line to be analyzed.
"* RETURN VALUES:
"   Indent counted in spaces.
"******************************************************************************
    return ingo#compat#strdisplaywidth(ingo#comments#SplitIndentAndText(a:line)[0])
endfunction

function! ingo#comments#indent#AfterComment( line ) abort
"******************************************************************************
"* PURPOSE:
"   Returns the width of the comment prefix plus the indent after it (counted in
"   screen cells). Like indent(), but only for the stuff after the comment
"   prefix (including the prefix itself). If there's no comment, just returns
"   the ordinary indent.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:line  The line to be analyzed.
"* RETURN VALUES:
"   Indent counted in spaces.
"******************************************************************************
    let [l:indentBefore, l:commentPrefix, l:indentAfter, l:text, l:isBlankRequired] = ingo#comments#SplitAll(a:line)

    let l:beforeWidth = ingo#compat#strdisplaywidth(l:indentBefore)
    if empty(l:commentPrefix . l:indentAfter)
	return l:beforeWidth
    endif

    let l:totalWidth = ingo#compat#strdisplaywidth(l:indentBefore . l:commentPrefix . l:indentAfter)
    return l:totalWidth - l:beforeWidth
endfunction

" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
autoload/ingo/compat.vim	[[[1
507
" ingo/compat.vim: Functions for backwards compatibility with old Vim versions.
"
" DEPENDENCIES:
"   - ingo/collections.vim autoload script
"   - ingo/list.vim autoload script
"   - ingo/option.vim autoload script
"   - ingo/os.vim autoload script
"   - ingo/strdisplaywidth.vim autoload script
"
" Copyright: (C) 2013-2019 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>

let s:compatFor = (exists('g:IngoLibrary_CompatFor') ? ingo#collections#ToDict(split(g:IngoLibrary_CompatFor, ',')) : {})

if exists('*shiftwidth') && ! has_key(s:compatFor, 'shiftwidth')
    function! ingo#compat#shiftwidth()
	return shiftwidth()
    endfunction
else
    function! ingo#compat#shiftwidth()
	return &shiftwidth
    endfunction
endif

if exists('*strdisplaywidth') && ! has_key(s:compatFor, 'strdisplaywidth')
    function! ingo#compat#strdisplaywidth( expr, ... )
	return call('strdisplaywidth', [a:expr] + a:000)
    endfunction
else
    function! ingo#compat#strdisplaywidth( expr, ... )
	let l:expr = (a:0 ? repeat(' ', a:1) . a:expr : a:expr)
	let i = 1
	while 1
	    if ! ingo#strdisplaywidth#HasMoreThan(l:expr, i)
		return i - (a:0 ? a:1 : 0)
	    endif
	    let i += 1
	endwhile
    endfunction
endif

if exists('*strchars') && ! has_key(s:compatFor, 'strchars')
    if v:version == 704 && has('patch755') || v:version > 704
	function! ingo#compat#strchars( ... )
	    return call('strchars', a:000)
	endfunction
    else
	function! ingo#compat#strchars( expr, ... )
	    return (a:0 && a:1 ? strlen(substitute(a:expr, ".", "x", "g")) : strchars(a:expr))
	endfunction
    endif
else
    function! ingo#compat#strchars( expr, ... )
	return len(split(a:expr, '\zs'))
    endfunction
endif

if exists('*strgetchar') && ! has_key(s:compatFor, 'strgetchar')
    function! ingo#compat#strgetchar( expr, index )
	return strgetchar(a:expr, a:index)
    endfunction
else
    function! ingo#compat#strgetchar( expr, index )
	return char2nr(matchstr(a:expr, '.\{' . a:index . '}\zs.'))
    endfunction
endif

if exists('*strcharpart') && ! has_key(s:compatFor, 'strcharpart')
    function! ingo#compat#strcharpart( ... )
	return call('strcharpart', a:000)
    endfunction
else
    function! ingo#compat#strcharpart( src, start, ... )
	let [l:start, l:len] = [a:start, a:0 ? a:1 : 0]
	if l:start < 0
	    let l:len += l:start
	    let l:start = 0
	endif

	return matchstr(a:src, '.\{' . l:start . '}\zs.' . (a:0 ? '\{,' . max([0, l:len]) . '}' : '*'))
    endfunction
endif

if exists('*abs') && ! has_key(s:compatFor, 'abs')
    function! ingo#compat#abs( expr )
	return abs(a:expr)
    endfunction
else
    function! ingo#compat#abs( expr )
	return (a:expr < 0 ? -1 : 1) * a:expr
    endfunction
endif

if exists('*uniq') && ! has_key(s:compatFor, 'uniq')
    function! ingo#compat#uniq( list )
	return uniq(a:list)
    endfunction
else
    function! ingo#compat#uniq( list )
	return ingo#collections#UniqueSorted(a:list)
    endfunction
endif

if exists('*getcurpos') && ! has_key(s:compatFor, 'getcurpos')
    function! ingo#compat#getcurpos()
	return getcurpos()
    endfunction
else
    function! ingo#compat#getcurpos()
	return getpos('.')
    endfunction
endif

if exists('*systemlist') && ! has_key(s:compatFor, 'systemlist')
    function! ingo#compat#systemlist( ... )
	return call('systemlist', a:000)
    endfunction
else
    function! ingo#compat#systemlist( ... )
	return split(call('system', a:000), '\n')
    endfunction
endif

if exists('*haslocaldir') && ! has_key(s:compatFor, 'haslocaldir')
    function! ingo#compat#haslocaldir()
	return haslocaldir()
    endfunction
else
    function! ingo#compat#haslocaldir()
	return 0
    endfunction
endif

if exists('*execute') && ! has_key(s:compatFor, 'execute')
    function! ingo#compat#execute( ... )
	return call('execute', a:000)
    endfunction
else
    function! ingo#compat#execute( command, ... )
	let l:prefix = (a:0 ? a:1 : 'silent')
	let l:output = ''
	try
	    redir => l:output
		for l:command in ingo#list#Make(a:command)
		    execute l:prefix l:command
		endfor
	    redir END
	    redraw	" This is necessary because of the :redir done earlier.
	finally
	    redir END
	endtry

	return l:output
    endfunction
endif

if exists('*trim') && ! has_key(s:compatFor, 'trim')
    function! ingo#compat#trim( ... )
	return call('trim', a:000)
    endfunction
else
    function! ingo#compat#trim( text, ... )
	let l:mask = (a:0 ? a:1 : "\x01\x02\x03\x04\x05\x06\x07\x08\t\n\x0b\x0c\r\x0e\x0f\x10\x11\x12\x13\x14\x15\x16\x17\x18\x19\x1a\x1b\x1c\x1d\x1e\x1f \xa0")
	let l:text = a:text

	while ! empty(a:text)
	    let [l:head, l:rest] = matchlist(l:text, '^\(.\)\(.*\)$')[1:2]
	    if stridx(l:mask, l:head) == -1
		break
	    endif

	    let l:text = l:rest
	endwhile

	while ! empty(a:text)
	    let [l:rest, l:tail] = matchlist(l:text, '^\(.*\)\(.\)$')[1:2]
	    if stridx(l:mask, l:tail) == -1
		break
	    endif

	    let l:text = l:rest
	endwhile

	return l:text
    endfunction
endif

function! ingo#compat#fnameescape( filespec )
"*******************************************************************************
"* PURPOSE:
"   Escape a normal filespec syntax so that it can be used in Ex commands.
"* ASSUMPTIONS / PRECONDITIONS:
"	? List of any external variable, control, or other element whose state affects this procedure.
"* EFFECTS / POSTCONDITIONS:
"	? List of the procedure's effect on each external variable, control, or other element.
"* INPUTS:
"   a:filespec	    normal filespec
"* RETURN VALUES:
"   Escaped filespec to be passed as a {file} argument to an Ex command.
"*******************************************************************************
    if exists('*fnameescape') && ! has_key(s:compatFor, 'fnameescape')
	if ingo#os#IsWindows()
	    let l:filespec = a:filespec

	    " XXX: fnameescape() on Windows mistakenly escapes the "!"
	    " character, which makes Vim treat the "foo!bar" filespec as if a
	    " file "!bar" existed in an intermediate directory "foo". Cp.
	    " http://article.gmane.org/gmane.editors.vim.devel/22421
	    let l:filespec = substitute(fnameescape(l:filespec), '\%(\%(^\|[^\\]\)\%(\\\\\)*\\\)\@<!\\!', '!', 'g')

	    " XXX: fnameescape() on Windows does not escape the "[" character
	    " (like on Linux), but Windows understands this wildcard and expands
	    " it to an existing file. As escaping with \ does not work (it is
	    " treated like a path separator), turn this into the neutral [[],
	    " but only if the file actually exists.
	    if a:filespec =~# '\[[^/\\]\+\]' && filereadable(fnamemodify(a:filespec, ':p')) " Need to expand to absolute path (but not use expand() because of the glob!) because filereadable() does not understand stuff like "~/...".
		let l:filespec = substitute(l:filespec, '\[', '[[]', 'g')
	    endif

	    return l:filespec
	else
	    return fnameescape(a:filespec)
	endif
    else
	" Note: On Windows, backslash path separators and some other Unix
	" shell-specific characters mustn't be escaped.
	return escape(a:filespec, " \t\n*?`%#'\"|<" . (ingo#os#IsWinOrDos() ? '' : '![{$\'))
    endif
endfunction

function! ingo#compat#shellescape( filespec, ... )
"*******************************************************************************
"* PURPOSE:
"   Escape a normal filespec syntax so that it can be used in shell commands.
"   The filespec will be quoted properly.
"   When the {special} argument is present and it's a non-zero Number, then
"   special items such as "!", "%", "#" and "<cword>" will be preceded by a
"   backslash.  This backslash will be removed again by the |:!| command.
"
"* ASSUMPTIONS / PRECONDITIONS:
"	? List of any external variable, control, or other element whose state affects this procedure.
"* EFFECTS / POSTCONDITIONS:
"	? List of the procedure's effect on each external variable, control, or other element.
"* INPUTS:
"   a:filespec	    normal filespec
"   a:special	    Flag whether special items will be escaped, too.
"
"* RETURN VALUES:
"   Escaped filespec to be used in a :! command or inside a system() call.
"*******************************************************************************
    let l:isSpecial = (a:0 ? a:1 : 0)
    let l:specialShellescapeCharacters = "\n%#'!"
    if exists('*shellescape') && ! has_key(s:compatFor, 'shellescape')
	if a:0
	    if v:version < 702
		" The shellescape({string}) function exists since Vim 7.0.111,
		" but shellescape({string}, {special}) was only introduced with
		" Vim 7.2. Emulate the two-argument function by (crudely)
		" escaping special characters for the :! command.
		return shellescape((l:isSpecial ? escape(a:filespec, l:specialShellescapeCharacters) : a:filespec))
	    else
		return shellescape(a:filespec, l:isSpecial)
	    endif
	else
	    return shellescape(a:filespec)
	endif
    else
	let l:escapedFilespec = (l:isSpecial ? escape(a:filespec, l:specialShellescapeCharacters) : a:filespec)

	if ingo#os#IsWinOrDos()
	    return '"' . l:escapedFilespec . '"'
	else
	    return "'" . l:escapedFilespec . "'"
	endif
    endif
endfunction

if v:version == 704 && has('patch279') || v:version > 704
    " This one has both {nosuf} and {list}.
    function! ingo#compat#glob( ... )
	return call('glob', a:000)
    endfunction
    function! ingo#compat#globpath( ... )
	return call('globpath', a:000)
    endfunction
elseif v:version == 703 && has('patch465') || v:version > 703
    " This one has glob() with both {nosuf} and {list}.
    function! ingo#compat#glob( ... )
	return call('glob', a:000)
    endfunction
    function! ingo#compat#globpath( ... )
	let l:list = (a:0 > 3 && a:4)
	let l:result = call('globpath', a:000[0:2])
	return (l:list ? split(l:result, '\n') : l:result)
    endfunction
elseif v:version == 702 && has('patch051') || v:version > 702
    " This one has {nosuf}.
    function! ingo#compat#glob( ... )
	let l:list = (a:0 > 2 && a:3)
	let l:result = call('glob', a:000[0:1])
	return (l:list ? split(l:result, '\n') : l:result)
    endfunction
    function! ingo#compat#globpath( ... )
	let l:list = (a:0 > 3 && a:4)
	let l:result = call('globpath', a:000[0:2])
	return (l:list ? split(l:result, '\n') : l:result)
    endfunction
else
    " This one has neither {nosuf} nor {list}.
    function! ingo#compat#glob( ... )
	let l:nosuf = (a:0 > 1 && a:2)
	let l:list = (a:0 > 2 && a:3)

	if l:nosuf
	    let l:save_wildignore = &wildignore
	    set wildignore=
	endif
	try
	    let l:result = call('glob', [a:1])
	    return (l:list ? split(l:result, '\n') : l:result)
	finally
	    if exists('l:save_wildignore')
		let &wildignore = l:save_wildignore
	    endif
	endtry
    endfunction
    function! ingo#compat#globpath( ... )
	let l:nosuf = (a:0 > 2 && a:3)
	let l:list = (a:0 > 3 && a:4)

	if l:nosuf
	    let l:save_wildignore = &wildignore
	    set wildignore=
	endif
	try
	    let l:result = call('globpath', a:000[0:1])
	    return (l:list ? split(l:result, '\n') : l:result)
	finally
	    if exists('l:save_wildignore')
		let &wildignore = l:save_wildignore
	    endif
	endtry
    endfunction
endif

if (v:version == 703 && has('patch32') || v:version > 703) && ! has_key(s:compatFor, 'maparg')
    function! ingo#compat#maparg( name, ... )
	let l:args = [a:name, '', 0, 1]
	if a:0 > 0
	    let l:args[1] = a:1
	endif
	if a:0 > 1
	    let l:args[2] = a:2
	endif
	let l:mapInfo = call('maparg', l:args)

	" Contrary to the old maparg(), <SID> doesn't get automatically
	" translated into <SNR>NNN_ here.
	return substitute(l:mapInfo.rhs, '\c<SID>', '<SNR>' . l:mapInfo.sid . '_', 'g')
    endfunction
else
    function! ingo#compat#maparg( name, ... )
	let l:rhs = call('maparg', [a:name] + a:000)
	let l:rhs = substitute(l:rhs, '\%(\%(^\|[^\\]\)\%(\\\\\)*\\\)\@<!\\\zs<\|<\%([^<]\+>\)\@!', '<lt>', 'g')    " Escape stand-alone < (when not part of a key-notation), or when escaped \<, but not proper key-notation like <C-CR>.
	let l:rhs = substitute(l:rhs, '|', '<Bar>', 'g')    " '|' must be escaped, or the map command will end prematurely.
	return l:rhs
    endfunction
endif

if (v:version == 703 && has('patch590') || v:version > 703) && ! has_key(s:compatFor, 'setpos')
    function! ingo#compat#setpos( expr, list )
	return setpos(a:expr, a:list)
    endfunction
else
    function! s:IsOnOrAfter( pos1, pos2 )
	return (a:pos2[1] > a:pos1[1] || a:pos2[1] == a:pos1[1] && a:pos2[2] >= a:pos1[2])
    endfunction
    function! ingo#compat#setpos( expr, list )
	" Vim versions before 7.3.590 cannot set the selection directly.
	let l:save_cursor = getpos('.')
	if a:expr ==# "'<"
	    let l:status = setpos('.', a:list)
	    if l:status != 0 | return l:status | endif
	    if s:IsOnOrAfter(a:list, getpos("'>"))
		execute "normal! vg`>\<Esc>"
	    else
		" We cannot maintain the position of the end of the selection,
		" as it is _before_ the new start, and would therefore make Vim
		" swap the two mark positions.
		execute "normal! v\<Esc>"
	    endif
	    call setpos('.', l:save_cursor)
	    return 0
	elseif a:expr ==# "'>"
	    if &selection ==# 'exclusive' && ! ingo#option#ContainsOneOf(&virtualedit, ['all', 'onemore'])
		" We may have to select the last character in a line.
		let l:save_virtualedit = &virtualedit
		set virtualedit=onemore
	    endif
	    try
		let l:status = setpos('.', a:list)
		if l:status != 0 | return l:status | endif
		if s:IsOnOrAfter(getpos("'<"), a:list)
		    execute "normal! vg`<o\<Esc>"
		else
		    " We cannot maintain the position of the start of the selection,
		    " as it is _after_ the new end, and would therefore make Vim
		    " swap the two mark positions.
		    execute "normal! v\<Esc>"
		endif
		call setpos('.', l:save_cursor)
		return 0
	    finally
		if exists('l:save_virtualedit')
		    let &virtualedit = l:save_virtualedit
		endif
	    endtry
	else
	    return setpos(a:expr, a:list)
	endif
    endfunction
endif

if exists('*sha256') && ! has_key(s:compatFor, 'sha256')
    function! ingo#compat#sha256( string )
	return sha256(a:string)
    endfunction
elseif executable('sha256sum')
    let s:printStringCommandTemplate = (ingo#os#IsWinOrDos() ? 'echo.%s' : 'printf %%s %s')
    function! ingo#compat#sha256( string )
	return get(split(system(printf(s:printStringCommandTemplate . "|sha256sum", ingo#compat#shellescape(a:string)))), 0, '')
    endfunction
else
    function! ingo#compat#sha256( string )
	throw 'ingo#compat#sha256: Not implemented here'
    endfunction
endif

if exists('*synstack') && ! has_key(s:compatFor, 'synstack')
    if v:version < 702 || v:version == 702 && ! has('patch14')
	" 7.2.014: synstack() doesn't work in an empty line
	function! ingo#compat#synstack( lnum, col )
	    let l:s =  synstack(a:lnum, a:col)
	    return (empty(l:s) ? [] : l:s)
	endfunction
    else
	function! ingo#compat#synstack( lnum, col )
	    return synstack(a:lnum, a:col)
	endfunction
    endif
else
    " As the synstack() function is not available, we can only try to get the
    " actual syntax ID and the one of the syntax item that determines the
    " effective color.
    function! ingo#compat#synstack( lnum, col )
	return [synID(a:lnum, a:col, 1), synID(a:lnum, a:col, 0)]
    endfunction
endif

" Patch 7.4.1707: Allow using an empty dictionary key
if (v:version == 704 && has('patch1707') || v:version > 704) && ! has_key(s:compatFor, 'DictKey')
    function! ingo#compat#DictKey( key )
	return a:key
    endfunction
    function! ingo#compat#FromKey( key )
	return a:key
    endfunction
else
    function! ingo#compat#DictKey( key )
	return (empty(a:key) ? "\<Nul>" : a:key)
    endfunction
    function! ingo#compat#FromKey( key )
	return (a:key ==# "\<Nul>" ? '' : a:key)
    endfunction
endif

if exists('*matchstrpos') && ! has_key(s:compatFor, 'matchstrpos')
    function! ingo#compat#matchstrpos( ... )
	return call('matchstrpos', a:000)
    endfunction
else
    function! ingo#compat#matchstrpos( ... )
	let l:start = call('match', a:000)

	if type(a:1) == type([])
	    let l:index = l:start
	    if l:index < 0
		return ['', -1, -1, -1]
	    endif

	    let l:matchArgs = [a:1[l:index], a:2] " {start} and {count} address the List, not the element; omit it here.
	    let l:str = call('matchstr', l:matchArgs)
	    let l:start = call('match', l:matchArgs)
	    let l:end = call('matchend', l:matchArgs)

	    return [l:str, l:index, l:start, l:end]
	else
	    let l:str = call('matchstr', a:000)
	    let l:end = call('matchend', a:000)
	    return [l:str, l:start, l:end]
	endif
    endfunction
endif

" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
autoload/ingo/compat/command.vim	[[[1
37
" ingo/compat/command.vim: Compatibility functions for commands.
"
" DEPENDENCIES:
"
" Copyright: (C) 2017-2019 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
"
" REVISION	DATE		REMARKS
"   1.030.001	20-Feb-2017	file creation

function! ingo#compat#command#Mods( mods )
"******************************************************************************
"* PURPOSE:
"   Return the command modifiers |<mods>| passed in raw as a:mods.
"   In order to support older Vim versions that don't have this (prior to
"   Vim 7.4.1898), one cannot use <q-mods>; this isn't understood and raises an
"   error. Instead, we can benefit from the fact that the modifiers do not
"   contain special characters, and do the quoting ourselves: '<mods>'. Now we
"   only need to remove the identifer in case it hasn't been understood, and
"   this is what this function is about.
"	-command! Sedit call SpecialEdit(<q-mods>)
"	+command! Sedit call SpecialEdit(ingo#compat#command#Mods('<mods>'))
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   '<mods>'
"* RETURN VALUES:
"   Usable modifiers.
"******************************************************************************
    return (a:mods ==# '<mods>' ? '' : a:mods)
endfunction

" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
autoload/ingo/compat/commands.vim	[[[1
98
" ingo/compat/commands.vim: Command emulations for backwards compatibility with Vim versions that don't have these commands.
"
" DEPENDENCIES:
"
" Copyright: (C) 2017-2019 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>

let s:compatFor = (exists('g:IngoLibrary_CompatFor') ? ingo#collections#ToDict(split(g:IngoLibrary_CompatFor, ',')) : {})

"******************************************************************************
"* PURPOSE:
"   Return ':keeppatterns' if supported or an emulation of it.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   Creates internal command if emulation is needed.
"* INPUTS:
"   None.
"* RETURN VALUES:
"   Command. To use, turn >
"	command! -range Foo keeppatterns <line1>,<line2>substitute/\<...\>/FOO/g
"   <into >
"	command! -range Foo execute ingo#compat#commands#keeppatterns() '<line1>,<line2>substitute/\<...\>/FOO/g'
"******************************************************************************
if exists(':keeppatterns') == 2 && ! has_key(s:compatFor, 'keeppatterns')
    function! ingo#compat#commands#keeppatterns()
	return 'keeppatterns'
    endfunction
else
    if exists('ZzzzKeepPatterns') != 2
	command! -nargs=* ZzzzKeepPatterns let g:ingo#compat#commands#histnr = histnr('search') | execute <q-args> | if g:ingo#compat#commands#histnr != histnr('search') | call histdel('search', -1) | let @/ = histget('search', -1) | nohlsearch | endif
    endif
    function! ingo#compat#commands#keeppatterns()
	return 'ZzzzKeepPatterns'
    endfunction
endif


function! ingo#compat#commands#NormalWithCount( ... )
"******************************************************************************
"* PURPOSE:
"   Execute the normal mode commands that may include a count as soon as
"   possible. Uses :normal if it supports count or no count is given; prior to
"   Vim 7.3.100, a bug prevented this, and feedkeys() has to be used. Note that
"   this means that the keys will only be interpreted _after_ the function ends,
"   and that other :normal commands will come first!
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   Executes a:count . a:string.
"* INPUTS:
"   a:prefix    Optional: Any characters to be executed before a:count. (With
"               :normal, the sequence has to be a single call.)
"   a:count     Optional count for a:string. If omitted, no count is used.
"   a:string    Characters to be executed in normal mode.
"   a:isNoRemap Flag whether mappings are ignored for a:string characters.
"* RETURN VALUES:
"   1 if the execution could be done immediately, 0 if it will happen after the
"   current command sequence has finished.
"******************************************************************************
    let l:prefix = ''
    let l:count = ''
    if a:0 == 4
	let [l:prefix, l:count, l:string, l:isNoRemap] = a:000
    elseif a:0 == 3
	let [l:count, l:string, l:isNoRemap] = a:000
    elseif a:0 == 2
	let [l:string, l:isNoRemap] = a:000
    else
	throw 'ASSERT: Need 2..4 arguments instead of ' . a:0
    endif

    if ! l:count || v:version > 703 || (v:version == 703 && has('patch100'))
	execute 'normal' . (l:isNoRemap ? '!' : '') l:prefix . (l:count ? l:count : '') . l:string
	return 1
    else
	call feedkeys(l:prefix . (l:count ? l:count : '') . l:string, (l:isNoRemap ? 'n' : ''))
	return 0
    endif
endfunction

if v:version == 704 && has('patch601') || v:version > 704
" For these Vim versions, repeat.vim uses feedkeys(), which is asynchronous, so
" the actual sequence would only be executed after the caller finished. With
" this function, callers can force synchronous execution of the typeahead now to
" be able to work on the effects of command repetition.
function! ingo#compat#commands#ForceSynchronousFeedkeys()
    call feedkeys('', 'x')
endfunction
else
function! ingo#compat#commands#ForceSynchronousFeedkeys()
    return
endfunction
endif

" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
autoload/ingo/compat/complete.vim	[[[1
76
" ingo/compat/complete.vim: Function to retrofit :command -complete=filetype.
"
" DEPENDENCIES:
"   - ingo/compat.vim autoload script
"
" Copyright: (C) 2009-2014 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
"
" REVISION	DATE		REMARKS
"   1.022.002	22-Sep-2014	Use ingo#compat#globpath().
"   1.007.001	05-Jun-2013	file creation from ingocommands.vim

function! s:GenerateRuntimeFiletypes()
    let l:runtimeFiletypes = []

    " Vim filetypes can be gathered from the directory trees in 'runtimepath';
    " there are different kinds of filetype-specific plugins.
    " Extensions for a filetype "xxx" are specified either via "xxx_suffix.vim"
    " or a "xxx/*.vim" subdirectory. The latter isn't contained in the glob, the
    " first is explicitly filtered out.
    for l:kind in ['ftplugin', 'indent', 'syntax']
	call extend(l:runtimeFiletypes,
	\	filter(
	\	    map(
	\		ingo#compat#globpath(&runtimepath, l:kind . '/*.vim', 0, 1),
	\		'fnamemodify(v:val, ":t:r")'
	\	    ),
	\	    'v:val !~# "_"'
	\	)
	\)
    endfor

    function! s:IsUnique( val )
	let l:isUnique = (! exists('s:prevVal') || a:val !=# s:prevVal)
	let s:prevVal = a:val
	return l:isUnique
    endfunction
    let l:runtimeFiletypes = filter(
    \   sort(l:runtimeFiletypes),
    \   's:IsUnique(v:val)'
    \)
    delfunction s:IsUnique

    return l:runtimeFiletypes
endfunction
"******************************************************************************
"* PURPOSE:
"   Provide :command -complete=filetype for older Vim versions that don't support it.
"   Use like this:
"   try
"	command -complete=filetype ...
"   catch /^Vim\%((\a\+)\)\=:E180:/ " E180: Invalid complete value
"	command -complete=customlist,ingo#compat#complete#FileType ...
"   endtry
    call ingo#msg#VimExceptionMsg()
"* ASSUMPTIONS / PRECONDITIONS:
"	? List of any external variable, control, or other element whose state affects this procedure.
"* EFFECTS / POSTCONDITIONS:
"	? List of the procedure's effect on each external variable, control, or other element.
"* INPUTS:
"	? Explanation of each argument that isn't obvious.
"* RETURN VALUES:
"	? Explanation of the value returned.
"******************************************************************************
function! ingo#compat#complete#FileType( ArgLead, CmdLine, CursorPos )
    if ! exists('s:runtimeFiletypes')
	let s:runtimeFiletypes = s:GenerateRuntimeFiletypes()
    endif

    let l:filetypes = filter(copy(s:runtimeFiletypes), 'v:val =~ ''\V\^'' . escape(a:ArgLead, "\\")')
    return sort(l:filetypes)
endfunction

" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
autoload/ingo/compat/regexp.vim	[[[1
29
" ingo/compat/regexp.vim: Functions for regular expression compatibility.
"
" DEPENDENCIES:
"
" Copyright: (C) 2015 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
"
" REVISION	DATE		REMARKS
"   1.024.001	20-Feb-2015	file creation

if exists('+regexpengine') " {{{2
    " XXX: The new NFA-based regexp engine has a problem with non-greedy \s\{-}
    " match together with the branches where only one is anchored; cp.
    " http://article.gmane.org/gmane.editors.vim.devel/43712
    " XXX: The new NFA-based regexp engine has a problem with the /\@<= pattern
    " in combination with a back reference \1; cp.
    " http://article.gmane.org/gmane.editors.vim.devel/46596
    function! ingo#compat#regexp#GetOldEnginePrefix()
	return '\%#=1'
    endfunction
else
    function! ingo#compat#regexp#GetOldEnginePrefix()
	return ''
    endfunction
endif

" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
autoload/ingo/compat/shellcommand.vim	[[[1
44
" ingo/compat/shellcommand.vim: Escaping of Windows shell commands.
"
" DEPENDENCIES:
"   - ingo/os.vim autoload script
"
" Copyright: (C) 2014 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
"
" REVISION	DATE		REMARKS
"   1.016.001	21-Jan-2014	file creation from ingo/escape/shellcommand.vim.

function! ingo#compat#shellcommand#escape( command )
"******************************************************************************
"* PURPOSE:
"   Wrap the entire shell command a:command in double quotes on Windows.
"   This was necessary in Vim versions before 7.3.443 when passing a command to
"   cmd.exe which has arguments that are enclosed in double quotes, e.g.
"	""%SystemRoot%\system32\dir.exe" /B "%ProgramFiles%"".
"
"* EXAMPLE:
"   execute '!' ingo#escape#shellcommand#shellcmdescape(escapings#shellescape($ProgramFiles .
"   '/foobar/foo.exe', 1) . ' ' . escapings#shellescape(args, 1))
"
"* ASSUMPTIONS / PRECONDITIONS:
"	? List of any external variable, control, or other element whose state affects this procedure.
"* EFFECTS / POSTCONDITIONS:
"	? List of the procedure's effect on each external variable, control, or other element.
"* INPUTS:
"   a:command	    Single shell command, with optional arguments.
"		    The shell command should already have been escaped via
"		    shellescape().
"* RETURN VALUES:
"   Escaped command to be used in a :! command or inside a system() call.
"******************************************************************************
    if ingo#os#IsWinOrDos() && &shellxquote !=# '(' && a:command =~# '"'
	return '"' . a:command . '"'
    endif

    return a:command
endfunction

" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
autoload/ingo/compat/window.vim	[[[1
27
" ingo/compat/window.vim: Compatibility functions for windows.
"
" DEPENDENCIES:
"
" Copyright: (C) 2016 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
"
" REVISION	DATE		REMARKS
"   1.028.001	10-Oct-2016	file creation

if exists('*getcmdwintype')
function! ingo#compat#window#IsCmdlineWindow()
    return ! empty(getcmdwintype())
endfunction
elseif v:version >= 702
function! ingo#compat#window#IsCmdlineWindow()
    return bufname('') ==# '[Command Line]'
endfunction
else
function! ingo#compat#window#IsCmdlineWindow()
    return bufname('') ==# 'command-line'
endfunction
endif

" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
autoload/ingo/cursor.vim	[[[1
95
" ingo/cursor.vim: Functions for the cursor position.
"
" DEPENDENCIES:
"
" Copyright: (C) 2013-2017 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
"
" REVISION	DATE		REMARKS
"   1.030.003	10-Feb-2017	Add ingo#cursor#StartInsert() and
"				ingo#cursor#StartAppend().
"   1.018.002	10-Apr-2014	Add ingo#cursor#IsAtEndOfLine().
"   1.016.001	11-Dec-2013	file creation

function! ingo#cursor#Set( lnum, virtcol )
"******************************************************************************
"* PURPOSE:
"   Set the cursor position to a virtual column, not the byte count like
"   cursor() does.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   Re-positions the cursor.
"* INPUTS:
"   a:lnum  Line number; if {lnum} is zero, the cursor will stay in the current
"	    line.
"   a:virtcol   Screen column; if no such column is available, will put the
"		cursor on the last character in the line.
"* RETURN VALUES:
"   1 if the desired virtual column has been reached; 0 otherwise.
"******************************************************************************
    if a:lnum != 0
	call cursor(a:lnum, 0)
    endif
    execute 'normal!' a:virtcol . '|'
    return (virtcol('.') == a:virtcol)
endfunction

function! ingo#cursor#IsAtEndOfLine( ... )
"******************************************************************************
"* PURPOSE:
"   Tests whether the cursor is on (or behind, with 'virtualedit') the last
"   character of the current line.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:mark  Optional mark containing the current position; this should be
"	    located in the current line to make sense!
"* RETURN VALUES:
"   1 if at the end of the current line, 0 otherwise.
"******************************************************************************
    let l:mark = (a:0 ? a:1 : '.')
    return (col(l:mark) + len(matchstr(getline(l:mark), '.$')) >= col('$'))    " I18N: Cannot just add 1; need to consider the byte length of the last character in the line.

    " This won't work with :set virtualedit=all, when the cursor is after the
    " physical end of the line.
    "return (search('\%#.$', 'cn', line('.')) > 0)
endfunction


function! ingo#cursor#StartInsert( isAtEndOfLine )
    if a:isAtEndOfLine
	startinsert!
    else
	startinsert
    endif
endfunction

function! ingo#cursor#StartAppend( ... )
"******************************************************************************
"* PURPOSE:
"   Start appending just after executing this command. Works like typing "a" in
"   normal mode.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   Starts insert mode.
"* INPUTS:
"   a:isAtEndOfLine Optional flag whether the cursor is at the end of the line.
"* RETURN VALUES:
"   None.
"******************************************************************************
    let l:isAtEndOfLine = (a:0 ? a:1 : ingo#cursor#IsAtEndOfLine())
    if l:isAtEndOfLine
	startinsert!
    else
	normal! l
	startinsert
    endif
endfunction

" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
autoload/ingo/cursor/keep.vim	[[[1
59
" ingo/cursor/keep.vim: Functions to keep the cursor at its current position.
"
" DEPENDENCIES:
"   - ingo/actions.vim autoload script
"   - ingo/range.vim autoload script
"
" Copyright: (C) 2018 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>

function! ingo#cursor#keep#WhileExecuteOrFunc( startLnum, endLnum, Action, ... )
"******************************************************************************
"* PURPOSE:
"   Commands in the executed a:Action do not change the current text position
"   (within the range of a:startLnum,a:endLnum), relative to the current text.
"   This works by temporarily inserting a sentinel character at the current
"   cursor position, and searching for it after the action has executed.
"* ASSUMPTIONS / PRECONDITIONS:
"   Current buffer is modifiable.
"   Text within the a:startLnum, a:endLnum (adapted to any change in line
"   numbers by a:Action) range does not contain the sentinel value (NUL = ^@).
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:startLnum Range of lines that may be affected by a:Action.
"   a:endLnum
"   a:Action    Either a Funcref or Ex commands to be :executed.
"   a:arguments Value(s) to be passed to the a:Action Funcref (but not the
"		Ex commands).
"* RETURN VALUES:
"   Result of evaluating a:Action, for Ex commands you need to use :return.
"******************************************************************************
    let l:endLnum = a:endLnum
    let l:lineNum = line('$')
    let l:save_foldenable = &l:foldenable
    setlocal nofoldenable

    noautocmd execute "normal! i\<C-v>\<C-@>\<Esc>"
    try
	return call('ingo#actions#ExecuteOrFunc', [a:Action] + a:000)
    finally
	let l:addedLineNum = line('$') - l:lineNum
	let l:endLnum += l:addedLineNum

	if ingo#range#IsOutside(line('.'), a:startLnum, l:endLnum)
	    call cursor(a:startLnum, 1)
	endif

	if search("\<C-j>", 'cW', l:endLnum) != 0 || search("\<C-j>", 'bcW', a:startLnum) != 0
	    " Found the sentinel, remove it.
	    noautocmd normal! x
	endif

	let &l:foldenable = l:save_foldenable
    endtry
endfunction

" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
autoload/ingo/cursor/move.vim	[[[1
50
" ingo/cursor/move.vim: Functions for moving the cursor.
"
" DEPENDENCIES:
"
" Copyright: (C) 2013 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
"
" REVISION	DATE		REMARKS
"   1.010.004	03-Jul-2013	Move into ingo-library.
"	003	08-Jan-2013	Reimplement wrapping by temporarily changing
"				'whichwrap' and 'virtualedit'; it's more robust
"				than the explicit checks and allows arbitrary
"				actions via new ingocursormove#Move().
"				Allow passing a count to ingocursormove#Left()
"				and ingocursormove#Right().
"	002	07-Jan-2013	I18N: FIX: Movement check in
"				ingocursormove#Right() doesn't properly consider
"				multi-byte character at the end of the line.
"	001	07-Jan-2013	file creation from autoload/surroundings.vim

function! ingo#cursor#move#Move( movement )
    let l:save_whichwrap = &whichwrap
    let l:save_virtualedit = &virtualedit
    set whichwrap=b,s,h,l,<,>,[,]
    set virtualedit=
	let l:originalPosition = getpos('.')    " Do this after 'virtualedit' has been reset; it may move the cursor back into the text.
	" Note: No try..catch here to abort a compound movement immediately.
	" Suppress beep with :silent!
	silent! execute 'normal!' a:movement
    let &virtualedit = l:save_virtualedit
    let &whichwrap = l:save_whichwrap

    return (getpos('.') != l:originalPosition)
endfunction

" Helper: move cursor one position left; with possible wrap to preceding line.
" Cursor does not move if at top of file.
function! ingo#cursor#move#Left( ... )
    return ingo#cursor#move#Move((a:0 ? a:1 : '') . 'h')
endfunction

" Helper: move cursor one position right; with possible wrap to following line.
" Cursor does not move if at end of file.
function! ingo#cursor#move#Right( ... )
    return ingo#cursor#move#Move((a:0 ? a:1 : '') . 'l')
endfunction

" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
autoload/ingo/date.vim	[[[1
130
" ingo/date.vim: Functions for date and time.
"
" DEPENDENCIES:
"
" Copyright: (C) 2011-2018 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
"
" REVISION	DATE		REMARKS
"   1.014.003	10-Nov-2013	Add month and year granularity to
"				ingo#date#HumanReltime().
"   1.010.002	08-Jul-2013	Move into ingo-library.
"	001	07-Oct-2011	file creation

function! s:Align( isShortFormat, isRightAligned, text )
    if a:isRightAligned
	return printf('%' . (a:isShortFormat ? 7 : 14) . 's', a:text)
    else
	return a:text
    endif
endfunction
function! s:Relative( isShortFormat, isRightAligned, isInFuture, time, timeunit )
    if a:isShortFormat
	let l:timestring = a:time . a:timeunit
    else
	let l:timestring = printf('%d %s%s', a:time, a:timeunit, (a:time == 1 ? '' : 's'))
    endif

    return s:Align(a:isShortFormat, a:isRightAligned, a:isInFuture ? 'in ' . l:timestring : l:timestring . ' ago')
endfunction
function! ingo#date#HumanReltime( timeElapsed, ... )
"******************************************************************************
"* PURPOSE:
"   Format a relative timespan in a format that is concise, not too precise, and
"   suitable for human understanding.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:timeElapsed   Time span in seconds; positive values mean time in the past.
"   a:options.shortformat   Flag whether a concise representation should be used
"			    (2 minutes -> 2m).
"   a:options.rightaligned  Flag whether the time text should be right-aligned,
"			    so that all results have the same width.
"* RETURN VALUES:
"   Text of the rendered time span, e.g. "just now", "2 minutes ago", "in 5
"   hours".
"******************************************************************************
    let l:options = (a:0 ? a:1 : {})
    let l:isShortFormat = get(l:options, 'shortformat', 0)
    let l:isRightAligned = get(l:options, 'rightaligned', 0)
    let [l:now, l:seconds, l:minutes, l:hours, l:days, l:months, l:years] = (
    \   l:isShortFormat ?
    \       ['now', 's', 'm', 'h', 'd', 'mo.', 'y'] :
    \       ['just now', 'second', 'minute', 'hour', 'day', 'month', 'year']
    \)

    let l:isInFuture = 0
    let l:timeElapsed = a:timeElapsed
    if l:timeElapsed < 0
	let l:timeElapsed = -1 * l:timeElapsed
	let l:isInFuture = 1
    endif

    let l:secondsElapsed = l:timeElapsed % 60
    let l:minutesElapsed = (l:timeElapsed / 60) % 60
    let l:hoursElapsed = (l:timeElapsed / 3600) % 24
    let l:daysElapsed = (l:timeElapsed / (3600 * 24))
    let l:monthsElapsed = (l:timeElapsed / (3600 * 24 * 30))
    let l:yearsElapsed = (l:timeElapsed / (3600 * 24 * 365))

    if l:timeElapsed < 5
	return s:Align(l:isShortFormat, l:isRightAligned, l:now)
    elseif l:timeElapsed < 60
	return s:Relative(l:isShortFormat, l:isRightAligned, l:isInFuture, l:timeElapsed, l:seconds)
    elseif l:timeElapsed > 3540 && l:timeElapsed < 3660
	return s:Relative(l:isShortFormat, l:isRightAligned, l:isInFuture, 1, l:hours)
    elseif l:timeElapsed < 7200
	return s:Relative(l:isShortFormat, l:isRightAligned, l:isInFuture, (l:timeElapsed / 60), l:minutes)
    elseif l:timeElapsed < 86400
	return s:Relative(l:isShortFormat, l:isRightAligned, l:isInFuture, (l:timeElapsed / 3600), l:hours)
    elseif l:timeElapsed < 86400 * (30 + 31)
	return s:Relative(l:isShortFormat, l:isRightAligned, l:isInFuture, (l:timeElapsed / 86400), l:days)
    elseif l:timeElapsed < 86400 * (365 + 31)
	return s:Relative(l:isShortFormat, l:isRightAligned, l:isInFuture, (l:timeElapsed / 86400 / 30), l:months)
    else
	return s:Relative(l:isShortFormat, l:isRightAligned, l:isInFuture, (l:timeElapsed / 86400 / 365), l:years)
    endif
endfunction

if exists('g:IngoLibrary_StrftimeEmulation')
    function! ingo#date#strftime( format, ... )
"******************************************************************************
"* PURPOSE:
"   Get the formatted date and time according to a:format, of a:time or the
"   current time.
"   Supports a "testing mode" by defining g:IngoLibrary_StrftimeEmulation
"   (before first use of this module), with a Dictionary that maps possible
"   a:format values to either a static value, or a Funcref that is invoked with
"   a:format and a:time (if given) that should return the value. A special key
"   of "*" acts as a fallback for those a:format values that don't have a key.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:format    According to manual of strftime().
"   a:time      Optional time used for formatting instead of now.
"* RETURN VALUES:
"   Formatted date / time according to a:format.
"******************************************************************************
	if has_key(g:IngoLibrary_StrftimeEmulation, a:format)
	    let l:Emulator = g:IngoLibrary_StrftimeEmulation[a:format]
	elseif has_key(g:IngoLibrary_StrftimeEmulation, '*')
	    let l:Emulator = g:IngoLibrary_StrftimeEmulation['*']
	else
	    throw printf('strftime: Unhandled format %s and no fallback * key in g:IngoLibrary_StrftimeEmulation', a:format)
	endif

	return (a:0 ? ingo#actions#ValueOrFunc(l:Emulator, a:format, a:1) : ingo#actions#ValueOrFunc(l:Emulator, a:format))
    endfunction
else
    function! ingo#date#strftime( ... )
	return call('strftime', a:000)
    endfunction
endif

" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
autoload/ingo/date/epoch.vim	[[[1
49
" ingo/date/epoch.vim: Date conversion to the Unix epoch format (seconds since 1970).
"
" DEPENDENCIES:
"   - ingo/compat.vim autoload script
"   - ingo/os.vim autoload script
"
" Copyright: (C) 2013-2018 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>

if ! exists('g:IngoLibrary_DateCommand')
    let g:IngoLibrary_DateCommand = (ingo#os#IsWinOrDos() ? 'unixdate' : 'date')
endif

function! ingo#date#epoch#ConvertTo( date )
    " Unfortunately, Vim doesn't have a built-in function to convert an
    " arbitrary date to the Unix Epoch, and that is the only format which is
    " accepted by strftime(). Therefore, we need to rely on the Unix "date"
    " command (named "unixdate" on Windows; you need to have e.g. the GNU Win32
    " port installed).
    return str2nr(system(printf('%s -d %s +%%s', ingo#compat#shellescape(g:IngoLibrary_DateCommand), ingo#compat#shellescape(a:date))))
endfunction

if exists('g:IngoLibrary_NowEpoch')
    function! ingo#date#epoch#Now()
	return g:IngoLibrary_NowEpoch
    endfunction
else
    function! ingo#date#epoch#Now()
"******************************************************************************
"* PURPOSE:
"   Get the Unix Epoch for the current date and time.
"   Supports a "testing mode" by defining g:IngoLibrary_NowEpoch (before first
"   use of this module) with the constant value to be returned instead.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   None.
"* RETURN VALUES:
"   Integer representing the seconds since 1970 as of now.
"******************************************************************************
	return localtime()
    endfunction
endif

" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
autoload/ingo/date/format.vim	[[[1
55
" ingo/date/format.vim: Common date formats.
"
" DEPENDENCIES:
"   - ingo/os.vim autoload script
"
" Copyright: (C) 2012-2015 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
"
" REVISION	DATE		REMARKS
"   1.024.004	22-Apr-2015	Rename ingo#date#format#Human() to
"				ingo#date#format#Preferred(), default to %x
"				value for strftime(), and allow to customize
"				that (even dynamically, maybe based on
"				'spelllang').
"   1.014.003	16-Sep-2013	Allow to pass optional date to all functions.
"   1.014.002	13-Sep-2013	Move into ingo-library.
"				Use operating system detection functions from
"				ingo/os.vim.
"	001	14-Apr-2012	file creation from InsertDate.vim

if ! exists('g:IngoLibrary_PreferredDateFormat')
    let g:IngoLibrary_PreferredDateFormat = '%x'
endif

function! ingo#date#format#International( ... )
    return call('strftime', ['%d-%b-%Y'] + a:000)
endfunction
function! ingo#date#format#Preferred( ... )
    return call('strftime', [ingo#actions#ValueOrFunc(ingo#plugin#setting#GetBufferLocal('IngoLibrary_PreferredDateFormat'))] + a:000)
endfunction
function! ingo#date#format#Sortable( ... )
    return call('strftime', ['%Y-%m-%d'] + a:000)
endfunction
function! ingo#date#format#SortableNumeric( ... )
    return call('strftime', ['%Y%m%d'] + a:000)
endfunction
function! ingo#date#format#InternetTimestamp( ... )
    " RFC 3339 Internet Date / Time "1996-12-19T16:39:57-08:00"
    if ingo#os#IsWindows()
	" Windows doesn't support %:z, and even returns "either the time-zone
	" name or time zone abbreviation, depending on registry settings" (e.g.
	" "Romance Daylight Time", so we hard-code our CET / CEST offset
	" depending on the outcome.
	return call('strftime', ['%Y-%m-%dT%H:%M:%S'] + a:000) . (call('strftime', ['%z'] + a:000) =~? '\<daylight\>\|\<CEST\>' ? '+02:00' : '+01:00')
    else
	" Ubuntu 10.04 doesn't support %:z yet, but %z works, so insert the
	" required colon afterwards.
	let l:colonZItem = call('strftime', ['%:z'] + a:000)
	return call('strftime', ['%Y-%m-%dT%H:%M:%S'] + a:000) . (l:colonZItem ==# '%:z' ? substitute(call('strftime', ['%z'] + a:000), '\(\d\d\)\(\d\d\)', '\1:\2', '') : l:colonZItem)
    endif
endfunction

" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
autoload/ingo/dict.vim	[[[1
192
" ingo/dict.vim: Functions for creating Dictionaries.
"
" DEPENDENCIES:
"
" Copyright: (C) 2013-2019 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
let s:save_cpo = &cpo
set cpo&vim

function! ingo#dict#Make( val, defaultKey, ... )
"******************************************************************************
"* PURPOSE:
"   Ensure that the passed a:val is a Dict; if not, wrap it in one, with
"   a:defaultKey as the key.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:val   Arbitrary value of arbitrary type.
"   a:defaultKey            Key for a:val if it's not a Dict yet.
"   a:isCopyOriginalDict    Optional flag; when set, an original a:val Dict is
"			    copied before returning.
"* RETURN VALUES:
"   Dict; either the original one or a new one containing a:defaultKey : a:val.
"******************************************************************************
    return (type(a:val) == type({}) ? (a:0 && a:1 ? copy(a:val) : a:val) : {a:defaultKey : a:val})
endfunction

function! ingo#dict#FromItems( items, ... )
"******************************************************************************
"* PURPOSE:
"   Create a Dictionary object from a list of [key, value] items, as returned by
"   |items()|.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:items List of [key, value] items.
"   a:isEnsureUniqueness    Optional flag whether a KeyNotUnique should be
"			    thrown if an equal key was already found. By
"			    default, the last key (in the arbitrary item()
"			    order) overrides previous ones.
"* RETURN VALUES:
"   A new Dictionary.
"******************************************************************************
    let l:isEnsureUniqueness = (a:0 && a:1)
    let l:dict = {}
    for [l:key, l:val] in a:items
	if l:isEnsureUniqueness
	    if has_key(l:dict, l:key)
		throw 'Mirror: KeyNotUnique: ' . l:key
	    endif
	endif
	let l:dict[l:key] = l:val
    endfor
    return l:dict
endfunction

function! ingo#dict#FromKeys( keys, ValueExtractor )
"******************************************************************************
"* PURPOSE:
"   Create a Dictionary object from a:keys, with the key taken from the List
"   elements, and the value obtained through a:KeyExtractor (which can be a
"   constant default).
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:keys  List of keys for the Dictionary.
"   a:ValueExtractor    Funcref that is passed a value and is expected to return
"                       a value.
"                       Or a static default value for each of the generated keys.
"* RETURN VALUES:
"   A new Dictionary with keys taken from a:keys and values extracted via /
"   provided by a:ValueExtractor.
"* SEE ALSO:
"   ingo#collections#ToDict() handles empty key values, but uses a hard-coded
"   default value.
"   ingo#dict#count#Items() also creates a Dict from a List, and additionally
"   counts the unique values.
"******************************************************************************
    let l:isFuncref = (type(a:ValueExtractor) == type(function('tr')))
    let l:dict = {}
    for l:key in a:keys
	let l:val = (l:isFuncref ?
	\   call(a:ValueExtractor, [l:key]) :
	\   a:ValueExtractor
	\)
	let l:dict[l:key] = l:val
    endfor
    return l:dict
endfunction

function! ingo#dict#FromValues( KeyExtractor, values ) abort
"******************************************************************************
"* PURPOSE:
"   Create a Dictionary object from a:values, with the value taken from the List
"   elements, and the key obtained through a:KeyExtractor.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:values    List of values for the Dictionary.
"   a:KeyExtractor  Funcref that is passed a value and is expected to return a
"                   (unique) key.
"* RETURN VALUES:
"   A new Dictionary with values taken from a:values and keys extracted through
"   a:KeyExtractor.
"******************************************************************************
    let l:dict = {}
    for l:val in a:values
	let l:key = call(a:KeyExtractor, [l:val])
	let l:dict[l:key] = l:val
    endfor
    return l:dict
endfunction

function! ingo#dict#Mirror( dict, ... )
"******************************************************************************
"* PURPOSE:
"   Turn all values of a:dict into keys, and vice versa.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:dict  Dictionary. It is assumed that all values are non-empty and of
"	    String or Number type (so that they can be coerced into the String
"	    type of the Dictionary key).
"	    Alternatively, a list of [key, value] items can be passed (to
"	    influence which key from equal values is used).
"   a:isEnsureUniqueness    Optional flag whether a ValueNotUnique should be
"			    thrown if an equal value was already found. By
"			    default, the last value (in the arbitrary item()
"			    order) overrides previous ones.
"* RETURN VALUES:
"   Returns a new, mirrored Dictionary.
"******************************************************************************
    let l:isEnsureUniqueness = (a:0 && a:1)
    let l:dict = {}
    for [l:key, l:value] in (type(a:dict) == type({}) ? items(a:dict) : a:dict)
	if l:isEnsureUniqueness
	    if has_key(l:dict, l:value)
		throw 'Mirror: ValueNotUnique: ' . l:value
	    endif
	endif
	let l:dict[l:value] = l:key
    endfor
    return l:dict
endfunction
function! ingo#dict#AddMirrored( dict, ... )
"******************************************************************************
"* PURPOSE:
"   Also define all values in a:dict as keys (with their keys as values).
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:dict  Dictionary. It is assumed that all values are non-empty and of
"	    String or Number type (so that they can be coerced into the String
"	    type of the Dictionary key).
"	    Alternatively, a list of [key, value] items can be passed (to
"	    influence which key from equal values is used).
"   a:isEnsureUniqueness    Optional flag whether a ValueNotUnique should be
"			    thrown if an equal value was already found. By
"			    default, the last value (in the arbitrary item()
"			    order) overrides previous ones.
"* RETURN VALUES:
"   Returns the original a:dict with added reversed entries.
"******************************************************************************
    let l:isEnsureUniqueness = (a:0 && a:1)
    for [l:key, l:value] in (type(a:dict) == type({}) ? items(a:dict) : a:dict)
	if l:isEnsureUniqueness
	    if has_key(l:dict, l:value)
		throw 'AddMirrored: ValueNotUnique: ' . l:value
	    endif
	endif
	let a:dict[l:value] = l:key
    endfor
    return a:dict
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo
" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
autoload/ingo/dict/count.vim	[[[1
55
" ingo/dict/count.vim: Functions for counting with Dictionaries.
"
" DEPENDENCIES:
"   - ingo/collections.vim autoload script
"   - ingo/dict.vim autoload script
"
" Copyright: (C) 2017 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
"
" REVISION	DATE		REMARKS
"	001	24-May-2017	file creation

function! ingo#dict#count#Items( dict, items, ... )
"******************************************************************************
"* PURPOSE:
"   For each item in a:items, create a key with count 1 / increment the value of
"   an existing key in a:dict.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:dict  Dictionary that holds the items -> counts. Need not be empty.
"   a:items List of items to be counted.
"   a:emptyValue    Optional value for items in a:list that yield an empty
"		    string, which (in Vim versions prior to 7.4.1707) cannot be
"		    used as a Dictionary key.
"		    If omitted, empty values are not included in the Dictionary.
"* RETURN VALUES:
"   a:dict
"* SEE ALSO:
"   ingo#collections#ToDict() does not count, just uses a hard-coded value
"   ingo#dict#FromKeys() also does not count but allows to specify a default value
"******************************************************************************
    for l:item in a:items
	if l:item ==# ''
	    if a:0
		let l:item = a:1
	    else
		continue
	    endif
	endif

	if has_key(a:dict, l:item)
	    let a:dict[l:item] += 1
	else
	    let a:dict[l:item] = 1
	endif
    endfor
    return a:dict
endfunction

" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
autoload/ingo/dict/find.vim	[[[1
72
" ingo/dict/find.vim: Functions for finding keys that match a value in a Dictionary.
"
" DEPENDENCIES:
"
" Copyright: (C) 2014 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
"
" REVISION	DATE		REMARKS
"   1.020.001	29-May-2014	file creation

function! s:Find( isAll, dict, value, ... )
    let l:resultKeys = []

    let l:keys = keys(a:dict)
    if a:0
	let l:keys = (empty(a:1) ? sort(l:keys) : sort(l:keys, a:1))
    endif

    for l:key in l:keys
	if a:dict[l:key] ==# a:value
	    if a:isAll
		call add(l:resultKeys, l:key)
	    else
		return l:key
	    endif
	endif
    endfor

    return l:resultKeys
endfunction

function! ingo#dict#find#FirstKey( dict, value, ... )
"******************************************************************************
"* PURPOSE:
"   Find the first key in a:dict that has a:value.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:dict  Dictionary.
"   a:value Value to search.
"   a:func  Optional function name / Funcref to sort the keys of a:dict. If 0 or
"	    '', uses default sort().
"* RETURN VALUES:
"   key of a:dict, or [] to indicate no matching keys.
"******************************************************************************
    return call('s:Find', [0, a:dict, a:value] + a:000)
endfunction

function! ingo#dict#find#Keys( dict, value, ... )
"******************************************************************************
"* PURPOSE:
"   Find all keys in a:dict that have a:value.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:dict  Dictionary.
"   a:value Value to search.
"   a:func  Optional function name / Funcref to sort the keys of a:dict. If 0 or
"	    '', uses default sort().
"* RETURN VALUES:
"   List of keys of a:dict, or [] to indicate no matching keys.
"******************************************************************************
    return call('s:Find', [1, a:dict, a:value] + a:000)
endfunction

" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
autoload/ingo/digest.vim	[[[1
169
" ingo/digest.vim: Functions to create short digests from larger collections of text.
"
" DEPENDENCIES:
"   - ingo/collections.vim autoload script
"   - ingo/dict/count.vim autoload script
"
" Copyright: (C) 2017 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
"
" REVISION	DATE		REMARKS
"   1.031.002	31-May-2017	FIX: Potentially invalid indexing of
"				l:otherResult[l:i] in s:GetUnjoinedResult(). Use
"				get() for inner List access, too.
"   1.030.001	24-May-2017	file creation
let s:save_cpo = &cpo
set cpo&vim

function! ingo#digest#Get( items, itemSplitPattern, ... )
"******************************************************************************
"* PURPOSE:
"   Split Strings in a:items into parts according to a:itemSplitPattern, and
"   keep those (and surrounding separators) that occur in all / a:percentage.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:items             List of input Strings.
"   a:itemSplitPattern  Regular expression that identifies the separators of
"			each item.
"   a:percentage        Optional value between 1 and 100 that specifies the
"			percentage of the items in which a part has to occur in
"			order to be kept in the digest. Default 100, i.e. a part
"			has to occur in all items.
"* RETURN VALUES:
"   List of non-consecutive parts that occur in all / a:percentage of items.
"   Consecutive parts are re-joined.
"******************************************************************************
    let l:separation = map(
    \   copy(a:items),
    \   'ingo#collections#SeparateItemsAndSeparators(v:val, a:itemSplitPattern, 1)'
    \)
    let l:itemsParts      = map(copy(l:separation), 'v:val[0]')
    let l:itemsSeparators = map(copy(l:separation), 'v:val[1]')
"****D echomsg '****' string(l:itemsParts) '+' string(l:itemsSeparators)
    let l:counts = {}
    for l:items in l:itemsParts
	call ingo#dict#count#Items(l:counts, ingo#collections#Unique(l:items))
    endfor

    let l:accepted = filter(
    \   copy(l:counts),
    \   'v:val' . (a:0 ?
    \       printf(' * 100 / %d >= %d', len(a:items), a:1) :
    \       ' == ' . len(a:items)
    \   )
    \)
"****D echomsg '****' string(l:counts) '->' string(l:accepted)
    let l:evaluation = map(l:separation, 's:Evaluate(v:val[0], v:val[1], l:accepted)')

    " When a percentage is given, select the longest parts, to consider that not
    " every item contains all parts. Without a percentage, all parts should be
    " contained, so the shortest parts is chosen.
    let l:filteredItems = s:FilterItems((a:0 ? 'max' : 'min'), l:evaluation)
"****D echomsg '****' string(l:filteredItems)
    let l:unjoinedResult = s:GetUnjoinedResult(l:filteredItems)
"****D echomsg '****' string(l:unjoinedResult)
    return s:UnjoinResult(l:unjoinedResult)
endfunction
function! s:Evaluate( parts, separators, accepted )
    let l:result = [0]
    let l:lastAcceptedIndex = -2
    for l:i in range(len(a:parts))
	let l:part = a:parts[l:i]
	if has_key(a:accepted, l:part)
	    if l:lastAcceptedIndex + 1 == l:i
		call add(l:result[-1], l:part)
		call add(l:result[-1], get(a:separators, l:i, ''))
	    else
		call add(l:result, [(l:i > 0 ? get(a:separators, l:i - 1, '') : ''), l:part, get(a:separators, l:i, '')])
	    endif
	    let l:lastAcceptedIndex = l:i
	    let l:result[0] += 1
	endif
    endfor
    return l:result
endfunction
function! s:FilterItems( Comparer, evaluation )
    let l:partsNum = call(a:Comparer, [map(copy(a:evaluation), 'v:val[0]')])
    return
    \   map(
    \       filter(
    \           copy(a:evaluation),
    \           'v:val[0] == l:partsNum'
    \       ),
    \       'v:val[1:]'
    \   )
endfunction
function! s:GetUnjoinedResult( filteredItems )
    let l:unjoinedResult = a:filteredItems[0]
    for l:i in range(len(l:unjoinedResult))
	let l:j = 0
	while l:j < len(l:unjoinedResult[l:i])
	    for l:otherResult in a:filteredItems[1:]
		if type(l:unjoinedResult[l:i][l:j]) != type([]) &&
		\   get(get(l:otherResult, l:i, []), l:j, '') !=# l:unjoinedResult[l:i][l:j]
		    let l:unjoinedResult[l:i][l:j] = [] " Discontinuation marker: split here later.
		endif
	    endfor
	    let l:j += 2    " Only check the separators on positions 0, 2, 4, ...
	endwhile
    endfor
    return l:unjoinedResult
endfunction
function! s:UnjoinResult( unjoinedResult )
    let l:result = ['']
    for l:resultPart in a:unjoinedResult
	while ! empty(l:resultPart)
	    if type(l:resultPart[0]) == type([]) && l:resultPart[0] == []
		call remove(l:resultPart, 0)
		call add(l:result, '')
	    else
		let l:result[-1] .= remove(l:resultPart, 0)
	    endif
	endwhile

	call add(l:result, '')
    endfor

    return filter(l:result, '! empty(v:val)')
endfunction

function! ingo#digest#BufferList( bufferList, ... )
"******************************************************************************
"* PURPOSE:
"   Determine common elements from the passed a:bufferList.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:bufferList	List of buffer numbers (or names).
"   a:percentage        Optional value between 1 and 100 that specifies the
"			percentage of the items in which a part has to occur in
"			order to be kept in the digest. Default 100, i.e. a part
"			has to occur in all items.
"* RETURN VALUES:
"   List of non-consecutive parts that occur in all / a:percentage of buffer
"   names. Consecutive parts are re-joined.
"******************************************************************************
    " Commonality in path and file name (without extensions)?
    let l:digest = call('ingo#digest#Get', [map(copy(a:bufferList), 'fnamemodify(bufname(v:val), ":p:r")'), '\A\+'] + a:000)
    if empty(l:digest)
	" Commonality in file extensions?
	let l:digest = call('ingo#digest#Get', [map(copy(a:bufferList), 'fnamemodify(bufname(v:val), ":e")'), '\A\+'] + a:000)
    endif
    if empty(l:digest)
	" Commonality in CamelParts?
	let l:digest = call('ingo#digest#Get', [map(copy(a:bufferList), 'fnamemodify(bufname(v:val), ":p")'), '\l\zs\ze\u'] + a:000)
    endif

    return l:digest
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo
" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
autoload/ingo/encoding.vim	[[[1
17
" ingo/encoding.vim: Functions for dealing with character encodings.
"
" DEPENDENCIES:
"
" Copyright: (C) 2015 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
"
" REVISION	DATE		REMARKS
"   1.024.001	20-Feb-2015	file creation

function! ingo#encoding#GetFileEncoding()
    return (empty(&l:fileencoding) ? &encoding : &l:fileencoding)
endfunction

" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
autoload/ingo/err.vim	[[[1
119
" ingo/err.vim: Functions for proper Vim error handling with :echoerr.
"
" DEPENDENCIES:
"
" Copyright: (C) 2013-2017 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
"
" REVISION	DATE		REMARKS
"   1.030.006	23-May-2017	Add ingo#err#Command() for an alternative way of
"				passing back [error] commands to be executed.
"   1.029.005	17-Dec-2016	Add ingo#err#SetAndBeep().
"   1.028.004	18-Nov-2016	ENH: Add optional {context} to all ingo#err#...
"				functions, in case other custom commands can be
"				called between error setting and checking, to
"				avoid clobbering of your error message.
"   1.009.003	14-Jun-2013	Minor: Make substitute() robust against
"				'ignorecase'.
"   1.005.002	17-Apr-2013	Add ingo#err#IsSet() for those cases when
"				wrapping the command in :if does not work (e.g.
"				:call'ing a range function).
"   1.002.001	08-Mar-2013	file creation

"******************************************************************************
"* PURPOSE:
"   Custom commands should use :echoerr for error reporting, because that also
"   properly aborts a command sequence. The echoing via ingo#msg#ErrorMsg() does
"   not provide this and is therefore deprecated (though sufficient for most
"   purposes).
"   This set of functions solves the problem that the error is often raised in a
"   function, but the :echoerr has to be done directly from the :command (to
"   avoid the printing of the multi-line error source). Unfortunately, an error
"   is still raised when an empty expression is used. One could return the error
"   string from the function and then perform the :echoerr on non-empty result,
"   but that requires a temporary (global) variable and is cumbersome.
"* USAGE:
"   Inside your function, invoke one of the ingo#err#Set...() functions.
"   Indicate to the invoking :command via a boolean flag whether the command
"   succeeded. On failure, :echoerr the stored error message via ingo#err#Get().
"	command! Foo if ! Foo#Bar() | echoerr ingo#err#Get() | endif
"   If you cannot wrap the function in :if, you have to ingo#err#Clear() the
"   message inside your function, and invoke like this:
"	function! Foo#Bar() range
"	    call ingo#err#Clear()
"	    ...
"	endfunction
"	nnoremap <Leader>f :call Foo#Bar()<Bar>if ingo#err#IsSet()<Bar>echoerr ingo#err#Get()<Bar>endif<CR>
"   Don't invoke anything after the :echoerr ... | endif | XXX! Though this is
"   normally executed, when run inside try...catch, it isn't! Better place the
"   command(s) between your function and the :echoerr, and also query
"   ingo#err#IsSet() to avoid having to use a temporary variable to get the
"   returned error flag across the command(s).
"   If there's a chance that other custom commands (that may also use these
"   error functions) are invoked between your error setting and checking (also
"   maybe triggered by autocmds), you can pass an optional {context} (e.g. your
"   plugin / command name) to any of the commands.
"   Note: With this approach, further typed commands will be aborted in a macro
"   / mapping. However, further commands in a command sequence or function (even
"   with :function-abort) will still be executed, unlike built-in commands (e.g.
"   :substitute/doesNotExist//). To prevent execution of further commands, you
"   have to wrap everything in try...catch (which is recommended anyhow, because
"   a function abort will still print a ugly multi-line exception, not a short
"   user-friendly message).
"******************************************************************************
let s:err = {}
let s:errmsg = ''
function! ingo#err#Get( ... )
    return (a:0 ? get(s:err, a:1, '') : s:errmsg)
endfunction
function! ingo#err#Clear( ... )
    if a:0
	let s:err[a:1] = ''
    else
	let s:errmsg = ''
    endif
endfunction
function! ingo#err#IsSet( ... )
    return ! empty(a:0 ? get(s:err, a:1, '') : s:errmsg)
endfunction
function! ingo#err#Set( errmsg, ... )
    if a:0
	let s:err[a:1] = a:errmsg
    else
	let s:errmsg = a:errmsg
    endif
endfunction
function! ingo#err#SetVimException( ... )
    call call('ingo#err#Set', [ingo#msg#MsgFromVimException()] + a:000)
endfunction
function! ingo#err#SetCustomException( customPrefixPattern, ... )
    call call('ingo#err#Set', [substitute(v:exception, printf('^\C\%%(%s\):\s*', a:customPrefixPattern), '', '')] + a:000)
endfunction
function! ingo#err#SetAndBeep( text )
    call ingo#err#Set(a:text)
    execute "normal! \<C-\>\<C-n>\<Esc>" | " Beep.
endfunction


"******************************************************************************
"* PURPOSE:
"   Sometimes you cannot return the status, but need to directly return the set
"   of commands to execute, or alternatively the error command. This function
"   allows you to assemble such.
"* USAGE:
"	command! Foo execute Foo#Bar()
"	function! Foo#Bar()
"	    if (error)
"		return ingo#err#Command('This did not work')
"	    else
"		return 'echomsg "yay, okay"'
"	    endif
"	endfunction
"******************************************************************************
function! ingo#err#Command( errmsg )
    return 'echoerr ' . string(a:errmsg)
endfunction

" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
autoload/ingo/escape.vim	[[[1
70
" ingo/escape.vim: Functions to escape different strings.
"
" DEPENDENCIES:
"
" Copyright: (C) 2013-2017 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
"
" REVISION	DATE		REMARKS
"   1.029.003	16-Dec-2016	Add ingo#escape#OnlyUnescaped().
"   1.017.002	20-Feb-2014	Add ingo#escape#UnescapeExpr().
"   1.009.001	15-Jun-2013	file creation

function! ingo#escape#UnescapeExpr( string, expr )
"******************************************************************************
"* PURPOSE:
"   Remove a leading backslash before all matches of a:expr that occur in
"   a:string, and are not itself escaped.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:string    The text to unescape.
"   a:expr      Regular expression to unescape.
"* RETURN VALUES:
"   Unescaped a:string.
"******************************************************************************
    return substitute(a:string, '\%(\%(^\|[^\\]\)\%(\\\\\)*\\\)\@<!\\\ze' . a:expr, '', 'g')
endfunction

function! ingo#escape#Unescape( string, chars )
"******************************************************************************
"* PURPOSE:
"   Remove a leading backslash before all a:chars that occur in a:string, and
"   are not itself escaped.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:string    The text to unescape.
"   a:chars     All characters to unescape; probably includes at least the
"		backslash itself.
"* RETURN VALUES:
"   Unescaped a:string.
"******************************************************************************
    return substitute(a:string, '\C\%(\%(^\|[^\\]\)\%(\\\\\)*\\\)\@<!\\\ze[' . escape(a:chars, ']^\-') . ']', '', 'g')
endfunction

function! ingo#escape#OnlyUnescaped( string, chars )
"******************************************************************************
"* PURPOSE:
"   Escape the characters in a:chars that occur in a:string and are not yet
"   escaped (this is the difference to built-in escape()) with a backslash.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:string    The text to escape.
"   a:chars     All characters to escape (unless they are already escaped).
"* RETURN VALUES:
"   Escaped a:string.
"******************************************************************************
    return substitute(a:string, '\C\%(\%(^\|[^\\]\)\%(\\\\\)*\\\)\@<![' . escape(a:chars, ']^\-') . ']', '\\&', 'g')
endfunction

" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
autoload/ingo/escape/command.vim	[[[1
84
" ingo/escape/command.vim: Additional escapings of Ex commands.
"
" DEPENDENCIES:
"   - ingo/collections/fromsplit.vim autoload script
"   - ingo/compat.vim autoload script
"
" Copyright: (C) 2013-2017 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
"
" REVISION	DATE		REMARKS
"   1.025.002	29-Apr-2016	Add ingo#escape#command#mapunescape().
"   1.012.001	09-Aug-2013	file creation

function! ingo#escape#command#mapescape( command )
"******************************************************************************
"* PURPOSE:
"   Escape the Ex command a:command for use in the right-hand side of a mapping.
"   If you want to redefine an existing mapping, use ingo#compat#maparg()
"   instead; it already returns this in the correct format.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:command   Ex command(s).
"* RETURN VALUES:
"   a:command for use in a :map command.
"******************************************************************************
    let l:command = a:command
    let l:command = substitute(l:command, '<', '<lt>', 'g')     " '<' may introduce a special-notation key; better escape them all.
    let l:command = substitute(l:command, '|', '<Bar>', 'g')    " '|' must be escaped, or the map command will end prematurely.
    return l:command
endfunction

function! ingo#escape#command#mapunescape( command )
"******************************************************************************
"* PURPOSE:
"   Unescape special mapping characters (<Bar>, <lt>) in a:command.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:command   Ex command(s).
"* RETURN VALUES:
"   a:command for use in a :map command.
"******************************************************************************
    let l:command = a:command
    let l:command = substitute(l:command, '<lt>', '<', 'g')
    let l:command = substitute(l:command, '<Bar>', '|', 'g')
    return l:command
endfunction

function! ingo#escape#command#mapeval( mapping )
"******************************************************************************
"* PURPOSE:
"   Interpret mapping characters (<C-W>, <CR>) into the actual characters (^W,
"   ^M).
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:mapping   String that may contain 'key-notation'.
"* RETURN VALUES:
"   a:mapping with key notation mapping characters converted into the actual
"   characters.
"******************************************************************************
    " Split on <...> and prefix those with a backslash. The rest needs
    " backslashes and double quotes escaped (for string interpolation), the
    " <...> only (unlikely) double quotes; <C-\\> != <C-\>!
    let l:string = join(
    \   ingo#collections#fromsplit#MapItemsAndSeparators(a:mapping, '\%(\%(^\|[^\\]\)\%(\\\\\)*\\\)\@<!<[^>]\+>',
    \       'escape(v:val, ''\"'')',
    \       '"\\" . escape(v:val, ''"'')'
    \   ),
    \   ''
    \)
    execute 'return "' . l:string . '"'
endfunctio

" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
autoload/ingo/escape/file.vim	[[[1
163
" ingo/escape/file.vim: Additional escapings of filespecs.
"
" DEPENDENCIES:
"   - ingo/os.vim autoload script
"
" Copyright: (C) 2013-2016 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
"
" REVISION	DATE		REMARKS
"   1.025.005	01-Mar-2016	BUG: Unescaped backslash resulted in unclosed
"				[...] regexp collection causing
"				ingo#escape#file#fnameunescape() to fail to
"				escape on Unix.
"   1.023.004	17-Dec-2014	ENH: Add a:isFile flag to
"				ingo#escape#file#bufnameescape() in order to do
"				full matching on scratch buffer names. There,
"				the expansion to a full absolute path must be
"				skipped in order to match.
"   1.019.003	23-May-2014	FIX: Correct ingo#escape#file#wildcardescape()
"				of * and ? on Windows.
"   1.018.002	21-Mar-2014	Add ingo#escape#file#wildcardescape().
"   1.012.001	08-Aug-2013	file creation

function! ingo#escape#file#bufnameescape( filespec, ... )
"*******************************************************************************
"* PURPOSE:
"   Escape a normal filespec syntax so that it can be used for the bufname(),
"   bufnr(), bufwinnr() commands.
"   Note: bufexists(), buflisted() and bufloaded() do not need
"   ingo#escape#file#bufnameescape() escaping; they only match relative or full
"   paths, anyway.
"   Ensure that there are no double (back-/forward) slashes inside the path; the
"   anchored pattern doesn't match in those cases!
"
"* ASSUMPTIONS / PRECONDITIONS:
"	? List of any external variable, control, or other element whose state affects this procedure.
"* EFFECTS / POSTCONDITIONS:
"	? List of the procedure's effect on each external variable, control, or other element.
"* INPUTS:
"   a:filespec	    Normal filespec
"   a:isFullMatch   Optional flag whether only the full filespec should be
"		    matched (default=1). If 0, the escaped filespec will not be
"		    anchored.
"   a:isFile        Optional flag whether a:filespec represents a file
"		    (default=1). Set to 0 to search for (scratch) buffers with
"		    'buftype' set to "nofile" with a:isFullMatch = 1.
"* RETURN VALUES:
"   Filespec escaped for the bufname() etc. commands listed above.
"*******************************************************************************
    let l:isFullMatch = (a:0 ? a:1 : 1)
    let l:isFile = (a:0 >= 2 ? a:2 : 1)

    " For a full match, the passed a:filespec must be converted to a full
    " absolute path (with symlinks resolved, just like Vim does on opening a
    " file) in order to match.
    let l:escapedFilespec = (l:isFile ? resolve(fnamemodify(a:filespec, ':p')) : a:filespec)

    " Backslashes are converted to forward slashes, as the comparison is done with
    " these on all platforms, anyway (cp. :help file-pattern).
    let l:escapedFilespec = tr(l:escapedFilespec, '\', '/')

    " Special file-pattern characters must be escaped: [ escapes to [[], not \[.
    let l:escapedFilespec = substitute(l:escapedFilespec, '[\[\]]', '[\0]', 'g')

    " The special filenames '#' and '%' need not be escaped when they are anchored
    " or occur within a longer filespec.
    let l:escapedFilespec = escape(l:escapedFilespec, '?*')

    " I didn't find any working escaping for {, so it is replaced with the ?
    " wildcard.
    let l:escapedFilespec = substitute(l:escapedFilespec, '[{}]', '?', 'g')

    if l:isFullMatch
	" The filespec must be anchored to ^ and $ to avoid matching filespec
	" fragments.
	return '^' . l:escapedFilespec . '$'
    else
	return l:escapedFilespec
    endif
endfunction

function! ingo#escape#file#fnameunescape( exfilespec, ... )
"*******************************************************************************
"* PURPOSE:
"   Converts the passed a:exfilespec to the normal filespec syntax (i.e. no
"   escaping of Ex special chars like [%#]). The normal syntax is required by
"   Vim functions such as filereadable(), because they do not understand the
"   escaping for Ex commands.
"   Note: On Windows, fnamemodify() doesn't convert path separators to
"   backslashes. We don't force that neither, as forward slashes work just as
"   well and there is even less potential for problems.
"* ASSUMPTIONS / PRECONDITIONS:
"	? List of any external variable, control, or other element whose state affects this procedure.
"* EFFECTS / POSTCONDITIONS:
"	? List of the procedure's effect on each external variable, control, or other element.
"* INPUTS:
"   a:exfilespec    Escaped filespec to be passed as a {file} argument to an Ex
"		    command.
"   a:isMakeFullPath	Flag whether the filespec should also be expanded to a
"			full path, or kept in whatever form it currently is.
"* RETURN VALUES:
"   Unescaped, normal filespec.
"*******************************************************************************
    let l:isMakeFullPath = (a:0 ? a:1 : 0)
    return fnamemodify(a:exfilespec, ':gs+\\\([ \t\n*?`%#''"|!<' . (ingo#os#IsWinOrDos() ? '' : '[{$\\') . ']\)+\1+' . (l:isMakeFullPath ? ':p' : ''))
endfunction

function! ingo#escape#file#autocmdescape( filespec )
"******************************************************************************
"* PURPOSE:
"   Escape a normal filespec syntax so that it can be used in an :autocmd.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:filespec	    Normal filespec or file pattern.
"* RETURN VALUES:
"   Escaped filespec to be passed as a {pat} argument to :autocmd.
"******************************************************************************
    let l:filespec = a:filespec

    if ingo#os#IsWinOrDos()
	" Windows: Replace backslashes in filespec with forward slashes.
	" Otherwise, the autocmd won't match the filespec.
	let l:filespec = tr(l:filespec, '\', '/')
    endif

    " Escape spaces in filespec.
    " Otherwise, the autocmd will be parsed wrongly, taking only the first part
    " of the filespec as the file and interpreting the remainder of the filespec
    " as part of the command.
    return escape(l:filespec, ' ')
endfunction

function! ingo#escape#file#wildcardescape( filespec )
"******************************************************************************
"* PURPOSE:
"   Escape a normal filespec for (literal) use in glob(). Escapes [, ?, * and
"   **.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:filespec	    Normal filespec
"* RETURN VALUES:
"   Escaped filespec to be passed as an argument to glob().
"******************************************************************************
    " On Unix, * and ? can be escaped via backslash; this doesn't work on
    " Windows, though, so we use the alternative [*]. We only need to ensure
    " that the wildcard is deactivated, as Windows file systems cannot contain
    " literal * and ? characters, anyway.
    if ingo#os#IsWinOrDos()
	return substitute(a:filespec, '[[?*]', '[&]', 'g')
    else
	return substitute(escape(a:filespec, '?*'), '[[]', '[[]', 'g')
    endif
endfunction

" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
autoload/ingo/escape/shellcommand.vim	[[[1
41
" ingo/escape/shellcommand.vim: Additional escapings of shell commands.
"
" DEPENDENCIES:
"
" Copyright: (C) 2013-2014 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
"
" REVISION	DATE		REMARKS
"   1.016.003	21-Jan-2014	Move ingo#escape#shellcommand#shellcmdescape()
"				to ingo#compat#shellcommand#escape(), as it is
"				only required for older Vim versions.
"   1.012.002	09-Aug-2013	Rename file.
"	001	08-Aug-2013	file creation from escapings.vim.

function! ingo#escape#shellcommand#exescape( command )
"*******************************************************************************
"* PURPOSE:
"   Escape a shell command (potentially consisting of multiple commands and
"   including (already quoted) command-line arguments) so that it can be used in
"   Ex commands. For example: 'hostname && ps -ef | grep -e "foo"'.
"
"* ASSUMPTIONS / PRECONDITIONS:
"	? List of any external variable, control, or other element whose state affects this procedure.
"* EFFECTS / POSTCONDITIONS:
"	? List of the procedure's effect on each external variable, control, or other element.
"* INPUTS:
"   a:command	    Shell command-line.
"
"* RETURN VALUES:
"   Escaped shell command to be passed to the !{cmd} or :r !{cmd} commands.
"*******************************************************************************
    if exists('*fnameescape')
	return join(map(split(a:command, ' '), 'fnameescape(v:val)'), ' ')
    else
	return escape(a:command, '\%#|' )
    endif
endfunction

" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
autoload/ingo/event.vim	[[[1
45
" ingo/event.vim: Functions for triggering events.
"
" DEPENDENCIES:
"
" Copyright: (C) 2015-2017 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>

if v:version == 703 && has('patch438') || v:version > 703
function! ingo#event#Trigger( arguments )
    execute 'doautocmd <nomodeline>' a:arguments
endfunction
function! ingo#event#TriggerEverywhere( arguments )
    execute 'doautoall <nomodeline>' a:arguments
endfunction
else
function! ingo#event#Trigger( arguments )
    let l:save_modeline = &l:modeline
    setlocal nomodeline
    try
	execute 'doautocmd             ' a:arguments
    finally
	let &l:modeline = l:save_modeline
    endtry
endfunction
function! ingo#event#TriggerEverywhere( arguments )
    let l:save_modeline = &l:modeline
    setlocal nomodeline
    try
	execute 'doautoall             ' a:arguments
    finally
	let &l:modeline = l:save_modeline
    endtry
endfunction
endif

function! ingo#event#TriggerCustom( eventName )
    silent call ingo#event#Trigger('User ' . a:eventName)
endfunction
function! ingo#event#TriggerEverywhereCustom( eventName )
    silent call ingo#event#TriggerEverywhere('User ' . a:eventName)
endfunction

" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
autoload/ingo/external.vim	[[[1
26
" ingo/external.vim: Functions to launch an external Vim instance.
"
" DEPENDENCIES:
"   - ingo/compat.vim autoload script
"   - ingo/os.vim autoload script
"
" Copyright: (C) 2013 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
"
" REVISION	DATE		REMARKS
"   1.013.005	13-Sep-2013	Use operating system detection functions from
"				ingo/os.vim.
"   1.012.004	08-Aug-2013	Move escapings.vim into ingo-library.
"   1.004.003	09-Apr-2013	FIX: "E117: Unknown function: s:externalLaunch".
"   1.002.002	25-Feb-2013	ENH: Allow to specify filespec of GVIM
"				executable.
"   1.000.001	28-Jan-2013	file creation from DropQuery.vim

let s:externalLaunch = (ingo#os#IsWindows() ? 'silent !start' : 'silent !')
function! ingo#external#LaunchGvim( commands, ... )
    execute s:externalLaunch . ' ' . (a:0 ? a:1 : 'gvim') join(map(a:commands, '"-c " . ingo#compat#shellescape(v:val, 1)'))
endfunction

" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
autoload/ingo/file.vim	[[[1
101
" ingo/file.vim: Functions to work on files not loaded into Vim.
"
" DEPENDENCIES:
"
" Copyright: (C) 2019 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
let s:save_cpo = &cpo
set cpo&vim

if ! exists('g:IngoLibrary_FileCacheMaxSize')
    let g:IngoLibrary_FileCacheMaxSize = 1048576
endif

let s:cachedFileContents = {}
let s:cachedFileInfo = {}
function! s:GetCacheSize()
    return ingo#collections#Reduce(
    \   map(values(s:cachedFileInfo), 'v:val.fsize'),
    \   'v:val[0] + v:val[1]',
    \   0
    \)
endfunction
function! ingo#file#GetCachedFilesByAge()
    return map(sort(items(s:cachedFileInfo), 's:SortByATime'), 'v:val[0]')
endfunction
function! s:GetOldestElement()
    return ingo#file#GetCachedFilesByAge()[0]
endfunction
function! s:SortByATime( i1, i2 )
    return ingo#collections#SortOnOneAttribute('atime', a:i1[1], a:i2[1])
endfunction
function! s:AddToCache( filespec, lines, ftime, fsize )
    if a:fsize > g:IngoLibrary_FileCacheMaxSize
	" Too large for the cache.
	return 0
    endif

    while len(s:cachedFileInfo) > 0 && g:IngoLibrary_FileCacheMaxSize - s:GetCacheSize() < a:fsize
	" Need to evict old elements from the cache to make room.
	call s:RemoveFromCache(s:GetOldestElement())
    endwhile

    let s:cachedFileContents[a:filespec] = copy(a:lines)
    let s:cachedFileInfo[a:filespec] = {'atime': localtime(), 'ftime': a:ftime, 'fsize': a:fsize}
endfunction
function! s:UseFromCache( filespec )
    let s:cachedFileInfo[a:filespec].atime = localtime()
    return s:cachedFileContents[a:filespec]
endfunction
function! s:IsCached( filespec, ftime )
    return has_key(s:cachedFileInfo, a:filespec) && s:cachedFileInfo[a:filespec].ftime == a:ftime
endfunction
function! s:RemoveFromCache( filespec )
    if has_key(s:cachedFileInfo, a:filespec)
	unlet! s:cachedFileInfo[a:filespec]
    endif
    if has_key(s:cachedFileContents, a:filespec)
	unlet! s:cachedFileContents[a:filespec]
    endif
endfunction

function! ingo#file#GetLines( filespec )
"******************************************************************************
"* PURPOSE:
"   Load the contents of a:filespec and return the (possibly cached) lines.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:filespec  Text file to be read. File contents must be in Vim's 'encoding'.
"* RETURN VALUES:
"   Empty List if the file doesn't exist or is empty. List of lines otherwise.
"******************************************************************************
    let l:filespec = ingo#fs#path#Canonicalize(a:filespec, 1)
    let l:ftime = getftime(l:filespec)

    if l:ftime == -1
	" File doesn't exist (any longer).
	call s:RemoveFromCache(l:filespec)
	return []
    elseif s:IsCached(l:filespec, l:ftime)
	" File is in cache and hasn't been changed.
	return s:UseFromCache(l:filespec)
    endif

    try
	let l:lines = readfile(l:filespec)
	call s:AddToCache(l:filespec, l:lines, l:ftime, getfsize(l:filespec))
	return l:lines
    catch /^Vim\%((\a\+)\)\=:E484/ " E484: Can't open file
	call s:RemoveFromCache(l:filespec)
	return []
    endtry
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo
" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
autoload/ingo/filetype.vim	[[[1
28
" ingo/filetype.vim: Functions for the buffer's filetype(s).
"
" DEPENDENCIES:
"   - ingo/list.vim autoload script

" Copyright: (C) 2012-2017 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>

function! ingo#filetype#Is( filetypes )
    for l:ft in split(&filetype, '\.')
	if (index(ingo#list#Make(a:filetypes), l:ft) != -1)
	    return 1
	endif
    endfor

    return 0
endfunction

function! ingo#filetype#GetPrimary( ... )
    return get(split((a:0 ? a:1 : &filetype), '\.'), 0, '')
endfunction
function! ingo#filetype#IsPrimary( filetypes )
    return (index(ingo#list#Make(a:filetypes), ingo#filetype#GetPrimary()) != -1)
endfunction

" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
autoload/ingo/folds.vim	[[[1
290
" ingo/folds.vim: Functions for dealing with folds.
"
" DEPENDENCIES:
"
" Copyright: (C) 2008-2018 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>

function! s:FoldBorder( lnum, direction )
    let l:foldBorder = (a:direction < 0 ? foldclosed(a:lnum) : foldclosedend(a:lnum))
    return (l:foldBorder == -1 ? a:lnum : l:foldBorder)
endfunction
function! ingo#folds#RelativeWindowLine( lnum, count, direction, ... )
"******************************************************************************
"* PURPOSE:
"   Determine the line number a:count visible (i.e. not folded) lines away from
"   a:lnum, including all lines in closed folds.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:lnum  Line number to base the calculation on.
"   a:count     Number of visible lines away from a:lnum.
"   a:direction -1 for upward, 1 for downward relative movement of a:count lines
"   a:folddirection for a fold at the target, return the fold start lnum when
"		    -1, or the fold end lnum when 1. Defaults to a:direction,
"		    which amounts to the maximum covered lines, i.e. for upward
"		    movement, the fold start, for downward movement, the fold
"		    end
"* RETURN VALUES:
"   line number, or -1 if the relative line is out of the range of the lines in
"   the buffer.
"******************************************************************************
    let l:lnum = a:lnum
    let l:count = a:count

    while l:count > 0
	let l:lnum = s:FoldBorder(l:lnum, a:direction) + a:direction
	if a:direction < 0 && l:lnum < 1 || a:direction > 0 && l:lnum > line('$')
	    return -1
	endif

	let l:count -= 1
    endwhile

    return s:FoldBorder(l:lnum, (a:0 ? a:1 : a:direction))
endfunction
function! ingo#folds#NextVisibleLine( lnum, direction )
"******************************************************************************
"* PURPOSE:
"   Determine the line number of the next visible (i.e. not folded) line.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:lnum  Line number to base the calculation on. When this one isn't folded,
"	    it is returned.
"   a:direction -1 for upward, 1 for downward relative movement
"* RETURN VALUES:
"   line number, of -1 if there is no more visible line in that direction of the
"   buffer.
"******************************************************************************
    let l:lnum = a:lnum
    while l:lnum > 0 && l:lnum <= line('$')
	let l:borderLnum = (a:direction < 0 ? foldclosed(l:lnum) : foldclosedend(l:lnum))
	if l:borderLnum == -1
	    return l:lnum
	else
	    let l:lnum = l:borderLnum + a:direction
	endif
    endwhile

    return -1
endfunction
function! ingo#folds#LastVisibleLine( lnum, direction )
"******************************************************************************
"* PURPOSE:
"   Determine the line number of the last visible (i.e. not folded) line.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:lnum  Line number to base the calculation on.
"   a:direction -1 for upward, 1 for downward relative movement
"* RETURN VALUES:
"   line number, of -1 if there is no more visible line in that direction of the
"   buffer.
"******************************************************************************
    let l:lnum = ingo#folds#NextVisibleLine(a:lnum, a:direction)
    if l:lnum == -1
	return l:lnum
    endif

    while l:lnum > 0 && l:lnum <= line('$')
	if foldclosed(l:lnum) != -1
	    break
	endif

	let l:lnum += a:direction
    endwhile

    return l:lnum - a:direction
endfunction
function! ingo#folds#NextClosedLine( lnum, direction )
"******************************************************************************
"* PURPOSE:
"   Determine the line number of the next closed (i.e. folded) line.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:lnum  Line number to base the calculation on. When this one is folded, it
"           is returned.
"   a:direction -1 for upward, 1 for downward relative movement
"* RETURN VALUES:
"   line number, of -1 if there is no more folded line in that direction of the
"   buffer.
"******************************************************************************
    let l:lnum = a:lnum

    while l:lnum > 0 && l:lnum <= line('$')
	if foldclosed(l:lnum) != -1
	    return l:lnum
	endif

	let l:lnum += a:direction
    endwhile

    return -1
endfunction
function! ingo#folds#LastClosedLine( lnum, direction )
"******************************************************************************
"* PURPOSE:
"   Determine the line number of the last closed (i.e. folded) line. Unlike
"   foldclosedend(), considers multiple adjacent closed folds as one unit.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:lnum  Line number to base the calculation on.
"   a:direction -1 for upward, 1 for downward relative movement
"* RETURN VALUES:
"   line number, of -1 if there is no more folded line in that direction of the
"   buffer.
"******************************************************************************
    let l:lnum = ingo#folds#NextClosedLine(a:lnum, a:direction)
    if l:lnum == -1
	return l:lnum
    endif

    while l:lnum > 0 && l:lnum <= line('$')
	let l:borderLnum = (a:direction < 0 ? foldclosed(l:lnum) : foldclosedend(l:lnum))
	if l:borderLnum == -1
	    break
	endif

	let l:lnum = l:borderLnum + a:direction
    endwhile

    return l:lnum - a:direction
endfunction


function! ingo#folds#GetClosedFolds( startLnum, endLnum )
"******************************************************************************
"* PURPOSE:
"   Determine the ranges of closed folds within the passed range.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:startLnum First line of the range.
"   a:endLnum   Last line of the range.
"* RETURN VALUES:
"   List of [foldStartLnum, foldEndLnum] elements.
"******************************************************************************
    let l:folds = []
    let l:lnum = a:startLnum
    while l:lnum <= a:endLnum
	let l:foldEndLnum = foldclosedend(l:lnum)
	if l:foldEndLnum == -1
	    let l:lnum += 1
	else
	    call add(l:folds, [l:lnum, l:foldEndLnum])
	    let l:lnum = l:foldEndLnum + 1
	endif
    endwhile
    return l:folds
endfunction


function! ingo#folds#FoldedLines( startLine, endLine )
"******************************************************************************
"* PURPOSE:
"   Determine the number of lines in the passed range that lie hidden in a
"   closed fold; that is, everything but the first line of a closed fold.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:startLnum First line of the range.
"   a:endLnum   Last line of the range.
"* RETURN VALUES:
"   Returns [ number of folds in range, number of folded away (i.e. invisible)
"   lines ]. Sum both values to get the total number of lines in a fold in the
"   passed range.
"******************************************************************************
    let l:foldCnt = 0
    let l:foldedAwayLines = 0
    let l:line = a:startLine

    while l:line < a:endLine
	if foldclosed(l:line) == l:line
	    let l:foldCnt += 1
	    let l:foldend = foldclosedend(l:line)
	    let l:foldedAwayLines += (l:foldend > a:endLine ? a:endLine : l:foldend) - l:line
	    let l:line = l:foldend
	endif
	let l:line += 1
    endwhile

    return [ l:foldCnt, l:foldedAwayLines ]
endfunction

function! ingo#folds#GetOpenFoldRange( lnum )
"******************************************************************************
"* PURPOSE:
"   Determine the range of the open fold around a:lnum.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:lnum  Line number to be considered.
"* RETURN VALUES:
"   [startLnum, endLnum] of the fold. If the line is fully in closed fold(s) or
"   not inside a fold at all, returns the entire range of the buffer.
"******************************************************************************
    if foldlevel(a:lnum) == 0
	" No fold at that line.
	return [1, line('$')]
    endif

    let l:save_view = winsaveview()
    try
	let [l:originalClosedStartLnum, l:originalClosedEndLnum] = [foldclosed(a:lnum), foldclosedend(a:lnum)]

	execute a:lnum . 'foldclose'
	let l:isAtBeginningOfCurrentFold = (foldclosed(a:lnum) == a:lnum)

	if foldclosed(a:lnum) == l:originalClosedStartLnum && foldclosedend(a:lnum) == l:originalClosedEndLnum
	    " The :foldclose didn't have any noticeable effect; either the line
	    " is on a toplevel closed fold, or on an nested open, same-size fold
	    " (which we'll leave closed as a side effect).
	else
	    execute a:lnum . 'foldopen'
	endif

	if l:isAtBeginningOfCurrentFold
	    " [z would jump to the beginning of the previous open fold, and
	    " we've already determined the start of the open fold, anyway.
	    let l:startLnum = a:lnum
	else
	    silent! execute a:lnum . 'normal! [z'
	    let l:startLnum = line('.')
	endif

	silent! execute a:lnum . 'normal! ]z'
	let l:endLnum = line('.')
	if l:endLnum == l:startLnum
	    " The cursor didn't move; there's no open fold, so return the whole
	    " buffer.
	    return [1, line('$')]
	endif

	return [l:startLnum, l:endLnum]
    finally
	call winrestview(l:save_view)
    endtry
endfunction

" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
autoload/ingo/folds/containment.vim	[[[1
128
" ingo/folds/containment.vim: Functions for determining how folds are contained in each other.
"
" DEPENDENCIES:
"   - ingo/folds.vim autoload script
"
" Copyright: (C) 2018 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>

function! s:GetRawStructure( startLnum, endLnum, endFoldLevel )
"******************************************************************************
"* PURPOSE:
"   Get the ranges of folds for each fold level in the [a:startLnum, a:endLnum]
"   range, starting with the current level, up to a:endFoldLevel.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   Unless the current fold state exactly corresponds to 'foldlevel', folds may
"   open / close.
"* INPUTS:
"   a:startLnum First line of the range.
"   a:endLnum   Last line of the range.
"   a:endFoldLevel  Maximum fold level for which the structure is determined.
"                   The function may stop earlier if there are not so many
"                   nested folds.
"* RETURN VALUES:
"   List (starting with the current 'foldlevel') of levels containing Lists of
"   fold ranges.
"******************************************************************************
    let l:save_foldlevel = &l:foldlevel

    let l:result = []
    while &l:foldlevel < a:endFoldLevel
	let l:foldRanges = ingo#folds#GetClosedFolds(a:startLnum, a:endLnum)
	if empty(l:foldRanges)
	    break
	endif

	call add(l:result, l:foldRanges)
	let &l:foldlevel += 1
    endwhile

    let &l:foldlevel = l:save_foldlevel
    return l:result
endfunction
function! s:MakeFoldStructureObject( foldRange )
    return {'range': a:foldRange, 'folds': []}
endfunction
function! s:Insert( results, foldRange )
    for l:result in a:results
	if s:IsInside(l:result.range, a:foldRange)
	    if ! s:Insert(l:result.folds, a:foldRange)
		call add(l:result.folds, s:MakeFoldStructureObject(a:foldRange))
	    endif
	    return 1
	endif
    endfor
    return 0
endfunction
function! s:IsInside( resultRange, foldRange )
    return a:foldRange[0] >= a:resultRange[0] && a:foldRange[1] <= a:resultRange[1]
endfunction
function! ingo#folds#containment#GetStructure( startLnum, endLnum, ... )
"******************************************************************************
"* PURPOSE:
"   Create a nested structure of fold information, similar to what is visualized
"   by the fold column. Each element contains the folded line range in the range
"   attribute, and a List of contained sub-folds in the folds attribute.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   Unless the current fold state exactly corresponds to 'foldlevel', folds may
"   open / close.
"* INPUTS:
"   a:startLnum First line of the range.
"   a:endLnum   Last line of the range.
"   a:endFoldLevel  Optional maximum fold level for which the structure is
"                   determined. The function may stop earlier if there are not
"                   so many nested folds.
"* RETURN VALUES:
"   Nested List of [{'range': [2, 34], 'folds': [{...}, ...]}]
"******************************************************************************
    let l:endFoldLevel = (a:0 ? a:1 : 999)

    let l:rawStructure = s:GetRawStructure(a:startLnum, a:endLnum, l:endFoldLevel)
    if empty(l:rawStructure)
	return []
    endif

    let l:results = map(l:rawStructure[0], 's:MakeFoldStructureObject(v:val)')
    for l:levelStructure in l:rawStructure[1:]
	for l:levelFoldRange in l:levelStructure
	    call s:Insert(l:results, l:levelFoldRange)
	endfor
    endfor

    return l:results
endfunction

function! s:CountOneFoldLevel( structure )
    return map(a:structure, 'empty(v:val.folds) ? (v:val.range[1] - v:val.range[0] + 1) : s:CountOneFoldLevel(v:val.folds)')
endfunction
function! ingo#folds#containment#GetContainedFoldCounts( ...  )
"******************************************************************************
"* PURPOSE:
"   Create a nested structure that represents the nesting of folds in the passed
"   range. Each nested List represents a contained fold; numbers represent the
"   number of lines in leaf-level folds.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   Unless the current fold state exactly corresponds to 'foldlevel', folds may
"   open / close.
"* INPUTS:
"   a:startLnum First line of the range.
"   a:endLnum   Last line of the range.
"   a:endFoldLevel  Optional maximum fold level for which the structure is
"                   determined. The function may stop earlier if there are not
"                   so many nested folds.
"* RETURN VALUES:
"   List of Lists of numbers of lines that are folded but not further folded.
"******************************************************************************
    let l:structure = call('ingo#folds#containment#GetStructure', a:000)
    return s:CountOneFoldLevel(l:structure)
endfunction

" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
autoload/ingo/folds/persistence.vim	[[[1
39
" ingo/folds/persistence.vim: Functions to persist and restore manual folds.
"
" DEPENDENCIES:
"   - ingo/compat.vim autoload script
"
" Copyright: (C) 2015 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
"
" REVISION	DATE		REMARKS
"   1.023.001	01-Jan-2015	file creation

function! ingo#folds#persistence#SaveManualFolds()
    if &foldmethod !=# 'manual'
	return ''
    endif

    let l:filespec = tempname()
    let l:save_viewoptions = &viewoptions
    set viewoptions=folds
    try
	execute 'mkview' ingo#compat#fnameescape(l:filespec)
	return l:filespec
    finally
	let &viewoptions = l:save_viewoptions
    endtry

    return ''
endfunction
function! ingo#folds#persistence#RestoreManualFolds( handle )
    if empty(a:handle)
	return
    endif

    silent! execute 'source' ingo#compat#fnameescape(a:handle)
endfunction

" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
autoload/ingo/foldtext.vim	[[[1
18
" ingo/foldtext.vim: Functions for creating a custom foldtext.
"
" DEPENDENCIES:
"
" Copyright: (C) 2013 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
"
" REVISION	DATE		REMARKS
"   1.014.001	19-Sep-2013	file creation

function! ingo#foldtext#DefaultPrefix( text )
    let l:num = v:foldend - v:foldstart + 1
    return printf("+-%s %2d line%s%s%s", v:folddashes, l:num, (l:num == 1 ? '' : 's'), (empty(a:text) ? '' : ': '), a:text)
endfunction

" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
autoload/ingo/format.vim	[[[1
96
" ingo/format.vim: Functions for printf()-like formatting of data.
"
" DEPENDENCIES:
"
" Copyright: (C) 2013-2017 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
"
" REVISION	DATE		REMARKS
"   1.030.003	14-Apr-2017	Add ingo#format#Dict() variant of
"				ingo#format#Format() that only handles
"				identifier placeholders and a Dict containing
"				them.
"				ENH: ingo#format#Format(): Also handle a:fmt
"				without any "%" items without error.
"   1.029.002	23-Jan-2017	FIX: ingo#format#Format(): An invalid %0$
"				references the last passed argument instead of
"				yielding the empty string (as [argument-index$]
"				is 1-based). Add bounds check to avoid that
"				get() references index of -1.
"  				FIX: ingo#format#Format(): Also support escaping
"  				via "%%", as in printf().
"   1.015.001	18-Nov-2013	file creation

function! ingo#format#Format( fmt, ... )
"******************************************************************************
"* PURPOSE:
"   Return a String with a:fmt, where "%" items are replaced by the formatted
"   form of their respective arguments. Like |printf()|, but like Java's
"   String.format(), additionally supports explicit positioning with (1-based)
"   %[argument-index$], e.g. "The %2$s is %1$d".
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:fmt   printf()-like format string.
"	    %  [argument-index$]  [flags]  [field-width]  [.precision]  type
"   a:args  Arguments referenced by the format specifiers in the format string.
"	    If there are more arguments than format specifiers, the extra
"	    arguments are ignored (unlike printf()!). The number of arguments is
"	    variable and may be zero.
"* RETURN VALUES:
"   Formatted string.
"******************************************************************************
    let l:args = []
    let s:consumedOriginalArgIdx = -1
    let l:printfFormat = substitute(a:fmt, '%\@<!%\%(\(\d\+\)\$\|[^%]\)', '\=s:ProcessFormat(a:000, l:args, submatch(1))', 'g')
    return (empty(l:args) ? l:printfFormat : call('printf', [l:printfFormat] + l:args))
endfunction
function! s:ProcessFormat( originalArgs, args, argCnt )
    if empty(a:argCnt)
	" Consume an original argument, or supply an empty arg.
	" Note: This will fail for %f with "E807: Expected Float argument for
	" printf()".
	let s:consumedOriginalArgIdx += 1
	call add(a:args, get(a:originalArgs, s:consumedOriginalArgIdx, ''))
	return submatch(0)
    else
	" Copy the indexed argument.
	let l:indexedArg = (a:argCnt > 0 ? get(a:originalArgs, (a:argCnt - 1), '') : '')
	call add(a:args, l:indexedArg)
	return '%'
    endif
endfunction

function! ingo#format#Dict( fmt, dict )
"******************************************************************************
"* PURPOSE:
"   Return a String with a:fmt, where "%identifier$" items are replaced by the
"   formatted form of their respective arguments, e.g. "The %key$s" is
"   %value$d".
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:fmt   printf()-like format string.
"	    %  identifier $  [flags]  [field-width]  [.precision]  type
"   a:dict  Dictionary containing the identifiers referenced by the format
"   specifiers in the format string as keys; their corresponding values are then
"   used for the replacement.
"* RETURN VALUES:
"   Formatted string.
"******************************************************************************
    let l:args = []
    let l:printfFormat = substitute(a:fmt, '%\@<!%\(\w\+\)\$', '\=s:ProcessIdentifier(a:dict, l:args, submatch(1))', 'g')
    return (empty(l:args) ? l:printfFormat : call('printf', [l:printfFormat] + l:args))
endfunction
function! s:ProcessIdentifier( dict, args, identifier )
    call add(a:args, get(a:dict, a:identifier, ''))
    return '%'
endfunction

" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
autoload/ingo/format/columns.vim	[[[1
59
" ingo/format/columns.vim: Functions for formatting in multiple columns.
"
" DEPENDENCIES:
"   - ingo/strdisplaywidth.vim autoload script
"   - ingo/strdisplaywidth/pad.vim autoload script
"
" Copyright: (C) 2016 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
"
" REVISION	DATE		REMARKS
"	001	11-Aug-2016	file creation

function! ingo#format#columns#Distribute( strings, ... )
"******************************************************************************
"* PURPOSE:
"   Distribute a:strings to a number of (equally sized) columns, fitting a
"   maximum width of a:width / &columns.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:strings:  List of strings.
"   a:alignment One of "left", "middle", "right"; default is "left".
"   a:width     Maximum width of all columns taken together.
"   a:columnSeparatorWidth  Width of the column separator with which the
"			    returned inner List elements will be join()ed;
"			    default 1.
"* RETURN VALUES:
"   List of [[c1s1, c2s1, ...], [c1s2, c2s2, ...], ...]
"******************************************************************************
    let l:PadFunction = function('ingo#strdisplaywidth#pad#' . {'left': 'Right', 'middle': 'Middle', 'right': 'Left'}[a:0 ? a:1 : 'left'])
    let l:columnSeparatorWidth = (a:0 >= 3 ? a:3 : 1)
    let l:maxWidth = ingo#strdisplaywidth#GetMinMax(a:strings)[1]
    let l:colNum = (a:0 >= 2 ? a:2 : &columns) / (l:maxWidth + l:columnSeparatorWidth)
    let l:rowNum = len(a:strings) / l:colNum + (len(a:strings) % l:colNum == 0 ? 0 : 1)

    "let l:result = repeat([[]], l:rowNum)  " Unfortunately duplicates the same empty List.
    let l:result = []
    for l:i in range(l:rowNum)
	call add(l:result, [])
    endfor

    let l:i = 0
    for l:string in a:strings
	if l:i >= l:rowNum
	    let l:i = 0
	endif

	call add(l:result[l:i], call(l:PadFunction, [l:string, l:maxWidth]))
	let l:i += 1
    endfor

    return l:result
endfunction

" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
autoload/ingo/fs/path.vim	[[[1
231
" ingo/fs/path.vim: Functions for manipulating a file system path.
"
" DEPENDENCIES:
"   - ingo/compat.vim autoload script
"   - ingo/escape/file.vim autoload script
"   - ingo/os.vim autoload script
"   - ingo/fs/path/split.vim autoload script
"
" Copyright: (C) 2012-2018 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>

function! ingo#fs#path#Separator()
    return (exists('+shellslash') && ! &shellslash ? '\' : '/')
endfunction

function! ingo#fs#path#Normalize( filespec, ... )
"******************************************************************************
"* PURPOSE:
"   Change all path separators in a:filespec to the passed or the typical format
"   for the current platform.
"   On Windows and Cygwin, also converts between the different D:\ and
"   /cygdrive/d/ notations.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:filespec      Filespec, potentially with mixed / and \ path separators.
"   a:pathSeparator Optional path separator to be used. With the special value
"		    of ":/", normalizes to "/", but keeps a "C:/" drive letter
"		    prefix instead of translating to "/cygdrive/c/".
"* RETURN VALUES:
"   a:filespec with uniform path separators, according to the platform.
"******************************************************************************
    let l:pathSeparator = (a:0 ? (a:1 ==# ':/' ? '/' : a:1) : ingo#fs#path#Separator())
    let l:badSeparator = (l:pathSeparator ==# '/' ? '\' : '/')
    let l:result = tr(a:filespec, l:badSeparator, l:pathSeparator)

    if ingo#os#IsWinOrDos()
	let l:result = substitute(l:result, '^[/\\]cygdrive[/\\]\(\a\)\ze[/\\]', '\u\1:', '')
    elseif ingo#os#IsCygwin() && l:pathSeparator ==# '/' && ! (a:0 && a:1 ==# ':/')
	let l:result = substitute(l:result, '^\(\a\):', '/cygdrive/\l\1', '')
    endif

    return l:result
endfunction
function! ingo#fs#path#Canonicalize( filespec, ... )
"******************************************************************************
"* PURPOSE:
"   Convert a:filespec into a unique, canonical form that other instances can be
"   compared against for equality. Expands to an absolute filespec and may
"   change case. Removes ../ etc. Only resolves shortcuts / symbolic links on
"   demand, as it depends on the use case whether these should be identical or
"   not.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:filespec      Filespec, potentially relative or with mixed / and \ path
"                   separators.
"   a:isResolveLinks    Flag whether to resolve shortcuts / symbolic links, too;
"                       off by default.
"* RETURN VALUES:
"   Absolute a:filespec with uniform path separators and case, according to the
"   platform.
"******************************************************************************
    let l:absoluteFilespec = fnamemodify(a:filespec, ':p')  " Expand to absolute filespec before resolving; as this handles ~/, too.
    let l:simplifiedFilespec = (a:0 && a:1 ? resolve(l:absoluteFilespec) : simplify(l:absoluteFilespec))
    let l:result = ingo#fs#path#Normalize(l:simplifiedFilespec)
    if ingo#fs#path#IsCaseInsensitive(l:result)
	let l:result = tolower(l:result)
    endif
    return l:result
endfunction

function! ingo#fs#path#Combine( first, ... )
"******************************************************************************
"* PURPOSE:
"   Concatenate the passed filespec fragments into a filespec, ensuring that all
"   fragments are combined with proper path separators.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   Either pass a dirspec and one or many filenames:
"	a:dirspec, a:filename [, a:filename2, ...]
"   Or a single list containing all filespec fragments.
"	[a:dirspec, a:filename, ...]
"* RETURN VALUES:
"   Combined filespec.
"******************************************************************************
    if type(a:first) == type([])
	let l:dirspec = a:first[0]
	let l:filenames = a:first[1:]
    else
	let l:dirspec = a:first
	let l:filenames = a:000
    endif

    " Use path separator as exemplified by the passed dirspec.
    if l:dirspec =~# '\' && l:dirspec !~# '/'
	let l:pathSeparator = '\'
    elseif l:dirspec =~# '/'
	let l:pathSeparator = '/'
    else
	" The dirspec doesn't contain a path separator, fall back to the
	" system's default.
	let l:pathSeparator = ingo#fs#path#Separator()
    endif

    let l:filespec = l:dirspec
    for l:filename in l:filenames
	let l:filename = substitute(l:filename, '^[/\\]', '', '')
	let l:filespec .= (l:filespec =~# '^$\|[/\\]$' ? '' : l:pathSeparator) . l:filename
    endfor

    return l:filespec
endfunction

function! ingo#fs#path#IsUncPathRoot( filespec )
    let l:ps = escape(ingo#fs#path#Separator(), '\')
    let l:uncPathPattern = printf('^%s%s[^%s]\+%s[^%s]\+$', l:ps, l:ps, l:ps, l:ps, l:ps)
    return (a:filespec =~# l:uncPathPattern)
endfunction
function! ingo#fs#path#GetRootDir( filespec )
"******************************************************************************
"* PURPOSE:
"   Determine the root directory of a:filespec.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:filespec  Full path (use |::p| modifier if necessary).
"* RETURN VALUES:
"   Root drive / UNC path / "/".
"******************************************************************************
    if ! ingo#os#IsWinOrDos()
	return '/'
    endif

    let l:dir = a:filespec
    while fnamemodify(l:dir, ':h') !=# l:dir && ! ingo#fs#path#IsUncPathRoot(l:dir)
	let l:dir = fnamemodify(l:dir, ':h')
    endwhile

    if empty(l:dir)
	throw 'GetRootDir: Could not determine root dir!'
    endif

    return l:dir
endfunction

function! ingo#fs#path#IsAbsolute( filespec )
"******************************************************************************
"* PURPOSE:
"   Test whether a:filespec is an absolute filespec; i.e. starts with a root
"   drive / UNC path / "/".
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:filespec  Relative / absolute filespec. Does not need to exist.
"* RETURN VALUES:
"   1 if it is absolute, else 0.
"******************************************************************************
    let l:rootDir = ingo#fs#path#GetRootDir(fnamemodify(a:filespec, ':p'))
    return (type(ingo#fs#path#split#AtBasePath(a:filespec, l:rootDir)) != type([]))
endfunction

function! ingo#fs#path#IsUpwards( filespec )
"******************************************************************************
"* PURPOSE:
"   Test whether a:filespec navigates to a parent directory through ".." path
"   elements.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:filespec  Relative / absolute filespec. Does not need to exist.
"* RETURN VALUES:
"   1 if it navigates to a parent. 0 if it is absolute, or relative within the
"   current context.
"******************************************************************************
    return (ingo#fs#path#Normalize(simplify(a:filespec), '/') =~# '^\.\./')
endfunction

function! ingo#fs#path#IsCaseInsensitive( ... )
    return ingo#os#IsWinOrDos() " Note: Check based on path not yet implemented.
endfunction

function! ingo#fs#path#Equals( p1, p2 )
    if ingo#fs#path#IsCaseInsensitive(a:p1) || ingo#fs#path#IsCaseInsensitive(a:p2)
	return a:p1 ==? a:p2 || ingo#fs#path#Normalize(fnamemodify(a:p1, ':p')) ==? ingo#fs#path#Normalize(fnamemodify(a:p2, ':p'))
    else
	return a:p1 ==# a:p2 || ingo#fs#path#Normalize(fnamemodify(resolve(a:p1), ':p')) ==# ingo#fs#path#Normalize(fnamemodify(resolve(a:p2), ':p'))
    endif
endfunction

function! ingo#fs#path#Exists( filespec )
"******************************************************************************
"* PURPOSE:
"   Test whether the passed a:filespec exists (as a file or directory). This is
"   like the combination of filereadable() and isdirectory(), but without the
"   requirement that the file must be readable.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:filespec      Filespec or dirspec.
"* RETURN VALUES:
"   0 if there's no such file or directory, 1 if it exists.
"******************************************************************************
    " I suppose these are faster than the glob(), and this avoids any escaping
    " issues, too, so it is more robust.
    if filereadable(a:filespec) || isdirectory(a:filespec)
	return 1
    endif

    let l:filespec = ingo#escape#file#wildcardescape(a:filespec)
    return ! empty(ingo#compat#glob(l:filespec, 1))
endfunction

" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
autoload/ingo/fs/path/asfilename.vim	[[[1
76
" ingo/fs/path/asfilename.vim: Encode / decode any filespec as a single filename.
"
" DEPENDENCIES:
"   - ingo/dict.vim autoload script
"   - ingo/fs/path.vim autoload script
"   - ingo/fs/path/split.vim autoload script
"   - ingo/os.vim autoload script
"
" Copyright: (C) 2016 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
"
" REVISION	DATE		REMARKS
"   1.028.001	18-Oct-2016	file creation
let s:save_cpo = &cpo
set cpo&vim

    " ex_docmd.c:11754
    " We want a file name without separators, because we're not going to make
    " a directory.
    " "normal" path separator	-> "=+"
    " "="			-> "=="
    " ":" path separator	-> "=-"
let s:encoder = {
\   ingo#fs#path#Separator(): '=+',
\   '=': '==',
\   ':': '=-',
\}
let s:decoder = ingo#dict#Mirror(s:encoder)

function! ingo#fs#path#asfilename#Encode( filespec )
"******************************************************************************
"* PURPOSE:
"   Encode a:filespec as a single filename, like :mkview does.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:filespec  file spec (existing or non-existing, expansion to absolute path
"		and normalization will be attempted)
"* RETURN VALUES:
"   file name representing the absolute a:filespec; any path separators are
"   escaped.
"******************************************************************************
    let l:filespec = ingo#fs#path#Normalize(fnamemodify(a:filespec, ':p'))
    if ! empty($HOME)
	let l:homeRelativeFilespec = ingo#fs#path#split#AtBasePath(l:filespec, $HOME)
	if type(l:homeRelativeFilespec) != type([])
	    let l:filespec = ingo#fs#path#Combine('~', l:homeRelativeFilespec)
	endif
    endif

    return substitute(l:filespec, '[=' . escape(ingo#fs#path#Separator(), '\') . (ingo#os#IsWinOrDos() ? ':' : '') . ']', '\=s:encoder[submatch(0)]', 'g')
endfunction
function! ingo#fs#path#asfilename#Decode( filename )
"******************************************************************************
"* PURPOSE:
"   Decode a filespec encoded in a single filename via
"   ingo#fs#path#asfilename#Encode() to a filespec.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:filename  Encoded filespec
"* RETURN VALUES:
"   filespec
"******************************************************************************
    return expand(substitute(a:filename, '=[+=-]', '\=s:decoder[submatch(0)]', 'g'))
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo
" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
autoload/ingo/fs/path/split.vim	[[[1
224
" ingo/fs/path/split.vim: Functions for splitting a file system path.
"
" DEPENDENCIES:
"   - ingo/fs/path.vim autoload script
"   - ingo/str.vim autoload script
"
" Copyright: (C) 2014-2018 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
let s:save_cpo = &cpo
set cpo&vim

function! ingo#fs#path#split#PathAndName( filespec, ... )
"******************************************************************************
"* PURPOSE:
"   Split a:filespec into the (absolute, relative, or ".') path and the file
"   name itself.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:filespec                      Absolute / relative filespec.
"   a:isPathWithTrailingSeparator   Optional flag whether the returned file path
"				    ends with a trailing path separator. Default
"				    true.
"* RETURN VALUES:
"   [filepath, filename]
"******************************************************************************
    let l:isPathWithTrailingSeparator = (a:0 ? a:1 : 1)
    let [l:dirspec, l:filename] = [fnamemodify(a:filespec, ':h'), fnamemodify(a:filespec, ':t')]

    if l:isPathWithTrailingSeparator
	let l:dirspec = ingo#fs#path#Combine(l:dirspec, '')
    endif

    return [l:dirspec, l:filename]
endfunction

function! ingo#fs#path#split#AtBasePath( filespec, basePath, ... )
"******************************************************************************
"* PURPOSE:
"   Split off a:basePath from a:filespec. The check will be done on normalized
"   paths.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:filespec  Filespec.
"   a:basePath  Filespec to the base directory that contains a:filespec.
"   a:onBasePathNotExisting Optional value to be returned when a:filespec does
"                           not start with a:basePath; default empty List.
"* RETURN VALUES:
"   Remainder of a:filespec, after removing a:basePath, or empty List if
"   a:filespec did not start with a:basePath.
"******************************************************************************
    let l:filespec = ingo#fs#path#Combine(ingo#fs#path#Normalize(a:filespec, '/'), '')
    let l:basePath = ingo#fs#path#Combine(ingo#fs#path#Normalize(a:basePath, '/'), '')
    return (ingo#str#StartsWith(l:filespec, l:basePath, ingo#fs#path#IsCaseInsensitive(l:filespec)) ?
    \   strpart(a:filespec, len(l:basePath)) :
    \   (a:0 ? a:1 : [])
    \)
endfunction

function! ingo#fs#path#split#Contains( filespec, fragment )
"******************************************************************************
"* PURPOSE:
"   Test whether a:filespec contains a:fragment anywhere. To match entire
"   (anchored) path fragments, pass a fragment surrounded by forward slashes
"   (e.g. "/foo/"); you can always use forward slashes, as these will be
"   internally normalized.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:filespec  Filespec to be examined.
"   a:fragment  Path fragment that may be contained inside a:filespec.
"* RETURN VALUES:
"   1 if contained, 0 if not.
"******************************************************************************
    let l:filespec = ingo#fs#path#Combine(ingo#fs#path#Normalize(a:filespec, '/'), '')
    let l:fragment = ingo#fs#path#Normalize(a:fragment, '/')
    return ingo#str#Contains(l:filespec, l:fragment, ingo#fs#path#IsCaseInsensitive(l:filespec))
endfunction

function! ingo#fs#path#split#StartsWith( filespec, basePath )
"******************************************************************************
"* PURPOSE:
"   Test whether a:filespec starts with a:basePath, matching entire path
"   fragments. You can always use forward slashes, as these will be internally
"   normalized.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:filespec  Filespec to be examined.
"   a:basePath  Filespec to the base directory that is checked against.
"* RETURN VALUES:
"   1 if it starts with it, 0 if not.
"******************************************************************************
    let l:basePath = ingo#fs#path#split#AtBasePath(a:filespec, a:basePath)
    return (type(l:basePath) != type([]))
endfunction

function! ingo#fs#path#split#EndsWith( filespec, fragment )
"******************************************************************************
"* PURPOSE:
"   Test whether a:filespec ends with a:fragment. To match entire (anchored)
"   path fragments, pass a fragment surrounded by forward slashes (e.g.
"   "/foo/"); you can always use forward slashes, as these will be internally
"   normalized.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:filespec  Filespec to be examined.
"   a:fragment  Path fragment that may be contained inside a:filespec.
"* RETURN VALUES:
"   1 if it ends with it, 0 if not.
"******************************************************************************
    let l:filespec = ingo#fs#path#Normalize(a:filespec, '/')
    let l:fragment = ingo#fs#path#Normalize(a:fragment, '/')
    return ingo#str#EndsWith(l:filespec, l:fragment, ingo#fs#path#IsCaseInsensitive(l:filespec))
endfunction

function! ingo#fs#path#split#ChangeBasePath( filespec, basePath, newBasePath )
"******************************************************************************
"* PURPOSE:
"   Replace a:basePath in a:filespec with a:newBasePath. This will be done on
"   normalized paths.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:filespec  Filespec.
"   a:basePath  Filespec to the base directory that contains a:filespec.
"   a:newBasePath Filespec to the new base directory.
"* RETURN VALUES:
"   Changed a:filespec, or empty List if a:filespec did not start with
"   a:basePath.
"******************************************************************************
    let l:remainder = ingo#fs#path#split#AtBasePath(a:filespec, a:basePath)
    if type(l:remainder) == type([])
	return []
    endif
    return ingo#fs#path#Combine(ingo#fs#path#Normalize(a:newBasePath, '/'), l:remainder)
endfunction

if ! exists('g:IngoLibrary_TruncateEllipsis')
    let g:IngoLibrary_TruncateEllipsis = (&encoding ==# 'utf-8' ? "\u2026" : '...')
endif
function! ingo#fs#path#split#TruncateTo( filespec, virtCol, ...)
"******************************************************************************
"* PURPOSE:
"   Truncate a:filespec to a maximum of a:virtCol virtual columns by removing
"   directories from the inside, and replacing those with a "..." indicator.
"* SEE ALSO:
"   - ingo#avoidprompt#TruncateTo() does something similar with hard truncation
"     in the middle of a:text, without regards to (path or other) boundaries.
"* ASSUMPTIONS / PRECONDITIONS:
"   The default ellipsis can be configured by g:IngoLibrary_TruncateEllipsis.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:filespec  Filespec. It is assumed to be in normalized form already.
"   a:virtCol   Maximum virtual columns for a:text.
"   a:pathSeparator Optional path separator to be used. Defaults to the
"                   platform's default one.
"   a:truncationIndicator   Optional text to be appended when truncation
"			    appears. a:text is further reduced to account for
"			    its width. Default is "..." or the single-char UTF-8
"			    variant if the encoding also is UTF-8.
"* RETURN VALUES:
"   Truncated a:filespec.
"******************************************************************************
    let l:sep = (a:0 ? a:1 : ingo#fs#path#Separator())

    if ingo#compat#strdisplaywidth(a:filespec) <= a:virtCol
	return a:filespec " Short circuit.
    endif

    let l:truncationIndicator = (a:0 >= 2 ? a:2 : g:IngoLibrary_TruncateEllipsis)
    let l:fragments = split(a:filespec, '\C\V' . escape(l:sep, '\'), 1)

    let l:i = 0
    let l:result = l:fragments[-1]
    while 2 * l:i <= len(l:fragments)
	let l:joinedFragments = join(l:fragments[0: l:i] + [l:truncationIndicator] + l:fragments[-1 * (l:i + 1) : -1], l:sep)
	if ingo#compat#strdisplaywidth(l:joinedFragments) > a:virtCol
	    break
	endif

	let l:result = l:joinedFragments
	let l:i += 1
    endwhile

    " Try adding one more, with a preference to the deeper subdirectory.
    let l:joinedFragments = join(l:fragments[0: (l:i - 1)] + [l:truncationIndicator] + l:fragments[-1 * (l:i + 1) : -1], l:sep)
    if ingo#compat#strdisplaywidth(l:joinedFragments) <= a:virtCol
	let l:result = l:joinedFragments
    else
	let l:joinedFragments = join(l:fragments[0: l:i] + [l:truncationIndicator] + l:fragments[-1 * l:i : -1], l:sep)
	if ingo#compat#strdisplaywidth(l:joinedFragments) <= a:virtCol
	    let l:result = l:joinedFragments
	endif
    endif

    " Corner case: Also handle truncation in a single large final fragment.
    if l:i == 0
	let l:result = ingo#avoidprompt#TruncateTo(l:result, a:virtCol, 0, l:truncationIndicator)
    endif

    return l:result
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo
" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
autoload/ingo/fs/tempfile.vim	[[[1
81
" ingo/fs/tempfile.vim: Functions for creating temporary files.
"
" DEPENDENCIES:
"   - ingo/fs/path.vim autoload script
"   - ingo/os.vim autoload script
"
" Copyright: (C) 2012-2015 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
"
" REVISION	DATE		REMARKS
"   1.024.003	22-Apr-2015	Add optional a:templateForNewBuffer argument to
"				ingo#fs#tempfile#Make() and ensure (by default)
"				that the temp file isn't yet loaded in a Vim
"				buffer (which would generate "E139: file is
"				loaded in another buffer" on the usual :write,
"				:saveas commands).
"   1.013.002	13-Sep-2013	Use operating system detection functions from
"				ingo/os.vim.
"   1.007.001	01-Jun-2013	file creation from ingofile.vim

function! ingo#fs#tempfile#Make( filename, ... )
"******************************************************************************
"* PURPOSE:
"   Generate a filespec in a temporary location. Unlike the built-in
"   |tempname()| function, this allows specification of the file name (which can
"   be beneficial if you want to open the temp file in a Vim buffer for the user
"   to use). Otherwise, prefer tempname().
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:filename	filename of the temp file. If empty, the function will just
"		return the name of a writable temp directory, with trailing path
"		separator.
"   a:templateForNewBuffer  When the temp filespec is already loaded in a
"			    buffer, a counter is appended according to the
"			    passed printf()-specification (default: "-%d"). If
"			    empty, will not generate a unique filespec and
"			    instead return an empty string in case the filespec
"			    is already loaded.
"* RETURN VALUES:
"   Temp filespec.
"******************************************************************************
    let l:tempdirs = [fnamemodify(tempname(), ':t')]	" The built-in function should know best about a good temp dir.
    let l:tempdirs += [$TEMP, $TMP] " Also check common environment variables.

    " And finally try operating system-specific places.
    if ingo#os#IsWinOrDos()
	let l:tempdirs += [$HOMEDRIVE . $HOMEPATH, $WINDIR . '\Temp', 'C:\temp']
    else
	let l:tempdirs += [$TMPDIR, $HOME . '/tmp', '/tmp']
    endif

    for l:tempdir in l:tempdirs
	if filewritable(l:tempdir) == 2
	    let l:filespec = ingo#fs#path#Combine(l:tempdir, a:filename)
	    if empty(a:filename)
		return l:filespec   " Just return the temp dirspec (with appended path separator).
	    elseif bufnr(ingo#escape#file#bufnameescape(l:filespec)) == -1
		return l:filespec   " Not loaded in buffer yet.
	    elseif a:0 && empty(a:1)
		return ''   " Signal that it's already loaded.
	    else
		let l:cnt = 1
		while 1
		    let l:appendedFilespec = l:filespec . printf((a:0 ? a:1 : '-%d'), l:cnt)
		    if bufnr(ingo#escape#file#bufnameescape(l:appendedFilespec)) == -1
			return l:appendedFilespec   " Found a unique one.
		    endif
		    let l:cnt += 1  " Keep trying.
		endwhile
	    endif
	endif
    endfor
    throw 'MakeTempfile: No writable temp directory found!'
endfunction

" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
autoload/ingo/fs/traversal.vim	[[[1
128
" ingo/fs/traversal.vim: Functions for traversal of the file system.
"
" DEPENDENCIES:
"   - ingo/actions.vim autoload script
"   - ingo/compat.vim autoload script
"   - ingo/fs/path.vim autoload script
"   - ingo/os.vim autoload script
"
" Copyright: (C) 2013-2016 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
"
" REVISION	DATE		REMARKS
"   1.029.006	05-Dec-2016	Add
"				ingo#fs#traversal#FindFirstContainedInUpDir().
"   1.022.005	22-Sep-2014	Use ingo#compat#globpath().
"   1.013.004	13-Sep-2013	Use operating system detection functions from
"				ingo/os.vim.
"   1.011.003	01-Aug-2013	Make a:path argument optional and default to the
"				current buffer's directory (as all existing
"				clients use that).
"				Add ingo#fs#traversal#FindDirUpwards().
"   1.003.002	26-Mar-2013	Rename to
"				ingo#fs#traversal#FindLastContainedInUpDir()
"	001	22-Mar-2013	file creation
let s:save_cpo = &cpo
set cpo&vim

function! ingo#fs#traversal#FindDirUpwards( Predicate, ... )
"******************************************************************************
"* PURPOSE:
"   Find directory where a:Predicate matches in a:path, searching upwards. Like
"   |finddir()|, but supports not just fixed directory names, but only upwards
"   search.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:Predicate     Either a Funcref that gets invoked with a dirspec, or an
"		    expression where "v:val" is replaced with a dirspec.
"   a:dirspec   Optional starting directory. Should be absolute or at least in a
"		format that allows upward traversal via :h. If omitted, the
"		search starts from the current buffer's directory.
"* RETURN VALUES:
"   First dirspec where a:Predicate returns true.
"   Empty string when that never happens until the root directory is reached.
"******************************************************************************
    let l:dir = (a:0 ? a:1 : expand('%:p:h'))
    let l:prevDir = ''
    while l:dir !=# l:prevDir
	if ingo#actions#EvaluateWithValOrFunc(a:Predicate, l:dir)
	    return l:dir
	endif

	" Stop iterating after reaching the file system root.
	if ingo#os#IsWindows() && ingo#fs#path#IsUncPathRoot(l:dir)
	    break
	endif
	let l:prevDir = l:dir
	let l:dir = fnamemodify(l:dir, ':h')
    endwhile

    return ''
endfunction

function! ingo#fs#traversal#FindFirstContainedInUpDir( expr, ... )
"******************************************************************************
"* PURPOSE:
"   Traversing upwards from the current buffer's directory, find the first
"   directory that yields a match for the a:expr glob.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:expr  File glob that must match in the target upwards directory.
"   a:dirspec   Optional starting directory. Should be absolute or at least in a
"		format that allows upward traversal via :h. If omitted, the
"		search starts from the current buffer's directory.
"* RETURN VALUES:
"   Dirspec of the first parent directory that matches a:expr.
"   Empty string if a:expr every matches up to the filesytem's root.
"******************************************************************************
    return call(
    \   function('ingo#fs#traversal#FindDirUpwards'),
    \   [printf('! empty(ingo#compat#glob(ingo#fs#path#Combine(v:val, %s), 1))', string(a:expr))] + a:000
    \)
endfunction

function! ingo#fs#traversal#FindLastContainedInUpDir( expr, ... )
"******************************************************************************
"* PURPOSE:
"   Traversing upwards from the current buffer's directory, find the last
"   directory that yields a match for the a:expr glob.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:expr  File glob that must match in each upwards directory.
"   a:dirspec   Optional starting directory. Should be absolute or at least in a
"		format that allows upward traversal via :h. If omitted, the
"		search starts from the current buffer's directory.
"* RETURN VALUES:
"   Dirspec of the highest directory that still matches a:expr.
"   Empty string if a:expr doesn't even match in the starting directory.
"******************************************************************************
    let l:dir = (a:0 ? a:1 : expand('%:p:h'))
    let l:prevDir = ''
    while l:dir !=# l:prevDir
	if empty(ingo#compat#globpath(l:dir, a:expr, 1))
	    return l:prevDir
	endif
	let l:prevDir = l:dir
	let l:dir = fnamemodify(l:dir, ':h')
	if ingo#os#IsWindows() && ingo#fs#path#IsUncPathRoot(l:dir)
	    break
	endif
    endwhile

    return l:dir
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo
" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
autoload/ingo/ftplugin/converter.vim	[[[1
65
" ingo/ftplugin/converter.vim: Supporting functions to build a file converter.
"
" DEPENDENCIES:
"
" Copyright: (C) 2019 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>

function! s:GetName( commandDefinition )
    return (has_key(a:commandDefinition, 'name') ? a:commandDefinition.name : fnamemodify(a:commandDefinition.command, ':t'))
endfunction
function! ingo#ftplugin#converter#GetNames( commandDefinitions )
    return map(copy(a:commandDefinitions), "s:GetName(v:val)")
endfunction
function! ingo#ftplugin#converter#GetArgumentMaps( commandDefinitions )
    return ingo#dict#FromItems(map(copy(a:commandDefinitions), "[v:val.name, get(v:val, 'arguments', [])]"))
endfunction

function! ingo#ftplugin#converter#GetCommandDefinition( commandDefinitionsVariable, arguments )
    execute 'let l:commandDefinitions =' a:commandDefinitionsVariable

    if empty(l:commandDefinitions)
	throw printf('converter: No converters are configured in %s.', a:commandDefinitionsVariable)
    elseif empty(a:arguments)
	if len(l:commandDefinitions) > 1
	    throw 'converter: Multiple converters are available; choose one: ' . join(ingo#ftplugin#converter#GetNames(l:commandDefinitions), ', ')
	endif

	let l:command = l:commandDefinitions[0]
	let l:commandArguments = ''
    else
	let l:parse = matchlist(a:arguments, '^\(\S\+\)\s\+\(.*\)$')
	let [l:selectedName, l:commandArguments] = (empty(l:parse) ? [a:arguments, ''] : l:parse[1:2])

	let l:command = get(filter(copy(l:commandDefinitions), 'l:selectedName == s:GetName(v:val)'), 0, '')
	if empty(l:command)
	    if len(l:commandDefinitions) > 1
		throw printf('converter: No such converter: %s', l:selectedName)
	    else
		" With a single default command, these are just custom command
		" arguments passed through.
		let l:command = l:commandDefinitions[0]
		let l:commandArguments = a:arguments
	    endif
	endif
    endif

    return [l:command, l:commandArguments]
endfunction

function! s:Action( actionName, commandDefinition ) abort
    let l:Action = get(a:commandDefinition, a:actionName, '')
    if ! empty(l:Action)
	call ingo#actions#ExecuteOrFunc(l:Action)
    endif
endfunction
function! ingo#ftplugin#converter#PreAction( commandDefinition ) abort
    call s:Action('preAction', a:commandDefinition)
endfunction
function! ingo#ftplugin#converter#PostAction( commandDefinition ) abort
    call s:Action('postAction', a:commandDefinition)
endfunction

" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
autoload/ingo/ftplugin/converter/builder.vim	[[[1
122
" ingo/ftplugin/converter/builder.vim: Build a file converter via an Ex command.
"
" DEPENDENCIES:
"
" Copyright: (C) 2019 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>

function! s:FilterBuffer( commandDefinition, commandArguments, range, isBang )
    if has_key(a:commandDefinition, 'commandline')
	let l:commandLine = ingo#actions#ValueOrFunc(a:commandDefinition.commandline, {'definition': a:commandDefinition, 'range': a:range, 'isBang': a:isBang, 'arguments': a:commandArguments})
	if has_key(a:commandDefinition, 'command')
	    let l:command = ingo#format#Format(l:commandLine, ingo#compat#shellescape(a:commandDefinition.command), a:commandArguments)
	else
	    let l:command = ingo#format#Format(l:commandLine, a:commandArguments)
	endif
    elseif has_key(a:commandDefinition, 'command')
	let l:command = a:commandDefinition.command
    else
	throw 'converter: Neither command nor commandline defined for ' . get(a:commandDefinition, 'name', string(a:commandDefinition))
    endif

    call ingo#ftplugin#converter#PreAction(a:commandDefinition)
	silent! execute a:range . l:command
	if l:command =~# '^!' && v:shell_error != 0
	    throw 'converter: Conversion failed: shell returned ' . v:shell_error
	endif
    call ingo#ftplugin#converter#PostAction(a:commandDefinition)
endfunction

function! ingo#ftplugin#converter#builder#Filter( commandDefinitionsVariable, range, isBang, arguments, ... ) abort
"******************************************************************************
"* PURPOSE:
"   Build a command that filters the current buffer by filtering its contents
"   through an command.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   Changes the current buffer.
"* INPUTS:
"   a:commandDefinitionsVariable    Name of a List of Definitions objects:
"	command:    Command to execute.
"	commandline:printf() (or ingo#format#Format()) template for inserting
"		    command and command arguments to build the Ex command-line
"		    to execute. a:range is prepended to this. To filter through
"		    an external command, start the commandline with "!".
"		    Or a Funcref that gets passed the invocation context (and
"		    Dictionary with these keys: definition, range, isBang,
"		    arguments) and should return the (dynamically generated)
"		    commandline.
"	arguments:  List of possible command-line arguments supported by
"                   command, used as completion candidates.
"	filetype:   Optional value to :setlocal filetype to.
"	extension:  Optional file extension (for
"		    ingo#ftplugin#converter#external#ExtractText())
"	preAction:  Optional Ex command or Funcref that is invoked before the
"                   external command.
"	postAction: Optional Ex command or Funcref that is invoked after
"                   successful execution of the external command.
"   a:range         Range of lines to be filtered.
"   a:arguments     Converter argument (optional if there's just one configured
"                   converter), followed by optional arguments for
"                   a:commandDefinitionsVariable.command, all passed by the user
"                   to the built command.
"   a:preCommand    Optional Ex command to be executed before anything else.
"                   a:commandDefinitionsVariable.preAction can configure
"                   different pre commands for each definition, whereas this one
"                   applies to all definitions.
"* USAGE:
"   command! -bang -bar -range=% -nargs=? FooPrettyPrint call setline(1, getline(1)) |
"   \   if ! ingo#ftplugin#converter#builder#Filter('g:Foo_PrettyPrinters',
"   \       '<line1>,<line2>', <bang>0, <q-args>) | echoerr ingo#err#Get() | endif
"* RETURN VALUES:
"   1 if successful, 0 if ingo#err#Set().
"******************************************************************************
    try
	let [l:commandDefinition, l:commandArguments] = ingo#ftplugin#converter#GetCommandDefinition(a:commandDefinitionsVariable, a:arguments)

	if a:0
	    execute a:1
	endif

	call s:FilterBuffer(l:commandDefinition, l:commandArguments, a:range, a:isBang)

	let l:targetFiletype = get(l:commandDefinition, 'filetype', '')
	if ! empty(l:targetFiletype)
	    let &l:filetype = l:targetFiletype
	endif

	return 1
    catch /^converter:/
	call ingo#err#SetCustomException('converter')
	return 0
    catch /^Vim\%((\a\+)\)\=:/
	call ingo#err#SetVimException()
	return 0
    endtry
endfunction
function! ingo#ftplugin#converter#builder#DifferentFiletype( targetFiletype, commandDefinitionsVariable, range, isBang, arguments, ... ) abort
"******************************************************************************
"* PURPOSE:
"   Build a command that converts the current buffer's contents to a different
"   a:targetFiletype by filtering its contents through an Ex command.
"   Like ingo#ftplugin#converter#builder#Filter(), but additionally sets
"   a:targetFiletype on a successful execution.
"* INPUTS:
"   a:targetFiletype    Target 'filetype' that the buffer is set to if the
"                       filtering has been successful. This overrides
"                       a:commandDefinitionsVariable.filetype (which is not
"                       supposed to be used here).
"* RETURN VALUES:
"   1 if successful, 0 if ingo#err#Set().
"******************************************************************************
    let l:success = call('ingo#ftplugin#converter#builder#Filter', [a:commandDefinitionsVariable, a:range, a:isBang, a:arguments] + a:000)
    if l:success
	let &l:filetype = a:targetFiletype
    endif
    return l:success
endfunction

" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
autoload/ingo/ftplugin/converter/external.vim	[[[1
119
" ingo/ftplugin/converter/external.vim: Build a file converter via an external command.
"
" DEPENDENCIES:
"
" Copyright: (C) 2017-2019 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>

function! s:ObtainText( commandDefinition, commandArguments, filespec )
    let l:command = call('ingo#format#Format', [a:commandDefinition.commandline] + map([a:commandDefinition.command, a:commandArguments, expand(a:filespec)], 'ingo#compat#shellescape(v:val)'))

    call ingo#ftplugin#converter#PreAction(a:commandDefinition)
	let l:result = ingo#compat#systemlist(l:command)
	if v:shell_error != 0
	    throw 'converter: Conversion failed: shell returned ' . v:shell_error . (empty(l:result) ? '' : ': ' . join(l:result))
	endif
    call ingo#ftplugin#converter#PostAction(a:commandDefinition)

    return l:result
endfunction

function! ingo#ftplugin#converter#external#ToText( externalCommandDefinitionsVariable, arguments, filespec )
"******************************************************************************
"* PURPOSE:
"   Build a command that converts a file via an external command to just text.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   Takes over the current buffer, replaces its contents, changes its filetype
"   and locks further editing.
"* INPUTS:
"   a:externalCommandDefinitionsVariable    Name of a List of Definitions
"					    objects (cp.
"					    ingo#ftplugin#converter#Builder#Format())
"					    Here, the a:filespec is additionally
"					    inserted (as the third placeholder)
"					    into the commandline attribute.
"   a:arguments     Converter argument (optional if there's just one configured
"                   converter), followed by optional arguments for
"                   a:externalCommandDefinitionsVariable.command, all passed by
"                   the user to the built command.
"   a:filespec      Filespec of the source file, usually representing the
"                   current buffer. It's read from the file system instead of
"                   being piped from Vim's buffer because it may be in binary
"                   format.
"* USAGE:
"   command! -bar -nargs=? FooToText call setline(1, getline(1)) |
"   \   if ! ingo#ftplugin#converter#external#ToText('g:foo_converters',
"   \   <q-args>, bufname('')) | echoerr ingo#err#Get() | endif
"* RETURN VALUES:
"   1 if successful, 0 if ingo#err#Set().
"******************************************************************************
    try
	let [l:commandDefinition, l:commandArguments] = ingo#ftplugin#converter#GetCommandDefinition(a:externalCommandDefinitionsVariable, a:arguments)
	let l:text = s:ObtainText(l:commandDefinition, l:commandArguments, a:filespec)

	silent %delete _
	setlocal endofline nobinary fileencoding<
	call setline(1, l:text)
	call ingo#change#Set([1, 1], [line('$'), 1])

	let &l:filetype = get(l:commandDefinition, 'filetype', 'text')

	setlocal nomodifiable nomodified
	return 1
    catch /^converter:/
	call ingo#err#SetCustomException('converter')
	return 0
    endtry
endfunction
function! ingo#ftplugin#converter#external#ExtractText( externalCommandDefinitionsVariable, mods, arguments, filespec )
"******************************************************************************
"* PURPOSE:
"   Build a command that converts a file via an external command to another
"   scratch buffer that contains just text.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   Creates a new scratch buffer.
"* INPUTS:
"   a:externalCommandDefinitionsVariable    Name of a List of Definitions
"					    objects (cp.
"					    ingo#ftplugin#converter#external#ToText())
"   a:mods          Any command modifiers supplied to the built command (to open
"                   the scratch buffer in a split and control its location).
"   a:arguments     Converter argument (optional if there's just one configured
"                   converter), followed by optional arguments for
"                   a:externalCommandDefinitionsVariable.command, all passed by
"                   the user to the built command.
"   a:filespec      Filespec of the source file, usually representing the
"                   current buffer. It's read from the file system instead of
"                   being piped from Vim's buffer because it may be in binary
"                   format.
"* USAGE:
"   command! -bar -nargs=? FooExtractText
"   \   if ! ingo#ftplugin#converter#external#ExtractText('g:foo_converters',
"   \   ingo#compat#command#Mods('<mods>'), <q-args>, bufname('')) |
"   \   echoerr ingo#err#Get() | endif
"* RETURN VALUES:
"   1 if successful, 0 if ingo#err#Set().
"******************************************************************************
    try
	let [l:commandDefinition, l:commandArguments] = ingo#ftplugin#converter#GetCommandDefinition(a:externalCommandDefinitionsVariable, a:arguments)
	let l:text = s:ObtainText(l:commandDefinition, l:commandArguments, a:filespec)

	let l:status = ingo#buffer#scratch#Create('', expand('%:r') . '.' . get(l:commandDefinition, 'extension', 'txt'), 1, l:text, (empty(a:mods) ? 'enew' : a:mods . ' new'))
	if l:status == 0
	    call ingo#err#Set('Failed to open scratch buffer.')
	    return 0
	endif
	return 1
    catch /^converter:/
	call ingo#err#SetCustomException('converter')
	return 0
    endtry
endfunction

" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
autoload/ingo/ftplugin/onbufwinenter.vim	[[[1
58
" ingo/ftplugin/onbufwinenter.vim: Execute a filetype-specific command after the buffer is fully loaded.
"
" DEPENDENCIES:
"
" Copyright: (C) 2010-2013 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
"
" REVISION	DATE		REMARKS
"   1.011.001	23-Jul-2013	file creation from ingointegration.vim.

let s:autocmdCnt = 0
function! ingo#ftplugin#onbufwinenter#Execute( command, ... )
"******************************************************************************
"* MOTIVATION:
"   You want to execute a command from a ftplugin (e.g. "normal! gg0") that only
"   is effective when the buffer is already fully loaded, modelines have been
"   processed, other autocmds have run, etc.
"
"* PURPOSE:
"   Schedule the passed a:command to execute once after the current buffer has
"   been fully loaded and is now displayed in a window (BufWinEnter).
"
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:command	Ex command to be executed.
"   a:when	Optional configuration of when a:command is executed.
"		By default, it is only executed on the BufWinEnter event, i.e.
"		only when the buffer actually is being loaded. If you want to
"		always execute it (and can live with it being potentially
"		executed twice), so that it is also executed when the user
"		changes the filetype of an existing buffer, pass "always" in
"		here.
"* RETURN VALUES:
"   None.
"******************************************************************************
    if a:0 && a:1 ==# 'always'
	execute a:command
    endif

    let s:autocmdCnt += 1
    let l:groupName = 'IngoLibraryOnBufWinEnter' . s:autocmdCnt
    execute 'augroup' l:groupName
	autocmd!
	execute 'autocmd BufWinEnter <buffer> execute' string(a:command) '| autocmd!' l:groupName '* <buffer>'
	" Remove the run-once autocmd in case the this command was NOT set up
	" during the loading of the buffer (but e.g. by a :setfiletype in an
	" existing buffer), so that it doesn't linger and surprise the user
	" later on.
	execute 'autocmd BufWinLeave,CursorHold,CursorHoldI,WinLeave <buffer> autocmd!' l:groupName '* <buffer>'
    augroup END
endfunction

" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
autoload/ingo/ftplugin/setting.vim	[[[1
31
" ingo/ftplugin/setting.vim: Functions for filetype plugin settings in a buffer-local Dict.
"
" DEPENDENCIES:
"
" Copyright: (C) 2018 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>

function! s:GetOption( variableName )
    return 'b:' . a:variableName
endfunction

function! ingo#ftplugin#setting#Get( variableName, key, default )
    let l:option = s:GetOption(a:variableName)
    if ! exists(l:option)
	return a:default
    endif
    execute 'return get(' . l:option . ', a:key, a:default)'
endfunction

function! ingo#ftplugin#setting#Set( variableName, key, value )
    let l:option = s:GetOption(a:variableName)
    if ! exists(l:option)
	execute 'let' l:option '= {}'
    endif

    execute 'let' l:option . '[a:key] = a:value'
endfunction

" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
autoload/ingo/ftplugin/windowsettings.vim	[[[1
102
" ingo/ftplugin/windowsettings.vim: Function to undo window settings for a buffer.
"
" DEPENDENCIES:
"
" Copyright: (C) 2011-2014 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
"
" REVISION	DATE		REMARKS
"   1.016.005	09-Jan-2014	BUG: Wrap :autocmd! undo_ftplugin_N in :execute
"				to that superordinated ftplugins can append
"				additional undo commands without causing "E216:
"				No such group or event:
"				undo_ftplugin_N|setlocal".
"   1.011.004	23-Jul-2013	Move into ingo-library.
"	003	23-Nov-2012	ENH: Correctly unset the window-local settings
"				when doing a :split otherfile, and when the
"				buffer is still visible in another window, so
"				the BufWinLeave event isn't triggered.
"	002	14-Feb-2011	BUG: Mismatch in augroup names resulted in E216.
"	001	27-Jan-2011	file creation
let s:save_cpo = &cpo
set cpo&vim

function! ingo#ftplugin#windowsettings#Undo( windowSettings )
"******************************************************************************
"* PURPOSE:
"   Filetype settings that have buffer-scope are undone via the b:undo_ftplugin
"   variable; some ftplugins may also want to set window-scoped settings like
"   'colorcolumn'. These must be undone when the buffer is removed from a window
"   and restored when the buffer displayed again; otherwise, these settings will
"   pollute other buffers when they are displayed in the same window. This
"   function sets up the correct autocmds and undo actions for such window-local
"   settings.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   Sets up buffer-local autocmds in augroup "undo_ftplugin_N", where N is the
"   buffer number.
"   Sets up window-local variables to detect and handle all possible situations.
"   Appends undo actions to b:undo_ftplugin.
"* INPUTS:
"   a:windowSettings	Space-separated list of window-local settings to be set
"			for this filetype, e.g. "colorcolumn=+1 stl=%s\ %P"
"* RETURN VALUES:
"   None.
"******************************************************************************
    let l:windowSettingNames = map(split(a:windowSettings, '\%(\%(^\|[^\\]\)\%(\\\\\)*\\\)\@<! '), 'substitute(v:val, "=.*$", "", "")')
    let l:windowUndoSettings = join(map(l:windowSettingNames, 'v:val . "<"'), ' ')

    " Set the window-local settings for now.
    execute 'setlocal' a:windowSettings

    let l:augroupName = 'undo_ftplugin_' . bufnr('')
    let l:bufWinSettings = string([bufnr(''), l:windowUndoSettings])
    execute 'augroup' l:augroupName
	autocmd!
	" These are the basic handlers that set and unset the window-local
	" settings when the buffer is displayed and removed from its window.
	execute 'autocmd BufWinEnter <buffer>   let  w:hasBufWinSettings = '.l:bufWinSettings.' | setlocal' a:windowSettings
	execute 'autocmd BufWinLeave <buffer> unlet! w:hasBufWinSettings                        | setlocal' l:windowUndoSettings

	" When splitting the window, that may mean that another buffer is about
	" to be loaded into it (:split otherfile). We detect the split on the
	" immediate WinEnter event because the w:hasBufWinSettings variable does
	" not inherit to the split window.
	" To have the window-local settings unset by the undo_ftplugin_other
	" group's autocmds, we set another w:windowUndoSettings variable for it
	" that contains the necessary commands.
	execute 'autocmd WinEnter    <buffer> ' .
	\   'if ! exists("w:hasBufWinSettings") | let w:windowUndoSettings = ' . string(l:windowUndoSettings) . ' | endif'
	" Should this :split have been intended as a cloning of the current
	" buffer, we detect this when the window is left with the same buffer
	" intact, and then also define w:hasBufWinSettings, so that it is
	" identical to the original.
	execute 'autocmd WinLeave    <buffer>   let  w:hasBufWinSettings = '.l:bufWinSettings.' | unlet! w:windowUndoSettings'
    augroup END
    augroup undo_ftplugin_other
	" When a buffer is loaded into a window that resulted from a split of a
	" buffer with window-local settings, undo them.
	" When a buffer is loaded into a window that contained a buffer with
	" window-local settings, and that buffer is still visible in another
	" window, the BufWinLeave event didn't fire, and therefore the
	" window-local settings weren't unset yet. Unset it now. (Unless this is
	" the buffer with the window-local settings itself.)
	autocmd! BufWinEnter *
	\   if exists('w:windowUndoSettings') |
	\       execute 'setlocal' w:windowUndoSettings |
	\       unlet w:windowUndoSettings |
	\   elseif exists('w:hasBufWinSettings') && w:hasBufWinSettings[0] != expand('<abuf>') |
	\       execute 'setlocal' w:hasBufWinSettings[1] |
	\       unlet w:hasBufWinSettings |
	\   endif
    augroup END

    let b:undo_ftplugin = (exists('b:undo_ftplugin') ? b:undo_ftplugin . '|' : '') . 'setlocal ' . l:windowUndoSettings . ' | execute "autocmd! ' . l:augroupName . '"'
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo
" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
autoload/ingo/funcref.vim	[[[1
19
" ingo/funcref.vim: Functions for handling Funcrefs.
"
" DEPENDENCIES:
"
" Copyright: (C) 2013-2018 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>

function! ingo#funcref#ToString( Funcref )
    let l:functionName = matchstr(string(a:Funcref), "^function('\\zs.*\\ze')$")
    return (empty(l:functionName) ? '' . a:Funcref : l:functionName)
endfunction

function! ingo#funcref#AsString( Funcref )
    return (type(a:Funcref) == 2 ? string(a:Funcref) : a:Funcref)
endfunction

" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
autoload/ingo/function/uniquify.vim	[[[1
85
" ingo/function/uniquify.vim: Functions to ensure uniqueness with function calls.
"
" DEPENDENCIES:
"
" Copyright: (C) 2019 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>

let s:records = {}
let s:maxAttempts = {}

function! ingo#function#uniquify#ReturnValue( id, Funcref, ... )
"******************************************************************************
"* PURPOSE:
"   Invoke a:Funcref so often until it returns a value that hasn't been seen (in
"   the scope of a:id) yet.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:id    Identifies the function; uniqueness is ensured in the context of it.
"   a:Funcref   Funcref to be invoked.
"   a:args      Optional arguments to be passed to a:Funcref.
"* RETURN VALUES:
"   Return value of a:Funcref that was never returned before.
"   Throws "ReturnValue: Too many invocations with same return value: N" if all
"   calls return the same value too often.
"******************************************************************************
    if ! has_key(s:records, a:id)
	let s:records[a:id] = {}
    endif

    let l:count = 0
    while l:count < get(s:maxAttempts, a:id, 1000)
	let l:value = call(a:Funcref, a:000)

	let l:v = ingo#compat#DictKey(l:value)
	if ! has_key(s:records[a:id], l:v)
	    let s:records[a:id][l:v] = 1
	    return l:value
	endif

	let l:count += 1
    endwhile

    throw 'ReturnValue: Too many invocations with same return value: ' . l:count
endfunction

function! ingo#function#uniquify#SetMaxAttempts( id, maxAttempts )
"******************************************************************************
"* PURPOSE:
"   Set the maximum number of attempts for ingo#function#uniquify#ReturnValue()
"   calling its a:Funcref in order to obtain a unique value.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:id    Identifies the function; uniqueness is ensured in the context of it.
"   a:maxAttempts   Maximum number of attempts; -1 for no limit.
"* RETURN VALUES:
"   None.
"******************************************************************************
    let s:maxAttempts[a:id] = a:maxAttempts
endfunction

function! ingo#function#uniquify#Clear( id )
"******************************************************************************
"* PURPOSE:
"   Clear the records for a:id that ensure uniqueness.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:id    Identifies the function; uniqueness is ensured in the context of it.
"* RETURN VALUES:
"   None.
"******************************************************************************
    let s:records[a:id] = {}
endfunction

" vikm: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
autoload/ingo/gui/position.vim	[[[1
20
" ingo/gui/position.vim: Functions for the GVIM position and size.
"
" DEPENDENCIES:
"
" Copyright: (C) 2013 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
"
" REVISION	DATE		REMARKS
"   1.011.001	19-Jul-2013	file creation

function! ingo#gui#position#Get()
    redir => l:winpos
	silent! winpos
    redir END
    return [&lines, &columns, matchstr(l:winpos, '\CX \zs-\?\d\+'), matchstr(l:winpos, '\CY \zs-\?\d\+')]
endfunction

" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
autoload/ingo/hlgroup.vim	[[[1
22
" ingo/hlgroup.vim: Functions around highlight groups.
"
" DEPENDENCIES:
"
" Copyright: (C) 2017 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
"
" REVISION	DATE		REMARKS
"   1.030.001	09-Feb-2017	file creation

function! ingo#hlgroup#LinksTo( name )
    redir => l:highlightOutput
	silent! execute 'highlight' a:name
    redir END
    redraw	" This is necessary because of the :redir done earlier.
    let l:linkedGroup = matchstr(l:highlightOutput, ' xxx links to \zs.*$')
    return l:linkedGroup
endfunction

" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
autoload/ingo/indent.vim	[[[1
46
" ingo/indent.vim: Functions for working with indent.
"
" DEPENDENCIES:
"
" Copyright: (C) 2016 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
"
" REVISION	DATE		REMARKS
"   1.029.002	02-Dec-2016	Add ingo#indent#Split(), a simpler version of
"				ingo#comments#SplitIndentAndText().
"   1.028.001	25-Nov-2016	file creation

function! ingo#indent#RangeSeveralTimes( firstLnum, lastLnum, command, times )
    for l:i in range(a:times)
	silent execute a:firstLnum . ',' . a:lastLnum . a:command
    endfor
endfunction

function! ingo#indent#GetIndent( lnum )
    return matchstr(getline(a:lnum), '^\s*')
endfunction
function! ingo#indent#GetIndentLevel( lnum )
    return indent(a:lnum) / &l:shiftwidth
endfunction
function! ingo#indent#Split( lnum )
"******************************************************************************
"* PURPOSE:
"   Split the line into any leading indent, and the text after it.
"* SEE ALSO:
"   ingo#comments#SplitIndentAndText() also considers any comment prefix as part
"   of the indent.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:lnum  Number of the line to be split.
"* RETURN VALUES:
"   Returns [a:indent, a:text].
"******************************************************************************
    return matchlist(getline(a:lnum), '^\(\s*\)\(.*\)$')[1:2]
endfunction

" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
autoload/ingo/join.vim	[[[1
155
" ingo/join.vim: Functions for joining lines in the buffer.
"
" DEPENDENCIES:
"   - ingo/folds.vim autoload script
"
" Copyright: (C) 2014-2019 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
"
" REVISION	DATE		REMARKS
"   1.020.002	08-Jun-2014	Do not clobber the default register when joining
"				lines with separator and not keeping spaces.
"   1.020.001	08-Jun-2014	file creation from ingocommands.vim

function! ingo#join#Lines( lnum, isKeepSpace, separator )
"******************************************************************************
"* PURPOSE:
"   Join a:lnum with the next line, putting a:separator in between (and
"   optionally deleting any separating whitespace).
"* ASSUMPTIONS / PRECONDITIONS:
"   The 'formatoptions' option may affect the join, especially M, B, j.
"* EFFECTS / POSTCONDITIONS:
"   Joins lines.
"* INPUTS:
"   a:lnum  Line number of the first line to be joined.
"   a:isKeepSpace   Flag whether to keep whitespace (i.e. trailing in a:lnum,
"		    indent in a:lnum + 1) or remove it altogether. The joining
"		    itself does not add whitespace.
"   a:separator     String to be put in between the lines (also when one of them
"		    is completely empty).
"* RETURN VALUES:
"   None.
"******************************************************************************
    if a:lnum >= line('$')
	return 0
    endif

    if a:isKeepSpace
	let l:lineLen = len(getline(a:lnum))
	execute a:lnum . 'join!'
	if ! empty(a:separator)
	    if len(getline(a:lnum)) == l:lineLen
		" The next line was completely empty.
		execute 'normal! A' . a:separator . "\<Esc>"
	    else
		call cursor(a:lnum, l:lineLen + 1)
		execute 'normal! i' . a:separator . "\<Esc>"
	    endif
	endif
    else
	execute a:lnum . 'normal! J'

	let l:changeJoiner = (empty(a:separator) ? '"_diw' : '"_ciw' . a:separator . "\<Esc>")
	" The J command inserts one space in place of the <EOL> unless there is
	" trailing white space or the next line starts with a ')'. The
	" whitespace will be handed by "ciw", but we need a special case for ).
	if ! search('\%#\s\|\s\%#', 'bcW', line('.'))
	    let l:changeJoiner = (empty(a:separator) ? '' : 'i' . a:separator . "\<Esc>")
	endif
	if ! empty(l:changeJoiner)
	    execute 'normal!' l:changeJoiner
	endif
    endif
    return 1
endfunction

function! ingo#join#Ranges( isKeepSpace, startLnum, endLnum, separator, ranges )
"******************************************************************************
"* PURPOSE:
"   Join each range of lines in a:ranges.
"* ASSUMPTIONS / PRECONDITIONS:
"   The 'formatoptions' option may affect the join, especially M, B, j.
"* EFFECTS / POSTCONDITIONS:
"   Joins lines.
"* INPUTS:
"   a:isKeepSpace   Flag whether to keep whitespace (i.e. trailing in a:lnum,
"		    indent in a:lnum + 1) or remove it altogether. The joining
"		    itself does not add whitespace.
"   a:startLnum     Ignored.
"   a:endLnum       Ignored.
"   a:separator     String to be put in between the lines (also when one of them
"		    is completely empty).
"   a:ranges        List of [startLnum, endLnum] pairs.
"* RETURN VALUES:
"   [ number of ranges, number of joined lines ]
"******************************************************************************
    if empty(a:ranges)
	return [0, 0]
    endif

    let l:joinCnt = 0
    let l:save_foldenable = &foldenable
    set nofoldenable
    try
	for [l:rangeStartLnum, l:rangeEndLnum] in reverse(a:ranges)
	    let l:cnt = l:rangeEndLnum - l:rangeStartLnum
	    for l:i in range(l:cnt)
		if ingo#join#Lines(l:rangeStartLnum, a:isKeepSpace, a:separator)
		    let l:joinCnt += 1
		endif
	    endfor
	endfor
    finally
	let &foldenable = l:save_foldenable
    endtry
    return [len(a:ranges), l:joinCnt]
endfunction

function! ingo#join#Range( isKeepSpace, startLnum, endLnum, separator )
"******************************************************************************
"* PURPOSE:
"   Join all lines in the a:startLnum, a:endLnum range.
"* ASSUMPTIONS / PRECONDITIONS:
"   The 'formatoptions' option may affect the join, especially M, B, j.
"* EFFECTS / POSTCONDITIONS:
"   Joins lines.
"* INPUTS:
"   a:isKeepSpace   Flag whether to keep whitespace (i.e. trailing in a:lnum,
"		    indent in a:lnum + 1) or remove it altogether. The joining
"		    itself does not add whitespace.
"   a:startLnum     First line of range.
"   a:endLnum       Last line of range.
"   a:separator     String to be put in between the lines (also when one of them
"		    is completely empty).
"* RETURN VALUES:
"   number of joined lines
"******************************************************************************
    return ingo#join#Ranges(a:isKeepSpace, 0, 0, a:separator, [[a:startLnum, a:endLnum]])[1]
endfunction

function! ingo#join#FoldedLines( isKeepSpace, startLnum, endLnum, separator )
"******************************************************************************
"* PURPOSE:
"   Join all folded lines.
"* ASSUMPTIONS / PRECONDITIONS:
"   The 'formatoptions' option may affect the join, especially M, B, j.
"* EFFECTS / POSTCONDITIONS:
"   Joins lines.
"* INPUTS:
"   a:isKeepSpace   Flag whether to keep whitespace (i.e. trailing in a:lnum,
"		    indent in a:lnum + 1) or remove it altogether. The joining
"		    itself does not add whitespace.
"   a:startLnum     First line number to be considered.
"   a:endLnum       last line number to be considered.
"   a:separator     String to be put in between the lines (also when one of them
"		    is completely empty).
"* RETURN VALUES:
"   [ number of folds, number of joined lines ]
"******************************************************************************
    let l:folds = ingo#folds#GetClosedFolds(a:startLnum, a:endLnum)
    return ingo#join#Ranges(a:isKeepSpace, a:startLnum, a:endLnum, a:separator, l:folds)
endfunction

" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
autoload/ingo/line/replace.vim	[[[1
39
" ingo/line/replace.vim: Functions to replace text in a single line.
"
" DEPENDENCIES:
"
" Copyright: (C) 2016 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
"
" REVISION	DATE		REMARKS
"   1.029.001	22-Dec-2016	file creation

function! ingo#line#replace#Substitute( lnum, pat, sub, flags )
"******************************************************************************
"* PURPOSE:
"   Substitute a pattern in a single line in the current buffer. Low-level
"   alternative to :substitute without the need to suppress messages, undo
"   search history clobbering, cursor move.
"* SEE ALSO:
"   - ingo#lines#replace#Substitute() handles multiple lines, but is more
"     costly.
"* ASSUMPTIONS / PRECONDITIONS:
"   Does not handle inserted newlines; i.e. no additional lines will be created,
"   the newline will be persisted as-is (^@).
"* EFFECTS / POSTCONDITIONS:
"   Updates a:lnum.
"* INPUTS:
"   a:lnum  Existing line number.
"   a:pat   Regular expression to match.
"   a:sub   Replacement string.
"   a:flags "g" for global replacement.
"* RETURN VALUES:
" If this succeeds, 0 is returned.  If this fails (most likely because a:lnum is
" invalid) 1 is returned.
"******************************************************************************
    return setline(a:lnum, substitute(getline(a:lnum), a:pat, a:sub, a:flags))
endfunction

" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
autoload/ingo/lines.vim	[[[1
89
" ingo/lines.vim: Functions for line manipulation.
"
" DEPENDENCIES:
"   - ingo/range.vim autoload script
"
" Copyright: (C) 2012-2019 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>

function! ingo#lines#PutWrapper( lnum, putCommand, lines )
"******************************************************************************
"* PURPOSE:
"   Insert a:lines into the current buffer at a:lnum without clobbering the
"   expression register.
"* SEE ALSO:
"   If you don't need the 'report' message, setting of change marks, and
"   handling of a string containing newlines, you can just use built-in
"   append().
"* ASSUMPTIONS / PRECONDITIONS:
"   Current buffer is modifiable.
"* EFFECTS / POSTCONDITIONS:
"   To suppress a potential message based on 'report', invoke this function with
"   :silent.
"   Sets change marks '[,'] to the inserted lines.
"* INPUTS:
"   a:lnum  Address for a:putCommand.
"   a:putCommand    The :put[!] command that is used.
"   a:lines         List of lines or string (where lines are separated by \n
"		    characters).
"* RETURN VALUES:
"   None.
"******************************************************************************
    if v:version < 703 || v:version == 703 && ! has('patch272')
	" Fixed by 7.3.272: ":put =list" does not add empty line for trailing
	" empty item
	if type(a:lines) == type([]) && len(a:lines) > 1 && empty(a:lines[-1])
	    " XXX: Vim omits an empty last element when :put'ting a List of lines.
	    " We can work around that by putting a newline character instead.
	    let a:lines[-1] = "\n"
	endif
    endif

    " Avoid clobbering the expression register.
    let l:save_register = getreg('=', 1)
	execute a:lnum . a:putCommand '=a:lines'
    let @= = l:save_register
endfunction
function! ingo#lines#PutBefore( lnum, lines )
    if a:lnum == line('$') + 1
	call ingo#lines#PutWrapper((a:lnum - 1), 'put',  a:lines)
    else
	call ingo#lines#PutWrapper(a:lnum, 'put!',  a:lines)
    endif
endfunction
function! ingo#lines#Replace( startLnum, endLnum, lines, ... )
"******************************************************************************
"* PURPOSE:
"   Replace the range of a:startLnum,a:endLnum with the List of lines (or string
"   where lines are separated by \n characters).
"* ASSUMPTIONS / PRECONDITIONS:
"   Current buffer is modifiable.
"* EFFECTS / POSTCONDITIONS:
"   Sets change marks '[,'] to the replaced lines.
"* INPUTS:
"   a:startLnum     First line to be replaced. Use ingo#range#NetStart() if
"		    necessary.
"   a:endLnum       Last line to be replaced. Use ingo#range#NetEnd() if
"		    necessary.
"   a:lines         List of lines or string (where lines are separated by \n
"		    characters).
"   a:register      Optional register to store the replaced lines. By default
"		    goes into black-hole.
"* RETURN VALUES:
"   None.
"******************************************************************************
    let l:isEntireBuffer = ingo#range#IsEntireBuffer(a:startLnum, a:endLnum)
    silent execute printf('%s,%sdelete %s', a:startLnum, a:endLnum, (a:0 ? a:1 : '_'))
    if ! empty(a:lines)
	silent call ingo#lines#PutBefore(a:startLnum, a:lines)
	if l:isEntireBuffer
	    silent $delete _

	    call ingo#change#Set([1, 1], [line('$'), 1])
	endif
    endif
endfunction

" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
autoload/ingo/lines/empty.vim	[[[1
40
" ingo/lines/empty.vim: Functions to search for empty lines.
"
" DEPENDENCIES:
"
" Copyright: (C) 2017 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>

function! ingo#lines#empty#IsEmptyLine( lnum )
    return empty(getline(a:lnum))
endfunction
function! ingo#lines#empty#IsEmptyLines( lnum1, lnum2 )
    return len(filter(getline(a:lnum1, a:lnum2), '! empty(v:val)')) == 0
endfunction

function! ingo#lines#empty#GetNextNonEmptyLnum( lnum )
    let l:lnum = (a:lnum < 0 ? line('$') + a:lnum + 2 : a:lnum) + 1
    while l:lnum <= line('$')
	if ingo#lines#empty#IsEmptyLine(l:lnum)
	    let l:lnum += 1
	else
	    return l:lnum
	endif
    endwhile
    return 0
endfunction
function! ingo#lines#empty#GetPreviousNonEmptyLnum( lnum )
    let l:lnum = (a:lnum < 0 ? line('$') + a:lnum + 2 : a:lnum) - 1
    while l:lnum >= 1
	if ingo#lines#empty#IsEmptyLine(l:lnum)
	    let l:lnum -= 1
	else
	    return l:lnum
	endif
    endwhile
    return 0
endfunction

" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
autoload/ingo/lines/replace.vim	[[[1
66
" replace.vim: Functions to replace text in lines.
"
" DEPENDENCIES:
"
" Copyright: (C) 2016 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
"
" REVISION	DATE		REMARKS
"   1.029.001	23-Dec-2016	file creation

function! ingo#lines#replace#Substitute( startLnum, endLnum, pat, sub, flags )
"******************************************************************************
"* PURPOSE:
"   Substitute a pattern in lines in the current buffer. Low-level
"   alternative to :[range]substitute without the need to suppress messages,
"   undo search history clobbering, cursor move.
"* SEE ALSO:
"   - ingo#line#replace#Substitute() is a cheaper alternative that only handles
"     a single line, though.
"* ASSUMPTIONS / PRECONDITIONS:
"   Handles inserted newlines and removed lines.
"* EFFECTS / POSTCONDITIONS:
"   Updates the buffer.
"* INPUTS:
"   a:startLnum  Existing line number.
"   a:endLnum  Existing line number.
"   a:pat   Regular expression to match. It is applied to all lines joined via
"	    \n; the last line does not end in \n. That means that even if you
"	    match everything in all lines (.*), and replace it with the empty
"	    string, a single empty line will remain.
"   a:sub   Replacement string.
"   a:flags "g" for global replacement.
"* RETURN VALUES:
" If this succeeds, 0 is returned.  If this fails 1 is returned.
"******************************************************************************
    let l:lines = getline(a:startLnum, a:endLnum)
    if empty(l:lines) | return 1 | endif
    let l:lineNum = len(l:lines)

    let l:newLines = split(substitute(join(l:lines, "\n"), a:pat, a:sub, a:flags), '\n', 1)
    let l:newLineNum = len(l:newLines)

    " Update existing lines first, then handle any additions / deletions.
    for l:i in range(min([l:lineNum, l:newLineNum]))
	call setline(a:startLnum + l:i, l:newLines[l:i])
    endfor
    if l:newLineNum < l:lineNum
	" We have less lines now; remove the surplus original ones.
	" Unfortunately, there's no low-level function for deletion, so we need
	" to use :delete.
	let l:save_view = winsaveview()
	let l:save_foldenable = &l:foldenable
	setlocal nofoldenable
	    silent! execute printf('keepjumps %d,%ddelete _', a:startLnum + l:newLineNum, a:endLnum)
	let &l:foldenable = l:save_foldenable
	call winrestview(l:save_view)
	return 0
    elseif l:newLineNum > l:lineNum
	" Additional lines need to be appended.
	return append(a:endLnum, l:newLines[l:lineNum : ])
    endif
endfunction

" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
autoload/ingo/list.vim	[[[1
214
" ingo/list.vim: Functions to operate on Lists.
"
" DEPENDENCIES:
"
" Copyright: (C) 2013-2018 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>

function! ingo#list#Make( val, ... )
"******************************************************************************
"* PURPOSE:
"   Ensure that the passed a:val is a List; if not, wrap it in one.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:val   Arbitrary value of arbitrary type.
"   a:isCopyOriginalList    Optional flag; when set, an original a:val List is
"			    copied before returning.
"* RETURN VALUES:
"   List; either the original one or a new one containing a:val.
"******************************************************************************
    return (type(a:val) == type([]) ? (a:0 && a:1 ? copy(a:val) : a:val) : [a:val])
endfunction

function! ingo#list#AddOrExtend( list, val, ... )
"******************************************************************************
"* PURPOSE:
"   Add a:val as item(s) to a:list. Extends a List, adds other types.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:list  List to be extended.
"   a:val   Arbitrary value of arbitrary type.
"   a:idx   Optional index before where in a:list to insert. Default to
"	    appending.
"* RETURN VALUES:
"   Returns the resulting a:list.
"******************************************************************************
    if type(a:val) == type([])
	if a:0
	    call extend(a:list, a:val, a:1)
	else
	    call extend(a:list, a:val)
	endif
    else
	if a:0
	    call insert(a:list, a:val, a:1)
	else
	    call add(a:list, a:val)
	endif
    endif
    return a:list
endfunction

function! ingo#list#Zip( ... )
"******************************************************************************
"* PURPOSE:
"   From several Lists, create a combined List. The first item is a List of all
"   first items of the original Lists, the second a List of all second items,
"   and so on, until one List is exhausted. Surplus items in other Lists are
"   omitted.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:list1, a:list2
"* RETURN VALUES:
"   List of Lists, each containing a certain index item of all source Lists.
"******************************************************************************
    let l:result = []
    for l:i in range(min(map(copy(a:000), 'len(v:val)')))
	call add(l:result, map(copy(a:000), 'v:val[l:i]'))
    endfor
    return l:result
endfunction

function! ingo#list#ZipLongest( defaultValue, ... )
"******************************************************************************
"* PURPOSE:
"   From several Lists, create a combined List. The first item is a List of all
"   first items of the original Lists, the second a List of all second items,
"   and so on, until all Lists are exhausted. Missing items in shorter Lists are
"   replaced by a:defaultValue.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:list1, a:list2
"* RETURN VALUES:
"   List of Lists, each containing a certain index item of all source Lists.
"******************************************************************************
    let l:result = []
    for l:i in range(max(map(copy(a:000), 'len(v:val)')))
	call add(l:result, map(copy(a:000), 'get(v:val, l:i, a:defaultValue)'))
    endfor
    return l:result
endfunction

function! ingo#list#Join( ... )
"******************************************************************************
"* PURPOSE:
"   From several Lists, create a combined List, starting with all first items,
"   then all second items, and so on.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:list1, a:list2
"* RETURN VALUES:
"   List of joined source Lists, from low to high indices.
"******************************************************************************
    let l:result = []
    let l:i = 0
    let l:isAdded = 1
    while l:isAdded
	let l:isAdded = 0
	for l:j in range(a:0)
	    if l:i < len(a:000[l:j])
		call add(l:result, a:000[l:j][l:i])
		let l:isAdded = 1
	    endif
	endfor
	let l:i += 1
    endwhile
    return l:result
endfunction


function! ingo#list#AddNonEmpty( list, val, ... )
"******************************************************************************
"* PURPOSE:
"   Add a:val if it is not empty as an item to a:list.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:list  List to be extended.
"   a:val   Arbitrary value of arbitrary type.
"   a:idx   Optional index before where in a:list to insert. Default to
"	    appending.
"* RETURN VALUES:
"   Returns the resulting a:list.
"******************************************************************************
    if ! empty(a:val)
	if a:0
	    call insert(a:list, a:val, a:1)
	else
	    call add(a:list, a:val)
	endif
    endif

    return a:list
endfunction

function! ingo#list#NonEmpty( list )
"******************************************************************************
"* PURPOSE:
"   Remove empty items from a:list.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   Modifies a:list; use copy() to avoid that.
"* INPUTS:
"   a:list  A list.
"* RETURN VALUES:
"   Modified a:list where all items where empty() is 1 have been removed.
"******************************************************************************
    return filter(a:list, '! empty(v:val)')
endfunction

function! ingo#list#IsEmpty( list )
"******************************************************************************
"* PURPOSE:
"   Test whether the list itself contains no items or only empty ones.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:list  A list.
"* RETURN VALUES:
"   0 if a:list is not empty and at least one of its items make empty()
"   return 1; else 1.
"******************************************************************************
    return empty(ingo#list#NonEmpty(copy(a:list)))
endfunction

function! ingo#list#JoinNonEmpty( list, ... )
"******************************************************************************
"* PURPOSE:
"   Join the non-empty items in a:list together into one String.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   Modifies a:list; use copy() to avoid that.
"* INPUTS:
"   a:list  A list.
"   a:sep   Optional separator to be put in between the items.
"* RETURN VALUES:
"   String.
"******************************************************************************
    return call('join', [ingo#list#NonEmpty(a:list)] + a:000)
endfunction

" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
autoload/ingo/list/find.vim	[[[1
69
" find.vim: Functions for finding indices in Lists.
"
" DEPENDENCIES:
"   - ingo/actions.vim autoload script
"
" Copyright: (C) 2016 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
"
" REVISION	DATE		REMARKS
"   1.028.001	21-Oct-2016	file creation

function! ingo#list#find#FirstIndex( list, Filter )
"******************************************************************************
"* PURPOSE:
"   Find the first index of an item in a:list where a:filter is true.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:list  List to be searched.
"   a:Filter    Expression to be evaluated; v:val has the value of the current
"		item. Returns false to skip the item.
"		If a:Filter is a Funcref it is called with the value of the
"		current item.
"* RETURN VALUES:
"   First found index, or -1.
"******************************************************************************
    let l:idx = 0
    while l:idx < len(a:list)
	if ingo#actions#EvaluateWithValOrFunc(a:Filter, a:list[l:idx])
	    return l:idx
	endif
	let l:idx += 1
    endwhile
    return -1
endfunction

function! ingo#list#find#Indices( list, Filter )
"******************************************************************************
"* PURPOSE:
"   Find all indices of items in a:list where a:filter is true.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:list  List to be searched.
"   a:Filter    Expression to be evaluated; v:val has the value of the current
"		item. Returns false to skip the item.
"		If a:Filter is a Funcref it is called with the value of the
"		current item.
"* RETURN VALUES:
"   List of found indices, or empty List.
"******************************************************************************
    let l:indices = []
    let l:idx = 0
    while l:idx < len(a:list)
	if ingo#actions#EvaluateWithValOrFunc(a:Filter, a:list[l:idx])
	    call add(l:indices, l:idx)
	endif
	let l:idx += 1
    endwhile
    return l:indices
endfunction

" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
autoload/ingo/list/lcs.vim	[[[1
159
" ingo/list/lcs.vim: Functions to find longest common substring(s).
"
" DEPENDENCIES:
"   - ingo/compat.vim autoload script
"   - ingo/list.vim autoload script
"   - ingo/str/split.vim autoload script
"
" Copyright: (C) 2017-2018 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
let s:save_cpo = &cpo
set cpo&vim

function! ingo#list#lcs#FindLongestCommon( strings, ... )
"******************************************************************************
"* PURPOSE:
"   Find the (first) longest common substring that occurs in each of a:strings.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:strings   List of strings.
"   a:minimumLength Minimum substring length; default 1.
"* RETURN VALUES:
"   Longest string that occurs in all of a:strings, or empty string if there's
"   no commonality at all.
"******************************************************************************
    let l:minimumLength = (a:0 ? a:1 : 1)
    let l:pos = 0
    let l:maxMatchLen = 0
    let l:maxMatch = ''

    while 1
	let [l:match, l:startPos, l:endPos] = ingo#compat#matchstrpos(
	\   join(a:strings + [''], "\n"),
	\   printf('^[^\n]\{-}\zs\([^\n]\{%d,}\)\ze[^\n]\{-}\n\%([^\n]\{-}\1[^\n]*\n\)\{%d}$', l:minimumLength, len(a:strings) - 1),
	\   l:pos
	\)
	if l:startPos == -1
	    break
	endif
	let l:pos = l:endPos
"****D echomsg '****' l:match
	let l:matchLen = ingo#compat#strchars(l:match)
	if l:matchLen > l:maxMatchLen
	    let l:maxMatch = l:match
	    let l:maxMatchLen = l:matchLen
	endif
    endwhile

    return l:maxMatch
endfunction

function! ingo#list#lcs#FindAllCommon( strings, ... )
"******************************************************************************
"* PURPOSE:
"   Find all common substrings that occur in each of a:strings.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:strings                   List of strings.
"   a:minimumCommonLength       Minimum substring length; default 1.
"   a:minimumDifferingLength    Minimum length; default 0.
"* RETURN VALUES:
"   [distinctLists, commons], as in:
"   [
"	[prefix1, prefix2, ...], [middle1, middle2, ...], ..., [suffix1, suffix2, ...],
"	[commonBetweenPrefixAndMiddle, ..., commonBetweenMiddleAndSuffix]
"   ]
"   The commons List always contains one element less than distinctLists; its
"   elements are meant to go between those of the first List.
"   If all strings start or end with a common substring, [prefix1, prefix2, ...]
"   / [suffix1, suffix2, ...] is the empty List [].
"******************************************************************************
    let l:minimumCommonLength = (a:0 ? a:1 : 1)
    let [l:minimumPrefixDifferingLength, l:minimumSuffixDifferingLength] = (a:0 >= 2 ?
    \   (type(a:2) == type([]) ?
    \       a:2 :
    \       [a:2, a:2]
    \   ) :
    \   [0, 0]
    \)

    let l:common = ingo#list#lcs#FindLongestCommon(a:strings, l:minimumCommonLength)
    if empty(l:common)
	return [[a:strings], []]
    endif

    let [l:differingCnt, l:prefixes, l:suffixes] = s:Split(a:strings, l:common)

    let l:isPrefixTooShort = s:IsTooShort(l:prefixes, l:minimumPrefixDifferingLength)
    let l:isSuffixTooShort = s:IsTooShort(l:suffixes, l:minimumSuffixDifferingLength)
    if l:isPrefixTooShort
	if l:isSuffixTooShort
	    " No more recursion. Join back prefixes, common, and suffixes. Oh
	    " wait, we can just return the original List.
	    return [[a:strings], []]

	    "let [l:prefixDiffering, l:prefixCommon] = [[map(range(l:differingCnt), 'get(l:prefixes, v:val, "") . l:common . get(l:suffixes, v:val, "")')], []]
	    "let l:common = ''
	    "let [l:suffixDiffering, l:suffixCommon] = [[], []]
	else
	    " Recurse into the suffixes, then join its first distincts with the
	    " prefixes and common.
	    let [l:suffixDiffering, l:suffixCommon] = ingo#list#lcs#FindAllCommon(l:suffixes, l:minimumCommonLength, [0, l:minimumSuffixDifferingLength]) " Minimum prefix length doesn't apply here, as we're joining it.

	    let [l:prefixDiffering, l:prefixCommon] = [[map(range(l:differingCnt), 'get(l:prefixes, v:val, "") . l:common . get(get(l:suffixDiffering, 0, []), v:val, "")')], []]
	    let l:common = ''
	    call remove(l:suffixDiffering, 0)
	endif
    elseif l:isSuffixTooShort
	" Recurse into the prefixes, then join its last distincts with common
	" and the suffixes.
	let [l:prefixDiffering, l:prefixCommon] = ingo#list#lcs#FindAllCommon(l:prefixes, l:minimumCommonLength, [l:minimumPrefixDifferingLength, 0]) " Minimum suffix length doesn't apply here, as we're joining it.
	let [l:suffixDiffering, l:suffixCommon] = [[map(range(l:differingCnt), 'get(l:prefixDiffering[-1], v:val, "") . l:common . get(l:suffixes, v:val, "")')], []]
	let l:common = ''
	call remove(l:prefixDiffering, -1)
    else
	" Recurse into both prefixes and suffixes.
	let [l:prefixDiffering, l:prefixCommon] = ingo#list#lcs#FindAllCommon(l:prefixes, l:minimumCommonLength, [l:minimumPrefixDifferingLength, l:minimumSuffixDifferingLength])
	let [l:suffixDiffering, l:suffixCommon] = ingo#list#lcs#FindAllCommon(l:suffixes, l:minimumCommonLength, [l:minimumPrefixDifferingLength, l:minimumSuffixDifferingLength])
    endif

    return [
    \   l:prefixDiffering + l:suffixDiffering,
    \   filter(l:prefixCommon + [l:common] + l:suffixCommon, '! empty(v:val)')
    \]
endfunction
function! s:IsTooShort( list, minimumLength )
    return a:minimumLength > 0 &&
    \   min(map(copy(a:list), 'ingo#compat#strchars(v:val)')) < a:minimumLength &&
    \   ! ingo#list#IsEmpty(a:list)
endfunction
function! s:Split( strings, common )
    let l:prefixes = []
    let l:suffixes = []

    for l:string in a:strings
	let [l:prefix, l:suffix] = ingo#str#split#StrFirst(l:string, a:common)
	call add(l:prefixes, l:prefix)
	call add(l:suffixes, l:suffix)
    endfor

    return [len(l:prefixes), s:Shorten(l:prefixes), s:Shorten(l:suffixes)]
endfunction
function! s:Shorten( list )
    return (ingo#list#IsEmpty(a:list) ?
    \   [] :
    \   a:list
    \)
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo
" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
autoload/ingo/list/pattern.vim	[[[1
122
" ingo/list/pattern.vim: Functions for applying a regular expression to List items.
"
" DEPENDENCIES:
"
" Copyright: (C) 2018 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>

function! ingo#list#pattern#AllItemsMatch( list, pattern )
"******************************************************************************
"* PURPOSE:
"   Test whether each item of the list matches the regular expression.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:list      A list.
"   a:pattern   Regular expression.
"* RETURN VALUES:
"   1 if all items of a:list match a:pattern; else 0.
"******************************************************************************
    return empty(filter(copy(a:list), 'v:val !~# a:pattern'))
endfunction

function! ingo#list#pattern#FirstMatchIndex( list, pattern )
"******************************************************************************
"* PURPOSE:
"   Return the index of the first item in a:list that matches a:pattern, or -1.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:list      A list.
"   a:pattern   Regular expression.
"* RETURN VALUES:
"   Index of the first item that matches a:pattern, or -1 if no item matches.
"******************************************************************************
    let l:i = 0
    while l:i < len(a:list)
	if a:list[l:i] =~# a:pattern
	    return l:i
	endif
	let l:i += 1
    endwhile
    return -1
endfunction

function! ingo#list#pattern#FirstMatch( list, pattern, ... )
"******************************************************************************
"* PURPOSE:
"   Return the first item in a:list that matches a:pattern, or an empty String.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:list      A list.
"   a:pattern   Regular expression.
"   a:noMatchValue  Optional value that is returned (instead of an empty String)
"                   if a:pattern does not match at all.
"* RETURN VALUES:
"   First item that matches a:pattern, or '' (or a:noMatchValue).
"******************************************************************************
    let l:i = ingo#list#pattern#FirstMatchIndex(a:list, a:pattern)
    return (l:i == -1 ? (a:0 ? a:1 : '') : a:list[l:i])
endfunction

function! ingo#list#pattern#AllMatchIndices( list, pattern )
"******************************************************************************
"* PURPOSE:
"   Return a List of indices of those items in a:list that match a:pattern.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:list      A list.
"   a:pattern   Regular expression.
"* RETURN VALUES:
"   (Possibly empty) List of (ascending) indices of matching items.
"******************************************************************************
    let l:i = 0
    let l:result = []
    while l:i < len(a:list)
	if a:list[l:i] =~# a:pattern
	    call add(l:result, l:i)
	endif
	let l:i += 1
    endwhile
    return l:result
endfunction

function! ingo#list#pattern#AllMatches( list, pattern )
"******************************************************************************
"* PURPOSE:
"   Return a List of those items in a:list that match a:pattern.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:list      A list.
"   a:pattern   Regular expression.
"* RETURN VALUES:
"   (Possibly empty) List of matching items. The original a:list is left
"   untouched.
"******************************************************************************
    let l:i = 0
    let l:result = []
    while l:i < len(a:list)
	if a:list[l:i] =~# a:pattern
	    call add(l:result, a:list[l:i])
	endif
	let l:i += 1
    endwhile
    return l:result
endfunction

" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
autoload/ingo/list/sequence.vim	[[[1
71
" ingo/list/sequence.vim: Functions for sequences of numbers etc.
"
" DEPENDENCIES:
"
" Copyright: (C) 2017 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>

function! s:NotRightType()
    throw 'NotRightType'
endfunction
function! s:ToNumber( val )
    return (type(a:val) == type(0) ? a:val : (a:val =~# '^\d\+$' ? str2nr(a:val) : s:NotRightType()))
endfunction
function! ingo#list#sequence#FindNumerical( list )
"******************************************************************************
"* PURPOSE:
"   Analyze whether a:list is made up / starts with a sequence of numbers, and return the
"   length of the sequence and stride.
"* ASSUMPTIONS / PRECONDITIONS:
"   All list elements are interpreted by their numerical value.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:list  Source list to be analyzed.
"* RETURN VALUES:
"   [sequenceLen, stride] (or [0, 0] if not at least two elements).
"******************************************************************************
    if len(a:list) < 2
	return [0, 0]
    endif

    let [l:idx, l:stride] = [0, 0]
    try
	let l:stride = s:ToNumber(a:list[1]) - s:ToNumber(a:list[0])

	let l:idx = 2
	while (l:idx < len(a:list) && s:ToNumber(a:list[l:idx]) - s:ToNumber(a:list[l:idx - 1]) == l:stride)
	    let l:idx += 1
	endwhile
    catch /NotRightType/
	" Using exception for flow control here.
    endtry
    return [l:idx, l:stride]
endfunction

function! ingo#list#sequence#FindCharacter( list )
"******************************************************************************
"* PURPOSE:
"   Analyze whether a:list is made up / starts with a sequence of single
"   characters, and return the length of the sequence and stride.
"* ASSUMPTIONS / PRECONDITIONS:
"   All list elements are interpreted as String.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:list  Source list to be analyzed.
"* RETURN VALUES:
"   [sequenceLen, stride] (or [0, 0] if not at least two elements, or not all
"   elements are single characters).
"******************************************************************************
    try
	let l:characterList = map(copy(a:list), 'v:val =~# "^.$" ? char2nr(v:val) : s:NotRightType()')
	return ingo#list#sequence#FindNumerical(l:characterList)
    catch /NotRightType/
	return [0, 0]
    endtry
endfunction

" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
autoload/ingo/list/split.vim	[[[1
68
" ingo/list/split.vim: Functions for splitting Lists.
"
" DEPENDENCIES:
"
" Copyright: (C) 2016-2018 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>

function! ingo#list#split#ChunksOf( list, n, ... )
"******************************************************************************
"* PURPOSE:
"   Split a:list into a List of Lists of a:n elements.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   Clears a:list.
"* INPUTS:
"   a:list  Source list.
"   a:n     Number of elements for each sublist.
"   a:fillValue Optional element that is used to fill the last sublist with if
"		there are not a:n elements left for it. If omitted, the last
"		sublist may have less than a:n elements.
"* RETURN VALUES:
"   [[e1, e2, ... en], [...]]
"******************************************************************************
    let l:result = []
    while ! empty(a:list)
	if len(a:list) >= a:n
	    let l:subList = remove(a:list, 0, a:n - 1)
	else
	    let l:subList = remove(a:list, 0, -1)
	    if a:0
		call extend(l:subList, repeat([a:1], a:n - len(l:subList)))
	    endif
	endif
	call add(l:result, l:subList)
    endwhile
    return l:result
endfunction

function! ingo#list#split#RemoveFromStartWhilePredicate( list, Predicate )
"******************************************************************************
"* PURPOSE:
"   Split off elements from the start of a:list while a:Predicate is true.
"* SEE ALSO:
"   - If you want to split off _all_ elements where a:Predicate matches (not
"     just from the start), use ingo#collections#Partition() instead.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   Removes element(s) from the start of the list.
"* INPUTS:
"   a:list      Source list.
"   a:Predicate Either a Funcref or an expression to be eval()ed where v:val
"               represents the current element.
"* RETURN VALUES:
"   List of elements that matched a:Predicate at the start of a:list.
"******************************************************************************
    let l:idx = 0
    while l:idx < len(a:list) && ingo#actions#EvaluateWithValOrFunc(a:Predicate, a:list[l:idx])
	let l:idx += 1
    endwhile

    return (l:idx > 0 ? remove(a:list, 0, l:idx - 1) : [])
endfunction

" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
autoload/ingo/lists.vim	[[[1
25
" ingo/lists.vim: Functions to compare Lists.
"
" DEPENDENCIES:
"
" Copyright: (C) 2018 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>

function! ingo#lists#StartsWith( list, sublist, ... )
    if len(a:list) < len(a:sublist)
	return 0
    elseif len(a:sublist) == 0
	return 1
    endif

    let l:ignorecase = (a:0 && a:1)
    if l:ignorecase
	return (a:list[0 : len(a:sublist) - 1] ==? a:sublist)
    else
	return (a:list[0 : len(a:sublist) - 1] ==# a:sublist)
    endif
endfunction

" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
autoload/ingo/lists/find.vim	[[[1
40
" ingo/lists/find.vim: Functions for comparing Lists.
"
" DEPENDENCIES:
"
" Copyright: (C) 2018 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>

function! ingo#lists#find#FirstDifferent( list1, list2 )
"******************************************************************************
"* PURPOSE:
"   Compare elements in a:list1 and a:list2 and return the index of the first
"   elements that are not equal.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:list1 A list.
"   a:list2 Another list.
"* RETURN VALUES:
"   Index of the first element not equal / not existing in one of the lists.
"   -1 if both lists are identical; i.e. have the same number of elements and
"   all elements are equal..
"******************************************************************************
    let l:i = 0
    while l:i < len(a:list1)
	if l:i >= len(a:list2)
	    return l:i
	elseif a:list1[l:i] != a:list2[l:i]
	    return l:i
	endif

	let l:i += 1
    endwhile
    return -1
endfunction

" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
autoload/ingo/lnum.vim	[[[1
39
" ingo/lnum.vim: Functions to work with line numbers.
"
" DEPENDENCIES:
"
" Copyright: (C) 2018 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>

function! ingo#lnum#AddOffsetWithWrapping( lnum, offset, ... )
"******************************************************************************
"* PURPOSE:
"   Add a:offset to a:lnum; if the result is less than 1 or larger than
"   a:maxLnum, wrap around.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:lnum      Source line number.
"   a:offset    Positive or negative offset to apply to a:lnum.
"   a:maxLnum   Maximum allowed line number; defaults to line('$'), the last
"               line of the current buffer.
"* RETURN VALUES:
"   1 <= result <= a:maxLnum
"******************************************************************************
    let l:lnum = a:lnum + a:offset
    let l:maxLnum = (a:0 ? a:1 : line('$'))

    if l:lnum < 1
	return l:maxLnum + l:lnum % l:maxLnum
    elseif l:lnum > l:maxLnum
	return l:lnum % l:maxLnum
    else
	return l:lnum
    endif
endfunction

" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
autoload/ingo/mapmaker.vim	[[[1
71
" ingo/mapmaker.vim: Functions that create mappings.
"
" DEPENDENCIES:
"
" Copyright: (C) 2010-2013 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
"
" REVISION	DATE		REMARKS
"   1.006.001	17-Apr-2013	file creation from ingointegration.vim

function! s:OpfuncExpression( opfunc )
    let &opfunc = a:opfunc

    let l:keys = 'g@'

    if ! &l:modifiable || &l:readonly
	" Probe for "Cannot make changes" error and readonly warning via a no-op
	" dummy modification.
	" In the case of a nomodifiable buffer, Vim will abort the normal mode
	" command chain, discard the g@, and thus not invoke the operatorfunc.
	let l:keys = ":call setline('.', getline('.'))\<CR>" . l:keys
    endif

    return l:keys
endfunction
function! ingo#mapmaker#OperatorMappingForRangeCommand( mapArgs, mapKeys, rangeCommand )
"******************************************************************************
"* PURPOSE:
"   Define a custom operator mapping "\xx{motion}" (where \xx is a:mapKeys) that
"   allows a [count] before and after the operator and supports repetition via
"   |.|.
"
"* ASSUMPTIONS / PRECONDITIONS:
"   Checks for a 'nomodifiable' or 'readonly' buffer and forces the proper Vim
"   error / warning, so it assumes that a:rangeCommand mutates the buffer.
"
"* EFFECTS / POSTCONDITIONS:
"   Defines a normal mode mapping for a:mapKeys.
"
"* INPUTS:
"   a:mapArgs	Arguments to the :map command, like '<buffer>' for a
"		buffer-local mapping.
"   a:mapKeys	Mapping key [sequence].
"   a:rangeCommand  Custom Ex command which takes a [range].
"
"* RETURN VALUES:
"   None.
"******************************************************************************
    let l:cnt = 0
    while 1
	let l:rangeCommandOperator = printf('Range%s%sOperator', matchstr(a:rangeCommand, '\w\+'), (l:cnt ? l:cnt : ''))
	if ! exists('*s:' . l:rangeCommandOperator)
	    break
	endif
	let l:cnt += 1
    endwhile

    execute printf("
    \	function! s:%s( type )\n
    \	    execute \"'[,']%s\"\n
    \	endfunction\n",
    \	l:rangeCommandOperator,
    \	a:rangeCommand
    \)

    execute 'nnoremap <expr>' a:mapArgs a:mapKeys '<SID>OpfuncExpression(''<SID>' . l:rangeCommandOperator . ''')'
endfunction

" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
autoload/ingo/matches.vim	[[[1
81
" ingo/matches.vim: Functions for pattern matching.
"
" DEPENDENCIES:
"   - ingo/list.vim autoload script
"
" Copyright: (C) 2013-2018 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>

function! s:Count()
    let s:matchCnt += 1
    return submatch(0)
endfunction
function! ingo#matches#CountMatches( text, pattern )
"******************************************************************************
"* PURPOSE:
"   Count the number of matches of a:pattern in a:text.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:text  String or List of Strings to be matches (each element individually).
"   a:pattern   Regular expression to be matched.
"* RETURN VALUES:
"   Number of matches.
"******************************************************************************
    let s:matchCnt = 0
    for l:line in ingo#list#Make(a:text)
	call substitute(l:line, a:pattern, '\=s:Count()', 'g')
    endfor
    return s:matchCnt
endfunction


function! ingo#matches#Any( text, patterns )
"******************************************************************************
"* PURPOSE:
"   Test whether any pattern in a:pattern matches a:text.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:text  String to be tested.
"   a:patterns  List of regular expressions.
"* RETURN VALUES:
"   1 if at least one pattern in a:patterns matches in a:text (or no pattern was
"   passed); 0 otherwise.
"******************************************************************************
    for l:pattern in a:patterns
	if a:text =~# l:pattern
	    return 1
	endif
    endfor
    return empty(a:patterns)
endfunction
function! ingo#matches#All( text, patterns )
"******************************************************************************
"* PURPOSE:
"   Test whether all patterns in a:pattern matches a:text.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:text  String to be tested.
"   a:patterns  List of regular expressions.
"* RETURN VALUES:
"   0 if at least one pattern in a:patterns does not match a:text; 1 otherwise.
"******************************************************************************
    for l:pattern in a:patterns
	if a:text !~# l:pattern
	    return 0
	endif
    endfor
    return 1
endfunction

" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
autoload/ingo/math.vim	[[[1
40
" ingo/math.vim: Mathematical functions.
"
" DEPENDENCIES:
"
" Copyright: (C) 2016 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
"
" REVISION	DATE		REMARKS
"   1.029.001	27-Dec-2016	file creation

"******************************************************************************
"* PURPOSE:
"   Return the power of a:x to the exponent a:y as a Number.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:x Number.
"   a:y Exponent.
"* RETURN VALUES:
"   Number.
"******************************************************************************
if exists('*pow')
    function! ingo#math#PowNr( x, y )
	return float2nr(pow(a:x, a:y))
    endfunction
else
    function! ingo#math#PowNr( x, y )
	let l:r = a:x
	for l:i in range(a:y - 1)
	    let l:r = l:r * a:x
	endfor
	return l:r
    endfunction
endif

" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
autoload/ingo/mbyte/virtcol.vim	[[[1
46
" ingo/mbyte/virtcol.vim: Multibyte-aware translation functions between byte index and virtcol.
"
" DEPENDENCIES:

" Copyright: (C) 2009-2017 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>

function! ingo#mbyte#virtcol#GetVirtStartColOfCurrentCharacter( lineNum, column )
    let l:currentVirtCol = ingo#mbyte#virtcol#GetVirtColOfCurrentCharacter(a:lineNum, a:column)
    let l:offset = 1
    while virtcol([a:lineNum, a:column - l:offset]) == l:currentVirtCol
	let l:offset += 1
    endwhile
    return virtcol([a:lineNum, a:column - l:offset]) + 1
endfunction
function! ingo#mbyte#virtcol#GetVirtColOfCurrentCharacter( lineNum, column )
    " virtcol() only returns the (end) virtual column of the current character
    " if the column points to the first byte of a multi-byte character. If we're
    " pointing to the middle or end of a multi-byte character, the end virtual
    " column of the _next_ character is returned.
    let l:offset = 1
    while a:column - l:offset > 0 && virtcol([a:lineNum, a:column - l:offset]) == virtcol([a:lineNum, a:column + 1])
	" If the next column's virtual column is the same, we're in the middle
	" of a multi-byte character, and must backtrack to get this character's
	" virtual column.
	let l:offset += 1
    endwhile
    return virtcol([a:lineNum, a:column - l:offset + 1])
endfunction
function! ingo#mbyte#virtcol#GetVirtColOfNextCharacter( lineNum, column )
    let l:currentVirtCol = ingo#mbyte#virtcol#GetVirtColOfCurrentCharacter(a:lineNum, a:column)
    let l:offset = 1
    while virtcol([a:lineNum, a:column + l:offset]) == l:currentVirtCol
	let l:offset += 1
    endwhile
    return virtcol([a:lineNum, a:column + l:offset])
endfunction

function! ingo#mbyte#virtcol#GetColOfVirtCol( lineNum, virtCol )
    let l:col = searchpos(printf('\%%%dl.\%%>%dv', a:lineNum, a:virtCol), 'cnw')[1]
    return (l:col > 0 ? l:col : len(getline(a:lineNum)) + 1)
endfunction

" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
autoload/ingo/motion/boundary.vim	[[[1
155
" ingo/motion/boundary.vim: Functions to go to the first / last of something.
"
" DEPENDENCIES:
"
" Copyright: (C) 2012-2013 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
"
" REVISION	DATE		REMARKS
"   1.012.003	08-Aug-2013	Move into ingo-library.
"				Add the remaining motions from
"				UniversalIteratorMapping.vim.
"	002	01-Aug-2012	Avoid cursor movement when there's no change /
"				spell checking is not enabled by trying a jump
"				before moving the cursor to the beginning / end
"				of the buffer.
"	001	01-Aug-2012	file creation from UniversalIteratorMapping.vim

" In diff mode, the granularity of changes is _per line_. The ']c' command
" doesn't wrap around the file.
" To go to the first change (even when it's on the first line of the buffer), go
" to line 1, then next change, then previous change.
function! s:TryGotoChange()
    let l:currentPosition = getpos('.')
    silent! normal! [c
    if getpos('.') == l:currentPosition
	silent! normal! ]c
	if getpos('.') == l:currentPosition
	    return 0
	endif
    endif

    return 1
endfunction
function! ingo#motion#boundary#FirstChange( count )
    " Try to locate any change before moving the cursor.
    if ! s:TryGotoChange()
	execute "normal! \<C-\>\<C-n>\<Esc>" | " Beep.
	return
    endif

    normal! gg]c
    silent! normal! [c

    if a:count > 1
	execute 'normal!' (v:count - 1) . ']c'
    endif
endfunction
function! ingo#motion#boundary#LastChange( count )
    " Try to locate any change before moving the cursor.
    if ! s:TryGotoChange()
	execute "normal! \<C-\>\<C-n>\<Esc>" | " Beep.
	return
    endif

    normal! G[c
    silent! normal! ]c

    if a:count > 1
	execute 'normal!' (v:count - 1) . '[c'
    endif
endfunction


" In spell mode, the granularity of spell errors is _per word_. The ']s' command
" observes 'wrapscan' and can thus wrap around the file.
" To go to the first spell error, temporarily turn off 'wrapscan' (this also
" avoids any wrap message), goto first line, first column, then next
" spell error, then previous spell error (there is only one if the buffer starts
" with a misspelling).
" To go to the last spell error, goto last line, last column, then previous
" spell error. (If the last word has a spell error, that'll jump to the
" beginning of the last word.)
" When typed, ']s' et al. open the fold at the search result, but inside a
" mapping or :normal this must be done explicitly via 'zv'.
function! ingo#motion#boundary#FirstMisspelling( count )
    let l:save_wrapscan = &wrapscan
    try
	" Do a jump to any misspelling first to force the "E756: Spell checking
	" is not enabled" error before moving the cursor.
	set wrapscan
	silent normal! ]s

	set nowrapscan
	normal! gg0]s
	silent! normal! [s
    finally
	let &wrapscan = l:save_wrapscan
    endtry

    if a:count > 1
	execute 'normal!' (v:count - 1) . ']s'
    endif

    normal! zv
endfunction
function! ingo#motion#boundary#LastMisspelling( count )
    let l:save_wrapscan = &wrapscan
    try
	" Do a jump to any misspelling first to force the "E756: Spell checking
	" is not enabled" error before moving the cursor.
	set wrapscan
	silent normal! ]s

	set nowrapscan
	normal! G$[s
    finally
	let &wrapscan = l:save_wrapscan
    endtry

    if a:count > 1
	execute 'normal!' (v:count - 1) . '[s'
    endif

    normal! zv
endfunction

function! ingo#motion#boundary#FirstArgument( count )
    if a:count <= 1
	first
    else
	execute a:count 'argument'
    endif
endfunction
function! ingo#motion#boundary#LastArgument( count )
    if a:count <= 1
	last
    elseif a:count > argc()
	throw 'E164: Cannot go before first file'
    else
	execute (argc() - a:count + 1) . 'argument'
    endif
endfunction

function! ingo#motion#boundary#LastQuickfix( count )
    if a:count <= 1
	clast
    else
	execute max([1, (len(getqflist()) - a:count + 1)]) . 'cfirst'
    endif

    normal! zv
endfunction
function! ingo#motion#boundary#LastLocationList( count )
    if a:count <= 1
	llast
    else
	execute max([1, (len(getqflist()) - a:count + 1)]) . 'lfirst'
    endif

    normal! zv
endfunction

" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
autoload/ingo/motion/helper.vim	[[[1
59
" ingo/motion/helper.vim: Functions for implementing custom motions.
"
" DEPENDENCIES:
"   - ingo/option.vim autoload script
"
" Copyright: (C) 2014 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
"
" REVISION	DATE		REMARKS
"   1.021.002	12-Jun-2014	Make test for 'virtualedit' option values also
"				account for multiple values.
"   1.016.001	11-Jan-2014	file creation

function! ingo#motion#helper#AdditionalMovement( ... )
"******************************************************************************
"* PURPOSE:
"   Make additional adaptive movement in a custom motion for certain modes.
"   The difference between normal mode, operator-pending and visual mode with
"   'selection' set to "exclusive" is that in the latter two, the motion must go
"   _past_ the final character, so that all characters of the text are selected.
"   This is done by appending a 'l' motion after the search for the text.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:isSpecialLastLineTreatment    Optional flag that allows to turn off the
"				    special treatment at the end of the last
"				    line; by default enabled.
"* RETURN VALUES:
"   None.
"******************************************************************************
    let l:isSpecialLastLineTreatment = (a:0 && a:1 || ! a:0)

    " The 'l' motion only works properly at the end of the line (i.e. when the
    " moved-over text is at the end of the line) when the 'l' motion is allowed
    " to move over to the next line. Thus, the 'l' motion is added temporarily
    " to the global 'whichwrap' setting. Without this, the motion would leave
    " out the last character in the line.
    let l:save_ww = &whichwrap
    set whichwrap+=l
    if l:isSpecialLastLineTreatment && line('.') == line('$') && ! ingo#option#ContainsOneOf(&virtualedit, ['all', 'onemore'])
	" For the last line in the buffer, that still doesn't work in
	" operator-pending mode, unless we can do virtual editing.
	let l:save_virtualedit = &virtualedit
	set virtualedit=onemore
	normal! l
	augroup IngoLibraryTempVirtualEdit
	    execute 'autocmd! CursorMoved * set virtualedit=' . l:save_virtualedit . ' | autocmd! IngoLibraryTempVirtualEdit'
	augroup END
    else
	normal! l
    endif
    let &whichwrap = l:save_ww
endfunction

" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
autoload/ingo/motion/omap.vim	[[[1
35
" ingo/motion/omap.vim: Helper function to repeat special operator-pending mappings.
"
" DEPENDENCIES:
"   - repeat.vim (vimscript #2136) autoload script (optional)
"
" Copyright: (C) 2014 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
"
" REVISION	DATE		REMARKS
"   1.016.001	15-Jan-2014	file creation
let s:save_cpo = &cpo
set cpo&vim

function! ingo#motion#omap#repeat( repeatMapping, operator, count )
    if a:operator ==# 'y' && &cpoptions !~# 'y'
	" A yank usually doesn't repeat.
	return
    endif

    silent! call repeat#set(a:operator . a:repeatMapping .
    \   (a:operator ==# 'c' ? "\<Plug>(IngoLibraryOmapRepeatReinsert)" : ''),
    \   a:count
    \)
endfunction

" This is for the special repeat of a "c" command, to insert the last entered
" text and leave insert mode. We define a :noremap so that any user mappings do
" not affect this.
inoremap <Plug>(IngoLibraryOmapRepeatReinsert) <C-r>.<Esc>

let &cpo = s:save_cpo
unlet s:save_cpo
" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
autoload/ingo/msg.vim	[[[1
195
" ingo/msg.vim: Functions for Vim errors and warnings.
"
" DEPENDENCIES:
"
" Copyright: (C) 2013-2019 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
"
" REVISION	DATE		REMARKS
"   1.029.010	10-Jan-2017	Add ingo#msg#ColoredMsg() and
"				ingo#msg#ColoredStatusMsg().
"   1.027.009	22-Aug-2016	Add ingo#msg#MsgFromShellError().
"   1.025.008	01-Aug-2016	ingo#msg#HighlightMsg(): Make a:hlgroup
"				optional, default to 'None' (so the function is
"				useful to return to normal highlighting).
"				Add ingo#msg#HighlightN(), an :echon variant.
"   1.025.007	15-Jul-2016	Add ingo#msg#VerboseMsg().
"   1.019.006	05-May-2014	Add optional a:isBeep argument to
"				ingo#msg#ErrorMsg().
"   1.009.005	21-Jun-2013	:echomsg sets v:statusmsg itself when there's no
"				current highlighting; no need to do that then in
"				ingo#msg#StatusMsg(). Instead, allow to set a
"				custom highlight group for the message.
"				Add ingo#msg#HighlightMsg() and use that in the
"				other functions.
"   1.009.004	14-Jun-2013	Minor: Make substitute() robust against
"				'ignorecase'.
"   1.006.003	06-May-2013	Add ingo#msg#StatusMsg().
"   1.003.002	13-Mar-2013	Add ingo#msg#ShellError().
"   1.000.001	22-Jan-2013	file creation

function! ingo#msg#HighlightMsg( text, ... )
    execute 'echohl' (a:0 ? a:1 : 'None')
    echomsg a:text
    echohl None
endfunction
function! ingo#msg#HighlightN( text, ... )
    execute 'echohl' (a:0 ? a:1 : 'None')
    echon a:text
    echohl None
endfunction

function! ingo#msg#StatusMsg( text, ... )
"******************************************************************************
"* PURPOSE:
"   Echo a message, optionally with a custom highlight group, and store the
"   message in v:statusmsg. (Vim only does this automatically when there's no
"   active highlighting.)
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:text  The message to be echoed and added to the message history.
"   a:hlgroup   Optional highlight group name.
"* RETURN VALUES:
"   None.
"******************************************************************************
    if a:0
	let v:statusmsg = a:text
	call ingo#msg#HighlightMsg(a:text, a:1)
    else
	echohl None
	echomsg a:text
    endif
endfunction

function! ingo#msg#ColoredMsg( ... )
"******************************************************************************
"* PURPOSE:
"   Echo a message that contains various, differently highlighted parts.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:part | [a:part, a:hlgroup], ...   Message parts or Pairs of message parts
"					and highlight group names. For the
"					former, reverts to "no highlighting".
"* RETURN VALUES:
"   None.
"******************************************************************************
    let l:isFirst = 1

    for l:element in a:000
	let [l:part, l:hlgroup] = (type(l:element) == type([]) ? l:element: [l:element, 'None'])
	execute 'echohl' l:hlgroup
	execute (l:isFirst ? 'echo' : 'echon') 'l:part'
	let l:isFirst = 0
    endfor
    echohl None
endfunction
function! ingo#msg#ColoredStatusMsg( ... )
"******************************************************************************
"* PURPOSE:
"   Echo a message that contains various, differently highlighted parts, and
"   store the full message in v:statusmsg.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   Performs a :redraw to put the message into the message history.
"* INPUTS:
"   a:part | [a:part, a:hlgroup], ...   Message parts or Pairs of message parts
"					and highlight group names. For the
"					former, reverts to "no highlighting".
"* RETURN VALUES:
"   None.
"******************************************************************************
    let l:elements = map(copy(a:000), "(type(v:val) == type([]) ? v:val: [v:val, 'None'])")
    let l:text = join(map(copy(l:elements), 'v:val[0]'), '')
    echomsg l:text
    redraw

    let l:isFirst = 1
    for [l:part, l:hlgroup] in l:elements
	execute 'echohl' l:hlgroup
	execute (l:isFirst ? 'echo' : 'echon') 'l:part'
	let l:isFirst = 0
    endfor
    echohl None
endfunction

function! ingo#msg#VerboseMsg( text, ... )
"******************************************************************************
"* PURPOSE:
"   Echo a message if 'verbose' is greater or equal 1 (or the optional
"   a:verboselevel).
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:text  The message to be echoed in verbose mode.
"* RETURN VALUES:
"   None.
"******************************************************************************
    if &verbose >= (a:0 ? a:1 : 1)
	echomsg a:text
    endif
endfunction

function! ingo#msg#WarningMsg( text )
    let v:warningmsg = a:text
    call ingo#msg#HighlightMsg(v:warningmsg, 'WarningMsg')
endfunction

function! ingo#msg#ErrorMsg( text, ... )
    let v:errmsg = a:text
    call ingo#msg#HighlightMsg(v:errmsg, 'ErrorMsg')

    if a:0 && a:1
	execute "normal! \<C-\>\<C-n>\<Esc>" | " Beep.
    endif
endfunction

function! ingo#msg#MsgFromVimException()
    " v:exception contains what is normally in v:errmsg, but with extra
    " exception source info prepended, which we cut away.
    return substitute(v:exception, '^\CVim\%((\a\+)\)\=:', '', '')
endfunction
function! ingo#msg#MsgFromCustomException( customPrefixPattern ) abort
    return substitute(v:exception, printf('^\C\%%(%s\):\s*', a:customPrefixPattern), '', '')
endfunction
function! ingo#msg#VimExceptionMsg()
    call ingo#msg#ErrorMsg(ingo#msg#MsgFromVimException())
endfunction
function! ingo#msg#CustomExceptionMsg( customPrefixPattern )
    call ingo#msg#ErrorMsg(ingo#msg#MsgFromCustomException(a:customPrefixPattern))
endfunction

function! ingo#msg#MsgFromShellError( whatFailure, shellOutput )
    if empty(a:shellOutput)
	let l:details = ['exit status ' . v:shell_error]
    else
	let l:details = split(a:shellOutput, "\n")
    endif
    return printf('Failed to %s: %s', a:whatFailure, join(l:details, ' '))
endfunction
function! ingo#msg#ShellError( whatFailure, shellOutput )
    if empty(a:shellOutput)
	let l:details = ['exit status ' . v:shell_error]
    else
	let l:details = split(a:shellOutput, "\n")
    endif
    let v:errmsg = printf('Failed to %s: %s', a:whatFailure, join(l:details, ' '))
    echohl ErrorMsg
    echomsg printf('Failed to %s: %s', a:whatFailure, l:details[0])
    for l:moreDetail in l:details[1:]
	echomsg l:moreDetail
    endfor
    echohl None
endfunction

" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
autoload/ingo/nary.vim	[[[1
100
" ingo/nary.vim: Functions for working with tuples of numbers in a fixed range.
"
" DEPENDENCIES:
"
" Copyright: (C) 2017 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
"
" REVISION	DATE		REMARKS
"   1.030.001	14-May-2017	file creation

function! ingo#nary#FromNumber( n, number, ... )
"******************************************************************************
"* PURPOSE:
"   Turn the integer a:number into a (little-endian) List of values from [0..n).
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:n         Maximum number that can be represented by one List element.
"   a:number    Positive integer.
"   a:elementNum    Optional number of elements to use. If specified and
"		    a:number cannot be represented by it, a exception is thrown.
"		    If a:elementNum is negative, only the lower elements will be
"		    returned. If omitted, the minimal amount of elements is
"		    used.
"* RETURN VALUES:
"   List of [e0, e1, e2, ...] values; lowest come first.
"******************************************************************************
    let l:number = a:number
    let l:result = []
    let l:elementCnt = 0
    let l:elementMax = (a:0 ? ingo#compat#abs(a:1) : 0)

    while 1
	" Encode this little-endian.
	call add(l:result, l:number % a:n)
	let l:number = l:number / a:n
	let l:elementCnt += 1

	if l:elementMax && l:elementCnt == l:elementMax
	    if a:1 > 0 && l:number != 0
		throw printf('FromNumber: Cannot represent %d in %d elements', a:number, l:elementMax)
	    endif
	    break
	elseif ! a:0 && l:number == 0
	    break
	endif
    endwhile
    return l:result
endfunction
function! ingo#nary#ToNumber( n, elements )
"******************************************************************************
"* PURPOSE:
"   Turn the (little-endian) List of boolean values from [0..n) into a number.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:n         Maximum number that can be represented by one List element.
"   a:elements  List of [e0, e1, e2, ...] values; lowest elements come first.
"* RETURN VALUES:
"   Positive integer represented by a:elements.
"******************************************************************************
    let l:number = 0
    let l:factor = 1
    while ! empty(a:elements)
	let l:number += l:factor * remove(a:elements, 0)
	let l:factor = l:factor * a:n
    endwhile
    return l:number
endfunction

function! ingo#nary#ElementsRequired( n, number )
"******************************************************************************
"* PURPOSE:
"   Determine the number of elements within [0..n) required to represent a:number.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:n         Maximum number that can be represented by one List element.
"   a:number    Positive integer.
"* RETURN VALUES:
"   Number of elements required to represent numbers between 0 and a:number.
"******************************************************************************
    let l:elementCnt = 1
    let l:max = a:n
    while a:number >= l:max
	let l:elementCnt += 1
	let l:max = l:max * a:n
    endwhile
    return l:elementCnt
endfunction

" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
autoload/ingo/number.vim	[[[1
33
" ingo/number.vim: Functions for dealing with numbers.
"
" DEPENDENCIES:
"
" Copyright: (C) 2013 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
"
" REVISION	DATE		REMARKS
"   1.005.001	12-Apr-2013	file creation

function! ingo#number#DecimalStringIncrement( number, offset )
"******************************************************************************
"* PURPOSE:
"   Increment the decimal number in a:number by a:offset while keeping (the
"   width of) leading zeros.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:number    String (or number) to be incremented.
"   a:offset    Offset to add to a:number.
"* RETURN VALUES:
"   Incremented number as String.
"******************************************************************************
    " Note: Need to use str2nr() to avoid interpreting leading zeros as octal
    " number.
    return printf('%0' . strlen(a:number) . 'd', str2nr(a:number) + a:offset)
endfunction

" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
autoload/ingo/option.vim	[[[1
91
" ingo/option.vim: Functions for dealing with Vim options.
"
" DEPENDENCIES:
"
" Copyright: (C) 2014-2018 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>

function! ingo#option#Split( optionValue, ... )
    return call('split', [a:optionValue, '\%(\%(^\|[^\\]\)\%(\\\\\)*\\\)\@<!,'] + a:000)
endfunction
function! ingo#option#SplitAndUnescape( optionValue, ... )
    return map(call('ingo#option#Split', [a:optionValue] + a:000), 'ingo#escape#Unescape(v:val, ",\\")')
endfunction

function! ingo#option#Contains( optionValue, expr )
    return (index(ingo#option#SplitAndUnescape(a:optionValue), a:expr) != -1)
endfunction
function! ingo#option#ContainsOneOf( optionValue, list )
    let l:optionValues = ingo#option#SplitAndUnescape(a:optionValue)
    for l:expr in a:list
	if (index(l:optionValues, l:expr) != -1)
	    return 1
	endif
    endfor
    return 0
endfunction

function! ingo#option#JoinEscaped( ... )
    return join(a:000, ',')
endfunction
function! ingo#option#JoinUnescaped( ... )
    return join(map(copy(a:000), 'escape(v:val, ",")'), ',')
endfunction

function! ingo#option#Append( val1, ... )
"******************************************************************************
"* PURPOSE:
"   Add a:val2, a:val3, ... to the original a:val1 option value. Commas in the
"   additional values will be escaped, empty values will be skipped.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:val1  Original option value.
"* RETURN VALUES:
"   Concatenation of a:val1, a:val2, ...
"******************************************************************************
    let l:result = a:val1
    for l:val in map(copy(a:000), 'escape(v:val, ",")')
	if empty(l:result)
	    let l:result = l:val
	elseif ! empty(l:val)
	    let l:result .= ',' . l:val
	endif
    endfor
    return l:result
endfunction
function! ingo#option#Prepend( val1, ... )
"******************************************************************************
"* PURPOSE:
"   Prepend a:val2, a:val3, ... to the original a:val1 option value. Commas in
"   the additional values will be escaped, empty values will be skipped.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:val1  Original option value.
"* RETURN VALUES:
"   Concatenation of a:val2, ..., a:val1
"******************************************************************************
    let l:result = []
    for l:val in map(copy(a:000), 'escape(v:val, ",")') + [a:val1]
	if empty(l:result)
	    let l:result = l:val
	elseif ! empty(l:val)
	    let l:result .= ',' . l:val
	endif
    endfor
    return l:result
endfunction

function! ingo#option#GetBinaryOptionValue( optionName )
    execute 'let l:originalOptionValue = &' . a:optionName
    return (l:originalOptionValue ? '' : 'no') . a:optionName
endfunction

" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
autoload/ingo/os.vim	[[[1
38
" ingo/os.vim: Functions for operating system-specific stuff.
"
" DEPENDENCIES:
"
" Copyright: (C) 2013-2017 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
"
" REVISION	DATE		REMARKS
"   1.030.005	21-Apr-2017	Add ingo#os#IsWindowsShell().
"   1.014.004	26-Sep-2013	Add ingo#os#IsCygwin().
"   1.014.003	13-Sep-2013	Add ingo#os#PathSeparator().
"   1.013.002	13-Sep-2013	FIX: Correct case of ingo#os#IsWin*() function
"				names.
"   1.012.001	08-Aug-2013	file creation

function! ingo#os#IsWindows()
    return has('win16') || has('win95') || has('win32') || has('win64')
endfunction

function! ingo#os#IsWinOrDos()
    return has('dos16') || has('dos32') || ingo#os#IsWindows()
endfunction

function! ingo#os#IsCygwin()
    return has('win32unix')
endfunction

function! ingo#os#PathSeparator()
    return (ingo#os#IsWinOrDos() ? ';' : ':')
endfunction

function! ingo#os#IsWindowsShell()
    return (&shell =~? 'cmd\.exe$')
endfunction

" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
autoload/ingo/plugin/cmd/withpattern.vim	[[[1
61
" ingo/plugin/cmd/withpattern.vim: Functions to make plugin commands that operate on a pattern.
"
" DEPENDENCIES:
"
" Copyright: (C) 2019 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>

let s:lastCommandPatternForId = {}

function! ingo#plugin#cmd#withpattern#CommandWithPattern( id, isQuery, isSelection, commandTemplate, ... )
"******************************************************************************
"* PURPOSE:
"   Build an Ex command from a:commandTemplate that is passed a queried /
"   recalled pattern (stored under a:id) and apply this to the visual selection
"   or the command-line range created from a:count, defaulting to the current
"   line if no count is given.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   - queries for input with a:isQuery
"   - executes a:commandTemplate
"* INPUTS:
"   a:id    Identifier under which the queried pattern is stored and recalled.
"   a:isQuery   Flag whether the pattern is queried from the user.
"   a:isSelection   Flag whether the command should be applied to the last
"                   selected range.
"   a:commandTemplate   Ex command that contains a %s for the queried / recalled
"                       range to be inserted.
"   a:defaultRange  Optional default range when count is 0. Defaults to the
"                   current line ("."); pass "%" to default to the whole buffer
"                   if no count is given (even though the command defaults to
"                   the current line).
"   a:count         Optional given count.
"* RETURN VALUES:
"   1 if success, 0 if the execution failed. An error message is then available
"   from ingo#err#Get().
"******************************************************************************
    if a:isQuery
	let l:pattern = input('/')
	if empty(l:pattern) | return 1 | endif
	let s:lastCommandPatternForId[a:id] = l:pattern
    endif
    if ! has_key(s:lastCommandPatternForId, a:id)
	call ingo#err#Set('No pattern defined yet')
	return 0
    endif

    let l:command = printf(a:commandTemplate, escape(s:lastCommandPatternForId[a:id], '/'))

    try
	execute (a:isSelection ? "'<,'>" : call('ingo#cmdrange#FromCount', a:000)) . l:command
	return 1
    catch /^Vim\%((\a\+)\)\=:/
	call ingo#err#SetVimException()
	return 0
    endtry
endfunction

" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
autoload/ingo/plugin/cmdcomplete.vim	[[[1
175
" ingo/plugin/cmdcomplete.vim: Functions to build simple command completions.
"
" DEPENDENCIES:
"
" Copyright: (C) 2013-2019 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
let s:save_cpo = &cpo
set cpo&vim

let s:completeFuncCnt = 0
function! ingo#plugin#cmdcomplete#MakeCompleteFunc( implementation, ... )
"******************************************************************************
"* PURPOSE:
"   Generically define a complete function for :command -complete=customlist
"   with a:implementation as the function body.
"* USAGE:
"   call ingo#plugin#cmdcomplete#MakeCompleteFunc(
"   \   'return a:ArgLead ==? "f" ? "Foo" : "Bar"', 'FooCompleteFunc')
"   command! -complete=customlist,FooCompleteFunc Foo ...
"	or alternatively
"   execute 'command! -complete=customlist,' .
"	ingo#plugin#cmdcomplete#MakeCompleteFunc(
"	\   'return a:ArgLead ==? "f" ? "Foo" : "Bar"') 'Foo ...'
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   Defines function.
"* INPUTS:
"   a:implementation    String representing the function body of the completion
"                       function. It can refer to the completion arguments
"                       a:ArgLead, a:CmdLine, a:CursorPos.
"   a:funcName      Optional name for the complete function; when not specified,
"		    a unique name is generated.
"* RETURN VALUES:
"   Name of the defined complete function.
"******************************************************************************
    if a:0
	let l:funcName = a:1
    else
	let s:completeFuncCnt += 1
	let l:funcName = printf('CompleteFunc%d', s:completeFuncCnt)
    endif

    execute
    \   printf('function! %s( ArgLead, CmdLine, CursorPos )', l:funcName) . "\n" .
    \       a:implementation . "\n" .
    \       'endfunction'

    return l:funcName
endfunction

function! ingo#plugin#cmdcomplete#MakeFixedListCompleteFunc( argumentList, ... )
"******************************************************************************
"* PURPOSE:
"   Define a complete function for :command -complete=customlist that completes
"   from a static list of possible arguments.
"* USAGE:
"   call ingo#plugin#cmdcomplete#MakeFixedListCompleteFunc(
"   \   ['foo', 'fox', 'bar'], 'FooCompleteFunc')
"   command! -complete=customlist,FooCompleteFunc Foo ...
"	or alternatively
"   execute 'command! -complete=customlist,' .
"	ingo#plugin#cmdcomplete#MakeFixedListCompleteFunc(
"	\   ['foo', 'fox', 'bar']) 'Foo ...'
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   Defines function.
"* INPUTS:
"   a:argumentList  List of possible arguments.
"   a:funcName      Optional name for the complete function; when not specified,
"		    a unique name is generated.
"* RETURN VALUES:
"   Name of the defined complete function.
"******************************************************************************
    return call('ingo#plugin#cmdcomplete#MakeCompleteFunc',
    \   [printf('return filter(%s, ''v:val =~ "\\V\\^" . escape(a:ArgLead, "\\")'')', string(a:argumentList))] +
    \   a:000
    \)
endfunction

function! ingo#plugin#cmdcomplete#DetermineStageList( ArgLead, CmdLine, CursorPos, firstArgumentList, furtherArgumentMap, defaultFurtherArgumentList ) abort
    let l:cmdlineBeforeCursor = strpart(a:CmdLine, 0, a:CursorPos)
    let l:lastCommandArgumentsBeforeCursor = get(ingo#cmdargs#command#Parse(l:cmdlineBeforeCursor, '*'), -1, '')
    if empty(l:lastCommandArgumentsBeforeCursor)
	return a:firstArgumentList
    endif

    for l:firstArgument in a:firstArgumentList
	if l:lastCommandArgumentsBeforeCursor =~# '\V\^\s\*' . escape(l:firstArgument, '\') . '\s\+'
	    return get(a:furtherArgumentMap, l:firstArgument, a:defaultFurtherArgumentList)
	endif
    endfor

    return (l:lastCommandArgumentsBeforeCursor =~# '^\s*\S\+\s\+' ?
    \   a:defaultFurtherArgumentList :
    \   a:firstArgumentList
    \)
endfunction
function! ingo#plugin#cmdcomplete#MakeTwoStageFixedListAndMapCompleteFunc( firstArgumentList, furtherArgumentMap, ... )
"******************************************************************************
"* PURPOSE:
"   Define a complete function for :command -complete=customlist that completes
"   the first argument from a static list of possible arguments and any
"   following arguments from a map keyed by first argument.
"* USAGE:
"   call ingo#plugin#cmdcomplete#MakeTwoStageFixedListAndMapCompleteFunc(
"   \   ['foo', 'fox', 'bar'],
"   \   {'foo': ['f1', 'f2'], 'bar': ['b1', 'b2']},
"   \   ['d1', 'd2'],
"   \   'FooCompleteFunc')
"   command! -complete=customlist,FooCompleteFunc Foo ...
"	or alternatively
"   execute 'command! -complete=customlist,' .
"	ingo#plugin#cmdcomplete#MakeTwoStageFixedListAndMapCompleteFunc(
"	\   ['foo', 'fox', 'bar'], {}) 'Foo ...'
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   Defines function.
"* INPUTS:
"   a:firstArgumentList     List of possible first arguments.
"   a:furtherArgumentMap    Map of the first actually used argument to the List
"                           of possible second, third, ... arguments.
"   a:defaultFurtherArgumentList    Optional list of further arguments if the
"                                   first argument is not one from
"                                   a:firstArgumentList or there's no such key
"                                   in a:furtherArgumentMap.
"   a:funcName      Optional name for the complete function; when not specified,
"		    a unique name is generated.
"* RETURN VALUES:
"   Name of the defined complete function.
"******************************************************************************
    return call('ingo#plugin#cmdcomplete#MakeCompleteFunc',
    \   [printf('return filter(ingo#plugin#cmdcomplete#DetermineStageList(a:ArgLead, a:CmdLine, a:CursorPos, %s, %s, %s), ''v:val =~ "\\V\\^" . escape(a:ArgLead, "\\")'')', string(a:firstArgumentList), string(a:furtherArgumentMap), string(a:0 ? a:1 : []))] +
    \   a:000[1:]
    \)
endfunction

function! ingo#plugin#cmdcomplete#MakeListExprCompleteFunc( argumentExpr, ... )
"******************************************************************************
"* PURPOSE:
"   Define a complete function for :command -complete=customlist that completes
"   from a (dynamically invoked) expression.
"* USAGE:
"   call ingo#plugin#cmdcomplete#MakeListExprCompleteFunc(
"   \   'map(copy(g:values), "v:val[0:3]")', 'FooCompleteFunc')
"   command! -complete=customlist,FooCompleteFunc Foo ...
"	or alternatively
"   execute 'command! -complete=customlist,' .
"	ingo#plugin#cmdcomplete#MakeFixedListCompleteFunc(
"	\   'map(copy(g:values), "v:val[0:3]")') 'Foo ...'
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   Defines function.
"* INPUTS:
"   a:argumentExpr  Expression that returns a List of (currently) possible
"		    arguments when evaluated.
"   a:funcName      Optional name for the complete function; when not specified,
"		    a unique name is generated.
"* RETURN VALUES:
"   Name of the defined complete function.
"******************************************************************************
    return call('ingo#plugin#cmdcomplete#MakeCompleteFunc',
    \   [printf('return filter(%s, ''v:val =~ "\\V\\^" . escape(a:ArgLead, "\\")'')', a:argumentExpr)] +
    \   a:000
    \)
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo
" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
autoload/ingo/plugin/compiler.vim	[[[1
17
" ingo/plugin/compiler.vim: Functions for compiler plugins.
"
" DEPENDENCIES:
"
" Copyright: (C) 2014 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
"
" REVISION	DATE		REMARKS
"   1.016.001	21-Jan-2014	file creation

function! ingo#plugin#compiler#CompilerSet( optionname, expr )
    execute 'CompilerSet' a:optionname . '=' . escape(a:expr, ' "|\')
endfunction

" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
autoload/ingo/plugin/marks.vim	[[[1
133
" ingo/plugin/marks.vim: Functions for reserving marks for plugin use.
"
" DEPENDENCIES:
"
" Copyright: (C) 2010-2019 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>

function! ingo#plugin#marks#Reuse( pos, ... )
"******************************************************************************
"* PURPOSE:
"   Locate (for reuse) an existing mark at a:pos.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:pos               Position, either [lnum, col] or the full [bufnum, lnum,
"			col, off].
"   a:consideredMarks   Optional String or List of marks that are considered.
"			Defaults to lowercase and uppercase marks a-zA-Z.
"* RETURN VALUES:
"   Mark name, or empty String.
"******************************************************************************
    let l:consideredMarks = (a:0 ? a:1 : 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ')
    let l:pos = (len(a:pos) < 4 ? [0] + a:pos[0:1] + [0] : a:pos[0:3])

    for l:mark in (type(l:consideredMarks) == type([]) ? l:consideredMarks : split(l:consideredMarks, '\zs'))
	let l:targetPos = l:pos
	if l:mark =~# '\u'
	    if l:pos[0] == 0
		" Uppercase marks have the buffer number as the first element.
		let l:targetPos = [bufnr('')] + l:pos[1:]
	    endif
	else
	    if l:pos[0] != 0 && l:pos[0] != bufnr('')
		" The searched-for position is in another buffer, so local marks
		" must not be considered.
		continue
	    else
		" Lowercase marks have 0 as the first element.
		let l:targetPos[0] = 0
	    endif
	endif

	if getpos("'" . l:mark) == l:targetPos
	    return l:mark
	endif
    endfor

    return ''
endfunction

function! ingo#plugin#marks#FindUnused( ... )
"******************************************************************************
"* PURPOSE:
"   Find the next unused mark and return it.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   Sets the mark to avoid finding them again. The client will probably override
"   the mark location, anyway.
"* INPUTS:
"   a:consideredMarks   Optional String or List of marks that are considered.
"			Defaults to lowercase and uppercase marks a-zA-Z.
"* RETURN VALUES:
"   Mark name. Throws exception if no mark is available.
"******************************************************************************
    let l:consideredMarks = (a:0 && ! empty(a:1) ? a:1 : 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ')

    for l:mark in (type(l:consideredMarks) == type([]) ? l:consideredMarks : split(l:consideredMarks, '\zs'))
	if getpos("'" . l:mark)[1:2] == [0, 0]
	    " Reserve mark so that the next invocation doesn't return it again.
	    call setpos("'" . l:mark, getpos('.'))
	    return l:mark
	endif
    endfor
    throw 'ReserveMarks: Ran out of unused marks!'
endfunction

function! ingo#plugin#marks#Reserve( number, ... )
"******************************************************************************
"* PURPOSE:
"   Reserve a:number of available marks for use and return undo information.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   Sets reserved marks to avoid finding them again. The client will probably
"   override the mark location, anyway.
"* INPUTS:
"   a:number	Number of marks to be reserved.
"   a:marks	Optional string of concatenated marks. If passed, those marks
"               will be taken (and current positions will be saved in the undo
"               information). If empty or omitted, unused marks will be used.
"* RETURN VALUES:
"   reservedMarksRecord. Use keys(reservedMarksRecord) to get the names of the
"   reserved marks.  The records object must also be passed back to
"   ingo#plugin#marks#Unreserve().
"   Throws exception if no mark is available (and no a:marks had been passed).
"******************************************************************************
    let l:marksRecord = {}
    for l:cnt in range(0, (a:number - 1))
	let l:mark = strpart((a:0 ? a:1 : ''), l:cnt, 1)
	if empty(l:mark)
	    let l:unusedMark = ingo#plugin#marks#FindUnused()
	    let l:marksRecord[l:unusedMark] = [0, 0, 0, 0]
	else
	    let l:marksRecord[l:mark] = getpos("'" . l:mark)
	endif
    endfor
    return l:marksRecord
endfunction
function! ingo#plugin#marks#Unreserve( marksRecord )
"******************************************************************************
"* PURPOSE:
"   Unreserve marks and restore the original mark position.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   Resets reserved marks.
"* INPUTS:
"   a:marksRecord   Undo information object handed out by
"		    ingo#plugin#marks#Reserve().
"* RETURN VALUES:
"   None.
"******************************************************************************
    for l:mark in keys(a:marksRecord)
	call setpos("'" . l:mark, a:marksRecord[l:mark])
    endfor
endfunction

" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
autoload/ingo/plugin/persistence.vim	[[[1
212
" ingo/plugin/persistence.vim: Functions to store plugin data persistently across Vim sessions.
"
" DEPENDENCIES:
"
" Copyright: (C) 2019 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>

let s:compatFor = (exists('g:IngoLibrary_CompatFor') ? ingo#collections#ToDict(split(g:IngoLibrary_CompatFor, ',')) : {})

function! s:CompatibilityDeserialization( globalVariableName, targetType, rawValue )
    if (a:targetType == type([]) || a:targetType == type({})) && type(a:rawValue) != a:targetType
	try
	    execute 'let l:tempValue = ' a:rawValue

	    if type(l:tempValue) == a:targetType
		return l:tempValue
	    else
		throw printf('Load: Wrong deserialized type in %s; expected %d got %d.', a:globalVariableName, a:targetType, type(l:tempValue))
	    endif
	catch /^Vim\%((\a\+)\)\=:/
	    throw 'Load: Corrupted deserialized value in ' . a:globalVariableName
	endtry
    else
	return a:rawValue
    endif
endfunction
if (v:version == 703 && has('patch030') || v:version > 703) && ! has_key(s:compatFor, 'viminfoBasicTypes')
    function! s:CompatibilitySerialization( rawValue )
	return a:rawValue
    endfunction
else
    function! s:CompatibilitySerialization( rawValue )
	return string(a:rawValue)
    endfunction
endif

function! ingo#plugin#persistence#CanPersist( ... )
    return (index(split(&viminfo, ','), '!') != -1) && (! a:0 || a:1 =~# '^\u\L*$')
endfunction

function! ingo#plugin#persistence#Store( variableName, value )
"******************************************************************************
"* PURPOSE:
"   Store a:value under a:variableName. If empty(a:value), removes
"   a:variableName.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   Defines / updates global a:variableName.
"* INPUTS:
"   a:variableName  Global variable under which a:value is to be stored, if
"                   uppercased and configured, also in the viminfo file.
"   a:value         Value to be stored.
"* RETURN VALUES:
"   1 if persisted (/ removed) successfully, 0 if persistence is not configured,
"   or the variable is not all-uppercase.
"******************************************************************************
    let l:globalVariableName = 'g:' . a:variableName

    if empty(a:value)
	execute 'unlet!' l:globalVariableName
    else
	execute 'let' l:globalVariableName '= s:CompatibilitySerialization(a:value)'
    endif

    return ingo#plugin#persistence#CanPersist(a:variableName)
endfunction

function! ingo#plugin#persistence#Add( variableName, ... )
"******************************************************************************
"* PURPOSE:
"   Add a:value / a:key + a:value in the List / Dict a:variableName.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   Defines / updates global a:variableName.
"* INPUTS:
"   a:variableName  Global variable under which a:value is to be stored, if
"                   uppercased and configured, also in the viminfo file.
"   a:key           Optional key under which a:value is stored in a Dict-type
"                   a:variableName.
"   a:value         Value to be stored.
"* RETURN VALUES:
"   1 if persisted successfully, 0 if persistence is not configured, or the
"   variable is not all-uppercase.
"   Throws "Add: Wrong variable type" if a:variableName is already defined by
"   does not have the correct type for the number of arguments passed.
"******************************************************************************
    if a:0 < 1 || a:0 > 2
	throw "Add: Must pass [key, ] value"
    endif
    let l:isList = (a:0 == 1)

    let l:globalVariableName = 'g:' . a:variableName

    if exists(l:globalVariableName)
	let l:original = ingo#plugin#persistence#Load(a:variableName)
	if type(l:original) != type(l:isList ? [] : {})
	    throw "Add: Wrong variable type"
	endif
    else
	let l:original = (l:isList ? [] : {})
    endif

    if l:isList
	call add(l:original, a:1)
    else
	let l:original[a:1] = a:2
    endif

    return ingo#plugin#persistence#Store(a:variableName, l:original)
endfunction

function! ingo#plugin#persistence#Remove( variableName, expr )
"******************************************************************************
"* PURPOSE:
"   Remove a:expr (representing an index / key) from the List / Dict
"   a:variableName.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   Updates global a:variableName.
"* INPUTS:
"   a:variableName  Global variable under which a:value is to be stored, if
"                   uppercased and configured, also in the viminfo file.
"   a:expr          List index / Dictionary key to be removed.
"* RETURN VALUES:
"   1 if persisted successfully, 0 if persistence is not configured, or the
"   variable is not all-uppercase.
"******************************************************************************
    let l:globalVariableName = 'g:' . a:variableName

    if exists(l:globalVariableName)
	let l:original = ingo#plugin#persistence#Load(a:variableName)

	if type(l:original) == type([])
	    call remove(l:original, a:expr)
	elseif type(l:original) == type({})
	    unlet! l:original[a:expr]
	else
	    throw 'Remove: Not list nor dict'
	endif

	return ingo#plugin#persistence#Store(a:variableName, l:original)
    else
	" Nothing to do.
	return ingo#plugin#persistence#CanPersist(a:variableName)
    endif

endfunction

function! ingo#plugin#persistence#Load( variableName, ... )
"******************************************************************************
"* PURPOSE:
"   Load the persisted a:variableName and return it.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:variableName  Global variable that (if uppercased) is stored in viminfo
"                   file.
"   a:defaultValue  Optional value to return when persistence is not configured,
"                   or nothing was stored yet in viminfo. If omitted, will throw
"                   a Load: .. exception instead.
"                   For older Vim versions, also indicates the variable type
"                   (List or Dict) into which the raw value is deserialized.
"* RETURN VALUES:
"   Persisted (or current if a:variableName contains lowercase characters) value
"   or a:defaultValue / exception.
"   Throws "Load: Corrupted deserialized value in ..." or "Load: Wrong
"   deserialized type ..." if a:defaultValue is given and the deserialization to
"   its variable type fails.
"******************************************************************************
    let l:globalVariableName = 'g:' . a:variableName
    if exists(l:globalVariableName)
	let l:rawValue = eval(l:globalVariableName)
	return (a:0 ? s:CompatibilityDeserialization(l:globalVariableName, type(a:1), l:rawValue) : l:rawValue)
    elseif a:0
	return a:1
    else
	throw printf('Load: Nothing stored under %s%s', l:globalVariableName, (ingo#plugin#persistence#CanPersist(a:variableName) ? '' : ', and persistence not ' . (ingo#plugin#persistence#CanPersist() ? 'possible for that name' : 'configured')))
    endif
endfunction

function! ingo#plugin#persistence#QueryYesNo( question )
"******************************************************************************
"* PURPOSE:
"   Ask the user whether a:question should be accepted or declined, with
"   variants for the current instance, the current Vim session, or persistently
"   across sessions.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   Queries user via confirm().
"* INPUTS:
"   a:question  Text to be shown to the user.
"* RETURN VALUES:
"   One of "Yes", "No", "Always", "Never", "Forever", "Never ever", or empty
"   string if the dialog was aborted.
"******************************************************************************
    let l:choices = ['&Yes', '&No', '&Always', 'Ne&ver' ]
    if ingo#plugin#persistence#CanPersist()
	let l:choices += ['&Forever', 'Never &ever']
    endif

    return ingo#query#ConfirmAsText(a:question, l:choices, 0, 'Question')
endfunction

" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
autoload/ingo/plugin/rendered.vim	[[[1
253
" ingo/plugin/rendered.vim: Functions to interactively work with rendered items.
"
" DEPENDENCIES:
"   - ingo/avoidprompt.vim autoload script
"   - ingo/query.vim autoload script
"   - ingo/subs/BraceCreation.vim autoload script
"   - ingo/plugin/rendered/*.vim autoload scripts
"
" Copyright: (C) 2018 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
let s:save_cpo = &cpo
set cpo&vim

function! ingo#plugin#rendered#List( what, renderer, additionalOptions, items )
"******************************************************************************
"* PURPOSE:
"   Allow interactive reordering, filtering, and eventual rendering of List
"   a:items (and potentially more a:additionalOptions).
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:what  Text describing what each element in a:items represents (e.g.
"           "matches").
"   a:renderer  Object that implements the rendering of the a:items.
"		Can supply additional rendering options presented to the user,
"		via a List returned from a:renderer.options(). If such an option
"		is chosen, a:renderer.handleOption(command) is invoked. Finally,
"		a:renderer.render(items) is used to render the List.
"		This library ships with some default renderers that can be
"		copy()ed and passed; see below.
"   a:additionalOptions List of additional options presented to the user. Can
"                       include "&" accelerators; these will be dropped in the
"                       command passed to a:renderer.handleOption().
"   a:items     List of items to be renderer.
"* RETURN VALUES:
"   List of [command, renderedItems]. The command contains "Quit" if the user
"   chose to cancel. If an additional option was chosen, command contains the
"   option (without "&" accelerators), and renderedItems the (so far unrendered,
"   but potentially filtered) List of a:items. If an ordering was chosen,
"   command is empty and renderedItems contains the result.
"******************************************************************************
    let l:items = a:items
    let l:processOptions = a:additionalOptions + ['&Confirm each', '&Subset', '&Quit']
    let l:additionalChoices = map(copy(a:additionalOptions), 'ingo#query#StripAccellerator(v:val)')

    let l:save_guioptions = &guioptions
    set guioptions+=c
    try
	while 1
	    redraw
	    let l:orderingOptions = []
	    let l:orderingToItems = {}
	    let l:orderingToString = {}
	    call s:AddOrdering(l:orderingOptions, l:orderingToItems, l:orderingToString, '&Original',   a:renderer, l:items, l:items)
	    call s:AddOrdering(l:orderingOptions, l:orderingToItems, l:orderingToString, 'Re&versed',   a:renderer, l:items, reverse(copy(l:items)))
	    call s:AddOrdering(l:orderingOptions, l:orderingToItems, l:orderingToString, '&Ascending',  a:renderer, l:items, sort(copy(l:items)))
	    call s:AddOrdering(l:orderingOptions, l:orderingToItems, l:orderingToString, '&Descending', a:renderer, l:items, reverse(sort(copy(l:items))))

	    let l:orderingMessage = printf('Choose ordering for %d %s: ', len(l:items), a:what)

	    let l:rendererOptions = a:renderer.options()
	    let l:renderChoices = map(copy(l:rendererOptions), 'ingo#query#StripAccellerator(v:val)')
	    let l:ordering = ingo#query#ConfirmAsText(l:orderingMessage, l:orderingOptions + l:rendererOptions + l:processOptions, 1)
	    if empty(l:ordering) || l:ordering ==# 'Quit'
		return ['Quit', '']
	    elseif l:ordering ==# 'Confirm each' || l:ordering == 'Subset'
		if v:version < 702 | runtime autoload/ingo/plugin/rendered/*.vim | endif  " The Funcref doesn't trigger the autoload in older Vim versions.
		let l:ProcessingFuncref = function('ingo#plugin#rendered#' . substitute(l:ordering, '\s', '', 'g') . '#Filter')
		let l:items = call(l:ProcessingFuncref, [l:items])
	    elseif index(l:renderChoices, l:ordering) != -1
		call a:renderer.handleOption(l:ordering)
	    elseif index(l:additionalChoices, l:ordering) != -1
		return [l:ordering, l:items]
	    else
		break
	    endif
	endwhile
    finally
	let &guioptions = l:save_guioptions
    endtry

    return ['', l:orderingToString[l:ordering]]
endfunction
function! s:AddOrdering( orderingOptions, orderingToItems, orderingToString, option, renderer, items, reorderedItems )
    if a:reorderedItems isnot# a:items && a:reorderedItems ==# a:items ||
    \   index(values(a:orderingToItems), a:reorderedItems) != -1
	return
    endif

    let l:option = substitute(a:option, '&', '', 'g')
    let l:string = call(a:renderer.render, [a:reorderedItems])

    if index(values(a:orderingToString), l:string) != -1
	" Different ordering yields same rendered string; skip.
	return
    endif

    call add(a:orderingOptions, a:option)
    let a:orderingToItems[l:option] = a:reorderedItems
    let a:orderingToString[l:option] = l:string

    call ingo#avoidprompt#EchoAsSingleLine(printf("%s:\t%s", l:option, l:string))
endfunction



"******************************************************************************
"* PURPOSE:
"   Renderer that joins the items on a self.separator, and optionally wraps the
"   result in self.prefix and self.suffix.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"******************************************************************************
let g:ingo#plugin#rendered#JoinRenderer = {
\   'prefix': '',
\   'separator': '',
\   'suffix': '',
\}
function! g:ingo#plugin#rendered#JoinRenderer.options() dict
    return []
endfunction
function! g:ingo#plugin#rendered#JoinRenderer.render( items ) dict
    return self.prefix . join(a:items, self.separator) . self.suffix
endfunction
function! g:ingo#plugin#rendered#JoinRenderer.handleOption( command ) dict
endfunction

"******************************************************************************
"* PURPOSE:
"   Renderer that extracts common substrings and turns these into a Brace
"   Expression, like in Bash. The algorithm's parameters can be tweaked by the
"   user. These tweaks override any defaults in self.braceOptions, which is the
"   configuration passed to ingo#subs#BraceCreation#FromList().
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"******************************************************************************
let g:ingo#plugin#rendered#BraceExpressionRenderer = {
\   'commonLengthOffset': 0,
\   'differingLengthOffset': 0,
\   'braceOptions': {}
\}
function! g:ingo#plugin#rendered#BraceExpressionRenderer.options() dict
    let l:options = ['Longer co&mmon', 'Shor&ter common', 'Longer disti&nct', 'Sho&rter distinct']
    if ! get(self.braceOptions, 'strict', 0) | call add(l:options, '&Strict') | endif
    if ! get(self.braceOptions, 'short', 0)  | call add(l:options, 'S&hort')  | endif
    return l:options
endfunction
function! g:ingo#plugin#rendered#BraceExpressionRenderer.render( items ) dict
    let l:braceOptions = copy(self.braceOptions)
    let l:braceOptions.minimumCommonLength    = max([1, get(self.braceOptions, 'minimumCommonLength', 1) + self.commonLengthOffset])
    let l:braceOptions.minimumDifferingLength = max([0, get(self.braceOptions, 'minimumDifferingLength', 0) + self.differingLengthOffset])

    return ingo#subs#BraceCreation#FromList(a:items, l:braceOptions)
endfunction
function! g:ingo#plugin#rendered#BraceExpressionRenderer.handleOption( command ) dict
    if a:command ==# 'Strict'
	let self.braceOptions.strict = 1
	let self.braceOptions.short = 0
    elseif a:command ==# 'Short'
	let self.braceOptions.short = 1
	let self.braceOptions.strict = 0
    elseif a:command ==# 'Longer common'
	let self.commonLengthOffset += 1
    elseif a:command ==# 'Shorter common'
	let self.commonLengthOffset -= 1
    elseif a:command ==# 'Longer distinct'
	let self.differingLengthOffset += 1
    elseif a:command ==# 'Shorter distinct'
	let self.differingLengthOffset -= 1
    else
	throw 'ASSERT: Invalid render command: ' . string(a:command)
    endif
endfunction



function! ingo#plugin#rendered#ListJoinedOrBraceExpression( what, braceOptions, additionalOptions, items )
"******************************************************************************
"* PURPOSE:
"   Allow interactive reordering, filtering, and eventual rendering of List
"   a:items (and potentially more a:additionalOptions) either as a joined String
"   or as a Bash-like Brace Expression. The separator (and optional prefix /
"   suffix) is queried first, and can be changed during the interaction. Also,
"   there's the option to yank the result to a register.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:what  Text describing what each element in a:items represents (e.g.
"           "matches").
"   a:braceOptions  Dictionary of parameters for the Brace Expression creation;
"                   cp. ingo#subs#BraceCreation#FromList().
"   a:additionalOptions List of additional options presented to the user. Can
"                       include "&" accelerators; these will be dropped in the
"                       command passed to a:renderer.handleOption().
"   a:items     List of items to be renderer.
"* RETURN VALUES:
"   List of [command, renderedItems]. The command contains "Quit" if the user
"   chose to cancel, and "Yank" if the result was yanked to a register. If an
"   additional option was chosen, command contains the option (without "&"
"   accelerators), and renderedItems the (so far unrendered, but potentially
"   filtered) List of a:items. If an ordering was chosen, command is empty and
"   renderedItems contains the result.
"******************************************************************************
    echohl Question
	let l:separator = input('Enter separator string (or prefix^Mseparator^Msuffix); empty for creation of Brace Expression: ')
    echohl None
    if empty(l:separator)
	let l:renderer = copy(g:ingo#plugin#rendered#BraceExpressionRenderer)
	let l:renderer.braceOptions = a:braceOptions
    else
	let l:renderer = copy(g:ingo#plugin#rendered#JoinRenderer)
	let l:renderer.separator = l:separator
	if l:renderer.separator =~# '^\%(\r\@!.\)*\r\%(\r\@!.\)*\r\%(\r\@!.\)*$'
	    let [l:renderer.prefix, l:renderer.separator, l:renderer.suffix] = split(l:renderer.separator, '\r', 1)
	endif
    endif


    let [l:command, l:result] = ingo#plugin#rendered#List(a:what, l:renderer, ['Change se&parator', '&Yank'] + a:additionalOptions, a:items)
    if l:command ==# 'Quit'
	return [l:command, '']
    elseif l:command ==# 'Yank'
	call ingo#msg#HighlightMsg('Register ([a-zA-Z0-9"*+] <Enter> for default): ', 'Question')
	let l:register = ingo#query#get#Char({'validExpr': '[a-zA-Z0-9"*+\r]'})
	if empty(l:register) | continue | endif
	let l:register = (l:register ==# "\<C-m>" ? '' : l:register)
	let [l:command, l:result] = ingo#plugin#rendered#List('yanked ' . a:what, l:renderer, [], l:result)
	if empty(l:command)
	    call setreg(l:register, l:result)
	endif
	return ['Yank', l:result]
    elseif l:command ==# 'Change separator'
	return ingo#plugin#rendered#ListJoinedOrBraceExpression(a:what, a:braceOptions, a:additionalOptions, a:items)
    elseif empty(l:command)
	return ['', l:result]
    else
	throw 'ASSERT: Invalid command: ' . string(l:command)
    endif
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo
" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
autoload/ingo/plugin/rendered/Confirmeach.vim	[[[1
43
" ingo/plugin/rendered/Confirmeach.vim: Filter items by confirming each, as with :s///c.
"
" DEPENDENCIES:
"   - ingo/query/get.vim autoload script
"
" Copyright: (C) 2015-2018 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>

function! ingo#plugin#rendered#Confirmeach#Filter( items )
    let l:confirmedItems = []
    let l:idx = 0
    while l:idx < len(a:items)
	let l:match = a:items[l:idx]

	echo l:match . "\t"
	echohl Question
	    echon ' Use (y/n/a/q/l; <Esc> to abort)?'
	echohl None

	let l:choice = ingo#query#get#Char({'isBeepOnInvalid': 0, 'validExpr': "[ynl\<Esc>aq]"})
	if l:choice ==# "\<Esc>"
	    return a:items
	elseif l:choice ==# 'q'
	    break
	elseif l:choice ==# 'y'
	    call add(l:confirmedItems, l:match)
	elseif l:choice ==# 'l'
	    call add(l:confirmedItems, l:match)
	    break
	elseif l:choice ==# 'a'
	    let l:confirmedItems += a:items[l:idx : -1]
	    break
	endif

	let l:idx += 1
    endwhile

    return l:confirmedItems
endfunction

" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
autoload/ingo/plugin/rendered/Subset.vim	[[[1
49
" ingo/plugin/rendered/Subset.vim: Filter items by List indices.
"
" DEPENDENCIES:
"   - ingo/cmdargs/pattern.vim autoload script
"   - ingo/list.vim autoload script
"   - ingo/msg.vim autoload script
"
" Copyright: (C) 2015-2018 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>

function! ingo#plugin#rendered#Subset#Filter( items )
    echohl Question
    let l:subsets = input('Enter subsets in Vim List notation, e.g. "0 3:5 -1", or matching /pattern/ (non-matching with !/.../): ')
    echohl None

    let l:subsetsPattern = ingo#cmdargs#pattern#ParseUnescaped(l:subsets)
    if l:subsetsPattern !=# l:subsets
	return s:FilterByPattern(a:items, l:subsetsPattern, 0)
    elseif l:subsets[0] ==# '!'
	let l:subsetsPattern = ingo#cmdargs#pattern#ParseUnescaped(l:subsets[1:])
	if l:subsetsPattern !=# l:subsets
	    return s:FilterByPattern(a:items, l:subsetsPattern, 1)
	endif
    endif
    return s:Slice(a:items, split(l:subsets))
endfunction

function! s:FilterByPattern( items, pattern, isKeepNonMatching )
    return filter(a:items, printf('v:val %s~ a:pattern', a:isKeepNonMatching ? '!' : '='))
endfunction

function! s:Slice( items, subsets )
    try
	let l:subsetItems = []
	for l:subset in a:subsets
	    execute printf('let l:subsetItems += ingo#list#Make(a:items[%s])', l:subset)
	endfor
	return l:subsetItems
    catch /^Vim\%((\a\+)\)\=:/
	redraw
	call ingo#msg#VimExceptionMsg()
	sleep 500m
	return ingo#plugin#rendered#Subset#Filter(a:items)
    endtry
endfunction

" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
autoload/ingo/plugin/setting.vim	[[[1
103
" ingo/plugin/setting.vim: Functions for retrieving plugin settings.
"
" DEPENDENCIES:
"
" Copyright: (C) 2009-2017 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
"
" REVISION	DATE		REMARKS
"   1.030.008	20-Feb-2017	Add ingo#plugin#setting#Default().
"   1.023.007	27-Jan-2015	Add ingo#plugin#setting#GetScope().
"   1.023.006	06-Dec-2014	Add ingo#plugin#setting#GetTabLocal().
"   1.019.005	16-Apr-2014	Add ingo#plugin#setting#BooleanToStringValue().
"   1.010.004	08-Jul-2013	Add prefix to exception thrown from
"				ingo#plugin#setting#GetFromScope().
"   1.005.003	10-Apr-2013	Move into ingo-library.
"	002	06-Jul-2010	ENH: Now supporting passing of default value
"				instead of throwing exception, like the built-in
"				get().
"	001	04-Sep-2009	file creation

function! ingo#plugin#setting#GetScope( variableName, scopeList )
"******************************************************************************
"* PURPOSE:
"   Get the scope of a configuration variable that can be defined in multiple
"   scopes.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:variableName  Name of the variable.
"   a:scopeList     List of variable scope prefixes. These are tried in
"		    sequential order.
"* RETURN VALUES:
"   Scope prefix from a:scopeList where a:variableName is defined, or empty if
"   it's defined nowhere.
"******************************************************************************
    for l:scope in a:scopeList
	let l:variable = l:scope . ':' . a:variableName
	if exists(l:variable)
	    return l:scope
	endif
    endfor
    return ''
endfunction
function! ingo#plugin#setting#GetFromScope( variableName, scopeList, ... )
"******************************************************************************
"* PURPOSE:
"   Get a configuration variable that can be defined in multiple scopes.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:variableName  Name of the variable.
"   a:scopeList     List of variable scope prefixes. These are tried in
"		    sequential order.
"   a:defaultValue  Optional value to be returned when no a:variableName is
"		    defined in any of the a:scopeList. If omitted, an exception
"		    is thrown instead.
"* RETURN VALUES:
"   Value of a:variableName from the first scope in a:scopeList where it is
"   defined, or a:defaultValue, or exception.
"******************************************************************************
    for l:scope in a:scopeList
	let l:variable = l:scope . ':' . a:variableName
	if exists(l:variable)
	    execute 'return' l:variable
	endif
    endfor
    if a:0
	return a:1
    else
	throw 'GetFromScope: No variable named "' . a:variableName . '" defined.'
    endif
endfunction

function! ingo#plugin#setting#GetBufferLocal( variableName, ... )
    return call('ingo#plugin#setting#GetFromScope', [a:variableName, ['b', 'g']] + a:000)
endfunction
function! ingo#plugin#setting#GetWindowLocal( variableName, ... )
    return call('ingo#plugin#setting#GetFromScope', [a:variableName, ['w', 'g']] + a:000)
endfunction
function! ingo#plugin#setting#GetTabLocal( variableName, ... )
    return call('ingo#plugin#setting#GetFromScope', [a:variableName, ['t', 'g']] + a:000)
endfunction

function! ingo#plugin#setting#BooleanToStringValue( settingName, ... )
    if a:0
	let l:settingValue = a:1
    else
	execute 'let l:settingValue = &' . a:settingName
    endif
    return l:settingValue ? a:settingName : 'no' . a:settingName
endfunction

function! ingo#plugin#setting#Default( value, defaultValue )
    return (a:value ==# '' ? a:defaultValue : a:value)
endfunction

" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
autoload/ingo/pos.vim	[[[1
94
" ingo/pos.vim: Functions for comparing positions.
"
" DEPENDENCIES:
"
" Copyright: (C) 2014-2019 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>

function! ingo#pos#Make4( pos, ... ) abort
    if a:0 > 0
	if a:0 != 1
	    throw 'Make4: Must pass exactly two line, column arguments or a List'
	endif
	return [0, a:pos, a:1, 0]
    endif

    return (len(a:pos) >= 4 ? a:pos : [0, get(a:pos, 0, 0), get(a:pos, 1, 0), 0])
endfunction
function! ingo#pos#Make2( pos ) abort
    return (len(a:pos) >= 3 ? a:pos[1:2] : a:pos)
endfunction


function! ingo#pos#Compare( posA, posB )
    if a:posA == a:posB
	return 0
    else
	return (a:posA[0] > a:posB[0] || a:posA[0] == a:posB[0] && a:posA[1] > a:posB[1] ? 1 : -1)
    endif
endfunction

function! ingo#pos#IsOnOrAfter( posA, posB )
    return (a:posA[0] > a:posB[0] || a:posA[0] == a:posB[0] && a:posA[1] >= a:posB[1])
endfunction
function! ingo#pos#IsAfter( posA, posB )
    return (a:posA[0] > a:posB[0] || a:posA[0] == a:posB[0] && a:posA[1] > a:posB[1])
endfunction

function! ingo#pos#IsOnOrBefore( posA, posB )
    return (a:posA[0] < a:posB[0] || a:posA[0] == a:posB[0] && a:posA[1] <= a:posB[1])
endfunction
function! ingo#pos#IsBefore( posA, posB )
    return (a:posA[0] < a:posB[0] || a:posA[0] == a:posB[0] && a:posA[1] < a:posB[1])
endfunction

function! ingo#pos#IsOutside( pos, start, end )
    return (a:pos[0] < a:start[0] || a:pos[0] > a:end[0] || a:pos[0] == a:start[0] && a:pos[1] < a:start[1] || a:pos[0] == a:end[0] && a:pos[1] > a:end[1])
endfunction

function! ingo#pos#IsInside( pos, start, end )
    return ! ingo#pos#IsOutside(a:pos, a:start, a:end)
endfunction

function! ingo#pos#IsInsideVisualSelection( pos, ... )
    let l:start = (a:0 == 2 ? a:1 : getpos("'<")[1:2])
    let l:end   = (a:0 == 2 ? a:2 : getpos("'>")[1:2])
    if &selection ==# 'exclusive'
	return ! (a:pos[0] < l:start[0] || a:pos[0] > l:end[0] || a:pos[0] == l:start[0] && a:pos[1] < l:start[1] || a:pos[0] == l:end[0] && a:pos[1] >= l:end[1])
    else
	return ! (a:pos[0] < l:start[0] || a:pos[0] > l:end[0] || a:pos[0] == l:start[0] && a:pos[1] < l:start[1] || a:pos[0] == l:end[0] && a:pos[1] > l:end[1])
    endif
endfunction

function! ingo#pos#Before( pos )
    if a:pos[1] == 1
	return [a:pos[0], 0]
    endif

    let l:charBeforePosition = matchstr(getline(a:pos[0]), '.\%' . a:pos[1] . 'c')
    return (empty(l:charBeforePosition) ? [0, 0] : [a:pos[0], a:pos[1] - len(l:charBeforePosition)])
endfunction
function! ingo#pos#After( pos )
    let l:charAtPosition = matchstr(getline(a:pos[0]), '\%' . a:pos[1] . 'c.')
    return (empty(l:charAtPosition) ? [0, 0] : [a:pos[0], a:pos[1] + len(l:charAtPosition)])
endfunction



function! ingo#pos#SameLineIsOnOrAfter( posA, posB )
    return (a:posA[0] == a:posB[0] && a:posA[1] >= a:posB[1])
endfunction
function! ingo#pos#SameLineIsAfter( posA, posB )
    return (a:posA[0] == a:posB[0] && a:posA[1] > a:posB[1])
endfunction

function! ingo#pos#SameLineIsOnOrBefore( posA, posB )
    return (a:posA[0] == a:posB[0] && a:posA[1] <= a:posB[1])
endfunction
function! ingo#pos#SameLineIsBefore( posA, posB )
    return (a:posA[0] == a:posB[0] && a:posA[1] < a:posB[1])
endfunction

" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
autoload/ingo/print.vim	[[[1
39
" ingo/print.vim: Functions for printling lines.
"
" DEPENDENCIES:
"   - ingo/window/dimensions.vim autoload script
"
" Copyright: (C) 2013 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
"
" REVISION	DATE		REMARKS
"   1.015.001	22-Nov-2013	file creation

function! ingo#print#Number( lnum, ... )
"******************************************************************************
"* PURPOSE:
"   Like :number, but does not move the cursor to the line, and only prints the
"   passed a:lnum, not all lines in a (potential) closed fold.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   :echos output.
"* INPUTS:
"   a:lnum      Line number; when the line does not exist, nothing is printed.
"   a:hlgroup   Optional highlight group for the number, default is "LineNr".
"* RETURN VALUES:
"   1 is line exists and was printed; 0 otherwise.
"******************************************************************************
    if a:lnum < 1 || a:lnum > line('$')
	return 0
    endif

    execute 'echohl' (a:0 ? a:1 : 'LineNr')
    echo printf('%' . (ingo#window#dimensions#GetNumberWidth(1) - 1) . 'd ', a:lnum)
    echohl None
    echon getline(a:lnum)
endfunction

" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
autoload/ingo/query.vim	[[[1
141
" ingo/query.vim: Functions for user queries.
"
" DEPENDENCIES:
"
" Copyright: (C) 2014-2016 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
"
" REVISION	DATE		REMARKS
"   1.027.004	27-Sep-2016	Expose ingo#query#StripAccellerator().
"   1.025.003	27-Jan-2016	Refactoring: Factor out ingo#query#Question().
"   1.019.002	20-May-2014	confirm() automatically presets the first
"				character with an accelerator when no "&"
"				present; do that for s:EchoEmulatedConfirm(),
"				too.
"   1.019.001	30-Apr-2014	file creation from
"				autoload/IndentConsistencyCop.vim and
"				autoload/DropQuery.vim
let s:save_cpo = &cpo
set cpo&vim

function! ingo#query#Question( msg )
    echohl Question
    echomsg a:msg
    echohl None
endfunction


function! ingo#query#StripAccellerator( choice )
    return substitute(a:choice, '&', '', 'g')
endfunction
function! s:EchoEmulatedConfirm( msg, choices, defaultIndex )
    let l:defaultChoice = (a:defaultIndex > 0 ? get(a:choices, a:defaultIndex - 1) : '')
    echo a:msg
    echo join(map(copy(a:choices), 'substitute(v:val, "\\%(^\\%(.*&.*$\\)\\@!\\|&\\)\\(.\\)", (v:val ==# l:defaultChoice ? "[\\1]" : "(\\1)"), "g")'), ', ') . ': '
endfunction

function! ingo#query#Confirm( msg, ... )
"******************************************************************************
"* PURPOSE:
"   Drop-in replacement for confirm() that supports "headless mode", i.e.
"   bypassing the actual dialog so that no user intervention is necessary (in
"   automated tests).
"
"* ASSUMPTIONS / PRECONDITIONS:
"   The headless mode is activated by defining a List of choices (either
"   numerical return values of confirm(), or the choice text without the
"   shortcut key "&") in g:IngoLibrary_ConfirmChoices. Each invocation of this
"   function removes the first element from that List and returns it.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   See confirm().
"* RETURN VALUES:
"   See confirm().
"******************************************************************************
    if exists('g:IngoLibrary_ConfirmChoices') && len(g:IngoLibrary_ConfirmChoices) > 0
	" Headless mode: Bypass actual confirm so that no user intervention is
	" necesary.

	let l:choices = (a:0 ? split(a:1, '\n', 1) : ['&Ok'])
	let l:plainChoices = map(copy(l:choices), 'ingo#query#StripAccellerator(v:val)')

	" Emulate the console output of confirm(), so that it looks for a test
	" driver as if it were real.
	let l:defaultIndex = (a:0 >= 2 ? a:2 : 0)
	call s:EchoEmulatedConfirm(a:msg, l:choices, l:defaultIndex)

	" Return predefined choice.
	let l:choice = remove(g:IngoLibrary_ConfirmChoices, 0)
	return (type(l:choice) == type(0) ?
	\   l:choice :
	\   (l:choice == '' ?
	\       0 :
	\       index(l:plainChoices, l:choice) + 1
	\   )
	\)
    endif
    return call('confirm', [a:msg] + a:000)
endfunction

function! ingo#query#ConfirmAsText( msg, choices, ... )
"******************************************************************************
"* PURPOSE:
"   Replacement for confirm() that returns choices by name, not by index, and
"   supports "headless mode", i.e. bypassing the actual dialog so that no user
"   intervention is necessary (in automated tests).
"
"* ASSUMPTIONS / PRECONDITIONS:
"   The headless mode is activated by defining a List of choices (either
"   numerical return values of confirm(), or the choice text without the
"   shortcut key "&") in g:IngoLibrary_ConfirmChoices. Each invocation of this
"   function removes the first element from that List and returns it.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:msg	Dialog text.
"   a:choices	List of choices (not a newline-delimited String as in
"		|confirm()|). Set the shortcut key by prepending '&'.
"   a:default	Default choice text. Either number (0 for no default, (index +
"		1) for choice) or choice text; omit any shortcut key '&' there.
"   a:type      Optional type of dialog; see |confirm()|.
"* RETURN VALUES:
"   Choice text without the shortcut key '&'. Empty string if the dialog was
"   aborted.
"******************************************************************************
    let l:plainChoices = map(copy(a:choices), 'ingo#query#StripAccellerator(v:val)')

    let l:confirmArgs = [a:msg, join(a:choices, "\n")]
    if a:0
	call add(l:confirmArgs, (type(a:1) == type(0) ? a:1 : max([index(l:plainChoices, a:1) + 1, 0])))
	call extend(l:confirmArgs, a:000[1:])
    endif

    if exists('g:IngoLibrary_ConfirmChoices') && len(g:IngoLibrary_ConfirmChoices) > 0
	" Headless mode: Bypass actual confirm so that no user intervention is
	" necesary.

	" Emulate the console output of confirm(), so that it looks for a test
	" driver as if it were real.
	let l:defaultIndex = get(l:confirmArgs, 2, 0)
	call s:EchoEmulatedConfirm(a:msg, a:choices, l:defaultIndex)

	" Return predefined choice.
	let l:choice = remove(g:IngoLibrary_ConfirmChoices, 0)
	return (type(l:choice) == type(0) ?
	\   (l:choice == 0 ?
	\       '' :
	\       ingo#query#StripAccellerator(get(a:choices, l:choice - 1, ''))
	\   ) :
	\   l:choice
	\)
    endif
    let l:index = call('confirm', l:confirmArgs)
    return (l:index > 0 ? get(l:plainChoices, l:index - 1, '') : '')
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo
" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
autoload/ingo/query/confirm.vim	[[[1
76
" ingo/query/confirm.vim: Functions for building choices for confirm().
"
" DEPENDENCIES:
"
" Copyright: (C) 2013-2019 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
let s:save_cpo = &cpo
set cpo&vim

let s:acceleratorPattern = '[[:alnum:]]'
function! ingo#query#confirm#AutoAccelerators( choices, ... )
"******************************************************************************
"* PURPOSE:
"   Automatically add unique accelerators (&Accelerator) for the passed
"   a:choices, to be used in confirm(). Considers already existing ones.
"   Tries to assign to the first (possible) letter with priority.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   Modifies a:choices.
"* INPUTS:
"   a:choices   List of choices where the accelerators should be inserted.
"   a:defaultChoice Number (i.e. index + 1) of the default in a:choices. It is
"		    assumed that this item does not need an accelerator (in the
"		    GUI dialog). Pass -1 if there's no default (so that all
"		    items get accelerators).
"* RETURN VALUES:
"   Modified a:choices.
"******************************************************************************
    let l:isGui = (has('gui_running') && &guioptions !~# 'c')
    let l:defaultChoiceIdx = (a:0 ? a:1 - 1 : 0)
    let l:usedAccelerators = filter(
    \   map(
    \       copy(a:choices),
    \       'tolower(matchstr(v:val, "\\C&\\zs" . s:acceleratorPattern))',
    \   ),
    \   '! empty(v:val)'
    \)

    if ! l:isGui && l:defaultChoiceIdx >= 0 && a:choices[l:defaultChoiceIdx] !~# '&.'
	" When no GUI dialog is used, the default choice automatically gets an
	" accelerator, so don't assign that one to avoid masking another choice.
	call add(l:usedAccelerators, matchstr(a:choices[l:defaultChoiceIdx], '^.'))
    endif

    call   map(a:choices, 'v:key == l:defaultChoiceIdx ? v:val : s:AddAccelerator(l:usedAccelerators, v:val, 1)')
    return map(a:choices, 'v:key == l:defaultChoiceIdx ? v:val : s:AddAccelerator(l:usedAccelerators, v:val, 0)')
endfunction
function! s:AddAccelerator( usedAccelerators, value, isWantFirstCharacter )
    if a:value =~# '&' . s:acceleratorPattern
	return a:value
    endif

    if a:isWantFirstCharacter
	let l:candidates = ingo#list#NonEmpty([tolower(matchstr(a:value, s:acceleratorPattern))])
    else
	let l:candidates = split(
	\   tolower(substitute(a:value, '\%(' . s:acceleratorPattern . '\)\@!.', '', 'g')),
	\   '\zs'
	\)
    endif

    for l:candidate in l:candidates
	if index(a:usedAccelerators, l:candidate) == -1
	    call add(a:usedAccelerators, l:candidate)
	    return substitute(a:value, '\V\c' . escape(l:candidate, '\'), '\&&', '')
	endif
    endfor
    return a:value
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo
" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
autoload/ingo/query/file.vim	[[[1
59
" ingo/query/file.vim: Functions to query files from the user.
"
" DEPENDENCIES:
"   - ingo/compat.vim autoload script
"
" Copyright: (C) 2012-2013 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
"
" REVISION	DATE		REMARKS
"   1.012.006	08-Aug-2013	Move escapings.vim into ingo-library.
"   1.009.005	28-Jun-2013	FIX: Avoid E108: No such variable:
"				"b:browsefilter".
"   1.008.004	06-Jun-2013	Fix missing argument error for
"				ingo#query#file#BrowseDirForOpenFile() and
"				ingo#query#file#BrowseDirForAction().
"   1.007.003	31-May-2013	Move into ingo-library.
"	002	30-Nov-2012	ENH: Allow Funcref action for
"				ingouserinteraction#BrowseDirForAction().
"	001	27-Jan-2012	file creation from 00ingomenu.vim.

function! ingo#query#file#Browse( save, title, initdir, default, browsefilter )
    if exists('b:browsefilter')
	let l:save_browsefilter = b:browsefilter
    endif
    if empty(a:browsefilter)
	unlet! b:browsefilter
    else
	let b:browsefilter = a:browsefilter . "All Files (*.*)\t*.*\n"
    endif
    try
	return browse(a:save, a:title, a:initdir, a:default)
    finally
	if exists('l:save_browsefilter')
	    let b:browsefilter = l:save_browsefilter
	else
	    unlet! b:browsefilter
	endif
    endtry
endfunction
function! ingo#query#file#BrowseDirForAction( action, title, dirspec, browsefilter )
    let l:filespec = ingo#query#file#Browse(0, a:title, expand(a:dirspec), '', a:browsefilter)
    if ! empty(l:filespec)
	if type(a:action) == type(function('tr'))
	    call call(a:action, [l:filespec])
	else
	    execute a:action ingo#compat#fnameescape(l:filespec)
	endif
    else
	echomsg 'Canceled opening of file.'
    endif
endfunction
function! ingo#query#file#BrowseDirForOpenFile( title, dirspec, browsefilter )
    call ingo#query#file#BrowseDirForAction(((exists(':Drop') == 2) ? 'Drop' : 'drop'), a:title, a:dirspec, a:browsefilter)
endfunction


" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
autoload/ingo/query/fromlist.vim	[[[1
157
" ingo/query/fromlist.vim: Functions for querying elements from a list.
"
" DEPENDENCIES:
"   - ingo/compat.vim autoload script
"   - ingo/query.vim autoload script
"   - ingo/query/confirm.vim autoload script
"   - ingo/query/get.vim autoload script
"   - ingo/query/recall.vim autoload script
"
" Copyright: (C) 2014-2018 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
let s:save_cpo = &cpo
set cpo&vim

function! ingo#query#fromlist#RenderList( list, defaultIndex, formatString )
    let l:result = []
    for l:i in range(len(a:list))
	call add(l:result,
	\   printf(a:formatString, l:i + 1) .
	\   substitute(a:list[l:i], '&\(.\)', (l:i == a:defaultIndex ? '[\1]' : '(\1)'), '')
	\)
    endfor
    return l:result
endfunction
function! ingo#query#fromlist#Query( what, list, ... )
"******************************************************************************
"* PURPOSE:
"   Query for one entry from a:list; elements can be selected by accelerator key
"   or the number of the element. Supports "headless mode", i.e. bypassing the
"   actual dialog so that no user intervention is necessary (in automated
"   tests).
"* SEE ALSO:
"   ingo#query#recall#Query() provides an alternative means to query one
"   (longer) entry from a list.
"* ASSUMPTIONS / PRECONDITIONS:
"   The headless mode is activated by defining a List of choices (either
"   numerical return values of confirm(), or the choice text without the
"   shortcut key "&") in g:IngoLibrary_QueryChoices. Each invocation of this
"   function removes the first element from that List and returns it.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:what  Description of what is queried.
"   a:list  List of elements. Accelerators can be preset by prefixing with "&".
"   a:defaultIndex  Default element (which will be chosen via <Enter>); -1 for
"		    no default.
"* RETURN VALUES:
"   Index of the chosen element of a:list, or -1 if the query was aborted.
"******************************************************************************
    let l:defaultIndex = (a:0 ? a:1 : -1)
    let l:confirmList = ingo#query#confirm#AutoAccelerators(copy(a:list), -1)
    let l:accelerators = map(copy(l:confirmList), 'matchstr(v:val, "&\\zs.")')
    let l:list = ingo#query#fromlist#RenderList(l:confirmList, l:defaultIndex, '%d:')

    let l:renderedQuestion = printf('Select %s via [count] or (l)etter: %s ?', a:what, join(l:list, ', '))
    if ingo#compat#strdisplaywidth(l:renderedQuestion) + 3 > &columns
	call ingo#query#Question(printf('Select %s via [count] or (l)etter:', a:what))
	for l:listItem in ingo#query#fromlist#RenderList(l:confirmList, l:defaultIndex, '%3d: ')
	    echo l:listItem
	endfor
    else
	call ingo#query#Question(l:renderedQuestion)
    endif

    if exists('g:IngoLibrary_QueryChoices') && len(g:IngoLibrary_QueryChoices) > 0
	" Headless mode: Bypass actual confirm so that no user intervention is
	" necesary.
	let l:plainChoices = map(copy(a:list), 'ingo#query#StripAccellerator(v:val)')

	" Return predefined choice.
	let l:choice = remove(g:IngoLibrary_QueryChoices, 0)
	return (type(l:choice) == type(0) ?
	\   l:choice :
	\   (l:choice == '' ?
	\       0 :
	\       index(l:plainChoices, l:choice)
	\   )
	\)
    endif

    let l:maxNum = len(a:list)
    let l:choice = ingo#query#get#Char()
    let l:count = (empty(l:choice) ? -1 : index(l:accelerators, l:choice, 0, 1)) + 1
    if l:count == 0 && l:choice =~# '^\d$'
	let l:count = str2nr(l:choice)
	if l:maxNum > 10 * l:count
	    " Need to query more numbers to be able to address all choices.
	    echon ' ' . l:count

	    let l:leadingZeroCnt = (l:choice ==# '0')
	    while l:maxNum > 10 * l:count
		let l:char = nr2char(getchar())
		if l:char ==# "\<CR>"
		    break
		elseif l:char !~# '\d'
		    redraw | echo ''
		    return -1
		endif

		echon l:char
		if l:char ==# '0' && l:count == 0
		    let l:leadingZeroCnt += 1
		    if l:leadingZeroCnt >= len(l:maxNum)
			return -1
		    endif
		else
		    let l:count = 10 * l:count + str2nr(l:char)
		    if l:leadingZeroCnt + len(l:count) >= len(l:maxNum)
			break
		    endif
		endif
	    endwhile
	endif
    endif

    if l:count < 1 || l:count > l:maxNum
	redraw | echo ''
	return -1
    endif
    return l:count - 1
endfunction

function! ingo#query#fromlist#QueryAsText( what, list, ... )
"******************************************************************************
"* PURPOSE:
"   Query for one entry from a:list; elements can be selected by accelerator key
"   or the number of the element. Supports "headless mode", i.e. bypassing the
"   actual dialog so that no user intervention is necessary (in automated
"   tests).
"* SEE ALSO:
"   ingo#query#recall#Query() provides an alternative means to query one
"   (longer) entry from a list.
"* ASSUMPTIONS / PRECONDITIONS:
"   The headless mode is activated by defining a List of choices (either
"   numerical return values of confirm(), or the choice text without the
"   shortcut key "&") in g:IngoLibrary_QueryChoices. Each invocation of this
"   function removes the first element from that List and returns it.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:what  Description of what is queried.
"   a:list  List of elements. Accelerators can be preset by prefixing with "&".
"   a:defaultIndex  Default element (which will be chosen via <Enter>); -1 for
"		    no default.
"* RETURN VALUES:
"   Choice text without the shortcut key '&'. Empty string if the dialog was
"   aborted.
"******************************************************************************
    let l:index = call('ingo#query#fromlist#Query', [a:what, a:list] + a:000)
    return (l:index == -1 ? '' : a:list[l:index])
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo
" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
autoload/ingo/query/get.vim	[[[1
222
" ingo/query/get.vim: Functions for querying simple data types from the user.
"
" DEPENDENCIES:
"
" Copyright: (C) 2012-2018 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
let s:save_cpo = &cpo
set cpo&vim

function! ingo#query#get#Number( maxNum, ... )
"******************************************************************************
"* PURPOSE:
"   Query a number from the user. In contrast to |getchar()|, this allows for
"   multiple digits. In contrast to |input()|, the entry need not necessarily be
"   concluded with <Enter>, saving one keystroke.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   :echo's the typed number.
"* INPUTS:
"   a:maxNum    Maximum number to be input.
"   a:defaultNum    Number when the query is acknowledged with <Enter> without
"		    entering any digit. Default is -1.
"* RETURN VALUES:
"   Either the entered number, a:defaultNum when only <Enter> is pressed, or -1
"   when an invalid (i.e. non-digit) number was entered.
"******************************************************************************
    let l:nr = 0
    let l:leadingZeroCnt = 0
    while 1
	let l:char = nr2char(getchar())

	if l:char ==# "\<CR>"
	    return (l:nr == 0 ? (a:0 ? a:1 : -1) : l:nr)
	elseif l:char !~# '\d'
	    return -1
	endif
	echon l:char

	if l:char ==# '0' && l:nr == 0
	    let l:leadingZeroCnt += 1
	    if l:leadingZeroCnt >= len(a:maxNum)
		return 0
	    endif
	else
	    let l:nr = 10 * l:nr + str2nr(l:char)
	    if a:maxNum < 10 * l:nr || l:leadingZeroCnt + len(l:nr) >= len(a:maxNum)
		return l:nr
	    endif
	endif
    endwhile
endfunction

function! s:GetChar()
    " TODO: Handle digraphs via <C-K>.
    let l:char = getchar()
    if type(l:char) == type(0)
	let l:char = nr2char(l:char)
    endif
    return l:char
endfunction
function! ingo#query#get#Char( ... )
"******************************************************************************
"* PURPOSE:
"   Query a character from the user.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:options.isBeepOnInvalid   Flag whether to beep on invalid pattern (but not
"				when aborting with <Esc>). Default on.
"   a:options.validExpr         Pattern for valid characters. Aborting with
"				<Esc> is always possible, but if you add \e, it
"				will be returned as ^[.
"   a:options.invalidExpr       Pattern for invalid characters. Takes precedence
"				over a:options.validExpr.
"* RETURN VALUES:
"   Either the valid character, or an empty string when aborted or invalid
"   character.
"******************************************************************************
    let l:options = (a:0 ? a:1 : {})
    let l:isBeepOnInvalid = get(l:options, 'isBeepOnInvalid', 1)
    let l:validExpr = get(l:options, 'validExpr', '')
    let l:invalidExpr = get(l:options, 'invalidExpr', '')

    let l:char = s:GetChar()
    if l:char ==# "\<Esc>" && (empty(l:validExpr) || l:char !~ l:validExpr)
	return ''
    elseif (! empty(l:validExpr) && l:char !~ l:validExpr) ||
    \   (! empty(l:invalidExpr) && l:char =~ l:invalidExpr)
	if l:isBeepOnInvalid
	    execute "normal! \<C-\>\<C-n>\<Esc>" | " Beep.
	endif
	return ''
    endif

    return l:char
endfunction
function! ingo#query#get#ValidChar( ... )
"******************************************************************************
"* PURPOSE:
"   Query a character from the user until a valid one has been pressed (or
"   aborted with <Esc>).
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:options.isBeepOnInvalid   Flag whether to beep on invalid pattern (but not
"				when aborting with <Esc>). Default on.
"   a:options.validExpr         Pattern for valid characters. Aborting with
"				<Esc> is always possible, but if you add \e, it
"				will be returned as ^[.
"   a:options.invalidExpr       Pattern for invalid characters. Takes precedence
"				over a:options.validExpr.
"* RETURN VALUES:
"   Either the valid character, or an empty string when aborted.
"******************************************************************************
    let l:options = (a:0 ? a:1 : {})
    let l:isBeepOnInvalid = get(l:options, 'isBeepOnInvalid', 1)
    let l:validExpr = get(l:options, 'validExpr', '')
    let l:invalidExpr = get(l:options, 'invalidExpr', '')

    while 1
	let l:char = s:GetChar()

	if l:char ==# "\<Esc>" && (empty(l:validExpr) || l:char !~ l:validExpr)
	    return ''
	elseif (! empty(l:validExpr) && l:char !~ l:validExpr) ||
	\   (! empty(l:invalidExpr) && l:char =~ l:invalidExpr)
	    if l:isBeepOnInvalid
		execute "normal! \<C-\>\<C-n>\<Esc>" | " Beep.
	    endif
	else
	    break
	endif
    endwhile

    return l:char
endfunction

function! ingo#query#get#Register( errorRegister, ... )
"******************************************************************************
"* PURPOSE:
"   Query a register from the user.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:errorRegister     Register name to be returned when aborted or invalid
"			register. Defaults to the empty string. Use '\' to yield
"			an empty string (from getreg()) when passing the
"			function's results directly to getreg().
"   a:invalidRegisterExpr   Optional pattern for invalid registers.
"* RETURN VALUES:
"   Either the register, or an a:errorRegister when aborted or invalid register.
"******************************************************************************
    try
	let l:register = ingo#query#get#Char({'validExpr': ingo#register#All(), 'invalidExpr': (a:0 ? a:1 : '')})
	return (empty(l:register) ? a:errorRegister : l:register)
    catch /^Vim\%((\a\+)\)\=:E523:/ " E523: Not allowed here
	return a:errorRegister
    endtry
endfunction
function! ingo#query#get#WritableRegister( errorRegister, ... )
"******************************************************************************
"* PURPOSE:
"   Query a register that can be written to from the user.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:errorRegister     Register name to be returned when aborted or invalid
"			register. Defaults to the empty string. Use '\' to yield
"			an empty string (from getreg()) when passing the
"			function's results directly to getreg().
"   a:invalidRegisterExpr   Optional pattern for invalid registers.
"* RETURN VALUES:
"   Either the writable register, or an a:errorRegister when aborted or invalid
"   register.
"******************************************************************************
    try
	let l:register = ingo#query#get#Char({'validExpr': ingo#register#Writable(), 'invalidExpr': (a:0 ? a:1 : '')})
	return (empty(l:register) ? a:errorRegister : l:register)
    catch /^Vim\%((\a\+)\)\=:E523:/ " E523: Not allowed here
	return a:errorRegister
    endtry
endfunction

function! ingo#query#get#Mark( ... )
"******************************************************************************
"* PURPOSE:
"   Query a mark from the user.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:invalidMarkExpr   Optional pattern for invalid marks. Or pass 1 when you
"			want to use the mark for setting, and filter out all
"			read-only marks.
"* RETURN VALUES:
"   Either the mark, or empty string when aborted or invalid register.
"******************************************************************************
    try
	return ingo#query#get#Char({
	\   'validExpr': '[a-zA-Z0-9''`"[\]<>^.(){}]',
	\   'invalidExpr': (a:0 ? (a:1 is# 1 ? '[0-9^.(){}]' : a:1) : '')
	\})
    catch /^Vim\%((\a\+)\)\=:E523:/ " E523: Not allowed here
	return ''
    endtry
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo
" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
autoload/ingo/query/recall.vim	[[[1
57
" ingo/query/recall.vim: Functions to recall a value from a list.
"
" DEPENDENCIES:
"   - ingo/list.vim autoload script
"   - ingo/msg.vim autoload script
"   - ingo/query/get.vim autoload script
"
" Copyright: (C) 2017 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
"
" REVISION	DATE		REMARKS
"   1.029.001	10-Jan-2017	file creation

function! ingo#query#recall#Query( title, list, isReverse )
"******************************************************************************
"* PURPOSE:
"   Query one entry from a:list by number.
"* SEE ALSO:
"   ingo#query#fromlist#Query() provides an alternative means to query one entry
"   from a (longer) list.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:title Text describing the list elements; will be printed as a table
"	    header.
"   a:list  List of elements. Each element can also be a List of Strings (which
"	    are simply concatenated) or a List of [part, hlgroup] Pairs
"	    highlighted through ingo#msg#ColoredMsg().
"   a:isReverse Flag whether the first element from a:list comes last in the
"		table, which makes it faster to visually parse a long list of
"		MRU elements.
"* RETURN VALUES:
"   List index, or -2 if a:list is empty, or -1 if an invalid number was
"   chosen, or the query aborted via a non-numeric choice.
"******************************************************************************
    let l:len = len(a:list)
    if l:len == 0
	return -2
    endif

    echohl Title
    echo '      #  ' . a:title
    echohl None

    for l:i in (a:isReverse ? range(l:len - 1, 0, -1) : range(l:len))
	call call('ingo#msg#ColoredMsg', [printf('%7d  ', l:i + 1)] + ingo#list#Make(a:list[l:i]))
    endfor
    echo 'Type number (<Enter> cancels): '
    let l:choice = ingo#query#get#Number(l:len)
    return (l:choice < 1 || l:choice > l:len ? -1 : l:choice - 1)
endfunction

" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
autoload/ingo/query/substitute.vim	[[[1
48
" ingo/query/substitute.vim: Functions for confirming a command like :substitute//c.
"
" DEPENDENCIES:
"   - ingo/query.vim autoload script
"
" Copyright: (C) 2014-2016 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
"
" REVISION	DATE		REMARKS
"   1.025.002	27-Jan-2016	Refactoring: Factor out ingo#query#Question().
"   1.017.001	04-Mar-2014	file creation

function! s:Question( msg )
    call ingo#query#Question(a:msg . ' (y/n/a/q/l/^E/^Y)?')
endfunction
function! ingo#query#substitute#Get( msg )
"******************************************************************************
"* PURPOSE:
"   Query a response like |:s_c|, with choices of yes, no, last, quit, Ctrl-E,
"   Ctrl-Y. The latter two are handled transparently by this function.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   Moves the view on Ctrl-E / Ctrl-Y.
"* INPUTS:
"   a:msg   Message to be presented for acknowledging.
"* RETURN VALUES:
"   One of [ynlaq\e].
"******************************************************************************
    call s:Question(a:msg)

    while 1
	let l:choice = ingo#query#get#Char({'isBeepOnInvalid': 0, 'validExpr': "[ynl\<Esc>aq\<C-e>\<C-y>]"})
	if l:choice ==# "\<C-e>" || l:choice ==# "\<C-y>"
	    execute 'normal!' l:choice
	    redraw
	    call s:Question(a:msg)
	elseif l:choice ==# "\<Esc>"
	    return 'q'
	elseif ! empty(l:choice)
	    return l:choice
	endif
    endwhile
endfunction

" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
autoload/ingo/range.vim	[[[1
76
" ingo/range.vim: Functions for dealing with ranges and their contents.
"
" DEPENDENCIES:
"
" Copyright: (C) 2012-2018 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>

function! ingo#range#Get( range )
"******************************************************************************
"* PURPOSE:
"   Retrieve the contents of the passed range without clobbering any register.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:range A valid |:range|; when empty, the current line is used.
"* RETURN VALUES:
"   Text of the range on lines. Each line ends with a newline character.
"   Throws Vim error "E486: Pattern not found" when the range does not match.
"******************************************************************************
    let l:save_clipboard = &clipboard
    set clipboard= " Avoid clobbering the selection and clipboard registers.
    let l:save_reg = getreg('"')
    let l:save_regmode = getregtype('"')
    try
	silent execute a:range . 'yank'
	let l:contents = @"
    finally
	call setreg('"', l:save_reg, l:save_regmode)
	let &clipboard = l:save_clipboard
    endtry

    return l:contents
endfunction

function! ingo#range#NetStart( ... )
"******************************************************************************
"* PURPOSE:
"   Vim accounts for closed folds and adapts <line1>,<line2> when passed a
"   :{from},{to} range, but not with a single :{lnum} range! As long as the
"   range is forwarded to Ex commands, that's fine. But if you do line
"   arithmethic or use low-level functions like |getline()|, you need to convert
"   via this function.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:lnum  Optional line number; defaults to the current one.
"* RETURN VALUES:
"   Start line number of the fold covering the line, or the current / passed
"   line number itself.
"******************************************************************************
    let l:lnum = (a:0 ? a:1 : line('.'))
    return foldclosed(l:lnum) == -1 ? l:lnum : foldclosed(l:lnum)
endfunction
function! ingo#range#NetEnd( ... )
    let l:lnum = (a:0 ? a:1 : line('.'))
    return foldclosedend(l:lnum) == -1 ? l:lnum : foldclosedend(l:lnum)
endfunction

function! ingo#range#IsEntireBuffer( startLnum, endLnum )
    return (a:startLnum <= 1 && a:endLnum == line('$'))
endfunction

function! ingo#range#IsOutside( lnum, startLnum, endLnum )
    return (a:lnum < a:startLnum || a:lnum > a:endLnum)
endfunction
function! ingo#range#IsInside( lnum, startLnum, endLnum )
    return ! ingo#range#IsOutside(a:lnum, a:startLnum, a:endLnum)
endfunction

" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
autoload/ingo/range/borders.vim	[[[1
43
" ingo/range/borders.vim: Functions for determining ranges at the borders of the buffer.
"
" DEPENDENCIES:
"
" Copyright: (C) 2016 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
"
" REVISION	DATE		REMARKS
"	001	13-Jul-2016	file creation

function! ingo#range#borders#StartAndEndRange( startOffset, endOffset )
"******************************************************************************
"* PURPOSE:
"   Determine non-overlapping range(s) for a:startOffset lines from the start of
"   the current buffer, and a:endOffset lines from the end of the current
"   buffer.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:startOffset Number of lines to get from the start.
"   a:endOffset Number of lines to get from the end.
"* RETURN VALUES:
"   List of ranges, in the form ['1,3', '8,$']
"******************************************************************************
    let l:ranges = []
    let l:lastStartLnum = min([line('$'), a:startOffset])
    if a:startOffset > 0
	call add(l:ranges, '1,' . l:lastStartLnum)
    endif

    let l:firstEndLnum = max([1, line('$') - a:endOffset + 1])
    let l:firstEndLnum = max([l:lastStartLnum + 1, l:firstEndLnum])
    if l:firstEndLnum <= line('$')
	call add(l:ranges, l:firstEndLnum . ',$')
    endif
    return l:ranges
endfunction

" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
autoload/ingo/range/invert.vim	[[[1
50
" ingo/range/invert.vim: Functions for inverting ranges.
"
" DEPENDENCIES:
"
" Copyright: (C) 2016 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
"
" REVISION	DATE		REMARKS
"   1.029.001	21-Dec-2016	file creation

function! ingo#range#invert#Invert( startLnum, endLnum, ranges )
"******************************************************************************
"* PURPOSE:
"   Invert the ranges in a:ranges. Lines within a:startLnum, a:endLnum that were
"   contained in the ranges will be out, and all other lines will be in.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:startLnum First line number to be considered.
"   a:endLnum   Last line number to be considered.
"   a:ranges    List of [start, end] pairs in ascending, non-overlapping order.
"		Invoke ingo#range#merge#Merge() first if necessary.
"* RETURN VALUES:
"   List of [start, end] pairs in ascending order.
"******************************************************************************
    let l:result = []

    let l:lastIncludedLnum = a:startLnum - 1
    for [l:fromLnum, l:toLnum] in a:ranges
	call s:Add(l:result, a:startLnum, a:endLnum, l:lastIncludedLnum + 1, l:fromLnum - 1)
	let l:lastIncludedLnum = l:toLnum
    endfor
    call s:Add(l:result, a:startLnum, a:endLnum, l:lastIncludedLnum + 1, a:endLnum)
    return l:result
endfunction
function! s:Add( target, startLnum, endLnum, fromLnum, toLnum )
    let l:fromLnum = max([a:startLnum, a:fromLnum])
    let l:toLnum = min([a:endLnum, a:toLnum])

    if l:fromLnum > l:toLnum
	return
    endif
    call add(a:target, [l:fromLnum, l:toLnum])
endfunction

" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
autoload/ingo/range/lines.vim	[[[1
134
" ingo/range/Lines.vim: Functions for retrieving line numbers of ranges.
"
" DEPENDENCIES:
"   - ingo/cmdsargs/pattern.vim autoload script
"   - ingo/range.vim autoload script
"
" Copyright: (C) 2014-2016 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
"
" REVISION	DATE		REMARKS
"   1.029.005	23-Dec-2016	ingo#range#lines#Get(): If the range is a
"				backwards-looking ?{pattern}?, we need to
"				attempt the match on any line with :global/^/...
"				Else, the border behavior is inconsistent:
"				ranges that extend the passed range at the
"				bottom are (partially) included, but ranges that
"				extend at the front would not be.
"   1.029.004	07-Dec-2016	ingo#range#lines#Get(): A single
"				(a:isGetAllRanges = 0) /.../ range already
"				clobbers the last search pattern. Save and
"				restore if necessary, and base
"				didClobberSearchHistory on that check.
"				ingo#range#lines#Get(): Drop the ^ anchor for
"				the range check to also detect /.../ as the
"				end of the range.
"   1.023.003	26-Dec-2014	ENH: Add a:isGetAllRanges optional argument to
"				ingo#range#lines#Get().
"   1.022.002	23-Sep-2014	ingo#range#lines#Get() needs to consider and
"				temporarily disable closed folds when resolving
"				/{pattern}/ ranges.
"   1.020.001	10-Jun-2014	file creation from
"				autoload/PatternsOnText/Ranges.vim

function! s:RecordLine( records, startLnum, endLnum )
    let l:lnum = line('.')
    if l:lnum < a:startLnum || l:lnum > a:endLnum
	let s:didRecord = 0
	return
    endif

    let a:records[l:lnum] = 1
    let s:didRecord = 1
endfunction
function! s:RecordLines( records, startLines, endLines, startLnum, endLnum ) range
    execute printf('%d,%dcall s:RecordLine(a:records, a:startLnum, a:endLnum)', a:firstline, a:lastline)
    if s:didRecord
	call add(a:startLines, max([a:firstline, a:startLnum]))
	call add(a:endLines, min([a:lastline, a:endLnum]))
    endif
endfunction
function! ingo#range#lines#Get( startLnum, endLnum, range, ... )
"******************************************************************************
"* PURPOSE:
"   Determine the line numbers and start and end lines of a:range that fall
"   inside a:startLnum and a:endLnum. Closed folds do not affect the recorded
"   lines; only the actually matched lines are considered.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   Changes the cursor position in the buffer (to the beginning of the last line
"   within the range).
"* INPUTS:
"   a:startLnum First line number to be considered.
"   a:endLnum   Last line number to be considered.
"   a:range     Range in any format supported by Vim, e.g. 'a,'b or
"		/^fun/,/^endfun/
"   a:isGetAllRanges    Optional flag whether (for pattern ranges like /.../),
"			all (vs. only the next matching) ranges are determined.
"			Defaults to 1; pass 0 to only get the next one.
"* RETURN VALUES:
"   [recordedLnums, startLnums, endLnums, didClobberSearchHistory]
"   recordedLnums   Dictionary with all line numbers that fall into the range(s)
"		    as keys.
"   startLnums      List of line numbers where a range starts. Can contain
"		    multiple elements if a /pattern/ range is used.
"   endLnums        List of line numbers where a range ends.
"   didClobberSearchHistory Flag whether a command was used that has added a
"			    temporary pattern to the search history. If true,
"			    call histdel('search', -1) at the end of the client
"			    function once.
"******************************************************************************
    let l:isGetAllRanges = (! a:0 || a:1)
    let [l:startLnum, l:endLnum] = [ingo#range#NetStart(a:startLnum), ingo#range#NetEnd(a:endLnum)]
    let l:recordedLines = {}
    let l:startLines = []
    let l:endLines = []
    let l:save_search = @/
    let l:didClobberSearchHistory = 0

    if l:isGetAllRanges && a:range =~# '[/?]'
	" For patterns, we need :global to find _all_ (not just the first)
	" matching ranges. For that, folds must be open / disabled. And because
	" of that, the actual ranges must be determined first.
	let l:save_foldenable = &l:foldenable
	setlocal nofoldenable

	let l:searchRange = a:range
	if ingo#cmdargs#pattern#RawParse(a:range, [''], '\s*[,;]\s*\S.*')[0] ==# '?'
	    " If this is a simple /{pattern}/, we can just match that with
	    " :global. But for actual ranges, these should extend both upwards
	    " (?foo?,/bar/) as well as downwards (/foo/,/bar/). To handle the
	    " former, we must make :global attempt a match at any line.
	    let l:searchRange = '/^/' . a:range
	endif

	try
	    execute printf('silent! %d,%dglobal %s call <SID>RecordLines(l:recordedLines, l:startLines, l:endLines, %d, %d)',
	    \  l:startLnum, l:endLnum,
	    \  l:searchRange,
	    \  l:startLnum, l:endLnum
	    \)
	finally
	    let &l:foldenable = l:save_foldenable
	endtry
    else
	" For line number, marks, etc., we can just record them (limited to
	" those that fall into the command's range).
	execute printf('silent! %s call <SID>RecordLines(l:recordedLines, l:startLines, l:endLines, %d, %d)',
	\  a:range,
	\  l:startLnum, l:endLnum
	\)
    endif

    if @/ !=# l:save_search
	let @/ = l:save_search
	let l:didClobberSearchHistory = 1
    endif

    return [l:recordedLines, l:startLines, l:endLines, l:didClobberSearchHistory]
endfunction

" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
autoload/ingo/range/merge.vim	[[[1
77
" ingo/range/merge.vim: Functions for merging ranges.
"
" DEPENDENCIES:
"   - ingo/collections.vim autoload script
"
" Copyright: (C) 2015-2016 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
"
" REVISION	DATE		REMARKS
"   1.029.002	23-Dec-2016	Extract ingo#range#merge#FromLnums() from
"				ingo#range#merge#Merge().
"   1.023.001	22-Jan-2015	file creation
let s:save_cpo = &cpo
set cpo&vim

function! ingo#range#merge#Merge( ranges )
"******************************************************************************
"* PURPOSE:
"   Merge adjacent and overlapping ranges.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:ranges    List of [start, end] pairs.
"* RETURN VALUES:
"   List of joined, non-overlapping [start, end] pairs in ascending order.
"******************************************************************************
    let l:dict = {}
    for [l:start, l:end] in a:ranges
	for l:i in range(l:start, l:end)
	    let l:dict[l:i] = 1
	endfor
    endfor

    return ingo#range#merge#FromLnums(l:dict)
endfunction
function! ingo#range#merge#FromLnums( lnumsCollection )
"******************************************************************************
"* PURPOSE:
"   Turn the collection of line numbers into a List of ranges.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:lnumsCollection   Either Dictionary where each key represens a line
"			number, or List (not necessarily unique or sorted) of
"			line numbers.
"* RETURN VALUES:
"   List of joined, non-overlapping [start, end] pairs in ascending order.
"******************************************************************************
    let l:lnums = (type(a:lnumsCollection) == type({}) ?
    \   sort(keys(a:lnumsCollection), 'ingo#collections#numsort') :
    \   ingo#collections#UniqueSorted(sort(a:lnumsCollection, 'ingo#collections#numsort'))
    \)

    let l:result = []
    while ! empty(l:lnums)
	let l:start = str2nr(remove(l:lnums, 0))
	let l:candidate = l:start + 1
	while ! empty(l:lnums) && str2nr(l:lnums[0]) == l:candidate
	    call remove(l:lnums, 0)
	    let l:candidate += 1
	endwhile

	call add(l:result, [l:start, l:candidate - 1])
    endwhile

    return l:result
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo
" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
autoload/ingo/record.vim	[[[1
57
" ingo/record.vim: Functions for recording the current position / editing state.
"
" DEPENDENCIES:
"
" Copyright: (C) 2014-2016 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
"
" REVISION	DATE		REMARKS
"   1.025.002	23-Mar-2016	Add optional a:characterOffset to
"				ingo#record#PositionAndLocation().
"   1.020.001	30-May-2014	file creation

function! ingo#record#Position( isRecordChange )
    " The position record consists of the current cursor position, the buffer
    " number and optionally its current change state. When this position record
    " is assigned to a window-local variable, it is also linked to the current
    " window and tab page.
    return getpos('.') + [bufnr('')] + (a:isRecordChange ? [b:changedtick] : [])
endfunction
function! ingo#record#PositionAndLocation( isRecordChange, ... )
"******************************************************************************
"* PURPOSE:
"   The position record consists of the current cursor position, the buffer,
"   window and tab page number and optionally the buffer's current change state.
"   As soon as you make an edit, move to another buffer or even the same buffer
"   in another tab page or window (or as a minor side effect just close a window
"   above the current), the position changes.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:isRecordChange    Flag whether b:changedtick should be part of the record.
"   a:characterOffset   Offset in characters from the current cursor position.
"			Can be -1, 0, or 1.
"* RETURN VALUES:
"   List of recorded values (to be compared with later results from this
"   function).
"******************************************************************************
    let l:pos = getpos('.')

    if a:0
	if a:1 == 1
	    let l:pos[2] += len(ingo#text#GetChar(l:pos[1:2]))
	elseif a:1 == -1
	    let l:pos[2] -= len(ingo#text#GetCharBefore(l:pos[1:2]))
	elseif a:1 != 0
	    throw 'ASSERT: Offsets other than -1, 0, 1 not supported yet'
	endif
    endif

    return l:pos + [bufnr(''), winnr(), tabpagenr()] + (a:isRecordChange ? [b:changedtick] : [])
endfunction

" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
autoload/ingo/regexp.vim	[[[1
255
" ingo/regexp.vim: Functions around handling regular expressions.
"
" DEPENDENCIES:
"
" Copyright: (C) 2010-2019 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>

function! ingo#regexp#GetSpecialCharacters()
    " The set of characters that must be escaped depends on the 'magic' setting.
    return ['^$', '^$.*[~'][&magic]
endfunction
function! ingo#regexp#EscapeLiteralText( text, additionalEscapeCharacters )
"*******************************************************************************
"* PURPOSE:
"   Escape the literal a:text for use in search command.
"   The ignorant approach is to use atom \V, which sets the following pattern to
"   "very nomagic", i.e. only the backslash has special meaning. For \V, \ still
"   must be escaped. But that's not how the built-in star command works.
"   Instead, all special search characters must be escaped.
"
"   This works well even with <Tab> (no need to change ^I into \t), but not with
"   a line break, which must be changed from ^M to \n.
"
"   We also may need to escape additional characters like '/' or '?', because
"   that's done in a search via '*', '/' or '?', too. As the character depends
"   on the search direction ('/' vs. '?'), this is passed in as
"   a:additionalEscapeCharacters.
"
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:text  Literal text.
"   a:additionalEscapeCharacters    For use in the / command, add '/', for the
"				    backward search command ?, add '?'. For
"				    assignment to @/, always add '/', regardless
"				    of the search direction; this is how Vim
"				    escapes it, too. For use in search(), pass
"				    nothing.
"* RETURN VALUES:
"   Regular expression for matching a:text.
"*******************************************************************************
    return substitute(escape(a:text, '\' . ingo#regexp#GetSpecialCharacters() . a:additionalEscapeCharacters), "\n", '\\n', 'g')
endfunction

function! ingo#regexp#MakeWholeWordSearch( text, ... )
"******************************************************************************
"* PURPOSE:
"   Generate a pattern that searches only for whole words of a:text, but only if
"   a:text actually starts / ends with keyword characters (so that non-word
"   a:text still matches (anywhere)).
"   The star command only creates a \<whole word\> search pattern if the <cword>
"   actually only consists of keyword characters. Since
"   ingo#regexp#FromLiteralText() could handle a superset (e.g. also
"   "foo...bar"), just ensure that the keyword boundaries can be enforced at
"   either side, to avoid enclosing a non-keyword side and making a match
"   impossible with it (e.g. "\<..bar\>").
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:text  Text / pattern to be searched for. Note that this isn't escaped in any form;
"	    you probably want to escape backslashes beforehand and use \V "very
"	    nomagic" on the result.
"   a:pattern   If passed, this is adapted according to what a:text is about.
"		Useful if the pattern has already been so warped (e.g. by
"		enclosing in /\(...\|...\)/) that word boundary detection on the
"		original text wouldn't work.
"* RETURN VALUES:
"   a:text / a:pattern, with additional \< / \> atoms if applicable.
"******************************************************************************
    let l:pattern = (a:0 ? a:1 : a:text)
    if a:text =~# '^\k'
	let l:pattern = '\<' . l:pattern
    endif
    if a:text =~# '\k$'
	let l:pattern .= '\>'
    endif
    return l:pattern
endfunction
function! ingo#regexp#MakeStartWordSearch( text, ... )
    let l:pattern = (a:0 ? a:1 : a:text)
    if a:text =~# '^\k'
	let l:pattern = '\<' . l:pattern
    endif
    return l:pattern
endfunction
function! ingo#regexp#MakeEndWordSearch( text, ... )
    let l:pattern = (a:0 ? a:1 : a:text)
    if a:text =~# '\k$'
	let l:pattern .= '\>'
    endif
    return l:pattern
endfunction
function! ingo#regexp#MakeWholeWORDSearch( text, ... )
"******************************************************************************
"* PURPOSE:
"   Generate a pattern that searches only for whole WORDs of a:text, but only if
"   a:text actually starts / ends with non-whitespace characters.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:text  Text / pattern to be searched for. Note that this isn't escaped in any form;
"	    you probably want to escape backslashes beforehand and use \V "very
"	    nomagic" on the result.
"   a:pattern   If passed, this is adapted according to what a:text is about.
"		Useful if the pattern has already been so warped (e.g. by
"		enclosing in /\(...\|...\)/) that word boundary detection on the
"		original text wouldn't work.
"* RETURN VALUES:
"   a:text / a:pattern, with additional atoms if applicable.
"******************************************************************************
    let l:pattern = (a:0 ? a:1 : a:text)
    if a:text =~# '^\S'
	let l:pattern = '\%(^\|\s\)\@<=' . l:pattern
    endif
    if a:text =~# '\S$'
	let l:pattern .= '\%(\s\|$\)\@='
    endif
    return l:pattern
endfunction
function! ingo#regexp#MakeWholeWordOrWORDSearch( text, ... )
"******************************************************************************
"* PURPOSE:
"   Generate a pattern that searches only for whole words or whole WORDs of
"   a:text, depending on whether a:text actually starts / ends with
"   keyword or non-whitespace (not necessarily the same type at begin and end)
"   characters.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:text  Text / pattern to be searched for. Note that this isn't escaped in any form;
"	    you probably want to escape backslashes beforehand and use \V "very
"	    nomagic" on the result.
"   a:pattern   If passed, this is adapted according to what a:text is about.
"		Useful if the pattern has already been so warped (e.g. by
"		enclosing in /\(...\|...\)/) that word boundary detection on the
"		original text wouldn't work.
"* RETURN VALUES:
"   a:text / a:pattern, with additional atoms if applicable.
"******************************************************************************
    let l:pattern = (a:0 ? a:1 : a:text)
    if a:text =~# '^\k'
	let l:pattern = '\<' . l:pattern
    elseif a:text =~# '^\S'
	let l:pattern = '\%(^\|\s\)\@<=' . l:pattern
    endif
    if a:text =~# '\k$'
	let l:pattern .= '\>'
    elseif a:text =~# '\S$'
	let l:pattern .= '\%(\s\|$\)\@='
    endif
    return l:pattern
endfunction

function! ingo#regexp#FromLiteralText( text, isWholeWordSearch, additionalEscapeCharacters )
"*******************************************************************************
"* PURPOSE:
"   Convert literal a:text into a regular expression, similar to what the
"   built-in * command does.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:text  Literal text.
"   a:isWholeWordSearch	Flag whether only whole words (* command) or any
"			contained text (g* command) should match.
"			Note: If you do not need the a:isWholeWordSearch flag,
"			you can also use the ingo#regexp#EscapeLiteralText()
"			function.
"   a:additionalEscapeCharacters    For use in the / command, add '/', for the
"				    backward search command ?, add '?'. For
"				    assignment to @/, always add '/', regardless
"				    of the search direction; this is how Vim
"				    escapes it, too. For use in search(), pass
"				    nothing.
"* RETURN VALUES:
"   Regular expression for matching a:text.
"*******************************************************************************
    if a:isWholeWordSearch
	return ingo#regexp#MakeWholeWordSearch(a:text, ingo#regexp#EscapeLiteralText(a:text, a:additionalEscapeCharacters))
    else
	return ingo#regexp#EscapeLiteralText(a:text, a:additionalEscapeCharacters)
    endif
endfunction

function! ingo#regexp#FromWildcard( wildcardExpr, additionalEscapeCharacters )
"*******************************************************************************
"* PURPOSE:
"   Convert a shell-like a:wildcardExpr which may contain wildcards ? and * into
"   an (unanchored!) regular expression.
"
"   The ingo#regexp#fromwildcard#Convert() supports the full range of wildcards
"   and considers the path separators on different platforms. An anchored
"   version is ingo#regexp#fromwildcard#AnchoredToPathBoundaries().
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:wildcardExpr  Text containing file wildcards.
"   a:additionalEscapeCharacters    For use in the / command, add '/', for the
"				    backward search command ?, add '?'. For
"				    assignment to @/, always add '/', regardless
"				    of the search direction; this is how Vim
"				    escapes it, too. For use in search(), pass
"				    nothing.
"* RETURN VALUES:
"   Regular expression for matching a:wildcardExpr.
"*******************************************************************************
    let l:expr = '\V' . escape(a:wildcardExpr, '\' . a:additionalEscapeCharacters)

    " From the wildcards; emulate ?, * and **, but not [xyz].
    let l:expr = substitute(l:expr, '?', '\\.', 'g')
    let l:expr = substitute(l:expr, '\*\*', '\\.\\*', 'g')
    let l:expr = substitute(l:expr, '\*', '\\[^/\\\\]\\*', 'g')
    return l:expr
endfunction

function! ingo#regexp#IsValid( expr, ... )
"******************************************************************************
"* PURPOSE:
"   Test whether a:expr is a valid regular expression.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   In case of an invalid regular expression, makes Vim's error accessible via
"   ingo#err#Get(...). Any desired custom a:context can be passed to this
"   function as the optional argument.
"* INPUTS:
"   a:expr  Regular expression to test for correctness.
"   a:context	Optional context for ingo#err#Get().
"* RETURN VALUES:
"   1 if Vim's regular expression parser accepts a:expr, 0 if an error is
"   raised.
"******************************************************************************
    try
	call match('', a:expr)
	return 1
    catch /^Vim\%((\a\+)\)\=:/
	call call('ingo#err#SetVimException', a:000)
	return 0
    endtry
endfunction

" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
autoload/ingo/regexp/build.vim	[[[1
65
" ingo/regexp/build.vim: Functions to build regular expressions.
"
" DEPENDENCIES:
"
" Copyright: (C) 2016-2017 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>

function! ingo#regexp#build#Prepend( target, fragment )
"******************************************************************************
"* PURPOSE:
"   Add a:fragment at the beginning of a:target, considering the anchor ^.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:target    Regular expression to manipulate.
"   a:fragment  Regular expression fragment to insert.
"* RETURN VALUES:
"   New regexp.
"******************************************************************************
    return substitute(a:target, '^\%(\\%\?(\)*^\?', '&' . escape(a:fragment, '\&'), '')
endfunction

function! ingo#regexp#build#Append( target, fragment )
"******************************************************************************
"* PURPOSE:
"   Add a:fragment at the end of a:target, considering the anchor $.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:target    Regular expression to manipulate.
"   a:fragment  Regular expression fragment to insert.
"* RETURN VALUES:
"   New regexp.
"******************************************************************************
    return substitute(a:target, '$\?\%(\\)\)*$', escape(a:fragment, '\&') . '&', '')
endfunction

function! ingo#regexp#build#UnderCursor( pattern )
"******************************************************************************
"* PURPOSE:
"   Create a regular expression that only matches a:pattern when the cursor is
"   (somewhere) on the match. Stuff excluded by \zs / \ze still counts a match.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:pattern   Regular expression.
"* RETURN VALUES:
"   Augmented a:pattern that only matches when the cursor is on the match.
"******************************************************************************
    " Positive lookahead at the front to ensure that the cursor is at the start
    " of a:pattern or after that.
    " Positive lookbehind at the back to ensure that the cursor is before (not
    " at, that would already be one behind) the match.
    return '\%(.\{-}\%#\)\@=\%(' . a:pattern . '\m\)\%(\%#.\{-1,}\)\@<='
endfunction

" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
autoload/ingo/regexp/capture.vim	[[[1
48
" ingo/regexp/capture.vim: Functions to work with capture groups.
"
" DEPENDENCIES:
"   - ingo/subst.vim autoload script
"
" Copyright: (C) 2018 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>

function! ingo#regexp#capture#MakeNonCapturing( pattern, ... )
"******************************************************************************
"* PURPOSE:
"   Convert all / some capturing groups in a:pattern into non-capturing groups.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:pattern   Regular expression.
"   a:indices   Optional List of 0-based indices of matches that will be
"               converted. If omitted or String "g", all matches will be
"               converted.
"* RETURN VALUES:
"   Converted regular expression without any capturing groups.
"******************************************************************************
    return ingo#subst#Indexed(a:pattern, '\%(\%(^\|[^\\]\)\%(\\\\\)*\\\)\@<!\\(', '\\%(', (a:0 ? a:1 : 'g'))
endfunction
function! ingo#regexp#capture#MakeCapturing( pattern, ... )
"******************************************************************************
"* PURPOSE:
"   Convert all / some non-capturing groups in a:pattern into capturing groups.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:pattern   Regular expression.
"   a:indices   Optional List of 0-based indices of matches that will be
"               converted. If omitted or String "g", all matches will be
"               converted.
"* RETURN VALUES:
"   Converted regular expression without any non-capturing groups.
"******************************************************************************
    return ingo#subst#Indexed(a:pattern, '\%(\%(^\|[^\\]\)\%(\\\\\)*\\\)\@<!\\%(', '\\(', (a:0 ? a:1 : 'g'))
endfunction

" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
autoload/ingo/regexp/comments.vim	[[[1
75
" ingo/regexp/comments.vim: Functions that converts 'comments' to regular expressions.
"
" DEPENDENCIES:
"   - ingo/option.vim autoload script
"   - IndentCommentPrefix.vim plugin (optional integration)
"
" Copyright: (C) 2013-2017 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
"
" REVISION	DATE		REMARKS
"   1.030.004	27-Jan-2017	Add
"				ingo#regexp#comments#GetFlexibleWhitespaceAndCommentPrefixPattern().
"   1.020.003	03-Jun-2014	Use ingo#option#Split().
"   1.013.002	12-Sep-2013	Avoid using \ze in
"				ingo#regexp#comments#CommentToExpression(). It
"				may be used in a larger expression that still
"				wants to match after the prefix.
"   1.009.001	18-Jun-2013	file creation from
"				AdvancedJoiners/CommentJoin.vim

function! ingo#regexp#comments#CommentToExpression( comment )
    let [l:flags, l:comment] = matchlist(a:comment, '\([^:]*\):\(.*\)')[1:2]

    " Mask backslash for "very nomagic" pattern.
    let l:comment = escape(l:comment, '\')

    " Observe when a blank is required after the comment string, but do not
    " include it in the match, so that it is preserved during the join.
    " Illustration: With :setlocal comments=b:#,:>
    " # This is				>This is
    " # text.				> specta
    " Will be joined to			>cular.
    " # This is text.			Will be joined to
    "					>This is spectacular.
    return (l:flags =~# 'b' ? l:comment . '\%(\s\|\$\)\@=': l:comment)
endfunction
function! ingo#regexp#comments#FromSetting()
    if empty(&l:comments)
	" For this buffer, no comment markers are defined. Use any non-word
	" non-whitespace sequence as a generalization.
	let l:commentExpressions = ['\%(\W\&\S\)\+']
    else
	" Convert each comment marker of the 'comments' setting into a regular
	" expression.
	let l:commentExpressions = map(ingo#option#Split(&l:comments), 'ingo#regexp#comments#CommentToExpression(v:val)')
    endif

    " Integration with IndentCommentPrefix.vim plugin.
    let l:commentExpressions += map(copy(ingo#plugin#setting#GetBufferLocal('IndentCommentPrefix_Whitelist', [])), 'escape(v:val, ''\\'')')

    return l:commentExpressions
endfunction

function! ingo#regexp#comments#GetFlexibleWhitespaceAndCommentPrefixPattern( isAllowEmpty )
"******************************************************************************
"* PURPOSE:
"   Obtain a regular expression that matches any amount of whitespace (with
"   a:isAllowEmpty also none at all) and optionally any of the currently valid
"   comment prefixes in between.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:isAllowEmpty  Flag whether to allow a zero-length match of nothing at all.
"* RETURN VALUES:
"   Regular expression.
"******************************************************************************
    let l:commentPattern = '\%(' . join(ingo#regexp#comments#FromSetting(), '\|') . '\)'
    return '\_s' . (a:isAllowEmpty ? '*' : '\+') . l:commentPattern . '\?\_s*'
endfunction

" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
autoload/ingo/regexp/collection.vim	[[[1
115
" ingo/regexp/collection.vim: Functions around handling collections in regular expressions.
"
" DEPENDENCIES:
"
" Copyright: (C) 2016-2019 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
let s:save_cpo = &cpo
set cpo&vim

function! ingo#regexp#collection#Expr( ... )
"******************************************************************************
"* PURPOSE:
"   Returns a regular expression that matches any collection atom.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   The exact pattern can be influenced by the following options:
"   a:option.isBarePattern          Flag whether to return a bare pattern that
"                                   does not make any assertions on what's
"                                   before the [. This overrides the following
"                                   options. Default false.
"   a:option.isIncludeEolVariant    Flag whether to include the /\_[]/ variant as
"                                   well. Default true.
"   a:option.isMagic                Flag whether 'magic' is set, and [] is used
"                                   instead of \[]. Default true.
"   a:option.isCapture              Flag whether to capture the stuff inside the
"                                   collection. Default false.
"* RETURN VALUES:
"   Regular expression.
"******************************************************************************
    let l:options = (a:0 ? a:1 : {})
    let l:isBarePattern = get(l:options, 'isBarePattern', 0)
    let l:isIncludeEolVariant = get(l:options, 'isIncludeEolVariant', 1)
    let l:isMagic = get(l:options, 'isMagic', 1)
    let l:isCapture = get(l:options, 'isCapture', 0)
    let [l:capturePrefix, l:captureSuffix] = (l:isCapture ? ['\(', '\)'] : ['', ''])

    let l:prefixExpr = (l:isBarePattern ?
    \   '' :
    \   '\%(\%(^\|[^\\]\)\%(\\\\\)*\\%\?\)\@<!' . (l:isMagic ?
    \       (l:isIncludeEolVariant ? '\%(\\_\)\?' : '') :
    \       (l:isIncludeEolVariant ? '\\_\?' : '\\')
    \   )
    \)

    return l:prefixExpr . '\[' . l:capturePrefix . '\%(\]$\)\@!\]\?\%(\[:\a\+:\]\|\[=.\{-}=\]\|\[\..\.\]\|[^\]]\)*\%(\%(^\|[^\\]\)\%(\\\\\)*\\\)\@<!' . l:captureSuffix . '\]'
endfunction

function! ingo#regexp#collection#GetSpecialCharacters()
    return '[]-^\'
endfunction

function! ingo#regexp#collection#EscapeLiteralCharacters( text )
    " XXX: If we escape [ as \[, all backslashes will be matched, too.
    " Instead, we have to place [ last in the collection: [abc[].
    if a:text =~# '\['
	return escape(substitute(a:text, '\[', '', 'g'), ingo#regexp#collection#GetSpecialCharacters()) . '['
    else
	return escape(a:text, ingo#regexp#collection#GetSpecialCharacters())
    endif
endfunction

function! ingo#regexp#collection#LiteralToRegexp( text, ... )
    let l:isInvert = (a:0 && a:1)
    return '[' . (l:isInvert ? '^' : '') . ingo#regexp#collection#EscapeLiteralCharacters(a:text) . ']'
endfunction

function! ingo#regexp#collection#ToBranches( pattern )
"******************************************************************************
"* PURPOSE:
"   Convert each collection in a:pattern into an equivalent group of alternative
"   branches (where possible; i.e. for single characters). For example:
"   /[abc[:digit:]]/ to /\%(a\|b\|c\|[[:digit:]]\)/. Does not support negative
"   collections /[^...]/. Things that cannot be (easily) represented is kept as
"   smaller collections in a branch, e.g. /[a-fxyz]/ to
"   /\%([a-f]\|x\|y\|z\)/.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:pattern   regular expression, usually with collection(s) in them
"* RETURN VALUES:
"   Modified a:pattern
"******************************************************************************
    return substitute(a:pattern, ingo#regexp#collection#Expr(), '\=s:CollectionToBranches(submatch(0))', 'g')
endfunction
function! s:CollectionToBranches( collection )
    if a:collection =~# '^\[\^'
	return a:collection " Negative collections not yet supported.
    endif

    let l:branches = map(
    \   ingo#collections#SplitIntoMatches(matchstr(a:collection, '^\[\zs.*\ze\]$'), '[^-]-[^-]\|\[:\a\+:\]\|\[=.\{-}]\]\|\[\..\.\]\|\\[etrbn]\|\\d\d\+\|\\[uU]\x\{4,8\}\|.'),
    \   's:CollectionElementToPattern(v:val)'
    \)
    return '\%(' . join(l:branches, '\|') . '\)'
endfunction
function! s:CollectionElementToPattern( collectionElement )
    if a:collectionElement =~# '^\%(\\[etrbn]\|.\)$'
	" We can return (escaped) single characters as-is.
	return a:collectionElement
    else
	" For the rest, enclose in a (smaller) collection on its own.
	return '[' . a:collectionElement . ']'
    endif
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo
" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
autoload/ingo/regexp/deconstruct.vim	[[[1
275
" ingo/regexp/deconstruct.vim: Functions for taking apart regular expressions.
"
" DEPENDENCIES:
"
" Copyright: (C) 2018-2019 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
let s:save_cpo = &cpo
set cpo&vim

function! ingo#regexp#deconstruct#RemovePositionAtoms( pattern )
"******************************************************************************
"* PURPOSE:
"   Remove atoms that assert a certain position of the pattern (like ^, $, \<,
"   \%l) from a:pattern.
"* ASSUMPTIONS / PRECONDITIONS:
"   Does not consider "very magic" (/\v)-style syntax. If you may have this,
"   convert via ingo#regexp#magic#Normalize() first.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:pattern   regular expression
"* RETURN VALUES:
"   Modified a:pattern with position atoms removed.
"******************************************************************************
    return substitute(a:pattern, '\%(\%(^\|[^\\]\)\%(\\\\\)*\\\)\@<!\%(\\\%([\^<>]\|_\^\|_\$\|%[\^$V#]\|%[<>]\?''.\|%[<>]\?\d\+[lcv]\)\|[\^$]\)', '', 'g')
endfunction

function! ingo#regexp#deconstruct#RemoveMultis( pattern )
"******************************************************************************
"* PURPOSE:
"   Remove multi items (*, \+, etc.) that signify the multiplicity of the
"   previous atom from a:pattern.
"* ASSUMPTIONS / PRECONDITIONS:
"   Does not consider "very magic" (/\v)-style syntax. If you may have this,
"   convert via ingo#regexp#magic#Normalize() first.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:pattern   regular expression
"* RETURN VALUES:
"   Modified a:pattern with multi items removed.
"******************************************************************************
    return substitute(a:pattern, ingo#regexp#multi#Expr(), '', 'g')
endfunction

let s:specialLookup = {
\   'e': "\e",
\   't': "\t",
\   'r': "\r",
\   'b': "\b",
\   'n': "\n",
\}
function! ingo#regexp#deconstruct#UnescapeSpecialCharacters( pattern )
"******************************************************************************
"* PURPOSE:
"   Remove the backslash in front of characters that have special regular
"   expression meaning without it, like [\.*~], and interpret special sequences
"   like \e \t \n.
"* ASSUMPTIONS / PRECONDITIONS:
"   Does not consider "very magic" (/\v)-style syntax. If you may have this,
"   convert via ingo#regexp#magic#Normalize() first.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:pattern   regular expression
"* RETURN VALUES:
"   Modified a:pattern with special characters turned into literal ones.
"******************************************************************************
    let l:result = a:pattern
    let l:result = substitute(l:result, '\%(\%(^\|[^\\]\)\%(\\\\\)*\\\)\@<!\\\([etrbn]\)', '\=s:specialLookup[submatch(1)]', 'g')
    let l:result = ingo#escape#Unescape(l:result, '\^$.*~[]')
    return l:result
endfunction

function! ingo#regexp#deconstruct#TranslateCharacterClasses( pattern, ... ) abort
"******************************************************************************
"* PURPOSE:
"   Translate character classes (e.g. \d, \k), collections ([...]; unless they
"   only contain a single literal character), and optionally matched atoms from
"   a:pattern with the passed a:replacements or default ones.
"* ASSUMPTIONS / PRECONDITIONS:
"   Does not consider "very magic" (/\v)-style syntax. If you may have this,
"   convert via ingo#regexp#magic#Normalize() first.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:pattern   regular expression
"   a:replacements  Optional Dict that maps each character class / collection to
"                   a replacment.
"* RETURN VALUES:
"   Modified a:pattern with character classes translated.
"******************************************************************************
    let l:pattern = a:pattern
    let l:replacements = (a:0 ? a:1 : {
    \   'blank': ' ',
    \   'return': "\r",
    \   'tab': "\t",
    \   'escape': "\e",
    \   'backspace': "\b",
    \   'cntrl': "\uFF3E",
    \   'punct': "\u203D",
    \   'i': "\U1D456",
    \   'I': "\U1D43C",
    \   'k': "\U1D458",
    \   'K': "\U1D43E",
    \   'f': "\U1D453",
    \   'F': "\U1D439",
    \   'p': "\U1D45D",
    \   'print': "\U1D45D",
    \   'graph': "\U1D45D",
    \   'P': "\U1D443",
    \   'PRINT': "\U1D443",
    \   'GRAPH': "\U1D443",
    \   's': "\U1D460",
    \   'space': "\U1D460",
    \   'S': "\U1D446",
    \   'SPACE': "\U1D446",
    \   'd': "\U1D451",
    \   'digit': "\U1D451",
    \   'D': "\U1D437",
    \   'DIGIT': "\U1D437",
    \   'x': "\U1D465",
    \   'xdigit': "\U1D465",
    \   'X': "\U1D44B",
    \   'XDIGIT': "\U1D44B",
    \   'o': "\U1D45C",
    \   'O': "\U1D442",
    \   'w': "\U1D464",
    \   'W': "\U1D44A",
    \   'h': "\U1D455",
    \   'H': "\U1D43B",
    \   'a': "\U1D44E",
    \   'alpha': "\U1D44E",
    \   'alnum': "\U1D44E",
    \   'A': "\U1D434",
    \   'ALPHA': "\U1D434",
    \   'ALNUM': "\U1D434",
    \   'l': "\U1D459",
    \   'lower': "\U1D459",
    \   'L': "\U1D43F",
    \   'LOWER': "\U1D43F",
    \   'u': "\U1D462",
    \   'upper': "\U1D462",
    \   'U': "\U1D448",
    \   'UPPER': "\U1D448",
    \   '[]': "\u2026",
    \})

    let l:pattern = substitute(l:pattern, '\C\%(\%(^\|[^\\]\)\%(\\\\\)*\\\)\@<!\\_\?\([iIkKfFpPsSdDxXoOwWhHaAlLuU]\)', '\=get(l:replacements, submatch(1), "")', 'g')

    " Optional sequence of atoms \%[]. Note: Because these can contain
    " collection-like stuff, it has to be processed before collections.
    let l:pattern = substitute(l:pattern, '\%(\%(^\|[^\\]\)\%(\\\\\)*\\\)\@<!\\%\[\(\%(\[\[\]\|\[\]\]\|[^][]\|' . ingo#regexp#collection#Expr({'isBarePattern': 1}) . '\)\+\)\]', '\1', 'g')

    let l:pattern = substitute(l:pattern, ingo#regexp#collection#Expr({'isCapture': 1}), '\=s:TransformCollection(l:replacements, submatch(1))', 'g')

    return l:pattern
endfunction
function! s:TransformCollection( replacements, characters ) abort
    let l:literalCharacter = matchstr(a:characters, '^\\\?\zs.$')
    if ! empty(l:literalCharacter)
	return l:literalCharacter
    endif
    let l:characterClass = matchstr(a:characters, '^\[:\zs\a\+\ze:\]$')
    if ! empty(l:characterClass)
	return get(a:replacements, l:characterClass, '')
    endif
    let l:invertedCharacterClass = matchstr(a:characters, '^\^\[:\zs\a\+\ze:\]$')
    if ! empty(l:invertedCharacterClass)
	return get(a:replacements, toupper(l:invertedCharacterClass), '')
    endif

    return get(a:replacements, '[]', '')
endfunction
function! ingo#regexp#deconstruct#RemoveCharacterClasses( pattern ) abort
"******************************************************************************
"* PURPOSE:
"   Remove character classes (e.g. \d, \k), collections ([...]; unless they only
"   contain a single literal character), and optionally matched atoms from
"   a:pattern.
"* ASSUMPTIONS / PRECONDITIONS:
"   Does not consider "very magic" (/\v)-style syntax. If you may have this,
"   convert via ingo#regexp#magic#Normalize() first.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:pattern   regular expression
"* RETURN VALUES:
"   Modified a:pattern with character classes removed.
"******************************************************************************
    return ingo#regexp#deconstruct#TranslateCharacterClasses(a:pattern, {})
endfunction

function! ingo#regexp#deconstruct#TranslateNumberEscapes( pattern ) abort
"******************************************************************************
"* PURPOSE:
"   Convert characters escaped as numbers from a:pattern.
"* ASSUMPTIONS / PRECONDITIONS:
"   Does not consider "very magic" (/\v)-style syntax. If you may have this,
"   convert via ingo#regexp#magic#Normalize() first.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:pattern   regular expression
"* RETURN VALUES:
"   Modified a:pattern with numbered escapes translated to literal characters.
"******************************************************************************
    let l:pattern = a:pattern

    let l:pattern = substitute(l:pattern, '\C\%(\%(^\|[^\\]\)\%(\\\\\)*\\\)\@<!\\%d\(\d\+\)', '\=nr2char(str2nr(submatch(1)))', 'g')
    let l:pattern = substitute(l:pattern, '\C\%(\%(^\|[^\\]\)\%(\\\\\)*\\\)\@<!\\%o\(\o\+\)', '\=nr2char(str2nr(submatch(1), 8))', 'g')
    let l:pattern = substitute(l:pattern, '\C\%(\%(^\|[^\\]\)\%(\\\\\)*\\\)\@<!\\%x\(\x\{1,2}\)', '\=nr2char(str2nr(submatch(1), 16))', 'g')
    let l:pattern = substitute(l:pattern, '\C\%(\%(^\|[^\\]\)\%(\\\\\)*\\\)\@<!\\%u\(\x\{1,4}\)', '\=nr2char(str2nr(submatch(1), 16))', 'g')
    let l:pattern = substitute(l:pattern, '\C\%(\%(^\|[^\\]\)\%(\\\\\)*\\\)\@<!\\%U\(\x\{1,8}\)', '\=nr2char(str2nr(submatch(1), 16))', 'g')

    return l:pattern
endfunction

function! ingo#regexp#deconstruct#TranslateBranches( pattern ) abort
"******************************************************************************
"* PURPOSE:
"   Translate regular expression branches (/\(foo\|bar\)/) inside a:pattern into
"   simpler notation (foo|bar).
"* ASSUMPTIONS / PRECONDITIONS:
"   Does not consider "very magic" (/\v)-style syntax. If you may have this,
"   convert via ingo#regexp#magic#Normalize() first.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:pattern   regular expression
"* RETURN VALUES:
"   Modified a:pattern with branches translated.
"******************************************************************************
    let l:pattern = a:pattern

    for [l:search, l:replace] in [['%\?(', '('], ['|', '|'], [')', ')']]
	let l:pattern = substitute(l:pattern, '\%(\%(^\|[^\\]\)\%(\\\\\)*\\\)\@<!\\' . l:search, l:replace, 'g')
    endfor

    return l:pattern
endfunction

function! ingo#regexp#deconstruct#ToQuasiLiteral( pattern )
"******************************************************************************
"* PURPOSE:
"   Turn a:pattern into something resembling a literal match of it by removing
"   position atoms, multis, translating character classes / collections and
"   branches, and unescaping.
"* ASSUMPTIONS / PRECONDITIONS:
"   Does not consider "very magic" (/\v)-style syntax. If you may have this,
"   convert via ingo#regexp#magic#Normalize() first.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:pattern   regular expression
"* RETURN VALUES:
"   Modified a:pattern that resembles a literal match.
"******************************************************************************
    let l:result = a:pattern
    let l:result = ingo#regexp#deconstruct#RemovePositionAtoms(l:result)
    let l:result = ingo#regexp#deconstruct#RemoveMultis(l:result)
    let l:result = ingo#regexp#deconstruct#TranslateCharacterClasses(l:result)
    let l:result = ingo#regexp#deconstruct#TranslateNumberEscapes(l:result)
    let l:result = ingo#regexp#deconstruct#TranslateBranches(l:result)

    " Do the unescaping last.
    let l:result = ingo#regexp#deconstruct#UnescapeSpecialCharacters(l:result)
    return l:result
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo
" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
autoload/ingo/regexp/fromwildcard.vim	[[[1
188
" ingo/regexp/fromwildcard.vim: Functions for converting a shell-like wildcard to a regular expression.
"
" DEPENDENCIES:
"
" Copyright: (C) 2013-2015 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
"
" REVISION	DATE		REMARKS
"   1.023.003	30-Jan-2015	Add
"				ingo#regexp#fromwildcard#AnchoredToPathBoundaries().
"   1.021.002	23-Jun-2014	ENH: Allow to pass path separator to
"				ingo#regexp#fromwildcard#Convert() and
"				ingo#regexp#fromwildcard#IsWildcardPathPattern().
"   1.014.001	26-Oct-2013	file creation from
"				autoload/EditSimilar/Substitute.vim

if exists('+shellslash') && ! &shellslash
    let s:pathSeparator = '\'
    let s:notPathSeparatorPattern = '\\[^/\\\\]'
else
    let s:pathSeparator = '/'
    let s:notPathSeparatorPattern = '\\[^/]'
endif
function! s:AdaptCollection()
    " Special processing for the submatch inside the [...] collection.

    " Earlier, simpler regexp that didn't handle \] inside [...]:
    "let l:expr = substitute(l:expr, '\[\(\%(\^\?\]\)\?.\{-}\)\]', '\\%(\\%(\\[\1]\\\&' . s:notPathSeparatorPattern . '\\)\\|[\1]\\)', 'g')

    " Handle \] inside by including \] in the inner pattern, then undoing the
    " backslash escaping done first in this function (i.e. recreate \] from the
    " initial \\]).
    " Vim doesn't seem to support other escaped characters like [\x6f\d122] in a
    " file pattern.
    let l:result = substitute(submatch(1), '\\\\]', '\\]', 'g')

    " Escape ? and *; the later wildcard expansions will trample over them.
    let l:result = substitute(l:result, '[?*]', '\\\\\0', 'g')

    return l:result
endfunction
function! s:CanonicalizeWildcard( expr, pathSeparator )
    let l:expr = escape(a:expr, '\')

    if a:pathSeparator ==# '\'
	" On Windows, when the 'shellslash' option isn't set (i.e. backslashes
	" are used as path separators), still allow using forward slashes as
	" path separators, like Vim does.
	let l:expr = substitute(l:expr, '/', '\\\\', 'g')
    endif
    return l:expr
endfunction
function! s:Convert( wildcardExpr, ... )
    let l:pathSeparator = (a:0 > 1 ? a:2 : s:pathSeparator)
    let l:expr = s:CanonicalizeWildcard(a:wildcardExpr, l:pathSeparator)

    " [...] wildcards
    let l:expr = substitute(l:expr, '\[\(\%(\^\?\]\)\?\(\\\\\]\|[^]]\)*\)\]', '\="\\%(\\%(\\[". s:AdaptCollection() . "]\\\&' . s:notPathSeparatorPattern . '\\)\\|[". s:AdaptCollection() . "]\\)"', 'g')

    " ? wildcards
    let l:expr = substitute(l:expr, '\\\@<!?', s:notPathSeparatorPattern, 'g')
    let l:expr = substitute(l:expr, '\\\\?', '?', 'g')

    " ** wildcards
    " The ** wildcard matches multiple path elements up to the last path
    " separator; i.e. it doesn't match the filename itself. To implement this
    " restriction, the replacement regexp for ** ends with a zero-width match
    " (so it isn't substituted away) for the path separator if no path separator
    " is already following in the wildcard, anyway.
    " (The l:originalPathspec that is processed in s:Substitute() always has a
    " trailing path separator.)
    "
    " Note: Instead of escaping the '.*' pattern in the replacement (or else
    " it'll be processed as a * wildcard), we use the equivalent '.\{0,}'
    " pattern.
    " Note: The regexp .\{0,}/\@= later substitutes twice if nothing precedes
    " it?! To fix this, we add the ^ anchor when the ** wildcard appears at the
    " beginning.
    if l:pathSeparator ==# '\'
	" If backslash is the path separator, one cannot escape the ** wildcard.
	" That isn't necessary, anyway, because Windows doesn't allow the '*'
	" character in filespecs.
	let l:expr = substitute(l:expr, '\\\\\zs\*\*$', '\\.\\{0,}\\%(\\\\\\)\\@=', 'g')
	let l:expr = substitute(l:expr, '^\*\*$', '\\^\\.\\{0,}\\%(\\\\\\)\\@=', 'g')
	let l:expr = substitute(l:expr, '\%(^\|\\\\\)\zs\*\*\ze\\\\', '\\.\\{0,}', 'g')
    else
	let l:expr = substitute(l:expr, '/\zs\*\*$', '\\.\\{0,}/\\@=', 'g')
	let l:expr = substitute(l:expr, '^\*\*$', '\\^\\.\\{0,}/\\@=', 'g')
	let l:expr = substitute(l:expr, '\%(^\|/\)\zs\*\*\ze/', '\\.\\{0,}', 'g')
	" Convert the escaped \** to \*\*, so that the following * wildcard
	" substitution converts that to **.
	let l:expr = substitute(l:expr, '\\\\\*\*', '\\\\*\\\\*', 'g')
    endif

    " * wildcards
    let l:expr = substitute(l:expr, '\\\@<!\*', s:notPathSeparatorPattern . '\\*', 'g')
    let l:expr = substitute(l:expr, '\\\\\*', '*', 'g')

    let l:additionalEscapeCharacters = (a:0 ? a:1 : '')
    return [l:expr, l:additionalEscapeCharacters, l:pathSeparator]
endfunction
function! ingo#regexp#fromwildcard#Convert( ... )
"*******************************************************************************
"* PURPOSE:
"   Convert a shell-like a:wildcardExpr which may contain wildcards (?, *, **,
"   [...]) into an (unanchored!) regular expression.
"
"   In constrast to the simpler ingo#regexp#FromWildcard(), this handles the
"   full range of wildcards and considers the path separators on different
"   platforms.
"
"* SEE ALSO:
"   For automatic anchoring, use
"   ingo#regexp#fromwildcard#AnchoredToPathBoundaries().
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:wildcardExpr  Text containing file wildcards.
"   a:additionalEscapeCharacters    For use in the / command, add '/', for the
"				    backward search command ?, add '?'. For
"				    assignment to @/, always add '/', regardless
"				    of the search direction; this is how Vim
"				    escapes it, too. For use in search(), pass
"				    nothing / omit the argument.
"   a:pathSeparator Optional fixed value for the path separator, to use instead
"		    of the platform's default one.
"* RETURN VALUES:
"   Regular expression for matching a:wildcardExpr.
"*******************************************************************************
    let [l:expr, l:additionalEscapeCharacters, l:pathSeparator] = call('s:Convert', a:000)
    return '\V' . escape(l:expr, l:additionalEscapeCharacters)
endfunction
function! ingo#regexp#fromwildcard#AnchoredToPathBoundaries( ... )
"*******************************************************************************
"* PURPOSE:
"   Convert a shell-like a:wildcardExpr which may contain wildcards (?, *, **,
"   [...]) into a regular expression anchored to path boundaries; i.e.
"   a:wildcardExpr must match complete path components delimited by the
"   a:pathSeparator or the start / end of the String.
"
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:wildcardExpr  Text containing file wildcards.
"   a:additionalEscapeCharacters    For use in the / command, add '/', for the
"				    backward search command ?, add '?'. For
"				    assignment to @/, always add '/', regardless
"				    of the search direction; this is how Vim
"				    escapes it, too. For use in search(), pass
"				    nothing / omit the argument.
"   a:pathSeparator Optional fixed value for the path separator, to use instead
"		    of the platform's default one.
"* RETURN VALUES:
"   Regular expression for matching a:wildcardExpr.
"*******************************************************************************
    let [l:expr, l:additionalEscapeCharacters, l:pathSeparator] = call('s:Convert', a:000)
    let l:pathSeparator = escape(l:pathSeparator, '\')

    let l:prefix = printf('\%%(\^\|%s\@<=\)', l:pathSeparator)
    let l:suffix = printf('\%%(\$\|%s\@=\)', l:pathSeparator)
    return '\V' . escape(l:prefix . l:expr . l:suffix, l:additionalEscapeCharacters)
endfunction

function! ingo#regexp#fromwildcard#IsWildcardPathPattern( expr, ... )
    let l:pathSeparator = (a:0 ? a:1 : s:pathSeparator)
    let l:expr = s:CanonicalizeWildcard(a:expr, l:pathSeparator)
    let l:pathSeparatorExpr = escape(l:pathSeparator, '\')

    " Check for ** wildcard.
    if l:expr =~ '\%(^\|'. l:pathSeparatorExpr . '\)\zs\*\*\ze\%(' . l:pathSeparatorExpr . '\|$\)'
	return 1
    endif

    " Check for path separator outside of [...] wildcards.
    if substitute(l:expr, '\[\(\%(\^\?\]\)\?\(\\\\\]\|[^]]\)*\)\]', '', 'g') =~ l:pathSeparatorExpr
	return 1
    endif

    return 0
endfunction

" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
autoload/ingo/regexp/length.vim	[[[1
166
" ingo/regexp/length.vim: Functions to compare the length of regular expression matches.
"
" DEPENDENCIES:
"   - ingo/collections.vim autoload script
"   - ingo/compat.vim autoload script
"   - ingo/list/split.vim autoload script
"   - ingo/regexp/collection.vim autoload script
"   - ingo/regexp/deconstruct.vim autoload script
"   - ingo/regexp/magic.vim autoload script
"   - ingo/regexp/multi.vim autoload script
"   - ingo/regexp/split.vim autoload script
"
" Copyright: (C) 2018 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
let s:save_cpo = &cpo
set cpo&vim

function! s:AddWithLimit( accumulator, value )
    return (a:accumulator == 0x7FFFFFFF || a:value == 0x7FFFFFFF ?
    \   0x7FFFFFFF :
    \   min([a:accumulator + a:value, 0x7FFFFFFF])
    \)
endfunction
function! s:AddMinMax( accumulatorList, valueList )
    let a:accumulatorList[0] = s:AddWithLimit(a:accumulatorList[0], a:valueList[0])
    let a:accumulatorList[1] = s:AddWithLimit(a:accumulatorList[1], a:valueList[1])
    return a:accumulatorList
endfunction
function! s:OverallMinMax( minMaxList )
    let l:minLengths = map(copy(a:minMaxList), 'v:val[0]')
    let l:maxLengths = map(copy(a:minMaxList), 'v:val[1]')
    return [min(l:minLengths), max(maxLengths)]
endfunction
function! ingo#regexp#length#Project( pattern )
"******************************************************************************
"* PURPOSE:
"   Estimate the number of characters that a:pattern will match. Of course, this
"   works best if the pattern specifies a literal match or only has fixed-width
"   atoms.
"* ASSUMPTIONS / PRECONDITIONS:
"   Does not consider "very magic" (/\v)-style syntax. If you may have this,
"   convert via ingo#regexp#magic#Normalize() first.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:pattern   Regular expression to analyze.
"* RETURN VALUES:
"   List of [minLength, maxLength]. For complex expressions or unbounded multis
"   like |/*| , assumes a minimum of 0 and a maximum of 0x7FFFFFFF.
"   Throws 'PrefixGroupsSuffix: Unmatched \(' or
"   'PrefixGroupsSuffix: Unmatched \)' if a:pattern is invalid.
"******************************************************************************
    let l:branches = ingo#regexp#split#TopLevelBranches(ingo#regexp#split#GlobalFlags(a:pattern)[-1])
    let l:minMaxBranches = map(
    \   l:branches,
    \   's:ProjectBranch(v:val)'
    \)
    return s:OverallMinMax(l:minMaxBranches)
endfunction
function! s:ProjectBranch( pattern )
    let l:splits = ingo#regexp#split#PrefixGroupsSuffix(a:pattern)
    if len(l:splits) == 1
	return s:ProjectUngroupedPattern(a:pattern)
    endif

    call add(l:splits, '')  " Add one empty branch to be able to handle the last real one in a consistent way.
    let l:minMaxes = [0, 0]
    let l:previousMinMax = [0, 0]
    while len(l:splits) > 1
	let l:prefix = remove(l:splits, 0)
	let [l:multi, l:rest] = matchlist(l:prefix, '^\(' . ingo#regexp#multi#Expr() . '\)\?\(.\{-}\)$')[1:2]
	if empty(l:multi)
	    call s:AddMinMax(l:minMaxes, l:previousMinMax)
	else
	    let l:prefix = l:rest
	    call s:AddMinMax(l:minMaxes, s:Multiply(l:previousMinMax, l:multi))
	endif
	call s:AddMinMax(l:minMaxes, s:ProjectUngroupedPattern(l:prefix))

	let l:group = remove(l:splits, 0)
	let l:previousMinMax = ingo#regexp#length#Project(l:group)
    endwhile

    return l:minMaxes
endfunction
function! s:Multiply( minMax, multi )
    let [l:minLength, l:maxLength] = a:minMax
    let [l:minMultiplier, l:maxMultiplier] = s:ProjectMulti(a:multi)

    return [l:minLength * l:minMultiplier, l:maxLength * l:maxMultiplier]
endfunction
function! s:ProjectUngroupedPattern( pattern )
    let l:patternMultis =
    \   ingo#list#split#ChunksOf(
    \       ingo#collections#SplitKeepSeparators(
    \           a:pattern,
    \           ingo#regexp#multi#Expr(),
    \           1
    \       ),
    \       2, ''
    \   )

    let l:minMaxMultis = map(
    \   filter(
    \       l:patternMultis,
    \       'v:val !=# ["", ""]'
    \   ),
    \   's:ProjectMultis(v:val[0], v:val[1])'
    \)

    return ingo#collections#Reduce(l:minMaxMultis, function('s:AddMinMax'), [0, 0])
endfunction
function! s:ProjectMultis( pattern, multi )
    let l:minMaxes = [0, 0]
    call s:AddMinMax(l:minMaxes, s:ProjectUngroupedSinglePattern(a:pattern))
    call s:AddMinMax(l:minMaxes, [-1, -1])  " The tally for the atom before the multi is contained in the multi, so we need to subtract one. Simply cutting it off would be more difficult, because it could be an escaped special character or a collection.
    call s:AddMinMax(l:minMaxes, s:ProjectMulti(a:multi))
    return l:minMaxes
endfunction
function! s:ProjectUngroupedSinglePattern( pattern )
    let l:patternWithoutCollections = s:RemoveCollections(a:pattern)
    let l:literalText = ingo#regexp#deconstruct#ToQuasiLiteral(l:patternWithoutCollections)
    let l:literalTextLength = ingo#compat#strchars(l:literalText)
    return [l:literalTextLength, l:literalTextLength]
endfunction
function! s:RemoveCollections( pattern )
    return substitute(a:pattern, ingo#regexp#collection#Expr(), 'x', 'g')
endfunction
function! s:ProjectMulti( multi )
    if empty(a:multi)
	return [1, 1]
    elseif a:multi ==# '*'
	return [0, 0x7FFFFFFF]
    elseif a:multi ==# '\+'
	return [1, 0x7FFFFFFF]
    elseif a:multi ==# '\?'
	return [0, 1]
    elseif a:multi =~# '^\\{'
	let l:range = matchstr(a:multi, '^\\{-\?\zs[[:digit:],]*\ze}$')
	if l:range ==# a:multi | throw 'ASSERT: Invalid multi syntax' | endif
	if l:range =~# ','
	    let l:rangeNumbers = split(l:range, ',', 1)
	    return [
	    \   empty(l:rangeNumbers[0]) ? 0 : str2nr(l:rangeNumbers[0]),
	    \   empty(l:rangeNumbers[1]) ? 0x7FFFFFFF : str2nr(l:rangeNumbers[1])
	    \]
	else
	    return (empty(l:range) ?
	    \   [0, 0x7FFFFFFF] :
	    \   [str2nr(l:range), str2nr(l:range)]
	    \)
	endif
    elseif a:multi ==# '\@>'
	return [1, 1]
    elseif a:multi =~# '^\\@'
	return [0, 0]
    else
	throw 'ASSERT: Unhandled multi: ' . string(a:multi)
    endif
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo
" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
autoload/ingo/regexp/magic.vim	[[[1
140
" ingo/regexp/magic.vim: Functions around handling magicness in regular expressions.
"
" DEPENDENCIES:
"   - ingo/collections.vim autoload script for ingo#regexp#magic#Normalize()
"   - ingo/collections/fromsplit.vim autoload script
"   - ingo/regexp/collection.vim autoload script
"
" Copyright: (C) 2011-2018 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
let s:save_cpo = &cpo
set cpo&vim

function! ingo#regexp#magic#GetNormalizeMagicnessAtom( pattern )
"******************************************************************************
"* PURPOSE:
"   Return normalizing \m (or \M) if a:pattern contains atom(s) that change the
"   default magicness. This makes it possible to append another pattern without
"   having a:pattern affect it.
"
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:pattern	Regular expression to observe.
"* RETURN VALUES:
"   Normalizing atom or empty string.
"******************************************************************************
    let l:normalizingAtom = (&magic ? 'm' : 'M')
    let l:magicChangeAtoms = substitute('vmMV', '\C'.l:normalizingAtom, '', '')

    return (a:pattern =~# '\%(\%(^\|[^\\]\)\%(\\\\\)*\\\)\@<!\\[' . l:magicChangeAtoms . ']' ? '\' . l:normalizingAtom : '')
endfunction

let s:magicAtomsExpr = '\%(\%(^\|[^\\]\)\%(\\\\\)*\\\)\@<!\\[vmMV]'
function! ingo#regexp#magic#HasMagicAtoms( pattern )
    return a:pattern =~# s:magicAtomsExpr
endfunction
let s:specialSearchCharacterExpressions = {
\   'v': '\W',
\   'm': '[\\^$.*[~]',
\   'M': '[\\^$]',
\   'V': '\\',
\}
function! s:ConvertMagicnessOfFragment( fragment, sourceSpecialCharacterExpr, targetSpecialCharacterExpr )
    let l:elements = ingo#collections#fromsplit#MapItemsAndSeparators(a:fragment, '\%(\%(^\|[^\\]\)\%(\\\\\)*\\\)\@<!\\\?' . ingo#regexp#collection#Expr({'isBarePattern': 1}),
    \	printf('ingo#regexp#magic#ConvertMagicnessOfElement(v:val, %s, %s)', string(a:sourceSpecialCharacterExpr), string(a:targetSpecialCharacterExpr)),
    \	printf('ingo#regexp#magic#ConvertMagicnessOfCollection(v:val, %s, %s)', string(a:sourceSpecialCharacterExpr), string(a:targetSpecialCharacterExpr))
    \)
    return join(l:elements, '')
endfunction
function! ingo#regexp#magic#ConvertMagicnessOfCollection( collection, sourceSpecialCharacterExpr, targetSpecialCharacterExpr )
    let l:isEscaped = (a:collection =~# '^\\\[')
    if l:isEscaped && '[' =~# a:sourceSpecialCharacterExpr && '[' !~# a:targetSpecialCharacterExpr
	return a:collection[1:]
    elseif ! l:isEscaped && '[' !~# a:sourceSpecialCharacterExpr && '[' =~# a:targetSpecialCharacterExpr
	return '\' . a:collection
    else
	return a:collection
    endif
endfunction
function! ingo#regexp#magic#ConvertMagicnessOfElement( element, sourceSpecialCharacterExpr, targetSpecialCharacterExpr )
    let l:isEscaped = 0
    let l:chars = split(a:element, '\zs')
    for l:index in range(len(l:chars))
	let l:char = l:chars[l:index]

	if (l:char =~# a:sourceSpecialCharacterExpr) + (l:char =~# a:targetSpecialCharacterExpr) == 1
	    " The current character belongs to different classes in source and target.
	    if l:isEscaped
		let l:chars[l:index - 1] = ''
	    else
		let l:chars[l:index] = '\' . l:char
	    endif
	endif

	if l:char ==# '\'
	    let l:isEscaped = ! l:isEscaped
	else
	    let l:isEscaped = 0
	endif
    endfor

    return join(l:chars, '')
endfunction
function! ingo#regexp#magic#Normalize( pattern )
"******************************************************************************
"* PURPOSE:
"   Remove any \v, /m, \M, \V atoms from a:pattern that change the magicness,
"   and re-write the pattern (by selective escaping and unescaping) into an
"   equivalent pattern that is based on the current 'magic' setting.
"
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:pattern	Regular expression that may contain atoms that affect the
"		magicness.
"* RETURN VALUES:
"   Equivalent pattern that has any atoms affecting the magicness removed and is
"   based on the current 'magic' setting.
"******************************************************************************
    let l:currentMagicMode = (&magic ? 'm' : 'M')
    let l:defaultMagicMode = l:currentMagicMode
    let l:patternFragments = ingo#collections#SplitKeepSeparators(a:pattern, s:magicAtomsExpr, 1)
    " Because we asked to keep any empty fragments, we can easily test whether
    " there's any work to do.
    if len(l:patternFragments) == 1
	return a:pattern
    endif
"****D echomsg string(l:patternFragments)
    for l:fragmentIndex in range(len(l:patternFragments))
	let l:fragment = l:patternFragments[l:fragmentIndex]
	if l:fragment =~# s:magicAtomsExpr
	    let l:currentMagicMode = l:fragment[1]
	    let l:patternFragments[l:fragmentIndex] = ''
	    continue
	endif

	if l:currentMagicMode ==# l:defaultMagicMode
	    " No need for conversion.
	    continue
	endif

	let l:patternFragments[l:fragmentIndex] = s:ConvertMagicnessOfFragment(
	\   l:fragment,
	\   s:specialSearchCharacterExpressions[l:currentMagicMode],
	\   s:specialSearchCharacterExpressions[l:defaultMagicMode]
	\)
    endfor
"****D echomsg string(l:patternFragments)
    return join(l:patternFragments, '')
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo
" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
autoload/ingo/regexp/multi.vim	[[[1
26
" ingo/regexp/multi.vim: Functions around pattern multiplicity.
"
" DEPENDENCIES:
"
" Copyright: (C) 2018 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>

function! ingo#regexp#multi#Expr()
"******************************************************************************
"* PURPOSE:
"   REturn a regular expression that matches any multi.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   None.
"* RETURN VALUES:
"   Regular expression.
"******************************************************************************
    return '\%(\%(^\|[^\\]\)\%(\\\\\)*\\\)\@<!\%(\*\|\\[+=?]\|\\{-\?\d*,\?\d*}\|\\@\%(>\|=\|!\|<=\|<!\)\)'
endfunction

" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
autoload/ingo/regexp/pairs.vim	[[[1
54
" ingo/regexp/pairs.vim: Functions for skipping intermediate start-end pairs.
"
" DEPENDENCIES:
"
" Copyright: (C) 2014 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
"
" REVISION	DATE		REMARKS
"   1.022.001	20-Aug-2014	file creation

function! ingo#regexp#pairs#MatchEnd( expr, startPattern, endPattern, ... )
"******************************************************************************
"* PURPOSE:
"   Search for the match of the end of a pair, skipping intermediate start-end
"   pairs in between.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:expr  Text to match.
"   a:startPattern  Pattern that matches the start of a pair.
"   a:endPattern    Pattern that matches the end of a pair.
"   a:start         Optional byte index into a:expr from where to start.
"* RETURN VALUES:
"   Byte index of the start of the a:endPattern that belongs to a:startPattern,
"   skipping nested intermediate pairs. -1 if not such match.
"******************************************************************************
    let l:idx = (a:0 ? a:1 : 0)
    let l:pairCnt = 0
    while 1
	let l:startIdx = match(a:expr, a:startPattern, l:idx)
	let l:endIdx = match(a:expr, a:endPattern, l:idx)

	if l:startIdx == -1 && l:endIdx == -1
	    return -1
	elseif l:startIdx != -1 && l:startIdx < l:endIdx
	    let l:pairCnt += 1
	    let l:idx = l:startIdx + len(matchstr(a:expr, '\%' . (l:startIdx + 1) . 'c.'))
	elseif l:endIdx != -1
	    let l:pairCnt -= 1
	    if l:pairCnt <= 0
		return l:endIdx
	    endif
	    let l:idx = l:endIdx + len(matchstr(a:expr, '\%' . (l:endIdx + 1) . 'c.'))
	else
	    throw 'ASSERT: Never reached'
	endif
    endwhile
endfunction

" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
autoload/ingo/regexp/previoussubstitution.vim	[[[1
59
" ingo/regexp/previoussubstitution.vim: Function to get the previous substitution |s~|
"
" DEPENDENCIES:
"   - ingo/buffer/temp.vim autoload script
"   - ingo/compat.vim autoload script
"
" Copyright: (C) 2011-2014 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
"
" REVISION	DATE		REMARKS
"   1.012.005	08-Aug-2013	Move escapings.vim into ingo-library.
"   1.009.004	14-Jun-2013	Minor: Make matchstr() robust against
"				'ignorecase'.
"   1.008.003	12-Jun-2013	Change implementation from doing a :substitute
"				in a temp buffer (which has the nasty side
"				effect of clobbering the remembered flags) to
"				writing a temporary viminfo file and parsing
"				that.
"   1.008.002	11-Jun-2013	Use :s_& flag to avoid clobbering the remembered
"				flags. (Important for SmartCase.vim.)
"				Avoid clobbering the search history.
"	001	11-Jun-2013	file creation from ingomappings.vim

function! ingo#regexp#previoussubstitution#Get()
    " The substitution string is not exposed via a Vim variable, nor does
    " substitute() recognize it.
    let l:previousSubstitution = ''

    " We would have to perform a substitution in a scratch buffer to obtain it,
    " but that unfortunately clobbers the remembered flags, something that can
    " be important around custom substitutions. (Can't use the :s_& flag,
    " neither, since using :s_c would block the substitution with a query.)
    " It also doesn't allow us to retrieve |sub-replace-special| expressions,
    " just the (first) actual replacement result.
    "
    " Therefore, a better yet even more involved workaround is to extract the
    " value from a temporary |viminfo| file.
    let l:tempfile = tempname()
    let l:save_viminfo = &viminfo
    set viminfo='0,/1,:0,<0,@0,s0
    try
	execute 'wviminfo!' ingo#compat#fnameescape(l:tempfile)
	let l:viminfo = join(readfile(l:tempfile), "\n")
	let l:previousSubstitution = matchstr(l:viminfo, '\C\n# Last Substitute String:\n\$\zs\_.\{-}\ze\n\n# .* (newest to oldest):\n')
    catch /^Vim\%((\a\+)\)\=:/
	" Fallback.
	let l:previousSubstitution = ingo#buffer#temp#Execute('substitute/^/' . (&magic ? '~' : '\~') . '/')
	call histdel('search', -1)
    finally
	let &viminfo = l:save_viminfo
	call delete(l:tempfile)
    endtry

    return l:previousSubstitution
endfunction

" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
autoload/ingo/regexp/split.vim	[[[1
181
" ingo/regexp/split.vim: Functions to split a regular expression.
"
" DEPENDENCIES:
"   - ingo/collections.vim autoload script
"   - ingo/regexp/length.vim autoload script
"   - ingo/regexp/magic.vim autoload script
"
" Copyright: (C) 2017-2018 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>

function! ingo#regexp#split#TopLevelBranches( pattern )
"******************************************************************************
"* PURPOSE:
"   Split a:pattern on "\|" - separated branches, keeping nested \(...\|...\)
"   branches inside (non-)capture groups together. If the complete a:pattern is
"   wrapped in a group, it is treated as one toplevel branch, too.
"* ASSUMPTIONS / PRECONDITIONS:
"   Does not consider "very magic" (/\v)-style syntax (...|...). If you may have
"   this, convert via ingo#regexp#magic#Normalize() first.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:pattern   regular expression
"* RETURN VALUES:
"   List of regular expression branch fragments.
"******************************************************************************
    let l:rawBranches = split(a:pattern, '\%(\%(^\|[^\\]\)\%(\\\\\)*\\\)\@<!\\|', 1)
    let l:openGroupCnt = 0
    let l:branches = []

    let l:currentBranch = ''
    while ! empty(l:rawBranches)
	let l:currentBranch = remove(l:rawBranches, 0)
	let l:currentOpenGroupCnt = l:openGroupCnt

	let l:count = 1
	while 1
	    let l:match = matchstr(l:currentBranch, '\%(\%(^\|[^\\]\)\%(\\\\\)*\\\)\@<!\\\%(%\?(\|)\)', 0, l:count)
	    if empty(l:match)
		break
	    elseif l:match == '\)'
		let l:openGroupCnt = max([0, l:openGroupCnt - 1])
	    else
		let l:openGroupCnt += 1
	    endif
	    let l:count += 1
	endwhile

	if l:currentOpenGroupCnt == 0
	    call add(l:branches, l:currentBranch)
	else
	    if empty(l:branches)
		let l:branches = ['']
	    endif
	    let l:branches[-1] .= '\|' . l:currentBranch
	endif
    endwhile

    return l:branches
endfunction

function! ingo#regexp#split#PrefixGroupsSuffix( pattern )
"******************************************************************************
"* PURPOSE:
"   Split a:pattern into a \(...\) group (capture or non-capture), and any
"   preceding / trailing regular expression parts.
"* ASSUMPTIONS / PRECONDITIONS:
"   Does not consider "very magic" (/\v)-style syntax (...|...). If you may have
"   this, convert via ingo#regexp#magic#Normalize() first.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:pattern   regular expression
"* RETURN VALUES:
"   List of [prefix, group1, [infix, group2, [...]] suffix], or [a:pattern] if
"   there's no toplevel group at all.
"   Throws 'PrefixGroupsSuffix: Unmatched \(' or
"   'PrefixGroupsSuffix: Unmatched \)' if a:pattern is invalid.
"******************************************************************************
    let l:pattern = a:pattern
    let l:result = []
    let l:accu = ''
    let l:openGroupCnt = 0
    while 1
	let l:parse = matchlist(l:pattern, '^\(.\{-}\)\(\%(\%(^\|[^\\]\)\%(\\\\\)*\\\)\@<!\\\%(%\?(\|)\)\)\(.*\)$')
	if empty(l:parse)
	    " No more open / close parentheses.
	    call add(l:result, l:pattern)
	    break
	endif
	let [l:prefix, l:paren, l:pattern] = l:parse[1:3]

	let l:isOpen = (l:paren !=# '\)')
	let l:openGroupCnt += (l:isOpen ? 1 : -1)
	if l:openGroupCnt < 0
	    throw 'PrefixGroupsSuffix: Unmatched \)'
	elseif l:isOpen && l:openGroupCnt == 1
	    call add(l:result, l:prefix)
	elseif ! l:isOpen && l:openGroupCnt == 0
	    call add(l:result, l:accu . l:prefix)
	    let l:accu = ''
	else
	    let l:accu .= l:prefix . l:paren
	endif
    endwhile
    if l:openGroupCnt != 0
	throw 'PrefixGroupsSuffix: Unmatched \('
    endif

    return l:result
endfunction

function! ingo#regexp#split#AddPatternByProjectedMatchLength( branches, pattern )
"******************************************************************************
"* PURPOSE:
"   Add a:pattern to the List of regexp a:branches, in a position so that
"   shorter earlier branches do not eclipse a following longer match.
"* ASSUMPTIONS / PRECONDITIONS:
"   Does not consider "very magic" (/\v)-style syntax, in neither a:branches nor
"   a:pattern. If you may have this, convert via ingo#regexp#magic#Normalize()
"   first.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:branches  List of regular expression branches (e.g. split via
"               ingo#regexp#split#TopLevelBranches()).
"   a:pattern   Regular expression to be added at the appropriate position in
"               a:branches, depending on the projected length of the matches.
"               Longer matches will come first, so that a shorter earlier match
"               does not eclipse a following longer one.
"* RETURN VALUES:
"   Modified a:branches List.
"******************************************************************************
    try
	let l:projectedPatternMinLength = ingo#regexp#length#Project(a:pattern)[0]
    catch /^PrefixGroupsSuffix:/
	let l:projectedPatternMinLength = 0
    endtry

    let l:i = 0
    while l:i < len(a:branches)
	try
	    let [l:min, l:max] = ingo#regexp#length#Project(a:branches[l:i])
	    let l:compare = (l:max < 0x7FFFFFFF ? l:max : l:min)
	    if l:compare < l:projectedPatternMinLength
		break
	    endif
	catch /^PrefixGroupsSuffix:/
	    " Skip invalid existing branch.
	endtry

	let l:i += 1
    endwhile
    return insert(a:branches, a:pattern, l:i)
endfunction

function! ingo#regexp#split#GlobalFlags( pattern )
"******************************************************************************
"* PURPOSE:
"   Split global regular expression engine flags from a:pattern. These control
"   case sensitivity (/\c, /\C) and engine type (/\%#=0).
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:pattern   regular expression
"* RETURN VALUES:
"   [engineTypeFlag, caseSensitivityFlag, purePattern]
"******************************************************************************
    let [l:fragments, l:caseFlags] = ingo#collections#SeparateItemsAndSeparators(a:pattern, '\%(\%(^\|[^\\]\)\%(\\\\\)*\\\)\@<!\\[cC]')
    let [l:fragments, l:engineFlags] = ingo#collections#SeparateItemsAndSeparators(join(l:fragments, ''), '\%(\%(^\|[^\\]\)\%(\\\\\)*\\\)\@<!\\%#=[012]')
    let l:purePattern = join(l:fragments, '')

    let l:caseSensitivityFlag = (index(l:caseFlags, '\c') == -1 ? get(l:caseFlags, 0, '') : '\c')
    return [get(l:engineFlags, 0, ''), l:caseSensitivityFlag, l:purePattern]
endfunction

" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
autoload/ingo/regexp/virtcols.vim	[[[1
47
" ingo/regexp/virtcols.vim: Functions for regular expressions matching screen columns.
"
" DEPENDENCIES:
"
" Copyright: (C) 2015 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
"
" REVISION	DATE		REMARKS
"   1.024.001	01-Apr-2015	file creation
let s:save_cpo = &cpo
set cpo&vim

function! ingo#regexp#virtcols#ExtractCells( virtcol, width, isAllowSmaller )
"******************************************************************************
"* PURPOSE:
"   Assemble a regular expression that matches screen columns starting from
"   a:virtcol of a:width.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:virtcol   First virtual column (first column is 1); the character must
"		begin exactly at that column.
"   a:width     Width in screen columns.
"   a:isAllowSmaller    Boolean flag whether less characters can be matched if
"			the end doesn't fall on a character border, or there
"			aren't that many characters. Else, exactly a:width
"			screen columns must be matched.
"* RETURN VALUES:
"   Regular expression.
"******************************************************************************
    if a:virtcol < 1
	throw 'ExtractCells: Column must be at least 1'
    endif
    return '\%' . a:virtcol . 'v.*' .
    \   (a:isAllowSmaller ?
    \       '\%<' . (a:virtcol + a:width + 1) . 'v' :
    \       '\%' . (a:virtcol + a:width) . 'v'
    \)
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo
" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
autoload/ingo/register.vim	[[[1
85
" ingo/register.vim: Functions for accessing Vim registers.
"
" DEPENDENCIES:
"   - ingo/actions.vim autoload script
"
" Copyright: (C) 2013-2017 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>

function! ingo#register#All()
    return '[-a-zA-Z0-9":.%#=*+~/]'
endfunction
function! ingo#register#Writable()
    return '[-a-zA-Z0-9"*+_/]'
endfunction

function! ingo#register#Default()
    let l:values = split(&clipboard, ',')
    if index(l:values, 'unnamedplus') != -1
	return '+'
    elseif index(l:values, 'unnamed') != -1
	return '*'
    else
	return '"'
    endif
endfunction

function! ingo#register#KeepRegisterExecuteOrFunc( Action, ... )
"******************************************************************************
"* PURPOSE:
"   Commands in the executed a:Action do not modify the default register.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:Action    Either a Funcref or Ex commands to be :executed.
"   a:arguments Value(s) to be passed to the a:Action Funcref (but not the
"		Ex commands).
"* RETURN VALUES:
"   Result of evaluating a:Action, for Ex commands you need to use :return.
"******************************************************************************
    let l:save_clipboard = &clipboard
    set clipboard= " Avoid clobbering the selection and clipboard registers.
    if stridx(&cpoptions, 'y') != -1
	let l:save_cpoptions = &cpoptions
	set cpoptions-=y
    endif
    let l:save_reg = getreg('"')
    let l:save_regmode = getregtype('"')
    try
	return call('ingo#actions#ExecuteOrFunc', [a:Action] + a:000)
    finally
	call setreg('"', l:save_reg, l:save_regmode)
	if exists('l:save_cpoptions')
	    let &cpoptions = l:save_cpoptions
	endif
	let &clipboard = l:save_clipboard
    endtry
endfunction

function! ingo#register#GetAsList( register )
"******************************************************************************
"* PURPOSE:
"   Get the contents of a:register as a List of lines. For a linewise register,
"   there is no trailing empty element (so the returned List can be directly
"   passed to append(), and it will insert just like :put {reg}.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:register  Name of register.
"* RETURN VALUES:
"   List of lines.
"******************************************************************************
    let l:lines = split(getreg(a:register), '\n', 1)
    if len(l:lines) > 1 && empty(l:lines[-1])
	call remove(l:lines, -1)
    endif
    return l:lines
endfunction

" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
autoload/ingo/register/accumulate.vim	[[[1
57
" accumulate.vim: Functions for accumulating text in an uppercase register.
"
" DEPENDENCIES:
"   - ingo/actions.vim autoload script
"
" Copyright: (C) 2017 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>

function! ingo#register#accumulate#ExecuteOrFunc( register, Action, ... )
"******************************************************************************
"* PURPOSE:
"   Commands in the executed a:Action can append to any a:register; a temporary
"   uppercase register will be used as an intermediary if necessary.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   Any text appended to the uppercase register will be placed into a:register.
"* INPUTS:
"   a:Action    Either a Funcref or Ex commands to be :executed.
"   a:arguments Value(s) to be passed to the a:Action Funcref (but not the
"		Ex commands); the actual uppercase register will be passed as an
"		additional first argument. For Ex commands, each occurrence of
"		"v:val" is replaced with the uppercase register.
"* RETURN VALUES:
"   Result of evaluating a:Action, for Ex commands you need to use :return.
"******************************************************************************
    if a:register =~# '^\a$'
	let l:accumulator = a:register
    else
	let l:accumulator = 'z'
	let l:save_reg = getreg(l:accumulator)
	let l:save_regmode = getregtype(l:accumulator)
    endif
    if l:accumulator =~# '^\l$'
	call setreg(l:accumulator, '', 'v')
    endif

    try
	return call('ingo#actions#EvaluateWithValOrFunc', [a:Action, toupper(l:accumulator)] + a:000)
    finally
	if exists('l:save_reg')
	    let l:accumulatedText = getreg(l:accumulator)
	    call setreg(l:accumulator, l:save_reg, l:save_regmode)
	    call setreg(a:register, l:accumulatedText)
	endif

	if l:accumulator =~# '^\l$'
	    " When appending lines to an empty register, an initial newline
	    " is kept. We don't want that.
	    call setreg(a:register, substitute(getreg(a:register), '^\n', '', ''))
	endif
    endtry
endfunction

" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
autoload/ingo/search/buffer.vim	[[[1
20
" ingo/search/buffer.vim: Functions for searching a buffer.
"
" DEPENDENCIES:
"
" Copyright: (C) 2013 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
"
" REVISION	DATE		REMARKS
"   1.005.001	10-Apr-2013	file creation

function! ingo#search#buffer#IsKeywordMatch( text, startVirtCol )
    return search(
    \   printf('\C\V\%%%dv\<%s\>', a:startVirtCol, escape(a:text, '\')),
    \	'cnW', line('.')
    \)
endfunction

" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
autoload/ingo/search/pattern.vim	[[[1
37
" ingo/search/pattern.vim: Functions for the search pattern.
"
" DEPENDENCIES:
"
" Copyright: (C) 2011-2013 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
"
" REVISION	DATE		REMARKS
"   1.013.002	11-Sep-2013	Minor: Return last search pattern instead of
"				empty string on
"				ingo#search#pattern#GetLastForwardSearch(0).
"   1.006.001	24-May-2013	file creation

function! ingo#search#pattern#GetLastForwardSearch( ... )
"******************************************************************************
"* PURPOSE:
"   Get @/, or the a:count'th last search pattern, but also handle the case
"   where the pattern was set from a backward search, and doesn't have "/"
"   characters properly escaped.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:count Optional index into the end of the search history. 0 returns the
"   last search pattern, 1 the last from the history. (Usually, those should be
"   equal).
"* RETURN VALUES:
"   Last search pattern ready to use in a :s/{pat}/ command, with forward
"   slashes properly escaped.
"******************************************************************************
    return substitute((a:0 && a:1 ? histget('search', -1 * a:1) : @/), '\%(\%(^\|[^\\]\)\%(\\\\\)*\\\)\@<!/', '\\/', 'g')
endfunction

" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
autoload/ingo/search/timelimited.vim	[[[1
58
" ingo/search/timelimited.vim: Functions for time-limited searching.
"
" DEPENDENCIES:
"
" Copyright: (C) 2012-2019 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
"
" REVISION	DATE		REMARKS
"   1.003.002	26-Mar-2013	Move to ingo-library.
"	001	17-Oct-2012	file creation

if v:version < 702 || ! has('reltime')
function! ingo#search#timelimited#GetSearchArguments( timeout )
    " Limit searching to a maximum number of lines after the cursor.
    " Assume that 10000 lines can be searched per second; this depends greatly
    " on the CPU, regexp, and line length.
    return [(a:timeout == 0 ? 0 : line('.') + a:timeout * 10)]
endfunction
else
function! ingo#search#timelimited#GetSearchArguments( timeout )
    return [0, a:timeout]
endfunction
endif

function! ingo#search#timelimited#search( pattern, flags, ... )
    let l:timeout = (a:0 ? a:1 : 100)
    return call('search', [a:pattern, a:flags] + ingo#search#timelimited#GetSearchArguments(l:timeout))
endfunction
function! ingo#search#timelimited#IsBufferContains( pattern, ... )
    return call('ingo#search#timelimited#search', [a:pattern, 'cnw'] + a:000)
endfunction
function! ingo#search#timelimited#FirstPatternThatMatchesInBuffer( patterns, ... )
"******************************************************************************
"* PURPOSE:
"   Search for matches of any of a:patterns in the buffer, and return the first
"   pattern that matches.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:patterns  List of regular expressions.
"   a:timeout   Optional timeout in milliseconds; default 100.
"* RETURN VALUES:
"   First pattern from a:patterns that matches somewhere in the current buffer,
"   or empty String.
"******************************************************************************
    for l:pattern in a:patterns
	if call('ingo#search#timelimited#search', [l:pattern, 'cnw'] + a:000)
	    return l:pattern
	endif
    endfor
    return ''
endfunction

" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
autoload/ingo/selection.vim	[[[1
103
" ingo/selection.vim: Functions for accessing the visually selected text.
"
" DEPENDENCIES:
"
" Copyright: (C) 2011-2019 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
"
" REVISION	DATE		REMARKS
"   1.013.002	05-Sep-2013	Also avoid clobbering the last change ('.') in
"				ingo#selection#Get() when 'cpo' contains "y".
"   1.006.001	24-May-2013	file creation from ingointegration.vim.

function! ingo#selection#Get()
"******************************************************************************
"* PURPOSE:
"   Retrieve the contents of the current visual selection without clobbering any
"   register and the last change.
"* ASSUMPTIONS / PRECONDITIONS:
"   Visual selection is / has been made.
"* EFFECTS / POSTCONDITIONS:
"   Moves the cursor to the beginning of the selected text.
"   Clobbers v:count.
"* INPUTS:
"   None.
"* RETURN VALUES:
"   Text of visual selection.
"* SEE ALSO:
"   To execute an action while keeping the default register contents, use
"   ingo#register#KeepRegisterExecuteOrFunc().
"   To retrieve the contents of lines in a range, use ingo#range#Get().
"******************************************************************************
    let l:save_clipboard = &clipboard
    set clipboard= " Avoid clobbering the selection and clipboard registers.
    if stridx(&cpoptions, 'y') != -1
	let l:save_cpoptions = &cpoptions
	set cpoptions-=y
    endif
	let l:save_reg = getreg('"')
	let l:save_regmode = getregtype('"')
	    execute 'silent! keepjumps normal! gvy'
	    let l:selection = @"
	call setreg('"', l:save_reg, l:save_regmode)
    if exists('l:save_cpoptions')
	let &cpoptions = l:save_cpoptions
    endif
    let &clipboard = l:save_clipboard

    return l:selection
endfunction

function! ingo#selection#Set( startPos, endPos, ... ) abort
"******************************************************************************
"* PURPOSE:
"   Sets the visual selection to the passed area.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   Affects what the next gv command will select.
"* INPUTS:
"   a:startPos  [lnum, col] or [0, lnum, col, 0] of the start ('<) of the new
"               selection.
"   a:endPos    [lnum, col] or [0, lnum, col, 0] of the end ('>) of the new
"               selection.
"   a:mode      One of v, V, or CTRL-V. Defaults to characterwise.
"* RETURN VALUES:
"   1 if successful, 0 if one position could not be set.
"******************************************************************************
    let l:mode = (a:0 ? a:1 : 'v')
    if visualmode() !=# l:mode && ! empty(l:mode)
	execute 'normal!' l:mode . "\<Esc>"
    endif
    let l:result = 0
    let l:result += ingo#compat#setpos("'<", ingo#pos#Make4(a:startPos))
    let l:result += ingo#compat#setpos("'>", ingo#pos#Make4(a:endPos))

    return (l:result == 0)
endfunction
function! ingo#selection#Make( ... ) abort
"******************************************************************************
"* PURPOSE:
"   Creates a new visual selection on the passed area.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   Changes to visual mode.
"* INPUTS:
"   a:startPos  [lnum, col] of the start ('<) of the new selection.
"   a:endPos    [lnum, col] of the end ('>) of the new selection.
"   a:mode      One of v, V, or CTRL-V. Defaults to characterwise.
"* RETURN VALUES:
"   1 if successful, 0 if one position could not be set.
"******************************************************************************
    if call('ingo#selection#Set', a:000) == 0
	normal! gv
	return 1
    else
	return 0
    endif
endfunction

" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
autoload/ingo/selection/area.vim	[[[1
58
" ingo/selection/area.vim: Functions for getting the area of the selection.
"
" DEPENDENCIES:
"   - ingo/pos.vim autoload script
"
" Copyright: (C) 2013-2019 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>

function! ingo#selection#area#Get( ... )
"******************************************************************************
"* PURPOSE:
"   Get the start and end position of the current selection. The end position is
"   always _on_ the last selected character, even when 'selection' is
"   "exclusive'.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:options.isClipLinewise	        Optional flag whether the end column of
"					linewise selections should be clipped to
"					the last character before the newline.
"					Else, the end column will be 0x7FFFFFFF
"					for linewise selections. Default on.
"   a:options.returnValueOnNoSelection  Optional return value if no selection
"					has yet been made. If omitted, [[0, 0],
"					[0, 0]] will be returned.
"* RETURN VALUES:
"   [[startLnum, startCol], [endLnum, endCol]], or a:returnValueOnNoSelection
"   endCol points to the last character, not beyond it!
"******************************************************************************
    let l:options = (a:0 ? a:1 : {})
    let l:isClipLinewise = get(l:options, 'isClipLinewise', 1)

    let l:startPos = getpos("'<")[1:2]
    let l:endPos = getpos("'>")[1:2]
    if l:startPos == [0, 0] && l:endPos == [0, 0]
	return get(l:options, 'returnValueOnNoSelection', [l:startPos, l:endPos])
    endif

    if &selection ==# 'exclusive'
	let l:isCursorAfterSelection = ingo#pos#IsOnOrAfter(getpos('.')[1:2], l:endPos)
	let l:searchPos = searchpos('\_.\%''>', (l:isCursorAfterSelection ? 'b' : '') . 'cnW', line("'>") + (l:isCursorAfterSelection ? -1 : 0))
	if l:searchPos != [0, 0] " This happens with a linewise selection, where col = 0x7FFFFFFF. No need to adapt that.
	    let l:endPos = l:searchPos
	endif
    endif

    if l:isClipLinewise
	let l:endPos[1] = min([len(getline(l:endPos[0])), l:endPos[1]])
    endif

    return [l:startPos, l:endPos]
endfunction

" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
autoload/ingo/selection/frompattern.vim	[[[1
92
" ingo/selection/frompattern.vim: Functions to select around the cursor based on a regexp.
"
" DEPENDENCIES:
"
" Copyright: (C) 2013-2014 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
"
" REVISION	DATE		REMARKS
"   1.023.003	01-Oct-2014	ENH: Make
"				ingo#selection#frompattern#GetPositions()
"				automatically convert \%# in the passed
"				a:pattern to the hard-coded cursor column.
"   1.012.002	07-Aug-2013	CHG: Change return value format of
"				ingo#selection#frompattern#GetPositions() to
"				better match the arguments of functions like
"				ingo#text#Get().
"   1.011.001	23-Jul-2013	file creation from ingointegration.vim.

function! ingo#selection#frompattern#GetPositions( pattern, ... )
"******************************************************************************
"* PURPOSE:
"   Similar to <cword>, get the selection under / after the cursor that matches
"   a:pattern.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:pattern   Regular expression to match at the cursor position.
"   a:stopline  Optional line number where the search will stop. To get a
"		behavior like <cword>, pass in line('.').
"   a:timeout   Optional timeout when the search will stop.
"* RETURN VALUES:
"   [[startLnum, startCol], [endLnum, endCol]] or [[0, 0], [0, 0]]
"******************************************************************************
    " To match the cursor position itself, the \%# atom cannot be used directly
    " (because of the jumping around); instead, the current cursor column must
    " be hard-coded.
    let l:pattern = substitute(a:pattern, '\%(\%(^\|[^\\]\)\%(\\\\\)*\\\)\@<!\\%#', '\\%' . col('.') . 'c', 'g')

    let l:selection = [[0, 0], [0, 0]]
    let l:save_view = winsaveview()
	let l:endPos = call('searchpos', [l:pattern, 'ceW'] + a:000)
	if l:endPos == [0, 0]
	    return l:selection
	endif

	let l:startPos = call('searchpos', [l:pattern, 'bcnW'] + a:000)
	if l:startPos != [0, 0]
	    let l:selection = [l:startPos, l:endPos]
	endif
    call winrestview(l:save_view)

    return l:selection
endfunction

function! ingo#selection#frompattern#Select( selectMode, pattern, ... )
"******************************************************************************
"* PURPOSE:
"   Similar to <cword>, create a visual selection of the text region under /
"   after the cursor that matches a:pattern.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   Creates a visual selection if a:pattern matches.
"* INPUTS:
"   a:selectMode    Visual selection mode, one of "v", "V", or "\<C-v>".
"   a:pattern   Regular expression to match at the cursor position.
"   a:stopline  Optional line number where the search will stop. To get a
"		behavior like <cword>, pass in line('.').
"   a:timeout   Optional timeout when the search will stop.
"* RETURN VALUES:
"   1 if a selection was made, 0 if there was no match.
"******************************************************************************
    let [l:startPos, l:endPos] = call('ingo#selection#frompattern#GetPositions', [a:pattern] + a:000)
    if l:startPos == [0, 0]
	return 0
    endif
    call cursor(l:startPos[0], l:startPos[1])
    execute 'normal! zv' . a:selectMode
    call cursor(l:endPos[0], l:endPos[1])
    if &selection ==# 'exclusive'
	normal! l
    endif
    execute "normal! \<Esc>"

    return 1
endfunction

" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
autoload/ingo/selection/patternmatch.vim	[[[1
37
" ingo/selection/patternmatch.vim: Functions for matching inside the visual selection with \%V.
"
" DEPENDENCIES:
"
" Copyright: (C) 2013-2014 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
"
" REVISION	DATE		REMARKS
"   1.006.001	23-May-2013	file creation

function! ingo#selection#patternmatch#AdaptEmptySelection()
"******************************************************************************
"* PURPOSE:
"   With :set selection=exclusive, one can create an empty selection with |v| or
"   |CTRL-V|. The |/\%V| atom does not match anywhere then. However, (built-in)
"   commands like gU do work on one selected character. For consistency, custom
"   mappings should, too. Invoke this function at the beginning of your mapping
"   to adapt the selection in this special case. You can then use a pattern with
"   |/\%V| without worrying.
"* ASSUMPTIONS / PRECONDITIONS:
"   A visual selection has previously been established.
"* EFFECTS / POSTCONDITIONS:
"   Changes the visual selection.
"   Clobbers v:count when active.
"* INPUTS:
"   None.
"* RETURN VALUES:
"   None.
"******************************************************************************
    if &selection ==# 'exclusive' && virtcol("'<") == virtcol("'>")
	silent! execute "normal! gvl\<Esc>"
    endif
endfunction

" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
autoload/ingo/selection/virtcols.vim	[[[1
66
" ingo/selection/virtcols.vim: Functions for defining a visual selection based on virtual columns.
"
" DEPENDENCIES:
"   - ingo/cursor.vim autoload script
"
" Copyright: (C) 2018 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>

function! ingo#selection#virtcols#Get()
"******************************************************************************
"* PURPOSE:
"   Get a selectionObject that contains information about the cell-based,
"   virtual screen columns that the current visual selection occupies.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   None.
"* RETURN VALUES:
"   a:selection object
"******************************************************************************
    return {'mode': visualmode(), 'startLnum': line("'<"), 'startVirtCol': virtcol("'<"), 'endLnum': line("'>"), 'endVirtCol': virtcol("'>")}
endfunction

function! ingo#selection#virtcols#DefineAndExecute( selectionObject, command )
"******************************************************************************
"* PURPOSE:
"   Set / restore the visual selection based on the passed a:selectionObject and
"   execute a:command on it.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   Sets the visual selection.
"   Executes a:command.
"* INPUTS:
"   a:selectionObject   Obtained from ingo#selection#virtcols#Get().
"   a:command           Ex command to work on the visual selection, e.g.
"			'normal! y' to yank the contents.
"* RETURN VALUES:
"   None.
"******************************************************************************
    call ingo#cursor#Set(a:selectionObject.startLnum, a:selectionObject.startVirtCol)
    execute 'normal!' a:selectionObject.mode
    call ingo#cursor#Set(a:selectionObject.endLnum, a:selectionObject.endVirtCol)
    execute a:command
endfunction
function! ingo#selection#virtcols#Set( selectionObject )
"******************************************************************************
"* PURPOSE:
"   Set / restore the visual selection based on the passed a:selectionObject.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   Sets the visual selection.
"* INPUTS:
"   a:selectionObject   Obtained from ingo#selection#virtcols#Get().
"* RETURN VALUES:
"   None.
"******************************************************************************
    call ingo#selection#virtcols#DefineAndExecute(a:selectionObject, "normal! \<Esc>")
endfunction

" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
autoload/ingo/smartcase.vim	[[[1
70
" ingo/smartcase.vim: Functions for SmartCase searches.
"
" DEPENDENCIES:
"
" Copyright: (C) 2014 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
"
" REVISION	DATE		REMARKS
"   1.021.003	24-Jun-2014	ENH: For a single word that so far didn't change
"				the SmartCase pattern, allow for an optional
"				preceding or trailing non-alphabetic keyword
"				separator. This makes the
"				ChangeGloballySmartCase replacement of "foo"
"				also work correctly on FOO_BAR.
"   1.021.002	20-Jun-2014	Also handle regexp atoms in
"				ingo#smartcase#FromPattern(). This isn't
"				required by the (literal text, very nomagic)
"				original use case, but for the arbitrary
"				patterns in CmdlineSpecialEdits.vim.
"   1.021.001	20-Jun-2014	file creation from plugin/ChangeGloballySmartCase.vim
let s:save_cpo = &cpo
set cpo&vim

function! ingo#smartcase#IsSmartCasePattern( pattern )
    return (a:pattern =~# '\%(\%(^\|[^\\]\)\%(\\\\\)*\\\)\@<!\\c' && a:pattern =~# '\%(\%(^\|[^\\]\)\%(\\\\\)*\\\)\@<!\\A\\[?=]')
endfunction
function! s:Escape( atom )
    " Anything larger than two characters is a special regexp atom that must be
    " kept as-is.
    return (len(a:atom) > 2 ? a:atom : '\A\=')
endfunction
function! ingo#smartcase#FromPattern( pattern, ... )
    let l:pattern = a:pattern
    let l:additionalEscapeCharacters = (a:0 ? a:1 : '')

    " Make all non-alphabetic delimiter characters and whitespace optional.
    " Keep any regexp atoms, like \<, \%# (the 3+ character ones must be
    " explicitly matched).
    " As backslashes are escaped, they must be handled separately. Same for any
    " escaped substitution separator.
    let l:pattern = substitute(l:pattern, '\%(\%(^\|[^\\]\)\%(\\\\\)*\\\)\@<!\%(\\\@!\A\)\|' .
    \   '\%(\%(^\|[^\\]\)\%(\\\\\)*\\\)\@<!\\\%([' . l:additionalEscapeCharacters . '\\]\|' .
    \       '%[$^#<>(]\|%[<>]\?''\|@\%(=\|!\|<=\|<!\|>\)\|_[\[$^.]\|{[-[:digit:],]*}' .
    \   '\)',
    \   '\=s:Escape(submatch(0))', 'g'
    \)
    " Allow delimiters between CamelCase fragments to catch all variants.
    let l:pattern = substitute(l:pattern, '\%(\%(^\|[^\\]\)\%(\\\\\)*\\\)\@<!\(\l\)\(\u\)', '\1\\A\\=\2', 'g')

    if l:pattern ==# a:pattern
	" The smartcase'ing failed to extend the pattern. This is a single
	" all-lower or -uppercase alphabetic word. Allow for an optional
	" preceding or trailing non-alphabetic keyword separator.
	" Limit to keywords here to only match stuff like "_", but not arbitrary
	" stuff around (e.g. "'foo" in "'foo bar'", which would result in
	" "'foo'quux bar" instead of the desired "'fooQuux bar").
	let l:pattern = printf('\%%(\%%(\A\&\k\)\=%s\|%s\%%(\A\&\k\)\=\)', l:pattern, l:pattern)
    endif

    return '\c' . l:pattern
endfunction
function! ingo#smartcase#Undo( smartCasePattern )
    return substitute(a:smartCasePattern, '\%(\%(^\|[^\\]\)\%(\\\\\)*\\\)\@<!\\\(c\|A\\[?=]\)', '', 'g')
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo
" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
autoload/ingo/str.vim	[[[1
148
" ingo/str.vim: String functions.
"
" DEPENDENCIES:
"   - ingo/regexp/collection.vim autoload script
"   - ingo/regexp/virtcols.vim autoload script
"   - ingo/str/list.vim autoload script
"
" Copyright: (C) 2013-2019 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>

function! ingo#str#Trim( string )
"******************************************************************************
"* PURPOSE:
"   Remove all leading and trailing whitespace from a:string.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:string    Text.
"* RETURN VALUES:
"   a:string with leading and trailing whitespace removed.
"******************************************************************************
    return substitute(a:string, '^\_s*\(.\{-}\)\_s*$', '\1', '')
endfunction
function! ingo#str#TrimPattern( string, pattern, ... )
"******************************************************************************
"* PURPOSE:
"   Remove leading and trailing matches of a:pattern from a:string.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:string    Text.
"   a:pattern   Regular expression. Must not use capture groups itself.
"   a:pattern2  Regular expression. If given, a:pattern is only used for the
"               leading matches, and a:pattern2 is used for trailing matches.
"               Must not use capture groups itself.
"* RETURN VALUES:
"   a:string with leading and trailing matches of a:pattern removed.
"******************************************************************************
    return substitute(a:string, '^\%(' . a:pattern . '\)*\(.\{-}\)\%(' . (a:0 ? a:1 : a:pattern) . '\)*$', '\1', '')
endfunction

function! ingo#str#Reverse( string )
    return join(reverse(ingo#str#list#OfCharacters(a:string)), '')
endfunction

function! ingo#str#StartsWith( string, substring, ... )
    let l:ignorecase = (a:0 && a:1)
    if l:ignorecase
	return (strpart(a:string, 0, len(a:substring)) ==? a:substring)
    else
	return (strpart(a:string, 0, len(a:substring)) ==# a:substring)
    endif
endfunction
function! ingo#str#EndsWith( string, substring, ... )
    let l:ignorecase = (a:0 && a:1)
    if l:ignorecase
	return (strpart(a:string, len(a:string) - len(a:substring)) ==? a:substring)
    else
	return (strpart(a:string, len(a:string) - len(a:substring)) ==# a:substring)
    endif
endfunction

function! ingo#str#Equals( string1, string2, ...)
    let l:ignorecase = (a:0 && a:1)
    if l:ignorecase
	return a:string1 ==? a:string2
    else
	return a:string1 ==# a:string2
    endif
endfunction
function! ingo#str#Contains( string, part, ...)
    let l:ignorecase = (a:0 && a:1)
    if l:ignorecase
	return (stridx(a:string, a:part) != -1 || a:string =~? '\V' . escape(a:part, '\'))
    else
	return (stridx(a:string, a:part) != -1)
    endif
endfunction

function! ingo#str#GetVirtCols( string, virtcol, width, isAllowSmaller )
"******************************************************************************
"* PURPOSE:
"   Get a:width screen columns of a:string at a:virtcol.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:virtcol   First virtual column (first column is 1); the character must
"		begin exactly at that column.
"   a:width     Width in screen columns.
"   a:isAllowSmaller    Boolean flag whether less characters can be matched if
"			the end doesn't fall on a character border, or there
"			aren't that many characters. Else, exactly a:width
"			screen columns must be matched.
"* RETURN VALUES:
"   Text starting at a:virtcol with a (maximal) width of a:width.
"******************************************************************************
    if a:virtcol < 1
	throw 'GetVirtCols: Column must be at least 1'
    endif
    return matchstr(a:string, ingo#regexp#virtcols#ExtractCells(a:virtcol, a:width, a:isAllowSmaller))
endfunction

function! ingo#str#trd( src, fromstr )
"******************************************************************************
"* PURPOSE:
"   Delete characters in a:fromstr in a copy of a:src. Like tr -d, but the
"   built-in tr() doesn't support this.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:src   Source string.
"   a:fromstr   Characters that will each be removed from a:src.
"* RETURN VALUES:
"   Copy of a:src that has all instances of the characters in a:fromstr removed.
"******************************************************************************
    return substitute(a:src, '\C' . ingo#regexp#collection#LiteralToRegexp(a:fromstr), '', 'g')
endfunction

function! ingo#str#Wrap( string, commonOrPrefix, ... ) abort
"******************************************************************************
"* PURPOSE:
"   Surround a:string with a prefix + suffix or a common string.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:string    Text.
"   a:commonOrPrefix    Text to be put in front of a:string, and unless a:suffix
"                       is also given, also at the back.
"   a:suffix            Optional different text to be put at the back.
"* RETURN VALUES:
"   a:string with prefix and suffix text.
"******************************************************************************
    return a:commonOrPrefix . a:string . (a:0 ? a:1 : a:commonOrPrefix)
endfunction

" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
autoload/ingo/str/find.vim	[[[1
77
" ingo/str/find.vim: Functions to find stuff in a string.
"
" DEPENDENCIES:
"   - ingo/str.vim autoload script
"
" Copyright: (C) 2016-2017 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
"
" REVISION	DATE		REMARKS
"   1.029.001	14-Dec-2016	file creation

function! ingo#str#find#NotContaining( string, characterSet )
"******************************************************************************
"* PURPOSE:
"   Find the first character of a:characterSet not contained in a:string.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:string    Source string to be inspected.
"   a:characterSet  String or List of candidate characters.
"* RETURN VALUES:
"   First character in a:characterSet that is not contained in a:string, or
"   empty string if all characters are contained.
"******************************************************************************
    for l:candidate in (type(a:characterSet) == type([]) ? a:characterSet : split(a:characterSet, '\zs'))
	if stridx(a:string, l:candidate) == -1
	    return l:candidate
	endif
    endfor
    return ''
endfunction

function! ingo#str#find#StartIndex( haystack, needle, ... )
"******************************************************************************
"* PURPOSE:
"   Find the byte index in a:haystack of the first occurrence of a:needle
"   (starting the search at a:options.start, with a:options.ignorecase),
"   reducing a:needle's size from the end (until a:options.minMatchLength) to
"   fit what's left of a:haystack.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:haystack  String to be searched.
"   a:needle    String that is searched for. Characters are cut off at the end
"		if the search is farther down a:haystack so that the entire
"		a:needle wouldn't fit into it any longer.
"   a:options.minMatchLength    Minimum length of a:needle that must still match
"				in a:haystack; default is 1.
"   a:options.index             Index at which searching starts in a:haystack.
"   a:options.ignorecase        Flag whether searching is case-insensitive.
"* RETURN VALUES:
"   Byte index in a:haystack where (the remainder of) a:needle matches, or -1.
"******************************************************************************
    let l:options = (a:0 ? a:1 : {})
    let l:minMatchLength = get(l:options, 'minMatchLength', 1)
    let l:index = get(l:options, 'index', 0)
    let l:ignorecase = get(l:options, 'ignorecase', 0)

    while l:index + l:minMatchLength <= len(a:haystack)
	let l:straw = strpart(a:haystack, l:index)
	if ingo#str#StartsWith(l:straw, strpart(a:needle, 0, len(l:straw)), l:ignorecase)
	    return l:index
	endif

	let l:index += len(matchstr(l:straw, '^.'))
    endwhile

    return -1
endfunction

" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
autoload/ingo/str/frompattern.vim	[[[1
89
" ingo/str/frompattern.vim: Functions to get matches from a string.
"
" DEPENDENCIES:
"   - ingo/collections.vim autoload script
"
" Copyright: (C) 2014 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
"
" REVISION	DATE		REMARKS
"   1.023.001	30-Dec-2014	file creation
let s:save_cpo = &cpo
set cpo&vim

function! ingo#str#frompattern#Get( text, pattern, replacement, isOnlyFirstMatch, isUnique )
"******************************************************************************
"* PURPOSE:
"   Extract all non-overlapping matches of a:pattern in a:text and return them
"   (optionally a submatch / replacement, or only first or unique matches) as a
"   List.
"* SEE ALSO:
"   - ingo#text#frompattern#Get() extracts matches directly from a range of
"     lines.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:text          Source text, either a String (potentially with newlines), or
"		    a List of lines.
"   a:pattern       Regular expression to search. 'ignorecase' applies;
"		    'smartcase' and 'magic' don't. When empty, the last search
"		    pattern |"/| is used.
"   a:replacement   Optional replacement substitute(). When not empty, each
"		    match is processed through substitute() with a:pattern.
"		    You can also pass a [replPattern, replacement] tuple, which
"		    will then be globally applied to the match.
"   a:isOnlyFirstMatch  Flag whether to include only the first match in every
"			line.
"   a:isUnique          Flag whether duplicate matches are omitted from the
"			result. When set, the result will consist of unique
"			matches.
"* RETURN VALUES:
"   List of (optionally replaced) matches, or empty List when no matches.
"******************************************************************************
    let l:matches = []
    let l:pattern = (empty(a:pattern) ? @/ : a:pattern)

    if a:isOnlyFirstMatch
	" Need to process each line separately to only extract first matches.
	let l:source = (type(a:text) == type([]) ? a:text : split(a:text, '\n', 1))
	call map(
	\   l:source,
	\   'substitute(v:val, l:pattern, "\\=s:Collect(l:matches, a:isUnique)", "")'
	\)
    else
	let l:source = (type(a:text) == type([]) ? join(a:text, "\n") : a:text)
	call substitute(l:source, l:pattern, '\=s:Collect(l:matches, a:isUnique)', 'g')
    endif

    if ! empty(a:replacement)
	call map(
	\   l:matches,
	\   'type(a:replacement) == type([]) ?' .
	\       'substitute(v:val, a:replacement[0], a:replacement[1], "g") :' .
	\       'substitute(v:val, l:pattern, a:replacement, "")'
	\)

	if a:isUnique
	    " The replacement may have mapped different matches to the same
	    " replacement; need to restore the uniqueness.
	    let l:matches = ingo#collections#UniqueStable(l:matches)
	endif
    endif

    return l:matches
endfunction
function! s:Collect( accumulatorMatches, isUnique )
    let l:match = submatch(0)
	if ! a:isUnique || index(a:accumulatorMatches, l:match) == -1
	    call add(a:accumulatorMatches, l:match)
	endif
    return l:match
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo
" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
autoload/ingo/str/fromrange.vim	[[[1
123
" ingo/str/fromrange.vim: Functions to create strings by transforming codepoint ranges.
"
" DEPENDENCIES:
"
" Copyright: (C) 2016 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
"
" REVISION	DATE		REMARKS
"   1.029.002	28-Dec-2016	Split off
"				ingo#str#fromrange#GetTranslationStrings() from
"				ingo#str#fromrange#Tr().
"   1.029.001	14-Dec-2016	file creation from subs/Homoglyphs.vim

function! ingo#str#fromrange#GetAsList( ... )
"******************************************************************************
"* PURPOSE:
"   Get a List of characters with codepoints in the passed range.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:expr [, a:max [, a:stride]], as with |range()|.
"* RETURN VALUES:
"   List of characters.
"******************************************************************************
    return map(call('range', a:000), 'nr2char(v:val)')
endfunction
function! ingo#str#fromrange#Get( ... )
"******************************************************************************
"* PURPOSE:
"   Get a string of characters with codepoints in the passed range.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:expr [, a:max [, a:stride]], as with |range()|.
"* RETURN VALUES:
"   String of characters.
"******************************************************************************
    return join(map(call('range', a:000), 'nr2char(v:val)'), '')
endfunction


function! s:RangeToString( start, end )
    return join(
    \   map(
    \       range(a:start, a:end),
    \       'nr2char(v:val)'
    \   ),
    \   ''
    \)
endfunction
function! ingo#str#fromrange#GetTranslationStrings( mirrorMode, ranges )
"******************************************************************************
"* PURPOSE:
"   Generate source and destination character ranges from a:ranges.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:mirrorMode    0: Do not mirror
"		    1: Mirror a:range so that translation also works in the
"		       other direction.
"		    2: Only mirror, i.e. only translate back.
"   a:ranges        List of ranges; one of (also mixed) [source, destination] or
"		    [start, end, transformStart] codepoints.
"* RETURN VALUES:
"   [sourceRangeString, destinationRangeString]
"******************************************************************************
    let l:sources = ''
    let l:destinations = ''

    for l:range in a:ranges
	if len(l:range) == 3
	    let [l:start, l:end, l:transformStart] = l:range
	    let s = s:RangeToString(l:start, l:end)
	    let d = s:RangeToString(l:transformStart, l:transformStart + l:end - l:start)
	elseif len(l:range) == 2
	    let [s, d] = [nr2char(l:range[0]), nr2char(l:range[1])]
	else
	    throw 'ASSERT: Must pass either [start, end, transformStart] or [source, destination].'
	endif

	if a:mirrorMode != 2
	    let l:sources .= s
	    let l:destinations .= d
	endif
	if a:mirrorMode > 0
	    let l:sources .= d
	    let l:destinations .= s
	endif
    endfor

    return [l:sources, l:destinations]
endfunction
function! ingo#str#fromrange#Tr( text, mirrorMode, ranges )
"******************************************************************************
"* PURPOSE:
"   Translate the character ranges in a:ranges in a:text.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:text  Text to be modified.
"   a:mirrorMode    0: Do not mirror
"		    1: Mirror a:range so that translation also works in the
"		       other direction.
"		    2: Only mirror, i.e. only translate back.
"   a:ranges        List of ranges; one of (also mixed) [source, destination] or
"		    [start, end, transformStart] codepoints.
"* RETURN VALUES:
"   Modified a:text.
"******************************************************************************
    return call('tr', [a:text] + ingo#str#fromrange#GetTranslationStrings(a:mirrorMode, a:ranges))
endfunction

" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
autoload/ingo/str/join.vim	[[[1
17
" ingo/str/join.vim: Functions for joining lists of strings.
"
" DEPENDENCIES:
"
" Copyright: (C) 2015 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
"
" REVISION	DATE		REMARKS
"   1.024.001	24-Feb-2015	file creation

function! ingo#str#join#NonEmpty( list, ... )
    return call('join', [filter(a:list, '! empty(v:val)')] + a:000)
endfunction

" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
autoload/ingo/str/list.vim	[[[1
26
" ingo/str/list.vim: Functions for dealing with Strings as Lists.
"
" DEPENDENCIES:
"
" Copyright: (C) 2018 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>

function! ingo#str#list#OfCharacters( string )
    return split(a:string, '\zs')
endfunction

function! ingo#str#list#OfBytes( string )
    let l:i = 0
    let l:len = len(a:string)
    let l:list = []
    while l:i < l:len
	call add(l:list, a:string[l:i])
	let l:i += 1
    endwhile

    return l:list
endfunction

" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
autoload/ingo/str/restricted.vim	[[[1
114
" ingo/str/restricted.vim: Functions to restrict arbitrary strings to certain classes.
"
" DEPENDENCIES:
"   - ingo/compat.vim autoload script
"
" Copyright: (C) 2014-2017 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
"
" REVISION	DATE		REMARKS
"   1.017.001	28-Feb-2014	file creation

function! ingo#str#restricted#ToShortCharacterwise( expr, ... )
"******************************************************************************
"* PURPOSE:
"   Restrict an arbitrary string a:expr to a short, readable text.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:expr  Source text.
"   a:default   Text to be used when the source text doesn't fit the
"		requirements of being "short". Defaults to the empty string.
"   a:maxCharacterNum   Maximum width to be considered "short". Defaults to
"			'textwidth' / 80 screen cells.
"* RETURN VALUES:
"   If a:expr is short enough and does not contain multi-line text, return
"   a:expr. Else return nothing / the a:default.
"******************************************************************************
    let l:default = (a:0 ? a:1 : '')
    let l:maxCharacterNum = (a:0 > 1 ? a:2 : (&textwidth > 0 ? &textwidth : 80))

    return (a:expr =~# '\n' || ingo#compat#strchars(a:expr) > l:maxCharacterNum ? l:default : a:expr)
endfunction

function! ingo#str#restricted#ToSafeIdentifier( expr, ...)
"******************************************************************************
"* PURPOSE:
"   Restrict an arbitrary string a:expr to a short one that can be safely used
"   in filenames, URLs, etc. without having to worry about quoting or escaping
"   of special characters.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:expr  Source text, or List of strings.
"   a:options.replacementForSpecialCharacters	Replacement character; default "-".
"   a:options.removeFrom    Which position has the lowest priority in case the
"			    result is still too long, and is dropped. One of
"			    "l", "m", "r"; default is "m", dropping from the
"			    middle.
"   a:options.maxCharacterNum   Maximum width. Defaults to 'textwidth' / 80
"				screen cells.
"* RETURN VALUES:
"   Non-alphanumeric characters are replaced by
"   a:options.replacementForSpecialCharacters (two between different List items); those
"   at the front and end are dropped. If the text exceeds a:maxCharacterNum,
"   List elements / alphanumeric sequences from the middle are dropped until it
"   fits.
"******************************************************************************
    let l:options = (a:0 ? a:1 : {})
    let l:repl = get(l:options, 'replacementForSpecialCharacters', '-')
    let l:removeFrom = get(l:options, 'removeFrom', 'm')
    let l:maxCharacterNum = get(l:options, 'maxCharacterNum', &textwidth > 0 ? &textwidth : 80)

    if type(a:expr) == type([])
	let l:source = map(a:expr, 'l:repl . join(split(v:val, "[^[:alnum:]]\\+"), l:repl) . l:repl')
    else
	let l:source = split(a:expr, "[^[:alnum:]]\\+")
    endif

    while ingo#compat#strchars(s:Render(l:source, l:repl)) > l:maxCharacterNum
	if l:removeFrom ==# 'm' && len(l:source) == 2
	    " Special case: take the larger one that still fits.
	    let l:len0 = ingo#compat#strchars(s:Render([l:source[0]], l:repl))
	    let l:len1 = ingo#compat#strchars(s:Render([l:source[1]], l:repl))

	    if l:len0 >= l:len1 && l:len0 <= l:maxCharacterNum
		let l:source = [l:source[0]]
	    elseif l:len1 >= l:len0 && l:len1 <= l:maxCharacterNum
		let l:source = [l:source[1]]
	    else
		let l:source = [l:source[(l:len0 > l:len1 ? 1 : 0)]]
	    endif
	elseif len(l:source) > 1
	    if l:removeFrom ==# 'm'
		let l:dropIdx = len(l:source) / 2
	    elseif l:removeFrom ==# 'l'
		let l:dropIdx = 0
	    elseif l:removeFrom ==# 'r'
		let l:dropIdx = -1
	    else
		throw 'ASSERT: Invalid a:options.removeFrom: ' . string(l:removeFrom)
	    endif
	    call remove(l:source, l:dropIdx)
	elseif stridx(l:source[0], l:repl) != -1
	    " The part can be broken into sub-parts.
	    let l:source = split(l:source[0], '\V\C' . escape(l:repl, '\'))
	else
	    return matchstr(s:Render(l:source, l:repl), '^.\{' . l:maxCharacterNum . '}')
	endif
    endwhile
    return s:Render(l:source, l:repl)
endfunction
function! s:Render( source, repl )
    let l:render = join(a:source, a:repl)
    let l:r = escape(a:repl, '\')
    return substitute(l:render, printf('\V\C\^%s\+\|%s\+\$\|%s\{2}\zs%s\+', l:r, l:r, l:r, l:r), '', 'g')
endfunction

" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
autoload/ingo/str/split.vim	[[[1
110
" ingo/str/split.vim: Functions for splitting strings.
"
" DEPENDENCIES:
"   - ingo/str.vim autoload script
"
" Copyright: (C) 2013-2018 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
let s:save_cpo = &cpo
set cpo&vim

function! ingo#str#split#StrFirst( expr, str )
"******************************************************************************
"* PURPOSE:
"   Split a:expr into the text before and after the first occurrence of a:str.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:expr  Text to be split.
"   a:str   The literal text to split on.
"* RETURN VALUES:
"   Tuple of [beforeStr, afterStr].
"   When there's no occurrence of a:str, the returned tuple is [a:expr, ''].
"******************************************************************************
    let l:startIdx = stridx(a:expr, a:str)
    if l:startIdx == -1
	return [a:expr, '']
    endif

    let l:endIdx = l:startIdx + len(a:str)
    return [strpart(a:expr, 0, l:startIdx), strpart(a:expr, l:endIdx)]
endfunction
function! ingo#str#split#MatchFirst( expr, pattern )
"******************************************************************************
"* PURPOSE:
"   Split a:expr into the text before and after the first match of a:pattern.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:expr  Text to be split.
"   a:pattern	The pattern to split on; 'ignorecase' applies.
"* RETURN VALUES:
"   Tuple of [beforeMatch, matchedText, afterMatch].
"   When there's no match of a:pattern, the returned tuple is [a:expr, '', ''].
"******************************************************************************
    let l:startIdx = match(a:expr, a:pattern)
    if l:startIdx == -1
	return [a:expr, '', '']
    endif

    let l:endIdx = matchend(a:expr, a:pattern)
    return [strpart(a:expr, 0, l:startIdx), strpart(a:expr, l:startIdx, l:endIdx - l:startIdx), strpart(a:expr, l:endIdx)]
endfunction

function! ingo#str#split#AtPrefix( expr, prefix, ... )
"******************************************************************************
"* PURPOSE:
"   Split off a:prefix from the beginning of a:expr.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:expr                  Text to be split.
"   a:prefix                The literal prefix text to remove.
"   a:isIgnoreCase          Optional flag whether to ignore case differences
"                           (default: false).
"   a:onPrefixNotExisting   Optional value to be returned when a:expr does not
"                           start with a:prefix.
"* RETURN VALUES:
"   Remainder of a:expr without a:prefix. Returns a:onPrefixNotExisting or
"   a:expr if the prefix doesn't exist.
"******************************************************************************
    return (ingo#str#StartsWith(a:expr, a:prefix, (a:0 ? a:1 : 0)) ?
    \   strpart(a:expr, len(a:prefix)) :
    \   (a:0 >= 2 ? a:2 : a:expr)
    \)
endfunction

function! ingo#str#split#AtSuffix( expr, suffix, ... )
"******************************************************************************
"* PURPOSE:
"   Split off a:suffix from the end of a:expr.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:expr                  Text to be split.
"   a:suffix                The literal suffix text to remove.
"   a:onSuffixNotExisting   Optional value to be returned when a:expr does not
"                           end with a:suffix.
"* RETURN VALUES:
"   Remainder of a:expr without a:suffix. Returns a:onSuffixNotExisting or
"   a:expr if the suffix doesn't exist.
"******************************************************************************
    return (ingo#str#EndsWith(a:expr, a:suffix) ?
    \   strpart(a:expr, 0, len(a:expr) - len(a:suffix)) :
    \   (a:0 ? a:1 : a:expr)
    \)
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo
" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
autoload/ingo/strdisplaywidth.vim	[[[1
102
" ingo/strdisplaywidth.vim: Functions for dealing with the screen display width of text.
"
" DEPENDENCIES:
"   - ingo/str.vim autoload script
"
" Copyright: (C) 2008-2018 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
"
" REVISION	DATE		REMARKS
"   1.030.006	15-May-2017	Add ingo#strdisplaywidth#CutLeft() variant of
"				ingo#strdisplaywidth#strleft() that returns both
"				parts. Same for ingo#strdisplaywidth#strright().
"   1.026.005	11-Aug-2016	ENH: ingo#strdisplaywidth#TruncateTo() has a
"				configurable ellipsis string
"				g:IngoLibrary_TruncateEllipsis, now defaulting
"				to a single-char UTF-8 variant if we're in such
"				encoding. It also handles pathologically small
"				lengths that only show / cut into the ellipsis.
"   1.023.004	29-Dec-2014	Add ingo#strdisplaywidth#TruncateTo().
"   1.019.003	17-Apr-2014	Add ingo#strdisplaywidth#GetMinMax().
"   1.011.002	26-Jul-2013	FIX: Off-by-one in
"				ingo#strdisplaywidth#HasMoreThan() and
"				ingo#strdisplaywidth#strleft().
"				Factor out ingo#str#Reverse().
"   1.008.001	07-Jun-2013	file creation from EchoWithoutScrolling.vim.

function! ingo#strdisplaywidth#HasMoreThan( expr, virtCol )
    return (match(a:expr, '^.*\%>' . (a:virtCol + 1) . 'v') != -1)
endfunction

function! ingo#strdisplaywidth#GetMinMax( lines, ... )
    let l:col = (a:0 ? a:1 : 0)
    let l:widths = map(copy(a:lines), 'ingo#compat#strdisplaywidth(v:val, l:col)')
    return [min(l:widths), max(l:widths)]
endfunction

function! ingo#strdisplaywidth#strleft( expr, virtCol )
    return substitute(a:expr, '\zs.\%>' . (a:virtCol + 1) . 'v.*$', '', '')
endfunction
function! ingo#strdisplaywidth#CutLeft( expr, virtCol )
    let l:left = ingo#strdisplaywidth#strleft(a:expr, a:virtCol)
    return [l:left, strpart(a:expr, len(l:left))]
endfunction

if ! exists('g:IngoLibrary_TruncateEllipsis')
    let g:IngoLibrary_TruncateEllipsis = (&encoding ==# 'utf-8' ? "\u2026" : '...')
endif
function! ingo#strdisplaywidth#TruncateTo( text, virtCol, ... )
"******************************************************************************
"* PURPOSE:
"   Truncate a:text to a maximum of a:virtCol virtual columns, and if this
"   happens, indicate via an appended "..." indicator.
"* SEE ALSO:
"   - ingo#avoidprompt#TruncateTo() does something similar with truncation in
"     the middle of a:text, not at the end, but it is meant for :echoing, as
"     it accounts for buffer-local tabstop values.
"* ASSUMPTIONS / PRECONDITIONS:
"   The default ellipsis can be configured by g:IngoLibrary_TruncateEllipsis.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:text	Text which may be truncated to fit.
"   a:virtCol   Maximum virtual columns for a:text.
"   a:truncationIndicator   Optional text to be appended when truncation
"			    appears. a:text is further reduced to account for
"			    its width. Default is "..." or the single-char UTF-8
"			    variant if the encoding also is UTF-8.
"* RETURN VALUES:
"   Truncated a:text.
"******************************************************************************
    let l:truncationIndicator = (a:0 ? a:1 : g:IngoLibrary_TruncateEllipsis)
    if ingo#strdisplaywidth#HasMoreThan(a:text, a:virtCol)
	let l:ellipsisLength = ingo#compat#strchars(g:IngoLibrary_TruncateEllipsis)

	" Handle pathological cases.
	if a:virtCol == l:ellipsisLength
	    return g:IngoLibrary_TruncateEllipsis
	elseif a:virtCol < l:ellipsisLength
	    return ingo#compat#strcharpart(g:IngoLibrary_TruncateEllipsis, 0, a:virtCol)
	endif

	let l:truncatedText = ingo#strdisplaywidth#strleft(a:text, max([0, a:virtCol - ingo#compat#strdisplaywidth(l:truncationIndicator)]))
	return l:truncatedText . l:truncationIndicator
    else
	return a:text
    endif
endfunction

function! ingo#strdisplaywidth#strright( expr, virtCol )
    " Virtual columns are always counted from the start, not the end. To specify
    " the column counting from the end, the string is reversed during the
    " matching.
    return ingo#str#Reverse(ingo#strdisplaywidth#strleft(ingo#str#Reverse(a:expr), a:virtCol))
endfunction
function! ingo#strdisplaywidth#CutRight( expr, virtCol )
    let l:right = ingo#strdisplaywidth#strright(a:expr, a:virtCol)
    return [l:right, strpart(a:expr, 0, len(a:expr) - len(l:right))]
endfunction

" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
autoload/ingo/strdisplaywidth/pad.vim	[[[1
217
" ingo/strdisplaywidth/pad.vim: Functions for padding a string to certain display width.
"
" DEPENDENCIES:
"   - ingo/compat.vim autoload script
"   - ingo/tabstops.vim autoload script
"
" Copyright: (C) 2013-2018 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
"
" REVISION	DATE		REMARKS
"   1.030.003	15-May-2017	CHG: Rename ill-named
"				ingo#strdisplaywidth#pad#Middle() to
"				ingo#strdisplaywidth#pad#Center()
"				Add "real" ingo#strdisplaywidth#pad#Middle()
"				that inserts the padding in the middle of the
"				string / between the two passed string parts.
"   1.026.002	11-Aug-2016	Add ingo#strdisplaywidth#pad#Middle().
"   1.009.001	20-Jun-2013	file creation

function! ingo#strdisplaywidth#pad#Width( text, width, ... )
"******************************************************************************
"* PURPOSE:
"   Determine the amount of padding for a:text so that the overall display width
"   is at least a:width.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:text  Text to be padded.
"   a:width Desired display width.
"   a:tabstop	    Optional tabstop value; defaults to the buffer's 'tabstop'
"		    value.
"   a:startColumn   Optional column at which the text is to be rendered (default
"		    1).
"* RETURN VALUES:
"   Amount of display cells of padding for a:text, or 0 if its width is already
"   (more than) enough.
"******************************************************************************
    let l:existingWidth = call('ingo#compat#strdisplaywidth', [a:text] + a:000)
    return max([0, a:width - l:existingWidth])
endfunction
function! ingo#strdisplaywidth#pad#Left( text, width, ... )
"******************************************************************************
"* PURPOSE:
"   Add padding to the right of a:text so that the overall display width is at
"   least a:width.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:text  Text to be padded.
"   a:width Desired display width.
"   a:tabstop	    Optional tabstop value; defaults to the buffer's 'tabstop'
"		    value.
"   a:startColumn   Optional column at which the text is to be rendered (default
"		    1).
"* RETURN VALUES:
"   Padded text, or original text if its width is already (more than) enough.
"******************************************************************************
    " Any contained <Tab> characters would change their width when the padding
    " is prepended. Therefore, render them first into spaces.
    let l:renderedText = call('ingo#tabstops#Render', [a:text] + a:000)
    return repeat(' ', ingo#strdisplaywidth#pad#Width(l:renderedText, a:width)) . l:renderedText
endfunction
function! ingo#strdisplaywidth#pad#Right( text, width, ... )
"******************************************************************************
"* PURPOSE:
"   Add padding to the right of a:text so that the overall display width is at
"   least a:width.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:text  Text to be padded.
"   a:width Desired display width.
"   a:tabstop	    Optional tabstop value; defaults to the buffer's 'tabstop'
"		    value.
"   a:startColumn   Optional column at which the text is to be rendered (default
"		    1).
"* RETURN VALUES:
"   Padded text, or original text if its width is already (more than) enough.
"******************************************************************************
    return a:text . repeat(' ', call('ingo#strdisplaywidth#pad#Width', [a:text, a:width] + a:000))
endfunction
function! ingo#strdisplaywidth#pad#Center( text, width, ... )
"******************************************************************************
"* PURPOSE:
"   Add padding to the left and right of a:text so that the overall display
"   width is at least a:width.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:text  Text to be padded.
"   a:width Desired display width.
"   a:tabstop	    Optional tabstop value; defaults to the buffer's 'tabstop'
"		    value.
"   a:startColumn   Optional column at which the text is to be rendered (default
"		    1).
"* RETURN VALUES:
"   Padded text, or original text if its width is already (more than) enough.
"******************************************************************************
    let l:renderedText = call('ingo#tabstops#Render', [a:text] + a:000)
    let l:existingWidth = call('ingo#compat#strdisplaywidth', [l:renderedText] + a:000)
    let l:pad = a:width - l:existingWidth
    if l:pad <= 0
	return l:renderedText
    endif

    let l:leftPad = l:pad / 2
    let l:rightPad = l:pad - l:leftPad
    return repeat(' ', l:leftPad) . l:renderedText . repeat(' ', l:rightPad)
endfunction
function! ingo#strdisplaywidth#pad#Middle( text, width, ... )
"******************************************************************************
"* PURPOSE:
"   Add padding in the middle of a:text / between [a:left, a:right] so that the
"   overall display width is at least a:width.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:text  Text to be padded, or List of [a:left, a:right] text parts.
"   a:width Desired display width.
"   a:tabstop	    Optional tabstop value; defaults to the buffer's 'tabstop'
"		    value.
"   a:startColumn   Optional column at which the text is to be rendered (default
"		    1).
"* RETURN VALUES:
"   Padded text, or original text if its width is already (more than) enough.
"******************************************************************************
    if type(a:text) == type([])
	let [l:left, l:right] = map(copy(a:text), "call('ingo#tabstops#Render', [v:val] + a:000)")
	let l:renderedText = l:left . l:right
    else
	let l:renderedText = call('ingo#tabstops#Render', [a:text] + a:000)
	let [l:left, l:right] = ingo#strdisplaywidth#CutLeft(l:renderedText, ingo#compat#strdisplaywidth(l:renderedText) / 2)
    endif
    let l:existingWidth = call('ingo#compat#strdisplaywidth', [l:renderedText] + a:000)

    let l:pad = a:width - l:existingWidth
    if l:pad <= 0
	return l:renderedText
    endif

    return l:left . repeat(' ', ingo#strdisplaywidth#pad#Width(l:renderedText, a:width)) . l:right
endfunction

function! ingo#strdisplaywidth#pad#Repeat( text, width, ... )
"******************************************************************************
"* PURPOSE:
"   Duplicate a:text so often that the overall display width is at least
"   a:width.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:text  Text to be padded / repeated.
"   a:width Desired display width.
"   a:tabstop	    Optional tabstop value; defaults to the buffer's 'tabstop'
"		    value.
"   a:startColumn   Optional column at which the text is to be rendered (default
"		    1).
"* RETURN VALUES:
"   Padded text, or original text if its width is already (more than) enough.
"******************************************************************************
    " Any contained <Tab> characters would change their width when the padding
    " is prepended. Therefore, render them first into spaces.
    let l:renderedText = call('ingo#tabstops#Render', [a:text] + a:000)

    let l:textWidth = call('ingo#compat#strdisplaywidth', [l:renderedText] + a:000)
    if l:textWidth == 0 | return l:renderedText | endif

    let l:padWidth = max([0, a:width - l:textWidth])
    return (l:padWidth > 0 ? repeat(l:renderedText, (l:padWidth - 1) / l:textWidth + 2) : l:renderedText)
endfunction
function! ingo#strdisplaywidth#pad#RepeatExact( text, width, ... )
"******************************************************************************
"* PURPOSE:
"   Duplicate a:text so often that the overall display width is exactly a:width.
"   If a multi-cell character would have to be cut, it instead appends spaces /
"   a:filler to make up for the shortcoming.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:text  Text to be padded / repeated.
"   a:width Desired display width.
"   a:filler        Optional character to append (as often as necessary) if a
"                   multi-cell character at the end has to be cut. Default is
"                   <Space>. Must be a single-cell character itself. Pass empty
"                   String if you then want the result to be slightly shorter.
"   a:tabstop	    Optional tabstop value; defaults to the buffer's 'tabstop'
"		    value.
"   a:startColumn   Optional column at which the text is to be rendered (default
"		    1).
"* RETURN VALUES:
"   Padded text, or original text if its width is already (more than) enough.
"******************************************************************************
    let l:filler = (a:0 ? a:1 : ' ')
    let l:paddedText = call('ingo#strdisplaywidth#pad#Repeat', [a:text, a:width] + a:000[1:])
    let l:truncatedText = ingo#strdisplaywidth#strleft(l:paddedText, a:width)

    let l:padWidth = max([0, a:width - ingo#compat#strdisplaywidth(l:truncatedText)])
    return l:truncatedText . repeat(l:filler, l:padWidth)
endfunction

" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
autoload/ingo/subs/BraceCreation.vim	[[[1
193
" ingo/subs/BraceCreation.vim: Condense multiple strings into a Brace Expression like in Bash.
"
" DEPENDENCIES:
"   - ingo/collections.vim autoload script
"   - ingo/compat.vim autoload script
"   - ingo/list.vim autoload script
"   - ingo/list/lcs.vim autoload script
"   - ingo/list/sequence.vim autoload script
"
" Copyright: (C) 2017-2018 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
let s:save_cpo = &cpo
set cpo&vim

function! ingo#subs#BraceCreation#FromSplitString( text, ... )
"******************************************************************************
"* PURPOSE:
"   Split a:text into WORDs (or on a:separatorPattern), extract common
"   substrings, and turn these into a (shorter) Brace Expression, like in Bash.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:text  Source text with multiple strings.
"   a:separatorPattern  Regular expression to separate the source text into
"			strings. Defaults to whitespace (also when empty string
"			is passed).
"   a:options           Additional options; see
"			ingo#subs#BraceCreation#FromList().
"* RETURN VALUES:
"   Brace Expression. Returns braced and comma-separated original items if no
"   common substrings could be extracted.
"******************************************************************************
    let l:separatorPattern = (a:0 && ! empty(a:1) ? a:1 : '\_s\+')

    let l:strings = split(a:text, l:separatorPattern)
    if len(l:strings) <= 1
	throw 'Only one string'
    endif
    return ingo#subs#BraceCreation#FromList(l:strings, (a:0 >= 2 ? a:2 : {}))
endfunction
function! ingo#subs#BraceCreation#FromList( list, ... )
"******************************************************************************
"* PURPOSE:
"   Extract common substrings in a:list, and turn these into a (shorter) Brace
"   Expression, like in Bash.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:list      List of strings.
"   a:options.returnValueOnFailure
"		Return value if there are no common substrings (or in strict
"		mode the common substrings are not a prefix or suffix).
"   a:options.strict
"		Flag whether it must be possible to mechanically expand the
"		result back into the original strings. This means that
"		opportunities to extract multiple substrings are not taken.
"   a:options.short
"		Flag to enable all optimizations, i.e.
"		optionalElementInSquareBraces and uniqueElements.
"   a:options.optionalElementInSquareBraces
"		Flag whether a single optional element is denoted as [elem]
"		instead of {elem,} (or {,elem}, or even {,,elem,}; i.e. the
"		bidirectional equivalence is lost, but the notation is more
"		readable.
"   a:options.uniqueElements
"		Flag whether duplicate elements are removed, so that only unique
"		strings are contained in there.
"   a:options.minimumCommonLength       Minimum substring length; default 1.
"   a:options.minimumDifferingLength    Minimum length; default 0.
"* RETURN VALUES:
"   Brace Expression. Returns braced and comma-separated original items if no
"   common substrings could be extracted (or a:options.returnValueOnFailure).
"******************************************************************************
    let l:options = (a:0 ? a:1 : {})
    if has_key(l:options, 'short')
	let l:options.optionalElementInSquareBraces = 1
	let l:options.uniqueElements = 1
    endif

    let [l:distinctLists, l:commons] = ingo#list#lcs#FindAllCommon(a:list, get(l:options, 'minimumCommonLength', 1), get(l:options, 'minimumDifferingLength', 0))
    let l:isFailure = empty(l:commons)

    if ! l:isFailure && get(l:options, 'strict', 0)
	let [l:isFailure, l:distinctLists, l:commons] = s:ToStrict(a:list, l:distinctLists, l:commons)
    endif

    if l:isFailure && has_key(l:options, 'returnValueOnFailure')
	return a:options.returnValueOnFailure
    endif

    return s:Join(l:distinctLists, l:commons, (a:0 ? a:1 : {}))
endfunction
function! s:ToStrict( list, distinctLists, commons )
    let l:isCommonPrefix = empty(a:distinctLists[0])
    let l:isCommonSuffix = empty(a:distinctLists[-1])

    if ! l:isCommonPrefix && ! l:isCommonSuffix
	" Join the original strings.
	return [1, [a:list], []]
    elseif len(a:commons) > (l:isCommonPrefix && l:isCommonSuffix ? 2 : 1)
	if l:isCommonPrefix && l:isCommonSuffix
	    " Use first and last common, combine inner.
	    return [0, [[]] + s:Recombine(a:distinctLists[1:-2], a:commons[1:-2]) + [[]], [a:commons[0], a:commons[-1]]]
	elseif l:isCommonPrefix
	    " Use first common, combine rest.
	    return [0, [[]] + s:Recombine(a:distinctLists[1:], a:commons[1:]), [a:commons[0]]]
	elseif l:isCommonSuffix
	    " Use last common, combine rest.
	    return [0, s:Recombine(a:distinctLists[0: -2], a:commons[0: -2]) + [[]], [a:commons[-1]]]
	endif
    endif
    return [0, a:distinctLists, a:commons]
endfunction
function! s:Recombine( distinctLists, commons )
    let l:realDistincts = filter(copy(a:distinctLists), '! empty(v:val)')
    let l:distinctNum = len(l:realDistincts[0])
    let l:distinctAndCommonsIntermingled = ingo#list#Join(l:realDistincts, map(copy(a:commons), 'repeat([v:val], l:distinctNum)'))
    let l:indexedElementsTogether = call('ingo#list#Zip', l:distinctAndCommonsIntermingled)
    let l:joinedIndividualElements = map(l:indexedElementsTogether, 'join(v:val, "")')
    return [l:joinedIndividualElements]
endfunction
function! s:Join( distinctLists, commons, options )
    let l:result = []
    while ! empty(a:distinctLists) || ! empty(a:commons)
	if ! empty(a:distinctLists)
	    let l:distinctList = remove(a:distinctLists, 0)

	    if get(a:options, 'uniqueElements', 0)
		let l:distinctList = ingo#collections#UniqueStable(l:distinctList)
	    endif

	    call add(l:result, s:Create(a:options, l:distinctList, 1)[0])
	endif

	if ! empty(a:commons)
	    call add(l:result, remove(a:commons, 0))
	endif
    endwhile

    return join(l:result, '')
endfunction
function! s:Create( options, distinctList, isWrap )
    if empty(a:distinctList)
	return ['', 0]
    endif

    let [l:sequenceLen, l:stride] = ingo#list#sequence#FindNumerical(a:distinctList)
    if l:sequenceLen <= 2 || ! ingo#list#pattern#AllItemsMatch(a:distinctList[0 : l:sequenceLen - 1], '^\d\+$')
	let [l:sequenceLen, l:stride] = ingo#list#sequence#FindCharacter(a:distinctList)
    endif
    if l:sequenceLen > 2
	let l:result = a:distinctList[0] . '..' . a:distinctList[l:sequenceLen - 1] .
	\   (ingo#compat#abs(l:stride) == 1 ? '' : '..' . l:stride)

	if l:sequenceLen < len(a:distinctList)
	    " Search for further sequences in the surplus elements. If this is a
	    " sequence, we have to enclose it in {...}. A normal brace list can
	    " just be appended.
	    let [l:surplusResult, l:isSurplusSequence] = s:Create(a:options, a:distinctList[l:sequenceLen :], 0)
	    let l:result = s:Brace(l:result) . ',' . s:Brace(l:surplusResult, l:isSurplusSequence)
	endif

	return [s:Brace(l:result), a:isWrap]
    else
	if get(a:options, 'optionalElementInSquareBraces', 0)
	    let l:nonEmptyList = filter(copy(a:distinctList), '! empty(v:val)')
	    if len(l:nonEmptyList) == 1
		return [s:Wrap('[]', l:nonEmptyList[0]), 0]
	    endif
	endif

	return [s:Brace(join(map(a:distinctList, 's:Escape(v:val)'), ','), a:isWrap), 0]
    endif
endfunction
function! s:Wrap( wrap, string, ... )
    return (! a:0 || a:0 && a:1 ? a:wrap[0] . a:string . a:wrap[1] : a:string)
endfunction
function! s:Brace( string, ... )
    return call('s:Wrap', ['{}', a:string] + a:000)
endfunction
function! s:Escape( braceItem )
    return escape(a:braceItem, '{},')
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo
" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
autoload/ingo/subs/BraceExpansion.vim	[[[1
253
" ingo/subs/BraceExpansion.vim: Generate arbitrary strings like in Bash.
"
" DEPENDENCIES:
"   - ingo/collections.vim autoload script
"   - ingo/collections/fromsplit.vim autoload script
"   - ingo/compat.vim autoload script
"   - ingo/escape.vim autoload script
"
" Copyright: (C) 2016-2017 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
let s:save_cpo = &cpo
set cpo&vim

function! s:MakeToken( symbol, level )
    return "\001" . a:level . a:symbol . "\001"
endfunction
function! s:ProcessListInBraces( bracesText, iterationCnt )
    let l:text = a:bracesText
    let l:text = substitute(l:text, '\%(\%(^\|[^\\]\)\%(\\\\\)*\\\)\@<!,', s:MakeToken(a:iterationCnt, ';'), 'g')
    if l:text ==# a:bracesText
	let l:text = substitute(l:text, '\%(\%(^\|[^\\]\)\%(\\\\\)*\\\)\@<!\.\.', s:MakeToken(a:iterationCnt, '#'), 'g')
    endif
    return ingo#escape#Unescape(l:text, ',')
endfunction
function! s:ProcessBraces( text )
    " We need to process nested braces from the outside to the inside;
    " unfortunately, with regexp parsing, we cannot skip over inner matching
    " braces. To work around that, we process all braces from the inside out,
    " and translate them into special tokens: ^AN<^A ... ^AN;^A ... ^AN>^A,
    " where ^A is 0x01 (hopefully not occurring as this token in the text), N is
    " the nesting level (1 = innermost), and < ; > / < # > are the substitutes
    " for { , } / { .. }.
    let l:text = a:text
    let l:previousText = 'X' . a:text   " Make this unequal to the current one, handle empty string.

    let l:iterationCnt = 1
    while l:previousText !=# l:text
	let l:previousText = l:text
	let l:text = substitute(
	\   l:text,
	\   '\(.\{-}\)\%(\%(^\|[^\\]\)\%(\\\\\)*\\\)\@<!{\(\%([^{}]\|\%(\%(^\|[^\\]\)\%(\\\\\)*\\\)\@<!\\[{}]\)*\%(,\|\.\.\)\%([^{}]\|\%(\%(^\|[^\\]\)\%(\\\\\)*\\\)\@<!\\[{}]\)*\)\%(\%(^\|[^\\]\)\%(\\\\\)*\\\)\@<!}',
	\   '\=submatch(1) . s:MakeToken(l:iterationCnt, "<") . s:ProcessListInBraces(submatch(2), l:iterationCnt) . s:MakeToken(l:iterationCnt, ">")',
	\   'g'
	\)
	let l:iterationCnt += 1
    endwhile

    return [l:iterationCnt - 2, l:text]
endfunction
function! s:ExpandOneLevel( TailCall, text, level )
    let l:parse = matchlist(a:text, printf('^\(.\{-}\)%s\(.\{-}\)%s\(.*\)$', s:MakeToken(a:level, '<'), s:MakeToken(a:level, '>')))
    if empty(l:parse)
	return (a:level > 1 ?
	\   s:ExpandOneLevel(a:TailCall, a:text, a:level - 1) :
	\   [a:text]
	\)
    endif

    let [l:pre, l:braceList, l:post] = l:parse[1:3]
    if l:braceList =~# s:MakeToken(a:level, '#')
	" Sequence.
	let l:sequenceElements = split(l:braceList, s:MakeToken(a:level, '#'), 1)
	let l:nonEmptySequenceElementNum = len(filter(copy(l:sequenceElements), '! empty(v:val)'))
	if l:nonEmptySequenceElementNum < 2 || l:nonEmptySequenceElementNum > 3
	    " Undo the brace translation.
	    return [substitute(a:text, s:MakeToken('\d\+', '\([#<>]\)'), '\={"#": "..", "<": "{", ">": "}"}[submatch(1)]', 'g')]
	endif
	let l:isNumericSequence = (len(filter(copy(l:sequenceElements), 'v:val !~# "^[+-]\\?\\d\\+$"')) == 0)
	if l:isNumericSequence
	    let l:numberElements = map(copy(l:sequenceElements), 'str2nr(v:val)')
	    let l:step = ingo#compat#abs(get(l:numberElements, 2, 1))
	    if l:step == 0 | let l:step = 1 | endif
	    let l:isZeroPadding = (l:sequenceElements[0] =~# '^0\d' || l:sequenceElements[1] =~# '^0\d')
	    if l:numberElements[0] > l:numberElements[1]
		let l:step = l:step * -1
	    endif
	    let l:braceElements = range(l:numberElements[0], l:numberElements[1], l:step)

	    if l:isZeroPadding
		let l:digitNum = max(map(l:sequenceElements[0:1], 'len(v:val)'))
		call map(l:braceElements, 'printf("%0" . l:digitNum . "d", v:val)')
	    endif
	else
	    let l:step = ingo#compat#abs(str2nr(get(l:sequenceElements, 2, 1)))
	    if l:step == 0 | let l:step = 1 | endif
	    let [l:nrParameter0, l:nrParameter1] = [char2nr(l:sequenceElements[0]), char2nr(l:sequenceElements[1])]
	    if l:nrParameter0 > l:nrParameter1
		let l:step = l:step * -1
	    endif
	    let l:braceElements = map(range(l:nrParameter0, l:nrParameter1, l:step), 'nr2char(v:val)')
	endif
    else
	" List (possibly nested).
	let l:braceElements = split(l:braceList, s:MakeToken(a:level, ';'), 1)

	if a:level > 1
	    let l:braceElements = ingo#collections#Flatten1(map(l:braceElements, 's:ExpandOneLevel("s:FlattenRecurse", v:val, a:level - 1)'))
	endif
    endif

    return call(a:TailCall, [a:TailCall, l:pre, l:braceElements, l:post, a:level])
endfunction
function! s:UnescapeExpansions( expansions )
    return map(a:expansions, 'ingo#escape#Unescape(v:val, "\\{}")')
endfunction
function! s:FlattenRecurse( TailCall, pre, braceElements, post, level )
    return ingo#collections#Flatten1(map(a:braceElements, 's:ExpandOneLevel(a:TailCall, a:pre . v:val . a:post, a:level)'))
endfunction
function! ingo#subs#BraceExpansion#ExpandStrict( expression )
    let [l:nestingLevel, l:processedText] = s:ProcessBraces(a:expression)
    let l:expansions = s:ExpandOneLevel(function('s:FlattenRecurse'), l:processedText, l:nestingLevel)
    return s:UnescapeExpansions(l:expansions)
endfunction

function! s:Collect( TailCall, pre, braceElements, post, level )
    return [a:pre, a:braceElements] + s:ExpandOneLevel(a:TailCall, a:post, a:level)
endfunction
function! ingo#subs#BraceExpansion#ExpandMinimal( expression )
    let [l:nestingLevel, l:processedText] = s:ProcessBraces(a:expression)
    let l:collections = s:ExpandOneLevel(function('s:Collect'), l:processedText, l:nestingLevel)
    let l:expansions = s:CollectionsToExpansions(l:collections)
    return s:UnescapeExpansions(l:expansions)
endfunction
function! s:CalculateExpansionNumber( cardinalities )
    let l:num = 1
    while ! empty(a:cardinalities)
	let l:num = l:num * remove(a:cardinalities, 0)
    endwhile
    return l:num
endfunction
function! s:Multiply( elements, cardinalityNum )
    return repeat(a:elements, a:cardinalityNum / len(a:elements))
endfunction
function! s:CollectionsToExpansions( collections )
    let l:cardinalities = ingo#compat#uniq(sort(
    \   map(
    \       filter(copy(a:collections), 'type(v:val) == type([])'),
    \       'len(v:val)'
    \   )))

    let l:expansionNum = s:CalculateExpansionNumber(l:cardinalities)
    call map(a:collections, 's:Multiply(ingo#list#Make(v:val), l:expansionNum)')

    let l:expansions = repeat([''], l:expansionNum)
    while len(a:collections) > 0
	let l:collection = remove(a:collections, 0)
	for l:i in range(l:expansionNum)
	    let l:expansions[l:i] .= l:collection[l:i]
	endfor
    endwhile
    return l:expansions
endfunction

function! s:ConvertOptionalElementInSquareBraces( expression )
    return substitute(a:expression, '\[\([^\]]\+\)\]', '{\1,}', 'g')
endfunction
function! ingo#subs#BraceExpansion#ExpandToList( expression, options )
"******************************************************************************
"* PURPOSE:
"   Expand a brace expression into a List of expansions.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:expression  One brace expression with {...} braces.
"   a:options.strict    Flag whether this works like Bash's Brace Expansion,
"			where each {...} multiplies the number of resulting
"			expansions. Defaults to true. If false, {...} with the
"			same number of alternatives are all grouped together,
"			resulting in fewer expansions:
"			    {foo,bar}To{Me,You} ~
"			    true:  fooToMe fooToYou barToMe barToYou
"			    false: fooToMe barToYou
"   a:options.optionalElementInSquareBraces
"		Flag whether to also handle a single optional element denoted as
"		[elem] instead of {elem,}.
"* RETURN VALUES:
"   All expanded values of the brace expression as a List of Strings.
"******************************************************************************
    return call(
    \   function(get(a:options, 'strict', 1) ?
    \       'ingo#subs#BraceExpansion#ExpandStrict' :
    \       'ingo#subs#BraceExpansion#ExpandMinimal'
    \   ),
    \   [get(a:options, 'optionalElementInSquareBraces', 0) ?
    \       s:ConvertOptionalElementInSquareBraces(a:expression) :
    \       a:expression
    \   ]
    \)
endfunction
function! ingo#subs#BraceExpansion#ExpandToString( expression, joiner, options )
"******************************************************************************
"* PURPOSE:
"   Expand a brace expression and join the expansions with a:joiner.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:expression  One brace expression with {...} braces.
"   a:joiner    Literal text to be used to join the expanded expressions;
"		defaults to a <Space> character.
"   a:options               Additional options; see
"			    ingo#subs#BraceExpansion#ExpandToList().
"* RETURN VALUES:
"   All expanded values of the brace expression, joined by a:joiner, in a single
"   string.
"******************************************************************************
    return join(ingo#subs#BraceExpansion#ExpandToList(a:expression, a:options), a:joiner)
endfunction

function! ingo#subs#BraceExpansion#InsideText( text, ... )
"******************************************************************************
"* PURPOSE:
"   Expand "foo{x,y}" inside a:text to "foox fooy", like Bash's Brace Expansion.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:text  Source text with braces.
"   a:joiner    Literal text to be used to join the expanded expressions;
"		defaults to a <Space> character.
"   a:braceSeparatorPattern Regular expression to separate the expressions where
"			    braces are expanded; defaults to a:joiner or
"			    any whitespace (also when empty string is passed).
"   a:options               Additional options; see
"			    ingo#subs#BraceExpansion#ExpandToList().
"* RETURN VALUES:
"   a:text, separated by a:braceSeparatorPattern, each part had brace
"   expressions expanded, then joined by a:joiner, and all put together again.
"******************************************************************************
    let l:joiner = (a:0 ? a:1 : ' ')
    let l:braceSeparatorPattern = (a:0 >= 2 && ! empty(a:2) ? a:2 : (a:0 ? '\V' . escape(l:joiner, '\') : '\_s\+'))
    let l:options = (a:0 >= 3 ? a:3 : {})

    let l:result = ingo#collections#fromsplit#MapItems(
    \   a:text,
    \   '\%(\%(^\|[^\\]\)\%(\\\\\)*\\\)\@<!' . l:braceSeparatorPattern,
    \   printf('ingo#subs#BraceExpansion#ExpandToString(ingo#escape#UnescapeExpr(v:val, %s), %s, %s)',
    \       string(l:braceSeparatorPattern), string(l:joiner), string(l:options)
    \   )
    \)

    return join(l:result, '')
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo
" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
autoload/ingo/subst.vim	[[[1
172
" ingo/subst.vim: Functions for substitutions.
"
" DEPENDENCIES:
"   - ingo/format.vim autoload script
"   - ingo/subst/replacement.vim autoload script
"
" Copyright: (C) 2013-2018 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
let s:save_cpo = &cpo
set cpo&vim

function! ingo#subst#gsub( expr, pat, sub )
    return substitute(a:expr, '\C' . a:pat, a:sub, 'g')
endfunction

function! ingo#subst#MultiGsub( expr, substitutions )
"******************************************************************************
"* PURPOSE:
"   Perform a set of global substitutions in-order on the same text.
"   Neither 'ignorecase' nor 'smartcase' nor 'magic' applies.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:expr  Text to be transformed.
"   a:substitutions List of [pattern, substitution] tuples; is processed from
"		    begin to end.
"* RETURN VALUES:
"   Transformed a:expr.
"******************************************************************************
    let l:expr = a:expr
    for [l:pat, l:sub] in a:substitutions
	let l:expr = ingo#subst#gsub(l:expr, l:pat, l:sub)
    endfor
    return l:expr
endfunction

function! ingo#subst#FirstSubstitution( expr, flags, ... )
"******************************************************************************
"* PURPOSE:
"   Perform a substitution with the first matching [a:pattern, a:replacement]
"   substitution.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:expr  Text to be transformed.
"   [a:pattern0, a:replacement0], ...   List of [pattern, substitution] tuples.
"* RETURN VALUES:
"   [patternIndex, replacement]; if no supplied pattern matched, returns
"   [-1, a:expr].
"******************************************************************************
    for l:patternIndex in range(len(a:000))
	let [l:pattern, l:replacement] = a:000[l:patternIndex]
	if a:expr =~ l:pattern
	    return [l:patternIndex, substitute(a:expr, l:pattern, l:replacement, a:flags)]
	endif
    endfor
    return [-1, a:expr]
endfunction

function! ingo#subst#FirstPattern( expr, replacement, flags, ... )
"******************************************************************************
"* PURPOSE:
"   Perform a substitution with the first matching a:pattern0, a:pattern1, ...
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:expr  Text to be transformed.
"   a:replacement   Replacement (applied regardless of the chosen a:patternX)
"   a:pattern0, ... Search patterns.
"* RETURN VALUES:
"   [patternIndex, replacement]; if no supplied pattern matched, returns
"   [-1, a:expr].
"******************************************************************************
    for l:patternIndex in range(len(a:000))
	let l:pattern = a:000[l:patternIndex]
	if a:expr =~ l:pattern
	    return [l:patternIndex, substitute(a:expr, l:pattern, a:replacement, a:flags)]
	endif
    endfor
    return [-1, a:expr]
endfunction

function! ingo#subst#FirstParameter( expr, patternTemplate, replacement, flags, ... )
"******************************************************************************
"* PURPOSE:
"   Insert a:parameter1, ... into a:patternTemplate and perform a substitution
"   with the first matching resulting pattern.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:expr  Text to be transformed.
"   a:patternTemplate   Regular expression template; parameters are inserted
"			into the %s (or named %[argument-index]$s) inside the
"			template.
"   a:replacement       Replacement.
"   a:parameter1, ...   Parameters (regexp fragments) to be inserted into
"			a:patternTemplate.
"* RETURN VALUES:
"   [patternIndex, replacement]; if no supplied pattern matched, returns
"   [-1, a:expr].
"******************************************************************************
    let l:isIndexedParameter = (a:patternTemplate =~# '%\@<!%\d\+\$s')
    for l:patternIndex in range(len(a:000))
	let l:parameter = a:000[l:patternIndex]

	let l:currentParameterArgs = (l:isIndexedParameter ?
	\   repeat([''], l:patternIndex) + [l:parameter] :
	\   [l:parameter]
	\)
	let l:pattern = call('ingo#format#Format', [a:patternTemplate] + l:currentParameterArgs)

	if a:expr =~ l:pattern
	    return [l:patternIndex, substitute(a:expr, l:pattern, a:replacement, a:flags)]
	endif
    endfor
    return [-1, a:expr]
endfunction

function! ingo#subst#Indexed( expr, pattern, replacement, indices, ... )
"******************************************************************************
"* PURPOSE:
"   Substitute only / not the N+1'th matches for the N in a:indices. Other
"   matches are kept as-is.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:expr  Text to be transformed.
"   a:pattern   Regular expression.
"   a:replacement       Replacement. Handles |sub-replace-expression|, & and \0,
"                       \1 .. \9, and \r\n\t\b (but not \u, \U, etc.)
"   a:indices   List of 0-based indices whose corresponding matches are
"               replaced. A String value of "g" replaces globally, just like
"               substitute(..., 'g').
"   a:isInvert  Flag whether only those matches whose indices are NOT in
"               a:indices are replaced. Does not invert the "g" String value.
"               Default is false.
"* RETURN VALUES:
"   Replacement.
"******************************************************************************
    if type(a:indices) == type('') && a:indices ==# 'g'
	return substitute(a:expr, a:pattern, a:replacement, 'g')
    endif

    let l:context = {
    \   'matchCnt': 0,
    \   'indices': a:indices,
    \   'isInvert': (a:0 ? a:1 : 0),
    \   'replacement': a:replacement
    \}
    return substitute(a:expr, a:pattern, '\=s:IndexReplacer(l:context)', 'g')
endfunction
function! s:IndexReplacer( context )
    let a:context.matchCnt += 1
    execute 'let l:isSelected = index(a:context.indices, a:context.matchCnt - 1)' (a:context.isInvert ? '==' : '!=') '-1'
    return ingo#subst#replacement#DefaultReplacementOnPredicate(l:isSelected, a:context)
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo
" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
autoload/ingo/subst/expr/emulation.vim	[[[1
75
" ingo/subst/expr/emulation.vim: Function to emulate sub-replace-expression for recursive use.
"
" DEPENDENCIES:
"   - ingo/collection.vim autoload script
"
" Copyright: (C) 2014 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
"
" REVISION	DATE		REMARKS
"   1.017.001	07-Mar-2014	file creation

function! s:Submatch( idx )
    return get(s:submatches, a:idx, '')
endfunction
function! s:EmulateSubmatch( originalExpr, expr, pat, sub )
    let s:submatches = matchlist(a:expr, a:pat)
	if empty(s:submatches)
	    let l:innerReplacement = a:originalExpr
	else
	    let l:innerReplacement = eval(a:sub)
	endif
    unlet s:submatches
    return l:innerReplacement
endfunction
function! ingo#subst#expr#emulation#Substitute( expr, pat, sub, flags )
    if a:sub =~# '^\\='
	" Recursive use of \= is not allowed, so we need to emulate it:
	" matchlist() will get us the list of (sub-)matches, which we'll inject
	" into the passed expression via a s:Submatch() surrogate function for
	" submatch().
	let l:emulatedSub = substitute(a:sub[2:], '\w\@<!submatch\s*(', 's:Submatch(', 'g')

	if a:flags ==# 'g'
	    " For a global replacement, we need to separate the pattern matches
	    " from the surrounding text, and process each match in turn.
	    let l:innerParts = ingo#collections#SplitKeepSeparators(a:expr, a:pat, 1)
	    let l:replacement = ''
	    let l:innerPrefix = ''
	    while ! empty(l:innerParts)
		let l:innerSurroundingText = remove(l:innerParts, 0)
		if empty(l:innerParts)
		    let l:replacement .= l:innerSurroundingText
		else
		    let l:innerExpr = remove(l:innerParts, 0)

		    " To enable the use of lookahead and lookbehind, include the
		    " text before the current match (but nothing more, as that
		    " processed match would else match again) as well as all the
		    " text after it.
		    let l:augmentedInnerExpr = l:innerPrefix . l:innerSurroundingText . l:innerExpr . join(l:innerParts, '')

		    let l:replacement .= l:innerSurroundingText . s:EmulateSubmatch(l:innerExpr, l:augmentedInnerExpr, a:pat, l:emulatedSub)
		endif

		" To avoid that the ^ anchor matches on subsequent iterations,
		" invalidate the match position by prepending a dummy text that
		" is unlikely to be ever matched by a real pattern.
		let l:innerPrefix = "\<C-_>"
	    endwhile
	else
	    " For a first-only replacement, just match and replace once.
	    let s:submatches = matchlist(a:expr, a:pat)
	    let l:innerReplacement = s:EmulateSubmatch(a:expr, a:expr, a:pat, l:emulatedSub)
	    let l:replacement = substitute(a:expr, a:pat, escape(l:innerReplacement, '\&'), '')
	endif
    else
	let l:replacement = substitute(a:expr, a:pat, a:sub, a:flags)
    endif

    return l:replacement
endfunction

" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
autoload/ingo/subst/pairs.vim	[[[1
91
" ingo/subst/pairs.vim: Function to substitute wildcard=replacement pairs.
"
" DEPENDENCIES:
"   - ingo/fs/path.vim autoload script
"   - ingo/regexp/fromwildcard.vim autoload script
"
" Copyright: (C) 2014-2015 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
"
" REVISION	DATE		REMARKS
"   1.025.004	18-May-2015	ingo#subst#pairs#Substitute() and
"				ingo#subst#pairs#Split(): Only canonicalize path
"				separators in {replacement} on demand, via
"				additional a:isCanonicalizeReplacement argument.
"				Some clients may not need iterative replacement,
"				and treat the wildcard as a convenient
"				regexp-shorthand, not overly filesystem-related.
"   1.025.003	01-May-2015	ingo#subst#pairs#Substitute(): Canonicalize path
"				separators in {replacement}, too. This is
"				important to match further pairs, too, as the
"				pattern is always in canonical form, so the
"				replacement has to be, too.
"				ENH: Allow passing to
"				ingo#subst#pairs#Substitute() [wildcard,
"				replacement] Lists instead of
"				{wildcard}={replacement} Strings, too.
"   1.016.002	17-Jan-2014	Change s:pairPattern so that the first, not the
"				last = is used as the pair delimiter.
"   1.016.001	16-Jan-2014	file creation from
"				autoload/EditSimilar/Substitute.vim

let s:pairPattern = '\(^[^=]\+\)=\(.*$\)'
function! s:SplitPair( pair, isCanonicalizeReplacement )
    if type(a:pair) == type([])
	let [l:from, l:to] = a:pair
    else
	if a:pair !~# s:pairPattern
	    throw 'Substitute: Not a substitution: ' . a:pair
	endif
	let [l:from, l:to] = matchlist(a:pair, s:pairPattern)[1:2]
    endif
    return [ingo#regexp#fromwildcard#Convert(l:from), (a:isCanonicalizeReplacement ? ingo#fs#path#Normalize(l:to) : l:to)]
endfunction
function! ingo#subst#pairs#Split( pairs, ... )
    let l:isCanonicalizeReplacement = (a:0 ? a:1 : 0)
    return map(a:pairs, 's:SplitPair(v:val, l:isCanonicalizeReplacement)')
endfunction
function! ingo#subst#pairs#Substitute( text, pairs, ... )
"******************************************************************************
"* PURPOSE:
"   Apply {wildcard}={replacement} pairs (modeled after the Korn shell's "cd
"   {old} {new}" command).
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:text  Text to be substituted.
"   a:pairs List of {wildcard}={replacement} Strings that should be applied to
"	    a:text. Or List of [wildcard, replacement] List elements.
"   a:isCanonicalizeReplacement Optional flag whether path separators in
"				{replacement} should be canonicalized. This is
"				important when doing further substitutions on
"				the result, but may be unwanted when wildcards
"				are treated as a convenient regexp-shorthand.
"				Default is false, no canonicalization.
"* RETURN VALUES:
"   List of [replacement, failedPairs], where failedPairs is a subset of
"   a:pairs.
"******************************************************************************
    let l:isCanonicalizeReplacement = (a:0 ? a:1 : 0)
    let l:replacement = a:text
    let l:failedPairs = []

    for l:pair in a:pairs
	let [l:from, l:to] = s:SplitPair(l:pair, l:isCanonicalizeReplacement)
	let l:beforeReplacement = l:replacement
	let l:replacement = substitute(l:replacement, l:from, escape(l:to, '\&~'), 'g')
	if l:replacement ==# l:beforeReplacement
	    call add(l:failedPairs, l:pair)
	endif
"***D echo '****' (l:beforeReplacement =~ ingo#regexp#fromwildcard#Convert(l:from) ? '' : 'no ') . 'match for pair' ingo#regexp#fromwildcard#Convert(l:from)
"***D echo '**** replacing' l:beforeReplacement "\n          with" l:replacement
    endfor

    return [l:replacement, l:failedPairs]
endfunction

" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
autoload/ingo/subst/replacement.vim	[[[1
54
" ingo/subst/replacement.vim: Functions for replacing the match of a substitution.
"
" DEPENDENCIES:
"   - ingo/collections.vim autoload script
"   - ingo/escape.vim autoload script
"
" Copyright: (C) 2017 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>

function! ingo#subst#replacement#ReplaceSpecial( match, replacement, specialExpr, SpecialReplacer )
    if empty(a:specialExpr)
	return a:replacement
    endif

    return join(
    \   map(
    \       ingo#collections#SplitKeepSeparators(a:replacement, '\%(\%(^\|[^\\]\)\%(\\\\\)*\\\)\@<!' . a:specialExpr),
    \       'call(a:SpecialReplacer, [a:specialExpr, a:match, v:val])'
    \   ),
    \   ''
    \)
endfunction
function! ingo#subst#replacement#DefaultReplacer( expr, match, replacement )
    if a:replacement ==# '\n'
	return "\n"
    elseif a:replacement ==# '\r'
	return "\r"
    elseif a:replacement ==# '\t'
	return "\t"
    elseif a:replacement ==# '\b'
	return "\<BS>"
    elseif a:replacement =~# '^' . a:expr . '$'
	return submatch(a:replacement ==# '&' ? 0 : a:replacement[-1:-1])
    endif
    return ingo#escape#UnescapeExpr(a:replacement, '\%(\\\|' . a:expr . '\)')
endfunction
function! ingo#subst#replacement#DefaultReplacementOnPredicate( predicate, contextObject )
    if a:predicate
	let a:contextObject.lastLnum = line('.')
	if a:contextObject.replacement =~# '^\\='
	    " Handle sub-replace-special.
	    return eval(a:contextObject.replacement[2:])
	else
	    " Handle & and \0, \1 .. \9, and \r\n\t\b (but not \u, \U, etc.)
	    return ingo#subst#replacement#ReplaceSpecial('', a:contextObject.replacement, '\%(&\|\\[0-9rnbt]\)', function('ingo#subst#replacement#DefaultReplacer'))
	endif
    else
	return submatch(0)
    endif
endfunction

" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
autoload/ingo/swap.vim	[[[1
45
" ingo/swap.vim: Functions around the swap file.
"
" DEPENDENCIES:
"   - ingo/buffer/visible.vim autoload script
"
" Copyright: (C) 2016 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
"
" REVISION	DATE		REMARKS
"   1.025.001	29-Jan-2016	file creation

function! ingo#swap#GetNameImpl()
    " Use silent! so a failing redir (e.g. recursive redir call) won't hurt.
    silent! redir => o | silent swapname | redir END
    return (o[1:] ==# 'No swap file' ? '' : o[1:])
	return ''
    else
	return o[1:]
    endif
endfunction
function! ingo#swap#GetName( ... )
"******************************************************************************
"* PURPOSE:
"   Obtain the filespec of the swap file (like :swapname), for the current
"   buffer or the passed buffer number.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:bufnr Optional buffer number of an existing buffer where the swap file
"	    should be obtained from.
"* RETURN VALUES:
"   filespec of current swapfile, or empty string.
"******************************************************************************
    if a:0
	silent! return ingo#buffer#visible#Call(a:1, 'ingo#swap#GetNameImpl', [])
    else
	return ingo#swap#GetNameImpl()
    endif
endfunction

" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
autoload/ingo/syntaxitem.vim	[[[1
57
" ingo/syntaxitem.vim: Functions for retrieving information about syntax items.
"
" DEPENDENCIES:
"   - ingo/compat.vim autoload script
"
" Copyright: (C) 2011-2017 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>

function! ingo#syntaxitem#IsOnSyntax( pos, syntaxItemPattern, ... )
"******************************************************************************
"* PURPOSE:
"   Test whether on a:pos one of the syntax items in the stack matches
"   a:syntaxItemPattern.
"
"   Taking the example of comments:
"   Other syntax groups (e.g. Todo) may be embedded in comments. We must thus
"   check whole stack of syntax items at the cursor position for comments.
"   Comments are detected via the translated, effective syntax name. (E.g. in
"   Vimscript, "vimLineComment" is linked to "Comment".) A complication is with
"   fold markers. These are embedded in comments, so a stack for
"	" Public API for session persistence. {{{1
"	execute 'mksession' fnameescape(tempfile)
"   is this:
"	vimString -> vimExecute -> vimFoldTry -> vimFoldTryContainer ->
"	vimFuncBody -> vimFoldMarker -> vimLineComment
"   As we don't want to consider the fold marker comment, which is enclosing all
"   of the code, we add a stopItemPattern for 'FoldMarker$'.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:pos	        [bufnum, lnum, col, off] (as returned from |getpos()|)
"   a:syntaxItemPattern Regular expresson for the syntax item name.
"   a:stopItemPattern	Regular expresson for a syntax item name that stops
"			looking further down the syntax stack.
"* RETURN VALUES:
"   0 if no syntax name on the stack matches a:syntaxItemPattern, or a syntax
"   name higher on the stack already matches a:stopItemPattern. Else 1.
"******************************************************************************
    for l:id in reverse(ingo#compat#synstack(a:pos[1], a:pos[2]))
	let l:actualSyntaxItemName = synIDattr(l:id, 'name')
	let l:effectiveSyntaxItemName = synIDattr(synIDtrans(l:id), 'name')
"****D echomsg '****' l:actualSyntaxItemName . '->' . l:effectiveSyntaxItemName
	if a:0 && ! empty(a:1) && (l:actualSyntaxItemName =~# a:1 || l:effectiveSyntaxItemName =~# a:1)
	    return 0
	endif
	if l:actualSyntaxItemName =~# a:syntaxItemPattern || l:effectiveSyntaxItemName =~# a:syntaxItemPattern
	    return 1
	endif
    endfor
    return 0
endfunction

" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
autoload/ingo/system.vim	[[[1
29
" ingo/system.vim: Functions for invoking shell commands.
"
" DEPENDENCIES:
"
" Copyright: (C) 2013 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
"
" REVISION	DATE		REMARKS
"   1.003.001	22-Mar-2013	file creation

function! ingo#system#Chomped( ... )
"******************************************************************************
"* PURPOSE:
"   Wrapper around system() that strips off trailing newline(s).
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   As |system()|
"* RETURN VALUES:
"   Output of the shell command, without trailing newline(s).
"******************************************************************************
    return substitute(call('system', a:000), '\n\+$', '', '')
endfunction

" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
autoload/ingo/tabpage.vim	[[[1
32
" ingo/tabpage.vim: Functions for tab page information.
"
" DEPENDENCIES:
"
" Copyright: (C) 2017 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
let s:save_cpo = &cpo
set cpo&vim

function! ingo#tabpage#IsBlank( ... )
    if a:0
	let l:tabPageNr = a:1
	let l:currentBufNr = tabpagebuflist(l:tabPageNr)[0]
    else
	let l:tabPageNr = tabpagenr()
	let l:currentBufNr = bufnr('')
    endif

    return (
    \   empty(bufname(l:currentBufNr)) &&
    \   tabpagewinnr(l:tabPageNr, '$') <= 1 &&
    \   getbufvar(l:currentBufNr, '&modified') == 0 &&
    \   empty(getbufvar(l:currentBufNr, '&buftype'))
    \)
return l:isEmptyTabPage
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo
" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
autoload/ingo/tabstops.vim	[[[1
118
" ingo/tabstops.vim: Functions to render and deal with the dynamic width of <Tab> characters.
"
" DEPENDENCIES:
"   - ingo/compat.vim autoload script
"
" Copyright: (C) 2008-2013 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
"
" REVISION	DATE		REMARKS
"   1.009.008	27-Jun-2013	FIX: ingo#tabstops#RenderMultiLine() doesn't
"				pass an optional second a:startColumn argument.
"				Rewrite the forwarding.
"   1.009.007	26-Jun-2013	Add ingo#tabstops#RenderMultiLine(), as
"				ingo#tabstops#Render() does not properly render
"				multi-line text.
"   1.008.006	07-Jun-2013	Fix the rendering for text containing
"				unprintable ASCII and double-width (east Asian)
"				characters. The assumption index == char width
"				doesn't work there; so determine the actual
"				screen width via strdisplaywidth().
"   1.008.005	07-Jun-2013	Move into ingo-library.
"	004	05-Jun-2013	In EchoWithoutScrolling#RenderTabs(), make
"				a:tabstop and a:startColumn optional.
"	003	15-May-2009	Added utility function
"				EchoWithoutScrolling#TranslateLineBreaks() to
"				help clients who want to echo a single line, but
"				have text that potentially contains line breaks.
"	002	16-Aug-2008	Split off TruncateTo() from Truncate().
"	001	22-Jul-2008	file creation
let s:save_cpo = &cpo
set cpo&vim

function! ingo#tabstops#DisplayWidth( column, tabstop )
    return a:tabstop - (a:column - 1) % a:tabstop
endfunction
function! ingo#tabstops#Render( text, ... )
"*******************************************************************************
"* PURPOSE:
"   Replaces <Tab> characters in a:text with the correct amount of <Space>,
"   depending on the a:tabstop value. a:startColumn specifies at which start
"   column a:text will be printed.
"* ASSUMPTIONS / PRECONDITIONS:
"   none
"* EFFECTS / POSTCONDITIONS:
"   none
"* INPUTS:
"   a:text	    Text to be rendered. If the text contains newline
"		    characters, the rendering will be wrong in subsequent lines.
"		    Use ingo#tabstops#RenderMultiLine() then.
"   a:tabstop	    tabstop value (The built-in :echo command always uses a
"		    fixed value of 8; it isn't affected by the 'tabstop'
"		    setting.) Defaults to the buffer's 'tabstop' value.
"   a:startColumn   Column at which the text is to be rendered (default 1).
"* RETURN VALUES:
"   a:text with replaced <Tab> characters.
"*******************************************************************************
    if a:text !~# "\t"
	return a:text
    endif

    let l:tabstop = (a:0 ? a:1 : &l:tabstop)
    let l:startColumn = (a:0 > 1 ? a:2 : 1)
    let l:pos = 0
    let l:width = l:startColumn - 1
    let l:text = a:text
    while l:pos < strlen(l:text)
	let l:newPos = stridx(l:text, "\t", l:pos)
	if l:newPos == -1
	    break
	endif
	let l:newPart = strpart(l:text, l:pos, l:newPos - l:pos)
	let l:newWidth = ingo#compat#strdisplaywidth(l:newPart) " Note: strdisplaywidth() takes into account the current 'tabstop' value, but since we're never passing a <Tab> character into it, this doesn't matter here.
	let l:tabWidth = ingo#tabstops#DisplayWidth(1 + l:width + l:newWidth, l:tabstop)    " Here we're considering the current buffer's / passed 'tabstop' value.
	let l:text = strpart(l:text, 0, l:newPos) . repeat(' ', l:tabWidth) . strpart(l:text, l:newPos + 1)
"****D echomsg '****' l:pos l:width string(strtrans(l:newPart)) l:newWidth l:tabWidth
"****D echomsg '####' string(strtrans(l:text))
	let l:pos = l:newPos + l:tabWidth
	let l:width += l:newWidth + l:tabWidth
    endwhile

    return l:text
endfunction
function! ingo#tabstops#RenderMultiLine( text, ... )
"*******************************************************************************
"* PURPOSE:
"   Replaces <Tab> characters (in potentially multiple lines in) a:text with the
"   correct amount of <Space>, depending on the a:tabstop value. a:startColumn
"   specifies at which start column (each line of) a:text will be printed.
"* ASSUMPTIONS / PRECONDITIONS:
"   none
"* EFFECTS / POSTCONDITIONS:
"   none
"* INPUTS:
"   a:text	    Text to be rendered. Each line (i.e. substring delimited by
"		    newline characters) will be rendered separately and
"		    therefore correctly.
"   a:tabstop	    tabstop value (The built-in :echo command always uses a
"		    fixed value of 8; it isn't affected by the 'tabstop'
"		    setting.) Defaults to the buffer's 'tabstop' value.
"   a:startColumn   Column at which the text is to be rendered (default 1).
"* RETURN VALUES:
"   a:text with replaced <Tab> characters.
"*******************************************************************************
    return
    \   join(
    \       map(
    \           split(a:text, '\n', 1),
    \           'call("ingo#tabstops#Render", [v:val] + a:000)'
    \       ),
    \       "\n"
    \   )
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo
" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
autoload/ingo/text.vim	[[[1
267
" ingo/text.vim: Function for getting and setting text in the current buffer.
"
" DEPENDENCIES:
"   - ingo/mbyte/virtcol.vim autoload script
"   - ingo/pos.vim autoload script
"   - ingo/regexp/virtcols.vim autoload script
"
" Copyright: (C) 2012-2018 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>

function! ingo#text#Get( startPos, endPos, ... )
"*******************************************************************************
"* PURPOSE:
"   Extract the text between a:startPos and a:endPos from the current buffer.
"   Multiple lines will be delimited by a newline character.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:startPos	    [line, col]; col is the 1-based byte-index.
"   a:endPos	    [line, col]; col is the 1-based byte-index.
"   a:isExclusive   Flag whether a:endPos is exclusive; by default, the
"		    character at that position is included; pass 1 to exclude
"		    it.
"* RETURN VALUES:
"   string text
"*******************************************************************************
    let [l:exclusiveOffset, l:exclusiveMatch] = (a:0 && a:1 ? [1, ''] : [0, '.'])
    let [l:line, l:column] = a:startPos
    let [l:endLine, l:endColumn] = a:endPos
    if ingo#pos#IsAfter([l:line, l:column], [l:endLine, l:endColumn + l:exclusiveOffset])
	return ''
    endif

    let l:text = ''
    while 1
	if l:line == l:endLine
	    let l:text .= matchstr(getline(l:line) . "\n", '\%' . l:column . 'c' . '.*\%' . l:endColumn . 'c' . l:exclusiveMatch)
	    break
	else
	    let l:text .= matchstr(getline(l:line) . "\n", '\%' . l:column . 'c' . '.*')
	    let l:line += 1
	    let l:column = 1
	endif
    endwhile
    return l:text
endfunction
function! ingo#text#GetFromArea( area, ... )
"*******************************************************************************
"* PURPOSE:
"   Extract the text in the area of [startPos, endPos] from the current
"   buffer. Multiple lines will be delimited by a newline character.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:area	    [[startLnum, startCol], [endLnum, endCol]]; col is the
"		    1-based byte-index.
"   a:isExclusive   Flag whether a:endPos is exclusive; by default, the
"		    character at that position is included; pass 1 to exclude
"		    it.
"* RETURN VALUES:
"   string text
"*******************************************************************************
    if a:area[0][0] == 0 || a:area[1][0] == 0
	return ''
    endif
    return call('ingo#text#Get', a:area + a:000)
endfunction

function! ingo#text#GetChar( startPos, ... )
"*******************************************************************************
"* PURPOSE:
"   Extract one / a:count character(s) from a:startPos from the current buffer.
"   Only considers the current line.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:startPos	    [line, col]; col is the 1-based byte-index.
"   a:count         Optional number of characters to extract; default 1.
"		    If this is a negative number, tries to extract as many as
"		    possible instead of not matching.
"* RETURN VALUES:
"   string text, or empty string if no(t enough) character(s).
"*******************************************************************************
    let [l:line, l:column] = a:startPos
    let [l:count, l:isUpTo] = (a:0 ? (a:1 > 0 ? [a:1, 0] : [-1 * a:1, 1]) : [0, 0])

    return matchstr(getline(l:line), '\%' . l:column . 'c' . '.' . (l:count ? '\{' . (l:isUpTo ? ',' : '') . l:count . '}' : ''))
endfunction
function! ingo#text#GetCharBefore( startPos, ... )
"*******************************************************************************
"* PURPOSE:
"   Extract one / a:count character(s) before a:startPos from the current buffer.
"   Only considers the current line.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:startPos	    [line, col]; col is the 1-based byte-index.
"   a:count         Optional number of characters to extract; default 1.
"		    If this is a negative number, tries to extract as many as
"		    possible instead of not matching.
"* RETURN VALUES:
"   string text, or empty string if no(t enough) character(s).
"*******************************************************************************
    let [l:line, l:column] = a:startPos
    let [l:count, l:isUpTo] = (a:0 ? (a:1 > 0 ? [a:1, 0] : [-1 * a:1, 1]) : [0, 0])

    return matchstr(getline(l:line), '.' . (l:count ? '\{' . (l:isUpTo ? ',' : '') . l:count . '}' : '') . '\%' . l:column . 'c')
endfunction
function! ingo#text#GetCharVirtCol( startPos, ... )
"*******************************************************************************
"* PURPOSE:
"   Extract one / a:count character(s) from a:startPos from the current buffer.
"   Only considers the current line.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:startPos	    [line, virtcol]; virtcol is the 1-based screen column.
"   a:count         Optional number of characters to extract; default 1.
"		    If this is a negative number, tries to extract as many as
"		    possible instead of not matching.
"* RETURN VALUES:
"   string text, or empty string if no(t enough) character(s).
"*******************************************************************************
    let l:startBytePos = [a:startPos[0], ingo#mbyte#virtcol#GetColOfVirtCol(a:startPos[0], a:startPos[1])]
    return ingo#text#GetChar(l:startBytePos, (a:0 ? a:1 : 1))
endfunction

function! ingo#text#Insert( pos, text )
"******************************************************************************
"* PURPOSE:
"   Insert a:text at a:pos.
"* ASSUMPTIONS / PRECONDITIONS:
"   Buffer is modifiable.
"* EFFECTS / POSTCONDITIONS:
"   Changes the buffer.
"* INPUTS:
"   a:pos   [line, col]; col is the 1-based byte-index.
"   a:text  String to insert.
"* RETURN VALUES:
"   Flag whether the position existed (inserting in column 1 of one line beyond
"   the last one is also okay) and insertion was done.
"******************************************************************************
    let [l:lnum, l:col] = a:pos
    if l:lnum > line('$') + 1
	return 0
    endif

    let l:line = getline(l:lnum)
    if l:col > len(l:line) + 1
	return 0
    elseif l:col < 1
	throw 'Insert: Column must be at least 1'
    elseif l:col == 1
	return (setline(l:lnum, a:text . l:line) == 0)
    elseif l:col == len(l:line) + 1
	return (setline(l:lnum, l:line . a:text) == 0)
    elseif l:col == len(l:line) + 1
	return (setline(l:lnum, l:line . a:text) == 0)
    endif
    return (setline(l:lnum, strpart(l:line, 0, l:col - 1) . a:text . strpart(l:line, l:col - 1)) == 0)
endfunction
function! ingo#text#Remove( pos, len )
"******************************************************************************
"* PURPOSE:
"   Remove a:len bytes of text at a:pos.
"* ASSUMPTIONS / PRECONDITIONS:
"   Buffer is modifiable.
"* EFFECTS / POSTCONDITIONS:
"   Changes the buffer.
"* INPUTS:
"   a:pos   [line, col]; col is the 1-based byte-index.
"   a:len   Number of bytes to remove.
"* RETURN VALUES:
"   Flag whether the position existed and removal was done.
"******************************************************************************
    let [l:lnum, l:col] = a:pos
    if l:lnum > line('$')
	return 0
    endif

    let l:line = getline(l:lnum)
    if l:col > len(l:line)
	return 0
    elseif l:col < 1
	throw 'Remove: Column must be at least 1'
    endif
    return (setline(l:lnum, strpart(l:line, 0, l:col - 1) . strpart(l:line, l:col - 1 + a:len)) == 0)
endfunction
function! ingo#text#ReplaceChar( startPos, replacement, ... )
"******************************************************************************
"* PURPOSE:
"   Replace one / a:count character(s) from a:startPos with a:replacement.
"* ASSUMPTIONS / PRECONDITIONS:
"   Buffer is modifiable.
"* EFFECTS / POSTCONDITIONS:
"   Changes the buffer.
"* INPUTS:
"   a:startPos	    [line, col]; col is the 1-based byte-index.
"   a:replacement   String to be put into the buffer.
"   a:count         Optional number of characters to replace; default 1.
"		    If this is a negative number, tries to extract as many as
"		    possible instead of not matching.
"* RETURN VALUES:
"   Original string text that got replaced, or empty string if the position does
"   not exist and no replacement was done.
"******************************************************************************
    let l:originalText = call('ingo#text#GetChar', [a:startPos] + a:000)
    if empty(l:originalText)
	return ''
    endif

    let [l:lnum, l:col] = a:startPos
    let l:line = getline(l:lnum)
    let l:len = len(l:originalText)
    if setline(l:lnum, strpart(l:line, 0, l:col - 1) . a:replacement . strpart(l:line, l:col - 1 + l:len)) == 0
	return l:originalText
    else
	return ''
    endif
endfunction
function! ingo#text#RemoveVirtCol( pos, width, isAllowSmaller )
"******************************************************************************
"* PURPOSE:
"   Remove a:width screen columns of text at a:pos.
"* ASSUMPTIONS / PRECONDITIONS:
"   Buffer is modifiable.
"* EFFECTS / POSTCONDITIONS:
"   Changes the buffer.
"* INPUTS:
"   a:pos   [line, virtcol]; virtcol is the 1-based screen column.
"   a:width Number of screen columns.
"   a:isAllowSmaller    Boolean flag whether less characters can be removed if
"			the end doesn't fall on a character border, or there
"			aren't that many characters.
"* RETURN VALUES:
"   Flag whether the position existed and removal was done.
"******************************************************************************
    let [l:lnum, l:virtcol] = a:pos
    if l:lnum > line('$') || a:width <= 0
	return 0
    endif

    if l:virtcol < 1
	throw 'Remove: Column must be at least 1'
    endif
    let l:line = getline(l:lnum)
    let l:newLine = substitute(l:line, ingo#regexp#virtcols#ExtractCells(l:virtcol, a:width, a:isAllowSmaller), '', '')
    if l:newLine ==# l:line
	return 0
    else
	return setline(l:lnum, l:newLine)
    endif
endfunction

" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
autoload/ingo/text/frompattern.vim	[[[1
153
" ingo/text/frompattern.vim: Functions to get matches from the current buffer.
"
" DEPENDENCIES:
"
" Copyright: (C) 2013-2017 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
"
" REVISION	DATE		REMARKS
"   1.025.004	06-May-2015	Add ingo#text#frompattern#GetAroundHere(),
"				inspired by
"				http://stackoverflow.com/questions/30073662/vim-copy-match-with-cursor-position-atom-to-local-variable
"   1.024.003	17-Apr-2015	ingo#text#frompattern#GetHere(): Do not move the
"				cursor (to the end of the matched pattern); this
"				is unexpected and can be easily avoided.
"   1.014.002	27-Sep-2013	Add ingo#text#frompattern#GetHere().
"   1.012.001	03-Sep-2013	file creation

function! ingo#text#frompattern#GetHere( pattern, ... )
"******************************************************************************
"* PURPOSE:
"   Extract the match of a:pattern starting from the current cursor position.
"* SEE ALSO:
"   - ingo#area#frompattern#GetHere() returns the positions, not the match.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:pattern       Regular expression to search. 'ignorecase', 'smartcase' and
"		    'magic' applies. When empty, the last search pattern |"/| is
"		    used.
"   a:lastLine      End line number to search for the start of the pattern.
"		    Optional; defaults to the current line.
"* RETURN VALUES:
"   Matched text, or empty string.
"******************************************************************************
    let l:startPos = getpos('.')[1:2]
    let l:endPos = searchpos(a:pattern, 'cenW', (a:0 ? a:1 : line('.')))
    if l:endPos == [0, 0]
	return ''
    endif
    return ingo#text#Get(l:startPos, l:endPos)
endfunction
function! ingo#text#frompattern#GetAroundHere( pattern, ... )
"******************************************************************************
"* PURPOSE:
"   Extract the match of a:pattern starting the match from the current cursor
"   position, but (unlike ingo#text#frompattern#GetHere()), also include matched
"   characters _before_ the current position.
"* SEE ALSO:
"   - ingo#area#frompattern#GetAroundHere() returns the positions, not the match.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:pattern       Regular expression to search. 'ignorecase', 'smartcase' and
"		    'magic' applies. When empty, the last search pattern |"/| is
"		    used.
"   a:lastLine      End line number to search for the start of the pattern.
"		    Optional; defaults to the current line.
"   a:firstLine     First line number to search for the start of the pattern.
"		    Optional; defaults to the current line.
"* RETURN VALUES:
"   Matched text, or empty string.
"******************************************************************************
    let l:startPos = searchpos(a:pattern, 'bcnW', (a:0 >= 2 ? a:2 : line('.')))
    if l:startPos == [0, 0]
	return ''
    endif
    let l:endPos = searchpos(a:pattern, 'cenW', (a:0 ? a:1 : line('.')))
    if l:endPos == [0, 0]
	return ''
    endif
    return ingo#text#Get(l:startPos, l:endPos)
endfunction


function! s:UniqueAdd( list, expr )
    if index(a:list, a:expr) == -1
	call add(a:list, a:expr)
    endif
endfunction
function! ingo#text#frompattern#Get( firstLine, lastLine, pattern, replacement, isOnlyFirstMatch, isUnique )
"******************************************************************************
"* PURPOSE:
"   Extract all non-overlapping matches of a:pattern in the a:firstLine,
"   a:lastLine range and return them (optionally a submatch / replacement, or
"   only first or unique matches) as a List.
"* SEE ALSO:
"   - ingo#str#frompattern#Get() extracts matches from a string / List of lines
"     instead of the current buffer.
"   - ingo#area#frompattern#Get() returns the positions, not the matches.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:firstLine     Start line number to search.
"   a:lastLine      End line number to search.
"   a:pattern       Regular expression to search. 'ignorecase', 'smartcase' and
"		    'magic' applies. When empty, the last search pattern |"/| is
"		    used.
"   a:replacement   Optional replacement substitute(). When not empty, each
"		    match is processed through substitute() with a:pattern.
"		    When a:pattern cannot be used (e.g. because it references
"		    cursor or buffer position via special atoms like \%# and
"		    therefore doesn't work standalone), you can also pass a
"		    [replPattern, replacement] tuple, which will then be
"		    globally applied to the match.
"   a:isOnlyFirstMatch  Flag whether to include only the first match in every
"			line.
"   a:isUnique          Flag whether duplicate matches are omitted from the
"			result. When set, the result will consist of unique
"			matches.
"* RETURN VALUES:
"   List of (optionally replaced) matches, or empty List when no matches.
"******************************************************************************
    let l:save_view = winsaveview()
	let l:matches = []
	call cursor(a:firstLine, 1)
	let l:isFirst = 1
	while 1
	    let l:startPos = searchpos(a:pattern, (l:isFirst ? 'c' : '') . 'W', a:lastLine)
	    let l:isFirst = 0
	    if l:startPos == [0, 0] | break | endif
	    let l:endPos = searchpos(a:pattern, 'ceW', a:lastLine)
	    if l:endPos == [0, 0] | break | endif
	    let l:match = ingo#text#Get(l:startPos, l:endPos)
	    if ! empty(a:replacement)
		if type(a:replacement) == type([])
		    let l:match = substitute(l:match, a:replacement[0], a:replacement[1], 'g')
		else
		    let l:match = substitute(l:match, (empty(a:pattern) ? @/ : a:pattern), a:replacement, '')
		endif
	    endif
	    if a:isUnique
		call s:UniqueAdd(l:matches, l:match)
	    else
		call add(l:matches, l:match)
	    endif
"****D echomsg '****' string(l:startPos) string(l:endPos) string(l:match)
	    if a:isOnlyFirstMatch
		normal! $
	    endif
	endwhile
    call winrestview(l:save_view)
    return l:matches
endfunction

" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
autoload/ingo/text/replace.vim	[[[1
182
" ingo/text/replace.vim: Functions to replace a pattern with text.
"
" DEPENDENCIES:
"   - ingo/msg.vim autoload script
"
" Copyright: (C) 2012-2019 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>

function! s:ReplaceRange( source, startIdx, endIdx, string )
    return strpart(a:source, 0, a:startIdx) . a:string . strpart(a:source, a:endIdx + 1)
endfunction

function! ingo#text#replace#Between( startPos, endPos, Text )
"******************************************************************************
"* PURPOSE:
"   Replace the text between a:startPos and a:endPos from the current buffer
"   with a:Text.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   Modifies current buffer.
"   Sets the change marks '[,'] to the modified area.
"* INPUTS:
"   a:startPos  [line, col]
"   a:endPos    [line, col]
"   a:Text      Replacement text, or Funcref that gets passed the text to
"		replace, and returns the replacement text.
"* RETURN VALUES:
"   List of [originalText, replacementText, didReplacement].
"******************************************************************************
    if a:startPos[0] != a:endPos[0]
	throw 'Multi-line replacement not implemented yet'
    endif

    let l:line = getline(a:startPos[0])
    let l:currentText = strpart(l:line, a:startPos[1] - 1, (a:endPos[1] - a:startPos[1] + 1))
    if type(a:Text) == type(function('tr'))
	let l:text = call(a:Text, [l:currentText])
    else
	let l:text = a:Text
    endif

    " Because of setline(), we can only (easily) handle text replacement in a
    " single line, so replace with the first (non-empty) line only should the
    " replacement text consist of multiple lines.
    let l:text = split(l:text, "\n", 1)[0]

    if l:currentText !=# l:text
	call setline(a:startPos[0], s:ReplaceRange(l:line, a:startPos[1] - 1, a:endPos[1] - 1, l:text))
	call ingo#change#Set(a:startPos, ingo#pos#Make4(a:startPos[0], a:startPos[1] + len(l:text) - len(matchstr(l:text, '.$'))))
	return [l:currentText, l:text, 1]
    else
	" The range already contains the new text in the correct format, no
	" replacement was done.
	return [l:currentText, l:text, 0]
    endif
endfunction
function! ingo#text#replace#Area( area, Text )
"******************************************************************************
"* PURPOSE:
"   Replace the text in the area of [startPos, endPos] from the current buffer
"   with a:Text.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   Modifies current buffer.
"   Sets the change marks '[,'] to the modified area.
"* INPUTS:
"   a:area      [[startLnum, startCol], [endLnum, endCol]]; col is the 1-based
"		byte-index.
"   a:Text      Replacement text, or Funcref that gets passed the text to
"		replace, and returns the replacement text.
"* RETURN VALUES:
"   List of [originalText, replacementText, didReplacement].
"******************************************************************************
    return call('ingo#text#replace#Between', a:area + [a:Text])
endfunction
function! s:ReplaceTextInRange( startIdx, endIdx, Text, where )
    let [l:originalText, l:replacementText, l:didReplacement] = ingo#text#replace#Between([line('.'), a:startIdx + 1], [line('.'), a:endIdx + 1], a:Text)
    if l:didReplacement
	call cursor(line('.'), a:startIdx + 1)
	return {'startIdx': a:startIdx, 'endIdx': a:endIdx, 'original': l:originalText, 'replacement': l:replacementText, 'where': a:where}
    else
	return []
    endif
endfunction

function! ingo#text#replace#PatternWithText( pattern, Text, ... )
"******************************************************************************
"* PURPOSE:
"   Replace occurrences of a:pattern in the current line with a:text.
"* ASSUMPTIONS / PRECONDITIONS:
"   Current buffer is modifiable.
"* EFFECTS / POSTCONDITIONS:
"   Changes the current line.
"* INPUTS:
"   a:pattern   Regular expression that defines the text to replace.
"   a:Text      Replacement text, or Funcref that gets passed the text to
"		replace, and returns the replacement text.
"   a:strategy  Array of locations where in the current line a:pattern will
"		match. Possible values: 'current', 'next', 'last'. The default
"		is ['current', 'next'], to have the same behavior as the
"		built-in "*" command.
"* RETURN VALUES:
"   Object with replacement information: {'startIdx', 'endIdx', 'original',
"   'replacement', 'where'}, or empty Dictionary if no replacement was done.
"******************************************************************************
    let l:strategy = (a:0 ? copy(a:1) : ['current', 'next'])

    " Substitute any of the text patterns with the current text in the current
    " text format.
    let l:line = getline('.')

    while ! empty(l:strategy)
	let l:location = remove(l:strategy, 0)
	if l:location ==# 'current'
	    " If the cursor is positioned on a text, update that one.
	    let l:cursorIdx = col('.') - 1
	    let l:startIdx = 0
	    let l:count = 0
	    while l:startIdx != -1
		let l:count += 1
		let l:startIdx = match(l:line, a:pattern, 0, l:count)
		let l:endIdx = matchend(l:line, a:pattern, 0, l:count) - 1
		if l:startIdx <= l:cursorIdx && l:cursorIdx <= l:endIdx
"****D echomsg '**** cursor match from ' . l:startIdx . ' to ' . l:endIdx
		    let l:result = s:ReplaceTextInRange(l:startIdx, l:endIdx, a:Text, '%s at cursor position')
		    if ! empty(l:result) | return l:result | endif
		endif
	    endwhile
	    let l:maxCount = l:count
	elseif l:location ==# 'next'
	    " Update the next text (that is not already the current text and
	    " format) found in the line.
	    let l:cursorIdx = col('.') - 1
	    let l:startIdx = 0
	    let l:count = 0
	    while l:startIdx != -1
		let l:count += 1
		let l:startIdx = match(l:line, a:pattern, l:cursorIdx, l:count)
		let l:endIdx = matchend(l:line, a:pattern, l:cursorIdx, l:count) - 1
"****D echomsg '**** next match from ' . l:startIdx . ' to ' . l:endIdx
		if l:startIdx != -1
		    let l:result = s:ReplaceTextInRange(l:startIdx, l:endIdx, a:Text, 'next %s in line')
		    if ! empty(l:result) | return l:result | endif
		endif
	    endwhile
	elseif l:location ==# 'last'
	    " Update the last text (that is not already the current text and
	    " format) found in the line. This will update non-current texts from last to
	    " first on subsequent invocations until all occurrences are current.
	    let l:count = (exists('l:maxCount') ? l:maxCount - 1 : len(l:line))   " XXX: This is ineffective but easier than first counting the matches.
	    while l:count > 0
		let l:startIdx = match(l:line, a:pattern, 0, l:count)
		let l:endIdx = matchend(l:line, a:pattern, 0, l:count) - 1
"****D echomsg '**** last match from ' . l:startIdx . ' to ' . l:endIdx . ' at count ' . l:count
		if l:startIdx != -1
		    let l:result = s:ReplaceTextInRange(l:startIdx, l:endIdx, a:Text, 'last %s in line')
		    if ! empty(l:result) | return l:result | endif
		endif
		let l:count -= 1
	    endwhile
	else
	    throw 'ASSERT: Unknown strategy location: ' . l:location
	endif
    endwhile

    return {}
endfunction
function! ingo#text#replace#PatternWithTextAndMessage( what, pattern, text, ... )
    let l:replacement = call('ingo#text#replace#PatternWithText', [a:pattern, a:text] + a:000)
    if empty(l:replacement)
	call ingo#msg#WarningMsg(printf('No %s was found in this line', a:what))
    else
	echo 'Updated' printf(l:replacement.where, a:what)
    endif
    return l:replacement
endfunction

" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
autoload/ingo/undo.vim	[[[1
72
" ingo/undo.vim: Functions for undo and dealing with changes.
"
" DEPENDENCIES:
"
" Copyright: (C) 2014-2018 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>

function! ingo#undo#GetChangeNumber()
"******************************************************************************
"* PURPOSE:
"   Get the current change number, for use e.g. with :undo {N}.
"   In contrast to changenr(), this number always represents the current state
"   of the buffer, also after undo. If necessary, the function creates a new
"   no-op change.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   May make an additional no-op change.
"* INPUTS:
"   None.
"* RETURN VALUES:
"   Change number, for use with :undo {N}. -1 if undo is not supported.
"******************************************************************************
    if ! ingo#undo#IsEnabled()
	return -1
    endif

    if exists('*undotree')
	let l:undotree = undotree()
	let l:isLastChange = (l:undotree.seq_cur == l:undotree.seq_last)
    else
	redir => l:undolistOutput
	    silent! undolist
	redir END
	let l:undoChangeNumber = str2nr(split(l:undolistOutput, "\n")[-1])
	let l:isLastChange = (l:undoChangeNumber == changenr())
    endif

    if ! l:isLastChange
	" Create a new undo point, to be sure to return to the current state,
	" and not some undone earlier state.
	silent! call setline('$', getline('$'))
"****D echomsg '**** no-op change'
    endif

    return changenr()
endfunction

function! ingo#undo#IsEnabled( ... )
"******************************************************************************
"* PURPOSE:
"   Check whether (at least N levels of) undo is enabled.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:N Number of undo levels that must be supported.
"* RETURN VALUES:
"   1 if (N / one) level of undo is supported, else 0.
"******************************************************************************
    if a:0
	let l:undolevels = (&undolevels == 0 ? 1 : &undolevels)
	return (l:undolevels >= a:1)
    else
	return (&undolevels >= 0)
    endif
endfunction

" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
autoload/ingo/units.vim	[[[1
81
" ingo/units.vim: Functions for formatting number units.
"
" DEPENDENCIES:
"
" Copyright: (C) 2013 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
"
" REVISION	DATE		REMARKS
"   1.014.001	13-Nov-2013	file creation

function! ingo#units#Format( number, ... )
"******************************************************************************
"* PURPOSE:
"   Format a:number in steps of a:base (e.g. 1000), appending the a:base (e.g.
"   ['', 'k', 'M'], and returning a number with a:precision digits after the
"   decimal point.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:number    Original number to be formatted.
"   a:precision Number of digits returned after the decimal point. Default is 1.
"   a:units     List of unit strings, starting with factor 1, a:base, a:base *
"		a:base, ... Default is ['', 'k', 'M', 'G', ...]
"   a:base      Factor between the a:units; default 1000.
"* RETURN VALUES:
"   List of [formattedNumber, usedUnit].
"******************************************************************************
    let l:precision = (a:0 > 0 ? a:1 : 1)
    let l:units = (a:0 > 1 ? a:2 : ['', 'k', 'M', 'G', 'T', 'P', 'E', 'Z', 'Y'])
    let l:base = (a:0 > 2 ? a:3 : 1000)

    for l:i in range(len(l:units))
	let l:baseNumber = pow(l:base, len(l:units) - l:i - 1)
	if a:number / float2nr(l:baseNumber) > 0
	    break
	endif
    endfor

    return [printf('%0.' . l:precision . 'f', a:number / l:baseNumber), get(l:units, len(l:units) - l:i - 1, '')]
endfunction

function! ingo#units#FormatBytesDecimal( number, ... )
"******************************************************************************
"* PURPOSE:
"   Format a:number in decimal steps of 1000, using the metric units (KB, MB,
"   ...).
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:number    Original number to be formatted.
"   a:precision Number of digits returned after the decimal point. Default is 1.
"* RETURN VALUES:
"   List of [formattedNumber, usedUnit].
"******************************************************************************
    return ingo#units#Format(a:number, (a:0 ? a:1 : 1), ['B', 'kB', 'MB', 'GB', 'TB', 'PB', 'EB', 'ZB', 'YB'], 1000)
endfunction
function! ingo#units#FormatBytesBinary( number, ... )
"******************************************************************************
"* PURPOSE:
"   Format a:number in binary steps of 1024, using the IEC units (KiB, MiB,
"   ...).
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:number    Original number to be formatted.
"   a:precision Number of digits returned after the decimal point. Default is 1.
"* RETURN VALUES:
"   List of [formattedNumber, usedUnit].
"******************************************************************************
    return ingo#units#Format(a:number, (a:0 ? a:1 : 1), ['B', 'KiB', 'MiB', 'GiB', 'TiB', 'PiB', 'EiB', 'ZiB', 'YiB'], 1024)
endfunction

" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
autoload/ingo/view.vim	[[[1
75
" ingo/view.vim: Functions for saving and restoring the window's view.
"
" DEPENDENCIES:
"
" Copyright: (C) 2019 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:   Ingo Karkat <ingo@karkat.de>

" The functions here allow you to define internal mappings that, when they
" surround the right-hand side of your actual mapping, restore the current view
" in the current window. Define the right variant(s) based on the mapping
" mode(s), and whether a simple winsaveview() will do, or whether you need
" "extra strength" to relocate the current position via a temporary mark (when
" there are insertions / deletions above the current position, the recorded
" cursor position may be off).
"   noremap  <expr> <silent>  <SID>(WinSaveView)		ingo#view#Save(0)
"   inoremap <expr> <silent>  <SID>(WinSaveView)		ingo#view#Save(0)
"   noremap  <expr> <silent>  <SID>(WinSaveViewWithMark)	ingo#view#Save(1)
"   inoremap <expr> <silent>  <SID>(WinSaveViewWithMark)	ingo#view#Save(1)
" Use <Plug>(WinSaveView) from any mode at the beginning of a mapping to save
" the current window's view. This is a |:map-expr| which does not interfere with
" any pending <count> or mode.
"
" At the end of the mapping, use <Plug>(WinRestView) from normal mode to restore
" the view and cursor position.
"   nnoremap <expr> <silent>  <SID>(WinRestView) ingo#view#Restore()
" Example: >
"   nnoremap <script> <SID>(WinSaveView)<SID>MyMapping<SID>(WinRestView)
" or :execute the ingo#view#RestoreCommands() directly (e.g. if the mapping asks
" for input).

let s:save_count = 0
function! ingo#view#Save( isUseMark )
    let s:save_count = v:count
    let w:save_view = winsaveview()
    if a:isUseMark
	try
	    let w:save_mark = ingo#plugin#marks#FindUnused()
	    let l:markExpr = "'" . w:save_mark
	    call setpos(l:markExpr, getpos('.'))
	catch /^ReserveMarks:/
	    " If no marks are available, just use the saved view. Grabbing a
	    " used mark and clobber its position could be worse than just be off
	    " with the restored view.
	    unlet! w:save_mark
	endtry
    else
	unlet! w:save_mark
    endif
    return ''
endfunction
function! ingo#view#RestoreCommands()
    let l:commands = []
    if exists('w:save_view')
	call add(l:commands, 'call winrestview(w:save_view)|unlet w:save_view')
    endif
    if exists('w:save_mark')
	call add(l:commands, printf("execute 'silent! normal! g`%s'|call setpos(\"'%s\", [0, 0, 0, 0])|unlet! w:save_mark", w:save_mark, w:save_mark))
    endif
    return join(l:commands, '|')
endfunction
function! ingo#view#Restore()
    let l:commands = ingo#view#RestoreCommands()
    return (empty(l:commands) ? '' : "\<C-\>\<C-n>:" . ingo#view#RestoreCommands() . "\<CR>")
endfunction

" ingo#view#Restore[Commands]() clobber v:count, but you can for instance pass a
" Funcref to ingo#view#RestoredCount as the a:defaultCount optional argument to
" the repeatableMapping.vim functions to consider the saved value.
function! ingo#view#RestoredCount()
    return s:save_count
endfunction

" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
autoload/ingo/window.vim	[[[1
30
" ingo/window.vim: Functions for dealing with windows.
"
" DEPENDENCIES:
"
" Copyright: (C) 2017 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>

function! ingo#window#GotoNext( direction, ... )
"******************************************************************************
"* PURPOSE:
"   Go to the next window in a:direction.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   Activates another window.
"* INPUTS:
"   a:direction One of 'j', 'k', 'h', 'l'.
"   a:count     Number of windows to move (default 1).
"* RETURN VALUES:
"   1 if the move was successful, 0 if there's no [a:count] window[s] in that
"   direction.
"******************************************************************************
    let l:prevWinNr = winnr()
    execute (a:0 > 0 ? a:1 : '') . 'wincmd' a:direction
    return winnr() != l:prevWinNr
endfunction

" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
autoload/ingo/window/adjacent.vim	[[[1
73
" ingo/window/adjacent.vim: Functions around windows that are next to each other.
"
" DEPENDENCIES:
"   - ingo/window.vim autoload script
"
" Copyright: (C) 2017 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>

function! ingo#window#adjacent#FindHorizontal()
"******************************************************************************
"* PURPOSE:
"   Locate the windows that are left and right of the current window. If
"   multiple splits border a window, only that one that would be jumped to based
"   on the cursor position is selected.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   None.
"* RETURN VALUES:
"   List of window numbers, including the current window.
"******************************************************************************
    return s:Find('h', 'l')
endfunction
function! ingo#window#adjacent#FindVertical()
"******************************************************************************
"* PURPOSE:
"   Locate the windows that are above and below the current window. If multiple
"   splits border a window, only that one that would be jumped to based on the
"   cursor position is selected.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   None.
"* RETURN VALUES:
"   List of window numbers, including the current window.
"******************************************************************************
    return s:Find('k', 'j')
endfunction
function! s:Find( prevDirection, nextDirection )
    let l:originalWinNr = winnr()
    let l:previousWinNr = winnr('#') ? winnr('#') : 1

    let l:save_eventignore = &eventignore
    set eventignore=all
    try
	let l:winNrs = [winnr()]

	while ingo#window#GotoNext(a:prevDirection)
	    call insert(l:winNrs, winnr(), 0)
	endwhile

	execute l:originalWinNr . 'wincmd w'

	while ingo#window#GotoNext(a:nextDirection)
	    call add(l:winNrs, winnr())
	endwhile

	return l:winNrs
    finally
	execute l:previousWinNr . 'wincmd w'
	execute l:originalWinNr . 'wincmd w'

	let &eventignore = l:save_eventignore
    endtry
endfunction

" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
autoload/ingo/window/cmdwin.vim	[[[1
60
" ingo/window/cmdwin.vim: Functions for dealing with the command window.
"
" DEPENDENCIES:
"   - ingo/list.vim autoload script
"
" Copyright: (C) 2008-2013 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
"
" REVISION	DATE		REMARKS
"   1.014.004	15-Oct-2013	Replace conditional with ingo#list#Make().
"   1.011.003	23-Jul-2013	Change naming of augroup to match ingo-library
"				convention.
"   1.010.002	08-Jul-2013	Add prefix to exception thrown from
"				ingo#window#cmdwin#UndefineMappingForCmdwin().
"   1.004.001	08-Apr-2013	file creation from autoload/ingowindow.vim

" The command-line window is implemented as a window, so normal mode mappings
" apply here as well. However, certain actions cannot be performed in this
" special window. The 'CmdwinEnter' event can be used to redefine problematic
" normal mode mappings.
let s:CmdwinMappings = {}
function! ingo#window#cmdwin#UndefineMappingForCmdwin( mappings, ... )
"*******************************************************************************
"* PURPOSE:
"   Register mappings that should be undefined in the command-line window.
"   Previously registered mappings equal to a:mappings will be overwritten.
"* ASSUMPTIONS / PRECONDITIONS:
"   none
"* EFFECTS / POSTCONDITIONS:
"   :nnoremap <buffer> the a:mapping
"* INPUTS:
"   a:mapping	    Mapping (or list of mappings) to be undefined.
"   a:alternative   Optional mapping to be used instead. If omitted, the
"		    a:mapping is undefined (i.e. mapped to itself). If empty,
"		    a:mapping is mapped to <Nop>.
"* RETURN VALUES:
"   1 if accepted; 0 if autocmds not available
"*******************************************************************************
    let l:alternative = (a:0 > 0 ? (empty(a:1) ? '<Nop>' : a:1) : '')

    for l:mapping in ingo#list#Make(a:mappings)
	let s:CmdwinMappings[l:mapping] = l:alternative
    endfor
    return has('autocmd')
endfunction
function! s:UndefineMappings()
    for l:mapping in keys(s:CmdwinMappings)
	let l:alternative = s:CmdwinMappings[ l:mapping ]
	execute 'nnoremap <buffer> ' . l:mapping . ' ' . (empty(l:alternative) ? l:mapping : l:alternative)
    endfor
endfunction
if has('autocmd')
    augroup IngoLibraryCmdWin
	autocmd! CmdwinEnter * call <SID>UndefineMappings()
    augroup END
endif

" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
autoload/ingo/window/dimensions.vim	[[[1
110
" ingo/window/dimensions.vim: Functions for querying aspects of window dimensions.
"
" DEPENDENCIES:
"   - ingo/folds.vim autoload script
"
" Copyright: (C) 2008-2013 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
"
" REVISION	DATE		REMARKS
"   1.004.001	08-Apr-2013	file creation from autoload/ingowindow.vim

" Determine the number of lines in the passed range that aren't folded away;
" folded ranges count only as one line. Visible doesn't mean "currently
" displayed in the window"; for that, you could create the difference of the
" start and end winline(), or use ingo#window#dimensions#DisplayedLines().
function! ingo#window#dimensions#NetVisibleLines( startLine, endLine )
    return a:endLine - a:startLine + 1 - ingo#folds#FoldedLines(a:startLine, a:endLine)[1]
endfunction

" Determine the range of lines that are currently displayed in the window.
function! ingo#window#dimensions#DisplayedLines()
    let l:startLine = winsaveview().topline
    let l:endLine = l:startLine
    let l:screenLineCnt = 0
    while l:screenLineCnt < winheight(0)
	let l:lastFoldedLine = foldclosedend(l:endLine)
	if l:lastFoldedLine == -1
	    let l:endLine += 1
	else
	    let l:endLine = l:lastFoldedLine + 1
	endif

	let l:screenLineCnt += 1
    endwhile

    return [l:startLine, l:endLine - 1]
endfunction



function! ingo#window#dimensions#GetNumberWidth( isGetAbsoluteNumberWidth )
"******************************************************************************
"* PURPOSE:
"   Get the width of the number column for the current window.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:isGetAbsoluteNumberWidth	If true, assumes absolute number are requested.
"				Otherwise, determines whether 'number' or
"				'relativenumber' are actually set and calculates
"				based on the actual window settings.
"* RETURN VALUES:
"   Width for displaying numbers. To use the result for printf()-style
"   formatting of numbers, subtract 1:
"   printf('%' . (ingo#window#dimensions#GetNumberWidth(1) - 1) . 'd', l:lnum)
"******************************************************************************
    let l:maxNumber = 0
    " Note: 'numberwidth' is only the minimal width, can be more if...
    if &l:number || a:isGetAbsoluteNumberWidth
	" ...the buffer has many lines.
	let l:maxNumber = line('$')
    elseif exists('+relativenumber') && &l:relativenumber
	" ...the window width has more digits.
	let l:maxNumber = winheight(0)
    endif
    if l:maxNumber > 0
	let l:actualNumberWidth = strlen(string(l:maxNumber)) + 1
	return (l:actualNumberWidth > &l:numberwidth ? l:actualNumberWidth : &l:numberwidth)
    else
	return 0
    endif
endfunction

" Determine the number of virtual columns of the current window that are not
" used for displaying buffer contents, but contain window decoration like line
" numbers, fold column and signs.
function! ingo#window#dimensions#WindowDecorationColumns()
    let l:decorationColumns = 0
    let l:decorationColumns += ingo#window#dimensions#GetNumberWidth(0)

    if has('folding')
	let l:decorationColumns += &l:foldcolumn
    endif

    if has('signs')
	redir => l:signsOutput
	silent execute 'sign place buffer=' . bufnr('')
	redir END

	" The ':sign place' output contains two header lines.
	" The sign column is fixed at two columns.
	if len(split(l:signsOutput, "\n")) > 2
	    let l:decorationColumns += 2
	endif
    endif

    return l:decorationColumns
endfunction

" Determine the number of virtual columns of the current window that are
" available for displaying buffer contents.
function! ingo#window#dimensions#NetWindowWidth()
    return winwidth(0) - ingo#window#dimensions#WindowDecorationColumns()
endfunction

" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
autoload/ingo/window/locate.vim	[[[1
173
" ingo/window/locate.vim: Functions to locate a window.
"
" DEPENDENCIES:
"   - ingo/actions.vim autoload script
"
" Copyright: (C) 2016 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
"
" REVISION	DATE		REMARKS
"   1.028.001	25-Nov-2016	file creation

function! s:Match( winVarName, Predicate, winNr, ... )
    if a:0 >= 2 && a:winNr == a:2
	return 0
    endif
    let l:tabNr = (a:0 ? a:1 : tabpagenr())

    let l:value = gettabwinvar(l:tabNr, a:winNr, a:winVarName)
    return !! ingo#actions#EvaluateWithValOrFunc(a:Predicate, l:value)
endfunction

function! s:CheckTabPageNearest( tabNr, winVarName, Predicate, ... )
    let l:skipWinNr = (a:0 ? a:1 : 0)
    let [l:currentWinNr, l:previousWinNr, l:lastWinNr] = [tabpagewinnr(a:tabNr), tabpagewinnr(a:tabNr, '#'), tabpagewinnr(a:tabNr, '$')]
    if s:Match(a:winVarName, a:Predicate, l:currentWinNr, a:tabNr, l:skipWinNr)
	return [a:tabNr, l:currentWinNr]
    elseif s:Match(a:winVarName, a:Predicate, l:previousWinNr, a:tabNr, l:skipWinNr)
	return [a:tabNr, l:previousWinNr]
    endif

    let l:offset = 1
    while l:currentWinNr - l:offset > 0 || l:currentWinNr + l:offset <= l:lastWinNr
	if s:Match(a:winVarName, a:Predicate, l:currentWinNr - l:offset, a:tabNr, l:skipWinNr)
	    return [a:tabNr, l:currentWinNr - l:offset]
	elseif s:Match(a:winVarName, a:Predicate, l:currentWinNr + l:offset, a:tabNr, l:skipWinNr)
	    return [a:tabNr, l:currentWinNr + l:offset]
	endif
	let l:offset += 1
    endwhile
    return [0, 0]
endfunction

function! ingo#window#locate#NearestByPredicate( isSearchOtherTabPages, winVarName, Predicate )
"******************************************************************************
"* PURPOSE:
"   Locate the window closest to the current one where the window variable a:winVarName makes
"   a:Predicate (passed in as argument or v:val) true.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:isSearchOtherTabPages Flag whether windows in other tab pages should also
"			    be considered.
"   a:winVarName            Name of the window-local variable, like in
"			    |gettabwinvar()|
"   a:Predicate             Either a Funcref or an expression to be eval()ed.
"			    Gets the value of a:winVarName passed, should return
"			    a boolean value.
"* RETURN VALUES:
"   [tabpagenr, winnr] if a:isSearchOtherTabPages and the found window is on a
"	different tab page
"   [0, winnr] if the window is on the current tab page
"   [0, 0] if a:Predicate did not yield true in any other window
"******************************************************************************
    let l:lastWinNr = winnr('#')
    if l:lastWinNr != 0 && s:Match(a:winVarName, a:Predicate, l:lastWinNr)
	return [tabpagenr(), l:lastWinNr]
    endif

    let l:result = s:CheckTabPageNearest(tabpagenr(), a:winVarName, a:Predicate, winnr())
    if l:result != [0, 0] || ! a:isSearchOtherTabPages
	return l:result
    endif


    let [l:currentTabPageNr, l:lastTabPageNr] = [tabpagenr(), tabpagenr('$')]
    let l:offset = 1
    while l:currentTabPageNr - l:offset > 0 || l:currentTabPageNr + l:offset <= l:lastTabPageNr
	let l:result = s:CheckTabPageNearest(l:currentTabPageNr - l:offset, a:winVarName, a:Predicate)
	if l:result != [0, 0] | return l:result | endif

	let l:result = s:CheckTabPageNearest(l:currentTabPageNr + l:offset, a:winVarName, a:Predicate)
	if l:result != [0, 0] | return l:result | endif

	let l:offset += 1
    endwhile

    return [0, 0]
endfunction

function! ingo#window#locate#FirstByPredicate( isSearchOtherTabPages, winVarName, Predicate )
"******************************************************************************
"* PURPOSE:
"   Locate the first window (in this tab page, or with a:isSearchOtherTabPages
"   in other tabs) where the window variable a:winVarName makes a:Predicate
"   (passed in as argument or v:val) true.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:isSearchOtherTabPages Flag whether windows in other tab pages should also
"			    be considered.
"   a:winVarName            Name of the window-local variable, like in
"			    |gettabwinvar()|
"   a:Predicate             Either a Funcref or an expression to be eval()ed.
"			    Gets the value of a:winVarName passed, should return
"			    a boolean value.
"* RETURN VALUES:
"   [tabpagenr, winnr] if a:isSearchOtherTabPages and the found window is on a
"	different tab page
"   [0, winnr] if the window is on the current tab page
"   [0, 0] if a:Predicate did not yield true in any other window
"******************************************************************************
    for l:winNr in range(1, winnr('$'))
	if s:Match(a:winVarName, a:Predicate, l:winNr)
	    return [0, l:winNr]
	endif
    endfor
    if ! a:isSearchOtherTabPages
	return [0, 0]
    endif

    for l:tabPageNr in filter(range(1, tabpagenr('$')), 'v:val != ' . tabpagenr())
	let l:lastWinNr = tabpagewinnr(l:tabPageNr, '$')
	for l:winNr in range(1, l:lastWinNr)
	    if s:Match(a:winVarName, a:Predicate, l:winNr, l:tabPageNr)
		return [l:tabPageNr, l:winNr]
	    endif
	endfor
    endfor

    return [0, 0]
endfunction

function! ingo#window#locate#ByPredicate( strategy, isSearchOtherTabPages, winVarName, Predicate )
"******************************************************************************
"* PURPOSE:
"   Locate a window (in this tab page, or with a:isSearchOtherTabPages in other
"   tabs), with a:strategy to determine precedences, where the window variable
"   a:winVarName makes a:Predicate (passed in as argument or v:val) true.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:strategy              One of "first" or "nearest".
"   a:isSearchOtherTabPages Flag whether windows in other tab pages should also
"			    be considered.
"   a:winVarName            Name of the window-local variable, like in
"			    |gettabwinvar()|
"   a:Predicate             Either a Funcref or an expression to be eval()ed.
"			    Gets the value of a:winVarName passed, should return
"			    a boolean value.
"* RETURN VALUES:
"   [tabpagenr, winnr] if a:isSearchOtherTabPages and the found window is on a
"	different tab page
"   [0, winnr] if the window is on the current tab page
"   [0, 0] if a:Predicate did not yield true in any other window
"******************************************************************************
    if a:strategy ==# 'first'
	return ingo#window#locate#FirstByPredicate(a:isSearchOtherTabPages, a:winVarName, a:Predicate)
    elseif a:strategy ==# 'nearest'
	return ingo#window#locate#NearestByPredicate(a:isSearchOtherTabPages, a:winVarName, a:Predicate)
    else
	throw 'ASSERT: Unknown strategy ' . string(a:strategy)
    endif
endfunction

" vism: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
autoload/ingo/window/preview.vim	[[[1
126
" ingo/window/preview.vim: Functions for the preview window.
"
" DEPENDENCIES:
"
" Copyright: (C) 2008-2016 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
"
" REVISION	DATE		REMARKS
"   1.029.005	13-Dec-2016	BUG: Optional a:position argument to
"				ingo#window#preview#SplitToPreview() is
"				mistakenly truncated to [1:2]. Inline the
"				l:cursor and l:bufnr variables; they are only
"				used in the function call, anyway.
"   1.021.004	06-Jul-2014	Support all imaginable argument variants of
"				ingo#window#preview#OpenFilespec(), so that it
"				can be used as a wrapper that encapsulates the
"				g:previewwindowsplitmode config and the
"				workaround for the absolute filespec due to the
"				CWD.
"   1.021.003	03-Jul-2014	Add ingo#window#preview#OpenFilespec(), a
"				wrapper around :pedit that performs the
"				fnameescape() and obeys the custom
"				g:previewwindowsplitmode.
"   1.020.002	02-Jun-2014	ENH: Allow passing optional a:tabnr to
"				ingo#window#preview#IsPreviewWindowVisible().
"				Factor out ingo#window#preview#OpenBuffer().
"				CHG: Change optional a:cursor argument of
"				ingo#window#preview#SplitToPreview() from
"				4-tuple getpos()-style to [lnum, col]-style.
"   1.004.001	08-Apr-2013	file creation from autoload/ingowindow.vim
let s:save_cpo = &cpo
set cpo&vim

function! ingo#window#preview#OpenPreview( ... )
    " Note: We do not use :pedit to open the current file in the preview window,
    " because that command reloads the current buffer, which would fail (nobang)
    " / forcibly write (bang) it, and reset the current folds.
    "execute 'pedit! +' . escape( 'call setpos(".", ' . string(getpos('.')) . ')', ' ') . ' %'
    try
	" If the preview window is open, just go there.
	wincmd P
    catch /^Vim\%((\a\+)\)\=:E441:/
	" Else, temporarily open a dummy file. (There's no :popen command.)
	execute 'silent' (exists('g:previewwindowsplitmode') ? g:previewwindowsplitmode : '') (a:0 ? a:1 : '') 'pedit! +setlocal\ buftype=nofile\ bufhidden=wipe\ nobuflisted\ noswapfile [No\ Name]'
	wincmd P
    endtry
endfunction
function! ingo#window#preview#OpenBuffer( bufnr, ... )
    if ! &l:previewwindow
	call ingo#window#preview#OpenPreview()
    endif

    " Load the passed buffer in the preview window, if it's not already there.
    if bufnr('') != a:bufnr
	silent execute a:bufnr . 'buffer'
    endif

    if a:0
	call cursor(a:1)
    endif
endfunction
function! ingo#window#preview#OpenFilespec( filespec, ... )
    " Load the passed filespec in the preview window.
    let l:options = (a:0 ? a:1 : {})
    let l:isSilent = get(l:options, 'isSilent', 1)
    let l:isBang = get(l:options, 'isBang', 1)
    let l:prefixCommand = get(l:options, 'prefixCommand', '')
    let l:exFileOptionsAndCommands = get(l:options, 'exFileOptionsAndCommands', '')
    let l:cursor = get(l:options, 'cursor', [])
    if ! empty(l:cursor)
	let l:exFileOptionsAndCommands = (empty(l:exFileOptionsAndCommands) ? '+' : l:exFileOptionsAndCommands . '|') .
	\   printf('call\ cursor(%d,%d)', l:cursor[0], l:cursor[1])
    endif

    execute (l:isSilent ? 'silent' : '')
    \   (exists('g:previewwindowsplitmode') ? g:previewwindowsplitmode : '')
    \   l:prefixCommand
    \   'pedit' . (l:isBang ? '!' : '')
    \   l:exFileOptionsAndCommands
    \   ingo#compat#fnameescape(a:filespec)

    " XXX: :pedit uses the CWD of the preview window. If that already contains a
    " file with another CWD, the shortened command is wrong. Always use the
    " absolute filespec instead of shortening it via
    " fnamemodify(a:filespec, " ':~:.')
endfunction
function! ingo#window#preview#SplitToPreview( ... )
    if &l:previewwindow
	wincmd p
	if &l:previewwindow | return 0 | endif
    endif

    " Clone current cursor position to preview window (which now shows the same
    " file) or passed position.
    call ingo#window#preview#OpenBuffer(bufnr(''), (a:0 ? a:1 : getpos('.')[1:2]))
    return 1
endfunction
function! ingo#window#preview#GotoPreview()
    if &l:previewwindow | return | endif
    try
	wincmd P
    catch /^Vim\%((\a\+)\)\=:E441:/
	call ingo#window#preview#SplitToPreview()
    endtry
endfunction


function! ingo#window#preview#IsPreviewWindowVisible( ... )
    for l:winnr in range(1, winnr('$'))
	if (a:0 ?
	\   gettabwinvar(a:1, l:winnr, '&previewwindow') :
	\   getwinvar(l:winnr, '&previewwindow')
	\)
	    " There's still a preview window.
	    return l:winnr
	endif
    endfor

    return 0
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo
" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
autoload/ingo/window/quickfix.vim	[[[1
140
" ingo/window/quickfix.vim: Functions for the quickfix window.
"
" DEPENDENCIES:
"
" Copyright: (C) 2010-2015 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
"
" REVISION	DATE		REMARKS
"   1.023.003	07-Feb-2015	Improve heuristics of
"				ingo#window#quickfix#IsQuickfixList() to also
"				handle empty location list (with non-empty
"				quickfix list).
"				Add
"				ingo#window#quickfix#TranslateVirtualColToByteCount()
"				from autoload/QuickFixCurrentNumber.vim.
"   1.016.002	10-Dec-2013	Add ingo#window#quickfix#GetList() and
"				ingo#window#quickfix#SetList().
"   1.004.001	08-Apr-2013	file creation from autoload/ingowindow.vim

function! ingo#window#quickfix#IsQuickfixList( ... )
"******************************************************************************
"* PURPOSE:
"   Check whether the current window is the quickfix window or a location list.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   determineType   Flag whether it should also be attempted to determine the
"		    type (global quickfix / local location list).
"* RETURN VALUES:
"   Boolean when no a:determineType is given. Else:
"   1 if the current window is the quickfix window.
"   2 if the current window is a location list window.
"   0 for any other window.
"******************************************************************************
    if &buftype !=# 'quickfix'
	return 0
    elseif a:0
	" Try to determine the type.
	" getloclist(0) inside a location list returns the displayed location
	" list. A quickfix window cannot have a location list, so we can use
	" that to determine that we're in a quickfix window.
	if empty(getloclist(0))
	    " Cornercase: We may be in an empty location list window; do not
	    " fall back to the quickfix list, then.
	    if line('$') == 1 && ! empty(getqflist())
		return 2
	    else
		return 1
	    endif
	else
	    return 2
	endif
    else
	return 1
    endif
endfunction
function! ingo#window#quickfix#ParseFileFromQuickfixList()
    return (ingo#window#quickfix#IsQuickfixList() ? matchstr(getline('.'), '^.\{-}\ze|') : '')
endfunction

function! ingo#window#quickfix#GetList()
"******************************************************************************
"* PURPOSE:
"   Return a list with all the quickfix / location list errors of the current
"   window.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   None.
"* RETURN VALUES:
"   List.
"   Throws exception if the current window is no quickfix / location list.
"******************************************************************************
    let l:quickfixType = ingo#window#quickfix#IsQuickfixList(1)
    if l:quickfixType == 0
	throw 'GetList: Not in quickfix window'
    elseif l:quickfixType == 1
	return getqflist()
    elseif l:quickfixType == 2
	return getloclist(0)
    else
	throw 'ASSERT: Invalid quickfix type: ' . l:quickfixType
    endif
endfunction
function! ingo#window#quickfix#SetList( ... )
"******************************************************************************
"* PURPOSE:
"   Change or replace the quickfix / location list errors of the current window.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:list      Error list, like |setqflist()|.
"   a:action    Optional action, like |setqflist()|.
"* RETURN VALUES:
"   Returns zero for success, -1 for failure.
"   Throws exception if the current window is no quickfix / location list.
"******************************************************************************
    let l:quickfixType = ingo#window#quickfix#IsQuickfixList(1)
    if l:quickfixType == 0
	throw 'SetList: Not in quickfix window'
    elseif l:quickfixType == 1
	return call('setqflist', a:000)
    elseif l:quickfixType == 2
	return call('setloclist', [0] + a:000)
    else
	throw 'ASSERT: Invalid quickfix type: ' . l:quickfixType
    endif
endfunction

function! ingo#window#quickfix#TranslateVirtualColToByteCount( qfEntry )
    let l:bufNr = a:qfEntry.bufnr
    if l:bufNr == 0 || ! a:qfEntry.vcol
	" As the buffer doesn't exist, we can't do any translation. Just return
	" the byte index (even if it may in fact be a virtual column).
	" If vcol isn't set, no need for translation.
	return a:qfEntry.col
    endif

    let l:neededTabstop = getbufvar(l:bufNr, '&tabstop')
    if l:neededTabstop != &tabstop
	let l:save_tabstop = &l:tabstop
	let &l:tabstop = l:neededTabstop
    endif
	let l:translatedCol = len(matchstr(getbufline(l:bufNr, a:qfEntry.lnum)[0], '^.*\%<'.(a:qfEntry.col + 1).'v'))
    if exists('l:save_tabstop')
	let &l:tabtop = l:save_tabstop
    endif

    return l:translatedCol
endfunction

" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
autoload/ingo/window/special.vim	[[[1
82
" ingo/window/special.vim: Functions for dealing with special windows.
"
" DEPENDENCIES:
"
" Copyright: (C) 2008-2016 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
"
" REVISION	DATE		REMARKS
"   1.025.003	28-Jan-2016	ENH: Make
"				ingo#window#special#SaveSpecialWindowSize()
"				return sum of special windows' widths and sum of
"				special windows' heights.
"   1.025.002	26-Jan-2016	ENH: Enable customization of
"				ingo#window#special#IsSpecialWindow() via
"				g:IngoLibrary_SpecialWindowPredicates.
"   1.004.001	08-Apr-2013	file creation from autoload/ingowindow.vim

function! ingo#window#special#IsSpecialWindow( ... )
"******************************************************************************
"* PURPOSE:
"   Check whether the current / passed window is special; special windows are
"   preview, quickfix (and location lists, which is also of type 'quickfix').
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:winnr Optional window number.
"   The check can be customized via g:IngoLibrary_SpecialWindowPredicates, which
"   takes a List of Expressions or Funcrefs that are passed the window number,
"   and which should return a boolean flag. If any predicate is true, the window
"   is deemed special.
"* RETURN VALUES:
"   1 if special; else 0.
"******************************************************************************
    let l:winnr = (a:0 > 0 ? a:1 : winnr())
    return getwinvar(l:winnr, '&previewwindow') || getwinvar(l:winnr, '&buftype') ==# 'quickfix' ||
    \   (exists('g:IngoLibrary_SpecialWindowPredicates') && ! empty(
    \       filter(
    \           map(copy(g:IngoLibrary_SpecialWindowPredicates), 'ingo#actions#EvaluateWithValOrFunc(v:val, l:winnr)'),
    \           '!! v:val'
    \       )
    \   ))
endfunction
function! ingo#window#special#SaveSpecialWindowSize()
"******************************************************************************
"* PURPOSE:
"   Calculate widths and heights of visible special windows, and store those for
"   later restoration.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   Stores window numbers of special windows, and their current widths and
"   heights.
"* INPUTS:
"   None.
"* RETURN VALUES:
"   [sum of special windows' widths, sum of special windows' heights]
"******************************************************************************
    let s:specialWindowSizes = {}
    let [l:specialWidths, l:specialHeights] = [0, 0]
    for l:w in range(1, winnr('$'))
	if ingo#window#special#IsSpecialWindow(l:w)
	    let [l:width, l:height] = [winwidth(l:w), winheight(l:w)]
	    let s:specialWindowSizes[l:w] = [l:width, l:height]

	    let l:specialWidths += l:width
	    let l:specialHeights += l:height
	endif
    endfor
    return [l:specialWidths, l:specialHeights]
endfunction
function! ingo#window#special#RestoreSpecialWindowSize()
    for l:w in keys(s:specialWindowSizes)
	execute 'vert' l:w . 'resize' s:specialWindowSizes[l:w][0]
	execute        l:w . 'resize' s:specialWindowSizes[l:w][1]
    endfor
endfunction

" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
autoload/ingo/window/switches.vim	[[[1
101
" ingo/window/switches.vim: Functions for switching between windows.
"
" DEPENDENCIES:
"   - ingo/msg.vim autoload script
"
" Copyright: (C) 2012-2013 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
"
" REVISION	DATE		REMARKS
"   1.006.002	03-May-2013	Add optional isReturnError flag on
"				ingo#window#switches#GotoPreviousWindow().
"   1.004.001	08-Apr-2013	file creation from autoload/ingowindow.vim

function! ingo#window#switches#GotoPreviousWindow( ... )
"*******************************************************************************
"* PURPOSE:
"   Goto the previous window (CTRL-W_p). If there is no previous window, but
"   only one other window, go there.
"
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   Changes the current window, or:
"   Prints warning message (unless a:isReturnError).
"* INPUTS:
"   a:isReturnError When flag is set, returns the warning message instead of
"		    printing it.
"* RETURN VALUES:
"   If ! a:isReturnError: 1 on success, 0 if there is no previous window.
"   If   a:isReturnError: '' on success, message if there is no previous window.
"*******************************************************************************
    let l:isReturnError = (a:0 && a:1)
    let l:problem = ''
    let l:window = 'p'

    if winnr('$') == 1
	let l:problem = 'Only one window'
    elseif winnr('#') == 0 || winnr('#') == winnr()
	if winnr('$') == 2
	    " There is only one more window, we take that one.
	    let l:window = 'w'
	else
	    let l:problem = 'No previous window'
	endif
    endif
    if ! empty(l:problem)
	if l:isReturnError
	    return l:problem
	else
	    call ingo#msg#WarningMsg(l:problem)
	    return 0
	endif
    endif

    execute 'noautocmd wincmd' l:window
    return (l:isReturnError ? '' : 1)
endfunction

" Record the current buffer's window and try to later return exactly to the same
" window, even if in the meantime, windows have been added or removed. This is
" an enhanced version of bufwinnr(), which will always yield the _first_ window
" containing a buffer.
function! ingo#window#switches#WinSaveCurrentBuffer()
    let l:buffersUpToCurrent = tabpagebuflist()[0 : winnr() - 1]
    let l:occurrenceCnt= len(filter(l:buffersUpToCurrent, 'v:val == bufnr("")'))
    return {'bufnr': bufnr(''), 'occurrenceCnt': l:occurrenceCnt}
endfunction
function! ingo#window#switches#WinRestoreCurrentBuffer( dict )
    let l:targetWinNr = -1

    if a:dict.occurrenceCnt == 1
	" We want the first occurrence of the buffer, bufwinnr() can do this for
	" us.
	let l:targetWinNr = bufwinnr(a:dict.bufnr)
    else
	" Go through all windows and find the N'th window containing our buffer.
	let l:winNrs = []
	for l:winNr in range(1, winnr('$'))
	    if winbufnr(l:winNr) == a:dict.bufnr
		call add(l:winNrs, l:winNr)
	    endif
	endfor

	if len(l:winNrs) < a:dict.occurrenceCnt
	    " There are less windows showing that buffer now; choose the last.
	    let l:targetWinNr = l:winNrs[-1]
	else
	    let l:targetWinNr = l:winNrs[a:dict.occurrenceCnt - 1]
	endif
    endif

    if l:targetWinNr == -1
	throw printf('WinRestoreCurrentBuffer: target buffer %d not found', a:dict.bufnr)
    endif

    execute l:targetWinNr . 'wincmd w'
endfunction

" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
autoload/ingo/workingdir.vim	[[[1
30
" ingo/workingdir.vim: Functions to deal with the current working directory.
"
" DEPENDENCIES:
"   - ingo/compat.vim autoload script
"
" Copyright: (C) 2018 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>

let s:compatFor = (exists('g:IngoLibrary_CompatFor') ? ingo#collections#ToDict(split(g:IngoLibrary_CompatFor, ',')) : {})

if exists('*haslocaldir') && ! has_key(s:compatFor, 'haslocaldir')
    function! ingo#workingdir#ChdirCommand()
	return (haslocaldir() ? 'lchdir!' : 'chdir!')
    endfunction
else
    function! ingo#workingdir#ChdirCommand()
	return 'chdir!'
    endfunction
endif

function! ingo#workingdir#Chdir( dirspec )
    execute ingo#workingdir#ChdirCommand() ingo#compat#fnameescape(a:dirspec)
endfunction
function! ingo#workingdir#ChdirToSpecial( cmdlineSpecial )
    execute ingo#workingdir#ChdirCommand() a:cmdlineSpecial
endfunction

" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
doc/ingo-library.txt	[[[1
1018
*ingo-library.txt*              Vimscript library of common functions.

			INGO-LIBRARY    by Ingo Karkat
							    *ingo-library.vim*
description			|ingo-library-description|
configuration			|ingo-library-configuration|
installation			|ingo-library-installation|
usage				|ingo-library-usage|
limitations			|ingo-library-limitations|
known problems			|ingo-library-known-problems|
todo				|ingo-library-todo|
history				|ingo-library-history|

==============================================================================
DESCRIPTION					    *ingo-library-description*

This library contains common autoload functions that are used by almost all of
my plugins (http://www.vim.org/account/profile.php?user_id=9713). Instead of
duplicating the functionality, or installing potentially conflicting versions
with each plugin, this one core dependency fosters a lean Vim runtime and
easier plugin updates.

Separating common functions is explicitly recommended by Vim; see
|write-library-script|. The |autoload| mechanism was created to make this
really easy and efficient. Only those scripts that contain functions that are
actually used are loaded, the rest is ignored; it just "wastes" the space on
disk. (Not using autoload functions, and duplicating utility functions in the
plugin script itself, now that would be truly bad.)

Still, if you only use one or few of my plugins, yes, this might look
wasteful. However, I have published an awful lot of plugins (most of which now
use ingo-library), and intend to continue to do so. Considering that, the
decision to extract the common functionality (which caused a lot of effort for
me) benefits both users (no duplication, no incompatibilities, faster updates)
and me (less overall effort in maintaining, more time for features). Please
keep that in mind before complaining about this dependency.

Furthermore, several other authors have been following the same approach:

RELATED WORKS								     *

Other authors have published separate support libraries, too:

- genutils (vimscript #197) by Hari Krishna Dara
- lh-vim-lib (vimscript #214) by Luc Hermitte
- cecutil (vimscript #1066) by DrChip
- tlib (vimscript #1863) by Thomas Link
- TOVL (vimscript #1963) by Marc Weber
- l9 (vimscript #3252) by Takeshi Nishida
- anwolib (vimscript #3800) by Andy Wokula
- vim-misc (vimscript #4597) by Peter Odding
- maktaba (https://github.com/google/maktaba) by Google
- vital (https://github.com/vim-jp/vital.vim) by the Japanese Vim user group
- underscore.vim (vimscript #5149) by haya14busa provides functional
  programming functions and depends on the (rather complex) vital library

There have been initiatives to gather and consolidate useful functions into a
"standard Vim library", but these efforts have mostly fizzled out.

==============================================================================
USAGE							  *ingo-library-usage*

This library is mainly intended to be used by my own plugins. However, I try
to maintain backwards compatibility as much as possible. Feel free to use the
library for your own plugins and customizations, too. I'd also like to hear
from you if you have additions or comments.

EXCEPTION HANDLING							     *

For exceptional conditions (e.g. cannot locate window that should be there)
and programming errors (e.g. passing a wrong variable type to a library
function), error strings are |:throw|n. These are prefixed with (something
resembling) the short function name, so that it's possible to |:catch| these
and e.g. convert them into a proper error (e.g. via
|ingo#err#SetCustomException()|).

==============================================================================
CONFIGURATION					  *ingo-library-configuration*
						   *g:IngoLibrary_DateCommand*
The filespec to the external "date" command can be set via: >
    let g:IngoLibrary_DateCommand = 'date'
<
					   *g:IngoLibrary_PreferredDateFormat*
The preferred date format used by ingo#date#format#Preferred() can be set to a
|strftime()| format via: >
    let g:IngoLibrary_PreferredDateFormat = '%x'
<
					      *g:IngoLibrary_FileCacheMaxSize*
The size of the file cache (in bytes) used by ingo#file#GetLines() can be set
via: >
    let g:IngoLibrary_FileCacheMaxSize = 1048576
<
					      *g:IngoLibrary_TruncateEllipsis*
The string used as a replacement for truncated text can be set via: >
    let g:IngoLibrary_TruncateEllipsis = "\u2026"
<
				       *g:IngoLibrary_SpecialWindowPredicates*
The check for special windows in ingo#window#special#IsSpecialWindow() can be
customized via a List of Expressions or Funcrefs that are passed the window
number, and which should return a boolean flag. If any predicate is true, the
window is deemed special. >
    let g:IngoLibrary_SpecialWindowPredicates =
    \	['bufname(winbufnr(v:val)) =~# "^\\[\\%(Scratch\\|clipboard\\)\\]$"']
<
==============================================================================
INSTALLATION					   *ingo-library-installation*

The code is hosted in a Git repo at
    https://github.com/inkarkat/vim-ingo-library
You can use your favorite plugin manager, or "git clone" into a directory used
for Vim |packages|. Releases are on the "stable" branch, the latest unstable
development snapshot on "master".

This script is also packaged as a |vimball|. If you have the "gunzip"
decompressor in your PATH, simply edit the *.vmb.gz package in Vim; otherwise,
decompress the archive first, e.g. using WinZip. Inside Vim, install by
sourcing the vimball or via the |:UseVimball| command. >
    vim ingo-library*.vmb.gz
    :so %
To uninstall, use the |:RmVimball| command.

DEPENDENCIES					   *ingo-library-dependencies*

- Requires Vim 7.0 or higher.

==============================================================================
LIMITATIONS					    *ingo-library-limitations*

KNOWN PROBLEMS					 *ingo-library-known-problems*

TODO							   *ingo-library-todo*

IDEAS							  *ingo-library-ideas*

CONTRIBUTING					     *ingo-library-contribute*

Report any bugs, send patches, or suggest features via the issue tracker at
https://github.com/inkarkat/vim-ingo-library/issues or email (address below).

==============================================================================
HISTORY							*ingo-library-history*

1.038	09-Jun-2019
- ingo#compat#maparg() escaping didn't consider <; in fact, it needs to escape
  stand-alone < and escaped \<, but not proper key notations like <C-CR>.
- FIX: Make ingo#cmdline#showmode#TemporaryNoShowMode() work again.
- Factor out ingo#msg#MsgFromCustomException().
- Add ingo#regexp#MakeWholeWordOrWORDSearch() variant.
- Add ingo#pos#Compare(), useful for sort().
- FIX: Handle corner cases in ingo#join#Lines().
  Return join success. Also do proper counting in ingo#join#Ranges().
- Add ingo#join#Range() variant of ingo#join#Ranges().
- FIX: ingo#comments#SplitAll(): isBlankRequired is missing from the returned
  List when there's no comment.
- Add ingo/comments/indent.vim module.

1.037	28-Mar-2019
- Add ingo#dict#Make() (analog to ingo#list#Make()).
- Add ingo#selection#Set() and ingo#selection#Make().
- Add ingo#pos#Make4() and ingo#pos#Make2().
- Add ingo#change#Set().
- Add ingo#ftplugin#converter#builder#DifferentFiletype().
- Add ingo#plugin#cmdcomplete#MakeTwoStageFixedListAndMapCompleteFunc(), a
  more complex variant of ingo#plugin#cmdcomplete#MakeFixedListCompleteFunc().
- Add ingo#ftplugin#converter#builder#Filter() variant of
  ingo#ftplugin#converter#builder#DifferentFiletype().
- Add ingo#str#Wrap().
- Add ingo#dict#FromValues().
- ENH: ingo#dict#FromKeys() can also take a ValueExtractor Funcref in addition
  to the static defaultValue.
- Add ingo#collections#FileModificationTimeSort().

1.036	17-Mar-2019
- FIX: ingo#strdisplaywidth#strleft includes multi-width character that
  straddles the specified width. Need to exclude this one.
- Add ingo#strdisplaywidth#pad#Repeat[Exact]().
- Make Unix date command used in ingo#date#epoch#ConvertTo() configurable via
  g:IngoLibrary_DateCommand.
- ENH: Allow passing of a:truncationIndicator to
  ingo#avoidprompt#Truncate[To]().
- Add ingo#fs#path#split#TruncateTo().
- Add ingo#str#TrimPattern() variant of ingo#str#Trim().
- Add ingo#date#epoch#Now().
- Add ingo#date#strftime().
- Add ingo#compat#trim().
- Add ingo#buffer#locate#OtherWindowWithSameBuffer().
- Add ingo#search#timelimited#FirstPatternThatMatchesInBuffer().
- Add optional a:isPreferText flag to
  ingo#cmdargs#register#Parse{Prepended,Appended}WritableRegister().
- Add ingo#comments#GetSplitIndentPattern() variant of
  ingo#comments#SplitIndentAndText() that just returns the pattern.
- Extract ingo#cmdrange#FromCount() from
  ingo#cmdrangeconverter#LineToBufferRange().
- Add ingo/plugin/cmd/withpattern.vim module.
- Add ingo/view.vim module.
- Add ingo#compat#commands#ForceSynchronousFeedkeys().
- Add ingo/plugin/persistence.vim module; implementation based on my mark.vim
  plugin.
- Add ingo#collections#SortOnOneAttribute(), ingo#collections#PrioritySort(),
  and ingo#collections#SortOnTwoAttributes().
- Add ingo/collections/recursive.vim module.
- ENH: ingo#cmdargs#range#Parse(): Add a:options.isOnlySingleAddress flag.
- ENH: Add ingo#cmdargs#range#ParsePrependedRange().
- Minor fixes to ingo#query#confirm#AutoAccelerators().
- Expose ingo#collections#fromsplit#MapOne().
- Add function/uniquify.vim module.
- Add ingo#compat#FromKey() for the reversing of ingo#compat#DictKey().
- Add ingo#collections#SortOnOneListElement(), a variant of
  ingo#collections#SortOnOneAttribute().
- Add ingo#regexp#MakeWholeWORDSearch() variant of
  ingo#regexp#MakeWholeWordSearch().
- Add ingo/file.vim module.
- Add ingo#cmdargs#pattern#PatternExpr().
- BUG: ingo#text#replace#Between() and ingo#text#replace#Area() mistakenly
  update current line instead of passed position.
- BUG: ingo#text#replace#Between() and ingo#text#replace#Area() cause "E684:
  list index out of range: 0" when the replacement text is empty.
- FIX: Off-by-one in ingo#area#IsEmpty(). Also check for invalid area.
- Add ingo#area#EmptyArea().
- FIX: Make ingo#pos#Before() return column 0 if passed a position with column
  1; this matches the behavior of ingo#pos#After(), which also returns a
  non-existent position directly after the last character, and this fits in
  well with the area functions.
- Add ingo#regexp#deconstruct#{Translate,Remove}CharacterClasses(),
  ingo#regexp#deconstruct#TranslateNumberEscapes(),
  ingo#regexp#deconstruct#TranslateBranches()  and include all translations in
  ingo#regexp#deconstruct#ToQuasiLiteral().
- FIX: Don't match optionally matched atoms \%[] in
  ingo#regexp#collection#Expr().
- ENH: Add a:option.isCapture to ingo#regexp#collection#Expr().

1.035	29-Sep-2018
- Add ingo#compat#commands#NormalWithCount().
- Add ingo#compat#haslocaldir().
- Add ingo/workingdir.vim module.
- Add ingo/selection/virtcols.vim module.
- Add ingo/str/list.vim module.
- Add ingo#funcref#AsString().
- Add ingo#compat#execute().
- Add ingo#option#GetBinaryOptionValue().
- Add ingo/buffer/ephemeral.vim module.
- Add ingo/lists/find.vim module.
- Add ingo/folds/containment.vim module.
- Add ingo/ftplugin/setting.vim module.
- Extract generic ingo#plugin#cmdcomplete#MakeCompleteFunc().
- Add ingo#fs#path#split#StartsWith() (we already had
  ingo#fs#path#split#EndsWith()).
- Add ingo#fs#path#Canonicalize().
- Add ingo#avoidprompt#EchoMsg() and ingo#avoidprompt#EchoMsgAsSingleLine().
- Tweak ingo#avoidprompt#MaxLength() algorithm; empirical testing showed that
  1 more needs to be subtracted if :set noshowcmd ruler. Thanks to an9wer for
  making me aware of this.
- CHG: Move ingo#list#Matches() to ingo#list#pattern#AllItemsMatch(). The
  previous name wasn't very clear.
- Add ingo#list#pattern#{First,All}Match[Index]() functions.
- ingo#query#{get#Number,fromlist#Query}(): ENH: Also support number entry with leading zeros
- ingo#query#fromlist#Query(): BUG: Cannot conclude multi-digit entry with <Enter>
- ingo#query#fromlist#Query(): BUG: Typing non-accellerator non-number characters are treated as literal "0"
- Add ingo/lists.vim module.
- Add ingo/regexp/capture.vim module.
- Add ingo#cmdargs#substitute#GetFlags().
- Add ingo#subst#Indexed().
- Add ingo#regexp#split#PrefixGroupsSuffix().
- Add ingo#collections#SplitIntoMatches().
- Add ingo#regexp#collection#ToBranches().
- Add ingo/regexp/{deconstruct,length,multi} modules.
- Add ingo#range#Is{In,Out}side().
- Add ingo/cursor/keep.vim module.
- Add ingo#folds#GetOpenFoldRange().
- ingo#compat#commands#keeppatterns(): Don't remove the last search pattern
  when the search history wasn't modified. Allow to force compatibility
  function via g:IngoLibrary_CompatFor here, too.
- Add ingo#regexp#split#GlobalFlags().
- Add ingo#regexp#IsValid() (from mark.vim plugin).
- Add ingo#matches#Any() and ingo#matches#All().
- Add ingo#list#split#RemoveFromStartWhilePredicate().
- Add ingo#cmdargs#file#FilterFileOptions() variant of
  ingo#cmdargs#file#FilterFileOptionsAndCommands()
- Add ingo#cmdargs#file#FileOptionsAndCommandsToEscapedExCommandLine() and
  combining ingo#cmdargs#file#FilterFileOptionsToEscaped() and
  ingo#cmdargs#file#FilterFileOptionsAndCommandsToEscaped().
- Add ingo#list#AddNonEmpty().

1.034	13-Feb-2018
- Add ingo/regexp/split.vim module.
- Add ingo#folds#LastVisibleLine(), ingo#folds#NextClosedLine(),
  ingo#folds#LastClosedLine() variants of existing
  ingo#folds#NextVisibleLine().
- Add ingo/plugin/rendered.vim module.
- Add ingo/change.vim module.
- Add ingo#undo#IsEnabled().
- Add ingo#str#split#AtPrefix() and ingo#str#split#AtSuffix().
- Add ingo/lnum.vim module.
- Add ingo#text#GetCharVirtCol().
- Add ingo#compat#matchstrpos().

1.033	14-Dec-2017
- Add ingo/subs/BraceCreation.vim and ingo/subs/BraceExpansion.vim modules.
- Add ingo#query#get#WritableRegister() variant of ingo#query#get#Register().
- Add ingo#str#find#StartIndex().
- Fix recursive invocations of ingo#buffer#generate#Create().
- Add ingo#mbyte#virtcol#GetColOfVirtCol().
- Expose ingo#plugin#marks#FindUnused(), and have it optionally take the
  considered marks.
- Add ingo#plugin#marks#Reuse().
- BUG: ingo#syntaxitem#IsOnSyntax() considers empty a:stopItemPattern as
  unconditional stop.
- Add ingo#regexp#build#UnderCursor().
- Add ingo#escape#command#mapeval().
- Add ingo#range#IsEntireBuffer().
- Add ingo/compat/commands.vim module.
- Add ingo#register#All() and ingo#register#Writable() (so that this
  information doesn't have to be duplicated any longer).
- FIX: ingo#query#get#WritableRegister() doesn't consider all writable
  registers (-_* are writable, too).
- Add ingo/register/accumulate.vim module.
- Add ingo/tabpage.vim module.
- Add ingo#list#NonEmpty() and ingo#list#JoinNonEmpty().
- Factor out ingo#filetype#GetPrimary() from ingo#filetype#IsPrimary().
- Add ingo#fs#path#split#ChangeBasePath().
- ENH: ingo#funcref#ToString() returns non-Funcref argument as is (instead of
  empty String). This allows to transparently handle function names (as
  String), too.
- ingo#event#Trigger(): Temporarily disable modeline processing in
  compatibility implementation.
- Add ingo#event#TriggerEverywhere() and ingo#event#TriggerEverywhereCustom()
  compatibility wrappers for :doautoall <nomodeline>.

1.032	20-Sep-2017
- ingo#query#get#{Register,Mark}(): Avoid throwing E523 on invalid user input
  when executed e.g. from within a |:map-expr|.
- Add ingo/subst/replacement.vim module with functions originally in
  PatternsOnText.vim (vimscript #4602).
- Add ingo/lines/empty.vim module.
- CHG: Rename ingo#str#split#First() to ingo#str#split#MatchFirst() and add
  ingo#str#split#StrFirst() variant that uses a fixed string, not a pattern.
- Add ingo/list/lcs.vim module.
- Add ingo#list#IsEmpty().
- Add ingo/collection/find.vim module.
- Add ingo/window.vim and ingo/window/adjacent modules.
- Add ingo#list#Matches().
- Add ingo/list/sequence.vim module.
- Add ingo#fs#path#IsAbsolute() and ingo#fs#path#IsUpwards().
- Add ingo/area/frompattern.vim module.
- CHG: Rename ingo#selection#position#Get() to ingo#selection#area#Get().
  Extend the function's API with options.
- Add ingo#text#GetFromArea().
- CHG: Rename ingo#text#replace#Area() to ingo#text#replace#Between() and add
  ingo#text#replace#Area() that actually takes a (single) a:area argument.
- Add ingo/area.vim module.
- Add ingo#query#fromlist#QueryAsText() variant of
  ingo#query#fromlist#Query().
- ENH: ingo#buffer#scratch#Create(): Allow to set the scratch buffer contents
  directly by passing a List as a:scratchCommand.
- Extract generic ingo#buffer#generate#Create() from ingo/buffer/scratch.vim.
- Add ingo#plugin#cmdcomplete#MakeListExprCompleteFunc() variant of
  ingo#plugin#cmdcomplete#MakeFixedListCompleteFunc().
- Add ingo/ftplugin/converter/external.vim module.

1.031	27-Jun-2017
- FIX: Potentially invalid indexing of l:otherResult[l:i] in
  s:GetUnjoinedResult(). Use get() for inner List access, too.
- Add special ingo#compat#synstack to work around missing patch 7.2.014:
  synstack() doesn't work in an empty line.
- BUG: ingo#comments#SplitIndentAndText() and
  ingo#comments#RemoveCommentPrefix() fail with nestable comment prefixes with
  "E688: More targets than List items".

1.030	26-May-2017
- Add escaping of additional values to ingo#option#Join() and split into
  ingo#option#Append() and ingo#option#Prepend().
- Offer simpler ingo#option#JoinEscaped() and ingo#option#JoinUnescaped() for
  actual joining of values split via ingo#option#Split() /
  ingo#option#SplitAndUnescape().
- Add ingo#str#EndsWith() variant of ingo#fs#path#split#Contains().
- Add ingo#regexp#comments#GetFlexibleWhitespaceAndCommentPrefixPattern().
- Add ingo/hlgroup.vim module.
- Add ingo#cursor#StartInsert() and ingo#cursor#StartAppend().
- Add ingo/compat/command.vim module.
- Add ingo#plugin#setting#Default().
- BUG: ingo#mbyte#virtcol#GetVirtColOfCurrentCharacter() yields wrong values
  with single-width multibyte characters, and at the beginning of the line
  (column 1). Need to start with offset 1 (not 0), and account for that
  (subtract 1) in the final return. Need to check that the virtcol argument
  will be larger than 0.
- Add ingo#format#Dict() variant of ingo#format#Format() that only handles
  identifier placeholders and a Dict containing them.
- ENH: ingo#format#Format(): Also handle a:fmt without any "%" items without
  error.
- Add ingo#compat#DictKey(), as Vim 7.4.1707 now allows using an empty
  dictionary key.
- Add ingo#os#IsWindowsShell().
- Generalize functions into ingo/nary.vim and delegate ingo#binary#...()
  functions to those. Add ingo/nary.vim module.
- ENH: ingo#regexp#collection#LiteralToRegexp(): Support inverted collection
  via optional a:isInvert flag.
- Add ingo#strdisplaywidth#CutLeft() variant of ingo#strdisplaywidth#strleft()
  that returns both parts. Same for ingo#strdisplaywidth#strright().
- CHG: Rename ill-named ingo#strdisplaywidth#pad#Middle() to
  ingo#strdisplaywidth#pad#Center().
- Add "real" ingo#strdisplaywidth#pad#Middle() that inserts the padding in the
  middle of the string / between the two passed string parts.
- Add ingo#fs#path#split#PathAndName().
- Add ingo#text#ReplaceChar(), a combination of ingo#text#GetChar(),
  ingo#text#Remove(), and ingo#text#Insert().
- Add ingo#err#Command() for an alternative way of passing back [error]
  commands to be executed.
- ingo#syntaxitem#IsOnSyntax(): Factor out synstack() emulation into
  ingo#compat#synstack() and unify similar function variants.
- ENH: ingo#syntaxitem#IsOnSyntax(): Allow optional a:stopItemPattern to avoid
  considering syntax items at the bottom of the stack.
- Add ingo#compat#synstack().
- Add ingo/dict/count.vim module.
- Add ingo/digest.vim module.
- Add ingo#buffer#VisibleList().

1.029	24-Jan-2017
- CHG: ingo#comments#RemoveCommentPrefix() isn't useful as it omits any indent
  before the comment prefix. Change its implementation to just erase the
  prefix itself.
- Add ingo#comments#SplitIndentAndText() to provide what
  ingo#comments#RemoveCommentPrefix() was previously used to: The line broken
  into indent (before, after, and with the comment prefix), and the remaining
  text.
- Add ingo#indent#Split(), a simpler version of
  ingo#comments#SplitIndentAndText().
- Add ingo#fs#traversal#FindFirstContainedInUpDir().
- ingo#range#lines#Get(): A single (a:isGetAllRanges = 0) /.../ range already
  clobbers the last search pattern. Save and restore if necessary, and base
  didClobberSearchHistory on that check.
- ingo#range#lines#Get(): Drop the ^ anchor for the range check to also detect
  /.../ as the end of the range.
- Add ingo#cmdargs#register#ParsePrependedWritableRegister() alternative to
  ingo#cmdargs#register#ParseAppendedWritableRegister().
- BUG: Optional a:position argument to ingo#window#preview#SplitToPreview() is
  mistakenly truncated to [1:2]. Inline the l:cursor and l:bufnr variables;
  they are only used in the function call, anyway.
- Add ingo/str/find.vim module.
- Add ingo/str/fromrange.vim module.
- Add ingo#pos#SameLineIs[OnOr]After/Before() variants.
- Add ingo/regexp/build.vim module.
- Add ingo#err#SetAndBeep().
- FIX: ingo#query#get#Char() does not beep when validExpr is given and invalid
  character pressed.
- Add ingo#query#get#ValidChar() variant that loops until a valid character
  has been pressed.
- Add ingo/range/invert.vim module.
- Add ingo/line/replace.vim and ingo/lines/replace.vim modules.
- Extract ingo#range#merge#FromLnums() from ingo#range#merge#Merge().
- ingo#range#lines#Get(): If the range is a backwards-looking ?{pattern}?, we
  need to attempt the match on any line with :global/^/... Else, the border
  behavior is inconsistent: ranges that extend the passed range at the bottom
  are (partially) included, but ranges that extend at the front would not be.
- Add ingo/math.vim, ingo/binary.vim and ingo/list/split.vim modules.
- Add ingo#comments#SplitAll(), a more powerful variant of
  ingo#comments#SplitIndentAndText().
- Add ingo#compat#systemlist().
- Add ingo#escape#OnlyUnescaped().
- Add ingo#msg#ColoredMsg() and ingo#msg#ColoredStatusMsg().
- Add ingo/query/recall.vim module.
- Add ingo#register#GetAsList().
- FIX: ingo#format#Format(): An invalid %0$ references the last passed
  argument instead of yielding the empty string (as [argument-index$] is
  1-based). Add bounds check to avoid that
- FIX: ingo#format#Format(): Also support escaping via "%%", as in printf().
- Add ingo#subst#FirstSubstitution(), ingo#subst#FirstPattern(),
  ingo#subst#FirstParameter().
- Add ingo#regexp#collection#Expr().
- BUG: ingo#regexp#magic#Normalize() also processes the contents of
  collections [...]; especially the escaping of "]" wreaks havoc on the
  pattern. Rename s:ConvertMagicness() into
  ingo#regexp#magic#ConvertMagicnessOfElement() and introduce intermediate
  s:ConvertMagicnessOfFragment() that first separates collections from other
  elements and only invokes the former on those other elements.
- Add ingo#collections#fromsplit#MapItemsAndSeparators().

1.028	30-Nov-2016
- ENH: Also support optional a:flagsMatchCount in
  ingo#cmdargs#pattern#ParseUnescaped() and
  ingo#cmdargs#pattern#ParseUnescapedWithLiteralWholeWord().
- Add missing ingo#cmdargs#pattern#ParseWithLiteralWholeWord() variant.
- ingo#codec#URL#Decode(): Also convert the character set to UTF-8 to properly
  handle non-ASCII characters. For example, %C3%9C should decode to "Ü", not
  to "É".
- Add ingo#collections#SeparateItemsAndSeparators(), a variant of
  ingo#collections#SplitKeepSeparators().
- Add ingo/collections/fromsplit.vim module.
- Add ingo#list#Join().
- Add ingo/compat/window.vim module.
- Add ingo/fs/path/asfilename.vim module.
- Add ingo/list/find.vim module.
- Add ingo#option#Join().
- FIX: Correct delegation in ingo#buffer#temp#Execute(); wrong recursive call
  was used (after 1.027).
- ENH: Add optional a:isSilent argument to ingo#buffer#temp#Execute().
- ENH: Add optional a:reservedColumns also to ingo#avoidprompt#TruncateTo(),
  and pass this from ingo#avoidprompt#Truncate().
- ingo#avoidprompt#TruncateTo(): The strright() cannot precisely account for
  the rendering of tab widths. Check the result, and if necessary, remove
  further characters until we go below the limit.
- ENH: Add optional {context} to all ingo#err#... functions, in case other
  custom commands can be called between error setting and checking, to avoid
  clobbering of your error message.
- Add ingo/buffer/locate.vim module.
- Add ingo/window/locate.vim module.
- Add ingo/indent.vim module.
- Add ingo#compat#getcurpos().

1.027	30-Sep-2016
- Add ingo#buffer#temp#ExecuteWithText() and ingo#buffer#temp#CallWithText()
  variants that pre-initialize the buffer (a common use case).
- Add ingo#msg#MsgFromShellError().
- ENH: ingo#query#fromlist#Query(): Support headless (testing) mode via
  g:IngoLibrary_QueryChoices, like ingo#query#Confirm() already does.
- Expose ingo#query#fromlist#RenderList(). Expose
  ingo#query#StripAccellerator().
- ENH: ingo#cmdargs#pattern#Parse(): Add second optional a:flagsMatchCount
  argument, similar to what ingo#cmdargs#substitute#Parse() has in a:options.
- Add ingo#cmdargs#pattern#RawParse().
- Add ingo/regexp/collection.vim module.
- Add ingo#str#trd().

1.026	11-Aug-2016
- Add ingo#strdisplaywidth#pad#Middle().
- Add ingo/format/columns.vim module.
- ENH: ingo#avoidprompt#TruncateTo() and ingo#strdisplaywidth#TruncateTo()
  have a configurable ellipsis string g:IngoLibrary_TruncateEllipsis, now
  defaulting to a single-char UTF-8 variant if we're in such encoding. Thanks
  to Daniel Hahler for sending a patch! It also handles pathologically small
  lengths that only show / cut into the ellipsis.
- Add ingo#compat#strgetchar() and ingo#compat#strcharpart(), introduced in
  Vim 7.4.1730.
- Support ingo#compat#strchars() optional {skipcc} argument, introduced in Vim
  7.4.755.

1.025	09-Aug-2016
- Add ingo#str#Contains().
- Add ingo#fs#path#split#Contains().
- ingo#subst#pairs#Substitute(): Canonicalize path separators in
  {replacement}, too. This is important to match further pairs, too, as the
  pattern is always in canonical form, so the replacement has to be, too.
- ingo#subst#pairs#Substitute() and ingo#subst#pairs#Split(): Only
  canonicalize path separators in {replacement} on demand, via additional
  a:isCanonicalizeReplacement argument. Some clients may not need iterative
  replacement, and treat the wildcard as a convenient regexp-shorthand, not
  overly filesystem-related.
- ENH: Allow passing to ingo#subst#pairs#Substitute() [wildcard, replacement]
  Lists instead of {wildcard}={replacement} Strings, too.
- Add ingo#collections#Partition().
- Add ingo#text#frompattern#GetAroundHere().
- Add ingo#cmdline#showmode#TemporaryNoShowMode() variant of
  ingo#cmdline#showmode#OneLineTemporaryNoShowMode().
- ENH: Enable customization of ingo#window#special#IsSpecialWindow() via
  g:IngoLibrary_SpecialWindowPredicates.
- Add ingo#query#Question().
- ENH: Make ingo#window#special#SaveSpecialWindowSize() return sum of special
  windows' widths and sum of special windows' heights.
- Add ingo/swap.vim module.
- Add ingo#collections#unique#Insert() and ingo#collections#unique#Add().
- BUG: Unescaped backslash resulted in unclosed [...] regexp collection
  causing ingo#escape#file#fnameunescape() to fail to escape on Unix.
- Add ingo#text#GetCharBefore() variant of ingo#text#GetChar().
- Add optional a:characterOffset to ingo#record#PositionAndLocation().
- Add ingo#regexp#MakeStartWordSearch() ingo#regexp#MakeEndWordSearch()
  variants of ingo#regexp#MakeWholeWordSearch().
- Add ingo#pos#IsInsideVisualSelection().
- Add ingo#escape#command#mapunescape().
- ENH: Add second optional flag a:isKeepDirectories to
  ingo#cmdargs#glob#Expand() / ingo#cmdargs#glob#ExpandSingle().
- Add ingo#range#borders#StartAndEndRange().
- Add ingo#msg#VerboseMsg().
- Add ingo#compat#sha256(), with a fallback to an external sha256sum command.
- Add ingo#collections#Reduce().
- Add ingo/actions/iterations.vim module.
- Add ingo/actions/special.vim module.
- Add ingo#collections#differences#ContainsLoosely() and
  ingo#collections#differences#ContainsStrictly().
- Add ingo#buffer#ExistOtherLoadedBuffers().
- FIX: Temporarily reset 'switchbuf' in ingo#buffer#visible#Execute() and
  ingo#buffer#temp#Execute(), to avoid that "usetab" switched to another tab
  page.
- ingo#msg#HighlightMsg(): Make a:hlgroup optional, default to 'None' (so the
  function is useful to return to normal highlighting).
- Add ingo#msg#HighlightN(), an :echon variant.

1.024	23-Apr-2015
- FIX: Also correctly set change marks when replacing entire buffer with
  ingo#lines#Replace().
- Add ingo/collections/differences.vim module.
- Add ingo/compat/regexp.vim module.
- Add ingo/encoding.vim module.
- Add ingo/str/join.vim module.
- Add ingo#option#SplitAndUnescape().
- Add ingo#list#Zip() and ingo#list#ZipLongest().
- ingo#buffer#visible#Execute(): Restore the window layout when the buffer is
  visible but in a window with 0 height / width. And restore the previous
  window when the buffer isn't visible yet. Add a check that the command
  hasn't switched to another window (and go back if true) before closing the
  split window.
- Add ingo/regexp/virtcols.vim module.
- Add ingo#str#GetVirtCols() and ingo#text#RemoveVirtCol().
- FIX: Off-by-one: Allow column 1 in ingo#text#Remove().
- BUG: ingo#buffer#scratch#Create() with existing scratch buffer yields "E95:
  Buffer with this name already exists" instead of reusing the buffer.
- Keep current cursor position when ingo#buffer#scratch#Create() removes the
  first empty line in the scratch buffer.
- ingo#text#frompattern#GetHere(): Do not move the cursor (to the end of the
  matched pattern); this is unexpected and can be easily avoided.
- FIX: ingo#cmdargs#GetStringExpr(): Escape (unescaped) double quotes when the
  argument contains backslashes; else, the expansion of \x will silently fail.
- Add ingo#cmdargs#GetUnescapedExpr(); when there's no need for empty
  expressions, the removal of the (single / double) quotes may be unexpected.
- ingo#text#Insert(): Also allow insertion one beyond the last line (in column
  1), just like setline() allows.
- Rename ingo#date#format#Human() to ingo#date#format#Preferred(), default to
  %x value for strftime(), and allow to customize that (even dynamically,
  maybe based on 'spelllang').
- Add optional a:templateForNewBuffer argument to ingo#fs#tempfile#Make() and
  ensure (by default) that the temp file isn't yet loaded in a Vim buffer
  (which would generate "E139: file is loaded in another buffer" on the usual
  :write, :saveas commands).
- Add ingo#compat#shiftwidth(), taken from :h shiftwidth().

1.023	09-Feb-2015
- ENH: Make ingo#selection#frompattern#GetPositions() automatically convert
  \%# in the passed a:pattern to the hard-coded cursor column.
- Add ingo#collections#mapsort().
- Add ingo/collections/memoized.vim module.
- ENH: Add optional a:isReturnAsList flag to ingo#buffer#temp#Execute() and
  ingo#buffer#temp#Call().
- ENH: Also allow passing an items List to ingo#dict#Mirror() and
  ingo#dict#AddMirrored() (useful to influence which key from equal values is
  used).
- ENH: Also support optional a:isEnsureUniqueness flag for
  ingo#dict#FromItems().
- Expose ingo#regexp#MakeWholeWordSearch().
- Add ingo#plugin#setting#GetTabLocal().
- ENH: Add a:isFile flag to ingo#escape#file#bufnameescape() in order to do
  full matching on scratch buffer names. There, the expansion to a full
  absolute path must be skipped in order to match.
- ENH: Add a:isGetAllRanges optional argument to ingo#range#lines#Get().
- Add ingo#strdisplaywidth#TruncateTo().
- Add ingo/str/frompattern.vim module.
- Add ingo/folds/persistence.vim module.
- Add ingo#cmdargs#pattern#IsDelimited().
- Support ingo#query#fromlist#Query() querying of more than 10 elements by
  number. Break listing of query choices into multiple lines when the overall
  question doesn't fit in a single line.
- Add ingo/event.vim module.
- Add ingo/range/merge.vim module.
- Add ingo#filetype#IsPrimary().
- Add ingo#plugin#setting#GetScope().
- Add ingo#regexp#fromwildcard#AnchoredToPathBoundaries().
- Use :close! in ingo#buffer#visible#Execute() to handle modified buffers when
  :set nohidden, too.
- Improve heuristics of ingo#window#quickfix#IsQuickfixList() to also handle
  empty location list (with non-empty quickfix list).
- Minor: ingo#text#Remove(): Correct exception prefix.
- Add ingo#window#quickfix#TranslateVirtualColToByteCount() from
  autoload/QuickFixCurrentNumber.vim.

1.022	26-Sep-2014
- Add ingo#pos#Before() and ingo#pos#After().
- Move LineJuggler#FoldClosed() and LineJuggler#FoldClosedEnd() into
  ingo-library as ingo#range#NetStart() and ingo#range#NetEnd().
- Add ingo/regexp/pairs.vim module.
- Add ingo#compat#glob() and ingo#compat#globpath().
- ingo#range#lines#Get() needs to consider and temporarily disable closed
  folds when resolving /{pattern}/ ranges.

1.021	10-Jul-2014
- Add ingo#compat#uniq().
- Add ingo#option#Contains() and ingo#option#ContainsOneOf().
- BUG: Wrong position type causes ingo#selection#position#get() to be one-off
  with :set selection=exclusive and when the cursor is after the selection.
- Use built-in changenr() in ingo#undo#GetChangeNumber(); actually, the entire
  function could be replaced by the built-in, if it would not just return one
  less than the number of the undone change after undo. We want the result to
  represent the current change, regardless of what undo / redo was done
  earlier. Change the implementation to test for whether the current change is
  the last in the buffer, and if not, make a no-op change to get to an
  explicit change state.
- Simplify ingo#buffer#temprange#Execute() by using changenr(). Keep using
  ingo#undo#GetChangeNumber() because we need to create a new no-op change
  when there was a previous :undo.
- Add ingo/smartcase.vim module.
- FIX: ingo#cmdargs#substitute#Parse() branch for special case of {flags}
  without /pat/string/ must only be entered when a:arguments is not empty.
- ENH: Allow to pass path separator to ingo#regexp#fromwildcard#Convert() and
  ingo#regexp#fromwildcard#IsWildcardPathPattern().
- Add ingo/collections/permute.vim module.
- Add ingo#window#preview#OpenFilespec(), a wrapper around :pedit that
  performs the fnameescape() and obeys the custom g:previewwindowsplitmode.

1.020	11-Jun-2014
- Add ingo/dict/find.vim module.
- Use ingo#escape#Unescape() in ingo#cmdargs#pattern#Unescape(). Add
  ingo#cmdargs#pattern#ParseUnescaped() to avoid the double and inefficient
  ingo#cmdargs#pattern#Unescape(ingo#cmdargs#pattern#Parse()) so far used by
  many clients.
- Add ingo#cmdargs#pattern#ParseUnescapedWithLiteralWholeWord() for the common
  [/]{pattern}[/ behavior as built-in commands like |:djump|]. When the
  pattern isn't delimited by /.../, the returned pattern is modified so that
  only literal whole words are matched. so far used by many clients.
- CHG: At ingo#regexp#FromLiteralText(), add the a:isWholeWordSearch also on
  either side, or when there are non-keyword characters in the middle of the
  text. The * command behavior where this is modeled after only handles a
  smaller subset, and this extension looks sensible and DWIM.
- Add ingo#compat#abs().
- Factor out and expose ingo#text#Replace#Area().
- CHG: When replacing at the cursor position, also jump to the beginning of
  the replacement. This is more consistent with Vim's default behavior.
- Add ingo/record.vim module.
- ENH: Allow passing optional a:tabnr to
  ingo#window#preview#IsPreviewWindowVisible().
- Factor out ingo#window#preview#OpenBuffer().
- CHG: Change optional a:cursor argument of
  ingo#window#preview#SplitToPreview() from 4-tuple getpos()-style to [lnum,
  col]-style.
- Add ingo/query/fromlist.vim module.
- Add ingo/option.vim module.
- Add ingo/join.vim module.
- Expose ingo#actions#GetValExpr().
- Add ingo/range/lines.vim module.
- ENH: Add a:options.commandExpr to ingo#cmdargs#range#Parse().

1.019	24-May-2014
- Add ingo#plugin#setting#BooleanToStringValue().
- Add ingo#strdisplaywidth#GetMinMax().
- Add ingo/undo.vim module.
- Add ingo/query.vim module.
- Add ingo/pos.vim module.
- Add optional a:isBeep argument to ingo#msg#ErrorMsg().
- ingo#fs#path#Normalize(): Don't normalize to Cygwin /cygdrive/x/... when the
  chosen path separator is "\". This would result in a mixed separator style
  that is not actually handled.
- ingo#fs#path#Normalize(): Add special normalization to "C:/" on Cygwin via
  ":/" path separator argument.
- In ingo#actions#EvaluateWithValOrFunc(), remove any occurrence of "v:val"
  instead of passing an empty list or empty string. This is useful for
  invoking functions (an expression, not Funcref) with optional arguments.
- ENH: Make ingo#lines#Replace() handle replacement with nothing (empty List)
  and replacing the entire buffer (without leaving an additional empty line).
- Correct ingo#query#confirm#AutoAccelerators() default choice when not given
  (1 instead of 0). Avoid using the default choice's first character as
  accelerator unless in GUI dialog, as the plain text confirm() assigns a
  default accelerator.
- Move subs/URL.vim into ingo-library as ingo/codec/URL.vim module.
- Allow optional a:ignorecase argument for ingo#str#StartsWith() and
  ingo#str#EndsWith().
- Add ingo#fs#path#IsCaseInsensitive().
- Add ingo#str#Equals() for when it's convenient to pass in the a:ignorecase
  flag. This avoids coding the conditional between ==# and ==? yourself.
- Add ingo/fs/path/split.vim module.
- Add ingo#fs#path#Exists().
- FIX: Correct ingo#escape#file#wildcardescape() of * and ? on Windows.

1.018	14-Apr-2014
- FIX: Off-by-one: Allow column 1 in ingo#text#Insert(). Add special cases for
  insertion at front and end of line (in the hope that this is more
  efficient).
- Add ingo#escape#file#wildcardescape().
- I18N: Correctly capture last multi-byte character in ingo#text#Get(); don't
  just add one to the end column, but instead match at the column itself, too.
- Add optional a:isExclusive flag to ingo#text#Get(), as clients may end up
  with that position, and doing a correct I18N-safe decrease before getting
  the text is a hen-and-egg problem.
- Add ingo/buffer/temprange.vim module.
- Add ingo#cursor#IsAtEndOfLine().
- FIX: Off-by-one in emulated ingo#compat#strdisplaywidth() reported one too
  few.

1.017	13-Mar-2014
- CHG: Make ingo#cmdargs#file#FilterFileOptionsAndCommands() return the
  options and commands in a List, not as a joined String. This allows clients
  to easily re-escape them and handle multiple ones, e.g. ++ff=dos +setf\ foo.
- Add workarounds for fnameescape() bugs on Windows for ! and [] characters.
- Add ingo#escape#UnescapeExpr().
- Add ingo/str/restricted.vim module.
- Make ingo#query#get#Char() only abort on <Esc> when that character is not in
  the validExpr (to allow to explicitly query it).
- Add ingo/query/substitute.vim module.
- Add ingo/subst/expr/emulation.vim module.
- Add ingo/cmdargs/register.vim module.

1.016	22-Jan-2014
- Add ingo#window#quickfix#GetList() and ingo#window#quickfix#SetList().
- Add ingo/cursor.vim module.
- Add ingo#text#Insert() and ingo#text#Remove().
- Add ingo#str#StartsWith() and ingo#str#EndsWith().
- Add ingo#dict#Mirror() and ingo#dict#AddMirrored().
- BUG: Wrap :autocmd! undo_ftplugin_N in :execute to that superordinated
  ftplugins can append additional undo commands without causing "E216: No such
  group or event: undo_ftplugin_N|setlocal".
- Add ingo/motion/helper.vim module.
- Add ingo/motion/omap.vim module.
- Add ingo/subst/pairs.vim module.
- Add ingo/plugin/compiler.vim module.
- Move ingo#escape#shellcommand#shellcmdescape() to
  ingo#compat#shellcommand#escape(), as it is only required for older Vim
  versions.

1.015	28-Nov-2013
- Add ingo/format.vim module.
- FIX: Actually return the result of a Funcref passed to
  ingo#register#KeepRegisterExecuteOrFunc().
- Make buffer argument of ingo#buffer#IsBlank() optional, defaulting to the
  current buffer.
- Allow use of ingo#buffer#IsEmpty() with other buffers.
- CHG: Pass _all_ additional arguments of ingo#actions#ValueOrFunc(),
  ingo#actions#NormalOrFunc(), ingo#actions#ExecuteOrFunc(),
  ingo#actions#EvaluateOrFunc() instead of only the first (interpreted as a
  List of arguments) when passed a Funcref as a:Action.
- Add ingo#compat#setpos().
- Add ingo/print.vim module.

1.014	14-Nov-2013
- Add ingo/date/format.vim module.
- Add ingo#os#PathSeparator().
- Add ingo/foldtext.vim module.
- Add ingo#os#IsCygwin().
- ingo#fs#path#Normalize(): Also convert between the different D:\ and
  /cygdrive/d/ notations on Windows and Cygwin.
- Add ingo#text#frompattern#GetHere().
- Add ingo/date/epoch.vim module.
- Add ingo#buffer#IsPersisted().
- Add ingo/list.vim module.
- Add ingo/query/confirm.vim module.
- Add ingo#text#GetChar().
- Add ingo/regexp/fromwildcard.vim module (contributed by the EditSimilar.vim
  plugin). In constrast to the simpler ingo#regexp#FromWildcard(), this
  handles the full range of wildcards and considers the path separators on
  different platforms.
- Add ingo#register#KeepRegisterExecuteOrFunc().
- Add ingo#actions#ValueOrFunc().
- Add ingo/funcref.vim module.
- Add month and year granularity to ingo#date#HumanReltime().
- Add ingo/units.vim module.

1.013	13-Sep-2013
- Also avoid clobbering the last change ('.') in ingo#selection#Get() when
  'cpo' contains "y".
- Name the temp buffer for ingo#buffer#temp#Execute() and re-use previous
  instances to avoid increasing the buffer numbers and output of :ls!.
- CHG: Make a:isIgnoreIndent flag to ingo#comments#CheckComment() optional and
  add a:isStripNonEssentialWhiteSpaceFromCommentString, which is also on by
  default for DWIM.
- CHG: Don't strip whitespace in ingo#comments#RemoveCommentPrefix(); with the
  changed ingo#comments#CheckComment() default behavior, this isn't necessary,
  and is unexpected.
- ingo#comments#RenderComment: When the text starts with indent identical to
  what 'commentstring' would render, avoid having duplicate indent.
- Minor: Return last search pattern instead of empty string on
  ingo#search#pattern#GetLastForwardSearch(0).
- Avoid using \ze in ingo#regexp#comments#CommentToExpression(). It may be
  used in a larger expression that still wants to match after the prefix.
- FIX: Correct case of ingo#os#IsWin*() function names.
- ingo#regexp#FromWildcard(): Limit * glob matching to individual path
  components and add ** for cross-directory matching.
- Consistently use operating system detection functions from ingo/os.vim
  within the ingo-library.

1.012	05-Sep-2013
- CHG: Change return value format of ingo#selection#frompattern#GetPositions()
  to better match the arguments of functions like ingo#text#Get().
- Add ingo/os.vim module.
- Add ingo#compat#fnameescape() and ingo#compat#shellescape() from
  escapings.vim.
- Add remaining former escapings.vim functions as ingo/escape/shellcommand.vim
  and ingo/escape/file.vim modules.
- Add ingo/motion/boundary.vim module.
- Add ingo#compat#maparg().
- Add ingo/escape/command.vim module.
- Add ingo/text/frompattern.vim module.

1.011	02-Aug-2013
- Add ingo/range.vim module.
- Add ingo/register.vim module.
- Make ingo#collections#ToDict() handle empty list items via an optional
  a:emptyValue argument. This also distinguishes it from ingo#dict#FromKeys().
- ENH: Handle empty list items in ingo#collections#Unique() and
  ingo#collections#UniqueStable().
- Add ingo/gui/position.vim module.
- Add ingo/filetype.vim module.
- Add ingo/ftplugin/onbufwinenter.vim module.
- Add ingo/selection/frompattern.vim module.
- Add ingo/text.vim module.
- Add ingo/ftplugin/windowsettings.vim module.
- Add ingo/text/replace.vim module.
- FIX: Use the rules for the /pattern/ separator as stated in :help E146 for
  ingo#cmdargs#pattern#Parse() and ingo#cmdargs#substitute#Parse().
- FIX: Off-by-one in ingo#strdisplaywidth#HasMoreThan() and
  ingo#strdisplaywidth#strleft().
- Add ingo#str#Reverse().
- ingo#fs#traversal#FindLastContainedInUpDir now defaults to the current
  buffer's directory; omit the argument.
- Add ingo#actions#EvaluateWithValOrFunc().
- Extract ingo#fs#path#IsUncPathRoot().
- Add ingo#fs#traversal#FindDirUpwards().

1.010	09-Jul-2013
- Add ingo/actions.vim module.
- Add ingo/cursor/move.vim module.
- Add ingo#collections#unique#AddNew() and
  ingo#collections#unique#InsertNew().
- Add ingo/selection/position.vim module.
- Add ingo/plugin/marks.vim module.
- Add ingo/date.vim module.
- Add ingo#buffer#IsEmpty().
- Add ingo/buffer/scratch.vim module.
- Add ingo/cmdargs/command.vim module.
- Add ingo/cmdargs/commandcommands.vim module.
- Add ingo/cmdargs/range.vim module.

1.009	03-Jul-2013
- Minor: Make substitute() robust against 'ignorecase' in various functions.
- Add ingo/subst.vim module.
- Add ingo/escape.vim module.
- Add ingo/regexp/comments.vim module.
- Add ingo/cmdline/showmode.vim module.
- Add ingo/str.vim module.
- Add ingo/strdisplaywidth/pad.vim module.
- Add ingo/dict.vim module.
- Add ingo#msg#HighlightMsg(), and allow to pass an optional highlight group
  to ingo#msg#StatusMsg().
- Add ingo#collections#Flatten() and ingo#collections#Flatten1().
- Move ingo#collections#MakeUnique() to ingo/collections/unique.vim.
- Add ingo#collections#unique#ExtendWithNew().
- Add ingo#fs#path#Equals().
- Add ingo#tabstops#RenderMultiLine(), as ingo#tabstops#Render() does not
  properly render multi-line text.
- Add ingo/str/split.vim module.
- FIX: Avoid E108: No such variable: "b:browsefilter" in
  ingo#query#file#Browse().

1.008	13-Jun-2013
- Fix missing argument error for ingo#query#file#BrowseDirForOpenFile() and
  ingo#query#file#BrowseDirForAction().
- Implement ingo#compat#strdisplaywidth() emulation inside the library;
  EchoWithoutScrolling.vim isn't used for that any more.
- Add ingo/avoidprompt.vim, ingo/strdisplaywidth.vim, and ingo/tabstops
  modules, containing the former EchoWithoutScrolling.vim functions.
- Add ingo/buffer/temp.vim and ingo/buffer/visible.vim modules.
- Add ingo/regexp/previoussubstitution.vim module.

1.007	06-Jun-2013
- Add ingo/query/get.vim module.
- Add ingo/query/file.vim module.
- Add ingo/fs/path.vim module.
- Add ingo/fs/tempfile.vim module.
- Add ingo/cmdargs/file.vim module.
- Add ingo/cmdargs/glob.vim module.
- CHG: Move most functions from ingo/cmdargs.vim to new modules
  ingo/cmdargs/pattern.vim and ingo/cmdargs/substitute.vim.
- Add ingo/compat/complete.vim module.

1.006	29-May-2013
- Add ingo/cmdrangeconverter.vim module.
- Add ingo#mapmaker.vim module.
- Add optional isReturnError flag on
  ingo#window#switches#GotoPreviousWindow().
- Add ingo#msg#StatusMsg().
- Add ingo/selection/patternmatch.vim module.
- Add ingo/selection.vim module.
- Add ingo/search/pattern.vim module.
- Add ingo/regexp.vim module.
- Add ingo/regexp/magic.vim module.
- Add ingo/collections/rotate.vim module.
- Redesign ingo#cmdargs#ParseSubstituteArgument() to the existing use cases.
- Add ingo/buffer.vim module.

1.005	02-May-2013
- Add ingo/plugin/setting.vim module.
- Add ingo/plugin/cmdcomplete.vim module.
- Add ingo/search/buffer.vim module.
- Add ingo/number.vim module.
- Add ingo#err#IsSet() for those cases when wrapping the command in :if does
  not work (e.g. :call'ing a range function).
- Add ingo#syntaxitem.vim module.
- Add ingo#comments.vim module.

1.004	10-Apr-2013
- Add ingo/compat.vim module.
- Add ingo/folds.vim module.
- Add ingo/lines module.
- Add ingo/matches module.
- Add ingo/mbyte/virtcol module.
- Add ingo/window/* modules.
- FIX: ingo#external#LaunchGvim() broken with "E117: Unknown function: s:externalLaunch".

1.003	27-Mar-2013
- Add ingo#msg#ShellError().
- Add ingo#system#Chomped().
- Add ingo/fs/traversal.vim module.
- Add search/timelimited.vim module.

1.002	08-Mar-2013
- Minor: Allow to specify filespec of GVIM executable in
  ingo#external#LaunchGvim().
- Add err module for LineJugglerCommands.vim plugin.

1.001	21-Feb-2013
Add cmdargs and collections modules for use by PatternsOnText.vim plugin.

1.000	12-Feb-2013
First published version as separate shared library.

0.001	05-Jan-2009
Started development of shared autoload functionality.

==============================================================================
Copyright: (C) 2009-2019 Ingo Karkat
Contains URL encoding / decoding algorithms written by Tim Pope.
The VIM LICENSE applies to this plugin; see |copyright|.

Maintainer:	Ingo Karkat <ingo@karkat.de>
==============================================================================
 vim:tw=78:ts=8:ft=help:norl:
