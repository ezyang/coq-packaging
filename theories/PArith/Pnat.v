(* -*- coding: utf-8 -*- *)
(************************************************************************)
(*  v      *   The Coq Proof Assistant  /  The Coq Development Team     *)
(* <O___,, *   INRIA - CNRS - LIX - LRI - PPS - Copyright 1999-2014     *)
(*   \VV/  **************************************************************)
(*    //   *      This file is distributed under the terms of the       *)
(*         *       GNU Lesser General Public License Version 2.1        *)
(************************************************************************)

Require Import BinPos Le Lt Gt Plus Mult Minus Compare_dec.

(** Properties of the injection from binary positive numbers
    to Peano natural numbers *)

(** Original development by Pierre Crégut, CNET, Lannion, France *)

Local Open Scope positive_scope.
Local Open Scope nat_scope.

Module Pos2Nat.
 Import Pos.

(** [Pos.to_nat] is a morphism for successor, addition, multiplication *)

Lemma inj_succ p : to_nat (succ p) = S (to_nat p).
Proof.
 unfold to_nat. rewrite iter_op_succ. trivial.
 apply plus_assoc.
Qed.

Theorem inj_add p q : to_nat (p + q) = to_nat p + to_nat q.
Proof.
 revert q. induction p using peano_ind; intros q.
 now rewrite add_1_l, inj_succ.
 now rewrite add_succ_l, !inj_succ, IHp.
Qed.

Theorem inj_mul p q : to_nat (p * q) = to_nat p * to_nat q.
Proof.
 revert q. induction p using peano_ind; simpl; intros; trivial.
 now rewrite mul_succ_l, inj_add, IHp, inj_succ.
Qed.

(** Mapping of xH, xO and xI through [Pos.to_nat] *)

Lemma inj_1 : to_nat 1 = 1.
Proof.
 reflexivity.
Qed.

Lemma inj_xO p : to_nat (xO p) = 2 * to_nat p.
Proof.
 exact (inj_mul 2 p).
Qed.

Lemma inj_xI p : to_nat (xI p) = S (2 * to_nat p).
Proof.
 now rewrite xI_succ_xO, inj_succ, inj_xO.
Qed.

(** [Pos.to_nat] maps to the strictly positive subset of [nat] *)

Lemma is_succ : forall p, exists n, to_nat p = S n.
Proof.
 induction p using peano_ind.
 now exists 0.
 destruct IHp as (n,Hn). exists (S n). now rewrite inj_succ, Hn.
Qed.

(** [Pos.to_nat] is strictly positive *)

Lemma is_pos p : 0 < to_nat p.
Proof.
 destruct (is_succ p) as (n,->). auto with arith.
Qed.

(** [Pos.to_nat] is a bijection between [positive] and
    non-zero [nat], with [Pos.of_nat] as reciprocal.
    See [Nat2Pos.id] below for the dual equation. *)

Theorem id p : of_nat (to_nat p) = p.
Proof.
 induction p using peano_ind. trivial.
 rewrite inj_succ. rewrite <- IHp at 2.
 now destruct (is_succ p) as (n,->).
Qed.

(** [Pos.to_nat] is hence injective *)

Lemma inj p q : to_nat p = to_nat q -> p = q.
Proof.
 intros H. now rewrite <- (id p), <- (id q), H.
Qed.

Lemma inj_iff p q : to_nat p = to_nat q <-> p = q.
Proof.
 split. apply inj. intros; now subst.
Qed.

(** [Pos.to_nat] is a morphism for comparison *)

Lemma inj_compare p q : (p ?= q) = nat_compare (to_nat p) (to_nat q).
Proof.
 revert q. induction p as [ |p IH] using peano_ind; intros q.
 destruct (succ_pred_or q) as [Hq|Hq]; [now subst|].
 rewrite <- Hq, lt_1_succ, inj_succ, inj_1, nat_compare_S.
 symmetry. apply nat_compare_lt, is_pos.
 destruct (succ_pred_or q) as [Hq|Hq]; [subst|].
 rewrite compare_antisym, lt_1_succ, inj_succ. simpl.
 symmetry. apply nat_compare_gt, is_pos.
 now rewrite <- Hq, 2 inj_succ, compare_succ_succ, IH.
Qed.

(** [Pos.to_nat] is a morphism for [lt], [le], etc *)

Lemma inj_lt p q : (p < q)%positive <-> to_nat p < to_nat q.
Proof.
 unfold lt. now rewrite inj_compare, nat_compare_lt.
Qed.

Lemma inj_le p q : (p <= q)%positive <-> to_nat p <= to_nat q.
Proof.
 unfold le. now rewrite inj_compare, nat_compare_le.
Qed.

Lemma inj_gt p q : (p > q)%positive <-> to_nat p > to_nat q.
Proof.
 unfold gt. now rewrite inj_compare, nat_compare_gt.
Qed.

Lemma inj_ge p q : (p >= q)%positive <-> to_nat p >= to_nat q.
Proof.
 unfold ge. now rewrite inj_compare, nat_compare_ge.
Qed.

(** [Pos.to_nat] is a morphism for subtraction *)

Theorem inj_sub p q : (q < p)%positive ->
 to_nat (p - q) = to_nat p - to_nat q.
Proof.
 intro H; apply plus_reg_l with (to_nat q); rewrite le_plus_minus_r.
 now rewrite <- inj_add, add_comm, sub_add.
 now apply lt_le_weak, inj_lt.
Qed.

Theorem inj_sub_max p q :
 to_nat (p - q) = Peano.max 1 (to_nat p - to_nat q).
Proof.
 destruct (ltb_spec q p).
 rewrite <- inj_sub by trivial.
 now destruct (is_succ (p - q)) as (m,->).
 rewrite sub_le by trivial.
 replace (to_nat p - to_nat q) with 0; trivial.
 apply le_n_0_eq.
 rewrite <- (minus_diag (to_nat p)).
 now apply minus_le_compat_l, inj_le.
Qed.

Theorem inj_pred p : (1 < p)%positive ->
 to_nat (pred p) = Peano.pred (to_nat p).
Proof.
 intros H. now rewrite <- Pos.sub_1_r, inj_sub, pred_of_minus.
Qed.

Theorem inj_pred_max p :
 to_nat (pred p) = Peano.max 1 (Peano.pred (to_nat p)).
Proof.
 rewrite <- Pos.sub_1_r, pred_of_minus. apply inj_sub_max.
Qed.

(** [Pos.to_nat] and other operations *)

Lemma inj_min p q :
 to_nat (min p q) = Peano.min (to_nat p) (to_nat q).
Proof.
 unfold min. rewrite inj_compare.
 case nat_compare_spec; intros H; symmetry.
 apply Peano.min_l. now rewrite H.
 now apply Peano.min_l, lt_le_weak.
 now apply Peano.min_r, lt_le_weak.
Qed.

Lemma inj_max p q :
 to_nat (max p q) = Peano.max (to_nat p) (to_nat q).
Proof.
 unfold max. rewrite inj_compare.
 case nat_compare_spec; intros H; symmetry.
 apply Peano.max_r. now rewrite H.
 now apply Peano.max_r, lt_le_weak.
 now apply Peano.max_l, lt_le_weak.
Qed.

Theorem inj_iter :
  forall p {A} (f:A->A) (x:A),
    Pos.iter p f x = nat_iter (to_nat p) f x.
Proof.
 induction p using peano_ind. trivial.
 intros. rewrite inj_succ, iter_succ. simpl. now f_equal.
Qed.

End Pos2Nat.

Module Nat2Pos.

(** [Pos.of_nat] is a bijection between non-zero [nat] and
    [positive], with [Pos.to_nat] as reciprocal.
    See [Pos2Nat.id] above for the dual equation. *)

Theorem id (n:nat) : n<>0 -> Pos.to_nat (Pos.of_nat n) = n.
Proof.
 induction n as [|n H]; trivial. now destruct 1.
 intros _. simpl. destruct n. trivial.
 rewrite Pos2Nat.inj_succ. f_equal. now apply H.
Qed.

Theorem id_max (n:nat) : Pos.to_nat (Pos.of_nat n) = max 1 n.
Proof.
 destruct n. trivial. now rewrite id.
Qed.

(** [Pos.of_nat] is hence injective for non-zero numbers *)

Lemma inj (n m : nat) : n<>0 -> m<>0 -> Pos.of_nat n = Pos.of_nat m -> n = m.
Proof.
 intros Hn Hm H. now rewrite <- (id n), <- (id m), H.
Qed.

Lemma inj_iff (n m : nat) : n<>0 -> m<>0 ->
 (Pos.of_nat n = Pos.of_nat m <-> n = m).
Proof.
 split. now apply inj. intros; now subst.
Qed.

(** Usual operations are morphisms with respect to [Pos.of_nat]
    for non-zero numbers. *)

Lemma inj_succ (n:nat) : n<>0 -> Pos.of_nat (S n) = Pos.succ (Pos.of_nat n).
Proof.
intro H. apply Pos2Nat.inj. now rewrite Pos2Nat.inj_succ, !id.
Qed.

Lemma inj_pred (n:nat) : Pos.of_nat (pred n) = Pos.pred (Pos.of_nat n).
Proof.
 destruct n as [|[|n]]; trivial. simpl. now rewrite Pos.pred_succ.
Qed.

Lemma inj_add (n m : nat) : n<>0 -> m<>0 ->
 Pos.of_nat (n+m) = (Pos.of_nat n + Pos.of_nat m)%positive.
Proof.
intros Hn Hm. apply Pos2Nat.inj.
rewrite Pos2Nat.inj_add, !id; trivial.
intros H. destruct n. now destruct Hn. now simpl in H.
Qed.

Lemma inj_mul (n m : nat) : n<>0 -> m<>0 ->
 Pos.of_nat (n*m) = (Pos.of_nat n * Pos.of_nat m)%positive.
Proof.
intros Hn Hm. apply Pos2Nat.inj.
rewrite Pos2Nat.inj_mul, !id; trivial.
intros H. apply mult_is_O in H. destruct H. now elim Hn. now elim Hm.
Qed.

Lemma inj_compare (n m : nat) : n<>0 -> m<>0 ->
 nat_compare n m = (Pos.of_nat n ?= Pos.of_nat m).
Proof.
intros Hn Hm. rewrite Pos2Nat.inj_compare, !id; trivial.
Qed.

Lemma inj_sub (n m : nat) : m<>0 ->
 Pos.of_nat (n-m) = (Pos.of_nat n - Pos.of_nat m)%positive.
Proof.
 intros Hm.
 apply Pos2Nat.inj.
 rewrite Pos2Nat.inj_sub_max.
 rewrite (id m) by trivial. rewrite !id_max.
 destruct n, m; trivial.
Qed.

Lemma inj_min (n m : nat) :
 Pos.of_nat (min n m) = Pos.min (Pos.of_nat n) (Pos.of_nat m).
Proof.
 destruct n as [|n]. simpl. symmetry. apply Pos.min_l, Pos.le_1_l.
 destruct m as [|m]. simpl. symmetry. apply Pos.min_r, Pos.le_1_l.
 unfold Pos.min. rewrite <- inj_compare by easy.
 case nat_compare_spec; intros H; f_equal; apply min_l || apply min_r.
 rewrite H; auto. now apply lt_le_weak. now apply lt_le_weak.
Qed.

Lemma inj_max (n m : nat) :
 Pos.of_nat (max n m) = Pos.max (Pos.of_nat n) (Pos.of_nat m).
Proof.
 destruct n as [|n]. simpl. symmetry. apply Pos.max_r, Pos.le_1_l.
 destruct m as [|m]. simpl. symmetry. apply Pos.max_l, Pos.le_1_l.
 unfold Pos.max. rewrite <- inj_compare by easy.
 case nat_compare_spec; intros H; f_equal; apply max_l || apply max_r.
 rewrite H; auto. now apply lt_le_weak. now apply lt_le_weak.
Qed.

End Nat2Pos.

(**********************************************************************)
(** Properties of the shifted injection from Peano natural numbers
    to binary positive numbers *)

Module Pos2SuccNat.

(** Composition of [Pos.to_nat] and [Pos.of_succ_nat] is successor
    on [positive] *)

Theorem id_succ p : Pos.of_succ_nat (Pos.to_nat p) = Pos.succ p.
Proof.
rewrite Pos.of_nat_succ, <- Pos2Nat.inj_succ. apply Pos2Nat.id.
Qed.

(** Composition of [Pos.to_nat], [Pos.of_succ_nat] and [Pos.pred]
    is identity on [positive] *)

Theorem pred_id p : Pos.pred (Pos.of_succ_nat (Pos.to_nat p)) = p.
Proof.
now rewrite id_succ, Pos.pred_succ.
Qed.

End Pos2SuccNat.

Module SuccNat2Pos.

(** Composition of [Pos.of_succ_nat] and [Pos.to_nat] is successor on [nat] *)

Theorem id_succ (n:nat) : Pos.to_nat (Pos.of_succ_nat n) = S n.
Proof.
rewrite Pos.of_nat_succ. now apply Nat2Pos.id.
Qed.

Theorem pred_id (n:nat) : pred (Pos.to_nat (Pos.of_succ_nat n)) = n.
Proof.
now rewrite id_succ.
Qed.

(** [Pos.of_succ_nat] is hence injective *)

Lemma inj (n m : nat) : Pos.of_succ_nat n = Pos.of_succ_nat m -> n = m.
Proof.
 intro H. apply (f_equal Pos.to_nat) in H. rewrite !id_succ in H.
 now injection H.
Qed.

Lemma inj_iff (n m : nat) : Pos.of_succ_nat n = Pos.of_succ_nat m <-> n = m.
Proof.
 split. apply inj. intros; now subst.
Qed.

(** Another formulation *)

Theorem inv n p : Pos.to_nat p = S n -> Pos.of_succ_nat n = p.
Proof.
 intros H. apply Pos2Nat.inj. now rewrite id_succ.
Qed.

(** Successor and comparison are morphisms with respect to
    [Pos.of_succ_nat] *)

Lemma inj_succ n : Pos.of_succ_nat (S n) = Pos.succ (Pos.of_succ_nat n).
Proof.
apply Pos2Nat.inj. now rewrite Pos2Nat.inj_succ, !id_succ.
Qed.

Lemma inj_compare n m :
 nat_compare n m = (Pos.of_succ_nat n ?= Pos.of_succ_nat m).
Proof.
rewrite Pos2Nat.inj_compare, !id_succ; trivial.
Qed.

(** Other operations, for instance [Pos.add] and [plus] aren't
    directly related this way (we would need to compensate for
    the successor hidden in [Pos.of_succ_nat] *)

End SuccNat2Pos.

(** For compatibility, old names and old-style lemmas *)

Notation Psucc_S := Pos2Nat.inj_succ (compat "8.3").
Notation Pplus_plus := Pos2Nat.inj_add (compat "8.3").
Notation Pmult_mult := Pos2Nat.inj_mul (compat "8.3").
Notation Pcompare_nat_compare := Pos2Nat.inj_compare (compat "8.3").
Notation nat_of_P_xH := Pos2Nat.inj_1 (compat "8.3").
Notation nat_of_P_xO := Pos2Nat.inj_xO (compat "8.3").
Notation nat_of_P_xI := Pos2Nat.inj_xI (compat "8.3").
Notation nat_of_P_is_S := Pos2Nat.is_succ (compat "8.3").
Notation nat_of_P_pos := Pos2Nat.is_pos (compat "8.3").
Notation nat_of_P_inj_iff := Pos2Nat.inj_iff (compat "8.3").
Notation nat_of_P_inj := Pos2Nat.inj (compat "8.3").
Notation Plt_lt := Pos2Nat.inj_lt (compat "8.3").
Notation Pgt_gt := Pos2Nat.inj_gt (compat "8.3").
Notation Ple_le := Pos2Nat.inj_le (compat "8.3").
Notation Pge_ge := Pos2Nat.inj_ge (compat "8.3").
Notation Pminus_minus := Pos2Nat.inj_sub (compat "8.3").
Notation iter_nat_of_P := @Pos2Nat.inj_iter (compat "8.3").

Notation nat_of_P_of_succ_nat := SuccNat2Pos.id_succ (compat "8.3").
Notation P_of_succ_nat_of_P := Pos2SuccNat.id_succ (compat "8.3").

Notation nat_of_P_succ_morphism := Pos2Nat.inj_succ (compat "8.3").
Notation nat_of_P_plus_morphism := Pos2Nat.inj_add (compat "8.3").
Notation nat_of_P_mult_morphism := Pos2Nat.inj_mul (compat "8.3").
Notation nat_of_P_compare_morphism := Pos2Nat.inj_compare (compat "8.3").
Notation lt_O_nat_of_P := Pos2Nat.is_pos (compat "8.3").
Notation ZL4 := Pos2Nat.is_succ (compat "8.3").
Notation nat_of_P_o_P_of_succ_nat_eq_succ := SuccNat2Pos.id_succ (compat "8.3").
Notation P_of_succ_nat_o_nat_of_P_eq_succ := Pos2SuccNat.id_succ (compat "8.3").
Notation pred_o_P_of_succ_nat_o_nat_of_P_eq_id := Pos2SuccNat.pred_id (compat "8.3").

Lemma nat_of_P_minus_morphism p q :
 Pos.compare_cont p q Eq = Gt ->
  Pos.to_nat (p - q) = Pos.to_nat p - Pos.to_nat q.
Proof (fun H => Pos2Nat.inj_sub p q (Pos.gt_lt _ _ H)).

Lemma nat_of_P_lt_Lt_compare_morphism p q :
 Pos.compare_cont p q Eq = Lt -> Pos.to_nat p < Pos.to_nat q.
Proof (proj1 (Pos2Nat.inj_lt p q)).

Lemma nat_of_P_gt_Gt_compare_morphism p q :
 Pos.compare_cont p q Eq = Gt -> Pos.to_nat p > Pos.to_nat q.
Proof (proj1 (Pos2Nat.inj_gt p q)).

Lemma nat_of_P_lt_Lt_compare_complement_morphism p q :
 Pos.to_nat p < Pos.to_nat q -> Pos.compare_cont p q Eq = Lt.
Proof (proj2 (Pos2Nat.inj_lt p q)).

Definition nat_of_P_gt_Gt_compare_complement_morphism p q :
 Pos.to_nat p > Pos.to_nat q -> Pos.compare_cont p q Eq = Gt.
Proof (proj2 (Pos2Nat.inj_gt p q)).

(** Old intermediate results about [Pmult_nat] *)

Section ObsoletePmultNat.

Lemma Pmult_nat_mult : forall p n,
 Pmult_nat p n = Pos.to_nat p * n.
Proof.
 induction p; intros n; unfold Pos.to_nat; simpl.
 f_equal. rewrite 2 IHp. rewrite <- mult_assoc.
  f_equal. simpl. now rewrite <- plus_n_O.
 rewrite 2 IHp. rewrite <- mult_assoc.
  f_equal. simpl. now rewrite <- plus_n_O.
 simpl. now rewrite <- plus_n_O.
Qed.

Lemma Pmult_nat_succ_morphism :
 forall p n, Pmult_nat (Pos.succ p) n = n + Pmult_nat p n.
Proof.
 intros. now rewrite !Pmult_nat_mult, Pos2Nat.inj_succ.
Qed.

Theorem Pmult_nat_l_plus_morphism :
 forall p q n, Pmult_nat (p + q) n = Pmult_nat p n + Pmult_nat q n.
Proof.
 intros. rewrite !Pmult_nat_mult, Pos2Nat.inj_add. apply mult_plus_distr_r.
Qed.

Theorem Pmult_nat_plus_carry_morphism :
 forall p q n, Pmult_nat (Pos.add_carry p q) n = n + Pmult_nat (p + q) n.
Proof.
 intros. now rewrite Pos.add_carry_spec, Pmult_nat_succ_morphism.
Qed.

Lemma Pmult_nat_r_plus_morphism :
 forall p n, Pmult_nat p (n + n) = Pmult_nat p n + Pmult_nat p n.
Proof.
 intros. rewrite !Pmult_nat_mult. apply mult_plus_distr_l.
Qed.

Lemma ZL6 : forall p, Pmult_nat p 2 = Pos.to_nat p + Pos.to_nat p.
Proof.
 intros. rewrite Pmult_nat_mult, mult_comm. simpl. now rewrite <- plus_n_O.
Qed.

Lemma le_Pmult_nat : forall p n, n <= Pmult_nat p n.
Proof.
 intros. rewrite Pmult_nat_mult.
 apply le_trans with (1*n). now rewrite mult_1_l.
 apply mult_le_compat_r. apply Pos2Nat.is_pos.
Qed.

End ObsoletePmultNat.
