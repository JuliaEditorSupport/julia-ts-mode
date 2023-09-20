;;; julia-ts-misc.el --- Miscellaneous functions for the julia-ts-mode -*- lexical-binding: t; -*-

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
;; This file defines miscellaneous functions used in the `julia-ts-mode'.

;;;; Code:

(defun julia-ts--ancestor-bol (regexp)
  "Return the BOL of the current node's ancestor that matches REGEXP."
  (lambda (node &rest _)
      (treesit-node-start (julia-ts--ancestor-node node regexp))))

(defun julia-ts--ancestor-is (regexp)
  "Return the ancestor of NODE that matches `REGEXP', if it exists."
  (lambda (node &rest _)
    (julia-ts--ancestor-node node regexp)))

(defun julia-ts--ancestor-is-and-sibling-on-same-line (ancestor-type sibling-index)
  "Check the type of the node's ancestor and if a sibling is on the same line.

Return t if the node's ancestor type is ANCESTOR-TYPE and if the sibling with
index SIBLING-INDEX is on the same line of the ancestor."
  (lambda (node &rest _)
    (let ((ancestor (julia-ts--ancestor-node node ancestor-type)))
      (and ancestor
           (julia-ts--same-line? (treesit-node-start ancestor)
                                 (treesit-node-start (treesit-node-child ancestor sibling-index)))))))

(defun julia-ts--ancestor-is-and-sibling-not-on-same-line (ancestor-type sibling-index)
  "Check the type of the node's ancestor and if a sibling is not on the same line.

Return t if the node's ancestor type is ANCESTOR-TYPE and if the sibling with
index SIBLING-INDEX is not on the same line of the ancestor."
  (lambda (node &rest _)
    (let ((ancestor (julia-ts--ancestor-node node ancestor-type)))
      (and ancestor
           (not (julia-ts--same-line? (treesit-node-start ancestor)
                                      (treesit-node-start (treesit-node-child ancestor sibling-index))))))))

(defun julia-ts--ancestor-node (node regexp)
  "Return the ancestor NODE that matches REGEXP, if it exists."
  (treesit-parent-until node
                        (lambda (node)
                          (string-match-p regexp (treesit-node-type node)))))

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

(defun julia-ts--parent-is-and-sibling-on-same-line (parent-type sibling-index)
  "Check the type of the node's parent and if a sibling is on the same line.

Return t if the node's parent type is PARENT-TYPE and if the sibling with
index SIBLING-INDEX is on the same line of the current node's parent."
  (lambda (_node parent &rest _)
    (and (string-match-p (treesit-node-type parent) parent-type)
         (julia-ts--same-line? (treesit-node-start parent)
                               (treesit-node-start (treesit-node-child parent sibling-index))))))

(defun julia-ts--parent-is-and-sibling-not-on-same-line (parent-type sibling-index)
  "Check the type of the node's parent and if a sibling is not on the same line.

Return t if the node's parent type is PARENT-TYPE and if the sibling with
index SIBLING-INDEX is not on the same line of the current node's parent."
  (lambda (_node parent &rest _)
    (and (string-match-p (treesit-node-type parent) parent-type)
         (not (julia-ts--same-line? (treesit-node-start parent)
                                    (treesit-node-start (treesit-node-child parent sibling-index)))))))

(defun julia-ts--same-line? (point-1 point-2)
  "Return t if POINT-1 and POINT-2 are on the same line."
  (equal (julia-ts--line-beginning-position-of-point point-1)
         (julia-ts--line-beginning-position-of-point point-2)))

(provide 'julia-ts-misc)

;; Local Variables:
;; coding: utf-8
;; byte-compile-warnings: (not obsolete)
;; End:
;;; julia-ts-misc.el ends here
