(in-package #:org.shirakumo.fraf.kandria)

(defclass freeform (tool)
  ((start-pos :initform NIL :accessor start-pos)
   (original-loc :initform NIL :accessor original-loc)
   (original-size :initform NIL :accessor original-size)))

(defmethod label ((tool freeform)) "Freeform")

(defmethod handle ((event mouse-press) (tool freeform))
  (etypecase (entity tool)
    (resizable
     (let* ((p (nv- (mouse-world-pos (pos event))
                    (location (entity tool))))
            (b (bsize (entity tool)))
            ;; Box SDF
            (d (nv- (vabs p) b))
            (d (+ (min 0 (max (vx d) (vy d)))
                  (vlength (vmax d 0)))))
       ;; If close to borders, resize.
       (setf (state tool) (if (< (abs d) (/ 1 (zoom (unit :camera T))))
                              :resizing
                              :moving))))
    (located-entity
     (setf (state tool) :moving)))
  (setf (start-pos tool) (mouse-world-pos (pos event)))
  (setf (original-loc tool) (vcopy (location (entity tool))))
  (setf (original-size tool) (vcopy (bsize (entity tool)))))

(defmethod handle ((event mouse-release) (tool freeform))
  (let ((entity (entity tool)))
    (case (state tool)
      (:moving
       (let ((new (vcopy (location entity)))
             (old (vcopy (original-loc tool))))
         (with-commit (tool)
             ((setf (location entity) new))
             ((setf (location entity) old)))))
      (:resizing
       (let ((new-loc (vcopy (location entity)))
             (old-loc (vcopy (original-loc tool)))
             (new-size (vcopy (bsize entity)))
             (old-size (vcopy (original-size tool))))
         (with-commit (tool)
             ((resize entity (* 2 (vx new-size)) (* 2 (vy new-size)))
               (setf (location entity) new-loc))
             ((resize entity (* 2 (vx old-size)) (* 2 (vy old-size)))
               (setf (location entity) old-loc)))))))
  (setf (state tool) NIL))

(defun nvalign-corner (loc bsize grid)
  (nv+ (nvalign (v- loc bsize) grid) bsize))

(defmethod handle ((event mouse-move) (tool freeform))
  (case (state tool)
    (:moving
     (let* ((entity (entity tool))
            (new (closest-acceptable-location
                  entity (nvalign-corner
                          (nv+ (nv- (mouse-world-pos (pos event)) (start-pos tool))
                               (original-loc tool))
                          (bsize entity)
                          (typecase entity
                            (chunk +tile-size+)
                            (T (/ +tile-size+ 2)))))))
       (when (v/= new (location entity))
         (setf (location entity) new)
         (update-marker (editor tool)))))
    (:resizing
     (let* ((entity (entity tool))
            (current (nvalign (mouse-world-pos (pos event)) +tile-size+))
            (starting (nvalign (start-pos tool) +tile-size+))
            (new-pos (v+ (original-loc tool) (nv/ (v- current starting) 2)))
            (new-size (vmax (nv/ (vec +tile-size+ +tile-size+) 2)
                            (nvabs (v- current new-pos)))))
       (when (v/= new-size (bsize entity))
         ;; FIXME: this is destructive for chunks. Need some way to either copy state or not throw it away too eagerly.
         (resize entity (* 2 (vx new-size)) (* 2 (vy new-size)))
         (setf (location entity) new-pos)
         (update-marker (editor tool)))))))
