(************************************************************************)
(*  v      *   The Coq Proof Assistant  /  The Coq Development Team     *)
(* <O___,, * CNRS-Ecole Polytechnique-INRIA Futurs-Universite Paris Sud *)
(*   \VV/  **************************************************************)
(*    //   *      This file is distributed under the terms of the       *)
(*         *       GNU Lesser General Public License Version 2.1        *)
(************************************************************************)

(*i camlp4deps: "parsing/grammar.cma" i*)

(* $Id: g_quote.ml4,v 1.1.12.1 2004/07/16 19:30:13 herbelin Exp $ *)

open Quote

TACTIC EXTEND Quote
  [ "Quote" ident(f) ] -> [ quote f [] ]
| [ "Quote" ident(f) "[" ne_ident_list(lc) "]"] -> [ quote f lc ]
END
