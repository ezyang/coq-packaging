(************************************************************************)
(*  v      *   The Coq Proof Assistant  /  The Coq Development Team     *)
(* <O___,, * CNRS-Ecole Polytechnique-INRIA Futurs-Universite Paris Sud *)
(*   \VV/  **************************************************************)
(*    //   *      This file is distributed under the terms of the       *)
(*         *       GNU Lesser General Public License Version 2.1        *)
(************************************************************************)

(*i $Id: Relations.v,v 1.6.2.1 2004/07/16 19:31:16 herbelin Exp $ i*)

Require Export Relation_Definitions.
Require Export Relation_Operators.
Require Export Operators_Properties.

Lemma inverse_image_of_equivalence :
 forall (A B:Set) (f:A -> B) (r:relation B),
   equivalence B r -> equivalence A (fun x y:A => r (f x) (f y)).
intros; split; elim H; red in |- *; auto.
intros _ equiv_trans _ x y z H0 H1; apply equiv_trans with (f y); assumption.
Qed.

Lemma inverse_image_of_eq :
 forall (A B:Set) (f:A -> B), equivalence A (fun x y:A => f x = f y).
split; red in |- *;
 [  (* reflexivity *) reflexivity
 |  (* transitivity *) intros; transitivity (f y); assumption
 |  (* symmetry *) intros; symmetry  in |- *; assumption ].
Qed.