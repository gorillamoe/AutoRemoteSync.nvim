if exists("g:loaded_AutoRemoteSync")
        finish
endif
let g:loaded_AutoRemoteSync = 1
let g:AutoRemoteSyncEnabled = 0
let g:AutoRemoteSyncOnBufwriteEnabled = 0

function! AutoRemoteSync#Enable()
        let g:AutoRemoteSyncEnabled = 1
        call AutoRemoteSync#RegisterAutoCommandOnBufWrite()
endfunction

function! AutoRemoteSync#Disable()
        let g:AutoRemoteSyncEnabled = 0
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
        if a:verbose == 1
                execute "!" . a:command
        else
                silent execute "!" . a:command
        endif
endfunction

function! AutoRemoteSync#RegisterAutoCommandOnBufWrite()
        if g:AutoRemoteSyncOnBufwriteEnabled == 0
                let g:AutoRemoteSyncOnBufwriteEnabled = 1
                autocmd! BufWritePost * :call AutoRemoteSync#Upload()
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
        if g:AutoRemoteSyncEnabled == 0 && a:0 == 0
                return
        endif
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
        let cmd = " scp -r -P " . cfg.remote.port . " "
                \. cfg.remote.user . "@" . cfg.remote.host . ":"
                \. cfg.remote.path . "/" . filepath
                \. " " . filepath . " "
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

