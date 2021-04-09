(in-package #:kandria)

(defclass spawner (listener sized-entity resizable)
  ((spawn-type :initarg :spawn-type :initform NIL :accessor spawn-type :type symbol)
   (spawn-count :initarg :spawn-count :initform 2 :accessor spawn-count :type integer)
   (reflist :initform () :accessor reflist)
   (adjacent :initform () :accessor adjacent)))

(defmethod alloy::object-slot-component-type ((spawner spawner) _ (slot (eql 'spawn-type)))
  (find-class 'alloy:symb))

(defmethod (setf location) :after (location (spawner spawner))
  (let ((chunk (find-chunk spawner))
        (adjacent ()))
    (when chunk
      (bvh:do-fitting (entity (bvh (region +world+))
                              (vec (- (vx (location chunk)) (vx (bsize chunk)) 8)
                                   (- (vy (location chunk)) (vy (bsize chunk)) 8)
                                   (+ (vx (location chunk)) (vx (bsize chunk)) 8)
                                   (+ (vy (location chunk)) (vy (bsize chunk)) 8)))
        (when (typep entity 'chunk)
          (push entity adjacent))))
    (print adjacent)
    (setf (adjacent spawner) adjacent)))

(defmethod handle ((ev switch-chunk) (spawner spawner))
  (cond ((null (reflist spawner))
         (when (find (chunk ev) (adjacent spawner))
           (setf (reflist spawner)
                 (spawn (location spawner) (spawn-type spawner)
                        :count (spawn-count spawner)
                        :jitter (bsize spawner)))))
        ((not (find (chunk ev) (adjacent spawner)))
         (dolist (entity (reflist spawner))
           (when (slot-boundp entity 'container)
             (leave* entity T)))
         (setf (reflist spawner) ()))))

(defmethod spawn ((location vec2) type &rest initargs &key (count 1) (jitter +tile-size+) &allow-other-keys)
  (let* ((initargs (remf* initargs :count :jitter))
         (first (apply #'make-instance type :location (vcopy location) initargs)))
    ;; FIXME: speedup by caching which classes have already been loaded?
    (trial:commit first (loader +main+) :unload NIL)
    (loop repeat count
          collect (let ((clone (clone first)))
                    (nv+ (location clone) (etypecase jitter
                                            (real (vrandr 0 jitter PI))
                                            (vec2 (vrand (v- jitter) (v+ jitter)))))
                    (spawn (region +world+) clone)))))

(defmethod spawn ((container container) (entity entity) &key)
  (enter* entity container)
  entity)

(defmethod spawn ((marker located-entity) type &rest initargs)
  (apply #'spawn (location marker) type initargs))

(defmethod spawn ((name symbol) type &rest initargs &key &allow-other-keys)
  (apply #'spawn (location (unit name +world+)) type initargs))
