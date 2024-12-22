# ==============================
# tuple collections
# ==============================

()
# There's no (,)

(1) # NOT a tuple
(1,)
(2,3,4,)

# ==============================
# named tuple collections
# ==============================

(a = 1) # NOT a tuple
(a = 1,)
(a = 1, b = 2)
(;)
(; a)
(; a = 1)
(; a = 1, b = 2)
(; a, foo.b)

# ==============================
# vector array collections
# ==============================

[]
# There's no [,]
[x]
[x,]
[1, 2]

# Check unary-and-binary-operators
[x.-y, 2]

# ==============================
# matrix array collections
# ==============================

[x;]
[1 2]
[1 2; 3 4]
[1 2
 3 4]
[1
 2
 3
]
[
 a;
 b;
 c;
]
[1;; 2;; 3;;; 4;; 5;; 6;;]
Int[1 2 3 4]

# ========================================
# comprehension array collections
# ========================================

[x for x in xs]
[x
  for x in xs
  if x > 0
]
UInt[b(c, e) for c in d for e in f]

f(1, 2, i for i in iter)
(b(c, e) for c in d, e = 5 if e)

# ==============================
# module definitions
# ==============================

module A

baremodule B end

module C
end

end

# ==============================
# abstract type definitions
# ==============================

abstract type T end
abstract type T <: S end
abstract type T{S} <: U end

# ==============================
# primitive type definitions
# ==============================

primitive type T 8 end
primitive type T <: S 16 end
primitive type Ptr{T} 32 end

# ==============================
# struct definitions
# ==============================

struct Unit end

struct MyInt field::Int end

mutable struct Foo
  bar
  baz::Float64
end

# ==============================
# parametric struct definitions
# ==============================

struct Point{T}
  x::T
  y::T
end

struct Rational{T<:Integer} <: Real
  num::T
  den::T
end

mutable struct MyVec <: AbstractArray
  foos::Vector{Foo}
end

# ==============================
# function definitions
# ==============================

function f end

function nop() end

function I(x) x end

function Base.rand(n::MyInt)
    return 4
end

function Γ(z)
    gamma(z)
end

function ⊕(x, y)
    x + y
end

function fix2(f, x)
    return function(y)
        f(x, y)
    end
end

function (foo::Foo)()
end

# ==============================
# short function definitions
# ==============================

s(n) = n + 1

Base.foo(x) = x

ι(n) = range(1, n)

⊗(x, y) = x * y

(+)(x, y) = x + y

# ==============================
# function definition parameters
# ==============================

function f(x, y::Int, z=1, ws...) end

function (::Type{Int}, x::Int = 1, y::Int...) end

function apply(f, args...; kwargs...)
end

function g(; x, y::Int, z = 1, kwargs...) nothing end

# ==================================================
# function definition return types
# ==================================================

function s(n)::MyInt
    MyInt(n + 1)
end

function bar(f, xs::Foo.Bar)::Foo.Bar
    map(f, xs)
end

# ==================================================
# function definition tuple parameters
# ==================================================

function swap((x, y))
    (y, x)
end

function f((x, y)=(1,2))
    (x, y)
end

function car((x, y)::Tuple{T, T}) where T
    x
end

# ==================================================
# type parametric function definition parameters
# ==================================================

function f(x::T) where T
end

function f(n::N) where {N <: Integer}
    n
end

f(n::N, m::M) where {N <: Number} where {M <: Integer} = n^m

Foo{T}(x::T) where {T} = x

function norm(p::Point{T} where T<:Real)
    norm2(p)
end

Base.show(io::IO, ::MIME"text/plain", m::Method; kwargs...) = show_method(io, m, kwargs)

# ==============================
# macro definitions
# ==============================

macro name(s::Symbol)
    String(s)
end

macro count(args...) length(args) end

# ==============================
# identifiers
# ==============================

abc_123_ABC
_fn!
ρ; φ; z
ℝ
x′
θ̄
logŷ
ϵ
ŷ
🙋
🦀

# ==============================
# field expressions
# ==============================

foo.x
bar.x.y.z

(a[1].b().c).d

Base.:+

df."a"

# ==============================
# index expressions
# ==============================

a[1, 2, 3]
a[1, :]
"foo"[1]

# ==============================
# type parametrized expressions
# ==============================

Vector{Int}
Vector{<:Number}
$(usertype){T}

{:x} ~ normal(0, 1)

# ==============================
# function call expressions
# ==============================

f()
g("hi", 2)
h(d...)

f(e; f = g)
g(arg; kwarg)

new{typeof(xs)}(xs)

# ========================================
# function call expressions with do blocks
# ========================================

reduce(xs) do x, y
  f(x, y)
end

# ==============================
# macro call expressions
# ==============================

@assert x == y "a message"

@testset "a" begin
  b = c
end

@. a * x + b

joinpath(@__DIR__, "grammar.js")

@macroexpand @async accept(socket)

@Meta.dump 1, 2
Meta.@dump x = 1

# ==============================
# closed macro call expressions
# ==============================

@enum(Light, red, yellow, green)
f(@nospecialize(x)) = x

@m[1, 2] + 1
@m [1, 2] + 1

# ==============================
# quote expressions
# ==============================

:foo
:const

:(x; y)
:(x, y)
:[x, y, z]

:+
:->
:(::)

# ==============================
# interpolation expressions
# ==============================

$foo
$obj.field
$(obj.field)
$f(x)
$f[1, 2]
$"foo"

using $Package: $(name)

