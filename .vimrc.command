"" vimrc_for_office
"" @umisama

" Grep command
command! -complete=file -nargs=+ Grep :call UmisamaSmartGrep(<f-args>)
function! UmisamaSmartGrep( ... )
	let l:word = ''
	let l:path = ''

	if a:0 >= 1
		let l:word = a:1
	endif

	if a:0 >= 2
		let l:path = a:2
	else
		if has('win32')
			let l:path = '.\\**\\*'
		else
			let l:path = '**/*'
		endif
	endif

	try
		execute 'tabnew'
		execute 'noautocmd lvimgrep' l:word l:path
		execute 'lopen'
	catch
		echo 'not found'
	endtry
endfunction

" LoadVimrc Command
command! -nargs=0 Loadrc :call UmisamaLoadVimRc()
function! UmisamaLoadVimRc()
	try
		if has('win32')
			execute 'source ~/_vimrc'
			execute 'source ~/_gvimrc'
		else
			execute 'source ~/.vimrc'
			execute 'source ~/.gvimrc'
		end
	catch
		echo 'miss'
	endtry
endfunction

" GoRun Command 
command! -nargs=* GoRun :call UmisamaGoRun(<f-args>)
function! UmisamaGoRun(...)
	let l:gorun		= 'go run '
	let l:arguments	= ''

	" create run args
	let l:whileindex	= 0
	while whileindex != a:0
		let l:arguments = l:arguments . ' ' . a:[l:whileindex + 1]
		let l:whileindex += 1
	endwhile

	execute '!'. l:gorun . expand('%') . l:arguments
endfunction
