" Vimball Archiver by Charles E. Campbell
UseVimball
finish
autoload/mark.vim	[[[1
1161
" Script Name: mark.vim
" Description: Highlight several words in different colors simultaneously.
"
" Copyright:   (C) 2008-2019 Ingo Karkat
"              (C) 2005-2008 Yuheng Xie
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:  Ingo Karkat <ingo@karkat.de>
"
" DEPENDENCIES:
"   - ingo/cmdargs/pattern.vim autoload script
"   - ingo/err.vim autoload script
"   - ingo/msg.vim autoload script
"   - ingo/regexp.vim autoload script
"   - ingo/regexp/magic.vim autoload script
"   - ingo/regexp/split.vim autoload script
"   - SearchSpecial.vim autoload script (optional, for improved search messages).
"
" Version:     3.1.0

"- functions ------------------------------------------------------------------

silent! call SearchSpecial#DoesNotExist()	" Execute a function to force autoload.
if exists('*SearchSpecial#WrapMessage')
	function! s:WrapMessage( searchType, searchPattern, isBackward )
		redraw
		call SearchSpecial#WrapMessage(a:searchType, a:searchPattern, a:isBackward)
	endfunction
	function! s:EchoSearchPattern( searchType, searchPattern, isBackward )
		call SearchSpecial#EchoSearchPattern(a:searchType, a:searchPattern, a:isBackward)
	endfunction
else
	function! s:Trim( message )
		" Limit length to avoid "Hit ENTER" prompt.
		return strpart(a:message, 0, (&columns / 2)) . (len(a:message) > (&columns / 2) ? "..." : "")
	endfunction
	function! s:WrapMessage( searchType, searchPattern, isBackward )
		redraw
		let v:warningmsg = printf('%s search hit %s, continuing at %s', a:searchType, (a:isBackward ? 'TOP' : 'BOTTOM'), (a:isBackward ? 'BOTTOM' : 'TOP'))
		echohl WarningMsg
		echo s:Trim(v:warningmsg)
		echohl None
	endfunction
	function! s:EchoSearchPattern( searchType, searchPattern, isBackward )
		let l:message = (a:isBackward ? '?' : '/') .  a:searchPattern
		echohl SearchSpecialSearchType
		echo a:searchType
		echohl None
		echon s:Trim(l:message)
	endfunction
endif

function! s:EscapeText( text )
	return substitute( escape(a:text, '\' . '^$.*[~'), "\n", '\\n', 'ge' )
endfunction
function! s:IsIgnoreCase( expr )
	return ((exists('g:mwIgnoreCase') ? g:mwIgnoreCase : &ignorecase) && a:expr !~# '\\\@<!\\C')
endfunction
" Mark the current word, like the built-in star command.
" If the cursor is on an existing mark, remove it.
function! mark#MarkCurrentWord( groupNum )
	let l:regexp = (a:groupNum == 0 ? mark#CurrentMark()[0] : '')
	if empty(l:regexp)
		let l:cword = expand('<cword>')
		if ! empty(l:cword)
			let l:regexp = s:EscapeText(l:cword)
			" The star command only creates a \<whole word\> search pattern if the
			" <cword> actually only consists of keyword characters.
			if l:cword =~# '^\k\+$'
				let l:regexp = '\<' . l:regexp . '\>'
			endif
		endif
	endif
	return (empty(l:regexp) ? 0 : mark#DoMark(a:groupNum, l:regexp)[0])
endfunction

function! mark#GetVisualSelection()
	let save_clipboard = &clipboard
	set clipboard= " Avoid clobbering the selection and clipboard registers.
	let save_reg = getreg('"')
	let save_regmode = getregtype('"')
	silent normal! gvy
	let res = getreg('"')
	call setreg('"', save_reg, save_regmode)
	let &clipboard = save_clipboard
	return res
endfunction
function! mark#GetVisualSelectionAsLiteralPattern()
	return s:EscapeText(mark#GetVisualSelection())
endfunction
function! mark#GetVisualSelectionAsRegexp()
	return substitute(mark#GetVisualSelection(), '\n', '', 'g')
endfunction
function! mark#GetVisualSelectionAsLiteralWhitespaceIndifferentPattern()
	return substitute(escape(mark#GetVisualSelection(), '\' . '^$.*[~'), '\_s\+', '\\_s\\+', 'g')
endfunction

" Manually input a regular expression.
function! mark#MarkRegex( groupNum, regexpPreset )
	call inputsave()
		echohl Question
			let l:regexp = input('Input pattern to mark: ', a:regexpPreset)
		echohl None
	call inputrestore()
	if empty(l:regexp)
		call ingo#err#Clear()
		return 0
	endif

	redraw " This is necessary when the user is queried for the mark group.
	return mark#DoMarkAndSetCurrent(a:groupNum, ingo#regexp#magic#Normalize(l:regexp))[0]
endfunction

function! s:Cycle( ... )
	let l:currentCycle = s:cycle
	let l:newCycle = (a:0 ? a:1 : s:cycle) + 1
	let s:cycle = (l:newCycle < s:markNum ? l:newCycle : 0)
	return l:currentCycle
endfunction
function! s:FreeGroupIndex()
	let i = 0
	while i < s:markNum
		if empty(s:pattern[i])
			return i
		endif
		let i += 1
	endwhile
	return -1
endfunction
function! mark#NextUsedGroupIndex( isBackward, isWrapAround, startIndex, count )
	if a:isBackward
		let l:indices = range(a:startIndex - 1, 0, -1)
		if a:isWrapAround
			let l:indices += range(s:markNum - 1, a:startIndex + 1, -1) :
		endif
	else
		let l:indices = range(a:startIndex + 1, s:markNum - 1)
		if a:isWrapAround
			let l:indices += range(0, max([-1, a:startIndex - 1]))
		endif
	endif

	let l:count = a:count
	for l:i in l:indices
		if ! empty(s:pattern[l:i])
			let l:count -= 1
			if l:count == 0
				return l:i
			endif
		endif
	endfor
	return -1
endfunction

function! mark#DefaultExclusionPredicate()
	return (exists('b:nomarks') && b:nomarks) || (exists('w:nomarks') && w:nomarks) || (exists('t:nomarks') && t:nomarks)
endfunction

" Set match / clear matches in the current window.
function! s:MarkMatch( indices, expr )
	if ! exists('w:mwMatch')
		let w:mwMatch = repeat([0], s:markNum)
	elseif len(w:mwMatch) != s:markNum
		" The number of marks has changed.
		if len(w:mwMatch) > s:markNum
			" Truncate the matches.
			for l:match in filter(w:mwMatch[s:markNum : ], 'v:val > 0')
				silent! call matchdelete(l:match)
			endfor
			let w:mwMatch = w:mwMatch[0 : (s:markNum - 1)]
		else
			" Expand the matches.
			let w:mwMatch += repeat([0], (s:markNum - len(w:mwMatch)))
		endif
	endif

	for l:index in a:indices
		if w:mwMatch[l:index] > 0
			silent! call matchdelete(w:mwMatch[l:index])
			let w:mwMatch[l:index] = 0
		endif
	endfor

	if ! empty(a:expr)
		let l:index = a:indices[0]	" Can only set one index for now.

		" Info: matchadd() does not consider the 'magic' (it's always on),
		" 'ignorecase' and 'smartcase' settings.
		" Make the match according to the 'ignorecase' setting, like the star command.
		" (But honor an explicit case-sensitive regexp via the /\C/ atom.)
		let l:expr = (s:IsIgnoreCase(a:expr) ? '\c' : '') . a:expr

		" To avoid an arbitrary ordering of highlightings, we assign a different
		" priority based on the highlight group.
		let l:priority = g:mwMaxMatchPriority - s:markNum + 1 + l:index

		let w:mwMatch[l:index] = matchadd('MarkWord' . (l:index + 1), l:expr, l:priority)
	endif
endfunction
" Initialize mark colors in a (new) window.
function! mark#UpdateMark( ... )
	for l:Predicate in g:mwExclusionPredicates
		if ingo#actions#EvaluateOrFunc(l:Predicate)
			" The window may have had marks applied previously. Clear any
			" existing matches.
			call s:MarkMatch(range(s:markNum), '')

			return
		endif
	endfor

	if a:0
		call call('s:MarkMatch', a:000)
	else
		let i = 0
		while i < s:markNum
			if ! s:enabled || empty(s:pattern[i])
				call s:MarkMatch([i], '')
			else
				call s:MarkMatch([i], s:pattern[i])
			endif
			let i += 1
		endwhile
	endif
endfunction
" Update matches in all windows.
function! mark#UpdateScope( ... )
	" By entering a window, its height is potentially increased from 0 to 1 (the
	" minimum for the current window). To avoid any modification, save the window
	" sizes and restore them after visiting all windows.
	let l:originalWindowLayout = winrestcmd()
		let l:originalWinNr = winnr()
		let l:previousWinNr = winnr('#') ? winnr('#') : 1
			noautocmd keepjumps windo call call('mark#UpdateMark', a:000)
		noautocmd execute l:previousWinNr . 'wincmd w'
		noautocmd execute l:originalWinNr . 'wincmd w'
	silent! execute l:originalWindowLayout
endfunction

function! s:MarkEnable( enable, ...)
	if s:enabled != a:enable
		" En-/disable marks and perform a full refresh in all windows, unless
		" explicitly suppressed by passing in 0.
		let s:enabled = a:enable
		if g:mwAutoSaveMarks
			let g:MARK_ENABLED = s:enabled
		endif

		if ! a:0 || ! a:1
			call mark#UpdateScope()
		endif
	endif
endfunction
function! s:EnableAndMarkScope( indices, expr )
	if s:enabled
		" Marks are already enabled, we just need to push the changes to all
		" windows.
		call mark#UpdateScope(a:indices, a:expr)
	else
		call s:MarkEnable(1)
	endif
endfunction

" Toggle visibility of marks, like :nohlsearch does for the regular search
" highlighting.
function! mark#Toggle()
	if s:enabled
		call s:MarkEnable(0)
		echo 'Disabled marks'
	else
		call s:MarkEnable(1)

		let l:markCnt = mark#GetCount()
		echo 'Enabled' (l:markCnt > 0 ? l:markCnt . ' ' : '') . 'marks'
	endif
endfunction


" Mark or unmark a regular expression.
function! mark#Clear( groupNum )
	if a:groupNum > 0
		return mark#DoMark(a:groupNum, '')[0]
	else
		let l:markText = mark#CurrentMark()[0]
		if empty(l:markText)
			return mark#DoMark(a:groupNum)[0]
		else
			return mark#DoMark(a:groupNum, l:markText)[0]
		endif
	endif
endfunction
function! s:SetPattern( index, pattern )
	let s:pattern[a:index] = a:pattern

	if g:mwAutoSaveMarks
		call s:SavePattern()
	endif
endfunction
function! mark#ClearAll()
	let i = 0
	let indices = []
	while i < s:markNum
		if ! empty(s:pattern[i])
			call s:SetPattern(i, '')
			call add(indices, i)
		endif
		let i += 1
	endwhile
	let s:lastSearch = -1

	" Re-enable marks; not strictly necessary, since all marks have just been
	" cleared, and marks will be re-enabled, anyway, when the first mark is
	" added. It's just more consistent for mark persistence. But save the full
	" refresh, as we do the update ourselves.
	call s:MarkEnable(0, 0)

	call mark#UpdateScope(l:indices, '')

	if len(indices) > 0
		echo 'Cleared all' len(indices) 'marks'
	else
		echo 'All marks cleared'
	endif
endfunction
function! s:SetMark( index, regexp, ... )
	if a:0
		if s:lastSearch == a:index
			let s:lastSearch = a:1
		endif
	endif
	call s:SetPattern(a:index, a:regexp)
	call s:EnableAndMarkScope([a:index], a:regexp)
endfunction
function! s:ClearMark( index )
	" A last search there is reset.
	call s:SetMark(a:index, '', -1)
endfunction
function! s:RenderName( groupNum )
	return (empty(s:names[a:groupNum - 1]) ? '' : ':' . s:names[a:groupNum - 1])
endfunction
function! s:EnrichSearchType( searchType )
	if a:searchType !=# 'mark*'
		return a:searchType
	endif

	let [l:markText, l:markPosition, l:markIndex] = mark#CurrentMark()
	return (l:markIndex >= 0 ? a:searchType . (l:markIndex + 1) .  s:RenderName(l:markIndex + 1) : a:searchType)
endfunction
function! s:RenderMark( groupNum )
	return 'mark-' . a:groupNum . s:RenderName(a:groupNum)
endfunction
function! s:EchoMark( groupNum, regexp )
	call s:EchoSearchPattern(s:RenderMark(a:groupNum), a:regexp, 0)
endfunction
function! s:EchoMarkCleared( groupNum )
	echohl SearchSpecialSearchType
	echo s:RenderMark(a:groupNum)
	echohl None
	echon ' cleared'
endfunction
function! s:EchoMarksDisabled()
	echo 'All marks disabled'
endfunction

function! s:SplitIntoAlternatives( pattern )
	return ingo#regexp#split#TopLevelBranches(a:pattern)
endfunction

" Return [success, markGroupNum]. success is true when the mark has been set or
" cleared. markGroupNum is the mark group number where the mark was set. It is 0
" if the group was cleared.
function! mark#DoMark( groupNum, ... )
	call ingo#err#Clear()
	if s:markNum <= 0
		" Uh, somehow no mark highlightings were defined. Try to detect them again.
		call mark#Init()
		if s:markNum <= 0
			" Still no mark highlightings; complain.
			call ingo#err#Set('No mark highlightings defined')
			return [0, 0]
		endif
	endif

	let l:groupNum = a:groupNum
	if l:groupNum > s:markNum
		" This highlight group does not exist.
		let l:groupNum = mark#QueryMarkGroupNum()
		if l:groupNum < 1 || l:groupNum > s:markNum
			return [0, 0]
		endif
	endif

	let regexp = (a:0 ? a:1 : '')
	if empty(regexp)
		if l:groupNum == 0
			if a:0
				" :Mark // looks more like a typo than a command to disable all
				" marks; prevent that, and only accept :Mark for it.
				call ingo#err#Set('Do not pass empty pattern to disable all marks')
				return [0, 0]
			endif

			" Disable all marks.
			call s:MarkEnable(0)
			call s:EchoMarksDisabled()
		else
			" Clear the mark represented by the passed highlight group number.
			call s:ClearMark(l:groupNum - 1)
			if a:0 >= 2 | let s:names[l:groupNum - 1] = a:2 | endif
			call s:EchoMarkCleared(l:groupNum)
		endif

		return [1, 0]
	endif

	if l:groupNum == 0
		" Clear the mark if it has been marked.
		let i = 0
		while i < s:markNum
			if regexp ==# s:pattern[i]
				call s:ClearMark(i)
				if a:0 >= 2 | let s:names[i] = a:2 | endif
				call s:EchoMarkCleared(i + 1)
				return [1, 0]
			endif
			let i += 1
		endwhile
	else
		" Add / subtract the pattern as an alternative to the mark represented
		" by the passed highlight group number.
		let existingPattern = s:pattern[l:groupNum - 1]
		if ! empty(existingPattern)
			let alternatives = s:SplitIntoAlternatives(existingPattern)
			if index(alternatives, regexp) == -1
				let regexp = join(ingo#regexp#split#AddPatternByProjectedMatchLength(alternatives, regexp), '\|')
			else
				let regexp = join(filter(alternatives, 'v:val !=# regexp'), '\|')
				if empty(regexp)
					call s:ClearMark(l:groupNum - 1)
					if a:0 >= 2 | let s:names[l:groupNum - 1] = a:2 | endif
					call s:EchoMarkCleared(l:groupNum)
					return [1, 0]
				endif
			endif
		endif
	endif

	" add to history
	if stridx(g:mwHistAdd, '/') >= 0
		call histadd('/', regexp)
	endif
	if stridx(g:mwHistAdd, '@') >= 0
		call histadd('@', regexp)
	endif

	if l:groupNum == 0
		let i = s:FreeGroupIndex()
		if i != -1
			" Choose an unused highlight group. The last search is kept untouched.
			call s:Cycle(i)
			call s:SetMark(i, regexp)
		else
			" Choose a highlight group by cycle. A last search there is reset.
			let i = s:Cycle()
			call s:SetMark(i, regexp, -1)
		endif
	else
		let i = l:groupNum - 1
		" Use and extend the passed highlight group. A last search is updated
		" and thereby kept active.
		call s:SetMark(i, regexp, i)
	endif

	if a:0 >= 2 | let s:names[i] = a:2 | endif
	call s:EchoMark(i + 1, regexp)
	return [1, i + 1]
endfunction
function! mark#DoMarkAndSetCurrent( groupNum, ... )
	" To avoid accepting an invalid regular expression (e.g. "\(blah") and then
	" causing ugly errors on every mark update, check the patterns passed by the
	" user for validity. (We assume that the expressions generated by the plugin
	" itself from literal text are all valid.)
	if a:0 && ! ingo#regexp#IsValid(a:1)
		return [0, 0]
	endif

	let l:result = call('mark#DoMark', [a:groupNum] + a:000)
	let l:markGroupNum = l:result[1]
	if l:markGroupNum > 0
		let s:lastSearch = l:markGroupNum - 1
	endif

	return l:result
endfunction
function! mark#SetMark( groupNum, ... )
	" For the :Mark command, don't query when the passed mark group doesn't
	" exist (interactivity in Ex commands is unexpected). Instead, return an
	" error.
	if s:markNum > 0 && a:groupNum > s:markNum
		call ingo#err#Set(printf('Only %d mark highlight groups', s:markNum))
		return 0
	endif
	if a:0
		let [l:pattern, l:nameArgument] = ingo#cmdargs#pattern#ParseUnescapedWithLiteralWholeWord(a:1, '\(\s\+as\%(\s\+\(.\{-}\)\)\?\)\?\s*')
		let l:pattern = ingo#regexp#magic#Normalize(l:pattern)  " We'd strictly only have to do this for /{pattern}/, not for whole word(s), but as the latter doesn't contain magicness atoms, it doesn't hurt, and with this we don't need to explicitly distinguish between the two cases.
		if ! empty(l:nameArgument)
			let l:name = substitute(l:nameArgument, '^\s\+as\s*', '', '')
			return mark#DoMarkAndSetCurrent(a:groupNum, l:pattern, l:name)
		else
			return mark#DoMarkAndSetCurrent(a:groupNum, l:pattern)
		endif
	else
		return mark#DoMarkAndSetCurrent(a:groupNum)
	endif
endfunction

" Return [mark text, mark start position, mark index] of the mark under the
" cursor (or ['', [], -1] if there is no mark).
" The mark can include the trailing newline character that concludes the line,
" but marks that span multiple lines are not supported.
function! mark#CurrentMark()
	let line = getline('.') . "\n"

	" Highlighting groups with higher numbers take precedence over lower numbers,
	" and therefore its marks appear "above" other marks. To retrieve the visible
	" mark in case of overlapping marks, we need to check from highest to lowest
	" highlight group.
	let i = s:markNum - 1
	while i >= 0
		if ! empty(s:pattern[i])
			let matchPattern = (s:IsIgnoreCase(s:pattern[i]) ? '\c' : '\C') . s:pattern[i]
			" Note: col() is 1-based, all other indexes zero-based!
			let start = 0
			while start >= 0 && start < strlen(line) && start < col('.')
				let b = match(line, matchPattern, start)
				let e = matchend(line, matchPattern, start)
				if b < col('.') && col('.') <= e
					return [s:pattern[i], [line('.'), (b + 1)], i]
				endif
				if b == e
					break
				endif
				let start = e
			endwhile
		endif
		let i -= 1
	endwhile
	return ['', [], -1]
endfunction

" Search current mark.
function! mark#SearchCurrentMark( isBackward )
	let l:result = 0

	let [l:markText, l:markPosition, l:markIndex] = mark#CurrentMark()
	if empty(l:markText)
		if s:lastSearch == -1
			let l:result = mark#SearchAnyMark(a:isBackward)
			let s:lastSearch = mark#CurrentMark()[2]
		else
			let l:result = s:Search(s:pattern[s:lastSearch], v:count1, a:isBackward, [], s:RenderMark(s:lastSearch + 1))
		endif
	else
		let l:result = s:Search(l:markText, v:count1, a:isBackward, l:markPosition, s:RenderMark(l:markIndex + 1) . (l:markIndex ==# s:lastSearch ? '' : '!'))
		let s:lastSearch = l:markIndex
	endif

	return l:result
endfunction

function! mark#SearchGroupMark( groupNum, count, isBackward, isSetLastSearch )
	call ingo#err#Clear()
	if a:groupNum == 0
		" No mark group number specified; use last search, and fall back to
		" current mark if possible.
		if s:lastSearch == -1
			let [l:markText, l:markPosition, l:markIndex] = mark#CurrentMark()
			if empty(l:markText)
				return 0
			endif
		else
			let l:markIndex = s:lastSearch
			let l:markText = s:pattern[l:markIndex]
			let l:markPosition = []
		endif
	else
		let l:groupNum = a:groupNum
		if l:groupNum > s:markNum
			" This highlight group does not exist.
			let l:groupNum = mark#QueryMarkGroupNum()
			if l:groupNum < 1 || l:groupNum > s:markNum
				return 0
			endif
		endif

		let l:markIndex = l:groupNum - 1
		let l:markText = s:pattern[l:markIndex]
		let l:markPosition = []
	endif

	let l:result =  s:Search(l:markText, a:count, a:isBackward, l:markPosition, s:RenderMark(l:markIndex + 1) . (l:markIndex ==# s:lastSearch ? '' : '!'))
	if a:isSetLastSearch
		let s:lastSearch = l:markIndex
	endif
	return l:result
endfunction

function! mark#SearchNextGroup( count, isBackward )
	if s:lastSearch == -1
		" Fall back to current mark in case of no last search.
		let [l:markText, l:markPosition, l:markIndex] = mark#CurrentMark()
		if empty(l:markText)
			" Fall back to next group that would be taken.
			let l:groupIndex = s:GetNextGroupIndex()
		else
			let l:groupIndex = l:markIndex
		endif
	else
		let l:groupIndex = s:lastSearch
	endif

	let l:groupIndex = mark#NextUsedGroupIndex(a:isBackward, 1, l:groupIndex, a:count)
	if l:groupIndex == -1
		call ingo#err#Set(printf('No %s mark group%s used', (a:count == 1 ? '' : a:count . ' ') . (a:isBackward ? 'previous' : 'next'), (a:count == 1 ? '' : 's')))
		return 0
	endif
	return mark#SearchGroupMark(l:groupIndex + 1, 1, a:isBackward, 1)
endfunction


function! mark#NoMarkErrorMessage()
	call ingo#err#Set('No marks defined')
endfunction
function! s:ErrorMessage( searchType, searchPattern, isBackward )
	if &wrapscan
		let l:errmsg = a:searchType . ' not found: ' . a:searchPattern
	else
		let l:errmsg = printf('%s search hit %s without match for: %s', a:searchType, (a:isBackward ? 'TOP' : 'BOTTOM'), a:searchPattern)
	endif
	call ingo#err#Set(l:errmsg)
endfunction

" Wrapper around search() with additonal search and error messages and "wrapscan" warning.
function! s:Search( pattern, count, isBackward, currentMarkPosition, searchType )
	if empty(a:pattern)
		call mark#NoMarkErrorMessage()
		return 0
	endif

	let l:save_view = winsaveview()

	" searchpos() obeys the 'smartcase' setting; however, this setting doesn't
	" make sense for the mark search, because all patterns for the marks are
	" concatenated as branches in one large regexp, and because patterns that
	" result from the *-command-alike mappings should not obey 'smartcase' (like
	" the * command itself), anyway. If the :Mark command wants to support
	" 'smartcase', it'd have to emulate that into the regular expression.
	" Instead of temporarily unsetting 'smartcase', we force the correct
	" case-matching behavior through \c / \C.
	let l:searchPattern = (s:IsIgnoreCase(a:pattern) ? '\c' : '\C') . a:pattern

	let l:count = a:count
	let l:isWrapped = 0
	let l:isMatch = 0
	let l:line = 0
	while l:count > 0
		let [l:prevLine, l:prevCol] = [line('.'), col('.')]

		" Search for next match, 'wrapscan' applies.
		let [l:line, l:col] = searchpos( l:searchPattern, (a:isBackward ? 'b' : '') )

"****D echomsg '****' a:isBackward string([l:line, l:col]) string(a:currentMarkPosition) l:count
		if a:isBackward && l:line > 0 && [l:line, l:col] == a:currentMarkPosition && l:count == a:count
			" On a search in backward direction, the first match is the start of the
			" current mark (if the cursor was positioned on the current mark text, and
			" not at the start of the mark text).
			" In contrast to the normal search, this is not considered the first
			" match. The mark text is one entity; if the cursor is positioned anywhere
			" inside the mark text, the mark text is considered the current mark. The
			" built-in '*' and '#' commands behave in the same way; the entire <cword>
			" text is considered the current match, and jumps move outside that text.
			" In normal search, the cursor can be positioned anywhere (via offsets)
			" around the search, and only that single cursor position is considered
			" the current match.
			" Thus, the search is retried without a decrease of l:count, but only if
			" this was the first match; repeat visits during wrapping around count as
			" a regular match. The search also must not be retried when this is the
			" first match, but we've been here before (i.e. l:isMatch is set): This
			" means that there is only the current mark in the buffer, and we must
			" break out of the loop and indicate that search wrapped around and no
			" other mark was found.
			if l:isMatch
				let l:isWrapped = 1
				break
			endif

			" The l:isMatch flag is set so if the final mark cannot be reached, the
			" original cursor position is restored. This flag also allows us to detect
			" whether we've been here before, which is checked above.
			let l:isMatch = 1
		elseif l:line > 0
			let l:isMatch = 1
			let l:count -= 1

			" Note: No need to check 'wrapscan'; the wrapping can only occur if
			" 'wrapscan' is actually on.
			if ! a:isBackward && (l:prevLine > l:line || l:prevLine == l:line && l:prevCol >= l:col)
				let l:isWrapped = 1
			elseif a:isBackward && (l:prevLine < l:line || l:prevLine == l:line && l:prevCol <= l:col)
				let l:isWrapped = 1
			endif
		else
			break
		endif
	endwhile

	" We're not stuck when the search wrapped around and landed on the current
	" mark; that's why we exclude a possible wrap-around via a:count == 1.
	let l:isStuckAtCurrentMark = ([l:line, l:col] == a:currentMarkPosition && a:count == 1)
"****D echomsg '****' l:line l:isStuckAtCurrentMark l:isWrapped l:isMatch string([l:line, l:col]) string(a:currentMarkPosition)
	if l:line > 0 && ! l:isStuckAtCurrentMark
		let l:matchPosition = getpos('.')

		" Open fold at the search result, like the built-in commands.
		normal! zv

		" Add the original cursor position to the jump list, like the
		" [/?*#nN] commands.
		" Implementation: Memorize the match position, restore the view to the state
		" before the search, then jump straight back to the match position. This
		" also allows us to set a jump only if a match was found. (:call
		" setpos("''", ...) doesn't work in Vim 7.2)
		call winrestview(l:save_view)
		normal! m'
		call setpos('.', l:matchPosition)

		" Enable marks (in case they were disabled) after arriving at the mark (to
		" avoid unnecessary screen updates) but before the error message (to avoid
		" it getting lost due to the screen updates).
		call s:MarkEnable(1)

		if l:isWrapped
			call s:WrapMessage(s:EnrichSearchType(a:searchType), a:pattern, a:isBackward)
		else
			call s:EchoSearchPattern(s:EnrichSearchType(a:searchType), a:pattern, a:isBackward)
		endif
		return 1
	else
		if l:isMatch
			" The view has been changed by moving through matches until the end /
			" start of file, when 'nowrapscan' forced a stop of searching before the
			" l:count'th match was found.
			" Restore the view to the state before the search.
			call winrestview(l:save_view)
		endif

		" Enable marks (in case they were disabled) after arriving at the mark (to
		" avoid unnecessary screen updates) but before the error message (to avoid
		" it getting lost due to the screen updates).
		call s:MarkEnable(1)

		if l:line > 0 && l:isStuckAtCurrentMark && l:isWrapped
			call s:WrapMessage(s:EnrichSearchType(a:searchType), a:pattern, a:isBackward)
			return 1
		else
			call s:ErrorMessage(a:searchType, a:pattern, a:isBackward)
			return 0
		endif
	endif
endfunction

" Combine all marks into one regexp.
function! s:AnyMark()
	return join(filter(copy(s:pattern), '! empty(v:val)'), '\|')
endfunction

" Search any mark.
function! mark#SearchAnyMark( isBackward )
	let l:markPosition = mark#CurrentMark()[1]
	let l:markText = s:AnyMark()
	let s:lastSearch = -1
	return s:Search(l:markText, v:count1, a:isBackward, l:markPosition, 'mark*')
endfunction

" Search last searched mark.
function! mark#SearchNext( isBackward, ... )
	let l:markText = mark#CurrentMark()[0]
	if empty(l:markText)
		return 0    " Fall back to the built-in * / # command (done by the mapping).
	endif

	" Use the provided search type or choose depending on last use of
	" <Plug>MarkSearchCurrentNext / <Plug>MarkSearchAnyNext.
	call call(a:0 ? a:1 : (s:lastSearch == -1 ? 'mark#SearchAnyMark' : 'mark#SearchCurrentMark'), [a:isBackward])
	return 1
endfunction



" Load mark patterns from list.
function! mark#Load( marks, enabled )
	if s:markNum > 0 && len(a:marks) > 0
		" Initialize mark patterns (and optional names) with the passed list.
		" Ensure that, regardless of the list length, s:pattern / s:names
		" contain exactly s:markNum elements.
		for l:index in range(s:markNum)
			call s:DeserializeMark(get(a:marks, l:index, ''), l:index)
		endfor

		let s:enabled = a:enabled

		call mark#UpdateScope()

		" The list of patterns may be sparse, return only the actual patterns.
		return mark#GetCount()
	endif
	return 0
endfunction

" Access the list of mark patterns.
function! s:SerializeMark( index )
	return (empty(s:names[a:index]) ? s:pattern[a:index] : {'pattern': s:pattern[a:index], 'name': s:names[a:index]})
endfunction
function! s:Deserialize( mark )
	return (type(a:mark) == type({}) ? [get(a:mark, 'pattern', ''), get(a:mark, 'name', '')] : [a:mark, ''])
endfunction
function! s:DeserializeMark( mark, index )
	let [s:pattern[a:index], s:names[a:index]] = s:Deserialize(a:mark)
endfunction
function! mark#ToList()
	" Trim unused patterns from the end of the list, the amount of available marks
	" may differ on the next invocation (e.g. due to a different number of
	" highlight groups in Vim and GVIM). We want to keep empty patterns in the
	" front and middle to maintain the mapping to highlight groups, though.
	let l:highestNonEmptyIndex = s:markNum - 1
	while l:highestNonEmptyIndex >= 0 && empty(s:pattern[l:highestNonEmptyIndex]) && empty(s:names[l:highestNonEmptyIndex])
		let l:highestNonEmptyIndex -= 1
	endwhile

	return (l:highestNonEmptyIndex < 0 ? [] : map(range(0, l:highestNonEmptyIndex), 's:SerializeMark(v:val)'))
endfunction

" Common functions for :MarkLoad and :MarkSave
function! mark#MarksVariablesComplete( ArgLead, CmdLine, CursorPos )
	return sort(map(filter(keys(g:), 'v:val !~# "^MARK_\\%(MARKS\\|ENABLED\\)$" && v:val =~# "\\V\\^MARK_' . (empty(a:ArgLead) ? '\\S' : escape(a:ArgLead, '\')) . '"'), 'v:val[5:]'))
endfunction
function! s:GetMarksVariable( ... )
	return printf('MARK_%s', (a:0 ? a:1 : 'MARKS'))
endfunction

" :MarkLoad command.
function! mark#LoadCommand( isShowMessages, ... )
	try
		let l:marksVariable = call('s:GetMarksVariable', a:000)
		let l:isEnabled = (a:0 ? exists('g:' . l:marksVariable) : (exists('g:MARK_ENABLED') ? g:MARK_ENABLED : 1))

		let l:marks = ingo#plugin#persistence#Load(l:marksVariable, [])
		if empty(l:marks)
			call ingo#err#Set('No marks stored under ' . l:marksVariable . (ingo#plugin#persistence#CanPersist(l:marksVariable) ? '' : ", and persistence not configured via ! flag in 'viminfo'"))
			return 0
		endif

		let l:loadedMarkNum = mark#Load(l:marks, l:isEnabled)

		if a:isShowMessages
			if l:loadedMarkNum == 0
				echomsg 'No persistent marks defined in ' . l:marksVariable
			else
				echomsg printf('Loaded %d mark%s', l:loadedMarkNum, (l:loadedMarkNum == 1 ? '' : 's')) . (s:enabled ? '' : '; marks currently disabled')
			endif
		endif

		return 1
	catch /^Load:/
		if a:0
			call ingo#err#Set(printf('Corrupted persistent mark info in %s', l:marksVariable))
			execute 'unlet! g:' . l:marksVariable
		else
			call ingo#err#Set('Corrupted persistent mark info in g:MARK_MARKS and g:MARK_ENABLED')
			unlet! g:MARK_MARKS
			unlet! g:MARK_ENABLED
		endif
		return 0
	endtry
endfunction

" :MarkSave command.
function! s:SavePattern( ... )
	let l:savedMarks = mark#ToList()

	let l:marksVariable = call('s:GetMarksVariable', a:000)
	call ingo#plugin#persistence#Store(l:marksVariable, l:savedMarks)
	if ! a:0
		let g:MARK_ENABLED = s:enabled
	endif

	return (empty(l:savedMarks) ? 2 : 1)
endfunction
function! mark#SaveCommand( ... )
	if ! ingo#plugin#persistence#CanPersist()
		if ! a:0
			call ingo#err#Set("Cannot persist marks, need ! flag in 'viminfo': :set viminfo+=!")
			return 0
		elseif a:1 =~# '^\L\+$'
			call ingo#msg#WarningMsg("Cannot persist marks, need ! flag in 'viminfo': :set viminfo+=!")
		endif
	endif

	let l:result = call('s:SavePattern', a:000)
	if l:result == 2
		call ingo#msg#WarningMsg('No marks defined')
	endif
	return l:result
endfunction

" :MarkYankDefinitions and :MarkYankDefinitionsOneLiner commands.
function! mark#GetDefinitionCommands( isOneLiner )
	let l:marks = mark#ToList()
	if empty(l:marks)
		return []
	endif

	let l:commands = []
	for l:i in range(len(l:marks))
		if ! empty(l:marks[l:i])
			let [l:pattern, l:name] = s:Deserialize(l:marks[l:i])
			call add(l:commands, printf('%dMark! /%s/%s', l:i + 1, escape(l:pattern, '/'), (empty(l:name) ? '' : ' as ' . l:name)))
		endif
	endfor

	return (a:isOneLiner ? [join(map(l:commands, '"exe " . string(v:val)'), ' | ')] : l:commands)
endfunction
function! mark#YankDefinitions( isOneLiner, register )
	let l:commands = mark#GetDefinitionCommands(a:isOneLiner)
	if empty(l:commands)
		call ingo#err#Set('No marks defined')
		return 0
	endif

	return ! setreg(a:register, join(l:commands, "\n"))
endfunction

" :MarkName command.
function! s:HasNamedMarks()
	return (! empty(filter(copy(s:names), '! empty(v:val)')))
endfunction
function! mark#SetName( isClearAll, groupNum, name )
	if a:isClearAll
		if a:groupNum != 0
			call ingo#err#Set('Use either [!] to clear all names, or [N] to name a single group, but not both.')
			return 0
		endif
		let s:names = repeat([''], s:markNum)
	elseif a:groupNum > s:markNum
		call ingo#err#Set(printf('Only %d mark highlight groups', s:markNum))
		return 0
	else
		let s:names[a:groupNum - 1] = a:name
	endif
	return 1
endfunction


" Query mark group number.
function! s:GetNextGroupIndex()
	let l:nextGroupIndex = s:FreeGroupIndex()
	if l:nextGroupIndex == -1
		let l:nextGroupIndex = s:cycle
	endif
	return l:nextGroupIndex
endfunction
function! s:GetMarker( index, nextGroupIndex )
	let l:marker = ''
	if s:lastSearch == a:index
		let l:marker .= '/'
	endif
	if a:index == a:nextGroupIndex
		let l:marker .= '>'
	endif
	return l:marker
endfunction
function! s:GetAlternativeCount( pattern )
	return len(s:SplitIntoAlternatives(a:pattern))
endfunction
function! s:PrintMarkGroup( nextGroupIndex )
	for i in range(s:markNum)
		echon ' '
		execute 'echohl MarkWord' . (i + 1)
		let c = s:GetAlternativeCount(s:pattern[i])
		echon printf('%1s%s%2d ', s:GetMarker(i, a:nextGroupIndex), (c ? (c > 1 ? c : '') . '*' : ''), (i + 1))
		echohl None
	endfor
endfunction
function! mark#QueryMarkGroupNum()
	echohl Question
	echo 'Mark?'
	echohl None
	let l:nextGroupIndex = s:GetNextGroupIndex()
	call s:PrintMarkGroup(l:nextGroupIndex)

	let l:nr = 0
	while 1
		let l:char = nr2char(getchar())

		if l:char ==# "\<CR>"
			return (l:nr == 0 ? l:nextGroupIndex + 1 : l:nr)
		elseif l:char !~# '\d'
			return -1
		endif
		echon l:char

		let l:nr = 10 * l:nr + l:char
		if s:markNum < 10 * l:nr
			return l:nr
		endif
	endwhile
endfunction

" :Marks command.
function! mark#List()
	let l:hasNamedMarks = s:HasNamedMarks()
	echohl Title
	if l:hasNamedMarks
		echo "group:name\tpattern"
	else
		echo 'group     pattern'
	endif
	echohl None
	echon '   (N) # of alternatives   > next mark group    / current search mark'
	let l:nextGroupIndex = s:GetNextGroupIndex()
	for i in range(s:markNum)
		execute 'echohl MarkWord' . (i + 1)
		let l:alternativeCount = s:GetAlternativeCount(s:pattern[i])
		let l:alternativeCountString = (l:alternativeCount > 1 ? ' (' . l:alternativeCount . ')' : '')
		let [l:name, l:format] = (empty(s:names[i]) ? ['', '%-4s'] : [':' . s:names[i], '%-10s'])
		echo printf('%1s%3d' . l:format . ' ', s:GetMarker(i, l:nextGroupIndex), (i + 1), l:name . l:alternativeCountString)
		echohl None
		echon (l:hasNamedMarks ? "\t" : ' ') . s:pattern[i]
	endfor

	if ! s:enabled
		echo 'Marks are currently disabled.'
	endif
endfunction


" :Mark command completion.
function! mark#Complete( ArgLead, CmdLine, CursorPos )
	let l:cmdlineBeforeCursor = strpart(a:CmdLine, 0, a:CursorPos)
	let l:matches = matchlist(l:cmdlineBeforeCursor, '\C\(\d*\)\s*Mark!\?\s\+\V' . escape(a:ArgLead, '\'))
	if empty(l:matches)
		return []
	endif

	" Complete from the command's mark group, or all groups when none is
	" specified.
	let l:groupNum = 0 + l:matches[1]
	let l:patterns =(l:groupNum == 0 || empty(get(s:pattern, l:groupNum - 1, '')) ? s:GetUsedPatterns() : [s:pattern[l:groupNum - 1]])

	" Complete both the entire pattern as well as its individual alternatives.
	let l:expandedPatterns = []
	for l:pattern in l:patterns
		if index(l:expandedPatterns, l:pattern) == -1
			call add(l:expandedPatterns, l:pattern)
		endif
		let l:alternatives = s:SplitIntoAlternatives(l:pattern)
		if len(l:alternatives) > 1
			for l:alternative in l:alternatives
				if index(l:expandedPatterns, l:alternative) == -1
					call add(l:expandedPatterns, l:alternative)
				endif
			endfor
		endif
	endfor

	call map(l:expandedPatterns, '"/" . escape(v:val, "/") . "/"')

	" Filter according to the argument lead. Allow to omit the frequent initial
	" \< atom in the lead.
	return filter(l:expandedPatterns, "v:val =~ '^\\%(\\\\<\\)\\?\\V' . " . string(escape(a:ArgLead, '\')))
endfunction


"- integrations ----------------------------------------------------------------

" Access the number of possible marks.
function! mark#GetGroupNum()
	return s:markNum
endfunction

" Access the number of defined marks.
function! s:GetUsedPatterns()
	return filter(copy(s:pattern), '! empty(v:val)')
endfunction
function! mark#GetCount()
	return len(s:GetUsedPatterns())
endfunction

" Access the current / passed index pattern.
function! mark#GetPattern( ... )
	if a:0
		return s:pattern[a:1]
	else
		return (s:lastSearch == -1 ? '' : s:pattern[s:lastSearch])
	endif
endfunction


"- initializations ------------------------------------------------------------

augroup Mark
	autocmd!
	autocmd BufWinEnter * call mark#UpdateMark()
	autocmd WinEnter * if ! exists('w:mwMatch') | call mark#UpdateMark() | endif
	autocmd TabEnter * call mark#UpdateScope()
augroup END

" Define global variables and initialize current scope.
function! mark#Init()
	let s:markNum = 0
	while hlexists('MarkWord' . (s:markNum + 1))
		let s:markNum += 1
	endwhile
	let s:pattern = repeat([''], s:markNum)
	let s:names = repeat([''], s:markNum)
	let s:cycle = 0
	let s:lastSearch = -1
	let s:enabled = 1
endfunction
function! mark#ReInit( newMarkNum )
	if a:newMarkNum < s:markNum " There are less marks than before.
		" Clear the additional highlight groups.
		for i in range(a:newMarkNum + 1, s:markNum)
			execute 'highlight clear MarkWord' . (i + 1)
		endfor

		" Truncate the mark patterns.
		let s:pattern = s:pattern[0 : (a:newMarkNum - 1)]
		let s:names = s:names[0 : (a:newMarkNum - 1)]

		" Correct any indices.
		let s:cycle = min([s:cycle, (a:newMarkNum - 1)])
		let s:lastSearch = (s:lastSearch < a:newMarkNum ? s:lastSearch : -1)
	elseif a:newMarkNum > s:markNum " There are more marks than before.
		" Expand the mark patterns.
		let s:pattern += repeat([''], (a:newMarkNum - s:markNum))
		let s:names += repeat([''], (a:newMarkNum - s:markNum))
	endif

	let s:markNum = a:newMarkNum
endfunction

call mark#Init()
if exists('g:mwDoDeferredLoad') && g:mwDoDeferredLoad
	unlet g:mwDoDeferredLoad
	call mark#LoadCommand(0)
else
	call mark#UpdateScope()
endif

" vim: ts=4 sts=0 sw=4 noet
autoload/mark/cascade.vim	[[[1
146
" mark/cascade.vim: Cascading search through all used mark groups.
"
" DEPENDENCIES:
"	- mark.vim autoload script
"	- ingo/err.vim autoload script
"	- ingo/msg.vim autoload script
"
" Copyright: (C) 2015-2018 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
"
" Version:     3.0.0

let [s:cascadingLocation, s:cascadingPosition, s:cascadingGroupIndex, s:cascadingIsBackward, s:cascadingStop] = [[], [], -1, -1, -1]
function! s:GetLocation()
	return [tabpagenr(), winnr(), bufnr('')]
endfunction
function! s:SetCascade()
	let s:cascadingLocation = s:GetLocation()
	let [l:markText, s:cascadingPosition, s:cascadingGroupIndex] = mark#CurrentMark()
endfunction
function! mark#cascade#Start( count, isStopBeforeCascade )
	" Try passed mark group, current mark, last search, first used mark group, in that order.

	let s:cascadingIsBackward = -1
	let s:cascadingVisitedBuffers = {}
	call s:SetCascade()
	if (! a:count && s:cascadingGroupIndex != -1) || (a:count && s:cascadingGroupIndex + 1 == a:count)
		" We're already on a mark [with its group corresponding to count]. Take
		" that as the start and stay there (as we don't know which direction
		" (forward / backward) to take).
		return 1
	endif

	" Search for next mark and start cascaded search there.
	if ! mark#SearchGroupMark(a:count, 1, 0, 1)
		if a:count
			return 0
		elseif ! mark#SearchGroupMark(mark#NextUsedGroupIndex(0, 0, -1, 1) + 1, 1, 0, 1)
			call mark#NoMarkErrorMessage()
			return 0
		endif
	endif
	call s:SetCascade()
	return 1
endfunction
function! mark#cascade#Next( count, isStopBeforeCascade, isBackward )
	if s:cascadingIsBackward == -1
		let s:cascadingIsBackward = a:isBackward
	endif

	if s:cascadingGroupIndex == -1
		call ingo#err#Set('No cascaded search defined')
		return 0
	elseif get(s:cascadingVisitedBuffers, bufnr(''), -1) == s:cascadingGroupIndex && s:cascadingLocation != s:GetLocation()
		" We've returned to a buffer that had previously already been searched
		" for the current mark. Instead of searching again, cascade to the next
		" group.
		let s:cascadingLocation = s:GetLocation()
		return s:Cascade(a:count, 0, a:isBackward)
	elseif s:cascadingStop != -1
		if s:cascadingLocation == s:GetLocation()
			" Within the same location: Switch to the next mark group.
			call s:SwitchToNextGroup(s:cascadingStop, a:isBackward)
		else
			" Allow to continue searching for the current mark group in other
			" locations.
			call s:ClearLocationAndPosition()
		endif
		let s:cascadingStop = -1
	elseif s:cascadingIsBackward != a:isBackward && s:cascadingLocation == s:GetLocation() && s:cascadingPosition == getpos('.')[1:2]
		" We've just cascaded to the next mark group, and now want back to the
		" previous one (by reversing search direction).
		return s:Cascade(a:count, a:isStopBeforeCascade, a:isBackward)
	endif

	let l:save_wrapscan = &wrapscan
	set wrapscan
	let l:save_view = winsaveview()
	try
		if ! mark#SearchGroupMark(s:cascadingGroupIndex + 1, a:count, a:isBackward, 1)
			return s:Cascade(a:count, a:isStopBeforeCascade, a:isBackward)
		endif
		if s:cascadingLocation == s:GetLocation()
			if s:cascadingPosition == getpos('.')[1:2]
				if s:cascadingIsBackward == a:isBackward
					" We're returned to the first match from that group. Undo
					" that last jump, and then cascade to the next one.
					call winrestview(l:save_view)
					return s:Cascade(a:count, a:isStopBeforeCascade, a:isBackward)
				else
					" Search direction has been reversed (from what it was when
					" the cascading position has been established). The current
					" match is now the last valid mark before cascading (in the
					" other direction). To recognize that, search for the next
					" match in the reversed direction, and set its position and
					" direction, then stay put here.
					let l:save_view = winsaveview()
						silent call mark#SearchGroupMark(s:cascadingGroupIndex + 1, 1, a:isBackward, 1)
						let s:cascadingPosition = getpos('.')[1:2]
						let s:cascadingIsBackward = a:isBackward
					call winrestview(l:save_view)
					return 1
				endif
			endif
		endif

		if empty(s:cascadingLocation) && empty(s:cascadingPosition)
			call s:SetCascade()
		endif

		return 1
	finally
		let &wrapscan = l:save_wrapscan
	endtry
endfunction
function! s:Cascade( count, isStopBeforeCascade, isBackward )
	let l:nextGroupIndex = mark#NextUsedGroupIndex(a:isBackward, 0, s:cascadingGroupIndex, 1)
	if l:nextGroupIndex == -1
		redraw  " Get rid of the previous mark search message.
		call ingo#err#Set(printf('Cascaded search ended with %s used group', (a:isBackward ? 'first' : 'last')))
		return 0
	endif

	let s:cascadingVisitedBuffers[bufnr('')] = s:cascadingGroupIndex
	if a:isStopBeforeCascade
		let s:cascadingStop = l:nextGroupIndex
		redraw  " Get rid of the previous mark search message.
		call ingo#msg#WarningMsg('Cascaded search reached last match of current group')
		return 1
	else
		call s:SwitchToNextGroup(l:nextGroupIndex, a:isBackward)
		return mark#cascade#Next(a:count, a:isStopBeforeCascade, a:isBackward)
	endif
endfunction
function! s:SwitchToNextGroup( nextGroupIndex, isBackward )
	let s:cascadingGroupIndex = a:nextGroupIndex
	let s:cascadingIsBackward = a:isBackward
	call s:ClearLocationAndPosition()
endfunction
function! s:ClearLocationAndPosition()
	let [s:cascadingLocation, s:cascadingPosition] = [[], []]   " Clear so that the next mark match will re-initialize them with the base match for the new mark group.
endfunction

" vim: ts=4 sts=0 sw=4 noet
autoload/mark/palettes.vim	[[[1
134
" mark/palettes.vim: Additional palettes for mark highlighting.
"
" DEPENDENCIES:
"
" Copyright: (C) 2012-2019 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
" Contributors: rockybalboa4
"
" Version:     3.1.0

function! mark#palettes#Extended()
	return [
		\   { 'ctermbg':'Blue',       'ctermfg':'Black', 'guibg':'#A1B7FF', 'guifg':'#001E80' },
		\   { 'ctermbg':'Magenta',    'ctermfg':'Black', 'guibg':'#FFA1C6', 'guifg':'#80005D' },
		\   { 'ctermbg':'Green',      'ctermfg':'Black', 'guibg':'#ACFFA1', 'guifg':'#0F8000' },
		\   { 'ctermbg':'Yellow',     'ctermfg':'Black', 'guibg':'#FFE8A1', 'guifg':'#806000' },
		\   { 'ctermbg':'DarkCyan',   'ctermfg':'Black', 'guibg':'#D2A1FF', 'guifg':'#420080' },
		\   { 'ctermbg':'Cyan',       'ctermfg':'Black', 'guibg':'#A1FEFF', 'guifg':'#007F80' },
		\   { 'ctermbg':'DarkBlue',   'ctermfg':'Black', 'guibg':'#A1DBFF', 'guifg':'#004E80' },
		\   { 'ctermbg':'DarkMagenta','ctermfg':'Black', 'guibg':'#A29CCF', 'guifg':'#120080' },
		\   { 'ctermbg':'DarkRed',    'ctermfg':'Black', 'guibg':'#F5A1FF', 'guifg':'#720080' },
		\   { 'ctermbg':'Brown',      'ctermfg':'Black', 'guibg':'#FFC4A1', 'guifg':'#803000' },
		\   { 'ctermbg':'DarkGreen',  'ctermfg':'Black', 'guibg':'#D0FFA1', 'guifg':'#3F8000' },
		\   { 'ctermbg':'Red',        'ctermfg':'Black', 'guibg':'#F3FFA1', 'guifg':'#6F8000' },
		\   { 'ctermbg':'White',      'ctermfg':'Gray',  'guibg':'#E3E3D2', 'guifg':'#999999' },
		\   { 'ctermbg':'LightGray',  'ctermfg':'White', 'guibg':'#D3D3C3', 'guifg':'#666666' },
		\   { 'ctermbg':'Gray',       'ctermfg':'Black', 'guibg':'#A3A396', 'guifg':'#222222' },
		\   { 'ctermbg':'Black',      'ctermfg':'White', 'guibg':'#53534C', 'guifg':'#DDDDDD' },
		\   { 'ctermbg':'Black',      'ctermfg':'Gray',  'guibg':'#131311', 'guifg':'#AAAAAA' },
		\   { 'ctermbg':'Blue',       'ctermfg':'White', 'guibg':'#0000FF', 'guifg':'#F0F0FF' },
		\   { 'ctermbg':'DarkRed',    'ctermfg':'White', 'guibg':'#FF0000', 'guifg':'#FFFFFF' },
		\   { 'ctermbg':'DarkGreen',  'ctermfg':'White', 'guibg':'#00FF00', 'guifg':'#355F35' },
		\   { 'ctermbg':'DarkYellow', 'ctermfg':'White', 'guibg':'#FFFF00', 'guifg':'#6F6F4C' },
		\]
endfunction

function! mark#palettes#Maximum()
		let l:palette = [
		\   { 'ctermbg':'Cyan',       'ctermfg':'Black', 'guibg':'#8CCBEA', 'guifg':'Black' },
		\   { 'ctermbg':'Green',      'ctermfg':'Black', 'guibg':'#A4E57E', 'guifg':'Black' },
		\   { 'ctermbg':'Yellow',     'ctermfg':'Black', 'guibg':'#FFDB72', 'guifg':'Black' },
		\   { 'ctermbg':'Red',        'ctermfg':'Black', 'guibg':'#FF7272', 'guifg':'Black' },
		\   { 'ctermbg':'Magenta',    'ctermfg':'Black', 'guibg':'#FFB3FF', 'guifg':'Black' },
		\   { 'ctermbg':'Blue',       'ctermfg':'Black', 'guibg':'#9999FF', 'guifg':'Black' },
		\]
		if has('gui_running') || &t_Co >= 88
		let l:palette += [
		\   { 'ctermfg':'White',      'ctermbg':'17',    'guifg':'White',   'guibg':'#00005f' },
		\   { 'ctermfg':'White',      'ctermbg':'22',    'guifg':'White',   'guibg':'#005f00' },
		\   { 'ctermfg':'White',      'ctermbg':'23',    'guifg':'White',   'guibg':'#005f5f' },
		\   { 'ctermfg':'White',      'ctermbg':'27',    'guifg':'White',   'guibg':'#005fff' },
		\   { 'ctermfg':'White',      'ctermbg':'29',    'guifg':'White',   'guibg':'#00875f' },
		\   { 'ctermfg':'White',      'ctermbg':'34',    'guifg':'White',   'guibg':'#00af00' },
		\   { 'ctermfg':'Black',      'ctermbg':'37',    'guifg':'Black',   'guibg':'#00afaf' },
		\   { 'ctermfg':'Black',      'ctermbg':'43',    'guifg':'Black',   'guibg':'#00d7af' },
		\   { 'ctermfg':'Black',      'ctermbg':'47',    'guifg':'Black',   'guibg':'#00ff5f' },
		\   { 'ctermfg':'White',      'ctermbg':'52',    'guifg':'White',   'guibg':'#5f0000' },
		\   { 'ctermfg':'White',      'ctermbg':'53',    'guifg':'White',   'guibg':'#5f005f' },
		\   { 'ctermfg':'White',      'ctermbg':'58',    'guifg':'White',   'guibg':'#5f5f00' },
		\   { 'ctermfg':'White',      'ctermbg':'60',    'guifg':'White',   'guibg':'#5f5f87' },
		\   { 'ctermfg':'White',      'ctermbg':'64',    'guifg':'White',   'guibg':'#5f8700' },
		\   { 'ctermfg':'White',      'ctermbg':'65',    'guifg':'White',   'guibg':'#5f875f' },
		\   { 'ctermfg':'Black',      'ctermbg':'66',    'guifg':'Black',   'guibg':'#5f8787' },
		\   { 'ctermfg':'Black',      'ctermbg':'72',    'guifg':'Black',   'guibg':'#5faf87' },
		\   { 'ctermfg':'Black',      'ctermbg':'74',    'guifg':'Black',   'guibg':'#5fafd7' },
		\   { 'ctermfg':'Black',      'ctermbg':'78',    'guifg':'Black',   'guibg':'#5fd787' },
		\   { 'ctermfg':'Black',      'ctermbg':'79',    'guifg':'Black',   'guibg':'#5fd7af' },
		\   { 'ctermfg':'Black',      'ctermbg':'85',    'guifg':'Black',   'guibg':'#5fffaf' },
		\]
		endif
		if has('gui_running') || &t_Co >= 256
		let l:palette += [
		\   { 'ctermfg':'White',      'ctermbg':'90',    'guifg':'White',   'guibg':'#870087' },
		\   { 'ctermfg':'White',      'ctermbg':'95',    'guifg':'White',   'guibg':'#875f5f' },
		\   { 'ctermfg':'White',      'ctermbg':'96',    'guifg':'White',   'guibg':'#875f87' },
		\   { 'ctermfg':'Black',      'ctermbg':'101',   'guifg':'Black',   'guibg':'#87875f' },
		\   { 'ctermfg':'Black',      'ctermbg':'107',   'guifg':'Black',   'guibg':'#87af5f' },
		\   { 'ctermfg':'Black',      'ctermbg':'114',   'guifg':'Black',   'guibg':'#87d787' },
		\   { 'ctermfg':'Black',      'ctermbg':'117',   'guifg':'Black',   'guibg':'#87d7ff' },
		\   { 'ctermfg':'Black',      'ctermbg':'118',   'guifg':'Black',   'guibg':'#87ff00' },
		\   { 'ctermfg':'Black',      'ctermbg':'122',   'guifg':'Black',   'guibg':'#87ffd7' },
		\   { 'ctermfg':'White',      'ctermbg':'130',   'guifg':'White',   'guibg':'#af5f00' },
		\   { 'ctermfg':'White',      'ctermbg':'131',   'guifg':'White',   'guibg':'#af5f5f' },
		\   { 'ctermfg':'Black',      'ctermbg':'133',   'guifg':'Black',   'guibg':'#af5faf' },
		\   { 'ctermfg':'Black',      'ctermbg':'138',   'guifg':'Black',   'guibg':'#af8787' },
		\   { 'ctermfg':'Black',      'ctermbg':'142',   'guifg':'Black',   'guibg':'#afaf00' },
		\   { 'ctermfg':'Black',      'ctermbg':'152',   'guifg':'Black',   'guibg':'#afd7d7' },
		\   { 'ctermfg':'White',      'ctermbg':'160',   'guifg':'White',   'guibg':'#d70000' },
		\   { 'ctermfg':'Black',      'ctermbg':'166',   'guifg':'Black',   'guibg':'#d75f00' },
		\   { 'ctermfg':'Black',      'ctermbg':'169',   'guifg':'Black',   'guibg':'#d75faf' },
		\   { 'ctermfg':'Black',      'ctermbg':'174',   'guifg':'Black',   'guibg':'#d78787' },
		\   { 'ctermfg':'Black',      'ctermbg':'175',   'guifg':'Black',   'guibg':'#d787af' },
		\   { 'ctermfg':'Black',      'ctermbg':'186',   'guifg':'Black',   'guibg':'#d7d787' },
		\   { 'ctermfg':'Black',      'ctermbg':'190',   'guifg':'Black',   'guibg':'#d7ff00' },
		\   { 'ctermfg':'White',      'ctermbg':'198',   'guifg':'White',   'guibg':'#ff0087' },
		\   { 'ctermfg':'Black',      'ctermbg':'202',   'guifg':'Black',   'guibg':'#ff5f00' },
		\   { 'ctermfg':'Black',      'ctermbg':'204',   'guifg':'Black',   'guibg':'#ff5f87' },
		\   { 'ctermfg':'Black',      'ctermbg':'209',   'guifg':'Black',   'guibg':'#ff875f' },
		\   { 'ctermfg':'Black',      'ctermbg':'212',   'guifg':'Black',   'guibg':'#ff87d7' },
		\   { 'ctermfg':'Black',      'ctermbg':'215',   'guifg':'Black',   'guibg':'#ffaf5f' },
		\   { 'ctermfg':'Black',      'ctermbg':'220',   'guifg':'Black',   'guibg':'#ffd700' },
		\   { 'ctermfg':'Black',      'ctermbg':'224',   'guifg':'Black',   'guibg':'#ffd7d7' },
		\   { 'ctermfg':'Black',      'ctermbg':'228',   'guifg':'Black',   'guibg':'#ffff87' },
		\]
		endif
		if has('gui_running')
		let l:palette += [
		\   {                                            'guifg':'Black',   'guibg':'#b3dcff' },
		\   {                                            'guifg':'Black',   'guibg':'#99cbd6' },
		\   {                                            'guifg':'Black',   'guibg':'#7afff0' },
		\   {                                            'guifg':'Black',   'guibg':'#a6ffd2' },
		\   {                                            'guifg':'Black',   'guibg':'#a2de9e' },
		\   {                                            'guifg':'Black',   'guibg':'#bcff80' },
		\   {                                            'guifg':'Black',   'guibg':'#e7ff8c' },
		\   {                                            'guifg':'Black',   'guibg':'#f2e19d' },
		\   {                                            'guifg':'Black',   'guibg':'#ffcc73' },
		\   {                                            'guifg':'Black',   'guibg':'#f7af83' },
		\   {                                            'guifg':'Black',   'guibg':'#fcb9b1' },
		\   {                                            'guifg':'Black',   'guibg':'#ff8092' },
		\   {                                            'guifg':'Black',   'guibg':'#ff73bb' },
		\   {                                            'guifg':'Black',   'guibg':'#fc97ef' },
		\   {                                            'guifg':'Black',   'guibg':'#c8a3d9' },
		\   {                                            'guifg':'Black',   'guibg':'#ac98eb' },
		\   {                                            'guifg':'Black',   'guibg':'#6a6feb' },
		\   {                                            'guifg':'Black',   'guibg':'#8caeff' },
		\   {                                            'guifg':'Black',   'guibg':'#70b9fa' },
		\]
		endif
	return l:palette
endfunction

" vim: ts=4 sts=0 sw=4 noet
plugin/mark.vim	[[[1
294
" Script Name: mark.vim
" Description: Highlight several words in different colors simultaneously.
"
" Copyright:   (C) 2008-2019 Ingo Karkat
"              (C) 2005-2008 Yuheng Xie
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:  Ingo Karkat <ingo@karkat.de>
" Orig Author: Yuheng Xie <elephant@linux.net.cn>
" Contributors:Luc Hermitte, Ingo Karkat
"
" Dependencies:
"	- Requires Vim 7.1 with "matchadd()", or Vim 7.2 or higher.
"	- mark.vim autoload script
"	- mark/palettes.vim autoload script for additional palettes
"	- mark/cascade.vim autoload script for cascading search
"	- ingo/err.vim autoload script
"	- ingo/msg.vim autoload script
"
" Version:     3.0.0

" Avoid installing twice or when in unsupported Vim version.
if exists('g:loaded_mark') || (v:version == 701 && ! exists('*matchadd')) || (v:version < 701)
	finish
endif
let g:loaded_mark = 1
let s:save_cpo = &cpo
set cpo&vim

"- configuration --------------------------------------------------------------

if ! exists('g:mwHistAdd')
	let g:mwHistAdd = '/@'
endif

if ! exists('g:mwAutoLoadMarks')
	let g:mwAutoLoadMarks = 0
endif

if ! exists('g:mwAutoSaveMarks')
	let g:mwAutoSaveMarks = 1
endif

if ! exists('g:mwDefaultHighlightingNum')
	let g:mwDefaultHighlightingNum = -1
endif
if ! exists('g:mwDefaultHighlightingPalette')
	let g:mwDefaultHighlightingPalette = 'original'
endif
if ! exists('g:mwPalettes')
	let g:mwPalettes = {
	\	'original': [
		\   { 'ctermbg':'Cyan',       'ctermfg':'Black', 'guibg':'#8CCBEA', 'guifg':'Black' },
		\   { 'ctermbg':'Green',      'ctermfg':'Black', 'guibg':'#A4E57E', 'guifg':'Black' },
		\   { 'ctermbg':'Yellow',     'ctermfg':'Black', 'guibg':'#FFDB72', 'guifg':'Black' },
		\   { 'ctermbg':'Red',        'ctermfg':'Black', 'guibg':'#FF7272', 'guifg':'Black' },
		\   { 'ctermbg':'Magenta',    'ctermfg':'Black', 'guibg':'#FFB3FF', 'guifg':'Black' },
		\   { 'ctermbg':'Blue',       'ctermfg':'Black', 'guibg':'#9999FF', 'guifg':'Black' },
		\],
	\	'extended': function('mark#palettes#Extended'),
	\	'maximum': function('mark#palettes#Maximum')
	\}
endif

if ! exists('g:mwDirectGroupJumpMappingNum')
	let g:mwDirectGroupJumpMappingNum = 9
endif

if ! exists('g:mwExclusionPredicates')
	let g:mwExclusionPredicates = (v:version == 702 && has('patch61') || v:version > 702 ? [function('mark#DefaultExclusionPredicate')] : [])
endif

if ! exists('g:mwMaxMatchPriority')
	" Default the highest match priority to -10, so that we do not override the
	" 'hlsearch' of 0, and still allow other custom highlightings to sneak in
	" between.
	let g:mwMaxMatchPriority = -10
endif


"- default highlightings ------------------------------------------------------

function! s:GetPalette()
	let l:palette = []
	if type(g:mwDefaultHighlightingPalette) == type([])
		" There are custom color definitions, not a named built-in palette.
		return g:mwDefaultHighlightingPalette
	endif
	if ! has_key(g:mwPalettes, g:mwDefaultHighlightingPalette)
		if ! empty(g:mwDefaultHighlightingPalette)
			call ingo#msg#WarningMsg('Mark: Unknown value for g:mwDefaultHighlightingPalette: ' . g:mwDefaultHighlightingPalette)
		endif

		return []
	endif

	if type(g:mwPalettes[g:mwDefaultHighlightingPalette]) == type([])
		return g:mwPalettes[g:mwDefaultHighlightingPalette]
	elseif type(g:mwPalettes[g:mwDefaultHighlightingPalette]) == type(function('tr'))
		return call(g:mwPalettes[g:mwDefaultHighlightingPalette], [])
	else
		call ingo#msg#ErrorMsg(printf('Mark: Invalid value type for g:mwPalettes[%s]', g:mwDefaultHighlightingPalette))
		return []
	endif
endfunction
function! s:DefineHighlightings( palette, isOverride )
	let l:command = (a:isOverride ? 'highlight' : 'highlight def')
	let l:highlightingNum = (g:mwDefaultHighlightingNum == -1 ? len(a:palette) : g:mwDefaultHighlightingNum)
	for i in range(1, l:highlightingNum)
		execute l:command 'MarkWord' . i join(map(items(a:palette[i - 1]), 'join(v:val, "=")'))
	endfor
	return l:highlightingNum
endfunction
call s:DefineHighlightings(s:GetPalette(), 0)
autocmd ColorScheme * call <SID>DefineHighlightings(<SID>GetPalette(), 0)

" Default highlighting for the special search type.
" You can override this by defining / linking the 'SearchSpecialSearchType'
" highlight group before this script is sourced.
highlight def link SearchSpecialSearchType MoreMsg



"- marks persistence ----------------------------------------------------------

if g:mwAutoLoadMarks
	" As the viminfo is only processed after sourcing of the runtime files, the
	" persistent global variables are not yet available here. Defer this until Vim
	" startup has completed.
	function! s:AutoLoadMarks()
		if g:mwAutoLoadMarks && exists('g:MARK_MARKS') && ! empty(ingo#plugin#persistence#Load('MARK_MARKS', []))
			if ! exists('g:MARK_ENABLED') || g:MARK_ENABLED
				" There are persistent marks and they haven't been disabled; we need to
				" show them right now.
				call mark#LoadCommand(0)
			else
				" Though there are persistent marks, they have been disabled. We avoid
				" sourcing the autoload script and its invasive autocmds right now;
				" maybe the marks are never turned on. We just inform the autoload
				" script that it should do this once it is sourced on-demand by a
				" mark mapping or command.
				let g:mwDoDeferredLoad = 1
			endif
		endif
	endfunction

	augroup MarkInitialization
		autocmd!
		" Note: Avoid triggering the autoload unless there actually are persistent
		" marks. For that, we need to check that g:MARK_MARKS doesn't contain the
		" empty list representation, and also :execute the :call.
		autocmd VimEnter * call <SID>AutoLoadMarks()
	augroup END
endif



"- commands -------------------------------------------------------------------

command! -bang -range=0 -nargs=? -complete=customlist,mark#Complete Mark if <bang>0 | silent call mark#DoMark(<count>, '') | endif | if ! mark#SetMark(<count>, <f-args>)[0] | echoerr ingo#err#Get() | endif
command! -bar MarkClear call mark#ClearAll()
command! -bar Marks call mark#List()

command! -bar -nargs=? -complete=customlist,mark#MarksVariablesComplete MarkLoad if ! mark#LoadCommand(1, <f-args>) | echoerr ingo#err#Get() | endif
command! -bar -nargs=? -complete=customlist,mark#MarksVariablesComplete MarkSave if ! mark#SaveCommand(<f-args>) | echoerr ingo#err#Get() | endif
command! -bar -register MarkYankDefinitions         if ! mark#YankDefinitions(0, <q-reg>) | echoerr ingo#err#Get()| endif
command! -bar -register MarkYankDefinitionsOneLiner if ! mark#YankDefinitions(1, <q-reg>) | echoerr ingo#err#Get()| endif
function! s:SetPalette( paletteName )
	if type(g:mwDefaultHighlightingPalette) == type([])
		" Convert the directly defined list to a palette named "default".
		let g:mwPalettes['default'] = g:mwDefaultHighlightingPalette
		unlet! g:mwDefaultHighlightingPalette   " Avoid E706.
	endif
	let g:mwDefaultHighlightingPalette = a:paletteName

	let l:palette = s:GetPalette()
	if empty(l:palette)
		return
	endif

	call mark#ReInit(s:DefineHighlightings(l:palette, 1))
	call mark#UpdateScope()
endfunction
function! s:MarkPaletteComplete( ArgLead, CmdLine, CursorPos )
	return sort(filter(keys(g:mwPalettes), 'v:val =~ ''\V\^'' . escape(a:ArgLead, "\\")'))
endfunction
command! -bar -nargs=1 -complete=customlist,<SID>MarkPaletteComplete MarkPalette call <SID>SetPalette(<q-args>)
command! -bar -bang -range=0 -nargs=? MarkName if ! mark#SetName(<bang>0, <count>, <q-args>) | echoerr ingo#err#Get() | endif



"- mappings -------------------------------------------------------------------

nnoremap <silent> <Plug>MarkSet               :<C-u>if ! mark#MarkCurrentWord(v:count)<Bar>execute "normal! \<lt>C-\>\<lt>C-n>\<lt>Esc>"<Bar>endif<CR>
vnoremap <silent> <Plug>MarkSet               :<C-u>if ! mark#DoMark(v:count, mark#GetVisualSelectionAsLiteralPattern())[0]<Bar>execute "normal! \<lt>C-\>\<lt>C-n>\<lt>Esc>"<Bar>endif<CR>
vnoremap <silent> <Plug>MarkIWhiteSet         :<C-u>if ! mark#DoMark(v:count, mark#GetVisualSelectionAsLiteralWhitespaceIndifferentPattern())[0]<Bar>execute "normal! \<lt>C-\>\<lt>C-n>\<lt>Esc>"<Bar>endif<CR>
nnoremap <silent> <Plug>MarkRegex             :<C-u>if ! mark#MarkRegex(v:count, '')<Bar>execute "normal! \<lt>C-\>\<lt>C-n>\<lt>Esc>"<Bar>echoerr ingo#err#Get()<Bar>endif<CR>
vnoremap <silent> <Plug>MarkRegex             :<C-u>if ! mark#MarkRegex(v:count, mark#GetVisualSelectionAsRegexp())<Bar>execute "normal! \<lt>C-\>\<lt>C-n>\<lt>Esc>"<Bar>echoerr ingo#err#Get()<Bar>endif<CR>
nnoremap <silent> <Plug>MarkClear             :<C-u>if ! mark#Clear(v:count)<Bar>execute "normal! \<lt>C-\>\<lt>C-n>\<lt>Esc>"<Bar>echoerr ingo#err#Get()<Bar>endif<CR>
nnoremap <silent> <Plug>MarkAllClear          :<C-u>call mark#ClearAll()<CR>
nnoremap <silent> <Plug>MarkConfirmAllClear   :<C-u>if confirm('Really delete all marks? This cannot be undone.', "&Yes\n&No") == 1<Bar>call mark#ClearAll()<Bar>endif<CR>
nnoremap <silent> <Plug>MarkToggle            :<C-u>call mark#Toggle()<CR>

nnoremap <silent> <Plug>MarkSearchCurrentNext :<C-u>if ! mark#SearchCurrentMark(0)<Bar>echoerr ingo#err#Get()<Bar>endif<CR>
nnoremap <silent> <Plug>MarkSearchCurrentPrev :<C-u>if ! mark#SearchCurrentMark(1)<Bar>echoerr ingo#err#Get()<Bar>endif<CR>
nnoremap <silent> <Plug>MarkSearchAnyNext     :<C-u>if ! mark#SearchAnyMark(0)<Bar>echoerr ingo#err#Get()<Bar>endif<CR>
nnoremap <silent> <Plug>MarkSearchAnyPrev     :<C-u>if ! mark#SearchAnyMark(1)<Bar>echoerr ingo#err#Get()<Bar>endif<CR>
" When typed, [*#nN] open the fold at the search result, but inside a mapping or
" :normal this must be done explicitly via 'zv'.
nnoremap <silent> <Plug>MarkSearchNext          :<C-u>if ! mark#SearchNext(0)<Bar>execute 'normal! *zv'<Bar>endif<CR>
nnoremap <silent> <Plug>MarkSearchPrev          :<C-u>if ! mark#SearchNext(1)<Bar>execute 'normal! #zv'<Bar>endif<CR>
nnoremap <silent> <Plug>MarkSearchOrCurNext     :<C-u>if ! mark#SearchNext(0,'mark#SearchCurrentMark')<Bar>execute 'normal! *zv'<Bar>endif<CR>
nnoremap <silent> <Plug>MarkSearchOrCurPrev     :<C-u>if ! mark#SearchNext(1,'mark#SearchCurrentMark')<Bar>execute 'normal! #zv'<Bar>endif<CR>
nnoremap <silent> <Plug>MarkSearchOrAnyNext     :<C-u>if ! mark#SearchNext(0,'mark#SearchAnyMark')<Bar>execute 'normal! *zv'<Bar>endif<CR>
nnoremap <silent> <Plug>MarkSearchOrAnyPrev     :<C-u>if ! mark#SearchNext(1,'mark#SearchAnyMark')<Bar>execute 'normal! #zv'<Bar>endif<CR>
nnoremap <silent> <Plug>MarkSearchGroupNext     :<C-u>if ! mark#SearchGroupMark(v:count, 1, 0, 1)<Bar>execute "normal! \<lt>C-\>\<lt>C-n>\<lt>Esc>"<Bar>echoerr ingo#err#Get()<Bar>endif<CR>
nnoremap <silent> <Plug>MarkSearchGroupPrev     :<C-u>if ! mark#SearchGroupMark(v:count, 1, 1, 1)<Bar>execute "normal! \<lt>C-\>\<lt>C-n>\<lt>Esc>"<Bar>echoerr ingo#err#Get()<Bar>endif<CR>
nnoremap <silent> <Plug>MarkSearchUsedGroupNext	:<C-u>if ! mark#SearchNextGroup(v:count1, 0)<Bar>execute "normal! \<lt>C-\>\<lt>C-n>\<lt>Esc>"<Bar>echoerr ingo#err#Get()<Bar>endif<CR>
nnoremap <silent> <Plug>MarkSearchUsedGroupPrev	:<C-u>if ! mark#SearchNextGroup(v:count1, 1)<Bar>execute "normal! \<lt>C-\>\<lt>C-n>\<lt>Esc>"<Bar>echoerr ingo#err#Get()<Bar>endif<CR>
nnoremap <silent> <Plug>MarkSearchCascadeStartWithStop  :<C-u>if ! mark#cascade#Start(v:count, 1)<Bar>execute "normal! \<lt>C-\>\<lt>C-n>\<lt>Esc>"   <Bar>echoerr ingo#err#Get()<Bar>endif<CR>
nnoremap <silent> <Plug>MarkSearchCascadeNextWithStop   :<C-u>if ! mark#cascade#Next(v:count1, 1, 0)<Bar>execute "normal! \<lt>C-\>\<lt>C-n>\<lt>Esc>"<Bar>echoerr ingo#err#Get()<Bar>endif<CR>
nnoremap <silent> <Plug>MarkSearchCascadePrevWithStop   :<C-u>if ! mark#cascade#Next(v:count1, 1, 1)<Bar>execute "normal! \<lt>C-\>\<lt>C-n>\<lt>Esc>"<Bar>echoerr ingo#err#Get()<Bar>endif<CR>
nnoremap <silent> <Plug>MarkSearchCascadeStartNoStop    :<C-u>if ! mark#cascade#Start(v:count, 0)<Bar>execute "normal! \<lt>C-\>\<lt>C-n>\<lt>Esc>"   <Bar>echoerr ingo#err#Get()<Bar>endif<CR>
nnoremap <silent> <Plug>MarkSearchCascadeNextNoStop     :<C-u>if ! mark#cascade#Next(v:count1, 0, 0)<Bar>execute "normal! \<lt>C-\>\<lt>C-n>\<lt>Esc>"<Bar>echoerr ingo#err#Get()<Bar>endif<CR>
nnoremap <silent> <Plug>MarkSearchCascadePrevNoStop     :<C-u>if ! mark#cascade#Next(v:count1, 0, 1)<Bar>execute "normal! \<lt>C-\>\<lt>C-n>\<lt>Esc>"<Bar>echoerr ingo#err#Get()<Bar>endif<CR>

function! s:MakeDirectGroupMappings( isDefineDefaultMappings )
	for l:cnt in range(1, g:mwDirectGroupJumpMappingNum)
		for [l:isBackward, l:direction, l:keyModifier] in [[0, 'Next', ''], [1, 'Prev', 'C-']]
			let l:plugMappingName = printf('<Plug>MarkSearchGroup%d%s', l:cnt, l:direction)
			execute printf('nnoremap <silent> %s :<C-u>if ! mark#SearchGroupMark(%d, v:count1, %d, 1)<Bar>execute "normal! \<lt>C-\>\<lt>C-n>\<lt>Esc>"<Bar>echoerr ingo#err#Get()<Bar>endif<CR>', l:plugMappingName, l:cnt, l:isBackward)
			if a:isDefineDefaultMappings && ! hasmapto(l:plugMappingName, 'n')
				execute printf('nmap <%sk%d> %s', l:keyModifier, l:cnt, l:plugMappingName)
			endif
		endfor
	endfor
endfunction
call s:MakeDirectGroupMappings(! exists('g:mw_no_mappings'))
delfunction s:MakeDirectGroupMappings

if exists('g:mw_no_mappings')
	finish
endif

if !hasmapto('<Plug>MarkSet', 'n')
	nmap <unique> <Leader>m <Plug>MarkSet
endif
if !hasmapto('<Plug>MarkSet', 'x')
	xmap <unique> <Leader>m <Plug>MarkSet
endif
" No default mapping for <Plug>MarkIWhiteSet.
if !hasmapto('<Plug>MarkRegex', 'n')
	nmap <unique> <Leader>r <Plug>MarkRegex
endif
if !hasmapto('<Plug>MarkRegex', 'x')
	xmap <unique> <Leader>r <Plug>MarkRegex
endif
if !hasmapto('<Plug>MarkClear', 'n')
	nmap <unique> <Leader>n <Plug>MarkClear
endif
" No default mapping for <Plug>MarkAllClear.
" No default mapping for <Plug>MarkConfirmAllClear.
" No default mapping for <Plug>MarkToggle.

if !hasmapto('<Plug>MarkSearchCurrentNext', 'n')
	nmap <unique> <Leader>* <Plug>MarkSearchCurrentNext
endif
if !hasmapto('<Plug>MarkSearchCurrentPrev', 'n')
	nmap <unique> <Leader># <Plug>MarkSearchCurrentPrev
endif
if !hasmapto('<Plug>MarkSearchAnyNext', 'n')
	nmap <unique> <Leader>/ <Plug>MarkSearchAnyNext
endif
if !hasmapto('<Plug>MarkSearchAnyPrev', 'n')
	nmap <unique> <Leader>? <Plug>MarkSearchAnyPrev
endif
if !hasmapto('<Plug>MarkSearchNext', 'n')
	nmap <unique> * <Plug>MarkSearchNext
endif
if !hasmapto('<Plug>MarkSearchPrev', 'n')
	nmap <unique> # <Plug>MarkSearchPrev
endif
" No default mapping for <Plug>MarkSearchOrCurNext
" No default mapping for <Plug>MarkSearchOrCurPrev
" No default mapping for <Plug>MarkSearchOrAnyNext
" No default mapping for <Plug>MarkSearchOrAnyPrev
" No default mapping for <Plug>MarkSearchGroupNext
" No default mapping for <Plug>MarkSearchGroupPrev
" No default mapping for <Plug>MarkSearchUsedGroupNext
" No default mapping for <Plug>MarkSearchUsedGroupPrev

let &cpo = s:save_cpo
unlet s:save_cpo
" vim: ts=4 sts=0 sw=4 noet
doc/mark.txt	[[[1
868
*mark.txt*              Highlight several words in different colors simultaneously.

			    MARK    by Ingo Karkat
		       (original version by Yuheng Xie)
								    *mark.vim*
description			|mark-description|
usage				|mark-usage|
installation			|mark-installation|
configuration			|mark-configuration|
integration			|mark-integration|
limitations			|mark-limitations|
known problems			|mark-known-problems|
todo				|mark-todo|
history				|mark-history|

==============================================================================
DESCRIPTION						    *mark-description*

This plugin adds mappings and a :Mark command to highlight several words in
different colors simultaneously, similar to the built-in 'hlsearch'
highlighting of search results and the * |star| command. For example, when you
are browsing a big program file, you could highlight multiple identifiers in
parallel. This will make it easier to trace the source code.

This is a continuation of vimscript #1238 by Yuheng Xie, who doesn't maintain
his original version anymore and recommends switching to this fork. This
plugin offers the following advantages over the original:
- Much faster, all colored words can now be highlighted, no more clashes with
  syntax highlighting (due to use of matchadd()).
- Many bug fixes.
- Jumps behave like the built-in search, including wrap and error messages.
- Like the built-in commands, jumps take an optional [count] to quickly skip
  over some marks.
- Marks can be persisted, and patterns can be added / subtracted from
  mark highlight groups.

SEE ALSO								     *

- SearchAlternatives.vim (vimscript #4146) provides mappings and commands to
  add and subtract alternative branches to the current search pattern.
- SearchHighlighting.vim (vimscript #4320) can change the semantics of the
  start command *, extends it to visual mode (like Mark) and has auto-search
  functionality which instantly highlights the word under the cursor when
  typing or moving around, like in many IDEs.

RELATED WORKS								     *

- MultipleSearch (vimscript #479) can highlight in a single window and in all
  buffers, but still relies on the :syntax highlighting method, which is
  slower and less reliable.
- http://vim.wikia.com/wiki/Highlight_multiple_words offers control over the
  color used by mapping the 1-9 keys on the numeric keypad, persistence, and
  highlights only a single window.
- highlight.vim (vimscript #1599) highlights lines or patterns of interest in
  different colors, using mappings that start with CTRL-H and work on cword.
- quickhl.vim (vimscript #3692) can also list the matches with colors and in
  addition offers on-the-fly highlighting of the current word (like many IDEs
  do).
- Highlight (http://www.drchip.org/astronaut/vim/index.html#HIGHLIGHT) has
  commands and mappings for highlighting and searching, uses matchadd(), but
  limits the scope of highlightings to the current window.
- TempKeyword (vimscript #4636) is a simple plugin that can matchadd() the
  word under the cursor with \0 - \9 mappings. (And clear with \c0 etc.)
- simple_highlighting (vimscript #4688) has commands and mappings to highlight
  8 different slots in all buffers.
- searchmatch (vimscript #4869) has commands and mappings for :[1,2,3]match,
  in the current window only.
- highlight-groups.vim (vimscript #5612) can do buffer-local as well as
  tab-scoped highlighting via :syntax, and has multiple groups whose
  highlighting is defined in an external CSV file.
- Syntax match (vimscript #5376) provides various (color-based) shortcut
  commands for :syntax match, and saves and restores those definitions, for
  text and log files.

==============================================================================
USAGE								  *mark-usage*

HIGHLIGHTING						   *mark-highlighting*
						     *<Leader>m* *v_<Leader>m*
<Leader>m		Mark the word under the cursor, similar to the |star|
			command. The next free highlight group is used.
			If already on a mark: Clear the mark, like
			|<Leader>n|.
{Visual}<Leader>m	Mark or unmark the visual selection.
{N}<Leader>m		With {N}, mark the word under the cursor with the
			named highlight group {N}. When that group is not
			empty, the word is added as an alternative match, so
			you can highlight multiple words with the same color.
			When the word is already contained in the list of
			alternatives, it is removed.

			When {N} is greater than the number of defined mark
			groups, a summary of marks is printed. Active mark
			groups are prefixed with "*" (or "M*" when there are
			M pattern alternatives), the default next group with
			">", the last used search with "/" (like |:Marks|
			does). Input the mark group, accept the default with
			<CR>, or abort with <Esc> or any other key.
			This way, when unsure about which number represents
			which color, just use 99<Leader>n and pick the color
			interactively!

{Visual}[N]<Leader>m	Ditto, based on the visual selection.

						     *<Leader>r* *v_<Leader>r*
[N]<Leader>r		Manually input a regular expression to mark.
{Visual}[N]<Leader>r	Ditto, based on the visual selection.

			In accordance with the built-in |star| command,
			all these mappings use 'ignorecase', but not
			'smartcase'.
								   *<Leader>n*
<Leader>n		Clear the mark under the cursor.
			If not on a mark: Disable all marks, similar to
			|:nohlsearch|.
			Note: Marks that span multiple lines are not detected,
			so the use of <Leader>n on such a mark will
			unintentionally disable all marks! Use
			{Visual}<Leader>r or :Mark {pattern} to clear
			multi-line marks (or pass [N] if you happen to know
			the group number).
{N}<Leader>n		Clear the marks represented by highlight group {N}.

								       *:Mark*
:{N}Mark		Clear the marks represented by highlight group {N}.
:[N]Mark[!] [/]{pattern}[/]
			Mark or unmark {pattern}. Unless [N] is given, the
			next free highlight group is used for marking.
			With [N], mark {pattern} with the named highlight
			group [N]. When that group is not empty, the word is
			added as an alternative match, so you can highlight
			multiple words with the same color, unless [!] is
			given; then, {pattern} overrides the existing mark.
			When the word is already contained in the list of
			alternatives, it is removed.
			For implementation reasons, {pattern} cannot use the
			'smartcase' setting, only 'ignorecase'.
			Without [/], only literal whole words are matched.
			|:search-args|
:Mark			Disable all marks, similar to |:nohlsearch|. Marks
			will automatically re-enable when a mark is added or
			removed, or a search for marks is performed.
								  *:MarkClear*
:MarkClear		Clear all marks. In contrast to disabling marks, the
			actual mark information is cleared, the next mark will
			use the first highlight group. This cannot be undone.
								   *:MarkName*
:[N]Mark[!] /{pattern}/ as [name]
			Mark or unmark {pattern}, and give it [name].
:{N}MarkName [name]
			Give [name] to mark group {N}.
:MarkName!		Clear names for all mark groups.


SEARCHING						      *mark-searching*
			    *<Leader>star* *<Leader>#* *<Leader>/* *<Leader>?*
[count]*         [count]#
[count]<Leader>* [count]<Leader>#
[count]<Leader>/ [count]<Leader>?
			Use these six keys to jump to the [count]'th next /
			previous occurrence of a mark.
			You could also use Vim's / and ? to search, since the
			mark patterns are (optionally, see configuration)
			added to the search history, too.

            Cursor over mark                    Cursor not over mark
 ---------------------------------------------------------------------------
  <Leader>* Jump to the next occurrence of      Jump to the next occurrence of
            current mark, and remember it       "last mark".
            as "last mark".

  <Leader>/ Jump to the next occurrence of      Same as left.
            ANY mark.

   *        If <Leader>* is the most recently   Do Vim's original * command.
            used, do a <Leader>*; otherwise
            (<Leader>/ is the most recently
            used), do a <Leader>/.

			Note: When the cursor is on a mark, the backwards
			search does not jump to the beginning of the current
			mark (like the built-in search), but to the previous
			mark. The entire mark text is treated as one entity.

			You can use Vim's |jumplist| to go back to previous
			mark matches and the position before a mark search.

						       *mark-keypad-searching*
If you work with multiple highlight groups and assign special meaning to them
(e.g. group 1 for notable functions, 2 for variables, 3 for includes), you can
use the 1-9 keys on the numerical keypad to jump to occurrences of a
particular highlight group. With the general * and # commands above, you'd
first need to locate a nearby occurrence of the desired highlight group if
it's not the last mark used.
							       *<k1>* *<C-k1>*
<k1> .. <k9>		Jump to the [count]'th next occurrence of the mark
			belonging to highlight group 1..9.
<C-k1> .. <C-k9>	Jump to the [count]'th previous occurrence of the mark
			belonging to highlight group 1..9.
			Note that these commands only work in GVIM or if your
			terminal sends different key codes; sadly, most still
			don't. The "Num Lock" indicator of your keyboard has
			to be ON; otherwise, the keypad is used for cursor
			movement. If the keypad doesn't work for you, you can
			still remap these mappings to alternatives; see below.
Alternatively, you can set up mappings to search in a next / previous used
group, see |mark-group-cycle|.

					       *mark-cascaded-group-searching*
[...]
After a stop, retriggering the cascaded search in the same buffer and window
moves to the next used group (you can jump inside the current buffer to choose
a different starting point first). If you instead switch to another window or
buffer, the current mark group continues to be searched (to allow you to
keep searching for the current group in other locations, until those are all
exhausted too).

MARK PERSISTENCE					    *mark-persistence*

The marks can be kept and restored across Vim sessions, using the |viminfo|
file. For this to work, the "!" flag must be part of the 'viminfo' setting: >
    set viminfo^=!  " Save and restore global variables.
<								   *:MarkLoad*
:MarkLoad 		Restore the marks from the previous Vim session. All
			current marks are discarded.
:MarkLoad {slot}	Restore the marks stored in the named {slot}. All
			current marks are discarded.
								   *:MarkSave*
:MarkSave		Save the currently defined marks (or clear the
			persisted marks if no marks are currently defined) for
			use in a future Vim session.
:MarkSave {slot}	Save the currently defined marks in the named {slot}.
			If {slot} is all UPPERCASE, the marks are persisted
			and can be |:MarkLoad|ed in a future Vim session (to
			persist without closing Vim, use |:wviminfo|; an
			already running Vim session can import marks via
			|:rviminfo| followed by |:MarkLoad|).
			If {slot} contains lowercase letters, you can just
			recall within the current session. When no marks are
			currently defined, the {slot} is cleared.

By default, automatic persistence is enabled (so you don't need to explicitly
|:MarkSave|), but you have to explicitly load the persisted marks in a new Vim
session via |:MarkLoad|, to avoid that you accidentally drag along outdated
highlightings from Vim session to session, and be surprised by the arbitrary
highlight groups and occasional appearance of forgotten marks. If you want
just that though and automatically restore any marks, set |g:mwAutoLoadMarks|.

You can also initialize some marks (even using particular highlight groups) to
static values, e.g. by including this in |vimrc|: >
    runtime plugin/mark.vim
    silent MarkClear
    silent 5Mark foo
    silent 6Mark /bar/
Or you can define custom commands that preset certain marks: >
    command -bar MyMarks exe '5Mark! foo' | exe '6Mark! /bar/'
Or a command that adds to the existing marks and then toggles them: >
    command -bar ToggleFooBarMarks exe 'Mark foo' | exe 'Mark /bar/'
The following commands help with setting these up:
			 *:MarkYankDefinitions* *:MarkYankDefinitionsOneLiner*
:MarkYankDefinitions [x]
			Place definitions for all current marks into the
			default register / [x], like this: >
			    1Mark! /\<foo\>/
			    2Mark! /bar/
			    9Mark! /quux/
:MarkYankDefinitionsOneLiner [x]
			Like |:MarkYankDefinitions|, but place all definitions
			into a single line, like this: >
			exe '1Mark! /\<foo\>/' | exe '2Mark! /bar/' | exe '9Mark! /quux/'
Alternatively, the mark#GetDefinitionCommands(isOneLiner) function can be used
to obtain a List of |:Mark| commands instead of using a register. With that,
you could for example build a custom alternative to |:MarkSave| that stores
Marks in separate files (using |writefile()|, read by |:source| or even
automatically via a local vimrc plugin) instead of the |viminfo| file.

MARK INFORMATION					    *mark-information*

Both |mark-highlighting| and |mark-searching| commands print information about
the mark and search pattern, e.g.
	mark-1/\<pattern\> ~
This is especially useful when you want to add or subtract patterns to a mark
highlight group via [N].

								      *:Marks*
:Marks			List all mark highlight groups and the search patterns
			defined for them.
			The group that will be used for the next |:Mark| or
			|<Leader>m| command (with [N]) is shown with a ">".
			The last mark used for a search (via <Leader>*) is
			shown with a "/".

MARK HIGHLIGHTING PALETTES					*mark-palette*

The plugin comes with three predefined palettes: original, extended, and
maximum. You can dynamically toggle between them, e.g. when you need more
marks or a different set of colors.
								*:MarkPalette*
:MarkPalette {palette}	Highlight existing and future marks with the colors
			defined in {palette}. If the new palette contains less
			mark groups than the current one, the additional marks
			are lost.
			You can use |:command-completion| for {palette}.

See |g:mwDefaultHighlightingPalette| for how to change the default palette,
and |mark-palette-define| for how to add your own custom palettes.

==============================================================================
INSTALLATION						   *mark-installation*

The code is hosted in a Git repo at
    https://github.com/inkarkat/vim-mark
You can use your favorite plugin manager, or "git clone" into a directory used
for Vim |packages|. Releases are on the "stable" branch, the latest unstable
development snapshot on "master".

This script is also packaged as a |vimball|. If you have the "gunzip"
decompressor in your PATH, simply edit the *.vmb.gz package in Vim; otherwise,
decompress the archive first, e.g. using WinZip. Inside Vim, install by
sourcing the vimball or via the |:UseVimball| command. >
    vim mark*.vmb.gz
    :so %
To uninstall, use the |:RmVimball| command.

DEPENDENCIES						   *mark-dependencies*

- Requires Vim 7.1 with |matchadd()|, or Vim 7.2 or higher.
- Requires the |ingo-library.vim| plugin (vimscript #4433), version 1.036 or
  higher.

==============================================================================
CONFIGURATION						  *mark-configuration*

For a permanent configuration, put the following commands into your |vimrc|.

					 *mark-colors* *mark-highlight-colors*
This plugin defines 6 mark groups:
    1: Cyan  2:Green  3:Yellow  4:Red  5:Magenta  6:Blue ~
Higher numbers always take precedence and are displayed above lower ones.

					      *g:mwDefaultHighlightingPalette*
Especially if you use GVIM, you can switch to a richer palette of up to 18
colors: >
    let g:mwDefaultHighlightingPalette = 'extended'
Or, if you have both good eyes and display, you can try a palette that defines
27, 58, or even 77 colors, depending on the number of available colors: >
    let g:mwDefaultHighlightingPalette = 'maximum'
Note: This only works for built-in palettes and those that you define prior to
running the plugin. If you extend the built-ins after plugin initialization
(|mark-palette-define|), use |:MarkPalette| instead.

If you like the additional colors, but don't need that many of them, restrict
their number via: >
	let g:mwDefaultHighlightingNum = 9
<
							*mark-colors-redefine*
If none of the default highlightings suits you, define your own colors in your
vimrc file (or anywhere before this plugin is sourced, but after any
|:colorscheme|), in the following form (where N = 1..): >
    highlight MarkWordN ctermbg=Cyan ctermfg=Black guibg=#8CCBEA guifg=Black
You can also use this form to redefine only some of the default highlightings.
If you want to avoid losing the highlightings on |:colorscheme| commands, you
need to re-apply your highlights on the |ColorScheme| event, similar to how
this plugin does. Or you define the palette not via :highlight commands, but
use the plugin's infrastructure: >
    let g:mwDefaultHighlightingPalette = [
    \	{ 'ctermbg':'Cyan', 'ctermfg':'Black', 'guibg':'#8CCBEA', 'guifg':'Black' },
    \	...
    \]
<							 *mark-palette-define*
If you want to switch multiple palettes during runtime, you need to define
them as proper palettes.
a) To add your palette to the existing ones, do this _after_ the default
   palette has been defined (e.g. in ~/.vim/after/plugin/mark.vim): >
    if ! exists('g:mwPalettes')	" (Optional) guard if the plugin isn't properly installed.
	finish
    endif

    let g:mwPalettes['mypalette'] = [
    \	{ 'ctermbg':'Cyan', 'ctermfg':'Black', 'guibg':'#8CCBEA', 'guifg':'Black' },
    \	...
    \]
    let g:mwPalettes['other'] = [ ... ]

    " Make it the default; you cannot use g:mwDefaultHighlightingPalette
    here, as the Mark plugin has already been initialized:
    MarkPalette mypalette
b) Alternatively, you can completely override all built-in palettes in your
   |vimrc|: >
    let g:mwPalettes = {
    \	'mypalette': [
    \	    { 'ctermbg':'Cyan', 'ctermfg':'Black', 'guibg':'#8CCBEA', 'guifg':'Black' },
    \	    ...
    \	]
    \}

    " Make it the default:
    let g:mwDefaultHighlightingPalette = 'mypalette'
<
The search type highlighting (in the search message) can be changed via: >
    highlight link SearchSpecialSearchType MoreMsg
<
								 *g:mwHistAdd*
By default, any marked words are also added to the search (/) and input (@)
history; if you don't want that, remove the corresponding symbols from: >
    let g:mwHistAdd = '/@'
<
							   *g:mwAutoLoadMarks*
To enable the automatic restore of marks from a previous Vim session: >
    let g:mwAutoLoadMarks = 1
<							   *g:mwAutoSaveMarks*
To turn off the automatic persistence of marks across Vim sessions: >
    let g:mwAutoSaveMarks = 0
You can still explicitly save marks via |:MarkSave|.

							      *g:mwIgnoreCase*
If you have set 'ignorecase', but want marks to be case-insensitive, you can
override the default behavior of using 'ignorecase' by setting: >
	let g:mwIgnoreCase = 0
<
						     *g:mwExclusionPredicates*
To exclude some tab pages, windows, or buffers / filetypes from showing mark
highlightings (you can still "blindly" navigate to marks in there with the
corresponding mappings), you can define a List of expressions or Funcrefs that
are evaluated in every window; if one returns 1, the window will not show
marks. >
    " Don't mark temp files, Python filetype, and scratch files as defined by
    " a custom function.
    let g:mwExclusionPredicates =
    \	['expand("%:p") =~# "/tmp"', '&filetype == "python", function('ExcludeScratchFiles')]
<					   *t:nomarks* *w:nomarks* *b:nomarks*
By default, tab pages / windows / buffers that have t:nomarks / w:nomarks /
b:nomarks with a true value are excluded. Therefore, to suppress mark
highlighting in a buffer, you can simply >
    :let b:nomarks = 1
If the predicate changes after a window has already been visible, you can
update the mark highlighting by either:
- switching tab pages back and forth
- toggling marks on / off (via <Plug>MarkToggle)
- :call mark#UpdateMark() (for current buffer)
- :call mark#UpdateScope() (for all windows in the current tab page)

							*g:mwMaxMatchPriority*
This plugin uses |matchadd()| for the highlightings. Each mark group has its
own priority, with higher group values having higher priority; i.e. going "on
top". The maximum priority (used for the last defined mark group) can be
changed via: >
    let g:mwMaxMatchPriority = -10
For example when another plugin or customization also uses matches and you
would like to change their relative priorities. The default is negative to
step back behind the default search highlighting.


							    *g:mw_no_mappings*
If you want no or only a few of the available mappings, you can completely
turn off the creation of the default mappings by defining: >
    :let g:mw_no_mappings = 1
This saves you from mapping dummy keys to all unwanted mapping targets.
							       *mark-mappings*
You can use different mappings by mapping to the <Plug>Mark... mappings (use
":map <Plug>Mark" to list them all) before this plugin is sourced.

There are no default mappings for toggling all marks and for the |:MarkClear|
command, but you can define some yourself: >
    nmap <Leader>M <Plug>MarkToggle
    nmap <Leader>N <Plug>MarkAllClear
As the latter is irreversible, there's also an alternative with an additional
confirmation: >
    nmap <Leader>N <Plug>MarkConfirmAllClear
<
To remove the default overriding of * and #, use: >
    nmap <Plug>IgnoreMarkSearchNext <Plug>MarkSearchNext
    nmap <Plug>IgnoreMarkSearchPrev <Plug>MarkSearchPrev
<
If you don't want the * and # mappings remember the last search type and
instead always search for the next occurrence of the current mark, with a
fallback to Vim's original * command, use: >
    nmap * <Plug>MarkSearchOrCurNext
    nmap # <Plug>MarkSearchOrCurPrev
<
The search mappings (*, #, etc.) interpret [count] as the number of
occurrences to jump over. If you don't want to use the separate
|mark-keypad-searching| mappings, and rather want [count] select the highlight
group to target (and you can live with jumps restricted to the very next
match), (re-)define to these mapping targets: >
    nmap * <Plug>MarkSearchGroupNext
    nmap # <Plug>MarkSearchGroupPrev
<
You can remap the direct group searches (by default via the keypad 1-9 keys): >
    nmap <Leader>1  <Plug>MarkSearchGroup1Next
    nmap <Leader>!  <Plug>MarkSearchGroup1Prev
<					       *g:mwDirectGroupJumpMappingNum*
If you need more / less groups, this can be configured via: >
    let g:mwDirectGroupJumpMappingNum = 20
Set to 0 to completely turn off the keypad mappings. This is easier than
remapping all <Plug>-mappings.
							    *mark-group-cycle*
As an alternative to the direct group searches, you can also define mappings
that search a next / previous used group: >
    nmap <Leader>+* <Plug>MarkSearchUsedGroupNext
    nmap <Leader>-* <Plug>MarkSearchUsedGroupPrev
<
						 *mark-whitespace-indifferent*
Some people like to create a mark based on the visual selection, like
|v_<Leader>m|, but have whitespace in the selection match any whitespace when
searching (searching for "hello world" will also find "hello<Tab>world" as
well as "hello" at the end of a line, with "world" at the start of the next
line). The Vim Tips Wiki describes such a setup for the built-in search at
    http://vim.wikia.com/wiki/Search_for_visually_selected_text
You can achieve the same with the Mark plugin through the <Plug>MarkIWhiteSet
mapping target: Using this, you can assign a new visual mode mapping <Leader>* >
    xmap <Leader>* <Plug>MarkIWhiteSet
or override the default |v_<Leader>m| mapping, in case you always want this
behavior: >
    vmap <Plug>IgnoreMarkSet <Plug>MarkSet
    xmap <Leader>m <Plug>MarkIWhiteSet
<
==============================================================================
INTEGRATION						    *mark-integration*

The following functions offer (read-only) access to the number of available
groups, number of defined marks and individual patterns:
- mark#GetGroupNum()
- mark#GetCount()
- mark#GetPattern([{index}])

==============================================================================
LIMITATIONS						    *mark-limitations*

- If the 'ignorecase' setting is changed, there will be discrepancies between
  the highlighted marks and subsequent jumps to marks.
- If {pattern} in a :Mark command contains atoms that change the semantics of
  the entire (|/\c|, |/\C|) regular expression, there may be discrepancies
  between the highlighted marks and subsequent jumps to marks.

KNOWN PROBLEMS						 *mark-known-problems*

TODO								   *mark-todo*

IDEAS								  *mark-ideas*

CONTRIBUTING						     *mark-contribute*

Report any bugs, send patches, or suggest features via the issue tracker at
https://github.com/inkarkat/vim-mark/issues or email (address below).

==============================================================================
HISTORY								*mark-history*

3.1.0	23-Mar-2019
- ENH: Handle magicness atoms (\V, \m) in regexps entered via <Leader>r or
  :Mark /{pattern}/.
- ENH: Choose a more correct insertion point with multiple alternatives for a
  mark by projecting the length of the existing and alternatives and the added
  pattern.
- BUG: Regression: <Leader>n without {N} and not on an existing mark prints
  error "Do not pass empty pattern to disable all marks".
- ENH: Allow to exclude certain tab pages, windows, or buffers / filetypes
  from showing mark highlightings via g:mwExclusionPredicates or (with the
  default predicate) t:nomarks / w:nomarks / b:nomarks flags.
- ENH: Allow to tweak the maximum match priority via g:mwMaxMatchPriority for
  better coexistence with other customizations that use :match / matchadd().
- ENH: Allow to disable all default mappings via a single g:mw_no_mappings
  configuration flag.
- ENH: Appended (strong) green and yellow highlightings to the extended
  palette.
- Refactoring: Move mark persistence implementation to ingo-library. No need
  to serialize into String type for viminfo beyond Vim 7.3.030.
- BUG: Avoid creating jump when updating marks. Need to use :keepjumps windo.
  Reported by epheien.
  *** You need to update to ingo-library (vimscript #4433) version 1.036! ***

3.0.0	18-Sep-2017
- CHG: Parse :Mark arguments as either /{pattern}/ or whole {word}. This
  better addresses the common use case of searching for whole words, and is
  consistent with built-in commands like :djump.
- ENH: Keep previous (last accessed) window on :windo.
- Consistently use :noautocmd during window iteration.
- ENH: Add :MarkYankDefinitions and :MarkYankDefinitionsOneLiner commands.
  These make it easier to persist marks for specific files (e.g. by putting
  the :Mark commands into a local vimrc) or occasions (by defining a custom
  command or mapping with these commands), and are an alternative to
  :MarkSave/Load.
- ENH: Add <Plug>MarkSearchUsedGroupNext and <Plug>MarkSearchUsedGroupPrev to
  search in a next / previous used group. Suggested by Louis Pan.
- ENH: Add <Plug>MarkSearchCascadeStartWithStop,
  <Plug>MarkSearchCascadeNextWithStop, <Plug>MarkSearchCascadeStartNoStop,
  <Plug>MarkSearchCascadeNextNoStop to search in cascading mark groups, i.e.
  first all matches for group 1, then all for group 2, and so on.
- CHG: Duplicate mark#GetNum() and mark#GetGroupNum(). Rename the former into
  mark#GetCount() and have it return the number of actually defined (i.e.
  non-empty) marks.
- ENH: Allow to give names to mark groups via :MarkName and new :Mark
  /{pattern}/ as {name} command syntax. Names will be shown during searching,
  and persisted together with the marks. This makes it easier to handle
  several marks and enforce custom semantics for particular groups.
- Properly abort on error by using :echoerr.
- Add dependency to ingo-library (vimscript #4433). *** You need to separately
  install ingo-library (vimscript #4433) version 1.020 (or higher)! ***

2.8.5	29-Oct-2014
- ENH: Add alternative <Plug>MarkConfirmAllClear optional command that works
  like <Plug>MarkAllClear, but with confirmation. Thanks to Marcelo Montu for
  suggesting this!

2.8.4	19-Jun-2014
- To avoid accepting an invalid regular expression (e.g. "\(blah") and then
  causing ugly errors on every mark update, check the patterns passed by the
  user for validity.
- CHG: The :Mark command doesn't query for a mark when the passed mark group
  doesn't exist (interactivity in Ex commands is unexpected). Instead, it
  returns an error.

2.8.3	23-May-2014
- The additional mapping described under :help mark-whitespace-indifferent got
  broken again by the refactoring of mark#DoMark() on 31-Jan-2013. Finally
  include this in the script as <Plug>MarkIWhiteSet and
  mark#GetVisualSelectionAsLiteralWhitespaceIndifferentPattern(). Thanks to
  Greg Klein for noticing and prodding me to include it.

2.8.2	16-Dec-2013
- BUG: :Mark cannot highlight patterns starting with a number. Use -range=0
  instead of -count. Thanks to Vladimir Marek for reporting this.

2.8.1	22-Nov-2013
- Allow to override the adding to existing marks via :[N]Mark! {pattern}.
- ENH: Implement command completion for :[N]Mark that offers existing mark
  patterns (from group [N] / all groups), both as one regular expression and
  individual alternatives. The leading \< can be omitted.

2.8.0	01-Jun-2013
- Also allow a [count] for <Leader>r to select (or query for) a mark group, as
  with <Leader>m.
- CHG: Also set the current mark to the used mark group when a mark was set
  via <Leader>r and :Mark so that it is easier to determine whether the
  entered pattern actually matches anywhere. Thanks to Xiaopan Zhang for
  notifying me about this problem.
- Add <Plug>MarkSearchGroupNext / <Plug>MarkSearchGroupPrev to enable
  searching for particular mark groups. Thanks to Xiaopan Zhang for the
  suggestion.
- Define default mappings for keys 1-9 on the numerical keypad to jump to a
  particular group (backwards with <C-kN>). Their definition is controlled by
  the new g:mwDirectGroupJumpMappingNum variable.
- ENH: Allow to store an arbitrary number of marks via named slots that can
  optionally be passed to :MarkLoad / :MarkSave. If the slot is all-uppercase,
  the marks will also be persisted across Vim invocations.

2.7.2	15-Oct-2012
- Issue an error message "No marks defined" instead of moving the cursor by
  one character when there are no marks (e.g. initially or after :MarkClear).
- Enable custom integrations via new mark#GetNum() and mark#GetPattern()
  functions.

2.7.1	14-Sep-2012
- Enable alternative * / # mappings that do not remember the last search type
  through new <Plug>MarkSearchOrCurNext, <Plug>MarkSearchOrCurPrev,
  <Plug>MarkSearchOrAnyNext, <Plug>MarkSearchOrAnyPrev mappings. Based on an
  inquiry from Kevin Huanpeng Du.

2.7.0	04-Jul-2012
- ENH: Implement :MarkPalette command to switch mark highlighting on-the-fly
  during runtime.
- Add "maximum" palette contributed by rockybalboa4.

2.6.5	24-Jun-2012
- Don't define the default <Leader>m and <Leader>r mappings in select mode,
  just visual mode. Thanks to rockybalboa4 for pointing this out.

2.6.4	23-Apr-2012
- Allow to override 'ignorecase' setting via g:mwIgnoreCase. Thanks to fanhe
  for the idea and sending a patch.

2.6.3	27-Mar-2012
- ENH: Allow choosing of palette and limiting of default mark highlight groups
  via g:mwDefaultHighlightingPalette and g:mwDefaultHighlightingNum.
- ENH: Offer an extended color palette in addition to the original 6-color one.
  Enable this via :let g:mwDefaultHighlightingPalette = "extended" in your
  vimrc.

2.6.2	26-Mar-2012
- ENH: When a [count] exceeding the number of available mark groups is given,
  a summary of marks is given and the user is asked to select a mark group.
  This allows to interactively choose a color via 99<Leader>m.
  If you use the |mark-whitespace-indifferent| mappings, *** PLEASE UPDATE THE
  vnoremap <Plug>MarkWhitespaceIndifferent DEFINITION ***
- ENH: Include count of alternative patterns in :Marks list.
- CHG: Use ">" for next mark and "/" for last search in :Marks.

2.6.1	23-Mar-2012
- ENH: Add :Marks command that prints all mark highlight groups and their
  search patterns, plus information about the current search mark, next mark
  group, and whether marks are disabled.
- ENH: Show which mark group a pattern was set / added / removed / cleared.
- FIX: When the cursor is positioned on the current mark, [N]<Leader>n /
  <Plug>MarkClear with [N] appended the pattern for the current mark (again
  and again) instead of clearing it. Must not pass current mark pattern when
  [N] is given.
- CHG: Show mark group number in same-mark search and rename search types from
  "any-mark", "same-mark", and "new-mark" to the shorter "mark-*", "mark-N",
  and "mark-N!", respectively.

2.6.0	22-Mar-2012
- ENH: Allow [count] for <Leader>m and :Mark to add / subtract match to / from
  highlight group [count], and use [count]<Leader>n to clear only highlight
  group [count]. This was also requested by Philipp Marek.
- FIX: :Mark and <Leader>n actually toggled marks back on when they were
  already off. Now, they stay off on multiple invocations. Use :call
  mark#Toggle() / <Plug>MarkToggle if you want toggling.

2.5.3	02-Mar-2012
- BUG: Version check mistakenly excluded Vim 7.1 versions that do have the
  matchadd() function. Thanks to Philipp Marek for sending a patch.

2.5.2	09-Nov-2011
Fixed various problems with wrap-around warnings:
- BUG: With a single match and 'wrapscan' set, a search error was issued.
- FIX: Backwards search with single match leads to wrong error message
  instead.
- FIX: Wrong logic for determining l:isWrapped lets wrap-around go undetected.

2.5.1	17-May-2011
- FIX: == comparison in s:DoMark() leads to wrong regexp (\A vs. \a) being
  cleared when 'ignorecase' is set. Use case-sensitive comparison ==# instead.
- Refine :MarkLoad messages
- Add whitespace-indifferent visual mark configuration example. Thanks to Greg
  Klein for the suggestion.

2.5.0	07-May-2011
- ENH: Add explicit mark persistence via :MarkLoad and :MarkSave commands and
  automatic persistence via the g:mwAutoLoadMarks and g:mwAutoSaveMarks
  configuration flags. (Request from Mun Johl, 16-Apr-2010)
- Expose toggling of mark display (keeping the mark patterns) via new
  <Plug>MarkToggle mapping. Offer :MarkClear command as a replacement for the
  old argumentless :Mark command, which now just disables, but not clears all
  marks.

2.4.4	18-Apr-2011
- BUG: Include trailing newline character in check for current mark, so that a
  mark that matches the entire line (e.g. created by V<Leader>m) can be
  cleared via <Leader>n. Thanks to ping for reporting this.
- FIX: On overlapping marks, mark#CurrentMark() returned the lowest, not the
  highest visible mark. So on overlapping marks, the one that was not visible
  at the cursor position was removed; very confusing! Use reverse iteration
  order.
- FIX: To avoid an arbitrary ordering of highlightings when the highlighting
  group names roll over, and to avoid order inconsistencies across different
  windows and tabs, we assign a different priority based on the highlighting
  group.

2.4.3	16-Apr-2011
- Avoid losing the mark highlightings on :syn on or :colorscheme commands.
  Thanks to Zhou YiChao for alerting me to this issue and suggesting a fix.
- Made the script more robust when somehow no highlightings have been defined
  or when the window-local reckoning of match IDs got lost. I had very
  occasionally encountered such script errors in the past.
- Made global housekeeping variables script-local, only g:mwHistAdd is used
  for configuration.

2.4.2	14-Jan-2011 (unreleased)
- FIX: Capturing the visual selection could still clobber the blockwise yank
  mode of the unnamed register.

2.4.1	13-Jan-2011
- FIX: Using a named register for capturing the visual selection on
  {Visual}<Leader>m and {Visual}<Leader>r clobbered the unnamed register. Now
  using the unnamed register.

2.4.0	13-Jul-2010
- ENH: The MarkSearch mappings (<Leader>[*#/?]) add the original cursor
  position to the jump list, like the built-in [/?*#nN] commands. This allows
  to use the regular jump commands for mark matches, like with regular search
  matches.

2.3.3	19-Feb-2010
- BUG: Clearing of an accidental zero-width match (e.g. via :Mark \zs) results
  in endless loop. Thanks to Andy Wokula for the patch.

2.3.2	17-Nov-2009
- BUG: Creation of literal pattern via '\V' in {Visual}<Leader>m mapping
  collided with individual escaping done in <Leader>m mapping so that an
  escaped '\*' would be interpreted as a multi item when both modes are used
  for marking. Thanks to Andy Wokula for the patch.

2.3.1	06-Jul-2009
- Now working correctly when 'smartcase' is set. All mappings and the :Mark
  command use 'ignorecase', but not 'smartcase'.

2.3.0	04-Jul-2009
- All jump commands now take an optional [count], so you can quickly skip over
  some marks, as with the built-in */# and n/N commands. For this, the entire
  core search algorithm has been rewritten. The script's logic has been
  simplified through the use of Vim 7 features like Lists.
- Now also printing a Vim-alike search error message when 'nowrapscan' is set.

2.2.0	02-Jul-2009
- Split off functions into autoload script.
- Initialization of global variables and autocommands is now done lazily on
  the first use, not during loading of the plugin. This reduces Vim startup
  time and footprint as long as the functionality isn't yet used.
- Split off documentation into separate help file. Now packaging as VimBall.


2.1.0	06-Jun-2009
- Replaced highlighting via :syntax with matchadd() / matchdelete(). This
  requires Vim 7.2 / 7.1 with patches. This method is faster, there are no
  more clashes with syntax highlighting (:match always has preference), and
  the background highlighting does not disappear under 'cursorline'.
- Using winrestcmd() to fix effects of :windo: By entering a window, its
  height is potentially increased from 0 to 1.
- Handling multiple tabs by calling s:UpdateScope() on the TabEnter event.

2.0.0	01-Jun-2009
- Now using Vim List for g:mwWord and thus requiring Vim 7. g:mwCycle is now
  zero-based, but the syntax groups "MarkWordx" are still one-based.
- Factored :syntax operations out of s:DoMark() and s:UpdateMark() so that
  they can all be done in a single :windo.
- Normal mode <Plug>MarkSet now has the same semantics as its visual mode
  cousin: If the cursor is on an existing mark, the mark is removed.
  Beforehand, one could only remove a visually selected mark via again
  selecting it. Now, one simply can invoke the mapping when on such a mark.

1.6.1	31-May-2009
Publication of improved version by Ingo Karkat.
- Now prepending search type ("any-mark", "same-mark", "new-mark") for better
  identification.
- Retired the algorithm in s:PrevWord in favor of simply using <cword>, which
  makes mark.vim work like the * command. At the end of a line, non-keyword
  characters may now be marked; the previous algorithm preferred any preceding
  word.
- BF: If 'iskeyword' contains characters that have a special meaning in a
  regexp (e.g. [.*]), these are now escaped properly.
- Highlighting can now actually be overridden in the vimrc (anywhere _before_
  sourcing this script) by using ':hi def'.
- Added missing setter for re-inclusion guard.

1.5.0	01-Sep-2008
Bug fixes and enhancements by Ingo Karkat.
- Added <Plug>MarkAllClear (without a default mapping), which clears all
  marks, even when the cursor is on a mark.
- Added <Plug>... mappings for hard-coded \*, \#, \/, \?, * and #, to allow
  re-mapping and disabling. Beforehand, there were some <Plug>... mappings
  and hard-coded ones; now, everything can be customized.
- BF: Using :autocmd without <bang> to avoid removing _all_ autocmds for the
  BufWinEnter event. (Using a custom :augroup would be even better.)
- BF: Explicitly defining s:current_mark_position; some execution paths left
  it undefined, causing errors.
- ENH: Make the match according to the 'ignorecase' setting, like the star
  command.
- ENH: The jumps to the next/prev occurrence now print 'search hit BOTTOM,
  continuing at TOP" and "Pattern not found:..." messages, like the * and n/N
  Vim search commands.
- ENH: Jumps now open folds if the occurrence is inside a closed fold, just
  like n/N do.

1.1.8-g	25-Apr-2008
Last version published by Yuheng Xie on vim.org.

1.1.2	22-Mar-2005
Initial version published by Yuheng Xie on vim.org.

==============================================================================
Copyright: (C) 2008-2019 Ingo Karkat
           (C) 2005-2008 Yuheng Xie
The VIM LICENSE applies to this plugin; see |copyright|.

Maintainer:	Ingo Karkat <ingo@karkat.de>
==============================================================================
 vim:tw=78:ts=8:ft=help:norl:
