;;; ospl-mode.el --- Format Markdown with one sentence per line
;;
;; Copyright (C) 2018 Reid 'arrdem' McKenzie.
;;
;; Author: Reid 'arrdem' McKenzie <me@arrdem.com>
;; Version: 0.1
;; Package-Requires: ((markdown-mode))
;; Keywords: markdown
;; URL: http://github.com/arrdem/ospl-mode

;;; Commentary:
;;
;; Cobbled together from https://emacs.stackexchange.com/a/473
;;  © https://stackexchange.com/users/1268889/francesco
;;  license unknown
;;
;; I've significantly reworked the original minor mode, mixing in
;; facilities for parsing Markdown using the patterns exposed by
;; `markdown-mode' to try and add support for code blocks, links and
;; other places where it may be inconvenient to insert line breaks.
;;
;; This mode attempts to integrate with
;; `aggressive-fill-paragraph-mode' and other tools based on `fill.el'
;; by buffer-locally binding `fill-paragraph-function' so that other
;; tools which attempt to format text will do the "right thing" in
;; OSPL buffers.

;;; License:
;;
;; This program is free software; you can redistribute it and/or
;; modify it under the terms of the GNU General Public License
;; as published by the Free Software Foundation; either version 3
;; of the License, or (at your option) any later version.
;;
;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs; see the file COPYING.  If not, write to the
;; Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
;; Boston, MA 02110-1301, USA.

;;; Code:

(require 'markdown-mode) ;; We use regexes from md's guts, so we need it.

(defun ospl/markdown-nobreak-p ()
  "Return nil if it is acceptable to break the current line at the point.
  Supports Markdown links, liquid tags."
  ;; inside in square brackets (e.g., link anchor text)
  (or (looking-back "^[\s]*[0-9]+\..*")
      (looking-back "\\[[^]]*")
      (looking-back "^[\s]*[-*]+.*")
      (looking-back "{%[^%]*")
      (looking-back "\.{2,}")))

(defun ospl/token-inbetween (start close)
  "Scans forwards from the start of the buffer, returning 't if
  the mark is in-between the start and end pattern, or the point
  is on either the open or the close pattern.

  Ex. is the point in a Markdown code block."
  (or (looking-at start)
      (looking-back close)
      (let ((m    (point))
            (flag  nil)
            (break nil))
        ;; Jump back to the start of the buffer
        (save-mark-and-excursion
          (goto-char (point-min))
          (while (not break)
            (if (and
                 ;; If there is a ``` open or close ahead of the point (and move there)
                 (re-search-forward
                  (if flag
                      close
                    start)
                  nil t)
                 ;; We have not scanned forwards past the point in question
                 (<= (point) m))
                ;; Flip the flag (initially nil, t after an open, nil after matching close etc.)
                (setq flag (not flag))
              ;; We've scanned far enough, break
              (setq break t))))
        ;; Yield the flag
        flag)))

(defun ospl/markdown-in-code-block-p ()
  "Returns 't if the point is in a code block"
  (ospl/token-inbetween
   markdown-regex-gfm-code-block-open
   markdown-regex-gfm-code-block-close))

(defun ospl/markdown-in-yaml-header-p ()
  "Returns 't if the point is in a Jekyll YAML header"
  (ospl/token-inbetween
   "---"
   "---"))

(defun ospl/markdown-in-quotation-p ()
  (save-mark-and-excursion
    (re-search-backward ">" (line-beginning-position nil))))

(defun ospl/unfill-region (start end)
  "Unfill the region, joining text paragraphs into a single
  logical line. This is useful, e.g., for use with
  'visual-line-mode'."
  (interactive "*r")
  (let ((fill-column (point-max)))
    (fill-region start end)))

(defun ospl/fill-sentences-in-region (start end)
  "Put a newline at the end of each sentence in region."
  (interactive "*r")
  (call-interactively 'ospl/unfill-region)
  (save-mark-and-excursion
    (goto-char start)
    (while (re-search-forward "[:;.?!][]\"')}]*\\( \\)" end t)
      (call-interactively (key-binding (kbd "M-j"))))))

(defun ospl/fill-sentences-in-paragraph ()
  "Put a newline at the end of each sentence in paragraph."
  (interactive)
  (when (not (or (ospl/markdown-in-code-block-p)
                 (ospl/markdown-in-yaml-header-p)
                 ;;(ospl/markdown-in-quotation-p)
                 ))
    (save-mark-and-excursion
      (mark-paragraph)
      (call-interactively 'ospl/fill-sentences-in-region))))

;;;###autoload
(define-minor-mode ospl-mode
  "One Sentence Per Line"
  :init-value nil
  :lighter " ospl"
  :keymap (let ((map (make-sparse-keymap)))
            (define-key map (kbd "M-q") 'ospl/fill-sentences-in-paragraph)
            map)

  (if ospl-mode
      (progn
        (setq-local fill-paragraph-function 'ospl/fill-sentences-in-paragraph)
        (setq-local fill-nobreak-predicate 'ospl/markdown-nobreak-p)))

  ;; Account for new margin width
  (set-window-buffer (selected-window) (current-buffer)))

(provide 'ospl-mode)
