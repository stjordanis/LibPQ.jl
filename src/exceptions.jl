"Base abstract type for all custom exceptions thrown by LibPQ.jl"
abstract type LibPQException <: Exception end

"An exception with an error message generated by PostgreSQL"
abstract type PostgreSQLException <: LibPQException end

# PostgreSQL errors have trailing newlines
# https://www.postgresql.org/docs/10/libpq-status.html#LIBPQ-PQERRORMESSAGE
Base.showerror(io::IO, err::PostgreSQLException) = print(io, chomp(err.msg))

"An exception generated by LibPQ.jl"
abstract type JLClientException <: LibPQException end

"An error regarding a connection reported by PostgreSQL"
struct PQConnectionError <: PostgreSQLException
    msg::String
end

function PQConnectionError(jl_conn::Connection)
    return PQConnectionError(error_message(jl_conn))
end

"An error regarding a connection reported by PostgreSQL"
struct ConninfoParseError <: PostgreSQLException
    msg::String
end

"An error regarding a connection generated by LibPQ.jl"
struct JLConnectionError <: JLClientException
    msg::String
end

"An error regarding a query result generated by LibPQ.jl"
struct JLResultError <: JLClientException
    msg::String
end

"""
An error regarding a query result generated by PostgreSQL

The `Code` parameter represents the PostgreSQL error code as defined in
[Appendix A. PostgreSQL Error Codes](https://www.postgresql.org/docs/devel/errcodes-appendix.html).
The `Class` parameter is the first two characters of that code, also listed on that page.

For a list of all error aliases, see [src/error_codes.jl](https://github.com/invenia/LibPQ.jl/blob/master/src/error_codes.jl),
which was generated using the PostgreSQL documentation linked above.

```jldoctest
julia> try execute(conn, "SELORCT NUUL;") catch err println(err) end
LibPQ.SyntaxError("ERROR:  syntax error at or near \\"SELORCT\\"\\nLINE 1: SELORCT NUUL;\\n        ^\\n")

julia> LibPQ.SyntaxError
LibPQ.PQResultError{c"42",e"42601"}
```
"""
struct PQResultError{Class, Code} <: PostgreSQLException
    msg::String
    verbose_msg::Union{String, Nothing}

    function PQResultError{Class_, Code_}(msg, verbose_msg) where {Class_, Code_}
        return new{Class_::Class, Code_::ErrorCode}(
            convert(String, msg),
            convert(Union{String, Nothing}, verbose_msg),
        )
    end
end

include("error_codes.jl")

function PQResultError{Class, Code}(msg::String) where {Class, Code}
    return PQResultError{Class, Code}(msg, nothing)
end

function PQResultError(result::Result; verbose=false)
    msg = error_message(result; verbose=false)
    verbose_msg = verbose ? error_message(result; verbose=true) : nothing
    code = error_field(result, libpq_c.PG_DIAG_SQLSTATE)

    return PQResultError{Class(code), ErrorCode(code)}(msg, verbose_msg)
end

error_class(err::PQResultError{Class_}) where {Class_} = Class_::Class
error_code(err::PQResultError{Class_, Code_}) where {Class_, Code_} = Code_::ErrorCode

function Base.showerror(io::IO, err::T) where T <: PQResultError
    msg = err.verbose_msg === nothing ? err.msg : err.verbose_msg

    print(io, ERROR_NAMES[T], ": ", chomp(msg))
end

function Base.show(io::IO, err::T) where T <: PQResultError
    print(io, "LibPQ.", ERROR_NAMES[T], '(', repr(err.msg))

    if err.verbose_msg !== nothing
        print(io, ", ", repr(err.verbose_msg))
    end

    print(io, ')')
end
