(************************************************************************)
(*  v      *   The Coq Proof Assistant  /  The Coq Development Team     *)
(* <O___,, * CNRS-Ecole Polytechnique-INRIA Futurs-Universite Paris Sud *)
(*   \VV/  **************************************************************)
(*    //   *      This file is distributed under the terms of the       *)
(*         *       GNU Lesser General Public License Version 2.1        *)
(************************************************************************)

(*i $Id: SplitRmult.v,v 1.7.2.1 2004/07/16 19:31:15 herbelin Exp $ i*)

(*i Lemma mult_non_zero :(r1,r2:R)``r1<>0`` /\ ``r2<>0`` -> ``r1*r2<>0``. i*)


Require Import Rbase.

Ltac split_Rmult :=
  match goal with
  |  |- ((?X1 * ?X2)%R <> 0%R) =>
      apply Rmult_integral_contrapositive; split; try split_Rmult
  end.
