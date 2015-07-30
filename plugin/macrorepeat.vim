"# vim-macrorepeat
"
"Automatically loop macros until they reach the end of the area you've given. The area tries to adapt its size when your macros edit the buffer, ie. ´G´ means the last line of the buffer even if your macro adds or deletes lines.
"
"There's mappings available for normal mode operator and visual mode. *The plugin maps nothing by default* so you'll have to add a couple of lines to your vimrc.
"
"
"## Visual mode
"
"Add this to your vimrc
"
"´autocmd VimEnter * call MapMacroRepeatVisualMode("{MAPPING}")´,
"
"where {MAPPING} means the key combination you want to use for the plugin in visual mode. After pressing the mapping you need to press the register (´:h registers´) your macro is stored in, and it will execute inside the selected area.
"
"
"## Normal mode
"
"Add this to your vimrc
"
"´autocmd VimEnter * call MapMacroRepeatNormalMode("{MAPPING}")´,
"
"where {MAPPING} means the key combination you want to use for the plugin in normal mode. After pressing the mapping you need to press the register (´:h registers´) your macro is stored in and then give a motion (text objects work too) that defines the area where macro should be executed in.
"
"
"## Limitations
"
"**Important**: This plugin works best with simple macros. Don't expect perfect results with anything too fancy.
"
"List of limitations:
"
"* The macro should make its move to the next position as its last operation instead of the first. The plugin relies on this specific order to recognize macros that go out of range.
"* The macro should avoid editing text outside of the area it's applied on. There's 2 exceptions: Non-newline characters that aren't on any of the lines in the range can safely be edited. Lines can be added/removed too, but only as long as the macro the min/max line of the range don't get deleted.
"* If the macro contains any edits after the first motion they may "bleed" over the area. Try leaving some safe distance to the target position if your macro is multi-part.
"* If the macro skips lines/characters it might get executed one time too much before breaking off if you let it get near the edge of the buffer. Instead you can execute only up to a safe distance of the edge and finish manually.
"* There's some heuristics in place to stop the macro when it reaches the edge of the buffer - when the macro hits the first or last line it it's not allowed to change its direction or insert/delete more lines. This keeps simple macros from looping infinitely and doesn't really cause unwanted side effects, but it's still not foolproof. Keep your hands on ctrl-c just in case.
"* The macro should obviously approach its target position when looped. If it doesn't, you'll get an infinite loop - break it with ctrl-c!
"* If you want to use the macro with visual mode instead of motions, the macro has to advance downwards and/or rightwards.
"* The above goes for text objects too. Also, with text objects the cursor must not be at the last character of the object when starting. I'd recommend sticking with appropriate movements instead of text objects.
"
"
"## License
"
"Published under the MIT License.


" Stores the register that's used with the plugin's operator mapping.
let g:macrorepeat_current_reg = 'q'
" Stores the cursor position when the plugin's operator mapping is initiated.
let g:macrorepeat_cursor_pos = [0, 0, 0, 0]


" Map the macrorepeat operator to all registers in normal mode. {mapping}{register}{motion} executes the operation.
" Important: Has to be called after Vim has finished loading everything. Use ´autocmd VimEnter * ´ in front of the call in vimrc.
" @mapping: The desired mapping for macrorepeat operator.
fun! MapMacroRepeatNormalMode(mapping)
	let registers = "\"*+~-.:1234567890abcdefghijklmnopqrstuvwxyz"
	for reg in split(registers, '\zs')
		exe 'nnoremap <silent> ' . a:mapping . reg . ' :call macrorepeat#SetupMacroRepeatOp("' . reg . '")<cr>:set opfunc=MacroRepeatOp<cr>g@'
	endfor
endfun

" Map the macrorepeat function to all registers in visual mode. {mapping}{register} executes macrorepeat in visual mode.
" Important: Has to be called after Vim has finished loading everything. Use ´autocmd VimEnter * ´ in front of the call in vimrc.
" @mapping: The desired mapping for macrorepeat operator.
fun! MapMacroRepeatVisualMode(mapping)
	let registers = "\"*+~-.:1234567890abcdefghijklmnopqrstuvwxyz"
	for reg in split(registers, '\zs')
		exe 'xnoremap <silent> ' . a:mapping . reg . ' :<c-u>call macrorepeat#MacroRepeat("char", "<", ">", "' . reg . "\", getpos(\"'<\"))\<cr>"
	endfor
endfun

" A helper function used by the macrorepeat operator.
fun! MacroRepeatOp(type)
	call macrorepeat#MacroRepeat(a:type, '[', ']', g:macrorepeat_current_reg, g:macrorepeat_cursor_pos)
endfun

" Setup everything before executing the operator function.
fun! macrorepeat#SetupMacroRepeatOp(regname)
	let g:macrorepeat_current_reg = a:regname
	let g:macrorepeat_cursor_pos = getpos('.')
endfun
