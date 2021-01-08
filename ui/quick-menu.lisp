(in-package #:org.shirakumo.fraf.kandria)

(defclass item-header (alloy:label*)
  ((alloy:value :initform (language-string 'items-menu))))

(presentations:define-realization (ui item-header)
  ((:bg simple:rectangle)
   (alloy:margins)
   :pattern (colored:color 0.15 0.15 0.15))
  ((:label simple:text)
   (alloy:margins 10)
   alloy:text
   :valign :middle
   :halign :middle
   :font "PromptFont"
   :size (alloy:un 15)
   :pattern colors:white))

(defclass item-list (alloy:vertical-linear-layout alloy:focus-list alloy:renderable)
  ((alloy:min-size :initform (alloy:size 300 40))
   (alloy:cell-margins :initform (alloy:margins))))

(presentations:define-realization (ui item-list)
  ((:bg simple:rectangle)
   (alloy:margins)
   :pattern (colored:color 0.1 0.1 0.1)))

(defmethod alloy:exit ((list item-list))
  (toggle-panel 'quick-menu))

(defclass item-button (alloy:direct-value-component alloy:button)
  ((inventory :initarg :inventory :accessor inventory)))

(presentations:define-realization (ui item-button)
  ((:background simple:rectangle)
   (alloy:margins))
  ((:label simple:text)
   (alloy:margins 10)
   alloy:text
   :valign :middle
   :halign :start
   :font "PromptFont"
   :size (alloy:un 15)
   :pattern colors:white))

(presentations:define-update (ui item-button)
  (:background
   :pattern (if alloy:focus colors:white colors:black))
  (:label
   :pattern (if alloy:focus colors:black colors:white)))

(defmethod alloy:text ((button item-button))
  (format NIL "~2d ~a"
          (item-count (alloy:value button) (inventory button))
          (language-string (alloy:value button))))

(defmethod alloy:activate ((button item-button))
  (use (alloy:value button) (inventory button))
  (when (= 0 (item-count (alloy:value button) (inventory button)))
    (setf (alloy:focus (alloy:focus-parent button)) :strong)
    (alloy:leave button (alloy:layout-parent button))
    (when (= 0 (item-count T (inventory button)))
      (toggle-panel 'quick-menu))))

(defclass quick-menu (menuing-panel)
  ())

(defmethod show :after ((panel quick-menu) &key)
  (setf (time-scale +world+) 0.05))

(defmethod hide :after ((panel quick-menu))
  (setf (time-scale +world+) 1.0))

(defmethod initialize-instance :after ((panel quick-menu) &key (inventory (unit 'player T)))
  (let ((layout (make-instance 'org.shirakumo.alloy.layouts.constraint:layout))
        (scroll (make-instance 'alloy:clip-view :limit :x))
        (list (make-instance 'item-list))
        (label (make-instance 'item-header)))
    (dolist (item (list-items inventory))
      (make-instance 'item-button :value item :inventory inventory
                                  :focus-parent list :layout-parent list))
    (alloy:enter list scroll)
    (alloy:enter scroll layout :constraints `((:left 0) (:bottom 0) (:width 300) (:height 400)))
    (alloy:enter label layout :constraints `((:left 0) (:above ,scroll 0) (:width 300) (:height 30)))
    (alloy:finish-structure panel layout list)))
