(in-package #:org.shirakumo.fraf.leaf)

(defun %flood-fill (layer width height x y fill)
  (let* ((tmp (vec2 0 0)))
    (labels ((pos (x y)
               (* (+ x (* y width)) 2))
             (tile (x y)
               (vsetf tmp
                      (aref layer (+ 0 (pos x y)))
                      (aref layer (+ 1 (pos x y)))))
             ((setf tile) (f x y)
               (setf (aref layer (+ 0 (pos x y))) (truncate (vx f))
                     (aref layer (+ 1 (pos x y))) (truncate (vy f)))))
      (let ((q ()) (find (vec2 (aref layer (+ 0 (pos x y)))
                               (aref layer (+ 1 (pos x y))))))
        (unless (v= fill find)
          (push (cons x y) q)
          (loop while q for (n . y) = (pop q)
                for w = n for e = n
                do (loop until (or (= w 0) (v/= (tile (1- w) y) find))
                         do (decf w))
                   (loop until (or (= e (1- width)) (v/= (tile (1+ e) y) find))
                         do (incf e))
                   (loop for i from w to e
                         do (setf (tile i y) fill)
                            (when (and (< y (1- height)) (v= (tile i (1+ y)) find))
                              (pushnew (cons i (1+ y)) q))
                            (when (and (< 0 y) (v= (tile i (1- y)) find))
                              (pushnew (cons i (1- y)) q)))))))))

(defun find-edge (solids width height x y)
  (labels ((pos (x y)
             (* (+ x (* y width)) 2)))
    (loop with state = :up
          while (= 255 (aref solids (+ 0 (pos x y))))
          do (ecase state
               (:up
                (incf y)
                (when (<= height y)
                  (decf y)
                  (setf state :right)))
               (:right
                (incf x)
                (when (<= width x)
                  (decf x)
                  (setf state :down)))
               (:down
                (decf y)
                (when (< y 0)
                  (incf y)
                  (setf state :left)))
               (:left
                (decf x)
                (when (< x 0)
                  (incf x)
                  (error "There is no edge.")))))
    (values x y)))

(defparameter *tile-filters*
  '((:t
     _ o _
     s s s
     x x x)
    (:b
     x x _
     s s s
     _ o _)
    (:l
     _ s x
     o s i
     _ s x)
    (:r
     x s _
     i s o
     x s _)
    (:tr>
     _ _ o
     s s _
     x s _)
    (:tl>
     o _ _
     _ s s
     _ s x)
    (:br>
     x s _
     s s o
     _ o o)
    (:bl>
     _ s x
     _ s s
     o _ _)
    (:tr<
     x x x
     s s x
     o s x)
    (:tl<
     x x x
     x s s
     x s o)
    (:br<
     o s x
     s s x
     x x x)
    (:bl<
     x s o
     x s s
     x x x)
    (:ct
     o s o
     s s s
     x i x)
    (:ct
     o s o
     s s s
     _ i _)
    (:cb
     _ i _
     s s s
     o s o)
    (:h
     _ o _
     s s s
     _ o _)
    (:v
     _ s _
     o s o
     _ s _)
    (:hl
     _ o _
     o s s
     _ o _)
    (:hr
     _ o _
     s s o
     _ o _)
    (:vt
     _ o _
     o s o
     _ s _)
    (:vb
     _ s _
     o s o
     _ o _)))

(defun filter-edge (solids width height x y)
  (labels ((pos (x y)
             (* (+ x (* y width)) 2))
           (tile (ox oy)
             (let* ((x (+ ox x))
                    (y (+ oy y))
                    (pos (pos x y)))
               (cond ((or (= -1 x) (= -1 y) (= width x) (= height y)) 1)
                     ((or (< x -1) (< y -1) (< width x) (< height y)) 0)
                     (T (aref solids pos))))))
    (loop for (type . filter) in *tile-filters*
          do (when (loop for i from 0 below 9
                         for v in filter
                         for x = (- (mod i 3) 1)
                         for y = (- 1 (floor i 3))
                         for tile = (tile x y)
                         always (case v
                                  (o (= 0 tile))
                                  (s (<= 1 tile 254))
                                  (x (< 0 tile))
                                  (i (= 255 tile))
                                  (_ T)))
               #+(OR)
               (warn "~a at ~3d,~3d:~%~3d ~3d ~3d~%~3d ~3d ~3d~%~3d ~3d ~3d" type x y
                     (tile -1 +1) (tile 0 +1) (tile +1 +1)
                     (tile -1 0) (tile 0 0) (tile +1 0)
                     (tile -1 -1) (tile 0 -1) (tile +1 -1))
               (return type))
          finally (error "Unknown tile configuration at ~3d,~3d:~%~3d ~3d ~3d~%~3d ~3d ~3d~%~3d ~3d ~3d" x y
                         (tile -1 +1) (tile 0 +1) (tile +1 +1)
                         (tile -1 0) (tile 0 0) (tile +1 0)
                         (tile -1 -1) (tile 0 -1) (tile +1 -1)))))

