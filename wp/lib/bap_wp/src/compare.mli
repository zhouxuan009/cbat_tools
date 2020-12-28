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

(**

   This module creates utilities to create preconditions for comparing
   BIR blocks and subroutines.

   Usage typically involves creating a new (abstract) {!Environment.t}
   value, a Z3 context and a {!Environment.var_gen} using the utility
   functions.

   The API returns a pair of {!comparator}s which are used to create a
   postcondition and hypothesis in that order. These should then be passed
   into {!compare_subs} in order to run the comparative analysis.

   The resulting precondition can then be tested for satisfiability or
   provability using the Z3 Solver module using the {!precondition}
   module utilities.

*)

module Env = Environment

module Constr = Constraint

(** The type of functions that generate a postcondition or hypothesis for
    comparative analysis. Also updates the environments as needed. *)
type comparator

(** Compare two blocks by composition: Given a set of register values at
    pre-execution and a set of register values at post-execution, return a
    precondition which is provable only if (modulo soundness bugs) the registers
    at post-execution will have equal values given the registers at
    pre-execution have equal values. *)
val compare_blocks
  :  pre_regs:Bap.Std.Var.Set.t
  -> post_regs:Bap.Std.Var.Set.t
  -> original:(Bap.Std.Blk.t * Env.t)
  -> modified:(Bap.Std.Blk.t * Env.t)
  -> smtlib_post:string
  -> smtlib_hyp:string
  -> Constr.t * Env.t * Env.t

(** Compare two subroutines by composition: given the lists of postconditions
    and hypotheses generated by the API below. *)
val compare_subs
  :  postconds:(comparator list)
  -> hyps:(comparator list)
  -> original:(Bap.Std.Sub.t * Env.t)
  -> modified:(Bap.Std.Sub.t * Env.t)
  -> Constr.t * Env.t * Env.t

(** Compare two subroutines by composition for equality of return
    values:

    Given a set of register values at pre-execution and a set of register values
    at post-execution, return a postcondition and hypothesis that, when passed to
    [compare_subs], will generate a precondition which is provable only if
    (modulo soundness bugs) the registers at post-execution will have equal
    values given the registers at pre-execution have equal values. *)
val compare_subs_eq
  :  pre_regs:Bap.Std.Var.Set.t
  -> post_regs:Bap.Std.Var.Set.t
  -> comparator * comparator

(** Compare two subroutines by composition for an empty postcondition:

    Given two subroutines and environments, return a postcondition
    and hypothesis that, when passed to [compare_subs], will generate a
    precondition which is provable only if (modulo soundness bugs) the VCs generated
    by the hooks provided by the environment are satisfied. *)
val compare_subs_empty : comparator * comparator

(** Compare two subroutines by composition for an empty
    postcondition:

    Given two subroutines and environments, return a postcondition
    and hypothesis that, when passed to [compare_subs], will generate a
    precondition which is provable only if (modulo soundness bugs), for equal
    inputs, the VCs generated by the hooks provided by the environment
    are satisfied. *)
val compare_subs_empty_post : comparator * comparator

(** Compare two subs by composition for an empty postcondition:

    Give two subroutines and environments, return a postcondition
    and hypothesis that, when passed to [compare_subs], will generate a
    precondition which is provable only if (modulo soundness bugs) the VCs generated
    by the hooks provided by the environment are satisfied, given that the
    architecture of the binary is x86_64. The hypothesis comparator generates a
    constraint which states that the stack pointer is within the bounds of the
    memory region we define with [Env.mk_env ~stack_range] at environment
    creation time. *)
val compare_subs_sp : comparator * comparator

(** Given a constraint to use as the hypothesis (precondition) and a constraint
    to use as the postcondition, returns a tuple of comparators. The first
    comparator returns the input postcondition constraint when called. The
    second comparator returns the input precondition constraint when called. *)
val compare_subs_constraints
  :  pre_conds:Constr.t
  -> post_conds:Constr.t
  -> comparator * comparator

(** Compare two subroutines by composition for conservation of function calls:

    Given two subroutines and environments, return a postcondition
    and hypothesis that, when passed to [compare_subs], will generate a
    precondition which is provable only if (modulo soundness bugs) every call made by
    the original subroutine is made by the modified one, given equal variables
    on input. *)
val compare_subs_fun : comparator * comparator

(** Compare two subroutines by composition based on the postcondition
    specified from the smtlib2 string.

    Give two subroutines and environments, return a postcondition
    and hypothesis that, when passed to [compare_subs], will generate a
    precondition which is provable only if (modulo soundness bugs) the
    postcondition from the smtlib2 string is satisfiable, given the
    hypothesis specified from the smtlib2 string. *)
val compare_subs_smtlib
  :  smtlib_post:string
  -> smtlib_hyp:string
  -> comparator * comparator

(** Compare two subroutines by composition for an empty postcondition with the
    hypothesis that memory between the two binaries are equal at the
    beginning of the subroutines. *)
val compare_subs_mem_eq : comparator * comparator

(** [mk_smtlib2_compare] builds a constraint out of an smtlib2 string that can be used
    as a comparison predicate between an original and modified binary. *)
val mk_smtlib2_compare : Env.t -> Env.t -> string -> Constr.t

val map_fun_names
  :  Bap.Std.Sub.t Bap.Std.Seq.t
  -> Bap.Std.Sub.t Bap.Std.Seq.t
  -> string Core_kernel.String.Map.t
