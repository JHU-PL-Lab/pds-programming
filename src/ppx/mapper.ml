open Batteries;;

open Migrate_parsetree;;
open OCaml_406.Ast;;
open Ast_mapper;;
open Asttypes;;
open Parsetree;;

open Pdr_programming_generation;;
open Pdr_programming_utils.Ast_utils;;
open Pdr_programming_utils.Utils;;

let reprocess (structure : structure) : structure =
  (* Okay... let's try to convince Ocaml_migrate_parsetree to run everything
     again on this structure.
  *)
  let reprocess_mapper =
    let open Migrate_parsetree.Driver in
    OCaml_current.Ast.make_top_mapper
      ~signature:(fun sg ->
          let config =
            make_config ~tool_name:"pdr-programming(reprocessing)" ()
          in
          rewrite_signature config (module OCaml_current) sg
          |> migrate_some_signature (module OCaml_current)
        )
      ~structure:(fun str ->
          let config =
            make_config ~tool_name:"pdr-programming(reprocessing)" ()
          in
          rewrite_structure config (module OCaml_current) str
          |> migrate_some_structure (module OCaml_current)
        )
  in
  reprocess_mapper.structure reprocess_mapper structure
;;

type continuation_conversion_configuration =
  { ccc_start_function_name : string;
    ccc_continue_function_name : string;
    ccc_continuation_type_name : string;
    ccc_continuation_type_attributes : attributes;
    ccc_continuation_data_type : core_type option;
    ccc_continuation_data_default : expression option;
  }
;;

type parse_result =
  | Inert_extension
  | Configuration_change of (continuation_conversion_configuration ->
                             continuation_conversion_configuration)
  | Parse_error of string
;;

let parse_continuation_configuration_extension
    (ext : extension) (attrs : attributes)
  : parse_result =
  let config_expr ?description:(description="an expression") ext expr_fn =
    match snd ext with
    | PStr([ { pstr_desc = Pstr_eval(e, _); _; } ]) ->
      expr_fn e
    | _ ->
      Parse_error(Printf.sprintf "%s payload must be %s"
                    (fst ext).txt description)
  in
  let config_type ext type_fn =
    match snd ext with
    | PTyp(core_type) -> type_fn core_type
    | _ -> Parse_error(Printf.sprintf "%s payload must be a type" (fst ext).txt)
  in
  let config_string ext string_fn =
    config_expr ~description:"a string constant" ext
      (fun e ->
         match e.pexp_desc with
         | Pexp_constant(Pconst_string(s,_)) -> string_fn s
         | _ ->
           Parse_error(Printf.sprintf "%s payload must be a string constant"
                         (fst ext).txt)
      )
  in
  let config_attributes ext attrs_fn =
    match snd ext with
    | PStr([]) -> attrs_fn attrs
    | _ -> Parse_error(Printf.sprintf "%s must have no payload" (fst ext).txt)
  in
  match (fst ext).txt with
  | "start_function_name" ->
    config_string ext
      (fun s ->
         Configuration_change(
           fun config -> { config with
                           ccc_start_function_name = s;
                         }
         )
      )
  | "continue_function_name" ->
    config_string ext
      (fun s ->
         Configuration_change(
           fun config -> { config with
                           ccc_continue_function_name = s;
                         }
         )
      )
  | "continuation_type_name" ->
    config_string ext
      (fun s ->
         Configuration_change(
           fun config -> { config with
                           ccc_continuation_type_name = s;
                         }
         )
      )
  | "continuation_type_attributes" ->
    config_attributes ext
      (fun a ->
         Configuration_change(
           fun config -> { config with
                           ccc_continuation_type_attributes =
                             config.ccc_continuation_type_attributes @ a
                         }
         )
      )
  | "continuation_data_type" ->
    config_type ext
      (fun t ->
         Configuration_change(
           fun config -> { config with
                           ccc_continuation_data_type = Some t;
                         }
         )
      )
  | "continuation_data_default" ->
    config_expr ext
      (fun e ->
         Configuration_change(
           fun config -> { config with
                           ccc_continuation_data_default = Some e;
                         }
         )
      )
  | _ ->
    Inert_extension
;;

