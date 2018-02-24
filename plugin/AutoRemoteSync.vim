if exists("g:loaded_AutoRemoteSync")
        finish
endif
let g:loaded_AutoRemoteSync = 1

function! AutoRemoteSync#GetConfig()
        let cfgFilepath = getcwd() . "/" . AutoRemoteSync#GetConfigFilename()
        let jsonstr = AutoRemoteSync#ReadfileAsString(".AutoRemoteSync.json")
        let json = AutoRemoteSync#JSONParse(jsonstr)
        return json
endfunction

function! AutoRemoteSync#GetConfigFilename()
        return ".AutoRemoteSync.json"
endfunction

function! AutoRemoteSync#ExecExternalCommand(command, ...)
        let verbose = get(a:, 2, 0)
        if a:verbose == 1
                execute "!" . a:command
        else
                silent "!" . a:command
        endif
endfunction

function! AutoRemoteSync#RegisterAutoCommandOnBufWrite()
        autocmd! BufWritePost * AutoRemoteSync#Upload
endfunction

function! AutoRemoteSync#Upload(...)
        let buffername = bufname("%")
        let filepath = get(a:, 1, buffername)
        let cfg = AutoRemoteSync#GetConfig()
        let cmd = "scp -r -p " . cfg.remote.port
                \. " " . filepath . " "
                \. cfg.remote.user . "@" . cfg.remote.host . ":"
                \. cfg.remote.path . "/" . filepath
        call AutoRemoteSync#ExecExternalCommand(cmd)
endfunction

function! AutoRemoteSync#Download(...)
        let buffername = bufname("%")
        let filepath = get(a:, 1, buffername)
        let cfg = AutoRemoteSync#GetConfig()
        let cmd = " scp -r -p " . cfg.remote.port . " "
                \. cfg.remote.user . "@" . cfg.remote.host . ":"
                \. cfg.remote.path . "/" . filepath
                \. " " . filepath . " "
        call AutoRemoteSync#ExecExternalCommand(cmd)
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

