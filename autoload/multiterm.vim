let s:cpo_save = &cpo
set cpo&vim

if exists('s:loaded')
    finish
endif
let s:loaded = 1

let s:term_buf_active_count = 0
let s:winnr_before = 0

let s:term_buf_active_counts = []
for i in range(10)
    call add(s:term_buf_active_counts, 0)
endfor

if !exists(':terminal')
    echoerr 'Multiterm needs NeoVim or Vim with terminal support'
    finish
endif

if !has('nvim-0.4.0') && !has('patch-8.2.191')
    echoerr 'Multiterm needs at least 0.4.0 version of NeoVim or 8.2.191 version of Vim'
    finish
endif

function! s:get_term_tag(tag) abort
    if a:tag < 0
        echoerr 'Terminal tag cannot be negative'
        return 0
    endif
    if a:tag > 9
        echoerr 'Terminal tag cannot be greater than 9'
        return 0
    endif
    if exists('w:_multiterm_term_tag')
        if a:tag == 0
            return w:_multiterm_term_tag
        else
            if has('nvim')
                call nvim_win_close(s:['term_win_' . w:_multiterm_term_tag], v:false)
            else
                call popup_close(s:['term_win_' . w:_multiterm_term_tag])
            endif
            return a:tag
        endif
    else
        if a:tag == 0
            let term_tag = 0
            let term_buf_active_count = 0
            for i in range(1, 10)
                if exists('s:term_buf_' . i) && bufexists(s:['term_buf_' . i]) && s:term_buf_active_counts[i] > term_buf_active_count
                    let term_tag = i
                    let term_buf_active_count = s:term_buf_active_counts[i]
                endif
            endfor
            return term_tag == 0 ? 1 : term_tag
        else
            return a:tag
        endif
    endif
endfunction

if has('nvim')
    function! multiterm#toggle_float_term(tag, no_close, tmode, ...) abort
        let term_tag = s:get_term_tag(a:tag)
        if !term_tag
            return
        endif
        let height = eval(g:multiterm_opts.height)
        let width = eval(g:multiterm_opts.width)
        let row = eval(g:multiterm_opts.row)
        let col = eval(g:multiterm_opts.col)
        let opts = {'relative': 'editor', 'row': row, 'col': col, 'width': width, 'height': height, 'style': 'minimal'}
        if !exists('s:term_win_' . term_tag) || !nvim_win_is_valid(s:['term_win_' . term_tag])
            let s:winnr_before = winnr()
            let border_buf = s:create_float_border(opts)
            if !exists('s:term_buf_' . term_tag) || !bufexists(s:['term_buf_' . term_tag])
                let s:['term_buf_' . term_tag] = nvim_create_buf(v:false, v:false)
                let need_termopen = 1
            else
                let need_termopen = 0
            endif
            let s:['term_win_' . term_tag] = nvim_open_win(s:['term_buf_' . term_tag], v:true, opts)
            call setwinvar(s:['term_win_' . term_tag], '&winhighlight', 'NormalFloat:' . g:multiterm_opts.term_hl)
            call setwinvar(s:['term_win_' . term_tag], '_multiterm_term_tag', term_tag)
            exe 'augroup MultitermBuffer' . term_tag
            exe 'autocmd!'
            exe 'au WinLeave * ++once if bufexists(' . border_buf . ') | bwipeout! ' . border_buf . ' | endif'
            exe 'au WinLeave * ++once if win_id2tabwin(' . s:['term_win_' . term_tag] . ') != [0, 0] | call nvim_win_close(' . s:['term_win_' . term_tag] . ', v:true) | let s:term_tmode_' . term_tag . ' = 0 | endif'
            exe 'au BufWipeout <buffer> if bufexists(' . border_buf . ') | bwipeout! ' . border_buf . ' | endif'
            exe 'au BufWipeout <buffer> if win_id2tabwin(' . s:['term_win_' . term_tag] . ') != [0, 0] | call nvim_win_close(' . s:['term_win_' . term_tag] . ', v:true) | endif'
            exe 'augroup END'
            if need_termopen
                call termopen(a:0 == 0 || empty(a:1) ? &shell : a:1, {'on_exit': function(a:no_close ? 'multiterm#on_term_exit_no_close' : 'multiterm#on_term_exit')})
            elseif get(s:, 'term_tmode_' . term_tag, 0) && mode() !=# 't'
                startinsert
            endif
            let s:term_buf_active_count += 1
            let s:term_buf_active_counts[term_tag] = s:term_buf_active_count
        else
            call nvim_win_close(s:['term_win_' . term_tag], v:true)
            let s:['term_tmode_' . term_tag] = a:tmode
            exe s:winnr_before . 'wincmd w'
        endif
    endfunction

    function! s:create_float_border(opts) abort
        let opts = copy(a:opts)
        let opts.row -= 1
        let opts.col -= 1
        let opts.height += 2
        let opts.width += 2
        let bcs = g:multiterm_opts.border_chars
        let top = bcs[4] . repeat(bcs[0], opts.width - 2) . bcs[5]
        let mid = bcs[3] . repeat(' ', opts.width - 2) . bcs[1]
        let bot = bcs[7] . repeat(bcs[2], opts.width - 2) . bcs[6]
        let lines = [top] + repeat([mid], opts.height - 2) + [bot]
        let border_buf = nvim_create_buf(v:false, v:true)
        call nvim_buf_set_lines(border_buf, 0, -1, v:true, lines)
        let win = nvim_open_win(border_buf, v:true, opts)
        call setbufvar(border_buf, '&bufhidden', 'wipe')
        call setwinvar(win, '&winhighlight', 'NormalFloat:' . g:multiterm_opts.border_hl)
        return border_buf
    endfunction

    function! multiterm#on_term_exit(job_id, code, event) abort dict
        if a:code == 0
            bwipeout!
        endif
    endfunction

    function! multiterm#on_term_exit_no_close(job_id, code, event) abort dict
        return
    endfunction