let convert_continuation_structure
    (module_loc : Location.t) (structure : structure)
  : structure =
  (*
    We need to gather up the contents of the module.  There should be exactly
    one function declaration which is annotated with "continuation".  There may
    also be some extensions which represent configuration options.
  *)
  let default_configuration =
    { ccc_start_function_name = "start";
      ccc_continue_function_name = "cont";
      ccc_continuation_type_name = "continuation";
      ccc_continuation_type_attributes = [];
      ccc_continuation_data_type = None;
      ccc_continuation_data_default = None;
    }
  in
  (* Scan for options. *)
  let nonoption_items, config_changes =
    structure
    |> List.map
      (fun (structure_item : structure_item) ->
         match structure_item.pstr_desc with
         | Pstr_extension(ext, attrs) ->
           begin
             match parse_continuation_configuration_extension ext attrs with
             | Inert_extension -> ([structure_item], identity)
             | Configuration_change f -> ([], f)
             | Parse_error(errmsg) ->
               ([structure_item;
                 error_as_structure_item structure_item.pstr_loc errmsg
                ],
                identity
               )
           end
         | _ ->
           ([structure_item], identity)
      )
    |> List.split
    |> first List.concat
  in
  let configuration =
    List.fold_left (fun a e -> e a) default_configuration config_changes
  in
  (* Perform transformation.  Doing this as a fold so that, if any extra
     continuation functions exist, they can be converted into error nodes.
  *)
  let result_structure, saw_continuation =
    nonoption_items
    |> List.fold_left
      (fun (collected_structure, seen_continuation_yet) item ->
         match item with
         | { pstr_desc =
               Pstr_extension(({ txt = "continuation_fn"; _ }, payload), _);
             _
           } ->
           if seen_continuation_yet then
             let err =
               error_as_structure_item item.pstr_loc @@
               "continuation module must no more than one continuation function"
             in
             (err :: collected_structure, true)
           else
             begin
               match payload with
               | PStr([{ pstr_desc = Pstr_value(recflag, [binding]);
                         pstr_loc = str_loc
                       }]) ->
                 if recflag <> Nonrecursive then
                   let err =
                     error_as_structure_item str_loc
                       "\"continuation_fn\" function must be non-recursive"
                   in
                   (err :: collected_structure, true)
                 else
                   (* TODO: make use of type configuration here *)
                   let continuation_structure =
                     Continuation_code.generate_code_from_function
                       ~start_fn_name:configuration.ccc_start_function_name
                       ~cont_fn_name:configuration.ccc_continue_function_name
                       ~continuation_type_name:
                         configuration.ccc_continuation_type_name
                       ~continuation_type_attributes:
                         configuration.ccc_continuation_type_attributes
                       ~continuation_data_type:
                         configuration.ccc_continuation_data_type
                       ~continuation_data_default:
                         configuration.ccc_continuation_data_default
                       binding.pvb_expr
                   in
                   (* This is silly, but we're assembling the list of structure
                      items backwards and they get flipped back at the end.  So
                      we need to attach the new continuation structure in
                      reverse so that the later reversal will make it correct.
                   *)
                   ((List.rev continuation_structure) @ collected_structure,
                    true)
               | PStr _ ->
                 let err =
                   error_as_structure_item item.pstr_loc @@
                   "\"continuation_fn\" extension payload must be exactly " ^
                   "one let-binding for a function"
                 in
                 (err :: collected_structure, seen_continuation_yet)
               | _ ->
                 let err =
                   error_as_structure_item item.pstr_loc @@
                   "\"continuation_fn\" extension payload must be exactly " ^
                   "one let-binding for a function"
                 in
                 (err :: collected_structure, seen_continuation_yet)
             end
         | _ ->
           (item::collected_structure, seen_continuation_yet)
      )
      ([], false)
    |> first List.rev
  in
  let errs =
    if not saw_continuation then
      [ error_as_structure_item module_loc @@
        "\"continuation\" module must have exactly one function let-binding " ^
        "annotated with \"continuation_fn\""
      ]
    else
      []
  in
  result_structure @ errs
;;

let continuation_transform_structure_item mapper structure_item : structure =
  (* We need to run last; all of the PPX extensions inside of this structure
     item should be processed before we try to mess with control flow. *)
  let structure_item' = default_mapper.structure_item mapper structure_item in
  match structure_item'.pstr_desc with
  | Pstr_extension(({txt = "continuation"; loc = _}, PStr(body)), _) ->
    begin
      match body with
      | [ { pstr_desc =
              Pstr_module(
                { pmb_expr =
                    { pmod_desc = Pmod_structure(module_structure);
                      _
                    } as cont_module_expr;
                  _
                } as cont_module_binding
              );
            pstr_loc = _;
          } as cont_module
        ] ->
        let converted_structure =
          convert_continuation_structure cont_module.pstr_loc module_structure
        in
        let new_module =
          { cont_module with
            pstr_desc = Pstr_module(
                { cont_module_binding with
                  pmb_expr = { cont_module_expr with
                               pmod_desc = Pmod_structure(converted_structure);
                             };
                }
              );
          }
        in
        (* Once the new module has been constructed, it may have several pieces
           of code that expect to be processed by the PPX extensions again.
           This is *gross*, but let's run the mapper on this new code.  Note
           that the continuation extensions are gone now, so we won't loop.
        *)
        let new_module_structure = reprocess [new_module] in
        print_endline @@ Jhupllib.Pp_utils.pp_to_string Pprintast.structure
          new_module_structure;
        new_module_structure;
      | _ ->
        [error_as_structure_item structure_item'.pstr_loc @@
         "\"continuation\" extension must be applied to a single module " ^
         "structure"
        ]
    end
  | _ -> [structure_item']
;;

let mapper =
  { default_mapper with
    structure =
      fun mapper structure ->
        structure
        |> List.map (continuation_transform_structure_item mapper)
        |> List.concat
  }
;;
