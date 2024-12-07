(require 'faceup)

(defvar julia-font-lock-test-dir (faceup-this-file-directory))

(defun julia-font-lock-test (file)
  "Test that the julia FILE is fontifies as the .faceup file describes."
  (faceup-test-font-lock-file 'julia-ts-mode
                              (concat julia-font-lock-test-dir file)))

(faceup-defexplainer julia-font-lock-test)

(ert-deftest julia-font-lock-file-test ()
  (should (julia-font-lock-test "ArgTools.jl")
  (should (julia-font-lock-test "Downloads.jl"))
