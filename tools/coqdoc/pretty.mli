(************************************************************************)
(*  v      *   The Coq Proof Assistant  /  The Coq Development Team     *)
(* <O___,, * CNRS-Ecole Polytechnique-INRIA Futurs-Universite Paris Sud *)
(*   \VV/  **************************************************************)
(*    //   *      This file is distributed under the terms of the       *)
(*         *       GNU Lesser General Public License Version 2.1        *)
(************************************************************************)

(*i $Id: pretty.mli,v 1.1.2.1 2004/07/16 19:31:47 herbelin Exp $ i*)

open Index

type file =
  | Vernac_file of string * coq_module
  | Latex_file of string

val gallina : bool ref

val produce_document : file list -> unit
