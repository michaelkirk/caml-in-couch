OCAMLMAKEFILE = OCamlMakefile

SOURCES = couchdb_client.ml couchdb_client.mli \
	couchdb_client_test.ml

#RESULT  = pagerank
PACKS = json-wheel netclient netstring str oUnit

-include $(OCAMLMAKEFILE)
