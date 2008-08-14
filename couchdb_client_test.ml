open OUnit
open Couchdb_client
open Json_type.Browse

let server = mk_server "localhost"
let test_suite_db_a = mk_database server "test_suite_db_a"
let test_db_1 = mk_database server "caml_in_couch_test_1"
let test_db = mk_database server "caml_in_couch_test"
let _ =
  try
    Database.create test_db
  with Http_client.Http_error(500, _) -> Json_type.Null


let document1 =
  Json_type.Build.objekt
    [ "rec1", Json_type.Build.int 123;
      "rec2", Json_type.Build.string "Hello World"]
exception TestError of string

let (document1_id,
     document1_rev) = Basic.create_ok test_db document1

let print_json json =
  print_string (Json_io.string_of_json ~compact:false json)

let test_fixture = "couchdb_client" >:::
[
  "create_db" >:: ( fun () ->
		      let _v = Database.create test_db_1 in
			());
  "delete_db" >:: ( fun () ->
		      let _v = Database.delete test_db_1 in
			());

  "create_document" >:: ( fun () ->
			    let _id = Basic.create test_db document1 in
			      ());

  "get_document" >:: ( fun () ->
			 let v = Basic.get test_db document1_id in
			 let t1 = make_table (objekt document1) in
			 let t2 = make_table (objekt v) in
			 let equaller t1 t2 ty fieldname =
			   assert_equal
			     (ty (field t1 fieldname))
			     (ty (field t2 fieldname)) in
			 let eq_int = equaller t1 t2 int in
			 let eq_str = equaller t1 t2 string in
			   eq_int "rec1";
			   eq_str "rec2");
  "get_document_non_exist" >::
    ( fun () ->
	try
	  let _ = Basic.get test_db "some_non_existing_document" in
	    ()
	with CouchDbError (HttpError (404, msg)) ->
	  ());
  "get" >:: ( fun () ->
		let v = Basic.get test_suite_db_a "0" in
		let ht = make_table (objekt v) in
		  assert_equal "0" (string (Hashtbl.find ht "_id"));
		  assert_equal 0 (int (Hashtbl.find  ht "integer"));
		  assert_equal "0" (string (Hashtbl.find ht "string")));
  "..." >:: ( fun () ->
		assert_equal 0 0);
]




(* Test runs *)
let _ = run_test_tt ~verbose:true test_fixture
