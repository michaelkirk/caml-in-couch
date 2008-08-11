(* CouchDB Client implements a client for the CouchDB Document storage *)

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
	    let str = Json_io.string_of_json ~compact:true json in
	      new Http_client.put path str
	| Post_raw json ->
	    let str = Json_io.string_of_json ~compact:true json in
	      new Http_client.post_raw path str
	| Post headers -> new Http_client.post path headers
	| Delete -> new Http_client.delete path
  end

type t = {url: string}

let mk_server url = {url = url}

type db = {server: t;
	   database: string}

type doc_id = int

let mk_database server db = {server = server;
			     database = db}
	
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

let request ?(content=None) ?(headers=[]) mthod path =
  let call = Http_method.to_http_call mthod path in
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
      
let request_with_db ?(content=None) ?(headers=[]) db m components =
  let {server = _s; database = _db} = db in
  let build_url components = "" in
    request m (build_url components)

let get db doc_id =
  let r = request_with_db db Http_method.Get [doc_id] in
    Json_io.json_of_string (r # get_resp_body())

let mk_doc_id i = i

let create db json =
  let r = request_with_db db (Http_method.Post_raw json) [] in
    mk_doc_id (int_of_string (r # get_resp_body()))

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


