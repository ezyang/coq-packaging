(************************************************************************)
(*  v      *   The Coq Proof Assistant  /  The Coq Development Team     *)
(* <O___,, * CNRS-Ecole Polytechnique-INRIA Futurs-Universite Paris Sud *)
(*   \VV/  **************************************************************)
(*    //   *      This file is distributed under the terms of the       *)
(*         *       GNU Lesser General Public License Version 2.1        *)
(************************************************************************)

(* $Id: retyping.ml,v 1.43.2.1 2004/07/16 19:30:46 herbelin Exp $ *)

open Util
open Term
open Inductive
open Names
open Reductionops
open Environ
open Typeops
open Declarations
open Instantiate

let outsort env sigma t =
  match kind_of_term (whd_betadeltaiota env sigma t) with
    | Sort s -> s
    | _ -> anomaly "Retyping: found a type of type which is not a sort"

let rec subst_type env sigma typ = function
  | [] -> typ
  | h::rest ->
      match kind_of_term (whd_betadeltaiota env sigma typ) with
        | Prod (na,c1,c2) -> subst_type env sigma (subst1 h c2) rest
        | _ -> anomaly "Non-functional construction"

(* Si ft est le type d'un terme f, lequel est appliqu� � args, *)
(* [sort_of_atomic_ty] calcule ft[args] qui doit �tre une sorte *)
(* On suit une m�thode paresseuse, en esp�rant que ft est une arit� *)
(* et sinon on substitue *)

let sort_of_atomic_type env sigma ft args =
  let rec concl_of_arity env ar =
    match kind_of_term (whd_betadeltaiota env sigma ar) with
      | Prod (na, t, b) -> concl_of_arity (push_rel (na,None,t) env) b
      | Sort s -> s
      | _ -> outsort env sigma (subst_type env sigma ft (Array.to_list args))
  in concl_of_arity env ft

let typeur sigma metamap =
  let rec type_of env cstr=
    match kind_of_term cstr with
    | Meta n ->
          (try strip_outer_cast (List.assoc n metamap)
           with Not_found -> anomaly "type_of: this is not a well-typed term")
    | Rel n ->
        let (_,_,ty) = lookup_rel n env in
        lift n ty
    | Var id ->
        (try
          let (_,_,ty) = lookup_named id env in
          body_of_type ty
        with Not_found ->
          anomaly ("type_of: variable "^(string_of_id id)^" unbound"))
    | Const c ->
        let cb = lookup_constant c env in
        body_of_type cb.const_type
    | Evar ev -> existential_type sigma ev
    | Ind ind -> body_of_type (type_of_inductive env ind)
    | Construct cstr -> body_of_type (type_of_constructor env cstr)
    | Case (_,p,c,lf) ->
        let Inductiveops.IndType(_,realargs) =
          try Inductiveops.find_rectype env sigma (type_of env c)
          with Not_found -> anomaly "type_of: Bad recursive type" in
        let t = whd_beta (applist (p, realargs)) in
        (match kind_of_term (whd_betadeltaiota env sigma (type_of env t)) with
          | Prod _ -> whd_beta (applist (t, [c]))
          | _ -> t)
    | Lambda (name,c1,c2) ->
          mkProd (name, c1, type_of (push_rel (name,None,c1) env) c2)
    | LetIn (name,b,c1,c2) ->
         subst1 b (type_of (push_rel (name,Some b,c1) env) c2)
    | Fix ((_,i),(_,tys,_)) -> tys.(i)
    | CoFix (i,(_,tys,_)) -> tys.(i)
    | App(f,args)->
        strip_outer_cast
          (subst_type env sigma (type_of env f) (Array.to_list args))
    | Cast (c,t) -> t
    | Sort _ | Prod _ -> mkSort (sort_of env cstr)

  and sort_of env t = 
    match kind_of_term t with
    | Cast (c,s) when isSort s -> destSort s
    | Sort (Prop c) -> type_0
    | Sort (Type u) -> Type (Univ.super u)
    | Prod (name,t,c2) ->
        (match (sort_of env t, sort_of (push_rel (name,None,t) env) c2) with
	  | _, (Prop Null as s) -> s
          | Prop _, (Prop Pos as s) -> s
          | Type _, (Prop Pos as s) when
              Environ.engagement env = Some ImpredicativeSet -> s
          | Type _ as s, Prop Pos -> s
	  | _, (Type u2 as s) -> s (*Type Univ.dummy_univ*))
    | App(f,args) -> sort_of_atomic_type env sigma (type_of env f) args
    | Lambda _ | Fix _ | Construct _ ->
        anomaly "sort_of: Not a type (1)"
    | _ -> outsort env sigma (type_of env t)

  and sort_family_of env t =
    match kind_of_term t with
    | Cast (c,s) when isSort s -> family_of_sort (destSort s)
    | Sort (Prop c) -> InType
    | Sort (Type u) -> InType
    | Prod (name,t,c2) -> sort_family_of (push_rel (name,None,t) env) c2
    | App(f,args) -> 
       family_of_sort (sort_of_atomic_type env sigma (type_of env f) args)
    | Lambda _ | Fix _ | Construct _ ->
        anomaly "sort_of: Not a type (1)"
    | _ -> family_of_sort (outsort env sigma (type_of env t))

  in type_of, sort_of, sort_family_of

let get_type_of env sigma c = let f,_,_ = typeur sigma [] in f env c
let get_sort_of env sigma t = let _,f,_ = typeur sigma [] in f env t
let get_sort_family_of env sigma c = let _,_,f = typeur sigma [] in f env c

let get_type_of_with_meta env sigma metamap = 
  let f,_,_ = typeur sigma metamap in f env

(* Makes an assumption from a constr *)
let get_assumption_of env evc c = c

(* Makes an unsafe judgment from a constr *)
let get_judgment_of env evc c = { uj_val = c; uj_type = get_type_of env evc c }

