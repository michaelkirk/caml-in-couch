(* CouchDB Client implements a client for the CouchDB Document storage *)

module Http_method =
  struct
    type t = | Get 
	     | Put of Json_type.t 
	     | Post of (string * string) list
	     | Delete

    let to_http_call m path =
      match m with 
	| Get -> new Http_client.get path
	| Put json ->
	    let str = Json_io.string_of_json ~compact:true json in
	      new Http_client.put path str
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

let request mthod path content headers =
  let call = Http_method.to_http_call mthod path in
  let headers =
    ["Accept", "application/json"] @
    match mthod with
      | Http_method.Put _ -> ["Content-Type", "application/json"]
      | _ -> [] in
  let header = new Netmime.basic_mime_header ~ro:true headers in
    call#set_request_header header;
    l_request call
      
let get db doc_id = Json_type.Null

let create db json = 0

let delete db doc_id = ()
let update db doc_id json = ()
let info db = Json_type.Null

let query db mapper reducer init = init


