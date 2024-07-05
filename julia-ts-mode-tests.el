;;; julia-ts-mode-tests.el --- Tests for julia-ts-mode.el

;; Copyright (C) 2009-2014 Julia contributors
;; URL: https://github.com/JuliaLang/julia
;; Version: 0.3
;; Keywords: languages

;;; Usage:

;; From command line:
;;
;; emacs -batch -L . -l ert -l julia-ts-mode-tests.el -f  ert-run-tests-batch-and-exit

;;; Commentary:
;; Contains ert tests for julia-ts-mode.el

;;; License:
;; Permission is hereby granted, free of charge, to any person obtaining
;; a copy of this software and associated documentation files (the
;; "Software"), to deal in the Software without restriction, including
;; without limitation the rights to use, copy, modify, merge, publish,
;; distribute, sublicense, and/or sell copies of the Software, and to
;; permit persons to whom the Software is furnished to do so, subject to
;; the following conditions:
;;
;; The above copyright notice and this permission notice shall be
;; included in all copies or substantial portions of the Software.
;;
;; THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
;; EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
;; MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
;; NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
;; LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
;; OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
;; WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

;;; Code:

(require 'julia-ts-mode)
(require 'ert)

(defmacro julia-ts--should-indent (from to)
  "Assert that we indent text FROM producing text TO in `julia-ts-mode'."
  `(with-temp-buffer
     (let ((julia-indent-offset 4))
       (julia-ts-mode)
       (insert ,from)
       (indent-region (point-min) (point-max))
       (should (equal (buffer-substring-no-properties (point-min) (point-max))
                      ,to)))))

(defun julia-ts--get-font-lock (text pos)
  "Get the face of `text' at `pos' when font-locked as Julia code in this mode."
  (with-temp-buffer
     (julia-ts-mode)
     (insert text)
     (if (fboundp 'font-lock-ensure)
         (font-lock-ensure (point-min) (point-max))
       (with-no-warnings
         (font-lock-fontify-buffer)))
     (get-text-property pos 'face)))

(defmacro julia-ts--should-font-lock (text pos face)
  "Assert that TEXT at position POS gets font-locked with FACE in `julia-ts-mode'."
  `(should (eq ,face (julia-ts--get-font-lock ,text ,pos))))

(defun julia-ts--should-move-point-helper (text fun from to &optional end &rest args)
  "Takes the same arguments as `julia-ts--should-move-point', returns a cons of the expected and the actual point."
  (with-temp-buffer
    (julia-ts-mode)
    (insert text)
    (indent-region (point-min) (point-max))
    (goto-char (point-min))
    (if (stringp from)
        (re-search-forward from)
      (goto-char from))
    (apply fun args)
    (let ((actual-to (point))
          (expected-to
           (if (stringp to)
               (progn (goto-char (point-min))
                      (re-search-forward to)
                      (if end
                          (goto-char (match-end 0))
                        (goto-char (match-beginning 0))
                        (point-at-bol)))
             to)))
      (cons expected-to actual-to))))

(defmacro julia-ts--should-move-point (text fun from to &optional end &rest args)
  "With TEXT in `julia-ts-mode', after calling FUN, the point should move FROM\
to TO.  If FROM is a string, move the point to matching string before calling
function FUN.  If TO is a string, match resulting point to point a beginning of
matching line or end of match if END is non-nil.  Optional ARG is passed to FUN."
  (declare (indent defun))
  `(let ((positions (julia-ts--should-move-point-helper ,text ,fun ,from ,to ,end ,@args)))
     (should (eq (car positions) (cdr positions)))))

;;; indent tests

(ert-deftest julia-ts--test-indent-if ()
  "We should indent inside if bodies."
  (julia-ts--should-indent
   "
if foo
bar
end"
   "
if foo
    bar
end"))

(ert-deftest julia-ts--test-indent-else ()
  "We should indent inside else bodies."
  (julia-ts--should-indent
   "
if foo
    bar
else
baz
end"
   "
if foo
    bar
else
    baz
end"))

(ert-deftest julia-ts--test-indent-toplevel ()
  "We should not indent toplevel expressions. "
  (julia-ts--should-indent
   "
foo()
bar()"
   "
foo()
bar()"))

(ert-deftest julia-ts--test-indent-nested-if ()
  "We should indent for each level of indentation."
  (julia-ts--should-indent
   "
if foo
    if bar
bar
    end
end"
   "
if foo
    if bar
        bar
    end
end"))

(ert-deftest julia-ts--test-indent-module-keyword ()
  "Module should not increase indentation at any level."
  (julia-ts--should-indent
   "
module
begin
    a = 1
end
end"
   "
module
begin
    a = 1
end
end")
  (julia-ts--should-indent
   "
begin
module
foo
end
end"
   "
begin
    module
    foo
    end
end"))

(ert-deftest julia-ts--test-indent-function ()
  "We should indent function bodies."
  (julia-ts--should-indent
   "
function foo()
bar
end"
   "
function foo()
    bar
end"))

(ert-deftest julia-ts--test-indent-begin ()
  "We should indent after a begin keyword."
  (julia-ts--should-indent
   "
@async begin
bar
end"
   "
@async begin
    bar
end"))

(ert-deftest julia-ts--test-indent-paren ()
  "We should indent to line up with the text after an open paren."
  (julia-ts--should-indent
   "
foobar(bar,
baz)"
   "
foobar(bar,
       baz)"))

(ert-deftest julia-ts--test-indent-paren-space ()
  "We should indent to line up with the text after an open
paren, even if there are additional spaces."
  (julia-ts--should-indent
   "
foobar( bar,
baz )"
   "
foobar( bar,
        baz )"))

(ert-deftest julia-ts--test-indent-paren-newline ()
  "python-mode-like indentation."
  (julia-ts--should-indent
   "
foobar(
bar,
baz)"
   "
foobar(
    bar,
    baz)")
  (julia-ts--should-indent
   "
foobar(
bar,
baz
)"
   "
foobar(
    bar,
    baz
)"))

(ert-deftest julia-ts--test-indent-equals ()
  "We should increase indent on a trailing =."
  (julia-ts--should-indent
   "
foo() =
bar"
   "
foo() =
    bar"))

(ert-deftest julia-ts--test-indent-operator ()
  "We should increase indent after the first trailing operator
but not again after that."
  (julia-ts--should-indent
   "
foo() |>
bar |>
baz
qux"
   "
foo() |>
    bar |>
    baz
qux")
  (julia-ts--should-indent
   "x \\
y \\
z"
   "x \\
    y \\
    z"))

(ert-deftest julia-ts--test-indent-ignores-blank-lines ()
  "Blank lines should not affect indentation of non-blank lines."
  (julia-ts--should-indent
   "
if foo

bar
end"
   "
if foo

    bar
end"))

(ert-deftest julia-ts--test-indent-comment-equal ()
  "`=` at the end of comment should not increase indent level."
  (julia-ts--should-indent
   "
# a =
# b =
c"
   "
# a =
# b =
c"))

(ert-deftest julia-ts--test-indent-leading-paren ()
  "`(` at the beginning of a line should not affect indentation."
  (julia-ts--should-indent
   "
\(1)"
   "
\(1)"))

(ert-deftest julia-ts--test-top-level-following-paren-indent ()
  "`At the top level, a previous line indented due to parens should not affect indentation."
  (julia-ts--should-indent
   "y1 = f(x,
       z)
y2 = g(x)"
   "y1 = f(x,
       z)
y2 = g(x)"))

(ert-deftest julia-ts--test-indentation-of-multi-line-strings ()
  "Indentation should only affect the first line of a multi-line string."
  (julia-ts--should-indent
   "   a = \"\"\"
    description
begin
    foo
bar
end
\"\"\""
   "a = \"\"\"
    description
begin
    foo
bar
end
\"\"\""))

(ert-deftest julia-ts--test-indent-of-end-in-brackets ()
  "Ignore end keyword in brackets for the purposes of indenting blocks."
  (julia-ts--should-indent
   "begin
    begin
        arr[1: end - 1]
        end
end"
   "begin
    begin
        arr[1: end - 1]
    end
end"))

(ert-deftest julia-ts--test-indent-after-commented-keyword ()
  "Ignore keywords in comments when indenting."
  (julia-ts--should-indent
   "# if foo
a = 1"
   "# if foo
a = 1"))

(ert-deftest julia-ts--test-indent-after-commented-end ()
  "Ignore `end` in comments when indenting."
  (julia-ts--should-indent
   "if foo
a = 1
#end
b = 1
end"
   "if foo
    a = 1
    #end
    b = 1
end"))

(ert-deftest julia-ts--test-indent-import-export-using ()
  "Toplevel using, export, and import."
  (julia-ts--should-indent
   "export bar, baz,
quux"
   "export bar, baz,
    quux")
  (julia-ts--should-indent
   "using Foo: bar ,
baz,
quux
notpartofit"
   "using Foo: bar ,
    baz,
    quux
notpartofit")
  (julia-ts--should-indent
   "using Foo.Bar: bar ,
baz,
quux
notpartofit"
   "using Foo.Bar: bar ,
    baz,
    quux
notpartofit"))

(ert-deftest julia-ts--test-indent-anonymous-function ()
  "indentation for function(args...)"
  (julia-ts--should-indent
   "function f(x)
function(y)
x+y
end
end"
   "function f(x)
    function(y)
        x+y
    end
end"))

(ert-deftest julia-ts--test-backslash-indent ()
  "indentation for function(args...)"
  (julia-ts--should-indent
   "(\\)
   1
   (:\\)
       1"
   "(\\)
1
(:\\)
1"))

(ert-deftest julia-ts--test-indent-keyword-paren ()
  "indentation for ( following keywords"
  "if( a>0 )
end

    function( i=1:2 )
        for( j=1:2 )
            for( k=1:2 )
            end
            end
        end"
  "if( a>0 )
end

function( i=1:2 )
    for( j=1:2 )
        for( k=1:2 )
        end
    end
end")

(ert-deftest julia-ts--test-indent-ignore-:end-as-block-ending ()
  "Do not consider `:end` as a block ending."
  (julia-ts--should-indent
   "if a == :end
r = 1
end"
   "if a == :end
    r = 1
end")

  (julia-ts--should-indent
   "if a == a[end-4:end]
r = 1
end"
   "if a == a[end-4:end]
    r = 1
end")
  )

(ert-deftest julia-ts--test-indent-hanging ()
  "Test indentation for line following a hanging operator."
  (julia-ts--should-indent
   "
f(x) =
x*
x"
   "
f(x) =
    x*
    x")
  (julia-ts--should-indent
   "
a = \"#\" |>
identity"
   "
a = \"#\" |>
    identity")
  ;; make sure we don't interpret a hanging operator in a comment as
  ;; an actual hanging operator for indentation
  (julia-ts--should-indent
   "
a = \"#\" # |>
identity"
   "
a = \"#\" # |>
identity"))

(ert-deftest julia-ts--test-indent-quoted-single-quote ()
  "We should indent after seeing a character constant containing a single quote character."
  (julia-ts--should-indent "
if c in ('\'')
s = \"$c$c\"*string[startpos:pos]
end
" "
if c in ('\'')
    s = \"$c$c\"*string[startpos:pos]
end
"))

(ert-deftest julia-ts--test-indent-block-inside-paren ()
  "We should indent a block inside of a parenthetical."
  (julia-ts--should-indent "
variable = func(
arg1,
arg2,
if cond
statement()
arg3
else
arg3
end,
arg4
)" "
variable = func(
    arg1,
    arg2,
    if cond
        statement()
        arg3
    else
        arg3
    end,
    arg4
)"))

(ert-deftest julia-ts--test-indent-block-inside-hanging-paren ()
  "We should indent a block inside of a hanging parenthetical."
  (julia-ts--should-indent "
variable = func(arg1,
arg2,
if cond
statement()
arg3
else
arg3
end,
arg4
)" "
variable = func(arg1,
                arg2,
                if cond
                    statement()
                    arg3
                else
                    arg3
                end,
                arg4
                )"))

(ert-deftest julia-ts--test-indent-nested-block-inside-paren ()
  "We should indent a nested block inside of a parenthetical."
  (julia-ts--should-indent "
variable = func(
arg1,
if cond1
statement()
if cond2
statement()
end
arg3
end,
arg4
)" "
variable = func(
    arg1,
    if cond1
        statement()
        if cond2
            statement()
        end
        arg3
    end,
    arg4
)"))

(ert-deftest julia-ts--test-indent-block-next-to-paren ()
  (julia-ts--should-indent "
var = func(begin
test
end
)" "
var = func(begin
               test
           end
           )"))

;;; font-lock tests

(ert-deftest julia-ts--test-symbol-font-locking-at-bol ()
  "Symbols get font-locked at beginning or line."
  (julia-ts--should-font-lock
   ":a in keys(Dict(:a=>1))" 1 'julia-ts-quoted-symbol-face))

(ert-deftest julia-ts--test-symbol-font-locking-after-backslash ()
  "Even with a \ before the (, it is recognized as matching )."
  (let ((string "function \\(a, b)"))
    (julia-ts--should-font-lock string (1- (length string)) nil)))

(ert-deftest julia-ts--test-function-assignment-font-locking ()
  (julia-ts--should-font-lock
   "f(x) = 1" 1 'font-lock-function-name-face)
  (julia-ts--should-font-lock
   "Base.f(x) = 1" 6 'font-lock-function-name-face)
  (julia-ts--should-font-lock
   "f(x) where T = 1" 1 'font-lock-function-name-face)
  (julia-ts--should-font-lock
   "f(x) where{T} = 1" 1 'font-lock-function-name-face)
  (dolist (def '("f(x)::T = 1" "f(x) :: T = 1" "f(x::X)::T where X = x"))
    (julia-ts--should-font-lock def 1 'font-lock-function-name-face)))

(ert-deftest julia-ts--test-where-keyword-font-locking ()
  (julia-ts--should-font-lock
   "f(x) where T = 1" 6 'font-lock-keyword-face)
  (dolist (pos '(22 30))
    (julia-ts--should-font-lock
     "function f(::T, ::Z) where T where Z
          1
      end"
     pos 'font-lock-keyword-face)))

(ert-deftest julia-ts--test-escaped-strings-dont-terminate-string ()
  "Symbols get font-locked at beginning or line."
  (let ((string "\"\\\"\"; function"))
    (dolist (pos '(1 2 3 4))
      (julia-ts--should-font-lock string pos font-lock-string-face))
    (julia-ts--should-font-lock string (length string) font-lock-keyword-face)))

(ert-deftest julia-ts--test-ternary-font-lock ()
  "? and : in ternary expression font-locked as keywords"
  (let ((string "true ? 1 : 2"))
    (julia-ts--should-font-lock string 6 font-lock-keyword-face)
    (julia-ts--should-font-lock string 10 font-lock-keyword-face))
  (let ((string "true ?\n    1 :\n    2"))
    (julia-ts--should-font-lock string 6 font-lock-keyword-face)
    (julia-ts--should-font-lock string 14 font-lock-keyword-face)))

(ert-deftest julia-ts--test-forloop-font-lock ()
  "for and in/=/∈ font-locked as keywords in loops and comprehensions"
  (let ((string "for i=1:10\nprintln(i)\nend"))
    (julia-ts--should-font-lock string 1 font-lock-keyword-face)
    (julia-ts--should-font-lock string 6 font-lock-keyword-face))
  (let ((string "for i in 1:10\nprintln(i)\nend"))
    (julia-ts--should-font-lock string 3 font-lock-keyword-face)
    (julia-ts--should-font-lock string 7 font-lock-keyword-face))
  (let ((string "for i∈1:10\nprintln(i)\nend"))
    (julia-ts--should-font-lock string 2 font-lock-keyword-face)
    (julia-ts--should-font-lock string 6 font-lock-keyword-face))
  (let ((string "[i for i in 1:10]"))
    (julia-ts--should-font-lock string 4 font-lock-keyword-face)
    (julia-ts--should-font-lock string 10 font-lock-keyword-face))
  (let ((string "(i for i in 1:10)"))
    (julia-ts--should-font-lock string 4 font-lock-keyword-face)
    (julia-ts--should-font-lock string 10 font-lock-keyword-face))
  (let ((string "[i for i ∈ 1:15 if w(i) == 15]"))
    (julia-ts--should-font-lock string 4 font-lock-keyword-face)
    (julia-ts--should-font-lock string 10 font-lock-keyword-face)
    (julia-ts--should-font-lock string 17 font-lock-keyword-face)
    (julia-ts--should-font-lock string 25 nil)
    (julia-ts--should-font-lock string 26 nil)))

(ert-deftest julia-ts--test-typeparams-font-lock ()
  (let ((string "@with_kw struct Foo{A <: AbstractThingy, B <: Tuple}\n    bar::A\n    baz::B\nend"))
    (julia-ts--should-font-lock string 30 font-lock-type-face) ; AbstractThingy
    (julia-ts--should-font-lock string 50 font-lock-type-face) ; Tuple
    (julia-ts--should-font-lock string 63 font-lock-type-face) ; A
    (julia-ts--should-font-lock string 74 font-lock-type-face) ; B
    ))

(ert-deftest julia-ts--test-single-quote-string-font-lock ()
  "Test that single quoted strings are font-locked correctly even with escapes."
  ;; Issue #15
  (let ((s1 "\"a\\\"b\"c"))
    (julia-ts--should-font-lock s1 2 font-lock-string-face)
    (julia-ts--should-font-lock s1 5 font-lock-string-face)
    (julia-ts--should-font-lock s1 7 nil)))

(ert-deftest julia-ts--test-triple-quote-string-font-lock ()
  "Test that triple quoted strings are font-locked correctly even with escapes."
  ;; Issue #15
  (let ((s1 "\"\"\"a\\\"\\\"\"b\"\"\"d")
        (s2 "\"\"\"a\\\"\"\"b\"\"\"d")
        (s3 "\"\"\"a```b\"\"\"d")
        (s4 "\\\"\"\"a\\\"\"\"b\"\"\"d")
        (s5 "\"\"\"a\\\"\"\"\"b"))
    (julia-ts--should-font-lock s1 4 font-lock-string-face)
    (julia-ts--should-font-lock s1 10 font-lock-string-face)
    (julia-ts--should-font-lock s1 14 nil)
    (julia-ts--should-font-lock s2 4 font-lock-string-face)
    (julia-ts--should-font-lock s2 9 font-lock-string-face)
    (julia-ts--should-font-lock s2 13 nil)
    (julia-ts--should-font-lock s3 4 font-lock-string-face)
    (julia-ts--should-font-lock s3 8 font-lock-string-face)
    (julia-ts--should-font-lock s3 12 nil)
    (julia-ts--should-font-lock s4 5 font-lock-string-face)
    (julia-ts--should-font-lock s4 10 font-lock-string-face)
    (julia-ts--should-font-lock s4 14 nil)
    (julia-ts--should-font-lock s5 4 font-lock-string-face)
    (julia-ts--should-font-lock s5 10 nil)))

(ert-deftest julia-ts--test-triple-quote-cmd-font-lock ()
  "Test that triple-quoted cmds are font-locked correctly even with escapes."
  (let ((s1 "```a\\`\\``b```d")
        (s2 "```a\\```b```d")
        (s3 "```a\"\"\"b```d")
        (s4 "\\```a\\```b```d"))
    (julia-ts--should-font-lock s1 4 font-lock-string-face)
    (julia-ts--should-font-lock s1 10 font-lock-string-face)
    (julia-ts--should-font-lock s1 14 nil)
    (julia-ts--should-font-lock s2 4 font-lock-string-face)
    (julia-ts--should-font-lock s2 9 font-lock-string-face)
    (julia-ts--should-font-lock s2 13 nil)
    (julia-ts--should-font-lock s3 4 font-lock-string-face)
    (julia-ts--should-font-lock s3 8 font-lock-string-face)
    (julia-ts--should-font-lock s3 12 nil)
    (julia-ts--should-font-lock s4 5 font-lock-string-face)
    (julia-ts--should-font-lock s4 10 font-lock-string-face)
    (julia-ts--should-font-lock s4 14 nil)))

(ert-deftest julia-ts--test-ccall-font-lock ()
  (let ((s1 "t = ccall(:clock, Int32, ())"))
    (julia-ts--should-font-lock s1 5 font-lock-builtin-face)
    (julia-ts--should-font-lock s1 4 nil)
    (julia-ts--should-font-lock s1 10 nil)))

(ert-deftest julia-ts--test-char-const-font-lock ()
  (dolist (c '("'\\''"
               "'\\\"'"
               "'\\\\'"
               "'\\010'"
               "'\\xfe'"
               "'\\uabcd'"
               "'\\Uabcdef01'"
               "'\\n'"
               "'a'" "'z'" "'''"))
    (let ((c (format " %s " c)))
      (progn
        (julia-ts--should-font-lock c 1 nil)
        (julia-ts--should-font-lock c 2 font-lock-string-face)
        (julia-ts--should-font-lock c (- (length c) 1) font-lock-string-face)
        (julia-ts--should-font-lock c (length c) nil)))))

(ert-deftest julia-ts--test-const-def-font-lock ()
  (let ((string "const foo = \"bar\""))
    (julia-ts--should-font-lock string 1 font-lock-keyword-face) ; const
    (julia-ts--should-font-lock string 5 font-lock-keyword-face) ; const
    (julia-ts--should-font-lock string 7 font-lock-variable-name-face) ; foo
    (julia-ts--should-font-lock string 9 font-lock-variable-name-face) ; foo
    (julia-ts--should-font-lock string 11 nil) ; =
    ))

(ert-deftest julia-ts--test-const-def-font-lock-underscores ()
  (let ((string "@macro const foo_bar = \"bar\""))
    (julia-ts--should-font-lock string 8 font-lock-keyword-face) ; const
    (julia-ts--should-font-lock string 12 font-lock-keyword-face) ; const
    (julia-ts--should-font-lock string 14 font-lock-variable-name-face) ; foo
    (julia-ts--should-font-lock string 17 font-lock-variable-name-face) ; _
    (julia-ts--should-font-lock string 20 font-lock-variable-name-face) ; bar
    (julia-ts--should-font-lock string 22 nil) ; =
    ))

(ert-deftest julia-ts--test-!-font-lock ()
  (let ((string "!@macro foo()"))
    (julia-ts--should-font-lock string 1 nil)
    (julia-ts--should-font-lock string 2 'julia-ts-macro-face)
    (julia-ts--should-font-lock string 7 'julia-ts-macro-face)
    (julia-ts--should-font-lock string 8 nil)))

;;; Movement
(ert-deftest julia-ts--test-beginning-of-defun-assn-1 ()
  "Point moves to beginning of single-line assignment function."
  (julia-ts--should-move-point
    "f() = \"a + b\"" 'beginning-of-defun "a \\+" 1))

(ert-deftest julia-ts--test-beginning-of-defun-assn-2 ()
  "Point moves to beginning of multi-line assignment function."
  (julia-ts--should-move-point
    "f(x)=
    x*
    x" 'beginning-of-defun "x$" 1))

(ert-deftest julia-ts--test-beginning-of-defun-assn-3 ()
  "Point moves to beginning of multi-line assignment function adjoining
another function."
  (julia-ts--should-move-point
    "f( x 
)::Int16 = x / 2
f2(y)=
y*y" 'beginning-of-defun "2" 1))

(ert-deftest julia-ts--test-beginning-of-defun-assn-4 ()
  "Point moves to beginning of 2nd multi-line assignment function adjoining
another function."
  (julia-ts--should-move-point
    "f( x 
)::Int16 = 
x /
2
f2(y) =
y*y" 'beginning-of-defun "\\*y" "f2"))

(ert-deftest julia-ts--test-beginning-of-defun-assn-5 ()
  "Point moves to beginning of 1st multi-line assignment function adjoining
another function with prefix arg."
  (julia-ts--should-move-point
    "f( x 
)::Int16 = 
x /
2
f2(y) =
y*y" 'beginning-of-defun "y\\*y" 1 nil 2))

(ert-deftest julia-ts--test-beginning-of-macro ()
  "Point moves to beginning of macro."
  (julia-ts--should-move-point
    "macro current_module()
return VERSION >= v\"0.7-\" :(@__MODULE__) : :(current_module())))
end" 'beginning-of-defun "@" 1))

(ert-deftest julia-ts--test-beginning-of-defun-1 ()
  "Point moves to beginning of defun in 'function's."
  (julia-ts--should-move-point
    "function f(a, b)
a + b
end" 'beginning-of-defun "f(" 1))

(ert-deftest julia-ts--test-beginning-of-defun-nested-1 ()
  "Point moves to beginning of nested function."
  (julia-ts--should-move-point
    "function f(x)

function fact(n)
if n == 0
return 1
else
return n * fact(n-1)
end
end

return fact(x)
end" 'beginning-of-defun "fact(n" "function fact"))

(ert-deftest julia-ts--test-beginning-of-defun-nested-2 ()
  "Point moves to beginning of outermost function with prefix arg."
  (julia-ts--should-move-point
    "function f(x)

function fact(n)
if n == 0
return 1
else
return n * fact(n-1)
end
end

return fact(x)
end" 'beginning-of-defun "n \\*" 1 nil 2))

(ert-deftest julia-ts--test-beginning-of-defun-no-move ()
  "Point shouldn't move if there is no previous function."
  (julia-ts--should-move-point
    "1 + 1
f(x) = x + 1" 'beginning-of-defun "\\+" 4))

(ert-deftest julia-ts--test-end-of-defun-assn-1 ()
  "Point should move to end of assignment function."
  (julia-ts--should-move-point
    "f(x)::Int8 = 
x *x" 'end-of-defun "(" "*x" 'end))

(ert-deftest julia-ts--test-end-of-defun-nested-1 ()
  "Point should move to end of inner function when called from inner."
  (julia-ts--should-move-point
    "function f(x)
function fact(n)
if n == 0
return 1
else
return n * fact(n-1)
end
end
return fact(x)
end" 'julia-end-of-defun "function fact(n)" "end[ \n]+end" 'end))

(ert-deftest julia-ts--test-end-of-defun-nested-2 ()
  "Point should move to end of outer function when called from outer."
  (julia-ts--should-move-point
    "function f(x)
function fact(n)
if n == 0
return 1
else
return n * fact(n-1)
end
end
return fact(x)
end" 'julia-end-of-defun "function f(x)" "return fact(x)[ \n]+end" 'end))

;;;
;;; run all tests
;;;

(defun julia-ts--run-tests ()
  (interactive)
  (if (featurep 'ert)
      (ert-run-tests-interactively "julia-ts--test")
    (message "Can't run julia-ts-mode-tests because ert is not available.")))

(provide 'julia-ts-mode-tests)
;; Local Variables:
;; coding: utf-8
;; byte-compile-warnings: (not obsolete)
;; End:
;;; julia-ts-mode-tests.el ends here