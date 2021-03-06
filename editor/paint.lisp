(in-package #:org.shirakumo.fraf.kandria)

(defclass painter-tool (tool)
  ())

(defmethod handle ((event mouse-press) (tool painter-tool))
  (paint-tile tool event)
  (loop for layer across (layers (entity tool))
        for i from 0
        do (if (= i (layer (sidebar (editor tool))))
               (setf (visibility layer) 1.0)
               (setf (visibility layer) 0.5))))

(defmethod handle :after ((event mouse-release) (tool painter-tool))
  (loop for layer across (layers (entity tool))
        do (setf (visibility layer) 1.0))
  (setf (state tool) NIL))

(defmethod handle ((ev lose-focus) (tool painter-tool))
  (handle (make-instance 'mouse-release :button :left :pos (or (end-pos tool) (vec 0 0))) tool))

(defmethod handle ((event mouse-move) (tool painter-tool))
  (case (state tool)
    (:placing
     (paint-tile tool event))))

(defmethod handle ((event key-press) (tool painter-tool))
  (case (key event)
    (:1 (setf (layer (sidebar (editor tool))) 0))
    (:2 (setf (layer (sidebar (editor tool))) 1))
    (:3 (setf (layer (sidebar (editor tool))) 2))
    (:4 (setf (layer (sidebar (editor tool))) 3))
    (:5 (setf (layer (sidebar (editor tool))) 4))))

(defmethod tile-to-place ((tool painter-tool))
  (cond ((retained :left)
         (tile-to-place (sidebar (editor tool))))
        (T
         '(0 0 1 1))))

(defclass paint (painter-tool)
  ((stroke :initform NIL :accessor stroke)))

(defmethod label ((tool paint)) "Paint")

(defmethod end-pos ((tool paint))
  (caar (stroke tool)))

(defmethod handle ((event mouse-release) (tool paint))
  (case (state tool)
    (:placing
     (setf (state tool) NIL)
     (let ((entity (entity tool)))
       (destructuring-bind (tile . stroke) (nreverse (stroke tool))
         (with-commit (tool)
             ((loop for (loc . _) in stroke
                    do (setf (tile loc entity) tile)))
             ((loop for (loc . tile) in (reverse stroke)
                    do (setf (tile loc entity) tile)))))
       (setf (stroke tool) NIL)))))

(defmethod handle ((event mouse-scroll) (tool paint))
  (destructuring-bind (x y &optional w ha) (tile-to-place (sidebar (editor tool)))
    (setf (tile-to-place (sidebar (editor tool)))
          (if (retained :shift)
              (list x (+ y (floor (signum (delta event)))))
              (list (+ x (floor (signum (delta event)))) y)))))

(defmethod paint-tile ((tool paint) event)
  (let* ((entity (entity tool))
         (loc (mouse-world-pos (pos event)))
         (loc (if (show-solids entity)
                  loc
                  (vec (vx loc) (vy loc) (layer (sidebar (editor tool))))))
         (tile (tile-to-place tool)))
    (cond ((retained :control)
           (let* ((base-layer (aref (layers entity) +base-layer+))
                  (original (copy-seq (pixel-data base-layer))))
             (with-cleanup-on-failure (setf (pixel-data base-layer) original)
               (with-commit (tool)
                 ((auto-tile entity (vxy loc) (cdr (assoc (tile-set (sidebar (editor tool)))
                                                          (tile-types (tile-data entity))))))
                 ((setf (pixel-data base-layer) original))))))
          ((retained :shift)
           (let* ((base-layer (aref (layers entity) +base-layer+))
                  (original (copy-seq (pixel-data base-layer))))
             (with-commit (tool)
               ((flood-fill entity loc tile))
               ((setf (pixel-data base-layer) original)))))
          ((and (typep event 'mouse-press) (eql :middle (button event)))
           (setf (tile-to-place (sidebar (editor tool)))
                 (tile loc entity)))
          ((tile loc entity)
           (setf (state tool) :placing)
           (unless (stroke tool)
             (push tile (stroke tool)))
           (when (or (null (cdr (stroke tool)))
                     (v/= loc (caar (stroke tool))))
             ;; FIXME: Make this work right with multiple tiles placement.
             (push (cons loc (tile loc entity)) (stroke tool))
             (setf (tile loc entity) tile))))))
