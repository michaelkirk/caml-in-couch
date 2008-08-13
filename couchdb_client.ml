(* CouchDB Client implements a client for the CouchDB Document storage *)

let default_couchdb_port = 5984

module Http_method =
  struct
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

type t = {hostname: string;
	  scheme: string;
	  port: int}

type db = {server: t;
	   database: string}

type doc_id = string

exception InvalidDatabase

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
      raise InvalidDatabase
	
let get_default_pipe () =
  let p = new Http_client.pipeline in
    p#set_proxy_from_environment();
    p

let pipe = lazy (get_default_pipe ())
let pipe_empty = ref true

(* TODO: Serialize! *)
let l_request m =
  let p = Lazy.force pipe in
    if not !pipe_empty then
      p#reset();
    p#add_with_callback m (fun _ -> pipe_empty := true);
    pipe_empty := false;
    p # run ()

let request ?(content=None) ?(headers=[]) mthod url =
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
      
(* TODO: Generalize over scheme *)
let request_with_db ?(content=None) ?(headers=[]) db m components =
  let {server = {hostname = host;
		 scheme = scheme;
                 port = port}; database = db} = db in
  let build_url components =
    let url_syntax = Hashtbl.find Neturl.common_url_syntax "http" in
    let path = "" :: db :: components in
      Neturl.make_url
	~scheme ~port ~host ~path
	(Neturl.partial_url_syntax url_syntax) in
    request m (build_url components)

let create_database db =
  let r = request_with_db db (Http_method.Put Json_type.Null) [] in
    Json_io.json_of_string (r # get_resp_body())

let delete_database db =
  let r = request_with_db db Http_method.Delete [] in
    Json_io.json_of_string (r # get_resp_body())

let get db doc_id =
  let r = request_with_db db Http_method.Get [doc_id] in
    Json_io.json_of_string (r # get_resp_body())

let create db json =
  let r = request_with_db db (Http_method.Post_raw json) [] in
    (r # get_resp_body())

let delete db doc_id =
  let _r = request_with_db db Http_method.Delete [doc_id] in
    () (* TODO: Handle errors! *)

let update db doc_id json =
  let _r = request_with_db db (Http_method.Put json) [doc_id] in
    () (* TODO: Handle response! *)

let info db =
  let r = request_with_db db Http_method.Get [] in
    Json_io.json_of_string (r # get_resp_body())

(* Strictly TODO *)
let query db mapper reducer init = init
