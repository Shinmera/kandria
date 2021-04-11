(in-package #:org.shirakumo.fraf.kandria)

(defun save-state-path (name)
  (ensure-directories-exist
   (make-pathname :name (format NIL "~(~a~)" name) :type "zip"
                  :defaults (config-directory))))

(defclass save-state ()
  ((author :initarg :author :accessor author)
   (start-time :initarg :start-time :accessor start-time)
   (save-time :initarg :save-time :accessor save-time)
   (play-time :initarg :play-time :accessor play-time)
   (file :initarg :file :accessor file))
  (:default-initargs
   :author (pathname-utils:directory-name (user-homedir-pathname))
   :start-time (get-universal-time)
   :save-time (get-universal-time)
   :play-time (total-play-time)))

(defmethod initialize-instance :after ((save-state save-state) &key (filename ""))
  (unless (slot-boundp save-state 'file)
    (setf (file save-state) (merge-pathnames filename (save-state-path (start-time save-state))))))

(defmethod print-object ((save-state save-state) stream)
  (print-unreadable-object (save-state stream :type T)
    (format stream "~s ~s" (author save-state) (file save-state))))

(defun string<* (a b)
  (if (= (length a) (length b))
      (string< a b)
      (< (length a) (length b))))

(defun list-saves ()
  (sort
   (loop for file in (directory (make-pathname :name :wild :type "zip" :defaults (config-directory)))
         for state = (handler-case (minimal-load-state file)
                       (warning ()
                         (v:warn :kandria.save "Save state ~s is too old, ignoring." file)
                         NIL))
         when state collect state)
   #'string<* :key (lambda (f) (pathname-name (file f)))))

(defun minimal-load-state (file)
  (with-packet (packet file)
    (destructuring-bind (header initargs)
        (parse-sexps (packet-entry "meta.lisp" packet :element-type 'character))
      (assert (eq 'save-state (getf header :identifier)))
      (unless (supported-p (make-instance (getf header :version)))
        (warn "Save file too old to support."))
      (apply #'make-instance 'save-state :file file initargs))))

(defun current-save-version ()
  (make-instance 'save-v1))

(defgeneric load-state (state world))
(defgeneric save-state (world state &key version &allow-other-keys))

(defmethod save-state ((world (eql T)) save &rest args)
  (apply #'call-next-method +world+ save args))

(defmethod save-state :around (world target &rest args &key (version T))
  (apply #'call-next-method world target :version (ensure-version version (current-save-version)) args))

(defmethod save-state ((world world) (save-state save-state) &key version)
  (v:info :kandria.save "Saving state from ~a to ~a" world save-state)
  (setf (save-time save-state) (get-universal-time))
  (with-packet (packet (file save-state) :direction :output :if-exists :supersede)
    (with-packet-entry (stream "meta.lisp" packet :element-type 'character)
      (princ* (list :identifier 'save-state :version (type-of version)) stream)
      (princ* (list :author (author save-state)
                    :start-time (start-time save-state)
                    :save-time (save-time save-state)
                    :play-time (play-time save-state))
              stream))
    (encode-payload world NIL packet version)))

(defmethod load-state ((save-state save-state) world)
  (load-state (file save-state) world))

(defmethod load-state (state (world (eql T)))
  (load-state state +world+))

(defmethod load-state ((integer integer) world)
  (load-state (save-state-path integer) world))

(defmethod load-state ((pathname pathname) world)
  (with-packet (packet pathname)
    (load-state packet world)))

(defmethod load-state ((packet packet) (world world))
  (v:info :kandria.save "Loading state from ~a into ~a" packet world)
  (destructuring-bind (header initargs)
      (parse-sexps (packet-entry "meta.lisp" packet :element-type 'character))
    (assert (eq 'save-state (getf header :identifier)))
    (when (unit 'distortion T)
      (setf (strength (unit 'distortion T)) 0.0))
    (when (unit 'fade T)
      (setf (strength (unit 'fade T)) 0.0))
    (when (unit 'walkntalk world)
      (walk-n-talk NIL))
    (when (find-panel 'status-lines)
      (clear (find-panel 'status-lines)))
    (let ((version (coerce-version (getf header :version))))
      (decode-payload NIL world packet version)
      (apply #'make-instance 'save-state initargs))))

(defclass quicksave-state (save-state)
  ((file :initform (save-state-path "quicksave"))))
