" @type: see :h map-operator
" @start: the left/upper boundary of the target area
" @end: the right/lower boundary of the target area
" @regname: the register whose macro gets executed
function! macrorepeat#MacroRepeat(type, start, end, regname, cursor_pos)
	let start_f = "'".a:start
	let end_f = "'".a:end

	" vim moves the cursor to the start of the area. stop that from happening if the cursor was at the end.
	" this means that using macros with text objects is only possible if they advance down/right. however if the cursor is at the right edge of a text object, the macro will INSTEAD have to go up/left.
	" in general it's better to favor NOT USING text objects and instead using motions that fit the macro's direction
	if a:cursor_pos == getpos(end_f)
		call setpos('.', a:cursor_pos)
	endif

	" upper line of the area
	let start_line = line(start_f)
	" lower line of the area
	let end_line = line(end_f)
	" leftmost allowed column of the start line
	let start_col = col(start_f)
	" rightmost allowed column of the end line
	let end_col = col(end_f)
	" include the whole target line (but not the whole start line!) for linewise motions
	if a:type == 'line'
		if start_line < line('.')
			let start_col = 0
		else
			" empty lines have len 0, but the min cursor column is 1
			let end_col = max([1, len(getline(end_line))])
		endif
	endif

	" true if the macro's target position is on the end line and after the cursor. this means the macro moves towards the end of the buffer and we should look out for jams after the last line is reached.
	let targeted_end = end_line == line('$') && (a:cursor_pos[1] < end_line || a:cursor_pos[2] < end_col)
	" same as above for first line
	let targeted_start = start_line == 1 && a:cursor_pos[1] == end_line && a:cursor_pos[2] == end_col

	let user_a_mark = getpos("'a")
	let user_b_mark = getpos("'b")

	" set the "a" mark at the first line of the area and "b" at the last
	call setpos("'a", [0, start_line, start_col, 0])
	call setpos("'b", [0, end_line, end_col, 0])

	let line = line('.')
	let col = col('.')
	while 1
		if line < start_line || line > end_line
			break
		elseif line == start_line && col < start_col
			break
		elseif line == end_line && col > end_col
			break
		endif

		let end_line_len = len(getline(end_line))
		let lines = line('$')

		exe 'normal! @' . a:regname

		let line_new = line('.')
		let col_new = col('.')

		let lines_new = line('$')

		" there's some extra checks that can be made if the cursor reaches the last line of the buffer after targeting it and stays there after executing the macro.
		if targeted_end && line == lines && line_new == lines_new
			" inserting or deleting lines while staying at the last line - this could go on forever. even though the cursor might move columns forward and eventually stop, you still usually wouldn't want your macro to keep going after reaching the last line of the range if it inserts/removes lines.
			" doesn't help if the same amount of lines get deleted and added
			if lines_new != lines
				break
			" no effective movement rightwards - since the max line of the range shouldn't be edited after end_col we can be sure the macro isn't advancing towards its target position here. preventing this scenario stops infinite loops and backtracking caused by the end of the buffer.
			elseif (col_new - col) - (len(getline(end_line)) - end_line_len) <= 0
				break
			endif
		" all of the above for the start of the buffer
		elseif targeted_start && line == 1 && line_new == 1
			" same reasoning here, if the macro adds/removes lines you probably want it to stop at the top of the buffer
			if lines_new != lines
				break
			elseif col_new >= col
				break
			endif
		endif

		" if the start line is still there we can update its position with the mark (marks have their lines updated). otherwise we'll have to assume it hasn't moved (edits between the cursor and the start don't move it). as long as a macro doesn't remove the mark and then later edit lines before it the start line will stay correct.
		let a_pos_new = getpos("'a")
		if a_pos_new != [0, 0, 0, 0]
			let start_line = a_pos_new[1]
		endif

		" if the end line is still there we can update its position with the mark. otherwise we'll have to assume it HAS moved (all changes before the end edge move the end line) and so update it with the line count change.
		let b_pos_new = getpos("'b")
		if b_pos_new != [0, 0, 0, 0]
			let end_line = b_pos_new[1]
		" this isn't ideal because edits that happen after the range will throw the count off and there's no way of knowing where the end line used to be. assume lines don't get changed after the range.
		else
			let end_line += lines_new - lines
		endif

		" outside of lines vim doesn't offer any good way of finding out the changes in byte counts before and after a position (line2byte isn't enough to do that). we'll just have to assume all those changes happen within the area.

		" goes wrong if text after end_col gets changed on the same line
		let end_col += len(getline(end_line)) - end_line_len
		" empty lines have len 0, but the min cursor column is 1
		let end_col = max([1, end_col])

		let line = line_new
		let col = col_new
	endwhile

	call setpos("'a", user_a_mark)
	call setpos("'b", user_b_mark)
endfunction
