;;; julia-ts-mode.el --- Major mode for Julia source code using tree-sitter -*- lexical-binding: t; -*-

;; Copyright (C) 2022  Ronan Arraes Jardim Chagas
;; URL: https://github.com/ronisbr/julia-ts-mode
;; Version: 0.0.1
;; Keywords: languages
;; Package-Requires: ((emacs "29"))

;;; Usage:
;; 1. Install the Julia tree-sitter grammar.
;; 2. Put the following code in your .emacs, site-load.el, or other relevant
;;    file:
;; (add-to-list 'load-path "path-to-julia-ts-mode")
;; (require 'julia-ts-mode)

;;; Commentary:
;; This version is highly experimental.

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

(require 'treesit)

(declare-function treesit-parser-create "treesit.c")

(defcustom julia-ts-mode-align-parameter-list-to-first-sibling nil
  "Align the parameter list to the first sibling.

If it is set to `t', the following indentation is used:

    function myfunc(a,
                    b,
                    c)

Otherwise, the indentation is:

    function myfunc(
        a,
        b,
        c
    )
"
  :version "29"
  :type 'boolean
  :group 'julia)

(defcustom julia-ts-mode-indent-offset 4
  "Number of spaces for each indentation step in `julia-ts-mode'."
  :version "29"
  :type 'integer
  :safe 'intergerp
  :group 'julia)

(defface julia-ts-mode-macro-face
  '((t :inherit font-lock-preprocessor-face))
  "Face for Julia macro invocations in `julia-ts-mode'.")

(defface julia-ts-mode-quoted-symbol-face
  '((t :inherit font-lock-constant-face))
  "Face for quoted Julia symbols in `julia-ts-mode', e.g. :foo.")

;; The syntax table was copied from the `julia-mode'.
(defvar julia-ts-mode--syntax-table
  (let ((table (make-syntax-table)))
    (modify-syntax-entry ?_ "_" table)
    (modify-syntax-entry ?@ "_" table)
    (modify-syntax-entry ?! "_" table)
    (modify-syntax-entry ?# "< 14" table)  ; # single-line and multiline start
    (modify-syntax-entry ?= ". 23bn" table)
    (modify-syntax-entry ?\n ">" table)  ; \n single-line comment end
    (modify-syntax-entry ?\{ "(} " table)
    (modify-syntax-entry ?\} "){ " table)
    (modify-syntax-entry ?\[ "(] " table)
    (modify-syntax-entry ?\] ")[ " table)
    (modify-syntax-entry ?\( "() " table)
    (modify-syntax-entry ?\) ")( " table)
    ;; Here, we treat ' as punctuation (when it's used for transpose),
    ;; see our use of `julia-char-regex' for handling ' as a character
    ;; delimiter
    (modify-syntax-entry ?'  "." table)
    (modify-syntax-entry ?\" "\"" table)
    (modify-syntax-entry ?` "\"" table)
    ;; Backslash has escape syntax for use in strings but
    ;; julia-syntax-propertize-function sets punctuation syntax on it
    ;; outside strings.
    (modify-syntax-entry ?\\ "\\" table)

    (modify-syntax-entry ?. "." table)
    (modify-syntax-entry ?? "." table)
    (modify-syntax-entry ?$ "." table)
    (modify-syntax-entry ?& "." table)
    (modify-syntax-entry ?* "." table)
    (modify-syntax-entry ?/ "." table)
    (modify-syntax-entry ?+ "." table)
    (modify-syntax-entry ?- "." table)
    (modify-syntax-entry ?< "." table)
    (modify-syntax-entry ?> "." table)
    (modify-syntax-entry ?% "." table)

    (modify-syntax-entry ?′ "w" table) ; \prime is a word constituent
    table)
  "Syntax table for `julia-ts-mode'.")

(defvar julia-ts-mode--keywords
  '("baremodule" "begin" "catch" "const" "do" "else" "elseif" "end" "export"
    "finally" "for" "function" "global" "if" "let" "local" "macro" "quote"
    "return" "try" "where" "while" )
  "Keywords for `julia-ts-mode'.")

(defvar julia-ts-mode--treesit-font-lock-settings
  (treesit-font-lock-rules
   :language 'julia
   :feature 'constant
   `((quote_expression) @julia-ts-mode-quoted-symbol-face
     ((identifier) @font-lock-builtin-face
      (:match
       "^\\(:?NaN\\|NaN16\\|NaN32\\|NaN64\\|nothing\\|missing\\|undef\\)$"
       @font-lock-builtin-face)))

   :language 'julia
   :feature 'comment
   `((line_comment) @font-lock-comment-face)

   :language 'julia
   :feature 'definition
   `((function_definition
      name: (identifier) @font-lock-function-name-face)
     (macro_definition
      name: (identifier) @font-lock-function-name-face))

   :language 'julia
   :feature 'keyword
   `((abstract_definition) @font-lock-keyword-face
     (import_statement ["import" "using"] @font-lock-keyword-face)
     (struct_definition ["mutable" "struct"] @font-lock-keyword-face)
     ([,@julia-ts-mode--keywords]) @font-lock-keyword-face)

   :language 'julia
   :feature 'literal
   `([(boolean_literal)
      (character_literal)
      (integer_literal)
      (float_literal)] @font-lock-constant-face)

   :language 'julia
   :feature 'macro_call
   `((macro_identifier) @julia-ts-mode-macro-face)

   :language 'julia
   :feature 'operator
   `((operator) @font-lock-type-face
     (ternary_expression ["?" ":"] @font-lock-type-face))

   :language 'julia
   :feature 'string
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
   `((type_clause "<:" (_) @font-lock-type-face)
     (typed_expression (identifier) "::" (_) @font-lock-type-face)
     (typed_parameter
      type: (_) @font-lock-type-face)
     (where_clause "where"
                   (curly_expression "{"
                                     (binary_expression (identifier)
                                                        (operator)
                                                        (_)
                                                        @font-lock-type-face)))))
  "Tree-sitter font-lock settings for `julia-ts-mode'.")

(defvar julia-ts-mode--treesit-indent-rules
  `((julia
     ((parent-is "abstract_definition") parent-bol 0)
     ((node-is "end") (and parent parent-bol) 0)
     ((node-is "elseif") parent-bol 0)
     ((node-is "else") parent-bol 0)
     ((node-is "catch") parent-bol 0)
     ((node-is "finally") parent-bol 0)
     ((node-is ")") parent-bol 0)
     ((node-is "]") parent-bol 0)
     ((parent-is "_statement") parent-bol julia-ts-mode-indent-offset)
     ((parent-is "_definition") parent-bol julia-ts-mode-indent-offset)
     ((parent-is "_expression") parent-bol julia-ts-mode-indent-offset)
     ((parent-is "_clause") parent-bol julia-ts-mode-indent-offset)
     ,@(if julia-ts-mode-align-parameter-list-to-first-sibling
           (list '((parent-is "parameter_list") first-sibling 1))
         (list '((parent-is "parameter_list") parent-bol julia-ts-mode-indent-offset)))

     ;; This rule takes care of blank lines most of the time.
     (no-node parent-bol 0)))
  "Tree-sitter indent rules for `julia-ts-mode'.")

;; This function was adapted from the version in `go-ts-mode'.
(defun julia-ts-mode--imenu ()
  "Return Imenu alist for the current buffer."
  (let* ((node (treesit-buffer-root-node))
         (abst-tree (treesit-induce-sparse-tree
                     node "abstract_definition"))
         (func-tree (treesit-induce-sparse-tree
                     node "function_definition"))
         (struct-tree (treesit-induce-sparse-tree
                     node "struct_definition"))
         (abst-index (julia-ts-mode--imenu-1 abst-tree))
         (func-index (julia-ts-mode--imenu-1 func-tree))
         (struct-index (julia-ts-mode--imenu-1 struct-tree)))
    (append
     (when abst-index `(("Abstract type" . ,abst-index)))
     (when func-index `(("Function" . ,func-index)))
     (when struct-index `(("Structure" . ,struct-index))))))

;; This function was adapted from the version in `go-ts-mode'.
(defun julia-ts-mode--imenu-1 (node)
  "Helper for `julia-ts-mode--imenu'.
Find string representation for NODE and set marker, then recurse the subtrees."
  (let* ((ts-node (car node))
         (children (cdr node))
         (subtrees (mapcan #'julia-ts-mode--imenu-1
                           children))
         (name (when ts-node
                 (treesit-node-text
                  (pcase (treesit-node-type ts-node)
                    ("abstract_definition"
                     (treesit-node-child-by-field-name ts-node "name"))
                    ("function_definition"
                     (treesit-node-child-by-field-name ts-node "name"))
                    ("struct_definition"
                     (treesit-node-child-by-field-name ts-node "name"))))))
         (marker (when ts-node
                   (set-marker (make-marker)
                               (treesit-node-start ts-node)))))
    (cond
     ((or (null ts-node) (null name)) subtrees)
     (subtrees
      `((,name ,(cons name marker) ,@subtrees)))
     (t
      `((,name . ,marker))))))

;;;###autoload
(define-derived-mode julia-ts-mode prog-mode "Julia"
  "Major mode for Julia files using tree-sitter"
  :group 'julia
  :syntax-table julia-ts-mode--syntax-table

  (unless (treesit-ready-p 'julia)
    (error "Tree-sitter for Julia is not available"))

  (set-electric! 'julia-ts-mode
    :words '("catch"
             "else"
             "elseif"
             "finally"
             "end"))

  (treesit-parser-create 'julia)

  ;; Imenu.
  (setq-local imenu-create-index-function #'julia-ts-mode--imenu)

  ;; Indent.
  (setq-local treesit-simple-indent-rules julia-ts-mode--treesit-indent-rules)

  ;; Navigation.
  (setq-local treesit-defun-prefer-top-level t)
  (setq-local treesit-defun-type-regexp
              (rx (or "function_definition"
                      "struct_definition")))

  ;; Fontification
  (setq-local treesit-font-lock-settings julia-ts-mode--treesit-font-lock-settings)
  (setq-local treesit-font-lock-feature-list
              '((comment definition)
                (constant keyword string type)
                (literal macro_call)
                (operator)))

  (treesit-major-mode-setup))

;;;###autoload
(add-to-list 'auto-mode-alist '("\\.jl\\'" . julia-ts-mode))

(provide 'julia-ts-mode)

;; Local Variables:
;; coding: utf-8
;; byte-compile-warnings: (not obsolete)
;; End:
;;; julia-ts-mode.el ends here
