if exists("g:loaded_AutoRemoteSync")
        finish
endif
let g:loaded_AutoRemoteSync = 1

function! AutoRemoteSync#Enable()
        call AutoRemoteSync#RegisterAutoCommandOnBufWrite(1)
endfunction

function! AutoRemoteSync#Disable()
        call AutoRemoteSync#RegisterAutoCommandOnBufWrite(0)
endfunction

function! AutoRemoteSync#GetConfig()
        let cfgFilepath = getcwd() . "/" . AutoRemoteSync#GetConfigFilename()
        let jsonstr = AutoRemoteSync#ReadfileAsString(".AutoRemoteSync.json")
        let json = AutoRemoteSync#JSONParse(jsonstr)
        return json
endfunction

function! AutoRemoteSync#GetConfigFilename()
        return ".AutoRemoteSync.json"
endfunction

function! AutoRemoteSync#ExecExternalCommand(command, verbose)
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

function! AutoRemoteSync#RegisterAutoCommandOnBufWrite(enable)
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

function! AutoRemoteSync#GetBasename(...)
        let buffername = bufname("%")
        let filepath = get(a:, 1, buffername)
        return fnamemodify(filepath, ":t")
endfunction

function! AutoRemoteSync#GetBasedir(...)
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
        let basedir = AutoRemoteSync#GetBasedir()
        let filepath = get(a:, 1, buffername)
        let verbose = get(a:, 2, 0)
        let cfg = AutoRemoteSync#GetConfig()
        let cmd = "scp -r -P " . cfg.remote.port
                \. " " . filepath . " "
                \. cfg.remote.user . "@" . cfg.remote.host . ":"
                \. cfg.remote.path . "/" . basedir
        call AutoRemoteSync#ExecExternalCommand(cmd, verbose)
endfunction

function! AutoRemoteSync#Download(...)
        let buffername = bufname("%")
        let filepath = get(a:, 1, buffername)
        let verbose = get(a:, 2, 0)
        let cfg = AutoRemoteSync#GetConfig()
        let cmd = "scp -r -P " . cfg.remote.port . " "
                \. cfg.remote.user . "@" . cfg.remote.host . ":"
                \. cfg.remote.path . "/" . filepath
                \. " " . filepath . " "
        call AutoRemoteSync#ExecExternalCommand(cmd, verbose)
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
        let cfg = AutoRemoteSync#GetConfig()
        let cmd = "ssh -p " . cfg.remote.port . " "
                \. cfg.remote.user . "@" . cfg.remote.host . " \""
                \. "rm" . args . cfg.remote.path . "/" . filepath . "\""
        call AutoRemoteSync#ExecExternalCommand(cmd, verbose)
endfunction

function! AutoRemoteSync#ReadfileAsString(filepath)
        let lines = readfile(a:filepath)
        return join(lines, "\n")
endfunction

function! AutoRemoteSync#GetCurrentFile()
        return expand("%")
endfunction

function AutoRemoteSync#JSONParse(string)
        let [null, false, true] = ['', 0, 1]
        let stripped = substitute(a:string,'\C"\(\\.\|[^"\\]\)*"','','g')
        if stripped !~# "[^,:{}\\[\\]0-9.\\-+Eaeflnr-u \n\r\t]"
                try
                        return eval(substitute(a:string,"[\r\n]"," ",'g'))
                catch
                endtry
        endif
endfunction

function! AutoRemoteSync#JSONstringify(object)
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

