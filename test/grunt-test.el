(require 'f)
(require 'noflet)

;;; set up copied blatantly from
;;; http://tuxicity.se/emacs/testing/cask/ert-runner/2013/09/26/unit-testing-in-emacs.html

;;; thanks rejeep!

(defvar root-test-path
  (f-dirname (f-this-file)))

(defvar root-code-path
  (f-parent root-test-path))

(defvar root-sandbox-path
  (f-expand "sandbox" root-test-path))

(require 'grunt (f-expand "grunt.el" root-code-path))

(defmacro with-sandbox (&rest body)
  "Evaluate BODY in an empty temporary directory."
  `(let ((default-directory root-sandbox-path))
     (when (f-dir? root-sandbox-path)
       (f-delete root-sandbox-path :force))
     (f-mkdir root-sandbox-path)
     ,@body
     (f-delete root-sandbox-path :force)))

(defmacro with-grunt-sandbox (&rest body)
  "Evaluate BODY in an empty temporary directory."
  `(let ((default-directory (f-expand "has-gruntfile" root-sandbox-path)))
     (when (f-dir? root-sandbox-path)
       (f-delete root-sandbox-path :force))
     (f-mkdir root-sandbox-path default-directory)
     (f-touch (f-expand "Gruntfile.js" default-directory))
     ,@body
     (f-delete root-sandbox-path :force)))

(ert-deftest should-locate-gruntfiles ()
  (with-sandbox
   (let* ((new-dir "has-gruntfile")
          (default-directory (f-expand new-dir root-sandbox-path)))
     (f-mkdir default-directory)
     (f-touch (f-expand "Gruntfile.js" default-directory))
     (should (string-suffix-p (format "%s/Gruntfile.js" new-dir) (grunt-locate-gruntfile))))))

(ert-deftest should-locate-gruntfiles-from-inside ()
  (with-sandbox
   (let* ((root "has-gruntfile")
         (root-dir (f-expand root root-sandbox-path))
         (nested-dir (f-expand "nested" root-dir))
         (default-directory nested-dir))
    (f-mkdir root-dir nested-dir)
    (f-touch (f-expand "Gruntfile.js" root-dir))
    (should (string-suffix-p (format "%s/Gruntfile.js" root) (grunt-locate-gruntfile))))))

(ert-deftest should-fail-if-gruntfile-is-missing ()
  (with-sandbox
   (should (equal nil (grunt-locate-gruntfile)))))

(ert-deftest should-locate-current-project ()
  (with-sandbox
   (let* ((root "has-gruntfile")
          (default-directory (f-expand "has-gruntfile" root-sandbox-path)))
     (f-mkdir default-directory)
     (f-touch (f-expand "Gruntfile.js" default-directory))
     (grunt-locate-gruntfile)
     (should (string= root grunt-current-project)))))

(ert-deftest should-resolve-registered-tasks ()
  (with-sandbox
   (let* ((root "has-gruntfile")
          (default-directory (f-expand root root-sandbox-path)))
     (f-mkdir default-directory)
     (f-write "grunt.registerTask('build', ["
              'utf-8
              (f-expand "Gruntfile.js" default-directory))
     (should (string= "build" (car (grunt-resolve-registered-tasks)))))))

(ert-deftest should-include-custom-options ()
  (with-grunt-sandbox
   (let ((grunt-options "expected-option-string"))
     (grunt-locate-gruntfile)
     (should (string-match-p grunt-options (grunt-resolve-options))))))

(ert-deftest should-construct-valid-command ()
  (with-grunt-sandbox
   (grunt-locate-gruntfile)
   (let ((cmd (grunt--command "task")))
     (should (string-match-p " --base /.*has-gruntfile" cmd))
     (should (string-match-p " --gruntfile /.*Gruntfile.js" cmd))
     (should (string-suffix-p " task" cmd))
     (should (string-match-p "grunt " cmd)))))

(ert-deftest should-execute-grunt-commands ()
  (with-grunt-sandbox
   (noflet ((ido-completing-read (&rest any) "build")
            (async-shell-command (&rest args) args))
     (let* ((args (grunt-exec))
           (cmd (car args))
           (buf (buffer-name (cadr args))))
       (should (string-suffix-p "build" cmd))
       (should (string= "*grunt-build*<has-gruntfile>" buf))))))
