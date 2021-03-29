(in-package #:org.shirakumo.fraf.kandria)

(define-pool kandria)

(define-asset (kandria 1x) mesh
    (make-rectangle 1 1 :align :bottomleft))

(define-asset (kandria 16x) mesh
    (make-rectangle 16 16))

(define-asset (kandria placeholder) image
    #p"placeholder.png")

(defgeneric initargs (object)
  (:method-combination append :most-specific-last))

(defclass base-entity (entity)
  ((name :initarg :name :initform NIL :type symbol :documentation "The name of the entity")))

(defmethod entity-at-point (point (entity base-entity))
  (or (call-next-method)
      (when (contained-p point entity)
        entity)))

(defmethod initargs append ((_ base-entity))
  '(:name))

(defclass located-entity (base-entity transformed)
  ((location :initarg :location :initform (vec 0 0) :accessor location
             :type vec2 :documentation "The location in 2D space.")))

(defmethod initargs append ((_ located-entity))
  `(:location))

(defmethod print-object ((entity located-entity) stream)
  (print-unreadable-object (entity stream :type T :identity T)
    (format stream "~a" (location entity))))

(defmethod apply-transforms progn ((obj located-entity))
  (translate-by (round (vx (location obj))) (round (vy (location obj))) 0))

(defclass facing-entity (base-entity transformed)
  ((direction :initarg :direction :initform 1 :accessor direction
              :type integer :documentation "The direction the entity is facing. -1 for left, +1 for right.")))

(defmethod initargs append ((_ facing-entity))
  '(:direction))

(defmethod apply-transforms progn ((obj facing-entity))
  (scale-by (direction obj) 1 1))

(defclass rotated-entity (base-entity transformed)
  ((angle :initarg :angle :initform 0f0 :accessor angle
          :type single-float :documentation "The angle the entity is pointing in.")))

(defmethod initargs append ((_ rotated-entity))
  '(:angle))

(defmethod apply-transforms progn ((obj rotated-entity))
  (rotate-by 0 0 1 (angle obj)))

(defclass sized-entity (located-entity)
  ((bsize :initarg :bsize :initform (nv/ (vec +tile-size+ +tile-size+) 2) :accessor bsize
          :type vec2 :documentation "The bounding box half size.")))

(defmethod initargs append ((_ sized-entity))
  `(:bsize))

(defmethod size ((entity sized-entity))
  (v* (bsize entity) 2))

(defmethod resize ((entity sized-entity) width height)
  (vsetf (bsize entity) (/ width 2) (/ height 2)))

(defmethod scan ((entity sized-entity) (target vec2) on-hit)
  (let ((w (vx2 (bsize entity)))
        (h (vy2 (bsize entity)))
        (loc (location entity)))
    (when (and (<= (- (vx2 loc) w) (vx2 target) (+ (vx2 loc) w))
               (<= (- (vy2 loc) h) (vy2 target) (+ (vy2 loc) h)))
      (let ((hit (make-hit entity (location entity))))
        (unless (funcall on-hit hit) hit)))))

(defmethod scan ((entity sized-entity) (target vec4) on-hit)
  (let ((bsize (bsize entity))
        (loc (location entity)))
    (when (and (< (abs (- (vx2 loc) (vx4 target))) (+ (vx2 bsize) (vz4 target)))
               (< (abs (- (vy2 loc) (vy4 target))) (+ (vy2 bsize) (vw4 target))))
      (let ((hit (make-hit entity (location entity))))
        (unless (funcall on-hit hit) hit)))))

(defmethod scan ((entity sized-entity) (target sized-entity) on-hit)
  (let ((vec (load-time-value (vec4 0 0 0 0)))
        (loc (location target))
        (bsize (bsize target)))
    (vsetf vec (vx2 loc) (vy2 loc) (vx2 bsize) (vy2 bsize))
    (scan entity vec on-hit)))

(defmethod scan-collision (target (entity sized-entity))
  (let ((best-hit (load-time-value (%make-hit NIL (vec 0 0)))) (best-dist NIL))
    (setf (hit-time best-hit) float-features:single-float-positive-infinity)
    (flet ((on-find (hit)
             (when (and (not (eql entity (hit-object hit)))
                        (collides-p entity (hit-object hit) hit))
               (let ((dist (vsqrdist2 (hit-location hit) (location entity))))
                 (when (or (< (hit-time hit) (hit-time best-hit))
                           (and (= (hit-time hit) (hit-time best-hit))
                                (< dist best-dist)))
                   (transfer-hit best-hit hit)
                   (setf best-dist dist))))
             T))
      (scan target entity #'on-find)
      (when (/= (hit-time best-hit) float-features:single-float-positive-infinity)
        best-hit))))

(define-shader-entity sprite-entity (vertex-entity textured-entity sized-entity facing-entity)
  ((vertex-array :initform (// 'kandria '1x))
   (texture :initform (// 'kandria 'placeholder) :initarg :texture :accessor albedo
            :type resource :documentation "The tileset to display the sprite from.")
   (size :initform (vec 16 16) :initarg :size :accessor size
         :type vec2 :documentation "The size of the tile to display (in px).")
   (offset :initform (vec 0 0) :initarg :offset :accessor offset
           :type vec2 :documentation "The offset in the tile map (in px).")
   (layer-index :initform (1- +base-layer+) :initarg :layer :accessor layer-index
                :type integer :documentation "The layer the sprite should be on.")
   (fit-to-bsize :initform T :initarg :fit-to-bsize :accessor fit-to-bsize
                 :type boolean))
  (:inhibit-shaders (textured-entity :fragment-shader)))

(defmethod initargs append ((_ sprite-entity))
  '(:texture :size :offset :layer))

(defmethod initialize-instance :after ((sprite sprite-entity) &key bsize)
  (unless (size sprite)
    (setf (size sprite) (v* (bsize sprite) 2)))
  (unless bsize
    (setf (bsize sprite) (v/ (size sprite) 2))))

(defmethod apply-transforms progn ((sprite sprite-entity))
  (let ((size (v* 2 (bsize sprite))))
    (translate-by (/ (vx size) -2) (/ (vy size) -2) 0)
    (if (fit-to-bsize sprite)
        (scale (vxy_ size))
        (scale (vxy_ (size sprite))))))

(defmethod render :before ((entity sprite-entity) (program shader-program))
  (setf (uniform program "size") (size entity))
  (setf (uniform program "offset") (offset entity)))

(defmethod resize ((sprite sprite-entity) width height)
  (vsetf (size sprite) width height)
  (vsetf (bsize sprite) (/ width 2) (/ height 2)))

(define-class-shader (sprite-entity :fragment-shader)
  "in vec2 texcoord;
out vec4 color;
uniform sampler2D texture_image;
uniform vec2 size;
uniform vec2 offset;

void main(){
  color = texelFetch(texture_image, ivec2(offset+(texcoord*size)), 0);
}")

(defclass game-entity (sized-entity listener)
  ((velocity :initarg :velocity :initform (vec2 0 0) :accessor velocity
             :type vec2 :documentation "The velocity of the entity.")
   (state :initform :normal :accessor state
          :type symbol :documentation "The current state of the entity.")
   (frame-velocity :initform (vec2 0 0) :accessor frame-velocity)
   (chunk :initform NIL :initarg :chunk :accessor chunk)))

(defmethod layer-index ((_ game-entity)) +base-layer+)

;; KLUDGE: ugly way of avoiding allocations
(defmethod scan ((entity sized-entity) (target game-entity) on-hit)
  (let ((hit (aabb (location target) (frame-velocity target)
                   (location entity) (tv+ (bsize entity) (bsize target)))))
    (when hit
      (setf (hit-object hit) entity)
      (unless (funcall on-hit hit) hit))))

(defmethod scan ((entity game-entity) (target game-entity) on-hit)
  (let ((hit (aabb (location target) (tv- (frame-velocity target) (frame-velocity entity))
                   (location entity) (tv+ (bsize entity) (bsize target)))))
    (when hit
      (setf (hit-object hit) entity)
      (unless (funcall on-hit hit) hit))))

(defmethod oob ((entity entity) (none null))
  (unless (find-panel 'editor)
    (setf (state entity) :oob)
    (leave* entity T)))

(defmethod (setf chunk) :after (chunk (entity game-entity))
  (when (and chunk (eql :oob (state entity)))
    (setf (state entity) :normal)))

(defmethod oob ((entity entity) new-chunk)
  (setf (chunk entity) new-chunk))

(defun handle-oob (entity)
  (let ((other (find-containing entity (region +world+)))
        (chunk (chunk entity)))
    (cond (other
           (oob entity other))
          ((or (null chunk)
               (< (vy (location entity))
                  (- (vy (location chunk))
                     (vy (bsize chunk)))))
           (oob entity NIL))
          (T
           (setf (vx (location entity)) (clamp (- (vx (location chunk))
                                                  (vx (bsize chunk)))
                                               (vx (location entity))
                                               (+ (vx (location chunk))
                                                  (vx (bsize chunk)))))))))

(defmethod (setf location) (location (entity game-entity))
  (vsetf (location entity) (vx location) (vy location))
  (handle-oob entity))

(defmethod handle :after ((ev tick) (entity game-entity))
  (let ((vel (frame-velocity entity)))
    (nv+ (location entity) (v* vel (* 100 (dt ev))))
    (vsetf vel 0 0)
    ;; OOB
    (case (state entity)
      ((:oob :dying))
      (T
       (when (or (null (chunk entity))
                 (not (contained-p (location entity) (chunk entity))))
         (handle-oob entity))))))

(defclass transition-event (event)
  ((on-complete :initarg :on-complete :initform NIL :reader on-complete)))

(defmacro transition (&body on-blank)
  `(issue +world+ 'transition-event
          :on-complete (lambda () ,@on-blank)))
