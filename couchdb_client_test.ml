open OUnit
open Couchdb_client
open Json_type.Browse

let server = mk_server "localhost"
let test_db = mk_database server "caml_in_couch_test"

let test_fixture = "couchdb_client" >:::
[
  "create_db" >:: ( fun () ->
		      let _v = create_database test_db in
			());
  "get" >:: ( fun () ->
		let v = get test_db (mk_doc_id 0) in
		let ht = make_table (objekt v) in
		  assert_equal "0" (string (Hashtbl.find ht "_id"));
		  assert_equal 0 (int (Hashtbl.find  ht "integer"));
		  assert_equal "0" (string (Hashtbl.find ht "string")));
  "..." >:: ( fun () ->
		assert_equal 0 0);
]




(* Test runs *)
let _ = run_test_tt ~verbose:true test_fixture
