;;;-*- Mode: common-lisp; syntax: common-lisp; package: gx; base: 10 -*-
;;;
;;;; GX Type module
;;;
;;; IT Program Project in Japan: 
;;;    Building Operation-Support System for Large-scale System using IT
;;;
;;; This code is written by Seiji Koide at Galaxy Express Corporation, Japan,
;;; for the realization of the MEXT IT Program in Japan.
;;;
;;; Copyright (c) 2002-2005 Galaxy Express Corporation
;;; Copyright (c) 2007-2008, 2009, 2012 Seiji Koide
;;; Copyright (c) 2016-2017 Chun Tian (University of Bologna, Italy)
;;;
;;; ==================================================================================

(eval-when (:execute :load-toplevel :compile-toplevel)
  (require :swclospackages)
  (require :namespace)
  (require :rdfboot)
  ) ; end of eval-when

(in-package :gx)

(eval-when (:compile-toplevel :load-toplevel :execute)
  (export '(rsc-object-p rdf-class-p rdf-metaclass-p strict-class-p rdf-instance-p datatype-p 
	    object? class? metaclass? datatype? resource?
	    rdf-subtypep subsumed-p rdf-equalp value-of 
	    subproperty name
	    collect-all-subs disjoint-p
	    most-specific-concepts
	    *nonUNA* *autoepistemic-local-closed-world*
	    most-abstract-concepts)))

(eval-when (:execute :load-toplevel :compile-toplevel)
  (setf (uri-namedspace-package (set-uri-namedspace (documentation (find-package "xsd") t)))
    (find-package "xsd"))
  (setf (uri-namedspace-package (set-uri-namedspace (documentation (find-package "rdf") t)))
    (find-package "rdf"))
  (setf (uri-namedspace-package (set-uri-namedspace (documentation (find-package "rdfs") t)))
    (find-package "rdfs"))
  )

;;;
;;;; RDF Type Error Condition
;;;
;;; Followings are for type error message.

(define-condition rdf-type-error (type-error)
  ()
  (:report
   (lambda (condition stream)
     (format stream "invalid RDF type")))
  (:documentation
   "rdf-type-error inherits data variables and expected-type variables and 
type-error-datum and type-error-expected-type readers. 
format-control and format-arguments are from simple-condition."))

(define-condition cyclic-super/subclasses-error (rdf-type-error)
  ()
  (:report
   (lambda (condition stream)
     (format stream "acyclic super/sub relation")))
  (:documentation
   "Cyclic super/subclass relation is not supported in CLOS."))

(defmacro rdf-check-type (place type &optional type-string)
  `(loop
     (if (typep ,place ',type)
         (return nil)
       (setf ,place
         (rdf-check-type-1 ',place ,place ',type ,type-string)))))

(defun rdf-check-type-1 (name place type type-string)
  (restart-case
      (.rdf-type-error place type
                       "the value of ~s is ~s, which is not~@[ of type~*~] ~a."
                       name place (null type-string)
                       (if type-string type-string type))
    (store-value (value)
                 :report (lambda (stream)
                           (format stream "supply a new value for ~s." name))
                 :interactive read-evaluated-form
                 (return-from rdf-check-type-1 value))))

(defun .rdf-type-error
    (datum expected-type
           &optional ;; (frames 1) Removed!
           (format
               "~@<`~s' is not of the expected type `~s'~:@>"
               formatp)
           &rest args)
  (error 'rdf-type-error :datum datum :expected-type expected-type
    :format-control format
    :format-arguments
    (if formatp
        args
      (list datum expected-type))))

(defun read-evaluated-form ()
  (format *query-io* "~&Type a form to be evaluated: ")
  (list (eval (read *query-io*))))

(defvar *the-class-t* (find-class t))

(cl:provide :gxtype0)
