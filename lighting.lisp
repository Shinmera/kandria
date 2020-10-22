(in-package #:org.shirakumo.fraf.kandria)

(defvar *gi-info* (make-hash-table :test 'eq))

(defmethod gi ((name symbol))
  (or (gethash name *gi-info*)
      (error "No GI with name ~s found." name)))

(defmethod (setf gi) (value (name symbol))
  (if value
      (setf (gethash name *gi-info*) value)
      (remhash name *gi-info*))
  value)

(defmacro define-gi (name &body initargs)
  (let ((existing (gensym "EXISTING")))
    `(let ((,existing (ignore-errors (gi ',name))))
       (setf (gi ',name) (trial::ensure-instance ,existing 'gi-info :name ',name ,@initargs)))))

(define-gl-struct gi
  (activep :int :accessor active-p)
  (location :vec2 :accessor location)
  (light :vec3 :accessor light)
  (ambient :vec3 :accessor ambient))

(define-asset (kandria gi) uniform-block
    'gi)

(defclass gi-info ()
  ((name :initform NIL :initarg :name :accessor name)
   (location :initform NIL :initarg :location :accessor location)
   (light :initform NIL :initarg :light :accessor light)
   (ambient :initform 1 :initarg :ambient :accessor ambient)))

(defmethod shared-initialize :after ((info gi-info) slots &key)
  (flet ((normalize-light (light)
           (etypecase light
             (null (vec 0 0 0))
             (real (vec light light light))
             (cons (make-gradient light))
             (vec3 light)
             (gradient light))))
    (setf (light info) (normalize-light (slot-value info 'light)))
    (setf (ambient info) (normalize-light (slot-value info 'ambient)))))

(defmethod location ((info gi-info))
  (let ((loc (slot-value info 'location)))
    (flet ((time-position (hour)
             (let ((tt (* (/ hour 24) 2 PI)))
               (nv+ (vec2 (* -10000 (sin tt)) (* 10000 (- (cos tt))))
                    (location (unit :camera T))))))
      (etypecase loc
        (vec2
         loc)
        (located-entity
         (location loc))
        (real
         (time-position loc))
        ((eql :sun)
         (time-position (hour +world+)))
        (null
         NIL)))))

(flet ((evaluate-light (light)
         (etypecase light
           (vec3
            light)
           (gradient
            (gradient-value (hour +world+) light)))))
  (defmethod light ((info gi-info))
    (evaluate-light (slot-value info 'light)))

  (defmethod ambient ((info gi-info))
    (evaluate-light (slot-value info 'ambient))))

(define-shader-pass lighting-pass (scene-pass per-object-pass hdr-output-pass)
  ((gi-a :initform (make-instance 'gi-info) :accessor gi-a)
   (gi-b :initform (make-instance 'gi-info) :accessor gi-b)
   (mix :initform 1.0 :accessor mix)
   (name :initform 'lighting-pass)))

(defmethod render :before ((pass lighting-pass) target)
  (gl:clear-color 0 0 0 0))

(defmethod handle ((ev switch-chunk) (pass lighting-pass))
  (unless (eql (gi-b pass) (gi (chunk ev)))
    (setf (mix pass) (- 1.0 (min 1.0 (mix pass))))
    (setf (gi-a pass) (gi-b pass))
    (setf (gi-b pass) (gi (chunk ev)))
    (update-lighting pass)))

(defmethod handle ((ev change-time) (pass lighting-pass))
  (update-lighting pass))

(defmethod handle ((ev tick) (pass lighting-pass))
  (when (< (mix pass) 1)
    (incf (mix pass) (dt ev))
    (update-lighting pass)))

(defun update-lighting (pass)
  (let* ((b (gi-b pass))
         (location (location b))
         (light (light b))
         (ambient (ambient b))
         (mix (mix pass)))
    (when (< mix 1)
      (let* ((b (gi-b pass))
             (bloc (location b)))
        (cond (bloc
               (if location
                   (setf location (vlerp location (location b) mix))
                   (setf location (location b)))
               (setf light (vlerp light (light b) mix))
               (setf ambient (vlerp ambient (ambient b) mix)))
              (T
               (setf light (vlerp light (vec 0 0 0) mix))
               (setf ambient (vlerp ambient (vec 1 1 1) mix))))))
    (with-buffer-tx (gi (// 'kandria 'gi))
      (setf (active-p gi) (if location 1 0))
      (setf (location gi) (or location (vec 0 0)))
      (setf (light gi) light)
      (setf (ambient gi) ambient))))

(defmethod (setf lighting) (value (pass lighting-pass))
  (with-buffer-tx (gi (// 'kandria 'gi))
    (setf (active-p gi) (if value 1 0))))

(defmethod lighting ((pass lighting-pass))
  (= 1 (active-p (struct (// 'kandria 'gi)))))

(define-shader-entity light (vertex-entity sized-entity)
  ())

(defmethod object-renderable-p ((light light) (pass lighting-pass)) T)
(defmethod object-renderable-p ((renderable renderable) (pass lighting-pass)) NIL)

(define-shader-pass rendering-pass (render-pass)
  ((lighting :port-type input :texspec (:internal-format :rgba16f))
   (local-shade :initform 0.15 :accessor local-shade)
   (shadow-map :port-type input)
   (exposure :initform 0.5 :accessor exposure)
   (gamma :initform 2.2 :accessor gamma)
   #++(color :port-type output :attachment :color-attachment0
          :texspec (:width 640 :height 416))
   #++(depth :port-type output :attachment :depth-stencil-attachment
             :texspec (:width 640 :height 416))))

(defmethod object-renderable-p ((controller controller) (pass rendering-pass)) NIL)

(defmethod prepare-pass-program :after ((pass rendering-pass) (program shader-program))
  (setf (uniform program "exposure") (exposure pass))
  (setf (uniform program "gamma") (gamma pass)))

(defmethod render :before ((pass rendering-pass) target)
  (if (= 1 (active-p (struct (// 'kandria 'gi))))
      (let* ((target (max 0.1 (local-shade (flow:other-node pass (first (flow:connections (flow:port pass 'shadow-map)))))))
             (shade (local-shade pass))
             (exposure (* 5 shade))
             (gamma (* 2 shade)))
        (let* ((dir (- target shade))
               (ease (/ (expt (abs dir) 1.1) 30)))
          (incf (local-shade pass) (* ease (signum dir))))
        (setf (exposure pass) (clamp 0f0 exposure 10f0)
              (gamma pass) (clamp 1f0 gamma 3f0)))
      (setf (exposure pass) 0.5
            (gamma pass) 2.2)))

(define-class-shader (rendering-pass :fragment-shader -100)
  "out vec4 color;
uniform float gamma = 2.2;
uniform float exposure = 0.5;

void main(){
  vec3 mapped = vec3(1.0) - exp((-color.rgb) * exposure);
  color.rgb = pow(mapped, vec3(1.0 / gamma));
}")

(define-shader-entity lit-entity (renderable)
  ()
  (:buffers (kandria gi)))

(define-class-shader (lit-entity :fragment-shader 100)
  (gl-source (asset 'kandria 'gi))
  "uniform sampler2D lighting;
uniform sampler2D shadow_map;

vec4 apply_lighting(vec4 color, vec2 offset, float absorption){
  vec3 truecolor = pow(color.rgb, vec3(2.2));
  ivec2 pos = ivec2(gl_FragCoord.xy-vec2(0.5)+offset);
  vec4 light = texelFetch(lighting, pos, 0);

  truecolor *= gi.ambient;
  truecolor += light.rgb*max(0, light.a-absorption)*color.rgb;
  
  if(gi.activep != 0){
    float shade = (0.4 < texelFetch(shadow_map, pos, 0).r)? 0 : 1;
    truecolor += gi.light*max(0, shade-absorption)*color.rgb;
  }

  return vec4(truecolor, color.a);
}")

(define-shader-entity lit-sprite (lit-entity sprite-entity)
  ())

(define-class-shader (lit-sprite :fragment-shader)
  "out vec4 color;

void main(){
  color = apply_lighting(color, vec2(0, -5), 0);
}")

(define-shader-entity lit-animated-sprite (lit-entity animated-sprite)
  ())

(define-class-shader (lit-animated-sprite :fragment-shader)
  "out vec4 color;

void main(){
  color = apply_lighting(color, vec2(0, -5), 0);
}")

(define-shader-entity basic-light (light colored-entity)
  ((color :initform (vec4 0.3 0.25 0.1 1.0)
          :type vec4 :documentation "The color of the light")))

(defmethod initialize-instance :after ((light basic-light) &key data)
  (unless (slot-boundp light 'vertex-array)
    (let* ((data (make-array (length data) :adjustable T :fill-pointer T :element-type 'single-float
                                           :initial-contents data))
           (vbo (make-instance 'vertex-buffer :data-usage :dynamic-draw :buffer-data data))
           (vao (make-instance 'vertex-array :vertex-form :triangle-fan
                                             :bindings `((,vbo :size 2 :offset 0 :stride 8))
                                             :size (/ (length data) 2))))
      (setf (vertex-array light) vao))))

