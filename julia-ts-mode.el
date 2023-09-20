;;; julia-ts-mode.el --- Major mode for Julia source code using tree-sitter -*- lexical-binding: t; -*-

;; Copyright (C) 2022, 2023  Ronan Arraes Jardim Chagas
;;
;; Author           : Ronan Arraes Jardim Chagas
;; Created          : December 2022
;; Keywords         : julia languages tree-sitter
;; Package-Requires : ((emacs "29") (julia-mode "0.4"))
;; URL              : https://github.com/ronisbr/julia-ts-mode
;; Version          : 0.2.5
;;
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
;;
;;; Commentary:
;; This major modes uses tree-sitter for font-lock, indentation, imenu, and
;; navigation. It is derived from `julia-mode'.

;;;; Code:

(require 'treesit)
(eval-when-compile (require 'rx))
(require 'julia-mode)

(declare-function treesit-parser-create "treesit.c")

(defgroup julia-ts nil
  "Major mode for the julia programming language using tree-sitter."
  :group 'languages
  :prefix "julia-ts-")
;; Notice that all custom variables and faces are automatically added to the
;; most recent group.

(defcustom julia-ts-align-argument-list-to-first-sibling nil
  "Align the argument list to the first sibling.

If it is set to t, the following indentation is used:

    myfunc(a, b,
           c, d)

Otherwise, the indentation is:

    myfunc(a, b
        c, d)"
  :version "29.1"
  :type 'boolean)

(defcustom julia-ts-align-assignment-expressions-to-first-sibling nil
  "Align the expressions after an assignment to the first sibling.

If it is set to t, the following indentation is used:

    var = a + b + c +
          d + e +
          f

Otherwise, the indentation is:

    var = a + b + c +
        d + e +
        f"
  :version "29.1"
  :type 'boolean)

(defcustom julia-ts-align-parameter-list-to-first-sibling nil
  "Align the parameter list to the first sibling.

If it is set to t, the following indentation is used:

    function myfunc(a, b,
                    c, d)

Otherwise, the indentation is:

    function myfunc(a, b,
        c, d)"
  :version "29.1"
  :type 'boolean)

(defcustom julia-ts-align-curly-brace-expressions-to-first-sibling nil
  "Align curly brace expressions to the first sibling.

If it is set to t, the following indentation is used:

    MyType{A, B,
           C, D}

Otherwise, the indentation is:

    MyType{A, B
        C, D}"
  :version "29.1"
  :type 'boolean)

(defcustom julia-ts-align-type-parameter-list-to-first-sibling nil
  "Align type parameter lists to the first sibling.

If it is set to t, the following indentation is used:

    struct MyType{A, B
                  C, D}

Otherwise, the indentation is:

    struct MyType{A, B,
        C, D}"
  :version "29.1"
  :type 'boolean)

(defcustom julia-ts-indent-offset 4
  "Number of spaces for each indentation step in `julia-ts-mode'."
  :version "29.1"
  :type 'integer
  :safe 'intergerp)

(defface julia-ts-macro-face
  '((t :inherit font-lock-preprocessor-face))
  "Face for Julia macro invocations in `julia-ts-mode'.")

(defface julia-ts-quoted-symbol-face
  '((t :inherit font-lock-constant-face))
  "Face for quoted Julia symbols in `julia-ts-mode', e.g. :foo.")

(defface julia-ts-interpolation-expression-face
  '((t :inherit font-lock-constant-face))
  "Face for interpolation expressions in `julia-ts-mode', e.g. :foo.")

(defface julia-ts-string-interpolation-face
  '((t :inherit font-lock-constant-face :weight bold))
  "Face for string interpolations in `julia-ts-mode', e.g. :foo.")

(defvar julia-ts--keywords
  '("baremodule" "begin" "catch" "const" "do" "else" "elseif" "end" "export"
    "finally" "for" "function" "global" "if" "in" "let" "local" "macro" "module"
    "quote" "return" "try" "where" "while")
  "Keywords for `julia-ts-mode'.")

