(**
   This module defines a monad for continuation transformation operations.
*)

open Parsetree;;

open Pdr_programming_utils.Variable_utils;;

open Fragment_types;;

type extension_predicate = extension -> bool

include Monad.Monad
include Jhupllib_monad_utils.Utils with type 'a m := 'a m

val run :
  Fragment_uid.context ->
  fresh_variable_context ->
  extension_predicate ->
  extension_predicate ->
  'a m ->
  'a
val get_fragment_uid_context : unit -> Fragment_uid.context m
val get_fresh_variable_context : unit -> fresh_variable_context m
val get_continuation_predicate : unit -> extension_predicate m
val get_homomorphism_predicate : unit -> extension_predicate m
val fresh_uid : unit -> Fragment_uid.t m
val fresh_var : unit -> string m
val is_continuation_extension : extension -> bool m
val is_homomorphic_extension : extension -> bool m
