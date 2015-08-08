" The string representations of a couple of <Plug> mappings.
" the mapping that calls the macro
let s:call_mapping = ''
" the mapping to a function that stops the cursor when it goes out of range
let s:post_mapping = ''

" Valid register names.
let s:regnames = "\"*+~-.:1234567890abcdefghijklmnopqrstuvwxyz"

" Values needed to initiate the loop.
" the register of the macro
let s:reg = 'q'
" the type of the motion used with the operator (see :h opfunc)
let s:type = 'char'
" the left mark limiting the area
let s:start_mark = '['
" the right mark limiting the area
let s:end_mark = ']'
" the position of the cursor when initiating the loop
let s:cursor_pos = [0, 0, 0, 0]

" Values needed by each iteration of the loop.
" the top line of the original range
let s:start_line = 0
" the bottom line of the original range
let s:end_line = 0
" the leftmost column of the top line
let s:start_col = 0
" the rightmost column of the bottom line
let s:end_col = 0
" the number of lines in the buffer before executing the macro
let s:lines = 0
" the length of the bottom line before executing the macro
let s:end_line_len = 0

" The user's original data.
let s:user_a_mark = [0, 0, 0, 0]
let s:user_b_mark = [0, 0, 0, 0]
let s:user_reg_content = ''
let s:user_redraw = 0


" Convert a '<Plug>' mapping into its internal string representation. This allows us to inject commands into the macro without having to map physical keys or worrying about user remaps. Credit for the idea to Ingo Karkat's RangeMacro plugin
fun! s:Plug2Str(mapping)
	let str = string(a:mapping)
	let str = strpart(str, 1, len(str)-2)
	return str
endfun

fun! s:Contains(str, char)
	for c in split(a:str, '\zs')
		if c ==# a:char
			return 1
		endif
	endfor
	return 0
endfun

fun! s:GetRegName()
	let input = getchar()
	if input == 27 || input == 3
		return
	endif
	let char = nr2char(input)
	if !s:Contains(s:regnames, char)
		echo 'macrorepeat: Invalid register name.'
		return ''
	endif
	return char
endfun

" Mapping for normal mode
fun! macrorepeat#MacroRepeatNormal()
	let s:reg = s:GetRegName()
	if s:reg ==# ''
		return
	endif
	let s:cursor_pos = getpos('.')

	set opfunc=macrorepeat#MacroRepeatOp
	call feedkeys("g@", 'n')
endfun

" Mapping for visual mode
fun! macrorepeat#MacroRepeatVisual()
	let s:reg = s:GetRegName()
	if s:reg ==# ''
		return
	endif
	let s:cursor_pos = getpos("'<")
	let s:start_mark = '<'
	let s:end_mark = '>'
	let s:type = 'char'
	call macrorepeat#Init()
endfun

" A helper function used by the macrorepeat operator.
fun! macrorepeat#MacroRepeatOp(type)
	let s:start_mark = '['
	let s:end_mark = ']'
	let s:type = a:type
	call macrorepeat#Init()
endfun

" Start looping the macro that's been set.
fun! macrorepeat#Init()
	let s:user_redraw = &lazyredraw
	set lazyredraw

	if s:post_mapping ==# ''
		let s:post_mapping = s:Plug2Str("\<Plug>(MacroRepeatPost)")
	endif

	" Create a new mapping to call the macro from the current register.
	exe 'nnoremap <Plug>(MacroRepeatCall) @' . s:reg

	let s:call_mapping = s:Plug2Str("\<Plug>(MacroRepeatCall)")

	let s:user_reg_content = getreg(s:reg)
	" Inject a call to the checker function and a recursive macro call to the current register.
	call setreg(s:reg, s:user_reg_content . s:post_mapping . s:call_mapping)

	let start_f = "'".s:start_mark
	let end_f = "'".s:end_mark

	" vim moves the cursor to the start of the area. stop that from happening if the cursor was at the end.
	" this means that using macros with text objects is only possible if they advance down/right. however if the cursor is at the right edge of a text object, the macro will INSTEAD have to go up/left.
	" in general it's better to favor NOT USING text objects and instead using motions that fit the macro's direction
	if s:cursor_pos == getpos(end_f)
		call setpos('.', s:cursor_pos)
	endif

	let s:start_line = line(start_f)
	let s:end_line = line(end_f)
	let s:start_col = col(start_f)
	let s:end_col = col(end_f)
	" include the whole target line (but not the whole start line!) for linewise motions
	if s:type == 'line'
		if s:start_line < line('.')
			let s:start_col = 0
		else
			" empty lines have len 0, but the min cursor column is 1
			let s:end_col = max([1, len(getline(s:end_line))])
		endif
	endif

	" initialize these to correct values before starting recursion
	let s:end_line_len = len(getline(s:end_line))
	let s:lines = line('$')

	let s:user_a_mark = getpos("'a")
	let s:user_b_mark = getpos("'b")

	" set the "a" mark at the first line of the area and "b" at the last
	call setpos("'a", [0, s:start_line, s:start_col, 0])
	call setpos("'b", [0, s:end_line, s:end_col, 0])

	" the macro has to be called with feedkeys; vim won't do anything with a 'norm' command here for some reason.
	call feedkeys(s:call_mapping . "\<Plug>(MacroRepeatCleanup)", 't')
endfun

" Restore user data after the macro loop is finished.
fun! macrorepeat#MacroRepeatCleanup()
	call setreg(s:reg, s:user_reg_content)

	call setpos("'a", s:user_a_mark)
	call setpos("'b", s:user_b_mark)

	let &lazyredraw = s:user_redraw
endfun

" After each iteration of the macro, check if it is still inside its updated range. If it's not, break the recursion.
fun! macrorepeat#MacroRepeatPost()
	let lines_new = line('$')

	" if the start line is still there we can update its position with the mark (marks have their lines updated). otherwise we'll have to assume it hasn't moved (edits between the cursor and the start don't move it). as long as a macro doesn't remove the mark and then later edit lines before it the start line will stay correct.
	let a_pos_new = getpos("'a")
	if a_pos_new != [0, 0, 0, 0]
		let s:start_line = a_pos_new[1]
	endif

	" if the end line is still there we can update its position with the mark. otherwise we'll have to assume it HAS moved (all changes before the end edge move the end line) and so update it with the line count change.
	let b_pos_new = getpos("'b")
	if b_pos_new != [0, 0, 0, 0]
		let s:end_line = b_pos_new[1]
	" this isn't ideal because edits that happen after the range will throw the count off and there's no way of knowing where the end line used to be. assume lines don't get changed after the range.
	else
		let s:end_line += lines_new - s:lines
	endif

	" outside of lines vim doesn't offer any good way of finding out the changes in byte counts before and after a position (line2byte isn't enough to do that). we'll just have to assume all those changes happen within the area.

	" goes wrong if text after end_col gets changed on the same line
	let s:end_col += len(getline(s:end_line)) - s:end_line_len
	" empty lines have len 0, but the min cursor column is 1
	let s:end_col = max([1, s:end_col])

	let s:end_line_len = len(getline(s:end_line))
	let s:lines = line('$')

	let line = line('.')
	let col = col('.')

	if line < s:start_line || line > s:end_line
		call s:EndRecursion()
	elseif line == s:start_line && col < s:start_col
		call s:EndRecursion()
	elseif line == s:end_line && col > s:end_col
		call s:EndRecursion()
	endif
endfun

" End recursing the macro by clearing its register before the next iteration begins.
fun! s:EndRecursion()
	call setreg(s:reg, '')
endfun
