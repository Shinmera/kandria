(in-package #:org.shirakumo.fraf.kandria)

(defclass trigger (sized-entity resizable ephemeral)
  ((active-p :initarg :active-p :initform T :accessor active-p :type boolean)))

(defmethod interact :around ((trigger trigger) source)
  (when (active-p trigger)
    (call-next-method)))

(defmethod quest:activate ((trigger trigger))
  (setf (active-p trigger) T))

(defmethod quest:deactivate ((trigger trigger))
  (setf (active-p trigger) NIL))

(defclass one-time-trigger (trigger)
  ())

(defmethod interact :after ((trigger one-time-trigger) source)
  (setf (active-p trigger) NIL))

(defclass checkpoint (trigger)
  ())

(defmethod interact ((trigger checkpoint) entity)
  (setf (spawn-location entity)
        (vec (vx (location trigger))
             (+ (- (vy (location trigger))
                   (vy (bsize trigger)))
                (vy (bsize entity))))))

(defclass story-trigger (one-time-trigger)
  ((story-item :initarg :story-item :accessor story-item :type symbol)
   (target-status :initarg :target-status :accessor target-status :type symbol)))

(defmethod interact ((trigger story-trigger) entity)
  (let ((name (story-item trigger)))
    (flet ((finish (thing)
             (ecase (target-status trigger)
               (:active (quest:activate thing))
               (:inactive (quest:deactivate thing))
               (:complete (quest:complete thing)))
             (return-from interact)))
      (loop for quest in (quest:known-quests (storyline +world+))
            do (loop for task in (quest:active-tasks quest)
                     do (loop for trigger in (quest:triggers task)
                              do (when (eql name (quest:name trigger))
                                   (finish trigger)))
                        (when (eql name (quest:name task))
                          (finish task)))
               (when (eql name (quest:name quest))
                 (finish quest)))
      (v:warn :kandria.quest "Could not find active story-item named ~s when firing trigger ~s"
              name (name trigger)))))

(defclass interaction-trigger (one-time-trigger)
  ((interaction :initarg :interaction :initform NIL :accessor interaction :type symbol)))

(defmethod interact ((trigger interaction-trigger) entity)
  (when (typep entity 'player)
    (show (make-instance 'dialog :interactions (list (quest:find-trigger (interaction trigger) +world+))))))

(defclass walkntalk-trigger (one-time-trigger)
  ((interaction :initarg :interaction :initform NIL :accessor interaction :type symbol)
   (target :initarg :target :initform T :accessor target :type symbol)))

(defmethod interact ((trigger walkntalk-trigger) entity)
  (when (typep (name entity) (target trigger))
    (walk-n-talk (quest:find-trigger (interaction trigger) +world+))))

(defclass tween-trigger (trigger)
  ((left :initarg :left :accessor left :initform 0.0 :type single-float)
   (right :initarg :right :accessor right :initform 1.0 :type single-float)
   (horizontal :initarg :horizontal :accessor horizontal :initform T :type boolean)
   (ease-fun :initarg :easing :accessor ease-fun :initform 'linear :type symbol)))

(defmethod interact ((trigger tween-trigger) (entity located-entity))
  (let* ((x (if (horizontal trigger)
                (+ (/ (- (vx (location entity)) (vx (location trigger)))
                      (* 2.0 (vx (bsize trigger))))
                   0.5)
                (+ (/ (- (vy (location entity)) (vy (location trigger)))
                      (* 2.0 (vy (bsize trigger))))
                   0.5)))
         (v (ease (clamp 0 x 1) (ease-fun trigger) (left trigger) (right trigger))))
    (setf (value trigger) v)))

(defclass sandstorm-trigger (tween-trigger)
  ())

(defmethod (setf value) (value (trigger sandstorm-trigger))
  (setf (strength (unit 'sandstorm T)) value))

(defclass zoom-trigger (tween-trigger)
  ((easing :initform 'quint-in)))

(defmethod (setf value) (value (trigger zoom-trigger))
  (setf (intended-zoom (unit :camera T)) value))

(defclass pan-trigger (tween-trigger)
  ())

(defmethod (setf value) (value (trigger pan-trigger))
  (setf (offset (unit :camera T)) value))

(defclass teleport-trigger (trigger)
  ((target :initform NIL :initarg :target :accessor target)
   (primary :initform T :initarg :primary :accessor primary)))

(defmethod default-tool ((trigger teleport-trigger)) (find-class 'freeform))

(defmethod enter :after ((trigger teleport-trigger) (region region))
  (when (primary trigger)
    (destructuring-bind (&optional (location (vec (+ (vx (location trigger)) (* 2 (vx (bsize trigger))))
                                                  (vy (location trigger))))
                                   (bsize (vcopy (bsize trigger)))) (target trigger)
      (let* ((other (clone trigger :location location :bsize bsize :target trigger :active-p NIL :primary NIL)))
        (setf (target trigger) other)
        (enter other region)))))

(defmethod interact ((trigger teleport-trigger) (entity located-entity))
  (setf (location entity) (target trigger))
  (vsetf (velocity entity) 0 0))

(defclass earthquake-trigger (trigger)
  ((duration :initform 60.0 :initarg :duration :accessor duration)
   (clock :initform 0.0 :accessor clock)))

(defmethod stage :after ((trigger earthquake-trigger) (area staging-area))
  (stage (// 'kandria 'earthquake) area))

(defmethod interact ((trigger earthquake-trigger) (player player))
  (decf (clock trigger) 0.01)
  (let* ((max 7.0)
         (hmax (/ max 2.0)))
    (cond ((<= (clock trigger) (- max))
           (shake-camera :duration 0.0 :intensity 0)
           (setf (clock trigger) (+ (duration trigger) (random 10.0))))
          ((<= (clock trigger) -0.1)
           (let ((intensity (* 10 (- 1 (/ (expt 3 (abs (+ hmax (clock trigger))))
                                          (expt 3 hmax))))))
             (shake-camera :duration 7.0 :intensity intensity :controller-multiplier 0.1)))
          ((<= (clock trigger) 0.0)
           (harmony:play (// 'kandria 'earthquake))))))
;; TODO: make dust fall down over screen.
