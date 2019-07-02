(in-package #:org.shirakumo.fraf.leaf)

(define-global +light-count+ 32)

(define-gl-struct light
  (type :int)
  (position :vec3)
  (dimensions :vec4)
  (color :vec3)
  (intensity :float))

(define-gl-struct lights
  (global-illumination :vec3)
  (lights (:struct light) :count +light-count+)
  (count :int))

(define-asset (leaf lights) uniform-buffer
    'lights)

(defclass light (located-entity)
  ((index :initform NIL :accessor index)
   (location :initarg :location :initform (vec 0 0 0) :accessor location
             :type vec3 :documentation "The location in 3D space.")
   (color :initarg :color :initform (vec 1 1 1) :accessor color
          :type vec3 :documentation "The light colour.")
   (intensity :initarg :intensity :initform 0.5 :accessor intensity
              :type single-float :documentation "The light intensity.")
   (light-dimensions :initform (vec 0 0 0 0) :accessor light-dimensions)))

(defmethod active-p ((light light))
  (not (null (index light))))

(defmethod (setf location) :after (_ (light light))
  (activate light))

(defmethod (setf color) :after (_ (light light))
  (activate light))

(defmethod (setf intensity) :after (_ (light light))
  (activate light))

(defmethod activate ((light light))
  (when (active-p light)
    (let ((i (index light))
          (lights (asset 'leaf 'lights)))
      (setf (buffer-field lights (format NIL "Lights.lights[~d].type" i)) (light-type light))
      (setf (buffer-field lights (format NIL "Lights.lights[~d].position" i)) (location light))
      (setf (buffer-field lights (format NIL "Lights.lights[~d].dimensions" i)) (light-dimensions light))
      (setf (buffer-field lights (format NIL "Lights.lights[~d].color" i)) (color light))
      (setf (buffer-field lights (format NIL "Lights.lights[~d].intensity" i)) (intensity light)))))

(defmethod deactivate ((light light))
  (let ((i (index light)))
    (when i
      (let ((lights (asset 'leaf 'lights)))
        (setf (buffer-field lights (format NIL "Lights.lights[~d].type" i)) 0)))))

(defclass point-light (light)
  ())

(defmethod shared-initialize :after ((light point-light) slots &key radius)
  (when radius (setf (radius light) radius)))

(defmethod light-type ((light point-light)) 1)

(defmethod radius ((light point-light))
  (vx4 (light-dimensions light)))

(defmethod (setf radius) (value (light point-light))
  (setf (vx4 (light-dimensions light)) value)
  (activate light))

(defclass cone-light (light)
  ())

(defmethod shared-initialize :after ((light cone-light) slots &key aperture radius angle)
  (when aperture (setf (aperture light) aperture))
  (when radius (setf (radius light) radius))
  (when angle (setf (angle light) angle)))

(defmethod light-type ((light cone-light)) 2)

(defmethod aperture ((light cone-light))
  (vx4 (light-dimensions light)))

(defmethod (setf aperture) (value (light cone-light))
  (setf (vx4 (light-dimensions light)) value)
  (activate light))

(defmethod radius ((light cone-light))
  (vy4 (light-dimensions light)))

(defmethod (setf radius) (value (light cone-light))
  (setf (vy4 (light-dimensions light)) value)
  (activate light))

(defmethod angle ((light cone-light))
  (vz4 (light-dimensions light)))

(defmethod (setf angle) (value (light cone-light))
  (setf (vz4 (light-dimensions light)) value)
  (activate light))

(defclass trapezoid-light (light)
  ())

(defmethod shared-initialize :after ((light trapezoid-light) slots &key aperture top height angle)
  (when aperture (setf (aperture light) aperture))
  (when top (setf (top light) top))
  (when height (setf (height light) height))
  (when angle (setf (angle light) angle)))

(defmethod light-type ((light trapezoid-light)) 3)

(defmethod aperture ((light trapezoid-light))
  (vx4 (light-dimensions light)))

(defmethod (setf aperture) (value (light trapezoid-light))
  (setf (vx4 (light-dimensions light)) value)
  (activate light))

(defmethod top ((light trapezoid-light))
  (vy4 (light-dimensions light)))

(defmethod (setf top) (value (light trapezoid-light))
  (setf (vy4 (light-dimensions light)) value)
  (activate light))

(defmethod height ((light trapezoid-light))
  (vz4 (light-dimensions light)))

(defmethod (setf height) (value (light trapezoid-light))
  (setf (vz4 (light-dimensions light)) value)
  (activate light))

(defmethod angle ((light trapezoid-light))
  (vw4 (light-dimensions light)))

(defmethod (setf angle) (value (light trapezoid-light))
  (setf (vw4 (light-dimensions light)) value)
  (activate light))

(defclass light-environment ()
  ((active-p :initform NIL :reader active-p)
   (global-illumination :initarg :global-illumination :initform (vec 0.5 0.5 0.5) :accessor global-illumination)))

(defmethod (setf global-illumination) :after (value (environment light-environment))
  (when (active-p environment)
    (let ((lights (asset 'leaf 'lights)))
      (setf (buffer-field lights "Lights.global_illumination") value))))

(defmethod activate ((environment light-environment))
  (let ((lights (asset 'leaf 'lights))
        (i 0))
    (for:for ((light over environment))
      (when (typep light 'light)
        (setf (index light) i)
        (activate light)
        (incf i)))
    (setf (buffer-field lights "Lights.count") i)
    (setf (buffer-field lights "Lights.global_illumination") (global-illumination environment))))

(defmethod activate :after ((environment light-environment))
  (setf (slot-value environment 'active-p) T))

(defmethod deactivate ((environment light-environment))
  (let ((lights (asset 'leaf 'lights)))
    (for:for ((light over environment))
      (when (typep light 'light)
        (setf (index light) NIL)))
    (setf (buffer-field lights "Lights.count") 0)
    (setf (buffer-field lights "Lights.global_illumination") (vec 1 1 1))))

(defmethod deactivate :before ((environment light-environment))
  (setf (slot-value environment 'active-p) NIL))

;; Refresh environment to remove/add lights dynamically
(defmethod enter :after ((light light) (environment light-environment))
  (when (active-p environment)
    (activate environment)))

(defmethod leave :after ((light light) (environment light-environment))
  (when (active-p environment)
    (activate environment)))

(define-shader-entity lighted-entity ()
  ()
  (:buffers (leaf lights)))

(define-class-shader (lighted-entity :fragment-shader)
  (gl-source (asset 'leaf 'lights))
  "
vec3 add(vec3 a, vec3 b){
  return a+b;
}

vec3 screen(vec3 a, vec3 b){
  return 1 - (1-a) * (1-b);
}

vec3 overlay(vec3 a, vec3 b){
  return (length(a) < 0.5)? (2*a*b) : (1-2*(1-a)*(1-b));
}

vec3 soft_light(vec3 a, vec3 b){
  return (1-2*b)*a*a + 2*b*a;
}

float point_light_sdf(vec2 position, vec4 dimensions){
  return length(position) - dimensions.x;
}

vec2 rotate_point(vec2 p, float theta){
  mat2 rot;
  rot[0] = vec2(cos(theta), -sin(theta));
  rot[1] = vec2(sin(theta), cos(theta));
  return rot*p;
}

float trapezoid_light_sdf(vec2 p, vec4 dimensions){
  vec2 c = vec2(sin(dimensions.x/2), cos(dimensions.x/2));
  float t = dimensions.y;
  float b = dimensions.z;
  float theta = dimensions.w;
  float h = p.y;

  p = rotate_point(p, theta);
  p.x = abs(p.x);
  p.y += t;
  
  float m = length(p-c*max(dot(p,c),0.0));
  return max(max(m*sign(c.y*p.x-c.x*p.y), -h), -(b+(-h)));
}

float cone_light_sdf(vec2 p, vec4 dimensions){
  vec2 c = vec2(sin(dimensions.x/2), cos(dimensions.x/2));
  float r = dimensions.y;
  float theta = dimensions.z;

  p = rotate_point(p, theta);
  p.x = abs(p.x);
  float l = length(p) - r;
  float m = length(p-c*clamp(dot(p,c),0.0,r));
  return max(l,m*sign(c.y*p.x-c.x*p.y));
}

float evaluate_light(vec2 position, Light light){
  switch(light.type){
  case 1: return point_light_sdf(position, light.dimensions);
  case 2: return cone_light_sdf(position, light.dimensions);
  case 3: return trapezoid_light_sdf(position, light.dimensions);
  default: return 0.0;
  }
}

float light_shading(float sdf){
  return clamp(-sdf/2, 0, 1);
}

vec3 shade_lights(vec3 albedo, vec3 position){
  vec3 color = lights.global_illumination * albedo;
  for(int i=0; i<lights.count; ++i){
    Light light = lights.lights[i];
    vec3 relative_position = light.position - position;

    // Don't light layers that are more than one away from the light.
    if(1 < abs(relative_position.z)) continue;
    
    float sdf = evaluate_light(relative_position.xy, light);
    if(sdf <= 0){
      color += add(albedo.rgb, light.color)
            * light.intensity
            * light_shading(sdf);
    }
  }
  return color;
}")