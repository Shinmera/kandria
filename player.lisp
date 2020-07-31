(in-package #:org.shirakumo.fraf.leaf)

(define-global +player-movement-data+
    (macrolet ((mktab* (&rest entries)
                 `(mktab ,@(loop for (k v) in entries
                                 collect `(list ',k ,v)))))
      (mktab* (coyote-time     0.08)
              (velocity-limit  (vec 10 10))
              (walk-acc        0.1)
              (walk-limit      1.9)
              (run-acc         0.0125)
              (run-time        3.0)
              (run-limit       4.0)
              (air-acc         0.08)
              (air-dcc         0.97)
              (climb-up        0.8)
              (climb-down      1.5)
              (slide-limit    -1.2)
              (crawl           0.5)
              (jump-acc        2.5)
              (jump-mult       1.1)
              (walljump-acc    (vec 2.75 2.5))
              (dash-acc        1.2)
              (dash-dcc        0.875)
              (dash-air-dcc    0.98)
              (dash-acc-start  0.05)
              (dash-dcc-start  0.2)
              (dash-dcc-end    0.3)
              (dash-min-time   0.25)
              (dash-max-time   0.675))))

(defmacro p! (name)
  `(gethash ',name +player-movement-data+))

(define-shader-entity player (animatable ephemeral)
  ((bsize :initform (vec 7.0 15.0))
   (spawn-location :initform (vec2 0 0) :accessor spawn-location)
   (prompt :initform (make-instance 'prompt :text :y :size 16 :color (vec 1 1 1 1)) :accessor prompt)
   (interactable :initform NIL :accessor interactable)
   (jump-time :initform 1.0d0 :accessor jump-time)
   (dash-time :initform 1.0d0 :accessor dash-time)
   (run-time :initform 1.0d0 :accessor run-time)
   (air-time :initform 1.0d0 :accessor air-time)
   (buffer :initform NIL :accessor buffer)
   (chunk :initform NIL :accessor chunk))
  (:default-initargs
   :name 'player
   :sprite-data (asset 'leaf 'player)))

(defmethod initialize-instance :after ((player player) &key)
  (setf (spawn-location player) (vcopy (location player))))

(defmethod resize ((player player) w h))

(defmethod capable-p ((player player) (edge jump-edge)) T)
(defmethod capable-p ((player player) (edge crawl-edge)) T)
(defmethod capable-p ((player player) (edge climb-edge)) T)

(defmethod movement-speed ((player player))
  (case (state player)
    (:crawling 1.0)
    (T 1.9)))

(defmethod handle ((ev interact) (player player))
  (typecase (interactable player)
    (null)
    (door
     (setf (animation (interactable player)) 'open)
     (let ((location (location (target (interactable player)))))
       (transition
         (setf (animation (target (interactable player))) 'open)
         (vsetf (location player) (vx location) (- (vy location) 8))
         (snap-to-target (unit :camera T) player))))
    (T
     (issue +world+ 'interaction :with (interactable player)))))

(defmethod handle ((ev start-dash) (player player))
  (let ((vel (velocity player)))
    (cond ((in-danger-p player)
           ;; FIXME: If we are holding the opposite of what
           ;;        we are facing, we should evade left.
           ;;        to do this, need to buffer for a while.
           (start-animation 'evade-right player))
          ((and (= 0 (dash-time player))
                (eq :normal (state player)))
           (if (typep (trial::source-event ev) 'gamepad-event)
               (let ((dev (device (trial::source-event ev))))
                 (vsetf vel
                        (absinvclamp 0.3 (gamepad:axis :l-h dev) 0.5)
                        (absinvclamp 0.3 (gamepad:axis :l-v dev) 0.5)))
               (vsetf vel
                      (cond ((retained 'movement :left)  -0.5)
                            ((retained 'movement :right) +0.5)
                            (T                            0))
                      (cond ((retained 'movement :up)    +0.5)
                            ((retained 'movement :down)  -0.5)
                            (T                            0))))
           (setf (state player) :dashing)
           (setf (animation player) 'dash)
           (when (v= 0 vel) (setf (vx vel) (direction player)))
           (nvunit vel))
          ((eq :animated (state player))
           (setf (buffer player) 'dash)))))

(defmethod handle ((ev start-jump) (player player))
  (cond ((eql :animated (state player))
         (setf (buffer player) 'jump))
        ((not (eql :crawling (state player)))
         (setf (jump-time player) (- (p! coyote-time))))))

(defmethod handle ((ev crawl) (player player))
  (unless (svref (collisions player) 0)
    (case (state player)
      (:normal (setf (state player) :crawling))
      (:crawling (setf (state player) :normal)))))

(defmethod handle ((ev light-attack) (player player))
  (cond ((and (aref (collisions player) 2)
              (not (or (eql :crawling (state player))
                       (eql :animated (state player)))))
         (start-animation 'light-ground-1 player))
        ((eql :animated (state player))
          (setf (buffer player) 'light-attack))))

(defmethod handle ((ev heavy-attack) (player player))
  (cond ((and (aref (collisions player) 2)
              (not (or (eql :crawling (state player))
                       (eql :animated (state player)))))
         (start-animation 'heavy-ground-1 player))
        ((eql :animated (state player))
          (setf (buffer player) 'heavy-attack))))

(flet ((handle-solid (player hit)
         (when (and (= +1 (vy (hit-normal hit)))
                    (< (vy (velocity player)) -5))
           (when (< 0.5 (air-time player))
             (shake-camera :duration 20 :intensity (* 3 (/ (abs (vy (velocity player))) (vy (p! velocity-limit)))))))
         (when (<= 0 (vy (hit-normal hit)))
           (setf (air-time player) 0.0d0))
         (when (and (< 0 (vy (hit-normal hit)))
                    (not (eql :dashing (state player))))
           (setf (dash-time player) 0.0))))
  (defmethod collide :before ((player player) (block block) hit)
    (unless (typep block 'spike)
      (handle-solid player hit)))

  (defmethod collide :before ((player player) (solid solid) hit)
    (handle-solid player hit)))

(defmethod collide ((player player) (trigger trigger) hit)
  (when (active-p trigger)
    (fire trigger)))

(defmethod (setf state) :before (state (player player))
  (unless (eq state (state player))
    (case state
      (:crawling
       (setf (vy (bsize player)) (/ (vy (bsize player)) 2))
       (decf (vy (location player)) (vy (bsize player))))
      (:climbing
       (setf (direction player) (if (svref (collisions player) 1) +1 -1))))
    (case (state player)
      (:crawling
       (incf (vy (location player)) (vy (bsize player)))
       (setf (vy (bsize player)) (* (vy (bsize player)) 2))))))

(defmethod handle :before ((ev tick) (player player))
  (when (path player)
    (return-from handle))
  (let ((collisions (collisions player))
        (dt (* 100 (dt ev)))
        (loc (location player))
        (vel (velocity player))
        (size (bsize player))
        (ground-limit (if (< (p! run-time) (run-time player))
                          (p! run-limit)
                          (p! walk-limit)))
        (ground-acc (if (< (p! run-time) (run-time player))
                        (p! run-acc)
                        (p! walk-acc))))
    (when (< (abs (vx vel)) (/ (p! walk-limit) 2))
      (setf (run-time player) 0.0d0))
    (incf (run-time player) (dt ev))
    (setf (interactable player) NIL)
    (ecase (state player)
      ((:dying :animated :stunned)
       (let ((buffer (buffer player)))
         (when (and buffer (cancelable-p (frame player)))
           (case buffer
             (light-attack
              (case (name (animation player))
                (light-ground-1 (start-animation 'light-ground-2 player))
                (light-ground-2 (start-animation 'light-ground-3 player))
                (T (start-animation 'light-ground-1 player))))
             (heavy-attack
              (case (name (animation player))
                (heavy-ground-1 (start-animation 'heavy-ground-2 player))
                (T (start-animation 'heavy-ground-1 player))))
             (dash (handle (make-instance 'dash) player))
             (jump (handle (make-instance 'start-jump) player)))
           (setf (buffer player) NIL)))
       (handle-animation-states player ev)
       (when (svref collisions 2)
         (setf (vy vel) (max (vy vel) 0)))
       (nv+ vel (v* +vgrav+ dt)))
      (:dashing
       (incf (dash-time player) (dt ev))
       (enter (make-instance 'particle :location (nv+ (vrand -7 +7) (location player)))
              +world+)
       (setf (jump-time player) 100.0)
       (setf (run-time player) 100.0)
       (cond ((or (< (p! dash-max-time) (dash-time player))
                  (and (< (p! dash-min-time) (dash-time player))
                       (not (retained 'movement :dash))))
              (setf (state player) :normal))
             ((< (p! dash-dcc-end) (dash-time player)))
             ((< (p! dash-dcc-start) (dash-time player))
              (nv* vel (damp* (p! dash-dcc) dt)))
             ((< (p! dash-acc-start) (dash-time player))
              (nv* vel (p! dash-acc))))
       ;; Adapt velocity if we are on sloped terrain
       ;; I'm not sure why this is necessary, but it is.
       (typecase (svref collisions 2)
         (slope
          (let* ((block (svref collisions 2))
                 (normal (nvunit (vec2 (- (vy2 (slope-l block)) (vy2 (slope-r block)))
                                       (- (vx2 (slope-r block)) (vx2 (slope-l block))))))
                 (slope (vec (- (vy normal)) (vx normal)))
                 (proj (v* slope (v. slope vel))))
            (vsetf vel (vx proj) (vy proj))))
         (null
          (nv* vel (damp* (p! dash-air-dcc) dt)))))
      (:climbing
       ;; Movement
       (let* ((top (if (= -1 (direction player))
                       (scan-collision +world+ (vec (- (vx loc) (vx size) 2) (- (vy loc) (vy size) 2)))
                       (scan-collision +world+ (vec (+ (vx loc) (vx size) 2) (- (vy loc) (vy size) 2)))))
              (attached (or (svref collisions (if (< 0 (direction player)) 1 3))
                            top)))
         (unless (and (retained 'movement :climb) attached)
           (setf (state player) :normal))
         (cond ((retained 'movement :jump)
                (setf (state player) :normal))
               ((null (svref collisions (if (< 0 (direction player)) 1 3)))
                (setf (vy vel) (p! climb-up))
                (setf (vx vel) (* (direction player) (p! climb-up))))
               ((retained 'movement :up)
                (if (< (vy vel) (p! climb-up))
                    (setf (vy vel) (p! climb-up))
                    (decf (vy vel) 0.1)))
               ((retained 'movement :down)
                (setf (vy vel) (* (p! climb-down) -1)))
               (T
                (setf (vy vel) 0)))))
      (:crawling
       ;; Uncrawl on ground loss
       (when (and (not (svref collisions 2))
                  (not (svref collisions 0)))
         (setf (state player) :normal))
       
       (cond ((retained 'movement :left)
              (setf (vx vel) (- (p! crawl))))
             ((retained 'movement :right)
              (setf (vx vel) (+ (p! crawl))))
             (T
              (setf (vx vel) 0))))
      (:normal
       (for:for ((entity over (region +world+)))
         (when (and (typep entity 'interactable)
                    (contained-p entity player))
           (setf (interactable player) entity)))
       ;; Handle jumps
       (when (< (jump-time player) 0.0d0)
         (cond ((or (svref collisions 1)
                    (svref collisions 3))
                ;; Wall jump
                (let ((dir (if (svref collisions 1) -1.0 1.0))
                      (mov-dir (cond ((retained 'movement :left) -1)
                                     ((retained 'movement :right) +1)
                                     (T 0))))
                  (setf (vy vel) (vy (p! walljump-acc)))
                  (if (or (= dir mov-dir)
                          (not (retained 'movement :climb)))
                      (setf (vx vel) (* dir (vx (p! walljump-acc))))
                      (incf (vy vel) 0.3))
                  (setf (direction player) dir)
                  (setf (jump-time player) 0.0d0)))
               ((< (air-time player) (p! coyote-time))
                ;; Ground jump
                (setf (vy vel) (+ (p! jump-acc)
                                  (if (svref collisions 2)
                                      (* 0.25 (max 0 (vy (velocity (svref collisions 2)))))
                                      0)))
                (setf (jump-time player) 0.0d0))))
       
       ;; Test for climbing
       (when (and (retained 'movement :climb)
                  (not (retained 'movement :jump))
                  (or (typep (svref collisions 1) '(or ground solid))
                      (typep (svref collisions 3) '(or ground solid))))
         (setf (state player) :climbing))

       ;; Movement
       (cond ((svref collisions 2)
              (incf (vy vel) (min 0 (vy (velocity (svref collisions 2)))))
              (cond ((retained 'movement :left)
                     (setf (direction player) -1)
                     ;; Quick turns on the ground.
                     (when (< 0 (vx vel))
                       (setf (vx vel) 0))
                     (if (< (- ground-limit) (vx vel))
                         (decf (vx vel) ground-acc)
                         (setf (vx vel) (- ground-limit))))
                    ((retained 'movement :right)
                     (setf (direction player) +1)
                     ;; Quick turns on the ground.
                     (when (< (vx vel) 0)
                       (setf (vx vel) 0))
                     (if (< (vx vel) ground-limit)
                         (incf (vx vel) ground-acc)
                         (setf (vx vel) ground-limit)))
                    (T
                     (setf (vx vel) 0)))
              (when (typep (svref collisions 2) 'slope)
                (let ((incline (- (vy (slope-l (svref collisions 2)))
                                  (vy (slope-r (svref collisions 2))))))
                  (when (= (signum (vx vel)) (signum incline))
                    (decf (vy vel) (/ (abs incline) 8))))))
             ((retained 'movement :left)
              (setf (direction player) -1)
              (when (< (- ground-limit) (vx vel))
                (decf (vx vel) (p! air-acc))))
             ((retained 'movement :right)
              (setf (direction player) +1)
              (when (< (vx vel) ground-limit)
                (incf (vx vel) (p! air-acc)))))
       ;; Air friction
       (unless (svref collisions 2)
         (setf (vx vel) (* (vx vel) (damp* (p! air-dcc) dt))))
       ;; Jump progress
       (when (and (retained 'movement :jump)
                  (<= 0.05 (jump-time player) 0.15))
         (setf (vy vel) (* (vy vel) (damp* (p! jump-mult) dt))))
       (nv+ vel (v* +vgrav+ dt))
       ;; Limit when sliding down wall
       (when (and (or (typep (svref collisions 1) 'ground)
                      (typep (svref collisions 3) 'ground))
                  (< (vy vel) (p! slide-limit)))
         (setf (vy vel) (p! slide-limit)))))
    (nvclamp (v- (p! velocity-limit)) vel (p! velocity-limit))
    (nv+ (frame-velocity player) vel)))

(defmethod handle :after ((ev tick) (player player))
  (incf (jump-time player) (dt ev))
  (incf (air-time player) (dt ev))
  ;; OOB
  (unless (contained-p (location player) (chunk player))
    (let ((other (find-containing player (region +world+))))
      (cond (other
             (issue +world+ 'switch-chunk :chunk other))
            ((< (vy (location player))
                (- (vy (location (chunk player)))
                   (vy (bsize (chunk player)))))
             (kill player))
            (T
             (setf (vx (location player)) (clamp (- (vx (location (chunk player)))
                                                    (vx (bsize (chunk player))))
                                                 (vx (location player))
                                                 (+ (vx (location (chunk player)))
                                                    (vx (bsize (chunk player))))))))))
  ;; Animations
  (let ((vel (velocity player))
        (collisions (collisions player)))
    (setf (playback-direction player) +1)
    (setf (playback-speed player) 1.0)
    (case (state player)
      (:climbing
       (setf (animation player) 'climb)
       (cond
         ((< (vy vel) 0)
          (setf (playback-direction player) -1)
          (setf (playback-speed player) 1.5))
         ((= 0 (vy vel))
          (setf (clock player) 0.0d0))))
      (:crawling
       (cond ((< 0 (vx vel))
              (setf (direction player) +1))
             ((< (vx vel) 0)
              (setf (direction player) -1)))
       (setf (animation player) 'crawl)
       (when (= 0 (vx vel))
         (setf (clock player) 0.0d0)))
      (:normal
       (cond ((< 0 (vx vel))
              (setf (direction player) +1))
             ((< (vx vel) 0)
              (setf (direction player) -1)))
       (cond ((< 0 (vy vel))
              (setf (animation player) 'jump))
             ((null (svref collisions 2))
              (cond ((typep (svref collisions 1) 'ground)
                     (setf (animation player) 'slide)
                     (setf (direction player) +1))
                    ((typep (svref collisions 3) 'ground)
                     (setf (animation player) 'slide)
                     (setf (direction player) -1))
                    (T
                     (setf (animation player) 'fall))))
             ((< 0 (abs (vx vel)))
              (setf (playback-speed player) (/ (abs (vx vel)) (p! walk-limit)))
              (setf (animation player) 'run))
             (T
              (setf (animation player) 'stand)))))))

(defmethod handle ((ev switch-region) (player player))
  (let* ((region (slot-value ev 'region))
         (other (find-containing player (region +world+))))
    (unless other
      (warn "Player is somehow outside all chunks, picking first chunk we can get.")
      (setf other (for:for ((entity over region))
                    (when (typep entity 'chunk) (return entity))))
      (unless other
        (error "What the fuck? Could not find any chunks.")))
    (snap-to-target (unit :camera T) player)
    (issue +world+ 'switch-chunk :chunk other)))

(defmethod handle ((ev switch-chunk) (player player))
  (let ((loc (vcopy (location player))))
    (when (v/= 0 (velocity player))
      (nv+ loc (v* (vunit (velocity player)) +tile-size+)))
    (setf (chunk player) (chunk ev))
    (setf (spawn-location player) loc)))

(defmethod die ((player player))
  (transition
    (vsetf (velocity player) 0 0)
    (vsetf (location player)
           (vx (spawn-location player))
           (vy (spawn-location player)))
    (setf (state player) :normal)
    (snap-to-target (unit :camera T) player)))

(defun player-screen-y ()
  (* (- (vy (location (unit 'player T))) (vy (location (unit :camera T))))
     (view-scale (unit :camera T))))
