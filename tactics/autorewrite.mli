(************************************************************************)
(*  v      *   The Coq Proof Assistant  /  The Coq Development Team     *)
(* <O___,, * CNRS-Ecole Polytechnique-INRIA Futurs-Universite Paris Sud *)
(*   \VV/  **************************************************************)
(*    //   *      This file is distributed under the terms of the       *)
(*         *       GNU Lesser General Public License Version 2.1        *)
(************************************************************************)

(*i $Id: autorewrite.mli,v 1.5.10.1 2004/07/16 19:30:52 herbelin Exp $ i*)

(*i*)
open Tacmach
(*i*)

(* Rewriting rules before tactic interpretation *)
type raw_rew_rule = Term.constr * bool * Tacexpr.raw_tactic_expr

(* To add rewriting rules to a base *)
val add_rew_rules : string -> raw_rew_rule list -> unit

(* The AutoRewrite tactic *)
val autorewrite : tactic -> string list -> tactic