(defmethod update-bounding-box ((light basic-light))
  (let ((data (buffer-data (caar (bindings (vertex-array light)))))
        (loc (location light))
        x+ x- y+ y-)
    ;; Determine bounds
    (loop for i from 0 below (length data) by 2
          for x = (+ (vx loc) (aref data (+ i 0)))
          for y = (+ (vy loc) (aref data (+ i 1)))
          do (when (or (null x+) (< x+ x)) (setf x+ x))
             (when (or (null x-) (< x x-)) (setf x- x))
             (when (or (null y+) (< y+ y)) (setf y+ y))
             (when (or (null y-) (< y y-)) (setf y- y)))
    ;; Update coordinates
    (vsetf (bsize light) (/ (- x+ x-) 2) (/ (- y+ y-) 2))
    (let ((newloc (vec (+ x- (vx (bsize light)))
                       (+ y- (vy (bsize light))))))
      (loop for i from 0 below (length data) by 2
            do (incf (aref data (+ i 0)) (- (vx loc) (vx newloc)))
               (incf (aref data (+ i 1)) (- (vy loc) (vy newloc))))
      (setf (location light) newloc))))

(defmethod add-vertex ((light basic-light) &key location)
  (let* ((vao (vertex-array light))
         (vbo (caar (bindings vao)))
         (data (buffer-data vbo))
         (loc (v- location (location light))))
    (loop for i from 0 below (length data) by 2
          do (when (and (= (vx loc) (aref data (+ i 0)))
                        (= (vy loc) (aref data (+ i 1))))
               (array-utils:array-shift data :n -2 :from (+ 2 i))
               (return))
          finally (vector-push-extend (vx loc) data)
                  (vector-push-extend (vy loc) data))
    (update-bounding-box light)
    (resize-buffer vbo (* (length data) 4) :data data)
    (setf (size vao) (if (<= 6 (length data))
                         (/ (length data) 2)
                         0))))

(define-shader-entity per-vertex-light (light vertex-colored-entity)
  ())

(define-shader-entity textured-light (light sprite-entity resizable)
  ((multiplier :initform 1.0f0 :initarg :multiplier :accessor multiplier
               :type single-float :documentation "Light intensity multiplier")))

(defmethod render :before ((light textured-light) (program shader-program))
  (setf (uniform program "multiplier") (multiplier light)))

(defmethod resize ((sprite sprite-entity) width height)
  (vsetf (bsize sprite) (/ width 2) (/ height 2)))

(define-class-shader (textured-light :fragment-shader)
  "uniform float multiplier = 1.0;
out vec4 color;

void main(){
  color *= multiplier;
}")