# Similar definitions in Gadfly/src/varset.jl
mutable struct $(name)
  $(vars...)
end
function $(name)($(parameters_expr))
    $(name)($(parsed_vars...))
end

# ==============================
# adjoint expressions
# ==============================

[u, v]'
A'[i]
(x, y)'
f'(x)
:a'

# ==============================
# juxtaposition expressions
# ==============================

1x
2v[i]
3f(x)
4df.a
5u"kg"
x'x
2x^2 - .3x
2(x-1)^2 - 3(x-1)

# =============================
# arrow function expressions
# =============================

x -> x^2
(x,y,z)-> 2*x + y - z
()->3
() -> (sleep(0.1); i += 1; l)
a -> a = 2, 3

# ==============================
# boolean literals
# ==============================

true
false

# ==============================
# integer number literals
# ==============================

0b01
0o01234567
0123456789
123_456_789
0x0123456789_abcdef_ABCDEF

# ==============================
# float number literals
# ==============================

0123456789.
.0123456789
0123456789.0123456789

9e10
9E-1
9f10
9f-1

.1e10
1.1e10
1.e10

0x0123456789_abcdef.ABCDEFp0
0x0123456789_abcdef_ABCDEF.p-1
0x.0123456789_abcdef_ABCDEFp1

# ==============================
# character literals
# ==============================

' '
'o'
'\t'
'\uffff'
'\U10ffff'

# ==============================
# string literals
# ==============================

""
"\""
"foo
 bar"
"this is a \"string\"."
"""this is also a "string"."""
band = "Interpol"
"$band is a cool band"
"$(2π) is a cool number"
"cells interlinked within $("cells interlinked whithin $("cells interlinked whithin one stem")")"

# ==============================
# command string literals
# ==============================

`pwd`
m`pwd`
`cd $dir`
`echo \`cmd\``
```
echo "\033[31mred\033[m"
```

# ==============================
# non-standard string literals
# ==============================

# FIXME: \s shouldn't be an escape_sequence here
trailing_ws = r"\s+$"
version = v"1.0"
K"\\"

# ==============================
# comments
# ==============================

# comment
#= comment =#
#=
comment
=#
x = #= comment =# 1

#=
nested #= comments =# =#
#==#

# ==============================
# assignment operators
# ==============================

a = b
a .. b = a * b
tup = 1, 2, 3
car, cdr... = list
c &= d ÷= e

# ==============================
# binary arithmetic operators
# ==============================

a + b
a ++ 1 × b ⥌ 2 → c
a // b
x = A \ (v × w)

# ==============================
# other binary operators
# ==============================

a & b | c
(x >>> 16, x >>> 8, x) .& 0xff

Dict(b => c, d => e)

x |>
  f |>
  g

1..10
(1:10...,)

# ==============================
# binary comparison operators
# ==============================

a === 1
a! != 0

A ⊆ B ⊆ C
x ≥ 0 ≥ z

# ==============================
# unary operators
# ==============================

-A'
+a
-b
√9
!p === !(p)
1 ++ +2

# =============================
# operator broadcasting
# =============================

a .* b .+ c
.~[x]

# ==============================
# ternary operator
# ==============================

x = batch_size == 1 ?
  rand(10) :
  rand(10, batch_size)

# ==============================
# operators as values
# ==============================

x = +
⪯ = .≤
print(:)
foo(^, ÷, -)

# ==============================
# compound statements
# ==============================

begin
end

begin
    foo
    bar
    baz
end

# ==============================
# quote statements
# ==============================

quote end

quote
  x = 1
  y = 2
  x + y
end

# ==============================
# let statements
# ==============================

let
end

let var1 = value1, var2, var3 = value3
    code
end

# ==============================
# if statements
# ==============================

if a
elseif b
else
end

if true 1 else 0 end

if a
  b()
elseif c
  d()
  d()
else
  e()
end

# ==============================
# try statements
# ==============================

try catch end
try finally end

try
    sqrt(x)
catch
    sqrt(complex(x, 0))
end

try
    operate_on_file(f)
finally
    close(f)
end

try
    # fallible
catch
    # handle errors
else
    # do something if there were no exceptions
end

# ==============================
# for statements
# ==============================

for x in xs end

for x in xs foo!(x) end

for i in [1, 2, 3]
  print(i)
end

for (a, b) in c
  print(a, b)
end

# ==============================
# for outer statements
# ==============================

n = 1
for outer n in range
  body
end

for outer x = iter1, outer y = iter2
  body
end

# ==============================
# while statements
# ==============================

while true end

while i < 5
  print(i)
  continue
  break
end

while a(); b(); end

# ==============================
# return statements
# ==============================

return
return a
return a || b
return a, b, c

# ==============================
# export statements
# ==============================

export a
export a, b, +, (*)
export @macroMcAtface
public a
public a, b, +, (*)
public @macroMcAtface

# ==============================
# import statements
# ==============================

import Pkg

using Sockets

using ..Foo, ..Bar

import CSV, Chain, DataFrames

import Base: show, @kwdef, +, (*)

import LinearAlgebra as la

import Base: @view as @v

# ===============================
# const statements
# ===============================

const x = 5
const y, z = 1, 2

(0, const x, y = 1, 2)

# ===============================
# local statements
# ===============================

local x
local y, z = 1, 2
local foo() = 3
local function bar() 4 end

# ===============================
# global statements
# ===============================

global X
global Y, Z = 11, 42
global foo() = 3
global function bar() 4 end
