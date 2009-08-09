(* macaque : sql.mli
    MaCaQue : Macros for Caml Queries
    Copyright (C) 2009 Gabriel Scherer, Jérôme Vouillon

    This library is free software; you can redistribute it and/or
    modify it under the terms of the GNU Library General Public
    License as published by the Free Software Foundation; either
    version 2 of the License, or (at your option) any later version.

    This library is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
    Library General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this library; see the file LICENSE.  If not, write to
    the Free Software Foundation, Inc., 59 Temple Place - Suite 330,
    Boston, MA 02111-1307, USA.
*)

type nullable
type non_nullable

class type ['t] type_info = object method typ : 't end
class type numeric_t = object method numeric : unit end

class type int_t = object inherit [int] type_info inherit numeric_t end
class type bool_t = object inherit [bool] type_info end
class type float_t = object inherit [float] type_info inherit numeric_t end
class type string_t = object inherit [string] type_info end

class type ['row] row_t = object inherit ['row] type_info end

type +'a t

type 'a result_parser = string array * int ref -> 'a

(** access functions *)
val get : < get : _; nul : non_nullable; t : 't #type_info > t -> 't
val getn : < get : _; nul : nullable; t : 't #type_info > t -> 't option

(** parse function *)
val parse : 'a t -> 'a t result_parser

(** untyped access *)
type untyped
val untyped : 'a t -> untyped t

type +'a view
val untyped_view : 'a view -> untyped view

(** unsafe constructors *)
type +'a unsafe
val unsafe : 'a -> 'a unsafe

val force_gettable :
  < t : 't; nul : 'nul; .. > t unsafe -> < t : 't; nul : 'nul; get : unit > t

val field :
  < t : 'a #row_t; nul : non_nullable; .. > t ->
  string list unsafe ->
  ('a -> < t : 't; nul : 'n; ..> t) unsafe ->
  <t : 't; nul : 'n> t

val row : string unsafe -> 'a view -> < t : < typ : 'a >; nul : non_nullable > t
(* < typ : 'a > instead of 'a row_t to lighten error reporting *)

val tuple :
  (string * untyped t) list unsafe ->
  'tup result_parser unsafe ->
  < t : < typ : 'tup >; nul : non_nullable > t
(* < typ : 'a > instead of 'a row_t to lighten error reporting *)

(** select and view building *)
type +'a result

type from = (string * untyped view) list
type where = untyped t list

val view : 'a result -> from -> where -> 'a view
val simple_select : < t : 'a #row_t; .. > t -> 'a result

(** group by and accumulators *)
type grouped_row
val grouped_row : grouped_row

type +'a group
type +'a accum
val accum : 'a t -> 'a accum
val group_of_accum : 'a accum -> 'a group

val group : < t : 'const #row_t; .. > t -> < t : 'res #row_t; .. > t -> 'res result

(** final query building *)
type +'a query

val select : 'a view -> 'a list query
val insert : 'a view -> 'a view -> unit query
val delete : 'a view -> string unsafe -> < t : #bool_t; .. > t list -> unit query
val update :
  'a view -> string unsafe -> 'b t -> bool unsafe -> < t : #bool_t; .. > t list -> unit query

(** query printing *)
val sql_of_query : 'a query -> string
val sql_of_view : 'a view -> string

(** handle result from PGOCaml call *)
val handle_query_results : 'a query -> string array unsafe list -> 'a

(** standard data types (usable from user code) *)
module Data : sig
  val int : int -> < t : int_t; get : unit; nul : _ > t
  val bool : bool -> < t : bool_t; get : unit; nul : _ > t
  val float : float -> < t : float_t; get : unit; nul : _ > t
  val string : string -> < t : string_t; get : unit; nul : _ > t
end

(** standard operators (usable from user code) *)
module Op : sig
  val null :
    < t : < t : 'a; numeric : unit >; nul : nullable; get : unit > t
  val nullable :
    < t : 't; nul : non_nullable; .. > t -> < t : 't; nul : nullable > t
  val is_null :
    < nul : nullable; .. > t -> < t : bool_t; nul : non_nullable > t
  val is_not_null :
    < nul : nullable; .. > t -> < t : bool_t; nul : non_nullable > t

  type 'phant arith_op = 'a t -> 'b t -> 'c t
  constraint 'a = < t : < t : 't; numeric : _ >; nul : 'n; .. >
  constraint 'b = < t : < t : 't; numeric : _ >; nul : 'n; .. >
  constraint 'c = < t : < t : 't; numeric : unit >; nul : 'n >
  constraint 'phant = < t : 't; nul : 'n; a : 'a; b : 'b >

  val (+) : _ arith_op
  val (-) : _ arith_op
  val (/) : _ arith_op
  val ( * ) : _ arith_op

  type 'phant comp_op = 'a t -> 'b t -> 'c t
  constraint 'a = < t : 't; nul : 'nul; .. >
  constraint 'b = < t : 't; nul : 'nul; .. >
  constraint 'c = < t : bool_t; nul : 'nul >
  constraint 'phant = < nul : 'nul; t : 't; a : 'a; b : 'b >

  val (<) : _ comp_op
  val (<=) : _ comp_op
  val (=) : _ comp_op
  val (<>) : _ comp_op
  val (>=) : _ comp_op
  val (>) : _ comp_op
  val is_distinct_from :
    < nul : 'n; t : 't; .. > t ->
    < nul : 'n; t : 't; .. > t ->
    < nul : non_nullable; t : bool_t > t
  val is_not_distinct_from :
    < nul : 'n; t : 't; .. > t ->
    < nul : 'n; t : 't; .. > t ->
    < nul : non_nullable; t : bool_t > t

  type 'phant logic_op = 'a t -> 'b t -> 'c t
  constraint 'a = < t : #bool_t; nul : 'n; .. >
  constraint 'b = < t : #bool_t; nul : 'n; .. >
  constraint 'c = < t : bool_t; nul : 'n >
  constraint 'phant = < nul : 'n; a : 'a; b : 'b >

  val (&&) : _ logic_op
  val (||) : _ logic_op
  val not :
    < t : #bool_t; nul : 'n; .. > t -> < t : bool_t; nul : 'n; > t

  val count :
    _ group -> < t : int_t; nul : non_nullable > t
  val max :
    < t : #numeric_t as 't; nul : 'n; .. > group -> < t : 't; nul : 'n > t
  val sum :
    < t : #numeric_t as 't; nul : 'n; .. > group -> < t : 't; nul : 'n > t
end
