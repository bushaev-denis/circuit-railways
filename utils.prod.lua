require('types')
require('config')

logger = {
    debug = function(...) end,
    info = function(...) end,
    warn = function(...)
        print('[CCR]Warn:', ...)
    end,
    error = function(...)
        print('[CCR]Error:', ...)
    end
}
