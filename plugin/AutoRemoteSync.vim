if exists("g:loaded_AutoRemoteSync")
        finish
endif
let g:loaded_AutoRemoteSync = 1

function! AutoRemoteSync#Enable()
        call s:RegisterAutoCommandOnBufWrite(1)
endfunction

function! AutoRemoteSync#Disable()
        call s:RegisterAutoCommandOnBufWrite(0)
endfunction

function! s:GetConfig()
        let cfgFilepath = getcwd() . "/" . s:GetConfigFilename()
        let jsonstr = s:ReadfileAsString(".AutoRemoteSync.json")
        let json = s:JSONParse(jsonstr)
        return json
endfunction

function! s:GetConfigFilename()
        return ".AutoRemoteSync.json"
endfunction

function! s:ExecExternalCommand(command, verbose)
        if has("nvim") == 1
                call jobstart(["bash", "-c", a:command])
        elseif v:version >= 800
                call job_start("bash -c " . a:command)
        else
                if a:verbose == 1
                        execute "!" . a:command
                else
                        silent execute "!" . a:command
                endif
        endif
endfunction

function! s:RegisterAutoCommandOnBufWrite(enable)
        if a:enable == 1
                augroup AutoRemoteSyncOnBufWriteAugroup
                        autocmd!
                        autocmd! BufWritePost * :call AutoRemoteSync#Upload()
                augroup END
        else
                augroup AutoRemoteSyncOnBufWriteAugroup
                        autocmd!
                augroup END
        endif
endfunction

function! s:GetBasename(...)
        let buffername = bufname("%")
        let filepath = get(a:, 1, buffername)
        return fnamemodify(filepath, ":t")
endfunction

function! s:GetBasedir(...)
        let buffername = bufname("%")
        let filepath = get(a:, 1, buffername)
        let basedir = fnamemodify(filepath, ":h")
        if basedir == "."
                return ""
        else
                return basedir
endfunction

function! AutoRemoteSync#Upload(...)
        let buffername = bufname("%")
        let basedir = s:GetBasedir()
        let filepath = get(a:, 1, buffername)
        let verbose = get(a:, 2, 0)
        let cfg = s:GetConfig()
        let cmd = "scp -r -P " . cfg.remote.port
                \. " " . filepath . " "
                \. cfg.remote.user . "@" . cfg.remote.host . ":"
                \. cfg.remote.path . "/" . basedir
        call s:ExecExternalCommand(cmd, verbose)
endfunction

function! AutoRemoteSync#Download(...)
        let buffername = bufname("%")
        let filepath = get(a:, 1, buffername)
        let verbose = get(a:, 2, 0)
        let cfg = s:GetConfig()
        let cmd = "scp -r -P " . cfg.remote.port . " "
                \. cfg.remote.user . "@" . cfg.remote.host . ":"
                \. cfg.remote.path . "/" . filepath
                \. " " . filepath . " "
        call s:ExecExternalCommand(cmd, verbose)
endfunction

function! AutoRemoteSync#Delete(...)
        let buffername = bufname("%")
        let filepath = get(a:, 1, buffername)
        let verbose = get(a:, 2, 0)
        let recursive = get(a:, 3, 0)
        if recursive == 1
                let args = ""
        else
                let args = " -rf "
        endif
        let cfg = s:GetConfig()
        let cmd = "ssh -p " . cfg.remote.port . " "
                \. cfg.remote.user . "@" . cfg.remote.host . " \""
                \. "rm" . args . cfg.remote.path . "/" . filepath . "\""
        call s:ExecExternalCommand(cmd, verbose)
endfunction

function! s:ReadfileAsString(filepath)
        let lines = readfile(a:filepath)
        return join(lines, "\n")
endfunction

function! s:GetCurrentFile()
        return expand("%")
endfunction

function s:JSONParse(string)
        let [null, false, true] = ['', 0, 1]
        let stripped = substitute(a:string,'\C"\(\\.\|[^"\\]\)*"','','g')
        if stripped !~# "[^,:{}\\[\\]0-9.\\-+Eaeflnr-u \n\r\t]"
                try
                        return eval(substitute(a:string,"[\r\n]"," ",'g'))
                catch
                endtry
        endif
endfunction

function! s:JSONstringify(object)
        if type(a:object) == type('')
                return '"' . substitute(a:object, "[\001-\031\"\\\\]", '\=printf("\\u%04x", char2nr(submatch(0)))', 'g') . '"'
        elseif type(a:object) == type([])
                return '['.join(map(copy(a:object), 's:json_generate(v:val)'),', ').']'
        elseif type(a:object) == type({})
                let pairs = []
                for key in keys(a:object)
                        call add(pairs, s:json_generate(key) . ': ' . s:json_generate(a:object[key]))
                endfor
                return '{' . join(pairs, ', ') . '}'
        else
                return string(a:object)
        endif
endfunction

