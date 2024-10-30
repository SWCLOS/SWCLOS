;;;-*- Mode: common-lisp; syntax: common-lisp; package: gx; base: 10 -*-
;;;
;;; Copyright (c) 2017  Chun Tian (University of Bologna, Italy)

(in-package :gx)

(eval-when (:load-toplevel :execute)
  (export 'load-cyc))

;; > (translate-logical-pathname #p"CYC:opencyc-latest.owlz")
;; #P"/Users/binghe/Lisp/SWCLOS/opencyc/opencyc-latest.owl.gz"
;; > (pathname-type *)
;; "owl.gz"

;; > (pathname-type #P"/Users/binghe/Lisp/SWCLOS/opencyc/opencyc-latest.owl.gz")
;; "gz"

(defpackage "cyc"
  (:use ) ; supressing using common lisp package
  (:documentation "http://sw.cyc.com/concept/#"))

(defpackage "opencyc"
  (:use ) ; supressing using common lisp package
  (:documentation "http://sw.opencyc.org/concept/#"))

;; Package mappings for Cyc and OpenCyc
(eval-when (:execute :load-toplevel)
  (setf (uri-namedspace-package (set-uri-namedspace "http://sw.cyc.com/concept/"))
	(find-package "cyc"))
  (setf (uri-namedspace-package (set-uri-namedspace "http://sw.cyc.com/concept/#"))
	(find-package "cyc"))
  (setf (uri-namedspace-package (set-uri-namedspace "http://sw.opencyc.org/concept/"))
	(find-package "opencyc"))
  (setf (uri-namedspace-package (set-uri-namedspace "http://sw.opencyc.org/concept/#"))
	(find-package "opencyc")))

;; Package mappings for third-party URIs used in OpenCyc
(eval-when (:execute :load-toplevel)
  (setf (uri-namedspace-package (set-uri-namedspace "http://umbel.org/umbel/sc/"))
	(make-package "umbel" :use nil))
  (setf (uri-namedspace-package (set-uri-namedspace "http://dbpedia.org/resource/"))
	(make-package "dbpedia" :use nil))
  )

;; goal: "owl:FunctionalProperty" -> the "owl" package
(defun cyc-uri2symbol-package-mapping-fun (uri)
  "This function is bound to *uri2symbol-name-mapping-fun*"
  (let ((pkg
	 (find-package (string-downcase (symbol-name (uri-scheme uri))))))
    (or pkg
	(default-uri2symbol-package-mapping-fun uri))))

;; goal: "owl:FunctionalProperty" -> "FunctionalProperty"
(defun cyc-uri2symbol-name-mapping-fun (uri)
  "This function is bound to *uri2symbol-package-mapping-fun*, returning symbol, string or nil"
  (cond ((eq (uri-scheme uri) :http)
	 (default-uri2symbol-name-mapping-fun uri))
	(t
	 (uri-path uri))))

(defun load-cyc ()
  (let ((*uri2symbol-package-mapping-fun*
	 'cyc-uri2symbol-package-mapping-fun)
	(*uri2symbol-name-mapping-fun*
	 'cyc-uri2symbol-name-mapping-fun))
    (read-rdf-file #'add-rdf/xml #p"CYC:opencyc-latest.owlz")))