(defvar julia-ts--treesit-font-lock-settings
  (treesit-font-lock-rules
   :language 'julia
   :feature 'assignment
   `((assignment (identifier) @font-lock-variable-name-face (_))
     (assignment
      (field_expression (identifier) "." (identifier) @font-lock-variable-name-face)
      (operator))
     (assignment (bare_tuple (identifier) @font-lock-variable-name-face))
     (assignment
      (bare_tuple
       (field_expression (identifier) "." (identifier) @font-lock-variable-name-face))
      (operator))
     (local_statement (identifier) @font-lock-variable-name-face)
     (let_binding (identifier) @font-lock-variable-name-face)
     (global_statement (identifier) @font-lock-variable-name-face))

   :language 'julia
   :feature 'constant
   `((quote_expression) @julia-ts-quoted-symbol-face
     ((identifier) @font-lock-builtin-face
      (:match
       "^\\(:?NaN\\|NaN16\\|NaN32\\|NaN64\\|Inf\\|Inf16\\|Inf32\\|Inf64\\|nothing\\|missing\\|undef\\)$"
       @font-lock-builtin-face)))

   :language 'julia
   :feature 'comment
   `((line_comment) @font-lock-comment-face
     (block_comment) @font-lock-comment-face)

   :language 'julia
   :feature 'definition
   `((function_definition
      name: (identifier) @font-lock-function-name-face)
     (function_definition
      name: (field_expression (identifier) "." (identifier) @font-lock-function-name-face))
     (macro_definition
      name: (identifier) @font-lock-function-name-face)
     (short_function_definition
      name: (identifier) @font-lock-function-name-face)
     (short_function_definition
      name: (field_expression (identifier) "." (identifier) @font-lock-function-name-face)))

   :language 'julia
   :feature 'error
   :override t
   `((ERROR) @font-lock-warning-face)

   :language 'julia
   :feature 'interpolation
   :override 'append
   `((interpolation_expression) @julia-ts-interpolation-expression-face
     (string_interpolation) @julia-ts-string-interpolation-face)

   :language 'julia
   :feature 'keyword
   `((abstract_definition) @font-lock-keyword-face
     (break_statement) @font-lock-keyword-face
     (continue_statement) @font-lock-keyword-face
     (for_binding "in" @font-lock-keyword-face)
     (import_statement ["import" "using"] @font-lock-keyword-face)
     ((vector_expression
       (range_expression
        (identifier) @font-lock-keyword-face
        (:match "^\\(:?begin\\|end\\)$" @font-lock-keyword-face))))
     (struct_definition ["mutable" "struct"] @font-lock-keyword-face)
     ([,@julia-ts--keywords]) @font-lock-keyword-face)

   :language 'julia
   :feature 'literal
   `([(boolean_literal)
      (character_literal)
      (integer_literal)
      (float_literal)] @font-lock-constant-face)

   :language 'julia
   :feature 'macro_call
   `((macro_identifier) @julia-ts-macro-face)

   :language 'julia
   :feature 'operator
   `((adjoint_expression "'" @font-lock-type-face)
     (let_binding "=" @font-lock-type-face)
     (for_binding ["=" "∈"] @font-lock-type-face)
     (function_expression "->" @font-lock-type-face)
     (operator) @font-lock-type-face
     (slurp_parameter "..." @font-lock-type-face)
     (splat_expression "..." @font-lock-type-face)
     (ternary_expression ["?" ":"] @font-lock-type-face)
     (["." "::"] @font-lock-type-face))

   :language 'julia
   :feature 'string
   :override 'append
   `([(command_literal)
      (prefixed_command_literal)
      (string_literal)
      (prefixed_string_literal)] @font-lock-string-face)

   ;; We need to override this feature because otherwise in statements like:
   ;;     a::Union{Int, NTuple{4, Char}}
   ;; the type is not fontified correctly due to the integer literal.
   :language 'julia
   :feature 'type
   :override t
   `((type_clause (operator) (_) @font-lock-type-face)
     (typed_expression (_) "::" (_) @font-lock-type-face)
     (typed_parameter
      type: (_) @font-lock-type-face)
     (where_clause "where"
                   (curly_expression "{"
                                     (binary_expression (identifier)
                                                        (operator)
                                                        (_)
                                                        @font-lock-type-face)))))
  "Tree-sitter font-lock settings for `julia-ts-mode'.")

(defun julia-ts--ancestor-is (regexp)
  "Return the ancestor of NODE that matches `REGEXP', if it exists."
  (lambda (node &rest _)
    (treesit-parent-until
     node
     (lambda (node)
       (string-match-p regexp (treesit-node-type node))))))

(defun julia-ts--grand-parent-bol (_n parent &rest _)
  "Return the beginning of the line (non-space char) where the node's PARENT is on."
  (save-excursion
    (goto-char (treesit-node-start (treesit-node-parent parent)))
    (back-to-indentation)
    (point)))

(defun julia-ts--grand-parent-first-sibling (_n parent &rest _)
  "Return the start of the first child of the parent of the node PARENT."
  (treesit-node-start (treesit-node-child (treesit-node-parent parent) 0)))

(defun julia-ts--line-beginning-position-of-point (point)
  "Return the position of the beginning of the line of POINT."
  (save-mark-and-excursion
    (goto-char point)
    (line-beginning-position)))

(defun julia-ts--same-line? (point-1 point-2)
  "Return t if POINT-1 and POINT-2 are on the same line."
  (equal (julia-ts--line-beginning-position-of-point point-1)
         (julia-ts--line-beginning-position-of-point point-2)))

