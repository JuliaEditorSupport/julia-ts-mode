module ArgTools

export
    arg_read,  ArgRead,  arg_readers,
    arg_write, ArgWrite, arg_writers,
    arg_isdir, arg_mkdir, @arg_test

import Base: AbstractCmd, CmdRedirect, Process

if isdefined(Base.Filesystem, :prepare_for_deletion)
    using Base.Filesystem: prepare_for_deletion
else
    function prepare_for_deletion(path::AbstractString)
        try prepare_for_deletion_core(path)
        catch
        end
    end
    function prepare_for_deletion_core(path::AbstractString)
        isdir(path) || return
        chmod(path, filemode(path) | 0o333)
        for name in readdir(path)
            path′ = joinpath(path, name)
            prepare_for_deletion_core(path′)
        end
    end
end

const nolock_docstring = """
Note: when opening a file, ArgTools will pass `lock = false` to the file `open(...)` call.
Therefore, the object returned by this function should not be used from multiple threads.
This restriction may be relaxed in the future, which would not break any working code.
"""

if VERSION ≥ v"1.5"
    open_nolock(args...; kws...) = open(args...; kws..., lock=false)
else
    open_nolock(args...; kws...) = open(args...; kws...)
end

## main API ##

"""
    ArgRead = Union{AbstractString, AbstractCmd, IO}

The `ArgRead` types is a union of the types that the `arg_read` function knows
how to convert into readable IO handles. See [`arg_read`](@ref) for details.
"""
const ArgRead = Union{AbstractString, AbstractCmd, IO}

"""
    ArgWrite = Union{AbstractString, AbstractCmd, IO}

The `ArgWrite` types is a union of the types that the `arg_write` function knows
how to convert into writeable IO handles, except for `Nothing` which `arg_write`
handles by generating a temporary file. See [`arg_write`](@ref) for details.
"""
const ArgWrite = Union{AbstractString, AbstractCmd, IO}

"""
    arg_read(f::Function, arg::ArgRead) -> f(arg_io)

The `arg_read` function accepts an argument `arg` that can be any of these:

- `AbstractString`: a file path to be opened for reading
- `AbstractCmd`: a command to be run, reading from its standard output
- `IO`: an open IO handle to be read from

Whether the body returns normally or throws an error, a path which is opened
will be closed before returning from `arg_read` and an `IO` handle will be
flushed but not closed before returning from `arg_read`.

$(nolock_docstring)
"""
arg_read(f::Function, arg::AbstractString) = open_nolock(f, arg)
arg_read(f::Function, arg::ArgRead) = open(f, arg)
arg_read(f::Function, arg::IO) = f(arg)

"""
    arg_write(f::Function, arg::ArgWrite) -> arg
    arg_write(f::Function, arg::Nothing) -> tempname()

The `arg_read` function accepts an argument `arg` that can be any of these:

- `AbstractString`: a file path to be opened for writing
- `AbstractCmd`: a command to be run, writing to its standard input
- `IO`: an open IO handle to be written to
- `Nothing`: a temporary path should be written to

If the body returns normally, a path that is opened will be closed upon
completion; an IO handle argument is left open but flushed before return. If the
argument is `nothing` then a temporary path is opened for writing and closed
open completion and the path is returned from `arg_write`. In all other cases,
`arg` itself is returned. This is a useful pattern since you can consistently
return whatever was written, whether an argument was passed or not.

If there is an error during the evaluation of the body, a path that is opened by
`arg_write` for writing will be deleted, whether it's passed in as a string or a
temporary path generated when `arg` is `nothing`.

$(nolock_docstring)
"""
function arg_write(f::Function, arg::AbstractString)
    try open_nolock(f, arg, write=true)
    catch
        rm(arg, force=true)
        rethrow()
    end
    return arg
end

function arg_write(f::Function, arg::AbstractCmd)
    open(f, arg, write=true)
    return arg
end

function arg_write(f::Function, arg::Nothing)
    @static if VERSION ≥ v"1.5"
        file = tempname()
        io = open_nolock(file, write=true)
    else
        file, io = mktemp()
    end
    try f(io)
    catch
        close(io)
        rm(file, force=true)
        rethrow()
    end
    close(io)
    return file
end

function arg_write(f::Function, arg::IO)
    try f(arg)
    finally
        flush(arg)
    end
    return arg
end

"""
    arg_isdir(f::Function, arg::AbstractString) -> f(arg)

The `arg_isdir` function takes `arg` which must be the path to an existing
directory (an error is raised otherwise) and passes that path to `f` finally
returning the result of `f(arg)`. This is definitely the least useful tool
offered by `ArgTools` and mostly exists for symmetry with `arg_mkdir` and to
give consistent error messages.
"""
function arg_isdir(f::Function, arg::AbstractString)
    isdir(arg) || error("arg_isdir: $(repr(arg)) not a directory")
    return f(arg)
end

