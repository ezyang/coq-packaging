(************************************************************************)
(*  v      *   The Coq Proof Assistant  /  The Coq Development Team     *)
(* <O___,, * CNRS-Ecole Polytechnique-INRIA Futurs-Universite Paris Sud *)
(*   \VV/  **************************************************************)
(*    //   *      This file is distributed under the terms of the       *)
(*         *       GNU Lesser General Public License Version 2.1        *)
(************************************************************************)

(* $Id: mod_typing.mli,v 1.2.8.1 2004/07/16 19:30:26 herbelin Exp $ *)

(*i*)
open Declarations
open Environ
open Entries
(*i*)


val translate_modtype : env -> module_type_entry -> module_type_body

val translate_module : env -> module_entry -> module_body

val add_modtype_constraints : env -> module_type_body -> env

val add_module_constraints : env -> module_body -> env

