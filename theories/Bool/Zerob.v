(************************************************************************)
(*  v      *   The Coq Proof Assistant  /  The Coq Development Team     *)
(* <O___,, * CNRS-Ecole Polytechnique-INRIA Futurs-Universite Paris Sud *)
(*   \VV/  **************************************************************)
(*    //   *      This file is distributed under the terms of the       *)
(*         *       GNU Lesser General Public License Version 2.1        *)
(************************************************************************)

(*i $Id: Zerob.v,v 1.8.2.1 2004/07/16 19:31:03 herbelin Exp $ i*)

Require Import Arith.
Require Import Bool.

Open Local Scope nat_scope.

Definition zerob (n:nat) : bool :=
  match n with
  | O => true
  | S _ => false
  end.

Lemma zerob_true_intro : forall n:nat, n = 0 -> zerob n = true.
destruct n; [ trivial with bool | inversion 1 ].
Qed.
Hint Resolve zerob_true_intro: bool.

Lemma zerob_true_elim : forall n:nat, zerob n = true -> n = 0.
destruct n; [ trivial with bool | inversion 1 ].
Qed.

Lemma zerob_false_intro : forall n:nat, n <> 0 -> zerob n = false.
destruct n; [ destruct 1; auto with bool | trivial with bool ].
Qed.
Hint Resolve zerob_false_intro: bool.

Lemma zerob_false_elim : forall n:nat, zerob n = false -> n <> 0.
destruct n; [ intro H; inversion H | auto with bool ].
Qed.