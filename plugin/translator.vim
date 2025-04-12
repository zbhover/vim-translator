let s:current_path = expand('<sfile>:p:h')

let s:has_popup = has('textprop') && has('patch-8.2.0286')

if !exists('g:translator_outputype')
    if s:has_popup
        let g:translator_outputype = 'popup'
    else
        let g:translator_outputype = 'echo1'
    endif
endif

if g:translator_outputype == 'popup' && !s:has_popup
    echoerr '[Translator] not support popup, `g:translator_outputype` will be changed to `echo1`'
    let g:translator_outputype = 'echo1'
endif

if !exists('g:translator_channel')
    let g:translator_channel = 'kd'
endif

if g:translator_channel == 'baidu'
    let s:translator_file= s:current_path . '/'.g:translator_channel.'.py'
endif

function! s:popup_filter(winid, key)
    if a:key == 'z'
        call popup_close(a:winid)
    endif
endfunction

function! s:create_popup(words, result)
    call popup_clear()
    if len(a:result) > 2000
        let l:max_wdith = 132
    else
        let l:max_wdith = 66
    endif
    let l:options = {
                \'maxwidth': l:max_wdith,
                \'minwidth': 20,
                \'border': [1,1,1,1],
                \'padding': [0, 0, 0, 0],
                \'filter': function('s:popup_filter'),
                \'highlight': 'TranslatorHi',
                \'borderhighlight': ['TranslatorBorder'],
                \'zindex': 100,
                \'scrollbar': 1,
                \'close' : 'click',
                \}
    let l:result = []
    for x in split(a:result, "\n")
        call add(l:result, substitute(x, '\s', ' ', 'g'))
    endfor
    if len(a:words) < 132
        let l:winid = popup_create([a:words, '-----------------'.g:translator_channel.'--按`z`或者鼠标左键关闭弹窗--'] + l:result, l:options)
    else
        let l:winid = popup_create(l:result, l:options)
    endif
endfunction

function! TranslateCallback(chan, msg)
    let l:channel_id = matchstr(string(a:chan), '[0-9]\+')
    let l:msg = substitute(a:msg, '\r', '', 'g')
    if has_key(s:channel_map, l:channel_id)
        if g:translator_outputype != 'popup'
            call s:do_echo(s:channel_map[l:channel_id]['words'], l:msg)
        else
            call s:create_popup(s:channel_map[l:channel_id]['words'], l:msg)
        endif

        unlet s:channel_map[l:channel_id]
    endif
endfunction


let s:channel_map = {}

function! s:do_echo(words, res)
    let l:tmp = a:words.":\n".substitute(a:res, '\r', '', 'g')
    if g:translator_outputype=="echo1"
        silent! execute 'cexpr l:tmp'
        silent! execute 'copen'
    elseif g:translator_outputype=="echo2"
        windo if expand("%")=="dict-win" |q!|endif
        50vsp dict-win
        setlocal buftype=nofile bufhidden=hide noswapfile
        1s/^/\=l:tmp/
        1
    else
        echo substitute(l:tmp, '\n', ' ', 'g')
    endif
endfunction

function! s:translate(words)
    if !executable('python3')
        echoerr '[Translator] [Err]: python3 is not installed!'
        return
    endif
    if len(substitute(a:words, '\s', '', 'g')) == 0
        echo '输入为空'
        return
    endif
    let l:base64 = util#base64(a:words)
    let l:md5 = ''
    if g:translator_channel == "baidu"
        if IsChinese(a:words)
            let l:cmd = 'python3 '.s:current_path.'/baidu.py '.l:base64.' zh'
            "let l:cmd = 'python3 '.s:translator_file.' '.l:base64
        else
            let l:cmd = 'python3 '.s:current_path.'/baidu.py '.a:words
        endif
    elseif g:translator_channel =="kd"
        let l:cmd = 'kd '.a:words
    endif
    if !exists('*job_start') && ! has('gui_macvim')
        let l:job = job_start(l:cmd, {'out_cb': 'TranslateCallback', 'err_cb': 'TranslateCallback', 'mode': 'raw'})
        let l:channel_id = matchstr(string(job_getchannel(l:job)), '[0-9]\+')
        let s:channel_map[l:channel_id] = {'md5': l:md5, 'words': a:words}
    else
        let l:res = substitute(system(l:cmd), '\r', '', 'g')
        if g:translator_outputype != 'popup'
            call s:do_echo(a:words, l:res)
        else
            call s:create_popup(a:words, l:res)
        endif
        return l:res
    endif
endfunction

function! s:input_translate(arg)
    if len(a:arg) > 0
        call s:translate(a:arg)
    else
        let l:word = input('Enter the word: ')
        redraw!
        call s:translate(l:word)
    endif
endfunction
" 定义中文字符范围
let chinese_ranges = [
            \ [0x4e00, 0x9fa5],
            \ [0x3400, 0x4dbf],
            \ [0x20000, 0x2a6df],
            \ [0x2a700, 0x2b73f],
            \ [0x2b740, 0x2b81f],
            \ [0x2b820, 0x2ceaf],
            \ [0xf900, 0xfaff],
            \ [0x2f800, 0x2fa1f]
            \ ]

" 定义一个函数来判断字符是否为中文
function! IsChineseChar(code)
    for range in g:chinese_ranges
        if a:code >= range[0] && a:code <= range[1]
            return 1
        endif
    endfor
    return 0
endfunction

" 定义一个函数来判断字符串是否为中文
function! IsChinese(str)
    let chars = split(a:str, '\zs')
    for char in chars
        let code = char2nr(char)
        if !IsChineseChar(code)
            return 0
        endif
    endfor
    return 1
endfunction

function! GetWord()
    " 获取当前行内容
    let line = getline('.')
    " 获取光标所在列
    let col = getpos('.')[2]
    " 向左查找字符串起始位置
    let start = col - 1
    while start >= 1 && line[start - 1] =~ '[a-zA-Z]'
        let start = start - 1
    endwhile
    " 向右查找字符串结束位置
    let end = col - 1
    while end < len(line) && line[end] =~ '[a-zA-Z]'
        let end = end + 1
    endwhile
    " 提取字符串
    let word = line[start:end - 1]
    return word
endfunction

function! s:cursor_translate()
    call s:translate(GetWord())
endfunction

function! s:visual_translate()
    call s:translate(s:get_visual_select())
endfunction

function! s:get_visual_select()
    try
        let l:a_save = @a
        silent! normal! gv"ay
        if len(@a) > 0
            redraw!
        endif
        return @a
    finally
        let @a = l:a_save
    endtry
endfunction

command! -nargs=? Ti call <SID>input_translate(<q-args>)
command! Tc call <SID>cursor_translate()
command! -range Tv call <SID>visual_translate()
highlight TranslatorBorder ctermfg=37 guifg=#459d90 guibg=#202a31
highlight TranslatorHi term=bold guifg=#898f9e guibg=#202a31
