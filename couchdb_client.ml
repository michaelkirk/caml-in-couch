(* CouchDB Client implements a client for the CouchDB Document storage *)

type t = {url: string}

let mk_server url = {url = url}

type db = {server: t;
	   database: string}

type doc_id = int

let mk_database server db = {server = server;
			     database = db}
				 
let get db url = Json_type.Null

let create db json = 0

let delete db doc_id = ()
let update db doc_id json = ()
let info db = Json_type.Null

let query db mapper reducer init = init


