(* CouchDB Client implements a client for the CouchDB Document storage *)

open Json_type

let default_couchdb_port = 5984


type t = {hostname: string;
	  scheme: string;
	  port: int}

type db = {server: t;
	   database: string}

type doc_id = string

type error = InvalidDatabase
	     | HttpError of int * string
	     | ClientError of string

exception CouchDbError of error

(* Constructors *)
let mk_server
    ?(scheme = "http")
    ?(port = default_couchdb_port)
    host =
  {hostname = host;
   scheme = scheme;
   port = port}

let mk_doc_id i = i

let mk_database server db =
  let valid_db name =
    let valid_db_names = Str.regexp "^[a-z0-9_$()+-/]+$" in      
      Str.string_match valid_db_names name 0 in
    if valid_db db
    then
      {server = server;
       database = db}
    else
      raise (CouchDbError InvalidDatabase)

module Http_method =
struct
  (* This module implements the different HTTP methods available in a general
     way so we can 'plug' them into requests later on. The abstraction allows
     us to make the code a bit simpler *)
  type t = | Get 
	   | Put of Json_type.t 
	   | Post of (string * string) list
	   | Post_raw of Json_type.t
	   | Delete
	       
  let to_http_call m path =
    match m with 
      | Get -> new Http_client.get path
      | Put json ->
	  let str = match json with
	    | Json_type.Null -> ""
	    | x -> Json_io.string_of_json ~compact:true json in
	    new Http_client.put path str
      | Post_raw json ->
	      let str = Json_io.string_of_json ~compact:true json in
		new Http_client.post_raw path str
	  | Post headers -> new Http_client.post path headers
	  | Delete -> new Http_client.delete path
end

module Request =
struct
  (* This module implements the parts that carries out actual HTTP requests.
     it is used by later modules for the REST communication *)

  let http_url_syntax = Hashtbl.find Neturl.common_url_syntax "http"
  let build_url scheme host port db components =
      let path = "" :: db :: components in
	Neturl.make_url
	  ~scheme ~host ~port ~path http_url_syntax

  (* Pipe for HTTP requests *)
  let pipe =
    let get_default_pipe () =
      let p = new Http_client.pipeline in
	p#set_proxy_from_environment();
	p in
      lazy (get_default_pipe())
    let pipe_empty = ref true

    (* Run a Pipe *)
    (* TODO: Serialize this to make the code MT safe *)
    let l_request m =
      let p = Lazy.force pipe in
	if not !pipe_empty then
	  p#reset();
	p#add_with_callback m (fun _ -> pipe_empty := true);
	pipe_empty := false;
	p # run ()

    let simple_request ?(content=None) ?(headers=[]) mthod url =
      let str_url = Neturl.string_of_url url in
      let call = Http_method.to_http_call mthod str_url in
      let augmented_headers =
	headers @
	  ["Accept", "application/json"] @
	  match mthod with
	    | Http_method.Put _ -> ["Content-Type", "application/json"]
	    | _ -> [] in
      let header = new Netmime.basic_mime_header ~ro:true augmented_headers in
	call#set_request_header header;
	l_request call;
	call
      
    let request ?content ?(headers=[]) mthod url =
      let str_url = Neturl.string_of_url url in
      let call = Http_method.to_http_call mthod str_url in
      let augmented_headers =
	headers @
	  ["Accept", "application/json"] @
	  match mthod with
	    | Http_method.Put _ -> ["Content-Type", "application/json"]
	    | Http_method.Post_raw _ -> ["Content-Type", "application/json"]
	    | _ -> [] in
      let header = new Netmime.basic_mime_header ~ro:true augmented_headers in
	call # set_request_header header;
	call

    let with_db ?(content=None) ?(headers=[]) db m components =
      let {server = {hostname = host;
		     scheme = scheme;
                     port = port}; database = db} = db in
	simple_request m (build_url scheme host port db components)
  end

module Database =
  struct
    exception DatabaseError of (int * string)

    let create db =
      let r = Request.with_db db (Http_method.Put Json_type.Null) [] in
	Json_io.json_of_string (r # get_resp_body())

    let create_ok db =
      let _ = create db in (* TODO: Fixme! *)
	()

    let delete db =
      let r = Request.with_db db Http_method.Delete [] in
	Json_io.json_of_string (r # get_resp_body())

    let info db =
      let r = Request.with_db db Http_method.Get [] in
	Json_io.json_of_string (r # get_resp_body())

    let compact db =
      let _r = Request.with_db db (Http_method.Post []) ["_compact"] in
	()

    let list db =
      let r = Request.with_db db Http_method.Get ["_all_dbs"] in
	Json_io.json_of_string (r # get_resp_body())
  end

module Basic =
  struct
    let with_error thunk =
      try
	thunk ()
      with Http_client.Http_error (control_code, msg) ->
	raise (CouchDbError (HttpError (control_code, msg)))

    let get db doc_id =
      with_error (fun () ->
		    let r = Request.with_db db Http_method.Get [doc_id] in
		      Json_io.json_of_string (r # get_resp_body()))

    let create db json =
      let r = Request.with_db db (Http_method.Post_raw json) [] in
	Json_io.json_of_string (r # get_resp_body())

    let create_ok db json =
      let handle_response r =
	let o = Browse.make_table (Browse.objekt r) in
	  (Browse.bool (Browse.field o "ok"),
	   Browse.string (Browse.field o "id"),
	   Browse.string (Browse.field o "rev")) in
	try
	  let (ok, id, rev) = handle_response (create db json) in
	    match ok with
	      | true -> (id, rev)
	      | false -> raise
		  (CouchDbError
		     (ClientError "Document Creation returned 'ok': false"))
	with Http_client.Http_error(control_code, msg) ->
	  raise (CouchDbError (HttpError (control_code, msg)))

    let delete db doc_id =
      with_error (fun () ->
		    let _r = Request.with_db db Http_method.Delete [doc_id] in
		      ()) (* TODO: Handle return message! *)

    let update db doc_id json =
      with_error
	(fun () ->
	   let _r = Request.with_db db (Http_method.Put json) [doc_id] in
	     ()) (* TODO: Handle return message! *)

  end

module View =
  struct
    let query ?reducer ?(language = "javascript") db mapper =
      let body = Build.objekt
	((match reducer with
	   | None -> []
	   | Some r -> ["reduce", Build.string r])
	@ ["map", Build.string mapper;
	   "language", Build.string language]) in
      let r = Request.with_db db (Http_method.Post_raw body) ["_temp_view"] in
	Json_io.json_of_string (r # get_resp_body ())

    let view db name =
      let r = Request.with_db db Http_method.Get ["_view"; name] in
	Json_io.json_of_string (r # get_resp_body ())

  end

module Pipeline =
  struct
    type t = {db: db;
	      pipeline: Http_client.pipeline}

    let mk_pipeline db =
      let p = new Http_client.pipeline in
	p # set_proxy_from_environment();
	{db = db;
	 pipeline = p}

    let add {db = db; pipeline = pipeline} request =
      pipeline # add (request db)

    let add_with_callback {db = db; pipeline = pipeline} request h =
      pipeline # add_with_callback (request db) h

    let get doc_id =
      (fun (db) ->
	 let {server = {hostname = host;
			scheme = scheme;
			port = port}; database = db} = db in
	 let url = Request.build_url scheme host port db [doc_id] in
	 let m = Http_method.Get in
	   Request.request m url)

    let add_get pipeline doc_id =
      add pipeline (get doc_id)

    let add_get_wc pipeline doc_id cb =
      add_with_callback pipeline (get doc_id) cb
      
  end
