(***************************************************************************)
(*                                                                         *)
(*  Copyright (C) 2018/2019 The Charles Stark Draper Laboratory, Inc.      *)
(*                                                                         *)
(*  This file is provided under the license found in the LICENSE file in   *)
(*  the top-level directory of this project.                               *)
(*                                                                         *)
(*  This work is funded in part by ONR/NAWC Contract N6833518C0107.  Its   *)
(*  content does not necessarily reflect the position or policy of the US  *)
(*  Government and no official endorsement should be inferred.             *)
(*                                                                         *)
(***************************************************************************)

open !Core_kernel
open Bap_main
open Monads.Std

(* Error for when a user does not specify a function to analyze. *)
type Extension.Error.t += Missing_function of string

(* Error for passing an unsupported option to a flag that takes in a list of
   options. *)
type Extension.Error.t += Unsupported_option of string

(* Error for passing in a comparison flag when there is only one file to
   analyze and vice versa. *)
type Extension.Error.t += Incompatible_flag of string

module Err = Monad.Result.Make(Extension.Error)(Monad.Ident)
open Err.Syntax

type t = {
  func : string;
  precond : string;
  postcond : string;
  trip_asserts : bool;
  check_null_derefs : bool;
  check_invalid_derefs : bool;
  compare_func_calls : bool;
  compare_post_reg_values : string list;
  pointer_reg_list : string list;
  inline : string option;
  num_unroll : int option;
  gdb_output : string option;
  bildb_output : string option;
  use_fun_input_regs : bool;
  mem_offset : bool;
  rewrite_addresses : bool;
  debug : string list;
  stack_base : int option;
  stack_size : int option;
  show : string list;
  func_name_map : (string * string) list;
  user_func_spec : (string * string * string) option;
  fun_specs : string list;
  ext_solver_path : string option
}

(* Ensures the user inputted a function for analysis. *)
let validate_func (func : string) : (unit, error) result =
  let err = Printf.sprintf "Function is not provided for analysis. Usage: \
                            --func=<name>%!" in
  Result.ok_if_true (not @@ String.is_empty func)
    ~error:(Missing_function err)

(* Looks for an unsupported option among the options the user inputted. *)
let find_unsupported_option (opts : string list) (valid : string list)
  : string option =
  List.find opts ~f:(fun opt ->
      not @@ List.mem valid opt ~equal:String.equal)

(* Ensures the user inputted only supported options for the debug flag. *)
let validate_debug (debug : string list) : (unit, error) result =
  let supported = [
    "z3-solver-stats";
    "z3-verbose";
    "constraint-stats";
    "eval-constraint-stats"
  ] in
  match find_unsupported_option debug supported with
  | Some s ->
    let err = Printf.sprintf "'%s' is not a supported option for --debug. \
                              Available options are: %s%!"
        s (List.to_string supported ~f:String.to_string) in
    Error (Unsupported_option err)
  | None -> Ok ()

(* Ensures the user inputted only supported options for the show flag. *)
let validate_show (show : string list) : (unit, error) result =
  let supported = [
    "bir";
    "refuted-goals";
    "paths";
    "precond-internal";
    "precond-smtlib"
  ] in
  match find_unsupported_option show supported with
  | Some s ->
    let err = Printf.sprintf "'%s' is not a supported option for --show. \
                              Available options are: %s%!"
        s (List.to_string supported ~f:String.to_string) in
    Error (Unsupported_option err)
  | None -> Ok ()

let validate_two_files (flag : bool) (name : string) (files : string list)
  : (unit, error) result =
  let err = Printf.sprintf "--%s is only used for a comparative analysis. \
                            Please specify two files. Number of files given: \
                            %d%!" name (List.length files) in
  Result.ok_if_true ((not flag) || (List.length files = 2))
    ~error:(Incompatible_flag err)

(* Ensures the user passed in two files to compare function calls. *)
let validate_compare_func_calls (flag : bool) (files : string list)
  : (unit, error) result =
  validate_two_files flag "compare-func-calls" files

(* Ensures the uer passed in two files to check for invalid dereferences. *)
let validate_check_invalid_derefs (flag : bool) (files : string list)
  : (unit, error) result =
  validate_two_files flag "check-invalid-derefs" files

(* Ensures the user passed in two files to compare post register values. *)
let validate_compare_post_reg_vals (regs : string list) (files : string list)
  : (unit, error) result =
  let err = Printf.sprintf "--compare-post-reg-values is only used for a \
                            comparative analysis. Please specify two files. \
                            Number of files given: %d%!" (List.length files) in
  Result.ok_if_true ((List.is_empty regs) || (List.length files = 2))
    ~error:(Incompatible_flag err)

let validate_mem_flags (mem_offset : bool) (rewrite_addrs : bool)
    (files : string list) : (unit, error) result =
  if mem_offset && rewrite_addrs then
    let err = "--mem-offset and --rewrite-addresses cannot be used together. \
               Please specify only one flag." in
    Error (Incompatible_flag err)
  else if mem_offset then
    validate_two_files mem_offset "mem-offset" files
  else if rewrite_addrs then
    validate_two_files rewrite_addrs "rewrite_addresses" files
  else
    Ok ()

let validate (f : t) (files : string list) : (unit, error) result =
  validate_func f.func >>= fun () ->
  validate_compare_func_calls f.compare_func_calls files >>= fun () ->
  validate_check_invalid_derefs f.check_invalid_derefs files >>= fun () ->
  validate_compare_post_reg_vals f.compare_post_reg_values files >>= fun () ->
  validate_mem_flags f.mem_offset f.rewrite_addresses files >>= fun () ->
  validate_debug f.debug >>= fun () ->
  validate_show f.show >>= fun () ->
  Ok ()
