source('/var/task/runtime.R')
# TODO: Why the multiple initializeRuntime()?
tryCatch({
    function_name <- initializeRuntime()
    while (TRUE) {
        handle_request(function_name)
        logReset()
        rm(list=ls())
        source('/var/task/runtime.R')
        function_name <- initializeRuntime()
    }
}, error = throwInitError)