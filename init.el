;;; GNU Emacs initialization file -*- mode: Emacs-Lisp -*-
;;; Emilio C. Lopes

;;; Note: lines beginning with `;;;_' are headers for Allout outline
;;; minor mode

;;;_* TODO:
;; o Use `add-to-list' and similars for adding things to alists.
;; o Review mode-alist changes.
;; o Use `eval-after-load' for customization of packages.
;; o Review use of "extra" packages. Some are not necessary anymore
;;   while some others could be added.
;; o Cleanup.
;; o Index, with page breaks between the "sections".
;; o Other things. Search for "TODO".

;;;_* Language settings
(setq edmacro-eight-bits t)

;; (add-hook 'set-language-environment-hook
;;           (lambda ()
;;             (when (equal current-language-environment "German")
;;               (setq default-input-method "german-prefix"))))

;; (set-language-environment "German")

(set-language-environment "UTF-8")
(prefer-coding-system 'utf-8)

(setq default-input-method "latin-1-prefix")

(defun activate-default-input-method ()
  "*Activate the input method defined in `default-input-method'."
  (set-input-method default-input-method))

(add-hook 'text-mode-hook 'activate-default-input-method)
(add-hook 'org-mode-hook 'activate-default-input-method)

(setq input-method-highlight-flag nil)
(setq input-method-verbose-flag t)