else
    function! multiterm#toggle_float_term(tag, no_close, tmode, ...) abort
        let term_tag = s:get_term_tag(a:tag)
        if !term_tag
            return
        endif
        if !exists('s:term_buf_' . term_tag) || !bufexists(s:['term_buf_' . term_tag])
            let s:['term_buf_' . term_tag] = term_start(a:0 == 0 || empty(a:1) ? &shell : a:1, extend({
                        \ 'hidden': 1,
                        \ 'norestore': 1,
                        \ 'term_kill': 'kill',
                        \ 'term_highlight': g:multiterm_opts.term_hl
                        \ }, a:no_close ? {} : {'term_finish': 'close'}))
            " exe 'autocmd BufWipeout <buffer=' . s:term_buf . '> ++once call term_sendkeys(' . s:term_buf . ', "exit\<cr>")'
            call setbufvar(s:['term_buf_' . term_tag], '&buflisted', 0)
        endif
        if !exists('s:term_win_' . term_tag) || empty(popup_getoptions(s:['term_win_' . term_tag]))
            let s:winnr_before = winnr()
            let height = eval(g:multiterm_opts.height)
            let width = eval(g:multiterm_opts.width)
            let row = eval(g:multiterm_opts.row)
            let col = eval(g:multiterm_opts.col)
            let s:['term_win_'. term_tag] = popup_create(s:['term_buf_' . term_tag], {
                        \ 'maxheight': height,
                        \ 'minheight': height,
                        \ 'maxwidth': width,
                        \ 'minwidth': width,
                        \ 'line': row,
                        \ 'col': col,
                        \ 'zindex': 50,
                        \ 'border': [1],
                        \ 'borderhighlight': [g:multiterm_opts.border_hl],
                        \ 'borderchars': g:multiterm_opts.border_chars
                        \ })
            call setwinvar(s:['term_win_' . term_tag], '_multiterm_term_tag', term_tag)
            if get(s:, 'term_tmode_' . term_tag, 0) && mode() !=# 't'
                normal! i
            endif
            let s:term_buf_active_count += 1
            let s:term_buf_active_counts[term_tag] = s:term_buf_active_count
        else 
            call popup_close(s:['term_win_' . term_tag])
            let s:['term_tmode_' . term_tag] = a:tmode
            exe s:winnr_before . 'wincmd w'
        endif
    endfunction
endif

let &cpo = s:cpo_save
unlet s:cpo_save
