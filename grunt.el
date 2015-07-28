;;; grunt.el --- Some glue to stick Emacs and Gruntfiles together
;; Version: 0.0.3

;; Copyright (C) 2014  Daniel Gempesaw

;; Author: Daniel Gempesaw <dgempesaw@sharecare.com>
;; Keywords: convenience, grunt
;; URL: https://github.com/gempesaw/grunt.el
;; Package-Requires: ((dash "2.6.0"))
;; Created: 2014 Apr 1

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:

;; I got tired of managing shells and one off Async Command buffers to
;; kick off Grunt tasks. This package provides rudimentary access to
;; the tasks in a Gruntfile.

;; When your default-directory is somewhere in a JS project with a
;; Gruntfile, invoke `grunt-exec' or bind something to it. You can
;; either execute one of the suggested registered tasks, or input a
;; custom task of your own. It will create one buffer per project per
;; task, killing any existing buffers by default.

;;; Code:

(require 'dash)

(defgroup grunt nil
  "Execute grunt tasks from your Gruntfile from Emacs"
  :group 'convenience)

(defcustom grunt-kill-existing-buffer t
  "Whether or not to kill the existing process buffer

Defaults to t. When not nil, we will try to kill the buffer name
that we construct to do our task. Of course, if you rename your
buffer, we won't be able to kill it."
  :type 'boolean
  :group 'grunt)

(defcustom grunt-base-command (executable-find "grunt")
  "The path to the grunt binary.

You may have to fix this if `grunt' isn't in your PATH."
  :type 'string
  :group 'grunt)

(defcustom grunt-help-command (format "%s --help --no-color" grunt-base-command)
  "Command to get the help section from grunt."
  :type 'string
  :group 'grunt)

(defcustom grunt-options ""
  "Additional options to pass to grunt."
  :type '(string)
  :group 'grunt)

(defcustom grunt-current-path ""
  "Path to the current gruntfile.

We'll try to find this on our own."
  :type '(string)
  :group 'grunt)

(defcustom grunt-current-dir ""
  "Path to the directory of the current gruntfile.

We'll try to find this on our own."
  :type '(string)
  :group 'grunt)

(defcustom grunt-current-project ""
  "Name of the current project in which the Gruntfile is found."
  :type '(string)
  :group 'grunt)

;;;###autoload
(defun grunt-exec ()
  "Invoke this while in your project and it will suggest registered tasks.

You can also manually enter in a specific task that isn't
registered.  It will get/create one buffer per task per project,
as needed."
  (interactive)
  (unless (grunt-locate-gruntfile)
    (error "Sorry, we couldn't find a gruntfile.  Consider setting `grunt-current-path' manually?"))
  (let* ((task (ido-completing-read
                "Execute which task: "
                (grunt-resolve-registered-tasks) nil nil))
         (command (grunt--command task))
         (buf (grunt--project-task-buffer task))
         (default-directory grunt-current-dir)
         (ret))
    (message "%s" command)
    (setq ret (async-shell-command command buf buf))
    ;; handle window sizing: see #6
    (grunt--set-process-dimensions buf)
    ret))

(defun grunt--project-task-buffer (task)
  (let* ((bufname (format "*grunt-%s*<%s>" task grunt-current-project))
         (buf (get-buffer bufname))
         (proc (get-buffer-process buf)))
    (when (and grunt-kill-existing-buffer buf proc)
      (set-process-query-on-exit-flag proc nil)
      (kill-buffer bufname))
    (get-buffer-create bufname)))

(defun grunt-resolve-registered-tasks ()
  "Build a list of potential Grunt tasks.

The list is constructed by searching performing the `grunt --help` command,
or similar, and narrowing down to the Available tasks section before extracting
the tasks using regexp."
  (with-temp-buffer
    (insert (grunt-get-help))
    (goto-char 0)
    (let* ((tasks-start (search-forward "Available tasks" nil t))
           (tasks-end (re-search-forward "^$" nil t))
           (result (list)))
      (when tasks-start
        (narrow-to-region tasks-start tasks-end)
        (goto-char 0)
        (while (re-search-forward "[\s]+$" nil t)
          (replace-match ""))
        (goto-char 0)
        (while (re-search-forward "^[\s\t]*\\(.*?\\)  " nil t)
          (let ((match (match-string 1)))
            (when (string-match "[a-zA-Z]" match)
              (setq result (append result (list match)))
              ))))
      result)))

(defun grunt-get-help ()
  "Run grunt-help-cmd for the current grunt-project."
  (shell-command-to-string
   (format "cd %s; %s" grunt-current-dir grunt-help-command)))

(defun grunt-resolve-options ()
  "Set up the arguments to the grunt binary.

This lets us invoke grunt properly from any directory with any
gruntfile and pulls in the user specified `grunt-options'"
  (format "%s %s"
          (mapconcat
           (lambda (item)
             (format "--%s %s" (car item) (shell-quote-argument (cadr item))))
           `(("base" ,grunt-current-dir)
             ("gruntfile" ,grunt-current-path))
           " ")
          grunt-options))

(defun grunt--command (task)
  "Return the grunt command for the specified TASK."
  (unless grunt-base-command
    (setq grunt-base-command (executable-find "grunt")))
  (mapconcat 'identity `(,grunt-base-command ,(grunt-resolve-options) ,task) " "))

(defun grunt-locate-gruntfile (&optional directory)
  "Search the current DIRECTORY and upwards for a Gruntfile."
  (let ((gruntfile-dir (locate-dominating-file
                        (if directory
                            directory
                          default-directory) "Gruntfile.js")))
    (when gruntfile-dir
      (setq gruntfile-dir (file-truename gruntfile-dir)
            grunt-current-dir gruntfile-dir
            grunt-current-project (car (last (split-string gruntfile-dir "/" t)))
            grunt-current-path (format "%sGruntfile.js" gruntfile-dir)))))

(defun grunt--set-process-dimensions (buf)
  (let ((process (get-buffer-process buf)))
    (when process
      (set-process-window-size process
                               (window-height)
                               (window-width)))))

(provide 'grunt)
;;; grunt.el ends here
