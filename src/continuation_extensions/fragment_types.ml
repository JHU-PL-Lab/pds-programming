open Batteries;;
open Jhupllib;;

open Parsetree;;
open Pdr_programming_utils.Variable_utils;;

module Fragment_uid = Uids.Make ();;

(** The metadata describing an input hole. *)
type input_hole_data =
  {
    inhd_loc: Location.t
    (** The location describing the point at which the input for this fragment
        was created. *)
  }
;;

(** The metadata describing an output hole. *)
type evaluation_hole_data =
  { evhd_loc: Location.t;
    (** The location describing the origin of the expression that produced the
          evaluated value. *)

    evhd_target_fragment: Fragment_uid.t option;
    (** The ID of the fragment which should be evaluated after this one, or
        [None] to indicate that the evaluated result of this evaluation hole is
        the result of the overall expression. *)

    evhd_bound_variables: core_type option Var_map.t;
    (** The variables which are bound by the point that this evaluation hole is
        reached and their corresponding types (if known). *)
  }
;;

(** The metadata describing an action hole. *)
type extension_hole_data =
  { exhd_loc: Location.t;
    (** The location describing the extension that created the hole. *)

    exhd_extension: extension;
    (** The extension which caused the creation of this action hole. *)

    exhd_target_fragment: Fragment_uid.t option;
    (** The ID of the fragment to which this hole leads, or [None] to indicate
        that the value generated by the extension (which would be passed to the
        next fragment) is the result of the overall expression. *)

    exhd_bound_variables: core_type option Var_map.t;
    (** The variables which are bound by the point that this extension hole is
        reached and their corresponding types (if known). *)
  }
;;

(** The type of an externally bound variable record. *)
type externally_bound_variable =
  { ebv_variable : Longident.t;
    ebv_binder : Fragment_uid.t;
    ebv_type : core_type option;
    ebv_bind_loc : Location.t;
  }
;;

(** The type of a code fragment. *)
type fragment =
  { fragment_uid: Fragment_uid.t;
    (** The UID of this fragment. *)

    fragment_loc: Location.t;
    (** A location to attribute to this fragment. *)

    fragment_free_variables: Var_set.t;
    (** The set of variables which are free in this fragment.  These variables
        appear free in the body of the code that this fragment generates. *)

    fragment_externally_bound_variables: externally_bound_variable Var_map.t;
    (** The set of variables in this fragment which are bound by other fragments
        in its group.  The pair identifies the UID of the fragment which binds
        the variable for this fragment as well as the variable's type, if it is
        known. *)

    fragment_input_hole: input_hole_data option;
    (** The input hole for this fragment (if one exists). *)

    fragment_evaluation_holes: evaluation_hole_data list;
    (** The evaluation holes for this fragment. *)

    fragment_extension_holes: extension_hole_data list;
    (** The extension holes for this fragment. *)

    fragment_code :
      expression option ->
      (expression -> expression) list ->
      expression list ->
      expression;
    (** A function representing the fragment's code with a number of holes in
        it.  The arguments provide a means to fill the input, evaluation, and
        extension holes, in that order.  Input holes are filled using a single
        expression (representing the value of the previous fragment).    Evaluation holes are filled using a function from the simple expression
        describing the result of this fragment (e.g. a variable) onto the
        expression which should be used in its place; this gives the supplier
        the opportunity to wrap the result in some meaningful call or
        constructor.  Extension holes are filled using a single expression which
        will result in the desired extension-specific behavior. *)
  }
;;

(** The type of a fragment UID set. *)
module Fragment_uid_set = struct
  module S = Set.Make(Fragment_uid)
  include S;;
  include Pp_utils.Set_pp(S)(Fragment_uid);;
end;;
(** The type of a fragment UID dictionary. *)
module Fragment_uid_map = Map.Make(Fragment_uid);;

type fragment_group =
  { fg_graph : fragment Fragment_uid_map.t;
    fg_loc : Location.t;
    fg_entry : Fragment_uid.t;
    fg_exits : Fragment_uid_set.t
  }
;;
