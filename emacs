;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;; install addons ;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(require 'package)
(package-initialize)
(add-to-list 'package-archives '("melpa" . "https://melpa.org/packages/") t)
(require 'cl-lib)
(setq package-selected-packages '(
	doom-modeline
	neotree
	dumb-jump
	company
	company-shell
	company-plsense
	flycheck
	ess
	poly-R
	markdown-mode
	git-commit
	magit
	poetry
	multiple-cursors
))
(unless (cl-every 'package-installed-p package-selected-packages)
	(let
		()
		(package-refresh-contents)
		(package-install-selected-packages)
	)
)


;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;; general config ;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(setq-default delete-selection-mode nil)

;; turn off welcome screen
(setq-default inhibit-startup-screen t)

;; turn of bell
(setq-default ring-bell-function 'ignore)

;; use y/n instead of yes/no
(fset 'yes-or-no-p 'y-or-n-p)

;; highlight parentheses
(show-paren-mode 1)
(setq-default show-paren-delay 0)

;; show line and column number
(setq-default column-number-mode t)
(setq-default line-number-mode t)
(setq-default display-line-numbers-type t)

;; show parenthesis pairs
(setq-default show-paren-mode t)

;; end a file with a newline
(setq-default require-final-newline t)

;; define tab-width
(setq-default tab-width 4)

;; remove tabs instead of spaces
(setq-default backward-delete-char-untabify-method 'hungry)

;; remove trailing whitespace
(add-hook 'before-save-hook 'delete-trailing-whitespace)

;; auto close paranthesis
(add-hook 'prog-mode-hook 'electric-pair-mode)


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;; custom key actions ;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; rectangle selection and replace: c-return to start, m-f fill with char
(cua-selection-mode 1)
(define-key global-map (kbd "<S-down-mouse-1>") 'ignore)
(define-key global-map (kbd "<S-mouse-1>") 'mouse-set-point)
(put 'mouse-set-point 'CUA 'move)

;; use 'C-x h b' or '<F1> b' to list all bindings
;; nice defaults
;; C-x 0           delete-window
;; M-\             delete-horizontal-space
;; C-t             transpose-chars
;; C-x r o         open-rectangle
;; C-x r M-w       copy-rectangle-as-kill
;; C-x r k         kill-rectangle
;; C-x r y         yank-rectangle
;; M-!             shell-command
(global-set-key (kbd "<home>") 'move-beginning-of-line)
(global-set-key (kbd "<end>") 'move-end-of-line)
(global-set-key (kbd "C-x h") 'help-command) ;; mark-whole-buffer
(global-set-key (kbd "C-s") 'isearch-forward-regexp) ;; isearch-forward
(global-set-key (kbd "C-h") 'query-replace-regexp) ;; help-command
(global-set-key (kbd "C-x o") 'other-window) ;; other-window or find-file
(global-set-key (kbd "C-x f") 'find-file) ;; set-fill-column
(global-set-key (kbd "C-x <right>") 'my-split-window-horizontally) ;; next-buffer
(global-set-key (kbd "C-x <down>") 'my-split-window-vertically) ;; undefined
(global-set-key (kbd "C-x <up>") 'ibuffer) ;; undefined
(global-set-key (kbd "C-x <C-left>") 'windmove-left)
(global-set-key (kbd "C-x <C-right>") 'windmove-right)
(global-set-key (kbd "C-x <C-up>") 'windmove-up)
(global-set-key (kbd "C-x <C-down>") 'windmove-down)
(global-set-key (kbd "C-x q") 'kill-buffer-and-window) ;; delete-window kill-buffer-and-window kbd-macro-query
(global-set-key (kbd "C-x /") 'comment-or-uncomment-region)
(global-set-key (kbd "C-<right>") 'forward-word)
(global-set-key (kbd "C-<left>") 'backward-word)

;; some modes override global key bindings, hence this function can be used in mode hooks below
(defun set-custom-keys ()
	(local-set-key (kbd "<home>") 'move-beginning-of-line)
	(local-set-key (kbd "<end>") 'move-end-of-line)
	(local-set-key (kbd "C-x h") 'help-command) ;; mark-whole-buffer
	(local-set-key (kbd "C-s") 'isearch-forward-regexp) ;; isearch-forward
	(local-set-key (kbd "C-h") 'query-replace-regexp) ;; help-command
	(local-set-key (kbd "C-x o") 'other-window) ;; other-window or find-file
	(local-set-key (kbd "C-x f") 'find-file) ;; set-fill-column
	(local-set-key (kbd "C-x <right>") 'my-split-window-horizontally) ;; next-buffer
	(local-set-key (kbd "C-x <down>") 'my-split-window-vertically) ;; undefined
	(local-set-key (kbd "C-x <up>") 'buffer-menu) ;; undefined undefined
	(local-set-key (kbd "C-x <C-left>") 'windmove-left)
	(local-set-key (kbd "C-x <C-right>") 'windmove-right)
	(local-set-key (kbd "C-x <C-up>") 'windmove-up)
	(local-set-key (kbd "C-x <C-down>") 'windmove-down)
	(local-set-key (kbd "C-x q") 'kill-buffer-and-window) ;; delete-window kill-buffer-and-window kbd-macro-query
	(local-set-key (kbd "C-x /") 'comment-or-uncomment-region)
	(local-set-key (kbd "C-<right>") 'forward-word)
	(local-set-key (kbd "C-<left>") 'backward-word)
)

;; split window and toggle
(defun my-split-window-horizontally ()
	(interactive)
	(split-window-horizontally)
	(other-window 1)
)
(defun my-split-window-vertically ()
	(interactive)
	(split-window-vertically)
	(other-window 1)
)


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;; my indent minor modes ;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(define-minor-mode space-mode
	"toggle space mode."
	:init-value nil
	:lighter " SPACE"
	(if (and (bound-and-true-p space-mode) (bound-and-true-p tab-mode) )
		(let
			()
			(tab-mode -1)
			(message "tab-mode disabled")
		)
	)
)

(define-minor-mode tab-mode
	"toggle tab mode."
	:init-value 1
	:lighter " TAB"
	(if (and (bound-and-true-p tab-mode) (bound-and-true-p space-mode) )
		(let
			()
			(space-mode -1)
			(message "space-mode disabled")
		)
	)
)

;;;;;; customize tab-mode ;;;;;;
(defun tab-mode-setup ()
	(defun unshift-text (distance)
		(if (use-region-p)
			;; then command or 'let'-block
			(let
				;; definition of vars
				(	(mark (mark))
					(beg (save-excursion (goto-char (region-beginning)) (line-beginning-position)))
					(end (region-end))
				)
				;; statements
				(indent-rigidly beg end distance)
				(push-mark mark t t)
				(setq deactivate-mark nil)
			)
			;; else command or 'let'-block
			(let
				()
				(indent-rigidly (line-beginning-position) (line-end-position) distance)
			)
		)
	)

	(defun shift-text (distance)
		(if (use-region-p)
			(let(	(mark  (mark))
					(beg (save-excursion (goto-char (region-beginning)) (line-beginning-position)))
					(end (region-end))
				)
				(indent-rigidly beg end distance)
				(push-mark mark t t)
				(setq deactivate-mark nil)
			)
			(let
				()
				(self-insert-command 1)
				;; (insert "\t")
			)
		)
	)

	(defun shift-right ()
		(interactive)
		(shift-text tab-width)
	)

	(defun shift-left ()
		(interactive)
		(unshift-text (- tab-width))
	)

	;; disable indent character detection
	(setq dtrt-indent-hook-mapping-list nil)
	;; indent by tabs
	(setq-default indent-line-function 'insert-tab)
	(setq-default indent-tabs-mode t)
	(global-set-key (kbd "TAB") 'shift-right)
	(global-set-key (kbd "<backtab>") 'shift-left)
)
(add-hook 'tab-mode-hook 'tab-mode-setup)


;;;;;; customize space-mode ;;;;;;
(defun space-mode-setup ()
	(defun unshift-text (distance)
		(if (use-region-p)
			;; then command or 'let'-block
			(let
				;; definition of vars
				(	(mark (mark))
					(beg (save-excursion (goto-char (region-beginning)) (line-beginning-position)))
					(end (region-end))
				)
				;; statements
				(indent-rigidly beg end distance)
				(push-mark mark t t)
				(setq deactivate-mark nil)
			)
			;; else command or 'let'-block
			(let
				()
				(indent-rigidly (line-beginning-position) (line-end-position) distance)
			)
		)
	)
	(defun shift-text (distance)
		(if (use-region-p)
			(let(	(mark  (mark))
					(beg (save-excursion (goto-char (region-beginning)) (line-beginning-position)))
					(end (region-end))
				)
				(indent-rigidly beg end distance)
				(push-mark mark t t)
				(setq deactivate-mark nil)
			)
			(let()
				(insert (make-string distance ? ))
			)
		)
	)
	(defun shift-right ()
		(interactive)
		(shift-text tab-width)
	)
	(defun shift-left ()
		(interactive)
		(unshift-text (- tab-width))
	)

	;; disable indent character detection
	(setq dtrt-indent-hook-mapping-list nil)
	;; indent by space
	(setq-default indent-tabs-mode nil)
	(global-set-key (kbd "TAB") 'shift-right)
	(global-set-key (kbd "<backtab>") 'shift-left)
)
(add-hook 'space-mode-hook 'space-mode-setup)

;; actually minor modes are activated upon calling M-x <mode> and disabled upon calling M-x <mode> again
;; thus, enabling it in an anonymous lambda function via (tab-mode 1) is equivalent to simply (tab-mode)
;; and thus an even more simplistically synopsis (see addon based modes) would be (add-hook 'after-init-hook 'tab-mode)

(add-hook 'after-init-hook '(lambda ()
	(tab-mode 1)
))

;; untabify upon save when in space-mode - customize via anonymous lambda function
(add-hook 'before-save-hook '(lambda ()
	(if (bound-and-true-p space-mode)
		(untabify (point-min) (point-max))
	)
))


;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;; addon modes ;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;; modeline ;;;;;;
(require 'doom-modeline)
(setq doom-modeline-minor-modes t)
(doom-modeline-mode 1)
(setq doom-modeline-checker-simple-format nil)
(defun modline-hide-modes ()
	(mapcar
		(lambda (mode) (
			condition-case nil
				(unless (or (string= mode "tab-mode") (string= mode "space-mode"))
					(setcar (alist-get mode minor-mode-alist) "")
				)
			(error nil)
		))
		minor-mode-list
	)
)
(add-hook 'after-change-major-mode-hook 'modline-hide-modes)
(add-hook 'find-file-hook 'modline-hide-modes)
(add-hook 'first-change-hook 'modline-hide-modes)


;;;;;; RNA alignment editing ;;;;;;
;; http://sgjlab.org/wp-content/uploads/2014/11/ralee-mode-0.8.tar.gz
(add-to-list 'load-path "/misc/paras/data/programs/ralee-mode/latest/elisp")
(add-to-list 'exec-path "/misc/paras/data/programs/ralee-mode/latest/elisp")
(require 'ralee-mode)
(add-to-list 'auto-mode-alist '("\\.stk$" . ralee-mode))


;;;;;; project tree browser ;;;;;;
(require 'neotree)
(defun neotree-mode-setup ()
	(setq neo-smart-open t)
	(setq neo-theme 'nerd)
	(global-set-key [f8] 'neotree-toggle)
	(neotree-toggle)
	(other-window 1)
)
;; addon is somehow enabled by default, thus do not use (add-hook 'neotree-mode-hook 'neotree-mode-setup)
(add-hook 'after-init-hook 'neotree-mode-setup)


;;;;;; emacs statistics r mode ;;;;;;
(require 'ess-r-mode)
(add-to-list 'auto-mode-alist '("\\.([rR]|[rR]md)$" . ess-r-mode))
;; customize ess-r-mode
(defun ess-r-mode-setup ()
	;; enable indentation
	(electric-indent-mode 1)
	;; disable indentation of previous line
	;; (setq electric-indent-inhibit t)
)
(add-hook 'ess-r-mode-hook 'ess-r-mode)


;;;;;; jump to definition package ;;;;;;
(require 'dumb-jump)
;; customize dump-jump-mode
;;(defun dumb-jump-mode-setup ()
	(setq dumb-jump-selector 'ivy)
	(setq dumb-jump-default-project "./")
	(global-set-key (kbd "M-/") 'xref-find-apropos)
;;)
;; deprecated: (add-hook 'dumb-jump-mode-hook 'dumb-jump-mode-setup)
;; (add-hook 'xref-backend-functions 'dumb-jump-xref-activate)


;;;;;; popup word completion ;;;;;;
(require 'company)
;; customize company-mode
(defun global-company-mode-setup ()
	;; disble completion by return
	(define-key company-active-map (kbd "RET") nil)
	(setq company-idle-delay 0)
	(setq company-minimum-prefix-length 2)
	;;(setq company-show-numbers t)
	;; use dabbrev (plain text) as default
	(setq company-backends '(company-dabbrev))
	(add-to-list 'company-backends '(company-files))
)
(add-hook 'global-company-mode-hook 'global-company-mode-setup)
(add-hook 'after-init-hook 'global-company-mode)


;;;;;; syntax checker ;;;;;;
(require 'flycheck)
;; customize flycheck-mode
(defun global-flycheck-mode-setup ()
	(setq flycheck-check-syntax-automatically '(mode-enabled new-line idle-change save))
	(setq flycheck-idle-change-delay 0)
	(setq flycheck-highlighting-mode 'lines)
	;; change colors, but line always defaults to foreground and forground might be overriden by emacs theme
	;; (set-face-attribute 'flycheck-error nil :foreground nil :background "color-88" :underline '(:color "color-88" :style wave))
	(set-face-attribute 'flycheck-error nil :foreground nil :background "color-88" :underline nil)
	(set-face-attribute 'flycheck-warning nil :foreground nil :background "yellow" :underline nil)
	(set-face-attribute 'flycheck-info nil :foreground nil :background "color-22" :underline nil)
)
(add-hook 'global-flycheck-mode-hook 'global-flycheck-mode-setup)
(add-hook 'after-init-hook 'global-flycheck-mode)


;;;;; multiple cursor
(require 'multiple-cursors)
;;(defun multiple-cursors-mode-setup ()
	(global-set-key (kbd "C-l") 'mc/edit-lines)
	(global-set-key (kbd "C-p") 'mc/mark-pop)
;;)
;;(add-hook 'multiple-cursors-mode-hook 'multiple-cursors-mode-setup)
;;(add-hook 'after-init-hook 'multiple-cursors-mode)


;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;; builtin modes ;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;; customize text-mode ;;;;;;
;; make text mode the global default
(setq-default major-mode 'text-mode)
(add-to-list 'auto-mode-alist '("\\.[tT][xX][tT]$" . text-mode))
(defun text-mode-setup ()
	;; disable indentation
	(electric-indent-mode 0)
	(paragraph-indent-minor-mode 1)
)
(add-hook 'text-mode-hook 'text-mode-setup)


;;;;;; customize sh-mode ;;;;;;
(add-to-list 'auto-mode-alist '("\\.sh$" . sh-mode))
(defun sh-mode-setup ()
	;; enable indentation
	(electric-indent-mode 1)
	;; disable indentation of previous line
	;; (setq electric-indent-inhibit t)
	;; define backend lookup priority for code completion
	(setq company-backends '(company-dabbrev))
	(add-to-list 'company-backends '(company-dabbrev-code company-files))
)
(add-hook 'sh-mode-hook 'sh-mode-setup)


;;;;;; customize cperl-mode ;;;;;;
(add-to-list 'auto-mode-alist '("\\.[pP][mMlL]$" . cperl-mode))
;; use instead of perl-mode
(setq interpreter-mode-alist (rassq-delete-all 'perl-mode interpreter-mode-alist))
;; (add-to-list 'interpreter-mode-alist '("perl" . cperl-mode))
;; (add-to-list 'interpreter-mode-alist '("perl5" . cperl-mode))
;; (add-to-list 'interpreter-mode-alist '("miniperl" . cperl-mode))
(defun cperl-mode-setup ()
	;; enable indentation
	(electric-indent-mode 1)
	;; disable indentation of previous line
	;; (setq electric-indent-inhibit t)
	;; setup indent
	(setq cperl-indent-level tab-width)
	(setq cperl-continued-statement-offset tab-width)
)
(add-hook 'cperl-mode-hook 'cperl-mode-setup)


;;;;;; customize python-mode ;;;;;;
(add-to-list 'auto-mode-alist '("\\.[pP][yY]$" . python-mode))
(defun python-mode-setup ()
	;; enable indentation
	(electric-indent-mode 1)
	;; disable indentation of previous line
	;; (setq electric-indent-inhibit t)
	;; setup indentation - needs local tab-width
	(setq tab-width 4)
	(setq python-indent-offset tab-width)
	;; enable custom tab indent mode
	(space-mode 1)
)
(add-hook 'python-mode-hook 'python-mode-setup)


;;;;;;;;;;;;;;;;;;;;;;;:;;;;;
;;;;;; custom settings ;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; to change e.g. colors, do "C-u C-x =" and navigate to face, then customize_this_face
(custom-set-variables
 ;; custom-set-variables was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 '(delete-selection-mode nil))
(custom-set-faces
 ;; custom-set-faces was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 '(font-lock-function-name-face ((t (:foreground "color-27"))))
 '(font-lock-string-face ((t (:foreground "color-70"))))
 '(minibuffer-prompt ((t (:foreground "color-27"))))
 '(neo-dir-link-face ((t (:foreground "magenta"))))
 '(neo-file-link-face ((t (:foreground "color-253"))))
 '(neo-root-dir-face ((t (:foreground "red")))))
