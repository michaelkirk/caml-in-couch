(* Interface for the CouchDB Document storage client *)

type t
  (** Represents a CouchDB server *)
type db
  (** Represents a CouchDB database *)

type doc_id = string
  (** Documentation identifiers: these are strings *)

val mk_server : ?scheme:string -> ?port:int -> string -> t
  (** Construct a new CouchDB representation object *)

val mk_database : t -> string -> db
  (** Construct a new Database representation handle *)

val create_database : db -> Json_type.t
  (** Create a new Database on the CouchDB server *)

val delete_database : db -> Json_type.t
  (** Delete a database on the CouchDB server *)

val get : db -> doc_id -> Json_type.t
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


