(************************************************************************)
(*  v      *   The Coq Proof Assistant  /  The Coq Development Team     *)
(* <O___,, * CNRS-Ecole Polytechnique-INRIA Futurs-Universite Paris Sud *)
(*   \VV/  **************************************************************)
(*    //   *      This file is distributed under the terms of the       *)
(*         *       GNU Lesser General Public License Version 2.1        *)
(************************************************************************)

(*i $Id: Logic_Type.v,v 1.19.2.1 2004/07/16 19:31:03 herbelin Exp $ i*)

Set Implicit Arguments.

(** This module defines quantification on the world [Type]
    ([Logic.v] was defining it on the world [Set]) *)

Require Import Datatypes.
Require Export Logic.

Definition notT (A:Type) := A -> False.

Section identity_is_a_congruence.

 Variables A B : Type.
 Variable f : A -> B.

 Variables x y z : A.
 
 Lemma sym_id : identity x y -> identity y x.
 Proof.
  destruct 1; trivial.
 Qed.

 Lemma trans_id : identity x y -> identity y z -> identity x z.
 Proof.
  destruct 2; trivial.
 Qed.

 Lemma congr_id : identity x y -> identity (f x) (f y).
 Proof.
  destruct 1; trivial.
 Qed.

 Lemma sym_not_id : notT (identity x y) -> notT (identity y x).
 Proof.
  red in |- *; intros H H'; apply H; destruct H'; trivial.
 Qed.

End identity_is_a_congruence.

Definition identity_ind_r :
  forall (A:Type) (a:A) (P:A -> Prop), P a -> forall y:A, identity y a -> P y.
 intros A x P H y H0; case sym_id with (1 := H0); trivial.
Defined.

Definition identity_rec_r :
  forall (A:Type) (a:A) (P:A -> Set), P a -> forall y:A, identity y a -> P y.
 intros A x P H y H0; case sym_id with (1 := H0); trivial.
Defined.

Definition identity_rect_r :
  forall (A:Type) (a:A) (P:A -> Type), P a -> forall y:A, identity y a -> P y.
 intros A x P H y H0; case sym_id with (1 := H0); trivial.
Defined.

Inductive prodT (A B:Type) : Type :=
    pairT : A -> B -> prodT A B.

Section prodT_proj.

  Variables A B : Type.

  Definition fstT (H:prodT A B) := match H with
                                   | pairT x _ => x
                                   end.
  Definition sndT (H:prodT A B) := match H with
                                   | pairT _ y => y
                                   end.

End prodT_proj.

Definition prodT_uncurry (A B C:Type) (f:prodT A B -> C) 
  (x:A) (y:B) : C := f (pairT x y).

Definition prodT_curry (A B C:Type) (f:A -> B -> C) 
  (p:prodT A B) : C := match p with
                       | pairT x y => f x y
                       end.

Hint Immediate sym_id sym_not_id: core v62.
