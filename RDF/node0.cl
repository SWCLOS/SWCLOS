;;;; -*- Mode: common-lisp; syntax: common-lisp; package: gx; base: 10 -*-
;;;
;;; Copyright (c) 2016  University of Bologna, Italy (Author: Chun Tian)
;;;

(in-package :gx)

;;;; gnode & rdf-node
;;; rdf-node will be a superclass of rdfs:Class. 
;;; gnode will be a superclass of rdfs:Resource. 
;;; gnode class is needed for registration of class-instance relation. 

(defclass rdf-node (standard-class)
  ((direct-instances :initarg :direct-instances
                     :initform nil 
                     :accessor class-direct-instances))
  (:documentation "This metaclass is node class. This metaclass provides method class-direct-instances"))

(defmethod validate-superclass ((class rdf-node) (superclass standard-class))
  t)

(cl:provide :rdfnode0)
