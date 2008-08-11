OCAMLMAKEFILE = OCamlMakefile

SOURCES = couchdb_client.ml couchdb_client.mli 
#RESULT  = pagerank
PACKS = json-wheel netclient netstring

-include $(OCAMLMAKEFILE)
