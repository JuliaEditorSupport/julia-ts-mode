# Julia major mode using tree-sitter

Emacs major mode for the Julia programming language using tree-sitter for
font-lock, indentation, imenu, and navigation. It is derived from
[`julia-mode`](https://github.com/JuliaEditorSupport/julia-emacs).

# Installation

## Dependencies

This package requires:

1. Emacs 29 or newer built with tree-sitter support;
2. [Julia tree-sitter grammar](https://github.com/tree-sitter/tree-sitter-julia); and
3. The package [`julia-mode`](https://github.com/JuliaEditorSupport/julia-emacs).

## Installation from MELPA

Coming soon.

## Installation from source

You can install this package from source by cloning this directory and adding
the following lines to your Emacs configuration:

``` emacs-lisp
(add-to-list 'load-path "<path to the source-code tree>")
(require 'julia-ts-mode)
```

# LSP Configuration

This mode is derived from `julia-mode`. Hence, most of the feature available for
it will also work in `julia-ts-mode`. However, the LSP requires additional
configuration. First, it is necessary to install the package
[`lsp-julia`](https://github.com/gdkrmr/lsp-julia), and apply the desired
configuration as stated in its documentation. Afterward, add the following code
to your Emacs configuration file:

``` emacs-lisp
(add-to-list 'lsp-language-id-configuration '(julia-ts-mode . "julia"))
(lsp-register-client
(make-lsp-client :new-connection (lsp-stdio-connection 'lsp-julia--rls-command)
                 :major-modes '(julia-mode ess-julia-mode julia-ts-mode)
                 :server-id 'julia-ls
                 :multi-root t))
```
