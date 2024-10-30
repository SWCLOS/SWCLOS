;;;-*- Mode: common-lisp; syntax: common-lisp; package: gx; base: 10 -*-
;;;
;;; RDF Node module
;;;

(in-package :gx)

(eval-when (:compile-toplevel :load-toplevel :execute)
  (export '(node-name mclasses)))

(defclass gnode ()
  ((name :initarg :name :initform nil)
   (iri :initarg :iri :initform nil :accessor iri)
   (type-tag :initform nil :accessor type-tag))
  (:metaclass rdf-node)
  (:documentation "This class provides the concept of RDF graph."))

(defgeneric mclasses (instance)
  (:documentation "returns multiple classes of instance"))

(defmethod mclasses ((instance gnode))
  "returns multiple classes of <gnode>. This function returns length=1 list for single class."
  (labels ((get-bright-supers (super)
                              (cond ((not (shadowed-class-p super)) (list super))
                                    (t (mapcan #'get-bright-supers (class-direct-superclasses super))))))
    (let ((class (class-of instance)))
      (cond ((shadowed-class-p class)
             (remove-duplicates (mapcan #'get-bright-supers (class-direct-superclasses class))))
            (t (list class))))))

;;; An element of direct-instances slot are initially stored by <make-instance(rdf-node)> method 
;;; and maintained by <update-instance-for-different-class:after(gnode)> which is invoked by 
;;; change-class.

(defmethod make-instance ((class rdf-node) &rest initargs)
  (declare (ignore initargs))
  (let ((instance (call-next-method)))
    (push instance (class-direct-instances class))
    instance))

(defun shadowed-class-p (x)
  "returns true if <x> is an instance of shadowed class.
   shadowed-class is defined at RdfsObjects file."
  (eq (class-name (class-of x)) 'shadowed-class))

(defmethod update-instance-for-different-class :after ((previous gnode) current &rest initargs)
  (declare (ignore initargs))
  (cond ((c2cl:typep current 'destroyed-class)
         (let ((old-class (class-of previous)))
           (setf (class-direct-instances old-class)
             (remove current (class-direct-instances old-class) :test #'eq))
           ))
        (t (let ((old-class (class-of previous))
                 (new-class (class-of current)))
             ;; domain constraint should be satisfied, if old-class was satisfied.
             ;; class direct instances handling
             (setf (class-direct-instances old-class)
               (remove current (class-direct-instances old-class) :test #'eq))
             (push current (class-direct-instances new-class))
             ))))

(defun node-p (x)
  (c2cl:typep x 'gnode))

(defun bnode-p (node)
  (or (not (slot-value node 'name))
      (not (symbol-package (slot-value node 'name)))))

(defgeneric ground? (node))

(defmethod ground? ((node gnode))
  (and (slot-value node 'name)
       (symbol-package (slot-value node 'name))))

(defgeneric node-name (node))

(defmethod node-name ((node symbol))
  node)

(defmethod node-name ((node gnode))
  "returns a QName or a nodeID of <node>, if it exists. Otherwise nil."
  (let ((name (slot-value node 'name)))
    (when (and name (symbol-package name)) name))) ; name might have uninterned symbol.

(defgeneric (setf node-name) (new-value node))

(defmethod (setf node-name) (symbol (node gnode))
  "exports <symbol> for QName."
  (setf (slot-value node 'name) symbol)
  (export-as-QName symbol)
  (setf (symbol-value symbol) node))

;; TODO
(defmethod shared-initialize :after ((instance gnode) slot-names &rest initargs)
  (cond ((and (null slot-names) (null initargs))  ; when change-class
         )
        ((and (consp slot-names) (null initargs)) ; when propagated
         )
        (t                                        ; first or redefinition
         (let ((name (getf initargs :name)))
           (when name
             (when (nodeID? name)
               (setf (slot-value instance 'name) nil))
             (export-as-QName name)
             (setf (symbol-value name) instance))))))


;;;
;;;; NodeID
;;;
;;; A nodeID is an exorted symbol in package "_".  See the following example.
;;; ----------------------------------------------------------------------------------
;;; (nodeID2symbol "abc")      -> _:abc
;;; (make-unique-nodeID "abc") -> _:abc0
;;; ----------------------------------------------------------------------------------
(defun nodeID? (name)
  "Is this <name> a nodeID?"
  (and (symbol-package name)
       (string= "_" (package-name (symbol-package name)))))

(defun nodeID2symbol (str)
  "simply transforms <str> to a exported symbol in anonymous node package :_
   and returns it."
  (let ((nodeID (intern str :_)))
    (export nodeID (find-package :_))
    nodeID))

(defun make-unique-nodeID (str)
  (declare (optimize (speed 3) (safety 1)))
  "makes a unique node ID from <str>. Namely, adds numbers at the end of <str> and makes unique symbol."
  (let ((symbol (gentemp str :_)))
    (export symbol (find-package :_))
    symbol))

(cl:provide :rdfnode)
