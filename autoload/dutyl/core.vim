"Create and return the instance object. If there already is an instance object
"don't re-create it - unless the argument reinit is not-empty
function! dutyl#core#instance(reinit) abort
    if !exists('s:instance') || !empty(a:reinit)
        let s:instance=dutyl#core#create()
    endif
    return s:instance
endfunction

function! dutyl#core#requireFunctions(...) abort
    return call(dutyl#core#instance(0).requireFunctions,a:000,s:instance)
endfunction

"Create the base Dutyl object and load all modules to it
function! dutyl#core#create() abort
    let l:result={}

    let l:modules=[]
    for l:moduleDefinition in dutyl#register#list()
        let l:module=function(l:moduleDefinition.constructor)()
        if !empty(l:module) "Empty module = can not be used
            let l:module.name=l:moduleDefinition.name
            if !has_key(l:module,'checkFunction')
                let l:module.checkFunction=function('s:checkFunction')
            endif
            call add(l:modules,l:module)
        endif
    endfor

    let l:result.modules=l:modules
    let l:result.requireFunctions=function('s:requireFunctions')

    return l:result
endfunction

"Base function for testing if a module supports a function
function! s:checkFunction(functionName) dict abort
    return !has_key(self,a:functionName)
endfunction

"Creates an object with the required functions from the modules, based on
"module priority
function! s:requireFunctions(...) dict abort
    let l:result={'obj':self}
    for l:functionName in a:000
        if exists('l:Function')
            unlet l:Function
        endif
        let l:reasons=[]
        for l:module in self.modules
            unlet! l:reason
            let l:reason=l:module.checkFunction(l:functionName)
            if empty(l:reason)
                "let l:result[l:functionName]=l:module[l:functionName]
                let l:Function=l:module[l:functionName]
                break
            elseif type('')==type(l:reason)
                let l:reasons=add(l:reasons,l:reason)
            endif
        endfor
        if exists('l:Function')
            let l:result[l:functionName]=l:Function
        else
            let l:errorMessage='Function `'.l:functionName.'` is not supported by currently loaded Dutyl modules.'
            if !empty(l:reasons)
                let l:errorMessage=l:errorMessage.' Possible reasons: '.join(l:reasons,', ')
            endif
            throw l:errorMessage
        endif
    endfor
    return l:result
endfunction

"Use vimproc if available under windows to prevent opening a console window
function! dutyl#core#system(command,...) abort
    if has('win32') && exists(':VimProcBang') "We don't need vimproc when we use linux
        if empty(a:000)
            return vimproc#system(a:command)
        else
            return vimproc#system(a:command,a:000[0])
        endif
    else
        if empty(a:000)
            return system(a:command)
        else
            return system(a:command,a:000[0])
        endif
    endif
endfunction

"Returns the return code from the last run of dutyl#core#system
function! dutyl#core#shellReturnCode() abort
    if has('win32') && exists(':VimProcBang') "We don't need vimproc when we use linux
        return vimproc#get_last_status()
    else
        return v:shell_error
    endif
endfunction

"Create the command line for running a tool
function! s:createRunToolCommand(tool,args) abort
    let l:tool=dutyl#register#getToolPath(a:tool)
    if !executable(l:tool)
        throw '`'.l:tool.'` is not executable'
    endif
    let l:result=shellescape(l:tool)
    if type('')==type(a:args)
        let l:result=l:result.' '.a:args
    elseif type([])==type(a:args)
        for l:arg in a:args
            let l:result=l:result.' '.shellescape(l:arg)
        endfor
    endif
    return l:result
endfunction

"Run a tool and return the result
function! dutyl#core#runTool(tool,args,...) abort
    return call(function('dutyl#core#system'),[s:createRunToolCommand(a:tool,a:args)]+a:000)
endfunction

"Check if a tool is executable. If not - it can not be used
function! dutyl#core#toolExecutable(tool) abort
    return executable(dutyl#register#getToolPath(a:tool))
endfunction

"Run a tool in the background
function! dutyl#core#runToolInBackground(tool,args) abort
    if has('win32')
        execute '!start '.s:createRunToolCommand(a:tool,a:args)
    else
        execute '!'.s:createRunToolCommand(a:tool,a:args).' > /dev/null &'
    endif
endfunction