(defun fill-edge (solids tiles width height ox oy map)
  (labels ((pos (x y)
             (* (+ x (* y width)) 2))
           (solid (x y)
             (when (and (<= 0 x (1- width))
                        (<= 0 y (1- height)))
               (aref solids (pos x y))))
           ((setf tile) (f x y)
             (when (and (<= 0 x (1- width))
                        (<= 0 y (1- height)))
               (let ((f (alexandria:random-elt f))
                     (pos (pos x y)))
                 (setf (aref tiles (+ 0 pos)) (first f)
                       (aref tiles (+ 1 pos)) (second f))))))
    (loop with x = ox with y = oy with px = x with py = y
          for i from 0 below 1000
          for edge = (filter-edge solids width height x y)
          for solid = (solid x y)
          for tile = (case solid
                       (2 :platform)
                       (3 :spike)
                       ((4 5) `(:slope 1 ,(- solid 4)))
                       ((6 7 8 9) `(:slope 2 ,(- solid 6)))
                       ((10 11 12 13 14 15) `(:slope 3 ,(- solid 10)))
                       (T edge))
          do (setf (tile x y) (cdr (assoc tile map :test 'equal)))
             (let ((ox x) (oy y))
               (ecase edge
                 (:l (incf y))
                 (:r (decf y))
                 (:t (incf x))
                 (:b (decf x))
                 (:tl> (incf x))
                 (:tr> (decf y))
                 (:br> (decf x))
                 (:bl> (incf y))
                 (:tl< (decf y))
                 (:tr< (decf x))
                 (:br< (incf y))
                 (:bl< (incf x))
                 (:ct (if (= px x)
                          (incf x)
                          (incf y)))
                 (:cb (if (= px x)
                          (decf x)
                          (decf y)))
                 (:cl (if (= py y)
                          (incf y)
                          (decf x)))
                 (:cr (if (= py y)
                          (decf y)
                          (incf x)))
                 (:h (if (< px x)
                         (incf x)
                         (decf x)))
                 (:v (if (< py y)
                         (incf y)
                         (decf y)))
                 (:hl (incf x))
                 (:hr (decf x))
                 (:vt (decf y))
                 (:vb (incf y)))
               (setf px ox py oy))
             (when (and (= x ox) (= y oy))
               (loop-finish))
          collect (vec x y))))

(defun fill-innards (solids tiles edge width height x- x+ y- y+ map)
  (labels ((pos (x y)
             (* (+ x (* y width)) 2))
           (tile (x y)
             (aref solids (+ 0 (pos x y))))
           ((setf tile) (f x y)
             (let ((f (alexandria:random-elt f)))
               (setf (aref tiles (+ 0 (pos x y))) (first f)
                     (aref tiles (+ 1 (pos x y))) (second f)))))
    (loop for y from (max 0 y-) to (min y+ height)
          do (loop for x from (max 0 x-) to (min x+ width)
                   do (when (= 255 (tile x y))
                        (setf (tile x y)
                              (cdr (or (assoc (round (mindist (vec x y) edge)) map)
                                       (assoc T map)))))))))

(defun %auto-tile (solids tiles width height x y map)
  (let ((solids (copy-seq solids)))
    (%flood-fill solids width height x y (vec2 255 0))
    (multiple-value-bind (x y) (find-edge solids width height x y)
      (let* ((edge (fill-edge solids tiles width height x y map))
             (x- (truncate (loop for pos in edge minimize (vx pos))))
             (x+ (truncate (loop for pos in edge maximize (vx pos))))
             (y- (truncate (loop for pos in edge minimize (vy pos))))
             (y+ (truncate (loop for pos in edge maximize (vy pos)))))
        (fill-innards solids tiles edge width height x- x+ y- y+ map)))))
