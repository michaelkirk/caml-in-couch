open OUnit
open Couchdb_client
open Json_type.Browse

let test_fixture = "couchdb_client" >:::
[
  "get" >:: ( fun () ->
		let s = mk_server "localhost" in
		let db = mk_database s "test_suite_db_a" in
		let v = get db (mk_doc_id 0) in
		let ht = make_table (objekt v) in
		  assert_equal "0" (string (Hashtbl.find ht "_id"));
		  assert_equal 0 (int (Hashtbl.find  ht "integer"));
		  assert_equal "0" (string (Hashtbl.find ht "string")));
  "..." >:: ( fun () ->
		assert_equal 0 0);
]




(* Test runs *)
let _ = run_test_tt ~verbose:true test_fixture
