(* Interface for the CouchDB Document storage client *)

type t
  (** Represents a CouchDB server *)
type db
  (** Represents a CouchDB database *)

type doc_id
  (** Documentation identifiers *)

val mk_server : ?scheme:string -> ?port:int -> string -> t
  (** Create a new CouchDB representation object *)

val mk_database : t -> string -> db
  (** Create a Database from a server and a name *)

val get : db -> doc_id -> Json_type.json_type
  (** Lowlevel GET *)

val create : db -> Json_type.json_type -> doc_id
  (** Lowlevel CREATE *)

val delete : db -> doc_id -> unit
  (** Lowlevel DELETE *)

val update : db -> doc_id -> Json_type.json_type -> unit
  (** Lowlevel UPDATE *)

val info : db -> Json_type.json_type
  (** Return information about Database *)

val query : db
  -> (Json_type.json_type -> 'a) (* Map *)
  -> (Json_type.json_type -> 'a -> 'b) (* Reduce *)
  -> 'b (* Initial element *)
  -> 'b
  (** Execute a Temporary View on data *)


