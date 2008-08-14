(** Interface for the CouchDB Document storage client *)

(** This module implements an interface to the CouchDB document
    storage. While the storage uses a very simple methodology for
    communication. (REST+Json), you will still have to write some
    convenience functions in order to actually use it.

    The intent of this interface is to plug that hole and provide you
    with everything you need in order to use CouchDB from your OCaml
    application. *)

type t
  (** Represents a CouchDB server *)
type db
  (** Represents a CouchDB database *)

type doc_id = string
  (** Documentation identifiers: these are strings *)

(** Error handling *)
type error = InvalidDatabase (** Raised for an Invalid Database *)
	     | HttpError of int * string (** HttpErrors from CouchDb *)
	     | ClientError of string (** Errors from this client *)

exception CouchDbError of error
  (** CouchDbError is raised upon internal errors *)

val mk_server : ?scheme:string -> ?port:int -> string -> t
  (** Construct a new CouchDB representation object.
      This is a handle to a couchdb server which can be used to refer
      to that server later on in the code. *)

val mk_database : t -> string -> db
  (** Construct a new Database representation handle. *)


module Database :
  sig
    (** The Database module contains functions that manipulates whole
	databases. *)

    exception DatabaseError of (int * string)
      (** Exception that is raised of something fails. Wraps the Http
	  error as an Error-number (404 for instance) and the reason string. *)

    val create : db -> Json_type.t
      (** Create a new Database on the CouchDB server

          TODO: Recreates *)

    val create_ok : db -> unit
      (** Create a new database under the assumption that the creation
	  will not fail. If it fails DatabaseError is raised. *)
	 
    val delete : db -> Json_type.t
      (** Delete a database on the CouchDB server

          TODO: Errors *)

    val info : db -> Json_type.t
      (** Return information about Database *)

    val compact : db -> unit
      (** Compact the database *)

    val list : db -> Json_type.t
      (** List all databases *)

  end

module Basic :
  sig
    (** Basic implements the Low-level interface to CouchDB. You can
	use these if you want, but it may be far easier to use the
	high-level API provided as well. *)

    val get : db -> doc_id -> Json_type.t
      (** Lowlevel GET of doc_id. Returns the Json document *)

    val create : db -> Json_type.t -> Json_type.t
      (** Lowlevel CREATE *)

    val create_ok : db -> Json_type.t -> (string * string)
      (** Create a document under the assemption that it can be
	  created. *)  

    val delete : db -> doc_id -> unit
      (** Lowlevel DELETE *)

    val update : db -> doc_id -> Json_type.t -> unit
      (** Lowlevel UPDATE *)

  end

module View :
  sig
    (** This module implements operations for managing and querying
	temporary and permanent views in CouchDB *)

    val query : ?reducer:string (** Optional Reduction *)
      -> ?language:string (** Language we are using, by default
			      Javascript *)
      -> db
      -> string (** Map *)
      -> Json_type.t
      (** Execute a temporary view on data.

	  You can use the map-function to refer to a Javascript mapper
	  and the reduce function to refer to a reduction (fold) on
	  the data *)

    val view : db -> string -> Json_type.t
      (** Get the contents of a permanent view.

	  The view is NOT prepended with '_view'. *)
  end

module Pipeline :
  sig
    (** The pipeline module implements a pipeline API built on
	Http_client.pipeline. The advantage of this API is that you
	get asynchronous access to CouchDB through a pipeline of
	requests. *)

    type t
      (** The type of asynchronous pipelines *)

    val mk_pipeline : db -> t
      (** Given a database, create a pipeline for it *)

    val add : t -> (db -> Http_client.http_call) -> Http_client.http_call
      (** Add a request to the pipeline and returns the call object *)

    val add_with_callback : t -> (db -> Http_client.http_call)
      -> (Http_client.http_call -> unit) -> Http_client.http_call
      (** As above, but when the call completes on the pipeline, a
	  callback function is executed. To get the state of the call,
	  query the status of the http_call object

	  Returns the call object *)

    val get : doc_id -> (db -> Http_client.http_call)
      (** A GET request for use with the pipeline interface *)

    val create : Json_type.t -> (db -> Http_client.http_call)
      (** Create a new document containing json *)

    val delete : doc_id -> (db -> Http_client.http_call)
      (** Delete a document *)

    val update : doc_id 
      -> Json_type.t -> (db -> Http_client.http_call)
      (** Update a document *)

  end