(defun julia-ts--parent-is-and-sibling-on-same-line (parent-type sibling-index)
  "Check the type of the node's parent and if a sibling is on the same line.

Return t if the node's parent type is PARENT-TYPE and if the sibling with index
SIBLING-INDEX is on the same line of the current node's parent.

This allows indentation rules to be matched based on whether the children of the
parent start on the same line as the parent.

The SIBLING-INDEX is required because the first few siblings may be part of the
syntax. For example, in an assignment expression, the first sibling is the
identifier being assigned to, the second sibling is the operator, and the third
child is the beginning of the right hand side of the expression. In that case,
we want to know if the third sibling is on the same line as the parent.

This is intended to be used as a matcher for `treesit-simple-indent-rules'."
  (lambda (_node parent &rest _)
    (and (string-match-p (treesit-node-type parent) parent-type)
         (julia-ts--same-line? (treesit-node-start parent)
                               (treesit-node-start (treesit-node-child parent sibling-index))))))

(defun julia-ts--parent-is-and-sibling-not-on-same-line (parent-type sibling-index)
  "Check the type of the node's parent and if a sibling is on the same line.

Return t if the node's parent type is PARENT-TYPE and if the sibling with index
SIBLING-INDEX is not on the same line of the current node's parent.

This allows indentation rules to be matched based on whether the children of the
parent start on the same line as the parent.

The SIBLING-INDEX is required because the first few siblings may be part of the
syntax. For example, in an assignment expression, the first sibling is the
identifier being assigned to, the second sibling is the operator, and the third
child is the beginning of the right hand side of the expression. In that case,
we want to know if the third sibling is on the same line as the parent.

This is intended to be used as a matcher for `treesit-simple-indent-rules'."
  (lambda (_node parent &rest _)
    (and (string-match-p (treesit-node-type parent) parent-type)
         (not (julia-ts--same-line? (treesit-node-start parent)
                                    (treesit-node-start (treesit-node-child parent sibling-index)))))))

