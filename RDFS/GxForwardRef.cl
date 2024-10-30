;;;-*- Mode: common-lisp; syntax: common-lisp; package: gx; base: 10 -*-
;;;
;;; Forward reference module 
;;;
;;; Copyright (c) 2007 Seiji Koide
;;; Copyright (c) 2016-2017 Chun Tian (University of Bologna, Italy)
;;;

(eval-when (:execute :load-toplevel :compile-toplevel)
  (require :gxtype)
  (require :rdfsobjects)
  (require :domainrange)
  (require :rdfskernel)
  ) ; end of eval-when

(in-package :gx)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; If you intend to make conventional CLOS slots that do not obey RDF semantics, you may make 
;; them before loading SWCLOS in the conventional CLOS environment. For exmaple, if you want 
;; to make housekeeping slots that is implicit in RDF, firstly you may define the classes and 
;; housekeeping slots before loading SWCLOS, then load SWCLOS and your ontologies. 
;; SWCLOS only adds knowledge of ontologies monotonically to classes that hold the same 
;; class-names as concepts in ontologies. Or, you may add any conventional CLOS slots 
;; designating slot-name by keyword, after loading SWCLOS. 

(without-package-locks
    #|
(defmethod change-class :after ((instance standard-object) (new-class rdfs:|Resource|) &rest initargs)
  (declare (ignore initargs))
  ;(format t "~%CHANGE-CLASS:AFTER standard-object ~S to rdfs:Resource ~S" instance new-class)
  (let ((name (slot-value instance 'name)))
    (when (and name (or (not (boundp name)) (null (symbol-value name))))
      (export-as-QName name)
      (setf (symbol-value name) instance))))
|#
(defmethod ensure-class-using-class :after ((class forward-referenced-class) name
                                                &rest args)
  ;; the class has become an instance of designated metaclass but this code is invoked 
  ;; if the original class was forward-referenced-class.
  (declare (ignore args))
  (when (and (%clos-subtype-p class |rdfs|:|Class|) name 
             (or (not (boundp name)) (null (symbol-value name))))
    (export-as-QName name)
    (setf (symbol-value name) class)))
)
#|
(without-package-locks
(defmethod finalize-inheritance :before ((class |rdfs|:|Class|))
  (let* ((classes (collect-superclasses* class))
         (forward-referenced-classes
          (remove-if-not #'excl::forward-referenced-class-p classes)))
    (loop for fclass in forward-referenced-classes
        do (change-class fclass |rdfs|:|Class|))
    ))
(defmethod finalize-inheritance :before ((class forward-referenced-class))
  (change-class class |rdfs|:|Class|))
)
|#
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;; Finalize Inheritance for Partial Order Inconsistency in CPL
;;

(defmethod finalize-inheritance ((class |rdfs|:|Class|))
  (let* ((oldsupers (class-direct-superclasses class))
         (newsupers (if (> (length oldsupers) 1)
                        (most-specific-concepts-by-superclasses oldsupers)
                      oldsupers)))
    (dolist (del (set-difference oldsupers newsupers))
      ;; keep the partial order in list
      #+allegro
      (setf (slot-value class 'excl::direct-superclasses)
        (remove del (slot-value class 'excl::direct-superclasses)))
      #-allegro
      (setf (class-direct-superclasses class)
	    (remove del (class-direct-superclasses class)))
      (remove-direct-subclass del class))
    (check-superclasses-order class)
    (call-next-method)))

(defun check-superclasses-order (self)
  (declare (optimize (speed 3) (safety 0)))
  (declare (ignore self))
  #+never
  (let* ((cpl-orderings
          (remove-duplicates (mappend #'local-precedence-ordering
                                      (collect-superclasses* self))
                             :test #'equal))
         (inconsistents
          (intersection cpl-orderings cpl-orderings
                        :test #'(lambda (x y)
                                  (and (not (eq x y))
                                       (or (and (%clos-subtype-p (cadr x) (car y))
                                                (%clos-subtype-p (cadr y) (car x)))
                                           (and (%clos-subtype-p (cadr y) (car x))
                                                (%clos-subtype-p (cadr x) (car y))))
                                       (or (format t "~%Insconsistent pair:~S ~S" x y)
                                           t))))))
    (when inconsistents
      (format t "~%Inconsistents:~S" inconsistents)
      (repair-inconsistent-ordering inconsistents self))))

(defun repair-inconsistent-ordering (inconsistents self)
  (flet ((swap (x y lst) 
               (substitute y :seiji (substitute x y (substitute :seiji x lst)))))
    (labels ((walk-supers-to-repair (inconsistent super)
               (cond ((eql self |rdfs|:|Resource|) nil)
                     ((eql self |rdfs:Resource|) nil)
                     ((member (cadr inconsistent)
                                 (member (car inconsistent)
                                            (class-direct-superclasses super)))
		      
                      (setf #+allegro (slot-value super 'excl::direct-superclasses)
			    #-allegro (class-direct-superclasses super)
			    (swap (car inconsistent) (cadr inconsistent) 
				  (class-direct-superclasses super)))
                      (when (class-finalized-p super)
                        (finalize-inheritance super))
                      (format t "~%Repaired ~S at ~S" inconsistent super)
                      t)
                     (t (loop with rslt = nil
			      for sup in (class-direct-superclasses super)
                            when (walk-supers-to-repair inconsistent sup)
                            do (setq rslt t)
                            finally (return rslt))))))
      (let ((to-be-repaired inconsistents))
        (loop while to-be-repaired
            do
              (let ((repairing (car to-be-repaired)))
                (when (member (cadr repairing)
                                 (member (car repairing)
                                            (class-direct-superclasses self)))
                  (setf #+allegro (slot-value self 'excl::direct-superclasses)
			#-allegro (class-direct-superclasses self)
                    (swap (car repairing) (cadr repairing)
                          (class-direct-superclasses self))))
                (loop with found = nil
		      for super in (class-direct-superclasses self)
                    when (walk-supers-to-repair repairing super)
                    do (setq found t)
                    finally (if found
                                (setq to-be-repaired
                                      (remove repairing (cdr to-be-repaired)
                                              :test #'(lambda (x y)
                                                        (and (not (eq x y))
                                                             (or (and (%clos-subtype-p (cadr x)
                                                                                       (car y))
                                                                      (%clos-subtype-p (cadr y)
                                                                                       (car x)))
                                                                 (and (%clos-subtype-p (cadr y)
                                                                                       (car x))
                                                                      (%clos-subtype-p (cadr x)
                                                                                       (car y))
                                                                      )
                                                                 )
                                                             ))))
                              (error "Not Found Inconsistent Source!")))))))))

(defun owl-restriction-p (obj)
  (declare (ignore obj))
  nil)

(defun owl-class-p (obj)
  (declare (ignore obj))
  nil)

(defun subsumed-p-without-equivalency (c1 c2)
  (declare (ignore c1 c2))
  nil)

;;......................................................................................
;; from Kiczales "The Art of the Metaobject Protocol"
#+never
(defmethod class-precedence-list ((root |rdfs|:|Class|))
  (std-compute-class-precedence-list root))

(defun std-compute-class-precedence-list (class)
  (let ((classes-to-order (collect-superclasses* class)))
    (topological-sort classes-to-order
                      (remove-duplicates
                       (mappend #'local-precedence-ordering
                                classes-to-order))
                      #'std-tie-breaker-rule)))

(defun collect-superclasses* (class)
  (labels ((all-superclasses-loop (seen superclasses)
             (let ((to-be-processed
                    (set-difference superclasses seen)))
               (if (null to-be-processed) superclasses
                 (let ((class-to-process (car to-be-processed)))
                   (all-superclasses-loop
                    (cons class-to-process seen)
                    (union (class-direct-superclasses class-to-process)
                           superclasses)))))))
    (all-superclasses-loop () (list class))))

(defun local-precedence-ordering (class)
  (mapcar #'list
    (cons class
          (butlast (class-direct-superclasses class)))
    (class-direct-superclasses class)))

(defun topological-sort (elements constraints tie-breaker)
  (let ((remaining-constraints constraints)
        (remaining-elements elements)
        (result ()))
    (loop
      (let ((minimal-elements
             (remove-if #'(lambda (class)
                            (member class remaining-constraints :key #'cadr))
                        remaining-elements)))
        (when (null minimal-elements)
          (if (null remaining-elements) (return-from topological-sort result)
            (error "Inconsistent precedence graph:~S" remaining-elements)))
        (let ((choice (if (null (cdr minimal-elements)) (car minimal-elements)
                        (funcall tie-breaker
                                 minimal-elements
                                 result))))
          (setq result (append result (list choice)))
          (setq remaining-elements
                (remove choice remaining-elements))
          (setq remaining-constraints
                (remove choice remaining-constraints :test #'member)))))))

(defun std-tie-breaker-rule (minimal-elements cpl-so-far)
  (dolist (cpl-constituent (reverse cpl-so-far))
    (let* ((supers (class-direct-superclasses cpl-constituent))
           (common (intersection minimal-elements supers)))
      (when (not (null common))
        (return-from std-tie-breaker-rule (car common))))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;;
;;

(defvar *reify-p* nil
  "when this flag is true, every statement is reified and strored in system.")

(defun book-keeping-for-reification (instance slot-names &rest initargs)
  (when *reify-p*
    (cond ((null slot-names) 
           (loop for (role filler) on initargs by #'cddr
               when (and (property? role) (setq filler (getf initargs role)))
               do (reify instance (symbol-value role) filler)))
          ((consp slot-names)
           (loop with filler
		 for role in slot-names
               when (and (property? role) (setq filler (getf initargs role)))
               do (reify instance (symbol-value role) filler)))
          ((eq slot-names t)
           (loop for (role filler) on initargs by #'cddr
               when (property? role)
               do (reify instance (symbol-value role) filler)))
          ((error "Cant happen!")))))

(defun reify (subject predicate object)
  (when (not (c2cl:typep subject |rdf|:|Statement|))
    (unless (loop for stat in (class-direct-instances |rdf|:|Statement|)
                thereis (and (rdf-equalp subject (slot-value stat '|rdf|:|subject|))
                             (rdf-equalp predicate (slot-value stat '|rdf|:|predicate|))
                             (rdf-equalp object (slot-value stat '|rdf|:|object|))))
      ;(format t "~%Making statement:~S ~S ~S" subject predicate object)
      (make-instance '|rdf|:|Statement| :subject subject :predicate predicate :object object))))

(defmethod shared-initialize :after ((instance |rdfs|:|Resource|) slot-names &rest initargs)
  "book-keeping for reification seiji"
  (cond ((and (null slot-names) (null initargs))  ; when change-class
         )
        ((and (consp slot-names) (null initargs)) ; when propagated
         )
        (t                                        ; first or redefinition
         (typecase instance
           (|rdfs|:|Literal| nil)
           (|rdfs|:|Datatype| nil)
           (|rdf|:|Statement| nil)
           (|rdf|:|List| nil)
           (otherwise 
            (apply #'book-keeping-for-reification instance slot-names initargs)
            )))))

;; End of module
;; --------------------------------------------------------------------

(provide :gxforwardref)
