# AutoRemoteSync.nvim

A Vim/Neovim plugin to automatically upload files via `scp` to a remote
server when you write the contents of a buffer to disk.

You need to have a `.AutoRemoteSync.json` configuration file in the current
working directory of Vim/Neovim.

An example `.AutoRemoteSync.json` file would look like this:

```json
{
        "remote": {
                "host": "example.com",
                "user": "root",
                "port": 22,
                "path": "/var/www/html"
        }
}
```

To enable the uploading of files on *bufwrite*, you need to call
`AutoRemoteSync#Enable()` like so:

```
:call AutoRemoteSync#Enable()<CR>
```

To disable it again, call `AutoRemoteSync#Disable()` like so:

```
:call AutoRemoteSync#Disable()<CR>
```