(defvar julia-ts--treesit-indent-rules
  `((julia
     ((parent-is "abstract_definition") parent-bol 0)
     ((parent-is "module_definition") parent-bol 0)
     ((node-is "end") (and parent parent-bol) 0)
     ((node-is "elseif") parent-bol 0)
     ((node-is "else") parent-bol 0)
     ((node-is "catch") parent-bol 0)
     ((node-is "finally") parent-bol 0)
     ((node-is ")") parent-bol 0)
     ((node-is "]") parent-bol 0)
     ((node-is "}") parent-bol 0)

     ;; Alignment of parenthesized expressions.
     ((parent-is "parenthesized_expression") parent-bol julia-ts-indent-offset)

     ;; Alignment of tuples.
     ((julia-ts--parent-is-and-sibling-on-same-line "tuple_expression" 1) first-sibling 1)
     ((julia-ts--parent-is-and-sibling-not-on-same-line "tuple_expression" 1) parent-bol julia-ts-indent-offset)

     ;; Alignment of arrays.
     ((julia-ts--parent-is-and-sibling-on-same-line "vector_expression" 1) first-sibling 1)
     ((julia-ts--parent-is-and-sibling-not-on-same-line "vector_expression" 1) parent-bol julia-ts-indent-offset)
     ((julia-ts--parent-is-and-sibling-on-same-line "matrix_expression" 1) first-sibling 1)
     ((julia-ts--parent-is-and-sibling-not-on-same-line "matrix_expression" 1) parent-bol julia-ts-indent-offset)

     ;; Alignment of curly brace expressions.
     ,(if julia-ts-align-curly-brace-expressions-to-first-sibling
          `((julia-ts--parent-is-and-sibling-on-same-line "curly_expression" 1) first-sibling 1)
        `((julia-ts--parent-is-and-sibling-on-same-line "curly_expression" 1) parent-bol julia-ts-indent-offset))
     ((julia-ts--parent-is-and-sibling-not-on-same-line "curly_expression" 1) parent-bol julia-ts-indent-offset)

     ;; Match if the node is inside an assignment.
     ,(if julia-ts-align-assignment-expressions-to-first-sibling
          ;; The identifier is the first sibling, = is the second sibling, and
          ;; the first part of the RHS is the third sibling.
          `((julia-ts--parent-is-and-sibling-on-same-line "assignment" 2) (nth-sibling 1) 2)
        `((julia-ts--parent-is-and-sibling-on-same-line "assignment" 2) parent-bol julia-ts-indent-offset))
     ((julia-ts--parent-is-and-sibling-not-on-same-line "assignment" 2) parent-bol julia-ts-indent-offset)

     ;; Align the expressions in the if statement conditions.
     ((julia-ts--ancestor-is "if_statement") parent-bol julia-ts-indent-offset)

     ;; For all other expressions, keep the indentation as the parent.
     ((parent-is "_expression") parent 0)

     ;; General indentation rules for blocks.
     ((parent-is "_statement") parent-bol julia-ts-indent-offset)
     ((parent-is "_definition") parent-bol julia-ts-indent-offset)
     ((parent-is "_clause") parent-bol julia-ts-indent-offset)

     ;; Alignment of argument lists.
     ,(if julia-ts-align-argument-list-to-first-sibling
          `((julia-ts--parent-is-and-sibling-on-same-line "argument_list" 1) first-sibling 1)
        `((julia-ts--parent-is-and-sibling-on-same-line "argument_list" 1) parent-bol julia-ts-indent-offset))
     ((julia-ts--parent-is-and-sibling-not-on-same-line "argument_list" 1) parent-bol julia-ts-indent-offset)

     ;; Alignment of parameter lists.
     ,(if julia-ts-align-parameter-list-to-first-sibling
          `((julia-ts--parent-is-and-sibling-on-same-line "parameter_list" 1) first-sibling 1)
        `((julia-ts--parent-is-and-sibling-on-same-line "parameter_list" 1) parent-bol julia-ts-indent-offset))
     ((julia-ts--parent-is-and-sibling-not-on-same-line "parameter_list" 1) parent-bol julia-ts-indent-offset)

     ;; Alignment of type parameter lists.
     ,(if julia-ts-align-argument-list-to-first-sibling
          `((julia-ts--parent-is-and-sibling-on-same-line "type_parameter_list" 1) first-sibling 1)
        `((julia-ts--parent-is-and-sibling-on-same-line "type_parameter_list" 1) parent-bol julia-ts-indent-offset))
     ((julia-ts--parent-is-and-sibling-not-on-same-line "type_parameter_list" 1) parent-bol julia-ts-indent-offset)

     ;; The keyword parameters is a child of parameter list. Hence, we need to
     ;; consider its grand parent to perform the alignment.
     ,@(if julia-ts-align-parameter-list-to-first-sibling
           (list '((n-p-gp nil "keyword_parameters" "parameter_list")
                   julia-ts--grand-parent-first-sibling
                   1))
         (list '((n-p-gp nil "keyword_parameters" "parameter_list")
                 julia-ts--grand-parent-bol
                 julia-ts-indent-offset)))

     ;; This rule takes care of blank lines most of the time.
     (no-node parent-bol 0)))
  "Tree-sitter indent rules for `julia-ts-mode'.")

(defun julia-ts--defun-name (node)
  "Return the defun name of NODE.
Return nil if there is no name or if NODE is not a defun node."
  (pcase (treesit-node-type node)
    ((or "abstract_definition"
         "function_definition"
         "short_function_definition"
         "struct_definition")
     (treesit-node-text
      (treesit-node-child-by-field-name node "name")
      t))))

;;;###autoload
(add-to-list 'auto-mode-alist '("\\.jl\\'" . julia-ts-mode))

;;;###autoload
(define-derived-mode julia-ts-mode julia-mode "Julia (TS)"
  "Major mode for Julia files using tree-sitter."
  :group 'julia

  (unless (treesit-ready-p 'julia)
    (error "Tree-sitter for Julia is not available"))

  ;; Override the functions in `julia-mode' that are not needed when using
  ;; tree-sitter.
  (setq-local syntax-propertize-function nil)
  (setq-local indent-line-function nil)

  (treesit-parser-create 'julia)

  ;; Comments.
  (setq-local comment-start "# ")
  (setq-local comment-end "")
  (setq-local comment-start-skip (rx "#" (* (syntax whitespace))))

  ;; Indent.
  (setq-local treesit-simple-indent-rules julia-ts--treesit-indent-rules)

  ;; Navigation.
  (setq-local treesit-defun-type-regexp
              (rx (or "function_definition"
                      "struct_definition")))
  (setq-local treesit-defun-name-function #'julia-ts--defun-name)

  ;; Imenu.
  (setq-local treesit-simple-imenu-settings
              `(("Function" "\\`function_definition\\|short_function_definition\\'" nil nil)
                ("Struct" "\\`struct_definition\\'" nil nil)))

  ;; Fontification
  (setq-local treesit-font-lock-settings julia-ts--treesit-font-lock-settings)
  (setq-local treesit-font-lock-feature-list
              '((comment definition)
                (constant keyword string type)
                (assignment literal interpolation macro_call)
                (error operator)))

  (treesit-major-mode-setup))

(provide 'julia-ts-mode)

;; Local Variables:
;; coding: utf-8
;; byte-compile-warnings: (not obsolete)
;; End:
;;; julia-ts-mode.el ends here