"""
    arg_mkdir(f::Function, arg::AbstractString) -> arg
    arg_mkdir(f::Function, arg::Nothing) -> mktempdir()

The `arg_mkdir` function takes `arg` which must either be one of:

- a path to an already existing empty directory,
- a non-existent path which can be created as a directory, or
- `nothing` in which case a temporary directory is created.

In all cases the path to the directory is returned. If an error occurs during
`f(arg)`, the directory is returned to its original state: if it already existed
but was empty, it will be emptied; if it did not exist it will be deleted.
"""
function arg_mkdir(f::Function, arg::Union{AbstractString, Nothing})
    existed = false
    if arg === nothing
        arg = mktempdir()
    else
        st = stat(arg)
        if !ispath(st)
            mkdir(arg)
        elseif !isdir(st)
            error("arg_mkdir: $(repr(arg)) not a directory")
        else
            isempty(readdir(arg)) ||
                error("arg_mkdir: $(repr(arg)) directory not empty")
            existed = true
        end
    end
    try f(arg)
    catch
        if existed
            for name in readdir(arg)
                path = joinpath(arg, name)
                prepare_for_deletion(path)
                rm(path, force=true, recursive=true)
            end
        else
            prepare_for_deletion(arg)
            rm(arg, force=true, recursive=true)
        end
        rethrow()
    end
    return arg
end

## test utilities ##

const ARG_READERS = [
    String      => path -> f -> f(path)
    Cmd         => path -> f -> f(`cat $path`)
    CmdRedirect => path -> f -> f(pipeline(path, `cat`))
    IOStream    => path -> f -> open(f, path)
    Process     => path -> f -> open(f, `cat $path`)
]

const ARG_WRITERS = [
    String      => path -> f -> f(path)
    Cmd         => path -> f -> f(`tee $path`)
    CmdRedirect => path -> f -> f(pipeline(`cat`, path))
    IOStream    => path -> f -> open(f, path, write=true)
    Process     => path -> f -> open(f, pipeline(`cat`, path), write=true)
]

@assert all(t <: ArgRead  for t in map(first, ARG_READERS))
@assert all(t <: ArgWrite for t in map(first, ARG_WRITERS))

"""
    arg_readers(arg :: AbstractString, [ type = ArgRead ]) do arg::Function
        ## pre-test setup ##
        @arg_test arg begin
            arg :: ArgRead
            ## test using `arg` ##
        end
        ## post-test cleanup ##
    end

The `arg_readers` function takes a path to be read and a single-argument do
block, which is invoked once for each test reader type that `arg_read` can
handle. If the optional `type` argument is given then the do block is only
invoked for readers that produce arguments of that type.

The `arg` passed to the do block is not the argument value itself, because some
of test argument types need to be initialized and finalized for each test case.
Consider an open file handle argument: once you've used it for one test, you
can't use it again; you need to close it and open the file again for the next
test. This function `arg` can be converted into an `ArgRead` instance using
`@arg_test arg begin ... end`.
"""
function arg_readers(
    body::Function,
    path::AbstractString,
    type::Type = ArgRead,
)
    for (t, reader) in ARG_READERS
        t <: type || continue
        body(reader(path))
    end
end

"""
    arg_writers([ type = ArgWrite ]) do path::String, arg::Function
        ## pre-test setup ##
        @arg_test arg begin
            arg :: ArgWrite
            ## test using `arg` ##
        end
        ## post-test cleanup ##
    end

The `arg_writers` function takes a do block, which is invoked once for each test
writer type that `arg_write` can handle with a temporary (non-existent) `path`
and `arg` which can be converted into various writable argument types which
write to `path`. If the optional `type` argument is given then the do block is
only invoked for writers that produce arguments of that type.

The `arg` passed to the do block is not the argument value itself, because some
of test argument types need to be initialized and finalized for each test case.
Consider an open file handle argument: once you've used it for one test, you
can't use it again; you need to close it and open the file again for the next
test. This function `arg` can be converted into an `ArgWrite` instance using
`@arg_test arg begin ... end`.

There is also an `arg_writers` method that takes a path name like `arg_readers`:

    arg_writers(path::AbstractString, [ type = ArgWrite ]) do arg::Function
        ## pre-test setup ##
        @arg_test arg begin
            # here `arg :: ArgWrite`
            ## test using `arg` ##
        end
        ## post-test cleanup ##
    end

This method is useful if you need to specify `path` instead of using path name
generated by `tempname()`. Since `path` is passed from outside of `arg_writers`,
the path is not an argument to the do block in this form.
"""
function arg_writers(
    body::Function,
    type::Type = ArgWrite,
)
    for (t, writer) in ARG_WRITERS
        t <: type || continue
        path = tempname()
        try body(path, writer(path))
        finally
            rm(path, force=true)
        end
    end
end

function arg_writers(
    body::Function,
    path::AbstractString,
    type::Type = ArgWrite,
)
    for (t, writer) in ARG_WRITERS
        t <: type || continue
        body(writer(path))
    end
end

"""
    @arg_test arg1 arg2 ... body

The `@arg_test` macro is used to convert `arg` functions provided by
`arg_readers` and `arg_writers` into actual argument values. When you write
`@arg_test arg body` it is equivalent to `arg(arg -> body)`.
"""
macro arg_test(args...)
    arg_test(args...)
end

function arg_test(var::Symbol, args...)
    var = esc(var)
    body = arg_test(args...)
    :($var($var -> $body))
end

arg_test(ex::Expr) = esc(ex)

end # module