;; extend the `latin-1-prefix' input method
(eval-after-load "latin-pre"
  `(progn
     (quail-select-package "latin-1-prefix")
     (quail-define-rules
      ((append . t))
      ("\"." ,(vector (string #xa0 #x2026))) ; ellipses, preceeded by nbsp.
      ("\"$" #x20ac)                         ; euro sign
      ("\"`" #x201e)                         ; gaensefuesschen links
      ("\"'" #x201c)                         ; gaensefuesschen rechts
      )))

;;;_* Useful defs

(setq hostname (car (split-string system-name "\\." )))

;; Windows sets the environment variable USERNAME, but neither USER
;; nor LOGNAME.  Bash defines only LOGNAME, but not USER.  Make sure
;; the variables USER and LOGNAME are available since some
;; programs/libraries expect one of them to be accordingly set.

(if (and (null (getenv "USER"))
         (getenv "USERNAME"))
    (setenv "USER" (getenv "USERNAME")))

(if (and (getenv "LOGNAME")
         (null (getenv "USER")))
    (setenv "USER" (getenv "LOGNAME")))

(if (and (getenv "USER")
         (null (getenv "LOGNAME")))
    (setenv "LOGNAME" (getenv "USER")))

(setenv "PAGER" "cat")

(setq running-interactively (not noninteractive))
(setq running-nt (equal system-type 'windows-nt))

(setq at-bmw (equal (getenv "BMW") "BMW"))

(unless (boundp 'user-emacs-directory)
  (setq user-emacs-directory "~/.emacs.d/"))

(defun add-to-path (path dir &optional append)
  "*Add directory DIR to path PATH.
If optional argument APPEND is non-nil, DIR is added at the end."
  (setq dir (expand-file-name dir))
  (and (file-directory-p dir) (file-accessible-directory-p dir)
       (add-to-list path dir append)))

(defmacro global-defkey (key def)
  "*Bind KEY globally to DEF.
KEY should be a string constant in the format used for
saving keyboard macros (cf. `insert-kbd-macro')."
  `(global-set-key (kbd ,key) ,def))

(defmacro local-defkey (key def)
  "*Bind KEY locally to DEF.
KEY should be a string constant in the format used for
saving keyboard macros (cf. `insert-kbd-macro')."
  `(local-set-key (kbd ,key) ,def))

(defmacro defkey (keymap key def)
  "*Define KEY to DEF in KEYMAP.
KEY should be a string constant in the format used for
saving keyboard macros (cf. `insert-kbd-macro')."
  `(define-key ,keymap (kbd ,key) ,def))

(defmacro bind-with-new-map (map binding &rest bindings)
  (let ((%map (make-symbol "mapu")))
    `(let ((,%map (make-sparse-keymap)))
       ,@(mapcar (lambda (char+command)
                   `(define-key ,%map (read-kbd-macro ,(car char+command)) ,(cdr char+command)))
                 bindings)
       (define-key ,map ,(read-kbd-macro binding) ,%map))))
(put 'bind-with-new-map 'lisp-indent-function 2)

(defmacro require-soft (feature &optional file)
  "*Try to require FEATURE, but don't signal an error if `require' fails."
  `(require ,feature ,file 'noerror))

(defmacro mapc-pair (proc seq)
  "Apply PROC to each element of SEQ, a sequence of pairs.
PROC should accept two arguments: the car and the cdr of each
pair. PROC is called for side effects only, don't accumulate the
results "
  `(mapc (lambda (x)
           (funcall ,proc (car x) (cdr x))) ,seq))

;;;_* Load-path
(add-to-path 'load-path user-emacs-directory)
(add-to-path 'load-path (concat user-emacs-directory "lib"))
(add-to-path 'load-path "~/.lib/emacs/elisp")
(add-to-path 'load-path "~/.lib/emacs/rc")

;;;_* System-dependent configuration

(when running-nt

  (setq user-login-name (downcase user-login-name))

  (modify-coding-system-alist 'process "svn" '(latin-1 . latin-1))

  (setq focus-follows-mouse nil)
  (auto-raise-mode -1)

  (setq w32-enable-synthesized-fonts nil)

  ;;(setq w32-enable-caps-lock nil)
  (setq w32-alt-is-meta t)
  (setq w32-pass-alt-to-system nil)

  (setq w32-pass-lwindow-to-system nil)
  (setq w32-lwindow-modifier 'hyper)
  (setq w32-pass-rwindow-to-system nil)
  (setq w32-rwindow-modifier 'hyper)

  (defun w32-toggle-meta-tab ()
    "*Toggle passing of the key combination M-TAB to the system."
    (interactive)
    (unless (fboundp 'w32-registered-hot-keys)
      (error "This command is not available on your system"))
    (let ((hotkeys (w32-registered-hot-keys))
          hotkey found)
      (while (and (setq hotkey (pop hotkeys)) (not found))
        (when (equal '(meta tab) (w32-reconstruct-hot-key hotkey))
          (w32-unregister-hot-key hotkey)
          (setq found t)))
      (if (not found)
          (w32-register-hot-key [(alt tab)]))))

  (setq w32-enable-num-lock nil)
  (global-defkey "<kp-numlock>" 'w32-toggle-meta-tab)

  (defun normalize-file-path-on-kill-ring ()
    "*Substitute the filename on the kill-ring with its canonical form.
The canonical form is the result of applying `expand-file-name'
to the filename."
    (interactive)
    (kill-new (replace-regexp-in-string "/"
                                        "\\\\"
                                        (expand-file-name (current-kill 0 'do-not-move)))
              'replace))
  (global-defkey "C-c k" 'normalize-file-path-on-kill-ring)

  (add-to-list 'default-frame-alist '(background-mode  . 'light))
  (add-to-list 'default-frame-alist '(background-color . "white"))
  (add-to-list 'default-frame-alist '(foreground-color . "black"))
  (add-to-list 'default-frame-alist '(cursor-color . "MediumSeaGreen"))
  (if (display-color-p)
      (progn
        (set-face-attribute 'default nil
                            ;; Fontname comes from (insert (prin1-to-string (w32-select-font)))
                            :font "-outline-Consolas-normal-r-normal-normal-19-142-96-96-c-*-iso8859-1")
        (set-face-foreground 'mode-line "white")
        (set-face-background 'mode-line "royalblue")
        (set-face-foreground 'fringe "slategray")
        (set-face-background 'fringe "white")
        (set-cursor-color "MediumSeaGreen")
        (set-mouse-color "red"))
    (progn
      (set-face-foreground 'mode-line "white")
      (set-face-background 'mode-line "DimGray")
      (set-face-foreground 'fringe "black")
      (set-face-background 'fringe "gray")))
  (setq w32-quote-process-args t)
  (setq process-coding-system-alist '(("bash" . undecided-unix) ("zsh" . undecided-unix)))
  (setq shell-file-name "bash")
  (setq explicit-bash-args '("-i"))
  (setenv "SHELL" shell-file-name)
  (setq explicit-shell-file-name shell-file-name))

;;;_* General configuration

(setq inhibit-startup-message t)
(setq inhibit-startup-echo-area-message "qx29999")
(setq inhibit-startup-echo-area-message "eclig")
(setq inhibit-startup-echo-area-message "ecl")
(setq initial-scratch-message nil)

(setq visible-bell t)

(setq use-dialog-box nil)

(setq initial-major-mode 'lisp-interaction-mode)

;; set up the mode based on the buffer name.  Thanks to `__jim__'.
;; http://www.reddit.com/r/emacs/comments/d2t4q/scratch_buffers_for_emacs/c0x7a68
(setq-default major-mode
              (lambda ()
                (let ((buffer-file-name (or buffer-file-name (buffer-name))))
                  (set-auto-mode))))

(setq view-read-only nil)

(setq disabled-command-function nil)    ; no disabled commands.
(put 'rmail 'disabled t)                ; avoid mbox destruction


(setq message-log-max 1024)     ; max size of the "*Messages*" buffer.

(setq eval-expression-print-length nil)

(setq scroll-step 0)
(setq scroll-conservatively 0)

(setq scroll-preserve-screen-position t)

(setq window-min-height 2)
(setq window-min-width 10)

(setq enable-recursive-minibuffers t)
(setq history-length 512)

(setq set-mark-command-repeat-pop t)

(setq-default indent-tabs-mode nil)

(setq parens-require-spaces nil)

(setq-default fill-column 70)

;; don't split windows horizontally
(setq split-width-threshold nil)

(setq auto-save-default t)
(setq auto-save-file-format t)
(setq auto-save-visited-file-name nil)
(setq auto-save-interval 200)
(setq auto-save-timeout 15)

(setq large-file-warning-threshold 20000000)

(setq make-backup-files t)
(setq backup-by-copying t)
(setq delete-auto-save-files t)
(setq version-control t)                ; numeric backups.
(setq kept-new-versions 4)
(setq kept-old-versions 2)
(setq delete-old-versions t)

(setq-default ctl-arrow t)

(setq echo-keystrokes 0.000001)

(setq-default case-fold-search t)
(setq case-replace t)

(setq search-whitespace-regexp "[ \t\r\n]+")

(setq revert-without-query '("."))

(setq search-highlight t)
(setq query-replace-highlight t)

(setq next-line-add-newlines nil)
(setq require-final-newline t)

(setq-default indicate-empty-lines t)

(setq enable-local-eval 'ask)
(setq enable-local-variables t)

(setq find-file-existing-other-name t)

(setq mouse-yank-at-point t)

(setq kill-read-only-ok t)

(setq windmove-wrap-around t)

(when (eq window-system 'x)
  (setq x-pointer-shape x-pointer-left-ptr)
  (when (x-display-color-p)
    (set-mouse-color "RoyalBlue")))

(setq comment-style 'indent)

(setq list-directory-brief-switches "-BCF")
(setq list-directory-verbose-switches "-Bl")

(add-to-path 'Info-default-directory-list "/usr/info")
(add-to-path 'Info-default-directory-list "/usr/share/info")

;;;_* Functions

(defvar default-register 0)

(defun set-default-register (register)
  (interactive "*cDefault register: ")
  (setq default-register register))

(defun insert-default-register ()
  "*Insert contents of register `default-register'."
  (interactive)
  (insert-register default-register t))

(defun copy-to-default-register (start end &optional append)
  "*Copy region into register `default-register'.
With prefix arg, append it."
  (interactive "r\nP")
  (funcall (if append 'append-to-register 'copy-to-register) default-register start end))

(defvar zap-to-char-last-char nil
  "Last char given as input to `zap-to-char'.")

(defun zap-up-to-char (arg char)        ; adapted from `zap-to-char'
  "*Kill up to (but not including) ARG'th occurrence of CHAR.
Case is ignored if `case-fold-search' is non-nil in the current buffer.
Goes backward if ARG is negative; error if CHAR not found."
  (interactive (list (prefix-numeric-value current-prefix-arg)
                     (if (eq real-last-command this-command)
                         zap-to-char-last-char
                       (setq zap-to-char-last-char (read-char "Zap to char: ")))))
  (kill-region (point) (save-excursion
                         (progn
                           (search-forward (char-to-string char)
                                           nil
                                           nil
                                           (if (looking-at (regexp-quote (char-to-string char)))
                                               (if (> arg 0)
                                                   (1+ arg)
                                                 (1- arg))
                                             arg))
                           (if (> arg 0) (1- (point)) (1+ (point)))))))

(global-defkey "M-z" 'zap-up-to-char)
(global-defkey "M-Z" 'zap-to-char)

;; analogous to dired-copy-filename-as-kill
(defun copy-filename-as-kill (arg)
  "*Copy the value of buffer-file-name into the kill ring.
If current buffer is not visiting any file, use the current
working directory instead.  With a prefix argument ARG use only
the last component of the file's path (its \"basename\")."
  (interactive "P")
  (let* ((fn (or buffer-file-name
                 (directory-file-name default-directory)))
         (kill-string (if arg (file-name-nondirectory fn) fn)))
    (kill-new kill-string)
    (message "%s" kill-string)))

;; show-buffer-file-name
(defun show-buffer-file-name ()
  "*Display the value of buffer-file-name in the echo area."
  (interactive)
  (if buffer-file-name 
      (message "%s" buffer-file-name)
    (message "Buffer \"%s\" is not visiting any file." 
             (buffer-name))))

(defun dos2unix ()
  "*Convert the entire buffer from M$-DOG text file format to UNIX."
  (interactive "*")
  (save-excursion
    (goto-char (point-min))
    (replace-regexp "\r+$" "" nil)
    (goto-char (1- (point-max)))
    (when (looking-at "\C-z")
        (delete-char 1))))

(defun revert-buffer-preserve-modes ()
  "*Revert current buffer preserving modes.
Normally they are reinitialized using `normal-mode'.
The read-only status of the buffer is also preserved."
  (interactive)
  (let (buffer-read-only)
    (revert-buffer nil nil t)))

(defun dos-revert ()
  "*Revert current buffer using 'undecided-dos as coding system."
  (interactive)
  (let ((coding-system-for-read 'undecided-dos)
        buffer-read-only)
    (revert-buffer nil t t)))

(defun confirm-exit ()
  (interactive)
  (yes-or-no-p "Really exit Emacs? "))
(add-hook 'kill-emacs-query-functions 'confirm-exit)

(defun mark-backup-buffers-read-only ()
  "*Mark buffers containing backup files as read-only."
  (when (backup-file-name-p buffer-file-name)
    (toggle-read-only 1)))
(add-hook 'find-file-hooks 'mark-backup-buffers-read-only)

(defun x11-maximize-frame-vertically ()
  "*Maximize the selected frame vertically.
Works only for X11."
  (interactive)
  (when (eq window-system 'x)
    (set-frame-height (selected-frame)
                      (/ (- (x-display-pixel-height) 50) (frame-char-height)))
    (set-frame-position (selected-frame)
                        (cdr (assq 'left (frame-parameters))) 30)))

(defun w32-maximize-frame ()
  "*Maximize the selected frame.
Works only on Windows."
  (interactive)
  (unless (fboundp 'w32-send-sys-command)
    (error "This command is not available on this system"))
  (w32-send-sys-command #xf030))

;;;_ + other-window-or-other-buffer

(defvar buffer-ignore-regexp '("^ ")
  "*Regexp matching buffer names to be ignored by \\[next-buffer].")

(setq buffer-ignore-regexp
      (concat "^ "
              "\\|\\*Completions\\*"
              "\\|\\*Help\\*"
              "\\|\\*Apropos\\*"
              "\\|\\*Buffer List\\*"
              "\\|\\*Messages\\*"
              "\\|\\*compilation\\*"
              "\\|\\*i?grep\\*"
              "\\|\\*occur\\*"
              "\\|^\\*Score Trace\\*"
              "\\|^\\*ftp"
              "\\|\\*Directory\\*"))

(defun buffer-list-filter (&optional list)
  (let ((bufflist (or list (buffer-list))))
    (mapcar (lambda (buffer)
              (when (string-match buffer-ignore-regexp (buffer-name buffer))
                (delete buffer bufflist))) bufflist)
    bufflist))

(defun other-window-or-other-buffer (arg)
  "*Select next visible window on this frame or, if none, switch to `other-buffer'.
With prefix argument ARG select the ARGth window or buffer.
Subject to `buffer-ignore-regexp'."
  (interactive "p")
  (if (one-window-p)
      (next-buffer arg)
    (other-window arg)))

(defun next-buffer (arg)
  "*Switch to the `next' buffer.
With prefix argument ARG switch to the ARGth buffer in the buffer list.
Subject to `buffer-ignore-regexp'."
  (interactive "p")
  (let ((bufflist (buffer-list-filter)))
    (when (> 0 arg)
      (setq arg (+ (length bufflist) arg)))
    (switch-to-buffer (nth arg bufflist))))

(defun resize-window (&optional arg)    ; Hirose Yuuji and Bob Wiener
  "*Resize window interactively."
  (interactive "P")
  (if (one-window-p) (error "Cannot resize sole window"))
  (setq arg (if arg (prefix-numeric-value arg) 4))
  (let (c)
    (catch 'done
      (while t
	(message
	 "h=heighten, s=shrink, w=widen, n=narrow (by %d);  0-9=unit, q=quit"
	 arg)
	(setq c (read-char))
	(condition-case ()
	    (cond
	     ((= c ?h) (enlarge-window arg))
	     ((= c ?s) (shrink-window arg))
	     ((= c ?w) (enlarge-window-horizontally arg))
	     ((= c ?n) (shrink-window-horizontally arg))
	     ((= c ?\^G) (keyboard-quit))
	     ((= c ?q) (throw 'done t))
             ((= c ?0) (setq arg 10))
	     ((and (> c ?0) (<= c ?9)) (setq arg (- c ?0)))
	     (t (beep)))
	  (error (beep)))))
    (message "Done.")))

;; The following two functions written by Noah Friedman
;; http://www.splode.com/users/friedman/software/emacs-lisp/src/buffer-fns.el
(defun toggle-mode-line-inverse-video (&optional current-only)
  (interactive)
  (cond ((fboundp 'set-face-attribute)
         (let ((onp (face-attribute 'modeline :inverse-video))
               (dt (cdr (assq 'display-type (frame-parameters)))))
           (when (equal onp 'unspecified)
             (setq onp nil))
           (set-face-attribute 'modeline nil :inverse-video (not onp))
           ;; This should be toggled on mono frames; in color frames, this
           ;; must always be t to use the face attribute.
           (setq mode-line-inverse-video (or (eq dt 'color) (not onp)))
           (force-mode-line-update (not current-only))))
        (t
         (setq mode-line-inverse-video (not mode-line-inverse-video))
         (force-mode-line-update (not current-only)))))

(defun bell-flash-mode-line ()
  "*Effect ringing bell by flashing mode line momentarily.
In emacs 20.1 or later, you can use the variable `ring-bell-function'
to declare a function to run in order to ring the emacs bell."
  (let ((localp (local-variable-p 'mode-line-inverse-video)))
    (or localp
        (make-local-variable 'mode-line-inverse-video))
    (toggle-mode-line-inverse-video t)
    (sit-for 0 100)
    ;; Set it back because it may be a permanently local variable.
    (toggle-mode-line-inverse-video t)
    (or localp
        (kill-local-variable 'mode-line-inverse-video))))
(setq ring-bell-function 'bell-flash-mode-line)


(defun describe-face-at-point ()
  "*Display the properties of the face at point."
  (interactive)
  (let ((face (or (get-char-property (point) 'face) 'default)))
    (describe-face face)
    (with-current-buffer "*Help*"
      (let ((inhibit-read-only t))
        (goto-char (point-min))
        (insert "Face at point: " (propertize (format "%s" face) 'face face) "\n\n")
        (set-buffer-modified-p nil)))))

(defun untabify-buffer ()
  "*Like `untabify', but operate on the whole buffer."
  (interactive "*")
  (untabify (point-min) (point-max)))

(defun delete-horizontal-space-forward () ; adapted from `delete-horizontal-space'
  "*Delete all spaces and tabs after point."
  (interactive "*")
  (delete-region (point) (progn (skip-chars-forward " \t") (point))))

(defun backward-delete-char-hungry (arg &optional killp)
  "*Delete characters backward in \"hungry\" mode.
See the documentation of `backward-delete-char-untabify' and
`backward-delete-char-untabify-method' for details."
  (interactive "*p\nP")
  (let ((backward-delete-char-untabify-method 'hungry))
    (backward-delete-char-untabify arg killp)))

(defun indirect-elisp-buffer (arg) ; Erik Naggum
  "*Edit Emacs Lisp code from this buffer in another window.
Optional argument ARG is number of sexps to include in that buffer."
  (interactive "P")
  (let ((buffer-name (generate-new-buffer-name " *elisp*")))
    (pop-to-buffer (make-indirect-buffer (current-buffer) buffer-name))
    (emacs-lisp-mode)
    (narrow-to-region (point) (save-excursion (forward-sexp arg) (point)))))

;; Noah Friedman
;; http://www.splode.com/users/friedman/software/emacs-lisp/src/buffer-fns.el
(defadvice rename-buffer (before interactive-edit-buffer-name activate)
  "Prompt for buffer name supplying current buffer name for editing."
  (interactive
   (list (let ((minibuffer-local-completion-map
                (copy-keymap minibuffer-local-completion-map)))
           (define-key
             minibuffer-local-completion-map " " 'self-insert-command)
           (completing-read "Rename current buffer to: "
                            (mapcar (function (lambda (buffer)
                                                (list (buffer-name buffer))))
                                    (buffer-list))
                            nil
                            nil
                            (if (string-lessp "19" emacs-version)
                                (cons (buffer-name) 0)
                              (buffer-name))))
         current-prefix-arg)))

(defun switch-to-buffer-create (name mode &optional wipe)
  "*Switch to buffer NAME, creating it if necessary.
Upon creation the buffer is put in major-mode MODE, which must be
a function.  If argument WIPE is non nil, clear the buffer's
contents."
  (if (get-buffer name)
      (progn
        (switch-to-buffer name)
        (when wipe
          (erase-buffer)
          (set-buffer-modified-p nil)))
    (switch-to-buffer (generate-new-buffer name))
    (funcall mode)))

;; Noah Friedman
;; http://www.splode.com/users/friedman/software/emacs-lisp/src/buffer-fns.el
(defun messages ()
  "*Display message log buffer, if it exists."
  (interactive)
  (let* ((buffer-name "*Messages*")
         (buf (get-buffer buffer-name))
         (curbuf (current-buffer))
         (curwin (selected-window))
         winbuf)
    (cond (buf
           (unwind-protect
               (progn
                 (setq winbuf (display-buffer buf))
                 (select-window winbuf)
                 (set-buffer buf)
                 (goto-char (point-max))
                 (recenter -1))
             (select-window curwin)
             (set-buffer curbuf)))
          (t
           (message "Message log is empty.")))))
(global-defkey "C-h M" 'messages)

(defun kill-buffer-and-window-no-confirm ()
  "*Kill the current buffer and delete the selected window, WITHOUT asking."
  (interactive)
  (let ((buffer (current-buffer)))
    (delete-window)
    (kill-buffer buffer)))
(defkey ctl-x-4-map "0" 'kill-buffer-and-window-no-confirm)

(defun quit-buffer-delete-window ()
  "Quit (bury) the current buffer and delete the selected window."
  (interactive)
  (quit-window nil (selected-window)))
(defkey ctl-x-4-map "q" 'quit-buffer-delete-window)

(defun swap-window-positions ()         ; Stephen Gildea
  "*Swap the positions of this window and the next one."
  (interactive)
  (let ((other-window (next-window (selected-window) 'no-minibuf)))
    (let ((other-window-buffer (window-buffer other-window))
	  (other-window-hscroll (window-hscroll other-window))
	  (other-window-point (window-point other-window))
	  (other-window-start (window-start other-window)))
      (set-window-buffer other-window (current-buffer))
      (set-window-hscroll other-window (window-hscroll (selected-window)))
      (set-window-point other-window (point))
      (set-window-start other-window (window-start (selected-window)))
      (set-window-buffer (selected-window) other-window-buffer)
      (set-window-hscroll (selected-window) other-window-hscroll)
      (set-window-point (selected-window) other-window-point)
      (set-window-start (selected-window) other-window-start))
    (select-window other-window)))

;; from http://www.emacswiki.org/cgi-bin/wiki/ToggleWindowSplit
(defun toggle-window-split ()
  (interactive)
  (if (= (count-windows) 2)
      (let* ((this-win-buffer (window-buffer))
	     (next-win-buffer (window-buffer (next-window)))
	     (this-win-edges (window-edges (selected-window)))
	     (next-win-edges (window-edges (next-window)))
	     (this-win-2nd (not (and (<= (car this-win-edges)
					 (car next-win-edges))
				     (<= (cadr this-win-edges)
					 (cadr next-win-edges)))))
	     (splitter
	      (if (= (car this-win-edges)
		     (car (window-edges (next-window))))
		  'split-window-horizontally
		'split-window-vertically)))
	(delete-other-windows)
	(let ((first-win (selected-window)))
	  (funcall splitter)
	  (if this-win-2nd (other-window 1))
	  (set-window-buffer (selected-window) this-win-buffer)
	  (set-window-buffer (next-window) next-win-buffer)
	  (select-window first-win)
	  (if this-win-2nd (other-window 1))))))

(define-key ctl-x-4-map "t" 'toggle-window-split)

(defun move-to-window-top ()
  "*Move the point to the top of the current window."
  (interactive)
  (move-to-window-line 0))

(defun move-to-window-bottom ()
  "*Move the point to the the bottom of the current window."
  (interactive)
  (move-to-window-line -1))

(defun kill-backward-up-list (&optional arg)
  "Kill the form containing the current sexp, leaving the sexp itself.
A prefix argument ARG causes the relevant number of surrounding
forms to be removed."
  (interactive "p")
  (let ((current-sexp (thing-at-point 'sexp)))
    (if current-sexp
        (save-excursion
          (backward-up-list arg)
          (kill-sexp)
          (insert current-sexp))
      (error "Not at a sexp"))))

(global-defkey "C-<backspace>" 'kill-backward-up-list)

(defun copy-sexp (arg)                  ; adapted from `kill-sexp'
  "*Copy the sexp following the cursor to the kill-ring.
With argument, copy that many sexps after the cursor.
Negative arg -N means copy N sexps before the cursor."
  (interactive "p")
  (copy-region-as-kill (point) (save-excursion (forward-sexp arg) (point))))

(defun comment-sexp (arg)               ; adapted from `kill-sexp'
  "*Comment the sexp following the cursor.
With argument, comment that many sexps after the cursor.
Negative arg -N means comment N sexps before the cursor."
  (interactive "p")
  (comment-region (point) (save-excursion (forward-sexp arg) (point))))

(global-defkey "C-;" 'comment-sexp)

(defun copy-line (&optional arg)        ; adapted from `kill-line'
  "*Copy the rest of the current line (or ARG lines) to the kill-ring.
Like \\[kill-line], except that the lines are not really killed, just copied
to the kill-ring. See the documentation of `kill-line' for details."
  (interactive "P")
  (copy-region-as-kill (point)
                       (progn ;save-excursion
                         (if arg
                             (forward-visible-line (prefix-numeric-value arg))
                           (if (eobp) (signal 'end-of-buffer nil))
                           (if (or (looking-at "[ \t]*$") (and kill-whole-line (bolp)))
                               (forward-visible-line 1)
                             (end-of-visible-line)))
                         (point)))
  (setq this-command 'kill-region))

;; inspired by Erik Naggum's `recursive-edit-with-single-window'
(defmacro recursive-edit-preserving-window-config (body)
  "*Return a command that enters a recursive edit after executing BODY.
Upon exiting the recursive edit (with\\[exit-recursive-edit] (exit)
or \\[abort-recursive-edit] (abort)), restore window configuration
in current frame."
  `(lambda ()
     "See the documentation for `recursive-edit-preserving-window-config'."
     (interactive)
     (save-window-excursion
       ,body
       (recursive-edit))))

;; (defun recursive-edit-with-single-window (&optional winfunc) ; Erik Naggum
;;   "*Enter a recursive edit with the current window as the single window.
;; The optional argument WINFUNC determines which function will be used
;; to set up the new window configuration.
;; Upon exit, restore window configuration in current frame.
;; Exit with \\[exit-recursive-edit] (exit) or \\[abort-recursive-edit] (abort)."
;;   (interactive)
;;   (when (one-window-p t)
;;     (error "Current window is the only window in its frame"))
;;   (save-window-excursion
;;     (if winfunc (funcall winfunc) (delete-other-windows))
;;     (recursive-edit)))

(defun insert-date (&optional arg)
  "*Insert date in current buffer using German format DD.MM.YYYY.
With optional prefix argument use ISO format instead."
  (interactive "*P")
  (insert (format-time-string
           (if arg "%Y-%m-%d" "%d.%m.%Y")
           (current-time))))

(defun update-date ()
  "*Update the date around point.
Recognise the formats DD.MM.YYYY, YYYY-MM-DD and MM/DD/YYYY."
  (interactive "*")
  (let ((update-date-formats
         '(("[0-3][0-9]\\.[01][0-9]\\.[0-9][0-9][0-9][0-9]"   . "%d.%m.%Y")
           ("[0-3]?[0-9]\\.[01]?[0-9]\\.[0-9][0-9][0-9][0-9]" . "%-d.%-m.%Y")
           ("[0-3]?[0-9]\\.[01]?[0-9]\\.[0-9][0-9]"           . "%-d.%-m.%y")

           ("[01][0-9]/[0-3][0-9]/[0-9][0-9][0-9][0-9]"       . "%m/%d/%Y")
           ("[01]?[0-9]/[0-3]?[0-9]/[0-9][0-9][0-9][0-9]"     . "%-m/%-d/%Y")
           ("[01]?[0-9]/[0-3]?[0-9]/[0-9][0-9]"               . "%-m/%-d/%y")

           ("[0-9][0-9][0-9][0-9]-[01][0-9]-[0-3][0-9]"       . "%Y-%m-%d"))))
    (save-excursion
      ;; (skip-syntax-backward "^-" (point-at-bol))
      (skip-chars-backward "[:digit:]/\.-" (point-at-bol))
      (catch 'done
       (dolist (regexp+format update-date-formats)
         (let ((date-regexp (car regexp+format))
               (date-format (cdr regexp+format)))
           (when (looking-at date-regexp)
             (replace-match (format-time-string date-format (current-time)))
             (throw 'done t))))))))

(defun update-german-date ()
  "*Update a date in German format near point."
  (interactive)
  (error "Use `update-date' instead!"))

(defun show-time-and-date ()
  "*Show current time and date in the echo-area."
  (interactive)
  ;; If one prefers a `date'-like output: "%a %b %d %H:%M:%S  %Y"
  (message (format-time-string "%d. %B %Y  %a (Week %V)   %H:%M:%S" (current-time))))

(defun diff-backup-this-file ()
  "*Diff this file with its backup file or vice versa.
Uses the latest backup, if there are several numerical backups.
If this file is a backup, diff it with its original.
The backup file is the first file given to `diff'."
  (interactive)
  (if buffer-file-name
      (diff-backup buffer-file-name)
    (error "Buffer \"%s\" is not visiting any file." (buffer-name))))

(defun toggle-variable (var &optional arg) ; adapted from `set-variable'
  "*Toggle the value of VAR.
With argument ARG, set VAR to t if ARG is positive, or to nil otherwise.
Return the new value of VAR."
  (interactive (let* ((default-var (variable-at-point))
                      (var (if (symbolp default-var)
                               (read-variable
                                (format "Toggle variable (default %s): "
                                        default-var) default-var)
                             (read-variable "Toggle variable: "))))
		 (list var current-prefix-arg)))
  (let ((type (get var 'custom-type)))
    (when type
      (unless (eq type 'boolean)
        (error "Not a boolean variable"))))
  (set var (if (null arg)
               (not (symbol-value var))
             (> (prefix-numeric-value arg) 0)))
  (when (interactive-p)
    (message
     (concat "Variable `%S' set to %S"
             (when (local-variable-p var) " in this buffer"))
     var (symbol-value var)))
  (symbol-value var))                   ; return the new value of var

;; See also:
;; http://www.splode.com/users/friedman/software/emacs-lisp/src/win-disp-util.el

(unless (fboundp 'toggle-truncate-lines)
  (defun toggle-truncate-lines (&optional arg)
    "*Toggle the value of the variable `truncate-lines'."
    (interactive "P")
    (setq truncate-partial-width-windows (toggle-variable 'truncate-lines arg))
    ;; If disabling truncation, make sure that window is entirely scrolled
    ;; to the right, otherwise truncation will remain in effect while still
    ;; horizontally scrolled.
    (or truncate-lines
        (scroll-right (window-hscroll)))
    (force-mode-line-update)
    (when (interactive-p)
      (message
       (concat "Line truncation" (if truncate-lines " enabled" " disabled")
               " in this buffer")))))

(defun toggle-stack-trace-on-error (&optional arg)
  (interactive "P")
  (setq stack-trace-on-error (if (null arg)
                                 (not stack-trace-on-error)
                               (> (prefix-numeric-value arg) 0))))

;; Daniel Lundin [http://ftp.codefactory.se/pub/people/daniel/elisp/dot.emacs]
(defun toggle-window-dedicated ()
"*Toggle whether current window is dedicated or not."
(interactive)
(message
 (if (let (window (get-buffer-window (current-buffer)))
       (set-window-dedicated-p window
		(not (window-dedicated-p window))))
     "Window dedicated to buffer '%s'"
   "Window displaying '%s' is not dedicated anymore.")
 (current-buffer)))

;; see http://www.emacswiki.org/emacs/RotateWordCapitalization
(defun cycle-word-capitalization ()
  "*Change the capitalization of the current word.
If the word under point is in lower case, capitalize it.  If it
is in capitalized form, change it to upper case.  If it is in
upper case, downcase it."
  (interactive "*")
  (let ((case-fold-search nil))
    (save-excursion
      (skip-syntax-backward "w")
      (cond
       ((looking-at-p "[[:lower:]]+")
        (capitalize-word 1))
       ;; ((looking-at-p "[[:upper:]][[:lower:]]+")
       ;;  (upcase-word 1))
       ;; ((looking-at-p "[[:upper:]]+")
       ;;  (downcase-word 1))
       (t
        (downcase-word 1))))))
(global-defkey "M-C" 'cycle-word-capitalization)

;; http://thread.gmane.org/gmane.emacs.devel/147660/focus=147675
(defun cat-command ()
  "A command for cats."
  (interactive)
  (require 'animate)
  (let ((mouse "
           ___00
        ~~/____'>
          \"  \"")
        (h-pos (floor (/ (window-height) 2)))
        (contents (buffer-substring (window-start) (window-end))))
    (with-temp-buffer
      (switch-to-buffer (current-buffer))
      (insert contents)
      (setq truncate-lines t)
      (animate-string mouse h-pos 0)
      (dotimes (_ (window-width))
        (sit-for 0.01)
        (dotimes (n 3)
          (goto-line (+ h-pos n 2))
          (move-to-column 0)
          (insert " "))))))

(defun leo (word)
  (require 'thingatpt)
  (interactive (list 
                (let ((word (thing-at-point 'word)))
                  (if word
                      (read-string (format "Word [default \"%s\"]: " word) nil nil word)
                    (read-string "Word: ")))))
  
  (browse-url (format "http://dict.leo.org/?search=%s" (string-make-unibyte word))))

(defun wp (word)
  (require 'thingatpt)
  (interactive (list 
                (let ((word (thing-at-point 'word)))
                  (if word
                      (read-string (format "Word [default \"%s\"]: " word) nil nil word)
                    (read-string "Word: ")))))
  
  (browse-url (format "http://de.wikipedia.org/wiki/Special:Search?search=%s" word)))

(defvar spelling-alphabet
  "Buchstabe  Deutschland      ITU/ICAO/NATO
A          Anton            Alfa
Ä          Ärger            –
B          Berta            Bravo
C          Cäsar            Charlie
Ch         Charlotte        –
D          Dora             Delta
E          Emil             Echo
F          Friedrich        Foxtrot
G          Gustav           Golf
H          Heinrich         Hotel
I          Ida              India
J          Julius           Juliett
K          Kaufmann         Kilo
L          Ludwig           Lima
M          Martha           Mike
N          Nordpol          November
O          Otto             Oscar
Ö          Ökonom           –
P          Paula            Papa
Q          Quelle           Quebec
R          Richard          Romeo
S          Siegfried        Sierra
Sch        Schule           –
ß          Eszett           –
T          Theodor          Tango
U          Ulrich           Uniform
Ü          Übermut          –
V          Viktor           Victor
W          Wilhelm          Whiskey
X          Xanthippe        X-Ray
Y          Ypsilon          Yankee
Z          Zeppelin         Zulu
")

;;;_* Packages

;; sooner or later it will be loaded, so do it now.
(require 'tramp)

(when running-nt
  (setq tramp-default-method "sshx"))

(when at-bmw
  ;; /sudo:eas254.muc:/etc/fstab
  (add-to-list 'tramp-default-proxies-alist
               '("eas254\\.muc\\'" "\\`root\\'" "/sshx:eas254@%h:")))

;; jka-compr provides transparent access to compressed files.
(require 'jka-compr)
(auto-compression-mode 1)

;; Automatic resizing of help windows.
(temp-buffer-resize-mode +1)

;; enable visiting image files as images.
(if (fboundp 'auto-image-file-mode)
    (auto-image-file-mode 1))

(autoload 'ntcmd-mode "ntcmd"
  "Major mode for editing CMD scripts." t)

;;;_ + imenu
(setq imenu-always-use-completion-buffer-p 'never)

(when (require-soft 'goto-last-change)
  (global-set-key "\C-x\C-\\" 'goto-last-change))

;;;_ + Hippie-expand
(setq hippie-expand-try-functions-list
      '(try-expand-dabbrev
        try-expand-dabbrev-visible
        try-expand-dabbrev-all-buffers
        try-expand-all-abbrevs
        try-complete-lisp-symbol-partially
        try-complete-lisp-symbol
        try-expand-list
        try-complete-file-name-partially
        try-complete-file-name
        try-expand-dabbrev-from-kill))

(global-defkey "M-/" 'hippie-expand)
(global-defkey "C-M-/" 'dabbrev-completion)

(setq-default truncate-lines nil)
(setq truncate-partial-width-windows nil)

;;;_  + chop: binary search for a line within a window
(autoload 'chop-move-up "chop")
(autoload 'chop-move-down "chop")
(eval-after-load "chop"
  '(setq chop-lines-near-middle nil))

(global-defkey "S-<up>" 'chop-move-up)
(global-defkey "S-<down>" 'chop-move-down)

(global-defkey "C-," 'chop-move-up)
(global-defkey "C-." 'chop-move-down)

(when (require-soft 'autopair)
  (defun autopair-dont-pair-before-words (action pair pos-before)
    (if (eq action 'opening)
        (let ((char-after-point (char-after (1+ pos-before))))
          (if (and char-after-point
                   (eq (char-syntax char-after-point) ?w))
              t
            (autopair-default-handle-action action pair pos-before)))
      t))
  (setq autopair-handle-action-fns '(autopair-dont-pair-before-words))
  (autopair-global-mode 1)
  (setq autopair-autowrap t))

;;;_ + Find file at point
(require 'ffap)
(setq ffap-require-prefix t)
(setq ffap-highlight nil)
(when running-nt
  (setq ffap-url-regexp nil))

(defun ffap-read-only ()
  "Like \\[find-file] but marks buffer as read-only.
Only intended for interactive use."
  (interactive)
  (let ((ffap-file-finder 'find-file-read-only))
    (call-interactively 'ffap)))

(defun ffap-read-only-other-window ()
  "Like \\[ffap-other-window] but marks buffer as read-only.
Only intended for interactive use."
  (interactive)
  (let ((ffap-file-finder 'find-file-read-only-other-window))
    (call-interactively 'ffap)))

(defun ffap-read-only-other-window-noselect ()
  "Like \\[ffap-read-only-other-window] but don't select buffer.
Only intended for interactive use."
  (interactive)
  (let ((ffap-file-finder 'find-file-read-only-other-window))
    (save-selected-window
      (call-interactively 'ffap))))

;;(ffap-bindings)
(global-defkey "C-x C-f"   'find-file-at-point)
(global-defkey "C-x 4 f"   'ffap-other-window)
(global-defkey "C-x 4 C-f" 'ffap-other-window)
;;(global-defkey "C-x d"     'dired-at-point)
(global-defkey "C-x C-r"   'ffap-read-only)
(global-defkey "C-x 4 r"   'ffap-read-only-other-window)
(global-defkey "C-x 4 R"   'ffap-read-only-other-window-noselect)


;;;_ + Gnuplot
(autoload 'gnuplot "gnuplot"
  "Run Gnuplot interactively in a Emacs buffer." t nil)
(autoload 'gnuplot-interaction-mode "gnuplot-interaction"
  "Major mode for editing Gnuplot input files." t nil)

;;;_ + Shell-script
(autoload 'sh-mode "sh-script" 
  "Major mode for editing shell scripts" t nil)
(eval-after-load "sh-script"
  '(set-face-foreground 'sh-heredoc-face (face-foreground 'font-lock-constant-face)))
(add-hook 'after-save-hook
  'executable-make-buffer-file-executable-if-script-p)
(add-hook 'sh-mode-hook
          (lambda ()
            (setq defun-prompt-regexp "^\\(function[ \t]\\|[^[:space:]]+[ \t]+()[ \t]+\\)")))

;; the-the is a nice thing for text processing:
(autoload 'the-the "the-the"
  "Search forward for for a duplicated word." t nil)

;;;_ + apropos
(defun apropos-function ()
  "*Show functions that match REGEXP."
  (interactive)
  (require 'apropos)
  (let ((apropos-do-all t))
    (call-interactively 'apropos-command)))

;;;_ + anything
(when (require-soft 'anything)
  (setq anything-command-map-prefix-key "M-<RET>")
  (require 'anything-config)
  (require-soft 'anything-match-plugin)

  (defkey anything-map "<f4>" 'anything-next-line)
  (defkey anything-map "<S-f4>" 'anything-previous-line)
  (defkey anything-map "C-h" 'anything-previous-line)

  ;; override original definition to provide default selection of the
  ;; symbol at point.
  (defun anything-imenu ()
    "*Preconfigured `anything' for `imenu'."
    (interactive)
    (anything 'anything-c-source-imenu nil nil nil (thing-at-point 'symbol) "*anything imenu*"))

  ;; http://emacs-fu.blogspot.com/2011/09/finding-just-about-anything.html
  (defun anything-switch-buffer ()
    (interactive)
    (anything
     :prompt "Switch to: "
     :candidate-number-limit 10 ;; up to 10 of each 
     :sources
     '(anything-c-source-buffers             ;; buffers 
       anything-c-source-recentf             ;; recent files 
       anything-c-source-files-in-current-dir+ ;; current dir
       anything-c-source-bookmarks             ;; bookmarks
       )))

  (defkey ctl-x-map "b" 'anything-switch-buffer))

;;;_ + iswitchb
(if (fboundp 'iswitchb-mode)
    (iswitchb-mode)
  (iswitchb-default-keybindings))
(setq read-buffer-function 'iswitchb-read-buffer)
(setq iswitchb-case t)
(when (require-soft 'recentf)
  (recentf-mode 1)
  (setq iswitchb-use-virtual-buffers t))
(setq iswitchb-regexp nil)
(setq iswitchb-prompt-newbuffer nil)
(setq iswitchb-default-method 'samewindow)
(setq iswitchb-all-frames 'no)
(add-to-list 'iswitchb-buffer-ignore "^\\*Ibuffer")

(defun major-mode-matches (buffer regexp)
  "*Return t if `mode-name' in  BUFFER matches REGEXP.
To be used mainly as a filter in iswitchb to select only buffers
whose major-mode matches REGEXP."
  (with-current-buffer buffer
    (string-match regexp (format-mode-line mode-name))))

(defun iswitchb-only-dired-buffers (buffer)
  "*Ignore all buffers not in dired-mode."
  (not (major-mode-matches buffer "\\`Dired\\>")))

(defun iswitchb-dired-buffers ()
  "*Switch to a Dired buffer."
  (interactive)
  (let ((iswitchb-buffer-ignore '(iswitchb-only-dired-buffers)))
    (call-interactively 'iswitchb-buffer)))

(global-defkey "C-x D" 'iswitchb-dired-buffers)

(defun iswitchb-only-shell-buffers (buffer)
  "*Ignore all buffers not in shell-mode."
  (not (major-mode-matches buffer "\\`Shell\\'")))

(defun iswitchb-shell-buffers ()
  "*Switch to a Shell buffer."
  (interactive)
  (let ((iswitchb-buffer-ignore '(iswitchb-only-shell-buffers)))
    (call-interactively 'iswitchb-buffer)))

;; Kin Cho
(defun iswitchb-exclude-nonmatching ()
  "*Exclude non matching buffer names."
  (interactive)
  (setq iswitchb-buflist iswitchb-matches)
  (setq iswitchb-rescan t)
  (delete-minibuffer-contents))

(defun iswitchb-rescan ()
  "*Regenerate the list of matching buffer names."
  (interactive)
  (iswitchb-make-buflist iswitchb-default)
  (setq iswitchb-rescan t))

(add-hook 'iswitchb-define-mode-map-hook 'iswitchb-my-keys)
(defun iswitchb-my-keys ()
 "*Add custom keybindings for iswitchb."
 (defkey iswitchb-mode-map "C-o" 'iswitchb-exclude-nonmatching)
 (defkey iswitchb-mode-map "C-M-l" 'iswitchb-rescan)
;; Cause problem in conjunction with minibuffer-complete-cycle!
;; (defkey iswitchb-mode-map "ESC" 'keyboard-escape-quit)
 (defkey iswitchb-mode-map "<f4>" 'iswitchb-next-match)
 (defkey iswitchb-mode-map "<S-f4>" 'iswitchb-prev-match)
 (defkey iswitchb-mode-map "<kp-add>" 'iswitchb-next-match)
 (defkey iswitchb-mode-map "<kp-subtract>" 'iswitchb-prev-match)
 (defkey iswitchb-mode-map "C-a" 'iswitchb-toggle-ignore)
 (defkey iswitchb-mode-map "C-z C-f" 'iswitchb-find-file))

(global-defkey "<kp-subtract>" 'bury-buffer)
(global-defkey "<kp-add>"      'iswitchb-buffer)

(defadvice iswitchb-kill-buffer (after rescan-after-kill activate)
  "*Regenerate the list of matching buffer names after a kill.
Necessary if using `uniquify' with `uniquify-after-kill-buffer-p'
set to non-nil."
  (setq iswitchb-buflist iswitchb-matches)
  (iswitchb-rescan))


(require-soft 'minibuf-isearch)


;;;_ + autoinsert
(setq auto-insert-directory (concat user-emacs-directory "auto-insert/"))
(auto-insert-mode 1)
(add-to-list 'auto-insert-alist '(("/\\.?lib/zsh/" . "ZSH function")
                                  "Short description: "
                                  '(shell-script-mode)
                                  "#!/usr/bin/env zsh
## Time-stamp: <>
## Emilio Lopes <eclig@gmx.net>

## " (file-name-nondirectory (buffer-file-name)) " --- " str "

## THIS FILE IS IN THE PUBLIC DOMAIN.  USE AT YOUR OWN RISK!

# " (file-name-nondirectory (buffer-file-name)) " () {

emulate -LR zsh

" _ "

# }\n"))
(add-to-list 'auto-insert-alist '(perl-mode . "header.pl"))
(add-to-list 'auto-insert-alist '("\\.pl\\'" . "header.pl"))


;;;_ + winner
(when (require-soft 'winner)
  (winner-mode +1))


;;;_ + completion
(defadvice PC-lisp-complete-symbol (before forward-sexp-before-completion (&optional arg) activate)
  "Do a `forward-sexp' if necessary before trying completion.
With prefix argument ARG behave as usual."
  (interactive "P")
  (unless arg
    (when (looking-at "\\sw\\|\\s_")
      (forward-sexp))))

(partial-completion-mode 1)

(setq resize-mini-windows t)

;; Stefan Monnier
;; Press `C-s' at the prompt to search the completion buffer
(defun complete-isearch (regexp)
  "Search in the completions.  If a prefix is given, use REGEXP isearch."
  (interactive "P")
  (unless (and (memq last-command '(minibuffer-complete
        minibuffer-completion-help))
        (window-live-p minibuffer-scroll-window))
    (minibuffer-completion-help))
  (with-current-buffer (window-buffer minibuffer-scroll-window)
    (save-window-excursion
      (select-window minibuffer-scroll-window)
      (if (isearch-forward regexp nil)
   (choose-completion)))))
(defkey minibuffer-local-completion-map "C-s" 'complete-isearch)
(defkey minibuffer-local-must-match-map "C-s" 'complete-isearch)

(defkey minibuffer-local-map "M-N" 'next-complete-history-element)
(defkey minibuffer-local-map "M-P" 'previous-complete-history-element)

(setq completion-ignored-extensions (delete ".pdf" completion-ignored-extensions))


;;;_ + Get the little rodent out of way
(when (and (display-mouse-p)
           (require-soft 'avoid))
  ;; (mouse-avoidance-mode 'banish)
  (defun toggle-mouse-avoidance-mode ()
    (interactive)
    (mouse-avoidance-mode)))


;;;_ + Filladapt
(when (require-soft 'filladapt)
  (setq filladapt-fill-column-tolerance 6)
  (setq filladapt-mode-line-string nil)
  (add-hook 'text-mode-hook 'turn-on-filladapt-mode))

;;;_ + Uniquify
(require 'uniquify)
(setq uniquify-after-kill-buffer-p t)
(setq uniquify-buffer-name-style 'forward)
(setq uniquify-ignore-buffers-re
      "\\(news\\|mail\\|reply\\|followup\\) message\\*")

;;;_ + Time-stamp 
(add-hook 'write-file-hooks 'time-stamp)
(setq time-stamp-active t)
(setq time-stamp-warn-inactive t)
(unless (string-match "^ecl\\(ig\\)?" (user-login-name))
  ;; use full name instead of login name in time-stamps
  (setq time-stamp-format "%:y-%02m-%02d %02H:%02M:%02S %U"))

;;;_ + font-lock mode
(when (display-color-p)
  (require-soft 'font-latex)
  (setq font-lock-support-mode 'jit-lock-mode)
  (setq font-lock-maximum-decoration t)
  (global-font-lock-mode 1)
  (setq font-lock-verbose nil)
  (set-face-foreground 'font-lock-comment-face "red")
  (set-face-foreground 'font-lock-string-face "indianred")
  (set-face-foreground 'font-lock-type-face "darkgreen")
  (set-face-foreground 'font-lock-variable-name-face "DodgerBlue")
  (set-face-foreground 'font-lock-constant-face "blue2")
  (set-face-foreground 'font-lock-variable-name-face "#008b8b")
  (add-hook 'font-lock-mode-hook
            (lambda ()
              (font-lock-add-keywords nil '(("\\*\\(ECL\\|FIXME\\)\\*:?" 0 'show-paren-mismatch-face t))))))

;;;_* Keybindings
(when running-nt
  (global-defkey "<apps>" 'undo))

;; extra "C-x" for Dvorak keyboard layouts, in the same hand as "s",
;; "f", "w", "v".
(global-defkey "C-z" ctl-x-map)
(or key-translation-map (setq key-translation-map (make-sparse-keymap)))
(define-key key-translation-map "\C-z8" 'iso-transl-ctl-x-8-map)

;; put `previous-line' in the same hand as `next-line' in Dvorak layout
(global-defkey "C-h"     'previous-line)
(global-defkey "C-x C-h" help-map)

(global-defkey "C-M-<backspace>" 'backward-kill-sexp)

;; (global-defkey "C-M-<SPC>" 'copy-sexp)
(global-defkey "M-k" 'copy-line)
(global-defkey "M-K" 'kill-sentence)
(global-defkey "M-+" 'delete-horizontal-space-forward)

(defkey esc-map ")" 'up-list)

(global-defkey "C-c 0" (recursive-edit-preserving-window-config (delete-window)))
(global-defkey "C-c 1" (recursive-edit-preserving-window-config
                        (if (one-window-p 'ignore-minibuffer)
                            (error "Current window is the only window in its frame")
                          (delete-other-windows))))
(global-defkey "C-c 2" (recursive-edit-preserving-window-config (split-window-vertically)))
(global-defkey "C-c 3" (recursive-edit-preserving-window-config (split-window-horizontally)))
(global-defkey "C-c 4 b" (recursive-edit-preserving-window-config (iswitchb-buffer-other-window)))
(global-defkey "C-c 4 C-o" (recursive-edit-preserving-window-config (iswitchb-display-buffer)))

(global-defkey "C-c $" 'toggle-truncate-lines)
(global-defkey "C-c \\" 'the-the)
(global-defkey "C-c ;" 'comment-or-uncomment-region)
(global-defkey "C-c ~" 'diff-backup-this-file)

(global-defkey "C-c a" 'show-time-and-date)
;; (global-defkey "C-c b" 'browse-url)

(global-defkey "C-c b" (lambda () (interactive) (mouse-avoidance-banish-mouse)))

(bind-with-new-map (current-global-map) "C-c d"
  ("b" . 'ediff-buffers)
  ("f" . 'ediff-files)
  ("d" . 'ediff-directories)
  ("P" . 'ediff-patch-file)
  ("p" . 'ediff-patch-buffer)

  ("m" . 'ediff-merge-buffers)
  ("M" . 'ediff-merge-files)

  ("i" . 'ediff-documentation)
  ("y" . 'ediff-show-registry))

(global-defkey "C-c e" (make-sparse-keymap))
(global-defkey "C-c e b"        'eval-buffer)
(global-defkey "C-c e d"        'byte-recompile-directory)
(global-defkey "C-c e e"        'eval-last-sexp)
(global-defkey "C-c e f"        'byte-compile-file)
(global-defkey "C-c e i"        'indirect-elisp-buffer)
(global-defkey "C-c e r"        'eval-region)
(global-defkey "C-c e t"        'top-level)

(bind-with-new-map (current-global-map) "C-c f"
  ("f" . 'find-function)
  ("k" . 'find-function-on-key)
  ("v" . 'find-variable)
  ("l" . 'find-library))

(bind-with-new-map (current-global-map) "C-c m"
  ("a" . 'abbrev-mode)
;; ("b" . 'toggle-skeleton-pair)         ; "b" as "brackets"
  ("f" . 'auto-fill-mode)
  ("s" . 'flyspell-mode)
  ("p" . 'autopair-mode)
  ("P" . 'paredit-mode)
  ("l" . 'longlines-mode)
  ("m" . 'toggle-mouse-avoidance-mode)
  ("$" . (lambda ()
           (interactive)
           (setq show-trailing-whitespace (not show-trailing-whitespace))
           (redraw-frame (selected-frame)))))

(global-defkey "C-c j" (make-sparse-keymap))
(global-defkey "C-c j h"        (lambda () (interactive) (dired     "~")))
(global-defkey "C-c j D"        (lambda () (interactive) (dired     (concat (or (getenv "USERPROFILE") "~") "/Downloads"))))
(global-defkey "C-c j p"        (lambda () (interactive) (dired     "e:/qx29999/projs")))
(global-defkey "C-c j d"        (lambda () (interactive) (find-library "init-dired")))
(global-defkey "C-c j e"        (lambda () (interactive) (find-file user-init-file)))
(global-defkey "C-c j m"        (lambda () (interactive) (find-library "message_rc")))
(global-defkey "C-c j g"        (lambda ()
                                  (interactive)
                                  (if (boundp 'gnus-init-file)
                                      (find-file  gnus-init-file)
                                    (find-library  "gnus_rc"))))
(global-defkey "C-c j s"        (lambda () (interactive) (find-library "init-shell")))
(global-defkey "C-c j t"        (lambda () (interactive) (find-file "u:/ORG/TODO")))

(global-defkey "C-c j ."        (lambda () (interactive) (find-file "~/.ee.sh")))

(global-defkey "C-c j z"        (lambda () (interactive) (find-file "~/.zshrc")))
(global-defkey "C-c j a"        (lambda () (interactive) (find-file "~/.zaliases")))
(global-defkey "C-c j l"        (lambda () (interactive) (find-file "~/.zprofile")))
(global-defkey "C-c j v"        (lambda () (interactive) (find-file "~/.zshenv")))

(global-defkey "C-c g" 'goto-line)
(global-defkey "M-g" 'goto-line)

(global-defkey "M-i" 'other-window)

(global-defkey "C-c t" 'insert-date)

(global-defkey "C-c s" 'jump-to-scratch-buffer)
(global-defkey "C-c z" 'jump-to-text-scratch-buffer)

(global-defkey "C-c u" 'rename-uniquely)
(global-defkey "C-c w" 'copy-filename-as-kill)

(bind-with-new-map help-map "a"
  ("a" . 'apropos)
  ("c" . 'apropos-command)
  ("f" . 'apropos-function)
  ("v" . 'apropos-variable)
  ("d" . 'apropos-documentation)
  ("i" . 'apropos-info)
  ("l" . 'apropos-value))

(global-defkey "C-x C-q" 'toggle-read-only)
(global-defkey "C-x v q" 'vc-toggle-read-only)

(setq outline-minor-mode-prefix (kbd "C-c C-o"))

(global-defkey "C-M-%"          'query-replace-regexp)
(global-defkey "C-x k"          'kill-this-buffer)
(global-defkey "C-x I"          'insert-buffer)  ; `insert-file' is on "C-x i"

(global-defkey "<home>"         'beginning-of-line)
(global-defkey "<end>"          'end-of-line)

(global-defkey "C-<home>"       'move-to-window-top)
(global-defkey "C-<end>"        'move-to-window-bottom)

(global-defkey "C-<prior>"      'move-to-window-top)
(global-defkey "C-<next>"       'move-to-window-bottom)

(global-defkey "C-x <left>"  'windmove-left)
(global-defkey "C-x <right>" 'windmove-right)
(global-defkey "C-x <up>"    'windmove-up)
(global-defkey "C-x <down>"  'windmove-down)

(global-defkey "S-<backspace>"  'backward-delete-char-hungry)

(global-defkey "<f1>"           'info)
(global-defkey "S-<f1>"         'woman)

(global-defkey "<f2>"           'save-buffer)
(global-defkey "S-<f2>"         'revert-buffer-preserve-modes)

(global-defkey "<f3>"           'dired-jump)
(global-defkey "S-<f3>"         'shell-hier)

(global-defkey "<f4>"           'iswitchb-buffer)
;; (global-defkey "<f4>"           'anything-switch-buffer)
(global-defkey "S-<f4>"         'bury-buffer)

(global-defkey "<f5>"           'resize-window)
(global-defkey "S-<f5>"         'swap-window-positions)

(global-defkey "<f7>"           'insert-default-register)
(global-defkey "S-<f7>"         'copy-to-default-register)

(global-defkey "<f8>"           'grep)
(global-defkey "S-<f8>"         'grep-find)

(global-defkey "<f9>"           'next-error)
(global-defkey "S-<f9>"         'compile)

(global-defkey "<f10>"           'call-last-kbd-macro)
(global-defkey "S-<f10>"         'apply-macro-to-region-lines)

;; (global-defkey "<f12>"           'toggle-window-dedicated)

;; Make <f12> act like Hyper, for keyboards without it. Just like
;; <f11> acts as Meta on older DEC terminals.
;; Must undef it first for the function-key-map binding to work
;; (global-unset-key [f12])
;; (define-key function-key-map [f12] 'event-apply-hyper-modifier)

(global-defkey "<f12>" 'imenu)

(global-defkey "<scroll>" 'toggle-window-dedicated) ; that's `scroll-lock'

(global-defkey "<find>"         'isearch-forward)
(global-defkey "<execute>"      'execute-extended-command)

(global-defkey "<print>"        'ps-spool-buffer-with-faces)
(global-defkey "S-<print>"      'set-default-printer)

;;;_* Frame parameters
(add-to-list 'default-frame-alist '(cursor-type . box))

;;;_* Time (and date) display setup.
(display-time-mode 1)
(setq display-time-interval 5)
(setq display-time-day-and-date nil)
(setq display-time-24hr-format t)
(setq display-time-use-mail-icon t)
(when running-nt
  (set-time-zone-rule "GMT-1"))

;;;_* Mode-line and Frame-title format:

(setq line-number-display-limit-width 512)

(setq-default frame-title-format (list "" "Emacs Macht Alle Computer Sch\366n"))

(setq-default icon-title-format frame-title-format)

;;;_* Common modes stuff
;; Add some suffix defs to auto-mode-alist:
(dolist (f (list auto-mode-alist interpreter-mode-alist))
  (while (rassq 'perl-mode f)
    (setcdr (rassq 'perl-mode f) 'cperl-mode)))
(setq auto-mode-alist (append '(("\\.\\([bB][aA][tT]\\|[cC][mM][dD]\\)\\'" . ntcmd-mode)
                                ("[^/]\\.dired\\'" . dired-virtual-mode)
                                ("\\.fi\\'" . fortran-mode)
                                ("\\.bash_\\(functions\\|aliases\\)\\'" . sh-mode)
                                ("\\.\\(SCORE\\|ADAPT\\)\\'" . gnus-score-mode)
                                ("\\.gpt?\\'" . gnuplot-interaction-mode)
                                ("\\.mak?\\'" . makefile-mode)
                                ("\\.col?\\'" . c-mode)
                                ("\\.hol?\\'" . c-mode)
                                ("\\.kgs?\\'" . c-mode)
                                ("\\.dtx\\'" . latex-mode))
                              auto-mode-alist))


(when at-bmw
  (setq auto-mode-alist (append '(("\\.dat?\\'" . c-mode)) auto-mode-alist)))

;;;_* kill-ring
(setq kill-ring-max 1024)
(setq save-interprogram-paste-before-kill t)

;; Thanks to Karl Fogel:
;; http://svn.red-bean.com/repos/kfogel/trunk/.emacs
(defun kf-browse-kill-ring ()
  "Browse the kill ring."
  (interactive)
  (switch-to-buffer (get-buffer-create "*Browse Kill Ring*"))
  (widen)
  (delete-region (point-min) (point-max))
  (mapcar
   (lambda (str)
     ;; We could put the full string as a text property on the summary
     ;; text displayed, but with yank-match available, there's no need.
     (insert (substring str 0 (min (length str) 72))
             "\n-*- -*- -*- -*- -*-\n"))
   kill-ring)
  (goto-char (point-min)))

(global-defkey "<f11>" 'kf-browse-kill-ring)
;; From http://lists.gnu.org/archive/html/emacs-devel/2008-03/msg00128.html
;; See also http://svn.red-bean.com/repos/kfogel/trunk/code/yank-match/
(defun insert-yank-from-kill-ring (string)
  "Insert the selected item from the kill-ring in the minibuffer history.
Use minibuffer navigation and search commands to browse the kill-ring
in the minibuffer history."
  (interactive (list (read-string "Yank from kill-ring: " nil 'kill-ring)))
  (insert-for-yank string))

;; Emacs 23.2 introduced `kill-do-not-save-duplicates': if it is
;; non-nil, identical subsequent kills are not duplicated in the
;; `kill-ring'.
(defadvice kill-new (around kill-ring-avoid-duplicates activate)
  "Only insert STRING in the kill-ring if not already there."
  (setq kill-ring (delete (ad-get-arg 0) kill-ring))
  ad-do-it)

;;;_* Major modes

;;;_ + Ispell

(setq-default ispell-local-dictionary "deutsch8")

(global-defkey "C-c i w" 'ispell-word)
(global-defkey "C-c i m" 'ispell-message)
(global-defkey "C-c i b" 'ispell-buffer)
(global-defkey "C-c i r" 'ispell-region)
(global-defkey "C-c i c" 'ispell-change-dictionary)
(global-defkey "C-c i k" 'ispell-kill-ispell)

(global-defkey "C-c i d"
  (lambda () "*Set German dictionary (Ispell)."
    (interactive) 
    (ispell-change-dictionary "deutsch8")))
(global-defkey "C-c i e"
  (lambda () "*Set English dictionary (Ispell)."
    (interactive)
    (ispell-change-dictionary "english")))
(global-defkey "C-c i p"
  (lambda () "*Set Portuguese dictionary (Ispell)."
    (interactive)
    (ispell-change-dictionary "portugues")))

(defun show-current-ispell-dictionary ()
  "*Display the value of ispell-dictionary in the echo area."
  (interactive)
  (if ispell-dictionary
      (message "Current dictionary: %s" ispell-dictionary)
    (message "Variable `ispell-dictionary' is not set.")))

(global-defkey "C-c i w" 'show-current-ispell-dictionary)


;;;_ + magit
(add-to-path 'load-path (concat user-emacs-directory "lib/magit"))
(when at-bmw
  (setq magit-git-executable "f:/apps/PortableGit-1.7.4/bin/git.exe"))
(autoload 'magit-status "magit" nil t)


;;;_ + nxml
;; (setq magic-mode-alist (cons '("<\\?xml " . nxml-mode) magic-mode-alist))
;; (defun nxml-kill-element (&optional arg)
;;   "*Kill the following element.
;; With optional argument ARG kill the next ARG elements."
;;   (interactive "*")
;;   (kill-region (point)
;;                (save-excursion 
;;                  (nxml-forward-element arg)
;;                  (point))))
(eval-after-load "nxml-mode"
  '(defun nxml-where ()
     "Display the hierarchy of XML elements the point is on as a path."
     (interactive)
     (let ((path nil))
       (save-excursion
         (save-restriction
           (widen)
           (while (condition-case nil
                      (progn
                        (nxml-backward-up-element) ; always returns nil
                        t)       
                    (error nil))
             (setq path (cons (xmltok-start-tag-local-name) path)))
           (message "/%s" (mapconcat 'identity path "/")))))))

;; (add-hook 'nxml-mode-hook
;;           (lambda ()
;;             (defkey nxml-mode-map "C-c M-k" 'nxml-kill-element)))



;;;_ + TeX
(setq tex-dvi-view-command
      (if (eq window-system 'x) "xdvi" "dvi2tty -q * | cat -s"))
(setq tex-dvi-print-command "dvips")
(setq tex-alt-dvi-print-command
      '(format "dvips -P%s" (read-string "Use printer: " ps-printer-name)))
(setq tex-open-quote "\"")              ; disable "smart quoting".
(setq tex-close-quote "\"")


;;;_ + AUCTeX
(when (require-soft 'tex-site)
  (setq LaTeX-math-abbrev-prefix "#")
  (setq TeX-open-quote "\"")              ; disable "smart quoting".
  (setq TeX-close-quote "\"")
  (add-hook 'LaTeX-mode-hook
            (lambda ()
              (setq  TeX-show-compilation nil)
              (setq LaTeX-default-environment "equation")
              ;;             (local-defkey "{" 'TeX-insert-braces)
              ;;             (local-defkey "}" 'up-list)
              (local-defkey "S-<f9>" (lambda ()(interactive)
                                       (let ((TeX-show-compilation nil))
                                         (TeX-command "LaTeX" 'TeX-master-file))))
              (local-defkey "<f9>" 'TeX-next-error))))


;;;_ + reftex
(setq reftex-insert-label-flags '("s" "sfte"))
(setq reftex-label-alist
      '(("equation" ?e "eq:" "~\\eqref{%s}" t (regexp "equations?" "eqs?\\." "eqn\\." "Gleichung\\(en\\)?"  "Gl\\."))))


;;;_ + BBDB
(when (require-soft 'bbdb)
  (bbdb-initialize 'gnus 'message)
  (add-hook 'gnus-startup-hook 'bbdb-insinuate-gnus)
  (setq bbdb-dwim-net-address-allow-redundancy t)
  (setq bbdb-use-pop-up t)
  (setq bbdb-display-layout 'one-line)
  (setq bbdb-pop-up-display-layout 'one-line)
  (setq bbdb-complete-name-allow-cycling t)
  (setq bbdb-offer-save 'save)
  (setq bbdb-quiet-about-name-mismatches 0)
  (setq bbdb-user-mail-names "\\(ecl\\(ig\\)?\\|[Ee]milio[_.][Ll]opes\\)@.+")
  ;;(setq bbdb/mail-auto-create-p t)
  ;;(setq bbdb/news-auto-create-p t)
  (setq bbdb-north-american-phone-numbers-p nil)
  (setq bbdb-check-zip-codes-p nil))

;; BrYan P. Johnson (bilko@onebabyzebra.com)
(defadvice bbdb-complete-name (after bbdb-complete-name-default-domain activate)
  (let* ((completed ad-return-value))
    (when (null completed)
      (expand-abbrev))))


;;;_ + SES
(eval-after-load "ses" '(require-soft 'ses-formulas))



;;;_ + text
;; (add-hook 'text-mode-hook 'turn-on-auto-fill)
;; (add-hook 'text-mode-hook (lambda ()
;;                             (flyspell-mode +1)))
;; (add-hook 'text-mode-hook (lambda ()
;;                             (longlines-mode +1)))

(add-hook 'text-mode-hook 'fix-broken-outlook-replies)

(defun fix-broken-outlook-replies ()
  (let ((bname (buffer-file-name)))
    (when (and (stringp bname)
               (string-match-p "/bmwmail\\." bname))
      (goto-char (point-max))
      (delete-blank-lines)
      (goto-char (point-min))
      ;; (delete-blank-lines)

      (let ((sig-start (and (search-forward-regexp "^-- *$" nil t)
                            (point-at-bol)))
            (citation-start (and (search-forward-regexp "^_______________+$" nil t)
                                 (progn (delete-region (point-at-bol) (min (1+ (point-at-eol)) (point-max)))
                                        (point-at-bol)))))

        (when citation-start
          (replace-regexp "^" "> " nil citation-start (1- (point-max))))

        ;; (goto-char (point-max))

        (save-excursion
          (when sig-start
            (let ((sig (delete-and-extract-region sig-start (or citation-start (point-max)))))
              (goto-char (point-max))
              (insert "\n" sig))))))))

;;;_ + Fortran
(defun fortran-uncomment-empty-lines (beg end)
  "*Remove comment characters from empty lines in region."
  (interactive "*r")
  (save-excursion
    (goto-char beg)
    (while (re-search-forward "^[*Cc!]+[ \t]*$" end t)
      (replace-match ""))))

(defun fortran-insert-print (vars)
  (interactive (list (read-from-minibuffer "Print: ")))
  (let ((vars (split-string vars "[ \t,]+"))
        varstring)
    (while vars
      (setq varstring (concat varstring (and varstring ", ") (car vars)))
      (setq vars (cdr vars)))
    (insert (format "print *, '%s: ', %s" varstring varstring))))

(defun my-fortran-mode-hook ()
  "*Setup fortran-mode."
  (setq fortran-startup-message nil
        fill-column 72
        fortran-continuation-string "&"
        fortran-comment-region "*"
        comment-line-start "*"
        comment-start "! "
        fortran-comment-indent-style nil
        fortran-blink-matching-if t
        fortran-tab-mode-default nil
        fortran-line-number-indent 5)
  (defkey fortran-mode-map "M-q" 'fortran-fill)
  (defkey fortran-mode-map "C-c p" 'fortran-insert-print)
  (abbrev-mode 1)
  (set (make-local-variable 'grep-command) "grep -ni ")
  (set (make-local-variable 'igrep-options) "-i")
  (set-compile-command "g77 -c %s"))
(add-hook 'fortran-mode-hook 'my-fortran-mode-hook)



;;;_ + Scheme/Lisp modes

(require 'init-lisp)

(defun jump-to-scratch-buffer (&optional arg)
  "*Switch to buffer `*scratch*', creating it if necessary.
With prefix arg clear the buffers content."
  (interactive "P")
  (switch-to-buffer-create "*scratch*" 'lisp-interaction-mode arg))

(defun jump-to-text-scratch-buffer (&optional arg)
  "*Switch to buffer `*text scratch*', creating it if necessary.
With prefix arg generate a fresh buffer."
  (interactive "P")
  (let ((buffer-name "*text scratch*"))
    (switch-to-buffer-create
     (if arg (generate-new-buffer-name buffer-name) buffer-name)
     (if (fboundp 'org-mode)
         'org-mode
       'text-mode)
     nil)))


;;;_ + Perl mode
;; use cperl-mode as default
;; (defalias 'perl-mode 'cperl-mode)
(setq cperl-hairy nil)
(setq cperl-font-lock t)
(setq cperl-clobber-lisp-bindings nil)
(setq cperl-lazy-help-time 1)
(setq cperl-info-page "Perl")

(defun perl-insert-dumper (var)
  "Insert a Perl print statement to print out variable VAR.
If VAR begins with one of `@%$' use `Data::Dumper'."
  (interactive "*MVariable: ")
  (insert
   (format (if (string-match "^[@%$].+" var)
               "print \"+++ \\%s: \", Dumper(\\%s), \"\\n\";"
             "print \"+++ %s: $%s\\n\";") var var)))
(add-hook 'cperl-mode-hook
	  (lambda ()
            (cperl-lazy-install)
            (when (fboundp 'skeleton-pair-insert-maybe)
              (fset 'cperl-electric-paren 'skeleton-pair-insert-maybe)
              (fset 'cperl-electric-rparen 'self-insert-command))
	    (set-compile-command "perl -cw %s")))


;;;_ + PHP
(require-soft 'php-mode)

(defun php (symbol)
  (require 'thingatpt)
  (interactive (list 
                (let ((symbol (thing-at-point 'symbol)))
                  (if symbol
                      (read-string (format "Symbol [default \"%s\"]: " symbol) nil nil symbol)
                    (read-string "Symbol: ")))))
  
  (browse-url (format "http://www.php.net/%s" (string-make-unibyte symbol))))


;;;_ + Compile
(setq compile-command "make ")
(setq compilation-read-command nil)
(setq compilation-ask-about-save t)
(setq compilation-scroll-output t)
(add-hook 'compilation-mode-hook (lambda () (toggle-truncate-lines -1)))

(defun set-compile-command (command)
  "*Locally set `compile-command' to COMMAND.
Look for a file named `GNUmakefile', `Makefile' or `makefile' in the buffer's
directory. If it can not be found, set `compile-command' locally to COMMAND.
An occurence of \"%s\" in COMMAND is substituted by the filename."
  (unless (or (file-exists-p "GNUmakefile")
              (file-exists-p "Makefile")
              (file-exists-p "makefile")
              (null buffer-file-name))
    (set (make-local-variable 'compile-command)
         (format command (file-name-nondirectory buffer-file-name)))))


;;;_ + Makefile mode
;; (setq makefile-electric-keys t)
(add-hook 'makefile-mode-hook
          (lambda ()
            (modify-syntax-entry ?. "_"  makefile-mode-syntax-table)))


;;;_ + Sendmail configuration
;;(setq mail-user-agent 'gnus-user-agent)
(setq mail-user-agent 'message-user-agent)

(setq mail-archive-file-name "~/Mail/Outgoing")

(setq user-full-name "Emilio C. Lopes")
(when at-bmw
  (setq user-mail-address "Emilio.Lopes@partner.bmw.de")
  (setq mail-default-reply-to "Emilio.Lopes@partner.bmw.de"))

(setq mail-from-style nil)

(setq mail-aliases t)
(setq mail-personal-alias-file "~/.mailrc")

(setq mail-yank-prefix "> ")

(add-hook 'mail-setup-hook 'mail-abbrevs-setup)


;;;_ + Message
(add-hook 'message-load-hook (lambda () (require-soft 'message_rc)))


;;;_ + Resume/Server configuration.
;; With these hooks and using emacs.bash (or emacs.csh), both from
;; "etc" dir, it is possible to specify arguments when resuming emacs
;; after a suspension.
(add-hook 'suspend-hook 'resume-suspend-hook)
(add-hook 'suspend-resume-hook 'resume-process-args)
(server-start)


;;;_ + Abbrevs
(setq save-abbrevs 'silently)
(quietly-read-abbrev-file)


;;;_ + Bookmarks
(setq bookmark-default-file (locate-user-emacs-file "bookmarks" ".emacs.bookmarks"))
(setq bookmark-save-flag 1)

(defadvice bookmark-load (before prefix-arg-revert activate)
  "A prefix arg is interpreted to specify (non-nil) REVERT."
  (if (interactive-p)
      (ad-set-arg 1 current-prefix-arg)))

(defun bookmark-location-as-kill ()
  "*Copy location of this bookmark to the kill ring."
  (interactive)
  (if (bookmark-bmenu-check-position)
      (let ((location (bookmark-location (bookmark-bmenu-bookmark))))
        (kill-new location)
        (message location))))

(defun my-bookmark-load-hook ()
  (defkey bookmark-bmenu-mode-map "<RET>" 'bookmark-bmenu-this-window)
  (defkey bookmark-bmenu-mode-map "w" 'bookmark-location-as-kill))

(add-hook 'bookmark-load-hook 'my-bookmark-load-hook)

;; From http://www.emacswiki.org/cgi-bin/wiki.pl/GraphicalBookmarkJump
(defun iswitchb-bookmark-jump (bname)
  "*Switch to bookmark interactively using `iswitchb'."
  (interactive (list (flet
                         ((iswitchb-make-buflist (default)
                                                 (require 'bookmark)
                                                 (setq iswitchb-buflist (bookmark-all-names))))
                       (iswitchb-read-buffer "Jump to bookmark: "))))
  (bookmark-jump bname))
(substitute-key-definition 'bookmark-jump 'iswitchb-bookmark-jump global-map)


;;;_ + folding
(autoload 'folding-mode          "folding" "Folding mode" t)
(autoload 'turn-off-folding-mode "folding" "Folding mode" t)
(autoload 'turn-on-folding-mode  "folding" "Folding mode" t)


;;;_ + TMM
(setq tmm-completion-prompt nil)
(setq tmm-mid-prompt ": ")
(setq tmm-shortcut-style 'downcase)
(setq tmm-shortcut-words nil)



;;;_ + ibuffer
(when (require-soft 'ibuffer)
  (global-defkey "C-x C-b" 'ibuffer)
  (setq ibuffer-formats
        '((mark modified read-only " " (name 16 16) " " (mode 16 16) " "  filename)
          (mark modified read-only " " (name 16 16) " "  filename)
          (mark modified read-only " " (name 16 16) " " (size 6 -1 :right) " " (mode 16 16) "  " (process 8 -1) " " filename)))
  (setq ibuffer-elide-long-columns t)
  (setq ibuffer-never-show-regexps '("^ "))
  (setq ibuffer-maybe-show-regexps '("^\*" "\.newsrc-dribble"))
  (setq ibuffer-expert t)
  (setq-default ibuffer-default-sorting-mode 'major-mode)

  (setq ibuffer-display-summary nil)

  (setq ibuffer-saved-filter-groups
        '(("default" 
           ("Dired" (mode . dired-mode))
           ("Remote" (predicate file-remote-p (or (buffer-file-name (current-buffer))
                                                  (directory-file-name default-directory))))
           ("Shells" (predicate processp (get-buffer-process (current-buffer))))
           ("Project" (filename . "/bms08/"))
           ("Org" (or (mode . org-mode) (filename . "u:/cenis/")))
           ("Gnus" (saved . "gnus"))
           ("Help" (predicate memq major-mode ibuffer-help-buffer-modes))
           ("Volatile" (name . "^\\*")))))

  (defun ibuffer-list-shells ()
    "Show a list of buffers using `shell-mode' using `ibuffer'."
    (interactive)
    (ibuffer nil "*Ibuffer Shells*" '((mode . shell-mode)) nil t))

  (global-defkey "C-x S" 'ibuffer-list-shells)

  (setq ibuffer-show-empty-filter-groups nil)

  (defadvice ibuffer-generate-filter-groups (after reverse-ibuffer-groups () activate)
    (let ((default (assoc-string "Default" ad-return-value)))
      (setq ad-return-value (nconc (delq default ad-return-value) (list default)))))

  (add-hook 'ibuffer-mode-hook
            (lambda ()
              (ibuffer-switch-to-saved-filter-groups "default")))

  (defun ibuffer-dired-buffers ()
    "*Limit current view to Dired buffers only."
    (interactive)
    (ibuffer-filter-by-mode 'dired-mode))

  (defkey ibuffer-mode-map "/ D" 'ibuffer-dired-buffers)

  (defadvice ibuffer-confirm-operation-on (around confirm-with-y-or-n-p activate)
    "Use `y-or-n-p' instead of `yes-or-no-p' to confirm operations."
    (flet ((yes-or-no-p (prompt) (y-or-n-p prompt)))
      ad-do-it))

  (defadvice ibuffer-marked-buffer-names (after current-buffer-if-none-marked activate)
    "*Return current buffer (and mark it) if none is marked.
This way the `ibuffer-do-*' commands operate on the current buffer if
none is marked."
    (unless ad-return-value
      (let ((buffer (ibuffer-current-buffer)))
        (when buffer
          (ibuffer-mark-interactive 1 ibuffer-marked-char 0)
          (setq ad-return-value (list buffer))))))
  )

;;;_ + Dired
(setq ls-lisp-use-insert-directory-program t)
(eval-after-load "dired" '(require-soft 'init-dired))
(autoload 'dired-jump "dired"
  "Jump to Dired buffer corresponding to current buffer." t)


;;;_ + Org-mode



;;;_ + eshell
;; TODO: Make it more generic (`next-buffer-satisfying') and use "ring.el"
(defun eshell-next-buffer (arg)
"Switch to the next EShell buffer.
Start a new Eshell session if invoked with prefix argument ARG or if
no EShell session is currently active."
  (interactive "P")
  (let (eshell-buffers)
    (mapc (lambda (buffer)
            (when (with-current-buffer buffer
                    (string-match "\\`EShell\\'" mode-name))
              (add-to-list 'eshell-buffers buffer 'append)))
          (buffer-list))
    (if (or arg (not eshell-buffers))
        (eshell t)
      (switch-to-buffer (car (delete (current-buffer) eshell-buffers))))))

(add-hook 'eshell-load-hook (lambda () (require-soft 'init-eshell)))



;;;_ + Shell and Comint
(defun shell-dwim (&optional create)
  "Start or switch to an inferior shell process, in a smart way.
If a buffer with a running shell process exists, simply switch to
that buffer.
If a shell buffer exists, but the shell process is not running,
restart the shell.
If already in an active shell buffer, switch to the next one, if
any.

With prefix argument CREATE always start a new shell."
  (interactive "P")
  (let* ((next-shell-buffer
          (catch 'found
            (dolist (buffer (reverse (buffer-list)))
              (when (string-match "^\\*shell\\*" (buffer-name buffer))
                (throw 'found buffer)))))
         (buffer (if create
                     (generate-new-buffer-name "*shell*")
                   next-shell-buffer)))
    (shell buffer)))

(defun shell-hier (&optional dir)
  (interactive)
  (let* ((dir (or dir default-directory))
         (buffs (mapcar (lambda (buffer)
                          (with-current-buffer buffer
                            (and (eq major-mode 'shell-mode)
                                 (string= (expand-file-name dir) (expand-file-name default-directory))
                                 buffer)))
                        (buffer-list))))
    (setq buffs (delq nil buffs))
    (if (null buffs)
        (let ((default-directory dir))
          (shell (generate-new-buffer-name "*shell*")))
      (shell (car buffs)))))

(when (memq system-type '(ms-dos windows-nt cygwin))
  (defun shell-cmd ()
    (interactive)
    (let ((explicit-shell-file-name (or (executable-find "cmdproxy.exe")
                                        (getenv "ComSpec")
                                        (executable-find "cmd.exe")
                                        "command.com"))
          (default-process-coding-system '(dos . dos))
          (comint-process-echoes t))
      (shell "*shell: cmd*"))))

(eval-after-load "shell" '(require-soft 'init-shell))


;;;_ + view-file
(eval-after-load "view"
  '(progn
     (substitute-key-definition 'View-quit 'View-exit-no-restore view-mode-map)
     (defkey view-mode-map "e" 'View-exit-and-edit)
     (defkey view-mode-map "b" 'View-scroll-page-backward)))
(defun View-exit-no-restore ()
  "*Quit View mode, without trying to restore window or buffer to previous state."
  (interactive)
  (let ((view-return-to-alist nil))
    (view-mode-exit nil view-exit-action)))
(setq-default view-exit-action 'kill-buffer)



;;;_ + grep
(setq grep-command "grep -s -n ")

(eval-after-load "grep"
  '(add-to-list 'grep-find-ignored-directories "_darcs"))


;;;_ + calendar
(add-hook 'calendar-load-hook
          (lambda ()
            (european-calendar)
            (defun calendar-goto-iso-week (week year &optional noecho)
              "Move cursor to start of ISO WEEK in YEAR; echo ISO date unless NOECHO is t.
Interactively asks for YEAR only when called with a prefix argument."
              (interactive
               (let* ((today (calendar-current-date))
                      (year (if current-prefix-arg
                                (calendar-read
                                 "ISO calendar year (>0): "
                                 '(lambda (x) (> x 0))
                                 (int-to-string (extract-calendar-year today)))
                              (extract-calendar-year today)))
                      (no-weeks (extract-calendar-month
                                 (calendar-iso-from-absolute
                                  (1-
                                   (calendar-dayname-on-or-before
                                    1 (calendar-absolute-from-gregorian
                                       (list 1 4 (1+ year))))))))
                      (week (calendar-read
                             (format "ISO calendar week (1-%d): " no-weeks)
                             '(lambda (x) (and (> x 0) (<= x no-weeks))))))
                 (list week year)))
              (calendar-goto-date (calendar-gregorian-from-absolute
                                   (calendar-absolute-from-iso
                                    (list week calendar-week-start-day year))))
              (or noecho (calendar-print-iso-date)))
            (defkey calendar-mode-map "g w" 'calendar-goto-iso-week)
            (setq calendar-week-start-day 1)))

(add-hook 'calendar-today-visible-hook 'calendar-mark-today)

;; display the ISO week numbers (from the help of `calendar-intermonth-text')
(setq calendar-intermonth-text
      '(propertize
        (format "%2d"
                (car
                 (calendar-iso-from-absolute
                  (calendar-absolute-from-gregorian (list month day year)))))
        'font-lock-face 'font-lock-function-name-face))

;; German settings and holidays

(setq calendar-time-display-form
      '(24-hours ":" minutes (and time-zone (concat " (" time-zone ")"))))

(setq calendar-day-name-array
      ["Sonntag" "Montag" "Dienstag" "Mittwoch" "Donnerstag" "Freitag" "Samstag"])
(setq calendar-month-name-array
      ["Januar" "Februar" "März" "April" "Mai" "Juni"
       "Juli" "August" "September" "Oktober" "November" "Dezember"])
(setq solar-n-hemi-seasons
      '("Frühlingsanfang" "Sommeranfang" "Herbstanfang" "Winteranfang"))

(setq general-holidays
      '((holiday-fixed 1 1 "Neujahr")
        (holiday-fixed 5 1 "1. Mai")
        (holiday-fixed 10 3 "Tag der Deutschen Einheit")))

(setq christian-holidays
      '((holiday-float 12 0 -4 "1. Advent" 24)
        (holiday-float 12 0 -3 "2. Advent" 24)
        (holiday-float 12 0 -2 "3. Advent" 24)
        (holiday-float 12 0 -1 "4. Advent" 24)
        (holiday-fixed 12 25 "1. Weihnachtstag")
        (holiday-fixed 12 26 "2. Weihnachtstag")
        (holiday-fixed 1 6 "Heilige Drei Könige")
        ;; Date of Easter calculation taken from holidays.el.
        (let* ((century (1+ (/ displayed-year 100)))
               (shifted-epact (% (+ 14 (* 11 (% displayed-year 19))
                                    (- (/ (* 3 century) 4))
                                    (/ (+ 5 (* 8 century)) 25)
                                    (* 30 century))
                                 30))
               (adjusted-epact (if (or (= shifted-epact 0)
                                       (and (= shifted-epact 1)
                                            (< 10 (% displayed-year 19))))
                                   (1+ shifted-epact)
                                 shifted-epact))
               (paschal-moon (- (calendar-absolute-from-gregorian
                                 (list 4 19 displayed-year))
                                adjusted-epact))
               (easter (calendar-dayname-on-or-before 0 (+ paschal-moon 7))))
          (filter-visible-calendar-holidays
           (mapcar
            (lambda (l)
              (list (calendar-gregorian-from-absolute (+ easter (car l)))
                    (nth 1 l)))
            '(
              ;;(-48 "Rosenmontag")
              ( -2 "Karfreitag")
              (  0 "Ostersonntag")
              ( +1 "Ostermontag")
              (+39 "Christi Himmelfahrt")
              (+49 "Pfingstsonntag")
              (+50 "Pfingstmontag")
              (+60 "Fronleichnam")))))
        (holiday-fixed 8 15 "Mariae Himmelfahrt")
        (holiday-fixed 11 1 "Allerheiligen")
        ;;(holiday-float 11 3 1 "Buss- und Bettag" 16)
        (holiday-float 11 0 1 "Totensonntag" 20)))

(setq calendar-holidays
      (append general-holidays local-holidays other-holidays
              christian-holidays solar-holidays))


;;;_ + Occur
(defun my-occur-mode-hook ()
  (defkey occur-mode-map "n" 'occur-next)
  (defkey occur-mode-map "<down>" 'occur-next)
  (defkey occur-mode-map "p" 'occur-prev)
  (defkey occur-mode-map "<up>" 'occur-prev))
(add-hook 'occur-mode-hook 'my-occur-mode-hook)

(defun occur-shrink-window ()
  "*Shrink the \"*Occur*\" window as much as possible to display its contents."
  (let ((win (get-buffer-window "*Occur*")))
    (when (windowp win)
      (shrink-window-if-larger-than-buffer win))))
(add-hook 'occur-hook 'occur-shrink-window)



;;;_ + Diff/Ediff

(setq diff-switches "--unified")

(setq ediff-keep-variants nil)

(add-hook 'ediff-load-hook
          (lambda ()
            (setq ediff-custom-diff-options "--unified")
            ;; (setq ediff-diff-options (concat ediff-diff-options " --minimal --ignore-all-space"))
            (mapc (lambda (face)
                    (set-face-foreground face "black")
                    (set-face-background face "sky blue"))
                  (list ediff-current-diff-face-A
                        ediff-current-diff-face-B))

            (set-face-foreground ediff-fine-diff-face-A "firebrick")
            (set-face-background ediff-fine-diff-face-A "pale green")
            (set-face-foreground ediff-fine-diff-face-B "dark orchid")
            (set-face-background ediff-fine-diff-face-B "yellow")

            (setq ediff-window-setup-function 'ediff-setup-windows-plain)

            (add-hook 'ediff-keymap-setup-hook
                      (lambda ()
                        (defkey ediff-mode-map "q" 'ediff-quit-no-questions)))
            
            (add-hook 'ediff-before-setup-hook
                      (lambda ()
                        (setq ediff-saved-window-configuration (current-window-configuration))))

            (let ((restore-window-configuration
                   (lambda ()
                     (set-window-configuration ediff-saved-window-configuration))))
              (add-hook 'ediff-quit-hook restore-window-configuration 'append)
              (add-hook 'ediff-suspend-hook restore-window-configuration 'append))

            (setq ediff-split-window-function (lambda (&optional arg)
                                                (if (> (frame-width) 150)
                                                    (split-window-horizontally arg)
                                                  (split-window-vertically arg))))

            (setq-default ediff-forward-word-function 'forward-char)

            (defadvice ediff-windows-wordwise (before invert-prefix-arg activate)
              "Invert the sense of the prefix argument, when run interactively."
              (when (interactive-p)
                (ad-set-arg 0 (not (ad-get-arg 0)))))))

(defun ediff-quit-no-questions (reverse-default-keep-variants)
  "Quit ediff without prompting."
  (interactive "P")
  (ediff-really-quit reverse-default-keep-variants))

(defun vc-ediff ()
  "*Compare revisions of the visited file using Ediff."
  (interactive)
  (require 'ediff)
  (ediff-load-version-control)
  (ediff-vc-internal "" "" nil))

(global-defkey "C-x v =" 'vc-ediff)

;;; Adapted from Dave Love's "fx-misc.el", http://www.loveshack.ukfsn.org/emacs
(defun ediff-diff-buffer-with-saved ()
  "*Run Ediff between the (modified) current buffer and the buffer's file.

A new buffer is created containing the disc file's contents and
`ediff-buffers' is run to compare that with the current buffer."
  (interactive)
  (unless (buffer-modified-p)
    (error "Buffer isn't modified"))
  (let ((current (buffer-name))
        (file (or (buffer-file-name)
                  (error "Current buffer isn't visiting a file")))
        (mode major-mode))
    (with-current-buffer (get-buffer-create (format "*%s-on-disc*" current))
      (buffer-disable-undo)
      (erase-buffer)
      (insert-file-contents file)
      (set-buffer-modified-p nil)
      (funcall mode)

      (ediff-buffers (buffer-name) current))))


;;;_ + Printing
(when (require-soft 'printing)
  (pr-update-menus t))

(defun set-default-printer (printer)
  "*Change the default printer."
  (interactive (list (read-from-minibuffer "Printer: " printer-name)))
  (setq printer-name printer)
  (setq ps-printer-name printer-name))


;; PS printing
(setq ps-paper-type 'a4)
(setq ps-print-header t)
(setq ps-print-header-frame t)
(setq ps-print-color-p nil)

;; (setq ps-font-family 'Times)
;; (setq ps-font-size '(8.5 . 11))

(setq ps-font-family 'Courier)
(setq ps-font-size   '(7 . 8.5))


(setq ps-right-header
      (list "/pagenumberstring load"
            'ps-time-stamp-yyyy-mm-dd 'ps-time-stamp-hh:mm:ss))

(defun ps-time-stamp-yyyy-mm-dd ()
  "*Return the date as, for example, \"2003-02-18\"."
  (format-time-string "%Y-%m-%d"))

;; One page per sheet
(setq ps-landscape-mode nil)
(setq ps-number-of-columns 1)

;; Two pages per sheet
;; (setq ps-landscape-mode t)
;; (setq ps-number-of-columns 2)

(defun ps-print-buffer-no-header ()
  (interactive)
  (let ((ps-print-header nil)
        (ps-print-header-frame nil))
    (funcall (if window-system 'ps-print-buffer-with-faces 'ps-print-buffer))))

(defun ps-print-buffer-maybe-with-faces-landscape ()
  (interactive)
  (let ((ps-landscape-mode nil)
        (ps-number-of-columns 1))
    (funcall (if window-system 'ps-print-buffer-with-faces 'ps-print-buffer))))

(defun ps-print-buffer-maybe-with-faces-n-up (&optional n)
  (interactive)
  (let ((ps-landscape-mode t)
        (ps-number-of-columns (or n 2)))
    (funcall (if window-system 'ps-print-buffer-with-faces 'ps-print-buffer))))

(global-defkey "C-c p" (make-sparse-keymap))

(global-defkey "C-c p p" (if window-system 'ps-print-buffer-with-faces 'ps-print-buffer))

(global-defkey "C-c p s" (if window-system 'ps-spool-buffer-with-faces 'ps-spool-buffer))

(global-defkey "C-c p b" (if window-system 'ps-print-buffer-with-faces 'ps-print-buffer))
(global-defkey "C-c p B" (if window-system 'ps-spool-buffer-with-faces 'ps-spool-buffer))
(global-defkey "C-c p r" (if window-system 'ps-print-region-with-faces 'ps-print-region))
(global-defkey "C-c p R" (if window-system 'ps-spool-region-with-faces 'ps-spool-region))

(global-defkey "C-c p l" 'ps-print-buffer-maybe-with-faces-landscape)
(global-defkey "C-c p n" 'ps-print-buffer-maybe-with-faces-n-up)

(global-defkey "C-c p S" 'set-default-printer)


;;;_ + Calc
(setq calc-full-mode t)
(setq calc-display-trail nil)



;;;_ + Man
(eval-after-load "man"
  '(progn
     (setq Man-notify-method 'friendly)
     (defkey Man-mode-map "q" 'Man-kill)))



;;;_ + Woman
(setq woman-use-own-frame nil)



;;;_ + Browse URL
(setq browse-url-new-window-flag nil)
(setq browse-url-mozilla-new-window-is-tab t)


;;;_ + W3
(when (or (require-soft 'w3-auto)
          (require-soft 'url))
  (cond
   (at-bmw
    (setq url-proxy-services '(("http" . "proxy.muc:8080")
                               ("ftp" .  "proxy.muc:8080"))))))



;;;_ + Custom
(setq custom-file (locate-user-emacs-file "custom.el" ".custom"))
(when (file-readable-p custom-file)
  (load-file custom-file))



;;;_ + isearch
(setq isearch-allow-scroll t)

(defun isearch-recenter ()
  (interactive)
  (recenter-top-bottom)
  (isearch-update))
(defkey isearch-mode-map "C-l" 'isearch-recenter)

(defun isearch-yank-sexp ()
  "*Pull next expression from buffer into search string."
  (interactive)
  (isearch-yank-internal (lambda () (forward-sexp 1) (point))))
(defkey isearch-mode-map "C-v" 'isearch-yank-sexp)

(defun isearch-yank-symbol ()
  "*Put symbol at current point into search string."
  (interactive)
  (let ((sym (symbol-at-point)))
    (if sym
        (progn
          (setq isearch-regexp t
                isearch-string (concat "\\_<" (regexp-quote (symbol-name sym)) "\\_>")
                isearch-message (mapconcat 'isearch-text-char-description isearch-string "")
                isearch-yank-flag t))
      (ding)))
  (isearch-search-and-update))
(defkey isearch-mode-map "C-y" 'isearch-yank-symbol)

;; Alex Schroeder [http://www.emacswiki.org/cgi-bin/wiki/OccurBuffer]
(defun isearch-occur ()
  "*Invoke `occur' from within isearch."
  (interactive)
  (let ((case-fold-search isearch-case-fold-search))
    (occur (if isearch-regexp isearch-string (regexp-quote isearch-string)))))

(defkey isearch-mode-map "<mouse-2>" 'isearch-yank-kill)
(defkey isearch-mode-map "<down-mouse-2>" nil)
(defkey isearch-mode-map "C-c" 'isearch-toggle-case-fold)
(defkey isearch-mode-map "C-t" 'isearch-toggle-regexp)
(defkey isearch-mode-map "C-o" 'isearch-occur)
(defkey isearch-mode-map "M-k" 'isearch-yank-line)
(defkey isearch-mode-map "C-h" 'isearch-mode-help)

;; Juri Linkov [http://www.jurta.org/emacs/dotemacs.el]
(defun isearch-beginning-of-buffer ()
  "Move isearch point to the beginning of the buffer."
  (interactive)
  (goto-char (point-min))
  (isearch-repeat-forward))

(defun isearch-end-of-buffer ()
  "Move isearch point to the end of the buffer."
  (interactive)
  (goto-char (point-max))
  (isearch-repeat-backward))

(defkey isearch-mode-map "M-<" 'isearch-beginning-of-buffer)
(defkey isearch-mode-map "M->" 'isearch-end-of-buffer)


;;;_* Misc

(defadvice describe-function (after where-is activate)
  "Call `\\[where-is] FUNCTION' iff it's interactive."
  (let ((func (ad-get-arg 0)))
    (when (commandp func)
      (where-is func))))

(defun unfill-paragraph ()
  (interactive "*")
  (let ((fill-column (point-max)))
    (fill-paragraph nil)))

;; see http://angg.twu.net/eev-article.html
(defun ee (s e)
  "Save the region in a temporary script"
  (interactive "r")
  (write-region s e "~/.ee.sh"))


(mapc-pair (lambda (x y)
             (when (fboundp x)
               (funcall x y)))
           '((menu-bar-mode . -1)
             (tool-bar-mode . -1)
             (scroll-bar-mode . -1)
             (transient-mark-mode . -1)
             (blink-cursor-mode . -1)
             (show-paren-mode . +1)
             (line-number-mode . +1)
             (column-number-mode . -1)
             (savehist-mode . +1)))

(global-defkey "<down-mouse-3>" 'mouse-major-mode-menu)

;;(x11-maximize-frame-vertically)
(when (and running-nt (eq window-system 'w32))
  (add-hook 'window-setup-hook 'w32-maximize-frame 'append))

;;; Misc history
;; Add *all* visited files to `file-name-history', no matter if they
;; are visited through Dired or gnuclient or whatever.
(defun add-filename-to-history ()
  "*Add or move the visited file to the beginning of `file-name-history'."
  (let ((filename buffer-file-name))
    (when filename
      (setq file-name-history (cons filename (delete filename file-name-history)))))
  nil)
(add-hook 'find-file-hook 'add-filename-to-history)

;;  show paren
(setq show-paren-mode-hook nil)
(add-hook 'show-paren-mode-hook 
          (lambda ()
            (set-face-foreground 'show-paren-match-face "orange")
            (set-face-background 'show-paren-match-face "moccasin")))

;;;_* Local Configuration
(when at-bmw
  (defun bmw-jump-to-exchange-dir (&optional arg)
    "*Visit (using Dired) the exchange directory, creating it if necessary."
    (interactive "P")
    (let ((exchange "//easerv.muc/Organisation/EA-41/Austausch/ecl")
          (find-file-existing-other-name t))
      (when arg (setq exchange (file-name-directory (directory-file-name exchange))))
      (unless (file-accessible-directory-p exchange)
        (make-directory exchange t))
      (dired exchange)))
  (global-defkey "C-c j A" 'bmw-jump-to-exchange-dir)
  (global-defkey "C-c j u" (lambda () (interactive) (dired "u:/")))
  (set-register ?P '(file . "//smuc1830/Projekt/DDE/")))

;; Fix the system PATH at BMW
(when at-bmw
  (setq exec-path
        (let (path)
          (mapc (lambda (dir)
                  (let ((case-fold-search t))
                    (cond
                     ((string-match "[\\/]winnt" dir)
                      (add-to-list 'path dir 'append)) ; append
                     ((string-match "[\\/]\\(orant\\|oracle\\|dds\\)" dir)
                      nil)              ; do nothing i.e. remove
                     (t
                      (add-to-list 'path dir)))))
                (reverse exec-path))
          path))
  (setq sql-oracle-program "c:/Oracle/Client/bin/sqlplus.exe")
  (setq ispell-program-name "f:/Apps/AspellPortable/bin/aspell.exe")
  (require-soft 'cygpath)
  (let ((cygwin-prefix "e:/tools/gnu"))
    (add-to-path 'exec-path (concat cygwin-prefix "/bin") 'append)
    (add-to-path 'exec-path (concat cygwin-prefix "/usr/local/bin") 'append)
    (add-to-path 'Info-default-directory-list (concat cygwin-prefix "/usr/info") 'append)
    (setenv "MAGIC" (cygpath-windows2unix (concat cygwin-prefix "/usr/share/magic")))
    (setq woman-manpath
          (mapcar (lambda (dir) (concat cygwin-prefix dir)) '("/usr/local/man" "/usr/man"))))
  (setenv "PATH" (mapconcat (if running-nt
                                (lambda (dir)
                                  (subst-char-in-string ?/ ?\\ dir))
                              'identity) exec-path path-separator)))


;;; periodically kill old buffers
(require 'midnight)



(when at-bmw
  (setq bmw-suppress-local-keybindings t)
  (setq bmw-suppress-local-look-and-feel t))
;;; EOF
