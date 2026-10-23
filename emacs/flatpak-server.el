;;; flatpak-server.el --- Emacs server reachable from other Flatpak instances  -*- lexical-binding: t; -*-

;;; Commentary:

;; Linked into prelude's personal/ directory by the install.sh of the mq
;; repository.
;;
;; Inside the Flatpak sandbox, $XDG_RUNTIME_DIR is private to each
;; instance, so `emacsclient' run from another instance can't find the
;; default socket.  $XDG_RUNTIME_DIR/app/<app id> is shared by all the
;; instances of the app, and with the host, so put the socket there.

;;; Code:

(require 'server)

(let ((app-id (getenv "FLATPAK_ID"))
      (runtime-dir (getenv "XDG_RUNTIME_DIR")))
  (when (and app-id runtime-dir)
    (setq server-socket-dir (expand-file-name (concat "app/" app-id) runtime-dir))))

;; A daemon starts its own server after loading the init files.
(unless (or (daemonp) (server-running-p))
  (server-start))

;;; flatpak-server.el ends here
