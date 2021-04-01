(in-package #:org.shirakumo.fraf.kandria)

(defclass sprite-animation (trial:sprite-animation)
  ((cooldown :initarg :cooldown :initform 0.0 :accessor cooldown)))

(defclass frame (sprite-frame alloy:observable)
  ((hurtbox :initform (vec 0 0 0 0) :accessor hurtbox)
   (offset :initform (vec 0 0) :accessor offset)
   (acceleration :initform (vec 0 0) :accessor acceleration)
   (multiplier :initform (vec 1 1) :accessor multiplier)
   (knockback :initform (vec 0 0) :accessor knockback)
   (damage :initform 0 :accessor damage)
   (stun-time :initform 0f0 :accessor stun-time)
   (flags :initform #b001 :accessor flags)
   (effect :initform NIL :accessor effect)))

(alloy:make-observable '(setf hurtbox) '(value alloy:observable))

(defmethod shared-initialize :after ((frame frame) slots &key sexp)
  (when sexp
    (destructuring-bind (&key (hurtbox '(0 0 0 0))
                              (offset '(0 0))
                              (acceleration '(0 0))
                              (multiplier '(1 1))
                              (knockback '(0 0))
                              (damage 0)
                              (stun-time 0)
                              (flags 1)
                              (effect NIL))
        sexp
      (setf (hurtbox frame) (apply #'vec hurtbox))
      (setf (offset frame) (apply #'vec offset))
      (setf (acceleration frame) (apply #'vec acceleration))
      (setf (multiplier frame) (apply #'vec multiplier))
      (setf (knockback frame) (apply #'vec knockback))
      (setf (damage frame) damage)
      (setf (stun-time frame) (float stun-time))
      (setf (flags frame) flags)
      (setf (effect frame) effect))))

(defmacro define-frame-flag (id name)
  `(progn
     (defmethod ,name ((frame frame))
       (logbitp ,id (flags frame)))
     (defmethod (setf ,name) (value (frame frame))
       (setf (ldb (byte 1 ,id) (flags frame)) (if value 1 0)))))

;; Whether an attack will interrupt this frame
(define-frame-flag 0 interruptable-p)
;; Whether the entity is invincible
(define-frame-flag 1 invincible-p)
;; Whether the frame can be cancelled
(define-frame-flag 2 cancelable-p)
;; Whether the frame's hit will override the iframes
(define-frame-flag 3 iframe-clearing-p)

(defun transfer-frame (target source)
  (setf (hurtbox target) (vcopy (hurtbox source)))
  (setf (offset target) (vcopy (offset source)))
  (setf (acceleration target) (vcopy (acceleration source)))
  (setf (multiplier target) (vcopy (multiplier source)))
  (setf (knockback target) (vcopy (knockback source)))
  (setf (damage target) (damage source))
  (setf (stun-time target) (stun-time source))
  (setf (flags target) (flags source))
  (setf (effect target) (effect source))
  target)

(defmethod clear ((target frame))
  (setf (hurtbox target) (vec 0 0 0 0))
  (setf (offset target) (vec 0 0))
  (setf (acceleration target) (vec 0 0))
  (setf (multiplier target) (vec 1 1))
  (setf (knockback target) (vec 0 0))
  (setf (damage target) 0)
  (setf (stun-time target) 0f0)
  (setf (flags target) #b001)
  (setf (effect target) NIL)
  target)

(defclass sprite-data (compiled-generator trial:sprite-data)
  ((json-file :initform NIL :accessor json-file)
   (source :initform NIL :accessor source)
   (palette :initform NIL :accessor palette)
   (palettes :initform NIL :accessor palettes)))

(defmethod notify:files-to-watch append ((asset sprite-data))
  (list (merge-pathnames (getf (read-src (input* asset)) :source) (input* asset))))

(defmethod notify:notify :before ((asset sprite-data) file)
  (when (string= "ase" (pathname-type file))
    (sleep 1)
    (compile-resources asset T)))

(defmethod write-animation ((sprite sprite-data) &optional (stream T))
  (let ((*package* #.*package*))
    (format stream "(:source ~s~%" (source sprite))
    (format stream " :animation-data ~s~%" (json-file sprite))
    (format stream " :palette ~s~%" (palette sprite))
    (format stream " :palettes ~s~%" (palettes sprite))
    (format stream " :animations~%  (")
    (loop for animation across (animations sprite)
          do (write-animation animation stream))
    (format stream ")~% :frames~%  (")
    (loop for frame across (frames sprite)
          for i from 1
          do (write-animation frame stream)
             (format stream " ; ~3d" i))
    (format stream "~%))~%")))

(defmethod write-animation ((animation sprite-animation) &optional (stream T))
  (format stream "~&   (~20a :start ~3d :end ~3d :loop-to ~3a :next ~s :cooldown ~s)"
          (name animation)
          (start animation)
          (end animation)
          (loop-to animation)
          (etypecase (next-animation animation)
            (symbol (next-animation animation))
            (animation (name (next-animation animation))))
          (cooldown animation)))

(defmethod write-animation ((frame frame) &optional (stream T))
  (format stream "~& (:damage ~3a :stun-time ~3f :flags #b~4,'0b :effect ~10s :acceleration (~4f ~4f) :multiplier (~4f ~4f) :knockback (~4f ~4f) :hurtbox (~4f ~4f ~4f ~4f) :offset (~4f ~4f))"
          (damage frame)
          (stun-time frame)
          (flags frame)
          (effect frame)
          (vx (acceleration frame)) (vy (acceleration frame))
          (vx (multiplier frame)) (vy (multiplier frame))
          (vx (knockback frame)) (vy (knockback frame))
          (vx (hurtbox frame)) (vy (hurtbox frame)) (vz (hurtbox frame)) (vw (hurtbox frame))
          (vx (offset frame)) (vy (offset frame))))

(defmethod compile-resources ((sprite sprite-data) (path pathname) &key force)
  (destructuring-bind (&key source palette albedo animation-data &allow-other-keys) (read-src path)
    (let ((source (merge-pathnames source path))
          (animation-data (merge-pathnames animation-data path))
          (albedo (merge-pathnames (or albedo (make-pathname :type "png" :defaults source)) path)))
      (when (or force (recompile-needed-p (list albedo animation-data)
                                          (list source path)))
        (v:info :kandria.resources "Compiling spritesheet from ~a..." source)
        (aseprite "--sheet-pack"
                  "--trim"
                  "--shape-padding" "1"
                  "--sheet" albedo
                  "--format" "json-array"
                  "--filename-format" "{tagframe} {tag}"
                  "--list-tags"
                  "--data" animation-data
                  source)
        ;; Make sure we have LF.
        (re-encode-json animation-data)
        ;; Convert palette colours
        (when palette
          (convert-palette albedo (merge-pathnames palette path)))))))

(defmethod generate-resources ((sprite sprite-data) (path pathname) &key)
  (destructuring-bind (&key source palette palettes animation-data animations frames &allow-other-keys) (read-src path)
    (setf (json-file sprite) animation-data)
    (setf (source sprite) source)
    (setf (palette sprite) palette)
    (setf (palettes sprite) palettes)
    (prog1 (with-kandria-io-syntax
             (call-next-method sprite (merge-pathnames animation-data path)))
      (loop for expr in animations
            do (destructuring-bind (name &key start end loop-to next (cooldown 0.0)) expr
                 (let ((animation (find name (animations sprite) :key #'name)))
                   (when animation
                     (change-class animation 'sprite-animation
                                   :loop-to loop-to
                                   :next-animation next
                                   :cooldown cooldown)
                     ;; Attempt to account for changes in the frame counts of the animations
                     ;; by updating frame data per-animation here. We have to assume that
                     ;; frames are only removed or added at the end of an animation, as we
                     ;; can't know anything more.
                     (when (and start end)
                       (let ((rstart (start animation))
                             (rend (end animation))
                             (rframes (frames sprite)))
                         (when (< (loop-to animation) rstart)
                           (setf (loop-to animation) (+ rstart (- (loop-to animation) start))))
                         (loop for i from 0 below (min (- end start) (- rend rstart))
                               for frame = (elt rframes (+ rstart i))
                               for frame-info = (elt frames (+ start i))
                               do (change-class frame 'frame :sexp frame-info))))))))
      ;; Make sure all frames are in the correct class.
      (loop for frame across (frames sprite)
            do (unless (typep frame 'frame) (change-class frame 'frame)))
      ;; Make sure all animations are in the correct class.
      (loop for animation across (animations sprite)
            do (unless (typep animation 'sprite-animation) (change-class animation 'sprite-animation))))))
