(in-package #:org.shirakumo.fraf.kandria)

(defclass tile-data (compiled-generator multi-resource-asset file-input-asset)
  ((tile-types :initform () :accessor tile-types)))

(defun parse-tile-types (types)
  (labels ((parse-tile-spec (spec)
             (case (first spec)
               (repeat
                (destructuring-bind ((start end) tile) (rest spec)
                  (loop for x from start to end
                        collect (subst x 'x tile))))
               (T (list spec))))
           (parse-type-spec (spec)
             (destructuring-bind (type . parts) spec
               (list* type (reduce #'append parts :key #'parse-tile-spec)))))
    (loop for (name . tiles) in types
          collect (list* name (mapcar #'parse-type-spec tiles)))))

(defmethod compile-resources ((data tile-data) (path pathname) &key force)
  (destructuring-bind (&key source albedo absorption normal &allow-other-keys) (read-src path)
    (let ((source (merge-pathnames source path))
          (albedo (merge-pathnames albedo path))
          (absorption (merge-pathnames absorption path))
          (normal (merge-pathnames normal path)))
      (when (or force (recompile-needed-p (list albedo absorption normal)
                                          (list path source)))
        (v:info :kandria.resources "Compiling tileset from ~a..." source)
        (aseprite source "--layer" "albedo" "--save-as" albedo)
        (aseprite source "--layer" "absorption" "--save-as" absorption)
        (aseprite source "--layer" "normal" "--save-as" normal)))))

(defmethod generate-resources ((data tile-data) (path pathname) &key compile)
  (destructuring-bind (&key source albedo absorption normal tile-types) (read-src path)
    (let ((albedo (merge-pathnames albedo path))
          (absorption (merge-pathnames absorption path))
          (normal (merge-pathnames normal path)))
      (setf (tile-types data) (parse-tile-types tile-types))
      (generate-resources 'image-loader albedo
                          :resource (resource data 'albedo))
      (generate-resources 'image-loader absorption
                          :resource (resource data 'absorption))
      (generate-resources 'image-loader normal
                          :resource (resource data 'normal))
      (list (resource data 'albedo)
            (resource data 'absorption)
            (resource data 'normal)))))

(defmethod resource ((data tile-data) (name (eql T)))
  (resource data 'albedo))

(defmethod notify:files-to-watch append ((asset tile-data))
  (list (merge-pathnames (getf (read-src (input* asset)) :source) (input* asset))))

(defmethod notify:notify :before ((asset tile-data) file)
  (when (string= "ase" (pathname-type file))
    (sleep 1)
    (compile-resources asset T)))
