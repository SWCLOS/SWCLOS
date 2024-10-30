Portable SWCLOS (CLOS-based Semantic Web)
======

OWL Full Processor on top of Common Lisp Object System (CLOS)

## Original platform

* Allegro CL Enterprise Edition 8.x, 9.x

## Supported platforms

* Allegro CL Free Express Edition 10.x
* LispWorks 6.1, 7.0, 7.1 (version <= 6.0 is NOT supported!)

## API changes comparing with original SWCLOS 2.0

* defConcept &rarr; def-concept
* defIndividual &rarr; def-individual
* defProperty &rarr; def-property
* defResource &rarr; def-resource
* defTriple &rarr; def-triple
* addClass &rarr; add-class
* addForm &rarr; add-form
* addObject &rarr; add-object
* addInstance &rarr; add-instance
* addTriple &rarr; add-triple
* addRdfXml &rarr; add-rdf/xml
* lasyAddRdfXml &rarr; lasy-add-rdf/xml

## OpenCyc

The full OpenCyc OWL file (compressed) is now part of this project, as it's not available for download from Cycorp, Inc. (www.cyc.com) any more.
