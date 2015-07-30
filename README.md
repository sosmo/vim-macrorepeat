# vim-macrorepeat

Automatically loop macros until they reach the end of the area you've given. The area tries to adapt its size when your macros edit the buffer, ie. `G` means the last line of the buffer even if your macro adds or deletes lines.

![Sample pic](/../resources/1.gif?raw=true "example animation")

There's mappings available for normal mode operator and visual mode. *The plugin maps nothing by default* so you'll have to add a couple of lines to your vimrc.


## Visual mode

Add this to your vimrc

`autocmd VimEnter * call MapMacroRepeatVisualMode("{MAPPING}")`,

where `{MAPPING}` means the key combination you want to use for the plugin in visual mode. After pressing the mapping you need to press the register (`:h registers`) your macro is stored in, and it will execute inside the selected area.


## Normal mode

Add this to your vimrc

`autocmd VimEnter * call MapMacroRepeatNormalMode("{MAPPING}")`,

where `{MAPPING}` means the key combination you want to use for the plugin in normal mode. After pressing the mapping you need to press the register (see `:h registers`) your macro is stored in and then give a motion (text objects work too) that defines the area where macro should be executed in.


## Limitations

**Important**: This plugin works best with simple macros. Don't expect perfect results with anything too fancy.

List of limitations:

* The macro should make its move to the next position as its last operation instead of the first. The plugin relies on this specific order to recognize macros that go out of range.
* The macro should avoid editing text outside of the area it's applied on. There's 2 exceptions: Non-newline characters that aren't on any of the lines in the range can safely be edited. Lines can be added/removed too, but only as long as the min/max line of the range don't get deleted.
* If the macro contains any edits after the first motion they may "bleed" over the area. Try leaving some safe distance to the target position if your macro is multi-part.
* There's some heuristics in place to stop the macro when it reaches the edge of the buffer - when the macro hits the first or last line it it's not allowed to change its direction or insert/delete more lines. This keeps simple macros from looping infinitely and doesn't really cause unwanted side effects, but it's still not foolproof. Keep your hands on ctrl-c just in case.
* If the macro skips lines/characters it might get executed one time too much before breaking off if you let it get near the edge of the buffer. Instead you can execute only up to a safe distance of the edge and finish manually.
* The macro should obviously approach its target position when looped. If it doesn't, you'll get an infinite loop - break it with ctrl-c!
* If you want to use the macro with visual mode instead of motions, the macro has to advance downwards and/or rightwards.
* The above goes for text objects too. Also, with text objects the cursor must not be at the last character of the object when starting. I'd recommend sticking with appropriate movements instead of text objects.


## Related plugins

[RangeMacro](http://www.vim.org/scripts/script.php?script_id=3271 "RangeMacro") by Ingo Karkat does mostly the same thing, though it doesn't try to adjust the area when text is edited.


## License

Published under the MIT License.
