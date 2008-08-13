open OUnit
open Couchdb_client
open Json_type.Browse

let server = mk_server "localhost"
let test_suite_db_a = mk_database server "test_suite_db_a"
let test_db_1 = mk_database server "caml_in_couch_test_1"
let test_db = mk_database server "caml_in_couch_test"
let _ =
  try
    create_database test_db
  with Http_client.Http_error(500, _) -> Json_type.Null


let document1 =
  Json_type.Build.objekt
    [ "rec1", Json_type.Build.int 123;
      "rec2", Json_type.Build.string "Hello World"]

let test_fixture = "couchdb_client" >:::
[
  "create_db" >:: ( fun () ->
		      let _v = create_database test_db_1 in
			());
  "delete_db" >:: ( fun () ->
		      let _v = delete_database test_db_1 in
			());

  "create_document" >:: ( fun () ->
			    let _id = create test_db document1 in
			      ());
  "get" >:: ( fun () ->
		let v = get test_suite_db_a "0" in
		let ht = make_table (objekt v) in
		  assert_equal "0" (string (Hashtbl.find ht "_id"));
		  assert_equal 0 (int (Hashtbl.find  ht "integer"));
		  assert_equal "0" (string (Hashtbl.find ht "string")));
  "..." >:: ( fun () ->
		assert_equal 0 0);
]




(* Test runs *)
let _ = run_test_tt ~verbose:true test_fixture
