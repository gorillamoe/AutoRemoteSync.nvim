if exists("g:loaded_AutoRemoteSync")
        finish
endif
let g:loaded_AutoRemoteSync = 1

let s:isVerbose = 0
let s:type = "rsync"
let s:configFilename = ".AutoRemoteSync.json"

function! AutoRemoteSync#Enable()
        let cfg = s:GetConfig()
        if has_key(cfg, 'verbose') && cfg.verbose == 1
                let s:isVerbose = 1
        else
                let s:isVerbose = 0
        endif
        if has_key(cfg, 'type')
                let s:type = cfg.type
	endif
        call s:RegisterAutoCommandOnBufWrite(1)
endfunction

function! AutoRemoteSync#Disable()
        call s:RegisterAutoCommandOnBufWrite(0)
endfunction

function! AutoRemoteSync#Verbose(enable)
        if a:enable == 1
                let s:isVerbose = 1
        else
                let s:isVerbose = 0
        endif
endfunction

function! AutoRemoteSync#Upload(...)
        let buffername = bufname("%")
        let basedir = s:GetBasedir()
        let filepath = get(a:, 1, buffername)
        let cfg = s:GetConfig()
	if s:type == "rsync"
		let cmd = "rsync -av --no-o --no-g " . filepath . " "
			\. cfg.remote.user . "@" . cfg.remote.host . ":"
			\. cfg.remote.path . "/" . basedir
	elseif s:type == "sftp"
		let cmd = "sftp " . cfg.remote.user . "@" . cfg.remote.host . ":"
			\. cfg.remote.path . "/" . basedir . "<<< $'put " . filepath . "'"
	else
		let cmd = "echo no valid type specified"
	endif
        call s:ExecExternalCommand(cmd)
endfunction

function! AutoRemoteSync#Download(...)
        let buffername = bufname("%")
        let filepath = get(a:, 1, buffername)
        let cfg = s:GetConfig()
	if s:type == "rsync"
		let cmd = "rsync -av --no-o --no-g "
			\. cfg.remote.user . "@" . cfg.remote.host . ":"
			\. cfg.remote.path . "/" . filepath
			\. " " . filepath . " "
	elseif s:type == "sftp"
		let cmd = "sftp " . cfg.remote.user . "@" . cfg.remote.host . ":"
			\. cfg.remote.path . "/" . filepath . " " . filepath
	else
		let cmd = "echo no valid type specified"
	endif
        call s:ExecExternalCommand(cmd)
endfunction

function! AutoRemoteSync#Delete(...)
        let buffername = bufname("%")
        let filepath = get(a:, 1, buffername)
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
        call s:ExecExternalCommand(cmd)
endfunction

function! s:OnJobEventHandler(job_id, data, event) dict
        if a:event == 'stdout'
                let str = self.shell.' stdout: '.join(a:data)
        elseif a:event == 'stderr'
                let str = self.shell.' stderr: '.join(a:data)
        else
                let str = self.shell.' finished'
        endif
        echom str
endfunction

let s:jobEventCallbacks = {
        \ 'on_stdout': function('s:OnJobEventHandler'),
        \ 'on_stderr': function('s:OnJobEventHandler'),
        \ 'on_exit': function('s:OnJobEventHandler')
\ }

function! s:GetConfig()
        let configFilename = AutoRemoteSync#GetConfigFilename()
        let cfgFilepath = getcwd() . "/" . configFilename
        let jsonstr = s:ReadfileAsString(configFilename)
        let json = s:JSONParse(jsonstr)
        return json
endfunction

function! AutoRemoteSync#SetConfigFilename(fn)
        let s:configFilename = a:fn
endfunction

function! AutoRemoteSync#GetConfigFilename()
        if s:isVerbose == 0
                echo s:configFilename
        endif
        return s:configFilename
endfunction

function! s:ExecExternalCommand(command)
        if has("nvim") == 1
                if s:isVerbose == 0
                        call jobstart(["bash", "-c", a:command])
                else
                        call jobstart(['bash', '-c', a:command], extend({'shell': 'AutoRemoteSync'}, s:jobEventCallbacks))
                endif
        elseif v:version >= 800
                call job_start("bash -c " . a:command)
        else
                if s:isVerbose == 1
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

function! s:CommandListBooleanCompletion(ArgLead, CmdLine, CursorPos)
        return [1, 0]
endfunction

function! s:CommandListFileCompletion(ArgLead, CmdLine, CursorPos)
        return filter(s:GetFilesInDir(), 'v:val =~ "^'. a:ArgLead .'"')
endfunction

function! s:GetAbsoluteFilepath()
        let filepath = getcwd() . "/"
        return filepath
endfunction

function! s:GetFilesInDir()
        let filepath = s:GetAbsoluteFilepath()
        let filelist = systemlist('ls -a ' . filepath)
        return filelist
endfunction

command! AutoRemoteSyncEnable call AutoRemoteSync#Enable()
command! AutoRemoteSyncDisable call AutoRemoteSync#Disable()
command! AutoRemoteSyncGetConfigFilename call AutoRemoteSync#GetConfigFilename()
command! -bang -complete=customlist,s:CommandListBooleanCompletion -nargs=1 AutoRemoteSyncVerbose call AutoRemoteSync#Verbose(<f-args>)
command! -bang -complete=customlist,s:CommandListFileCompletion -nargs=1 AutoRemoteSyncSetConfigFilename call AutoRemoteSync#SetConfigFilename(<f-args>)

