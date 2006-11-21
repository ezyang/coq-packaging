(************************************************************************)
(*  v      *   The Coq Proof Assistant  /  The Coq Development Team     *)
(* <O___,, * CNRS-Ecole Polytechnique-INRIA Futurs-Universite Paris Sud *)
(*   \VV/  **************************************************************)
(*    //   *      This file is distributed under the terms of the       *)
(*         *       GNU Lesser General Public License Version 2.1        *)
(************************************************************************)

(* $Id: reduction.ml 9215 2006-10-05 15:40:31Z herbelin $ *)

open Util
open Names
open Term
open Univ
open Declarations
open Environ
open Closure
open Esubst

let rec is_empty_stack = function
    [] -> true
  | Zupdate _::s -> is_empty_stack s
  | Zshift _::s -> is_empty_stack s
  | _ -> false

(* Compute the lift to be performed on a term placed in a given stack *)
let el_stack el stk =
  let n =
    List.fold_left
      (fun i z ->
        match z with
            Zshift n -> i+n
          | _ -> i)
      0
      stk in
  el_shft n el

let compare_stack_shape stk1 stk2 =
  let rec compare_rec bal stk1 stk2 =
  match (stk1,stk2) with
      ([],[]) -> bal=0
    | ((Zupdate _|Zshift _)::s1, _) -> compare_rec bal s1 stk2
    | (_, (Zupdate _|Zshift _)::s2) -> compare_rec bal stk1 s2
    | (Zapp l1::s1, _) -> compare_rec (bal+Array.length l1) s1 stk2
    | (_, Zapp l2::s2) -> compare_rec (bal-Array.length l2) stk1 s2
    | (Zcase(c1,_,_)::s1, Zcase(c2,_,_)::s2) ->
        bal=0 (* && c1.ci_ind  = c2.ci_ind *) && compare_rec 0 s1 s2
    | (Zfix(_,a1)::s1, Zfix(_,a2)::s2) ->
        bal=0 && compare_rec 0 a1 a2 && compare_rec 0 s1 s2
    | (_,_) -> false in
  compare_rec 0 stk1 stk2

type lft_constr_stack_elt =
    Zlapp of (lift * fconstr) array
  | Zlfix of (lift * fconstr) * lft_constr_stack
  | Zlcase of case_info * lift * fconstr * fconstr array
and lft_constr_stack = lft_constr_stack_elt list

let rec zlapp v = function
    Zlapp v2 :: s -> zlapp (Array.append v v2) s
  | s -> Zlapp v :: s

let pure_stack lfts stk =
  let rec pure_rec lfts stk =
    match stk with
        [] -> (lfts,[])
      | zi::s ->
          (match (zi,pure_rec lfts s) with
              (Zupdate _,lpstk)  -> lpstk
            | (Zshift n,(l,pstk)) -> (el_shft n l, pstk)
            | (Zapp a, (l,pstk)) ->
                (l,zlapp (Array.map (fun t -> (l,t)) a) pstk)
            | (Zfix(fx,a),(l,pstk)) ->
                let (lfx,pa) = pure_rec l a in
                (l, Zlfix((lfx,fx),pa)::pstk)
            | (Zcase(ci,p,br),(l,pstk)) ->
                (l,Zlcase(ci,l,p,br)::pstk)) in
  snd (pure_rec lfts stk)

(****************************************************************************)
(*                   Reduction Functions                                    *)
(****************************************************************************)

let nf_betaiota t =
  norm_val (create_clos_infos betaiota empty_env) (inject t)

let whd_betaiotazeta env x =
  match kind_of_term x with
    | (Sort _|Var _|Meta _|Evar _|Const _|Ind _|Construct _|
       Prod _|Lambda _|Fix _|CoFix _) -> x
    | _ -> whd_val (create_clos_infos betaiotazeta env) (inject x)

let whd_betadeltaiota env t = 
  match kind_of_term t with
    | (Sort _|Meta _|Evar _|Ind _|Construct _|
       Prod _|Lambda _|Fix _|CoFix _) -> t
    | _ -> whd_val (create_clos_infos betadeltaiota env) (inject t)

let whd_betadeltaiota_nolet env t = 
  match kind_of_term t with
    | (Sort _|Meta _|Evar _|Ind _|Construct _|
       Prod _|Lambda _|Fix _|CoFix _|LetIn _) -> t
    | _ -> whd_val (create_clos_infos betadeltaiotanolet env) (inject t)

(* Beta *)

let beta_appvect c v =
  let rec stacklam env t stack =
    match kind_of_term t, stack with
        Lambda(_,_,c), arg::stacktl -> stacklam (arg::env) c stacktl
      | _ -> applist (substl env t, stack) in
  stacklam [] c (Array.to_list v)

(********************************************************************)
(*                         Conversion                               *)
(********************************************************************)

(* Conversion utility functions *)
type 'a conversion_function = env -> 'a -> 'a -> Univ.constraints

exception NotConvertible
exception NotConvertibleVect of int

let compare_stacks f fmind lft1 stk1 lft2 stk2 cuniv =
  let rec cmp_rec pstk1 pstk2 cuniv =
    match (pstk1,pstk2) with
      | (z1::s1, z2::s2) ->
          let cu1 = cmp_rec s1 s2 cuniv in
          (match (z1,z2) with
            | (Zlapp a1,Zlapp a2) -> array_fold_right2 f a1 a2 cu1
            | (Zlfix(fx1,a1),Zlfix(fx2,a2)) ->
                let cu2 = f fx1 fx2 cu1 in
                cmp_rec a1 a2 cu2
            | (Zlcase(ci1,l1,p1,br1),Zlcase(ci2,l2,p2,br2)) ->
                if not (fmind ci1.ci_ind ci2.ci_ind) then
		  raise NotConvertible;
		let cu2 = f (l1,p1) (l2,p2) cu1 in
                array_fold_right2 (fun c1 c2 -> f (l1,c1) (l2,c2)) br1 br2 cu2
            | _ -> assert false)
      | _ -> cuniv in
  if compare_stack_shape stk1 stk2 then
    cmp_rec (pure_stack lft1 stk1) (pure_stack lft2 stk2) cuniv
  else raise NotConvertible

(* Convertibility of sorts *)

type conv_pb = 
  | CONV 
  | CUMUL

let sort_cmp pb s0 s1 cuniv =
  match (s0,s1) with
    | (Prop c1, Prop c2) -> if c1 = c2 then cuniv else raise NotConvertible
    | (Prop c1, Type u)  ->
        (match pb with
            CUMUL -> cuniv
          | _ -> raise NotConvertible)
    | (Type u1, Type u2) ->
	(match pb with
           | CONV -> enforce_eq u1 u2 cuniv
	   | CUMUL -> enforce_geq u2 u1 cuniv)
    | (_, _) -> raise NotConvertible


let conv_sort env s0 s1 = sort_cmp CONV s0 s1 Constraint.empty

let conv_sort_leq env s0 s1 = sort_cmp CUMUL s0 s1 Constraint.empty


(* Conversion between  [lft1]term1 and [lft2]term2 *)
let rec ccnv cv_pb infos lft1 lft2 term1 term2 cuniv = 
  Util.check_for_interrupt ();
  eqappr cv_pb infos
    (lft1, whd_stack infos term1 [])
    (lft2, whd_stack infos term2 [])
    cuniv

(* Conversion between [lft1](hd1 v1) and [lft2](hd2 v2) *)
and eqappr cv_pb infos appr1 appr2 cuniv =
  let (lft1,(hd1,v1)) = appr1 in
  let (lft2,(hd2,v2)) = appr2 in
  let el1 = el_stack lft1 v1 in
  let el2 = el_stack lft2 v2 in
  match (fterm_of hd1, fterm_of hd2) with
    (* case of leaves *)
    | (FAtom a1, FAtom a2) ->
	(match kind_of_term a1, kind_of_term a2 with
	   | (Sort s1, Sort s2) -> 
	       assert (is_empty_stack v1 && is_empty_stack v2);
	       sort_cmp cv_pb s1 s2 cuniv
	   | (Meta n, Meta m) ->
               if n=m
	       then convert_stacks infos lft1 lft2 v1 v2 cuniv
               else raise NotConvertible
	   | _ -> raise NotConvertible)
    | (FEvar (ev1,args1), FEvar (ev2,args2)) ->
        if ev1=ev2 then
          let u1 = convert_stacks infos lft1 lft2 v1 v2 cuniv in
          convert_vect infos el1 el2 args1 args2 u1
        else raise NotConvertible

    (* 2 index known to be bound to no constant *)
    | (FRel n, FRel m) ->
        if reloc_rel n el1 = reloc_rel m el2
        then convert_stacks infos lft1 lft2 v1 v2 cuniv
        else raise NotConvertible

    (* 2 constants, 2 local defined vars or 2 defined rels *)
    | (FFlex fl1, FFlex fl2) ->
	(try (* try first intensional equality *)
	  if fl1 = fl2
          then convert_stacks infos lft1 lft2 v1 v2 cuniv
          else raise NotConvertible
        with NotConvertible ->
          (* else the oracle tells which constant is to be expanded *)
          let (app1,app2) =
            if Conv_oracle.oracle_order fl1 fl2 then
              match unfold_reference infos fl1 with
                | Some def1 -> ((lft1, whd_stack infos def1 v1), appr2)
                | None ->
                    (match unfold_reference infos fl2 with
                      | Some def2 -> (appr1, (lft2, whd_stack infos def2 v2))
		      | None -> raise NotConvertible)
            else
	      match unfold_reference infos fl2 with
                | Some def2 -> (appr1, (lft2, whd_stack infos def2 v2))
                | None ->
                    (match unfold_reference infos fl1 with
                    | Some def1 -> ((lft1, whd_stack infos def1 v1), appr2)
		    | None -> raise NotConvertible) in
          eqappr cv_pb infos app1 app2 cuniv)

    (* only one constant, defined var or defined rel *)
    | (FFlex fl1, _)      ->
        (match unfold_reference infos fl1 with
           | Some def1 -> 
	       eqappr cv_pb infos (lft1, whd_stack infos def1 v1) appr2 cuniv
           | None -> raise NotConvertible)
    | (_, FFlex fl2)      ->
        (match unfold_reference infos fl2 with
           | Some def2 -> 
	       eqappr cv_pb infos appr1 (lft2, whd_stack infos def2 v2) cuniv
           | None -> raise NotConvertible)
	
    (* other constructors *)
    | (FLambda _, FLambda _) ->
        let (_,ty1,bd1) = destFLambda mk_clos hd1 in
        let (_,ty2,bd2) = destFLambda mk_clos hd2 in
        let u1 = ccnv CONV infos el1 el2 ty1 ty2 cuniv in
        ccnv CONV infos (el_lift el1) (el_lift el2) bd1 bd2 u1

    | (FProd (_,c1,c2), FProd (_,c'1,c'2)) ->
        assert (is_empty_stack v1 && is_empty_stack v2);
	(* Luo's system *)
        let u1 = ccnv CONV infos el1 el2 c1 c'1 cuniv in
        ccnv cv_pb infos (el_lift el1) (el_lift el2) c2 c'2 u1

    (* Inductive types:  MutInd MutConstruct Fix Cofix *)

     | (FInd ind1, FInd ind2) ->
         if mind_equiv_infos infos ind1 ind2
	 then
           convert_stacks infos lft1 lft2 v1 v2 cuniv
         else raise NotConvertible

     | (FConstruct (ind1,j1), FConstruct (ind2,j2)) ->
	 if j1 = j2 && mind_equiv_infos infos ind1 ind2
	 then
           convert_stacks infos lft1 lft2 v1 v2 cuniv
         else raise NotConvertible

     | (FFix ((op1,(_,tys1,cl1)),e1), FFix((op2,(_,tys2,cl2)),e2)) ->
	 if op1 = op2
	 then
	   let n = Array.length cl1 in
           let fty1 = Array.map (mk_clos e1) tys1 in
           let fty2 = Array.map (mk_clos e2) tys2 in
           let fcl1 = Array.map (mk_clos (subs_liftn n e1)) cl1 in
           let fcl2 = Array.map (mk_clos (subs_liftn n e2)) cl2 in
	   let u1 = convert_vect infos el1 el2 fty1 fty2 cuniv in
           let u2 =
             convert_vect infos 
		 (el_liftn n el1) (el_liftn n el2) fcl1 fcl2 u1 in
           convert_stacks infos lft1 lft2 v1 v2 u2
         else raise NotConvertible

     | (FCoFix ((op1,(_,tys1,cl1)),e1), FCoFix((op2,(_,tys2,cl2)),e2)) ->
         if op1 = op2
         then
	   let n = Array.length cl1 in
           let fty1 = Array.map (mk_clos e1) tys1 in
           let fty2 = Array.map (mk_clos e2) tys2 in
           let fcl1 = Array.map (mk_clos (subs_liftn n e1)) cl1 in
           let fcl2 = Array.map (mk_clos (subs_liftn n e2)) cl2 in
           let u1 = convert_vect infos el1 el2 fty1 fty2 cuniv in
           let u2 =
	     convert_vect infos
		 (el_liftn n el1) (el_liftn n el2) fcl1 fcl2 u1 in
           convert_stacks infos lft1 lft2 v1 v2 u2
         else raise NotConvertible

    (* Can happen because whd_stack on one arg may have side-effects
       on the other arg and coulb be no more in hnf... *)
    | ( (FLetIn _, _) | (FCases _,_) | (FApp _,_)
      | (FCLOS _, _) | (FLIFT _, _)) ->
        eqappr cv_pb infos (lft1, whd_stack infos hd1 v1) appr2 cuniv

    | ( (_, FLetIn _) | (_,FCases _) | (_,FApp _)
      | (_,FCLOS _) | (_,FLIFT _)) ->
        eqappr cv_pb infos (lft1, whd_stack infos hd1 v1) appr2 cuniv

    (* Should not happen because whd_stack unlocks references *)
    | ((FLOCKED,_) | (_,FLOCKED)) -> assert false

     | _ -> raise NotConvertible

and convert_stacks infos lft1 lft2 stk1 stk2 cuniv =
  compare_stacks
    (fun (l1,t1) (l2,t2) c -> ccnv CONV infos l1 l2 t1 t2 c)
    (mind_equiv_infos infos)
    lft1 stk1 lft2 stk2 cuniv

and convert_vect infos lft1 lft2 v1 v2 cuniv =
  let lv1 = Array.length v1 in
  let lv2 = Array.length v2 in
  if lv1 = lv2
  then 
    let rec fold n univ = 
      if n >= lv1 then univ
      else
        let u1 = ccnv CONV infos lft1 lft2 v1.(n) v2.(n) univ in
        fold (n+1) u1 in
    fold 0 cuniv
  else raise NotConvertible

let clos_fconv cv_pb env t1 t2 =
  let infos = create_clos_infos betaiotazeta env in
  ccnv cv_pb infos ELID ELID (inject t1) (inject t2) Constraint.empty

let fconv cv_pb env t1 t2 =
  if eq_constr t1 t2 then Constraint.empty
  else clos_fconv cv_pb env t1 t2

let conv_cmp = fconv
let conv = fconv CONV
let conv_leq = fconv CUMUL

let conv_leq_vecti env v1 v2 =
  array_fold_left2_i 
    (fun i c t1 t2 ->
      let c' =
        try conv_leq env t1 t2 
        with NotConvertible -> raise (NotConvertibleVect i) in
      Constraint.union c c')
    Constraint.empty
    v1
    v2

(* option for conversion *)

let vm_conv = ref fconv
let set_vm_conv f = vm_conv := f
let vm_conv cv_pb env t1 t2 = 
  try 
    !vm_conv cv_pb env t1 t2
  with Not_found | Invalid_argument _ ->
      (* If compilation fails, fall-back to closure conversion *)
      clos_fconv cv_pb env t1 t2
  

let default_conv = ref fconv 

let set_default_conv f = default_conv := f

let default_conv cv_pb env t1 t2 = 
  try 
    !default_conv cv_pb env t1 t2
  with Not_found | Invalid_argument _ ->
      (* If compilation fails, fall-back to closure conversion *)
      clos_fconv cv_pb env t1 t2
  
let default_conv_leq = default_conv CUMUL
(*
let convleqkey = Profile.declare_profile "Kernel_reduction.conv_leq";;
let conv_leq env t1 t2 =
  Profile.profile4 convleqkey conv_leq env t1 t2;;

let convkey = Profile.declare_profile "Kernel_reduction.conv";;
let conv env t1 t2 =
  Profile.profile4 convleqkey conv env t1 t2;;
*)

(********************************************************************)
(*             Special-Purpose Reduction                            *)
(********************************************************************)

(* pseudo-reduction rule:
 * [hnf_prod_app env s (Prod(_,B)) N --> B[N]
 * with an HNF on the first argument to produce a product.
 * if this does not work, then we use the string S as part of our
 * error message. *)

let hnf_prod_app env t n =
  match kind_of_term (whd_betadeltaiota env t) with
    | Prod (_,_,b) -> subst1 n b
    | _ -> anomaly "hnf_prod_app: Need a product"

let hnf_prod_applist env t nl = 
  List.fold_left (hnf_prod_app env) t nl

(* Dealing with arities *)

let dest_prod env = 
  let rec decrec env m c =
    let t = whd_betadeltaiota env c in
    match kind_of_term t with
      | Prod (n,a,c0) ->
          let d = (n,None,a) in
	  decrec (push_rel d env) (Sign.add_rel_decl d m) c0
      | _ -> m,t
  in 
  decrec env Sign.empty_rel_context

(* The same but preserving lets *)
let dest_prod_assum env = 
  let rec prodec_rec env l ty =
    let rty = whd_betadeltaiota_nolet env ty in
    match kind_of_term rty with
    | Prod (x,t,c)  ->
        let d = (x,None,t) in
	prodec_rec (push_rel d env) (Sign.add_rel_decl d l) c
    | LetIn (x,b,t,c) ->
        let d = (x,Some b,t) in
	prodec_rec (push_rel d env) (Sign.add_rel_decl d l) c
    | Cast (c,_,_)    -> prodec_rec env l c
    | _               -> l,rty
  in
  prodec_rec env Sign.empty_rel_context

let dest_arity env c =
  let l, c = dest_prod_assum env c in
  match kind_of_term c with
    | Sort s -> l,s
    | _ -> error "not an arity"

let is_arity env c =
  try
    let _ = dest_arity env c in
    true
  with UserError _ -> false

