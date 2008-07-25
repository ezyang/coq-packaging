(************************************************************************)
(*  v      *   The Coq Proof Assistant  /  The Coq Development Team     *)
(* <O___,, * CNRS-Ecole Polytechnique-INRIA Futurs-Universite Paris Sud *)
(*   \VV/  **************************************************************)
(*    //   *      This file is distributed under the terms of the       *)
(*         *       GNU Lesser General Public License Version 2.1        *)
(************************************************************************)
(*                                                                      *)
(* Micromega: A reflexive tactic using the Positivstellensatz           *)
(*                                                                      *)
(*  Frédéric Besson (Irisa/Inria) 2006-2008                             *)
(*                                                                      *)
(************************************************************************)

(* We take as input a list of polynomials [p1...pn] and return an unfeasibility
   certificate polynomial. *)

(*open Micromega.Polynomial*)
open Big_int
open Num

module Mc = Micromega
module Ml2C = Mutils.CamlToCoq
module C2Ml = Mutils.CoqToCaml

let (<+>) = add_num
let (<->) = minus_num
let (<*>) = mult_num

type var = Mc.positive

module Monomial :
sig
 type t
 val const : t
 val var : var -> t
 val find : var -> t -> int
 val mult : var -> t -> t
 val prod : t -> t -> t
 val compare : t -> t -> int
 val pp : out_channel -> t -> unit
 val fold : (var -> int -> 'a -> 'a) -> t -> 'a -> 'a
end
 =
struct
 (* A monomial is represented by a multiset of variables  *)
 module Map = Map.Make(struct type t = var let compare = Pervasives.compare end)
 open Map
 
 type t = int Map.t

 (* The monomial that corresponds to a constant *)
 let const = Map.empty
  
 (* The monomial 'x' *)
 let var x = Map.add x 1 Map.empty

 (* Get the degre of a variable in a monomial *)
 let find x m = try find x m with Not_found -> 0
  
 (* Multiply a monomial by a variable *)
 let mult x m = add x (  (find x m) + 1) m
  
 (* Product of monomials *)
 let prod m1 m2 = Map.fold (fun k d m -> add k ((find k m) + d) m) m1 m2
  
 (* Total ordering of monomials *)
 let compare m1 m2 = Map.compare Pervasives.compare m1 m2

 let pp o m = Map.iter (fun k v -> 
  if v = 1 then Printf.fprintf o "x%i." (C2Ml.index k)
  else     Printf.fprintf o "x%i^%i." (C2Ml.index k) v) m

 let fold = fold

end


module  Poly :
 (* A polynomial is a map of monomials *)
 (* 
    This is probably a naive implementation 
    (expected to be fast enough - Coq is probably the bottleneck)
    *The new ring contribution is using a sparse Horner representation.
 *)
sig
 type t
 val get : Monomial.t -> t -> num
 val variable : var -> t
 val add : Monomial.t -> num -> t -> t
 val constant : num -> t
 val mult : Monomial.t -> num -> t -> t
 val product : t -> t -> t
 val addition : t -> t -> t
 val uminus : t -> t
 val fold : (Monomial.t -> num -> 'a -> 'a) -> t -> 'a -> 'a
 val pp : out_channel -> t -> unit
 val compare : t -> t -> int
end =
struct
 (*normalisation bug : 0*x ... *)
 module P = Map.Make(Monomial)
 open P

 type t = num P.t

 let pp o p = P.iter (fun k v -> 
  if compare_num v (Int 0) <> 0
  then 
   if Monomial.compare Monomial.const k = 0
   then 	Printf.fprintf o "%s " (string_of_num v)
   else Printf.fprintf o "%s*%a " (string_of_num v) Monomial.pp k) p  

 (* Get the coefficient of monomial mn *)
 let get : Monomial.t -> t -> num = 
  fun mn p -> try find mn p with Not_found -> (Int 0)


 (* The polynomial 1.x *)
 let variable : var -> t =
  fun  x ->  add (Monomial.var x) (Int 1) empty
   
 (*The constant polynomial *)
 let constant : num -> t =
  fun c -> add (Monomial.const) c empty

 (* The addition of a monomial *)

 let add : Monomial.t -> num -> t -> t =
  fun mn v p -> 
   let vl = (get mn p) <+> v in
    add mn vl p


 (** Design choice: empty is not a polynomial 
     I do not remember why .... 
 **)

 (* The product by a monomial *)
 let mult : Monomial.t -> num -> t -> t =
  fun mn v p -> 
   fold (fun mn' v' res -> P.add (Monomial.prod mn mn') (v<*>v') res) p empty


 let  addition : t -> t -> t =
  fun p1 p2 -> fold (fun mn v p -> add mn v p) p1 p2
   

 let product : t -> t -> t =
  fun p1 p2 -> 
   fold (fun mn v res -> addition (mult mn v p2) res ) p1 empty


 let uminus : t -> t =
  fun p -> map (fun v -> minus_num v) p

 let fold = P.fold

 let compare = compare compare_num
end

open Mutils
type 'a number_spec = {
 bigint_to_number : big_int -> 'a;
 number_to_num : 'a  -> num;
 zero : 'a;
 unit : 'a;
 mult : 'a -> 'a -> 'a;
 eqb  : 'a -> 'a -> Mc.bool
}

let z_spec = {
 bigint_to_number = Ml2C.bigint ;
 number_to_num = (fun x -> Big_int (C2Ml.z_big_int x));
 zero = Mc.Z0;
 unit = Mc.Zpos Mc.XH;
 mult = Mc.zmult;
 eqb  = Mc.zeq_bool
}
 

let q_spec = {
 bigint_to_number = (fun x -> {Mc.qnum = Ml2C.bigint x; Mc.qden = Mc.XH});
 number_to_num = C2Ml.q_to_num;
 zero = {Mc.qnum = Mc.Z0;Mc.qden = Mc.XH};
 unit = {Mc.qnum =  (Mc.Zpos Mc.XH) ; Mc.qden = Mc.XH};
 mult = Mc.qmult;
 eqb  = Mc.qeq_bool
}

let r_spec = z_spec




let dev_form n_spec  p =
 let rec dev_form p = 
  match p with
   | Mc.PEc z ->  Poly.constant (n_spec.number_to_num z)
   | Mc.PEX v ->  Poly.variable v
   | Mc.PEmul(p1,p2) -> 
      let p1 = dev_form p1 in
      let p2 = dev_form p2 in
       Poly.product p1 p2 
   | Mc.PEadd(p1,p2) -> Poly.addition (dev_form p1) (dev_form p2)
   | Mc.PEopp p ->  Poly.uminus (dev_form p)
   | Mc.PEsub(p1,p2) ->  Poly.addition (dev_form p1) (Poly.uminus (dev_form p2))
   | Mc.PEpow(p,n)   ->  
      let p = dev_form p in
      let n = C2Ml.n n in
      let rec pow n = 
       if n = 0 
       then Poly.constant (n_spec.number_to_num n_spec.unit)
       else Poly.product p (pow (n-1)) in
       pow n in
  dev_form p


let monomial_to_polynomial mn = 
 Monomial.fold 
  (fun v i acc -> 
   let mn = if i = 1 then Mc.PEX v else Mc.PEpow (Mc.PEX v ,Ml2C.n i) in
    if acc = Mc.PEc (Mc.Zpos Mc.XH)
    then mn 
    else Mc.PEmul(mn,acc))
  mn 
  (Mc.PEc (Mc.Zpos Mc.XH))
  
let list_to_polynomial vars l = 
 assert (List.for_all (fun x -> ceiling_num x =/ x) l);
 let var x = monomial_to_polynomial (List.nth vars x)  in 
 let rec xtopoly p i = function
  | [] -> p
  | c::l -> if c =/  (Int 0) then xtopoly p (i+1) l 
    else let c = Mc.PEc (Ml2C.bigint (numerator c)) in
    let mn = 
     if c =  Mc.PEc (Mc.Zpos Mc.XH)
     then var i
     else Mc.PEmul (c,var i) in
    let p' = if p = Mc.PEc Mc.Z0 then mn else
      Mc.PEadd (mn, p) in
     xtopoly p' (i+1) l in
  
  xtopoly (Mc.PEc Mc.Z0) 0 l

let rec fixpoint f x =
 let y' = f x in
  if y' = x then y'
  else fixpoint f y'








let  rec_simpl_cone n_spec e = 
 let simpl_cone = 
  Mc.simpl_cone n_spec.zero n_spec.unit n_spec.mult n_spec.eqb in

 let rec rec_simpl_cone  = function
 | Mc.S_Mult(t1, t2) -> 
    simpl_cone  (Mc.S_Mult (rec_simpl_cone t1, rec_simpl_cone t2))
 | Mc.S_Add(t1,t2)  -> 
    simpl_cone (Mc.S_Add (rec_simpl_cone t1, rec_simpl_cone t2))
 |  x           -> simpl_cone x in
  rec_simpl_cone e
   
   
let simplify_cone n_spec c = fixpoint (rec_simpl_cone n_spec) c
 
type cone_prod = 
  Const of cone 
  | Ideal of cone *cone 
  | Mult of cone * cone 
  | Other of cone
and cone =   Mc.zWitness



let factorise_linear_cone c =
 
 let rec cone_list  c l = 
  match c with
   | Mc.S_Add (x,r) -> cone_list  r (x::l)
   |  _        ->  c :: l in
  
 let factorise c1 c2 =
  match c1 , c2 with
   | Mc.S_Ideal(x,y) , Mc.S_Ideal(x',y') -> 
      if x = x' then Some (Mc.S_Ideal(x, Mc.S_Add(y,y'))) else None
   | Mc.S_Mult(x,y) , Mc.S_Mult(x',y') -> 
      if x = x' then Some (Mc.S_Mult(x, Mc.S_Add(y,y'))) else None
   |  _     -> None in
  
 let rec rebuild_cone l pending  =
  match l with
   | [] -> (match pending with
      | None -> Mc.S_Z
      | Some p -> p
     )
   | e::l -> 
      (match pending with
       | None -> rebuild_cone l (Some e) 
       | Some p -> (match factorise p e with
	  | None -> Mc.S_Add(p, rebuild_cone l (Some e))
	  | Some f -> rebuild_cone l (Some f) )
      ) in

  (rebuild_cone (List.sort Pervasives.compare (cone_list c [])) None)



(* The binding with Fourier might be a bit obsolete 
   -- how does it handle equalities ? *)

(* Certificates are elements of the cone such that P = 0  *)

(* To begin with, we search for certificates of the form:
   a1.p1 + ... an.pn + b1.q1 +... + bn.qn + c = 0   
   where pi >= 0 qi > 0
   ai >= 0 
   bi >= 0
   Sum bi + c >= 1
   This is a linear problem: each monomial is considered as a variable.
   Hence, we can use fourier.

   The variable c is at index 0
*)

open Mfourier
   (*module Fourier = Fourier(Vector.VList)(SysSet(Vector.VList))*)
   (*module Fourier = Fourier(Vector.VSparse)(SysSetAlt(Vector.VSparse))*)
module Fourier = Mfourier.Fourier(Vector.VSparse)(*(SysSetAlt(Vector.VMap))*)

module Vect = Fourier.Vect
open Fourier.Cstr

(* fold_left followed by a rev ! *)

let constrain_monomial mn l  = 
 let coeffs = List.fold_left (fun acc p -> (Poly.get mn p)::acc) [] l in
  if mn = Monomial.const
  then  
   { coeffs = Vect.from_list ((Big_int unit_big_int):: (List.rev coeffs)) ; 
     op = Eq ; 
     cst = Big_int zero_big_int  }
  else
   { coeffs = Vect.from_list ((Big_int zero_big_int):: (List.rev coeffs)) ; 
     op = Eq ; 
     cst = Big_int zero_big_int  }

    
let positivity l = 
 let rec xpositivity i l = 
  match l with
   | [] -> []
   | (_,Mc.Equal)::l -> xpositivity (i+1) l
   | (_,_)::l -> 
      {coeffs = Vect.update (i+1) (fun _ -> Int 1) Vect.null ; 
       op = Ge ; 
       cst = Int 0 }  :: (xpositivity (i+1) l)
 in
  xpositivity 0 l


let string_of_op = function
 | Mc.Strict -> "> 0" 
 | Mc.NonStrict -> ">= 0" 
 | Mc.Equal -> "= 0"
 | Mc.NonEqual -> "<> 0"



(* If the certificate includes at least one strict inequality, 
   the obtained polynomial can also be 0 *)
let build_linear_system l =

 (* Gather the monomials:  HINT add up of the polynomials *)
 let l' = List.map fst l in
 let monomials = 
  List.fold_left (fun acc p -> Poly.addition p acc) (Poly.constant (Int 0)) l'
 in  (* For each monomial, compute a constraint *)
 let s0 = 
  Poly.fold (fun mn _ res -> (constrain_monomial mn l')::res) monomials [] in
  (* I need at least something strictly positive *)
 let strict = {
  coeffs = Vect.from_list ((Big_int unit_big_int)::
			    (List.map (fun (x,y) -> 
			     match y with Mc.Strict -> 
			      Big_int unit_big_int 
			      | _ -> Big_int zero_big_int) l));
  op = Ge ; cst = Big_int unit_big_int } in
  (* Add the positivity constraint *)
  {coeffs = Vect.from_list ([Big_int unit_big_int]) ; 
   op = Ge ; 
   cst = Big_int zero_big_int}::(strict::(positivity l)@s0)


let big_int_to_z = Ml2C.bigint
 
(* For Q, this is a pity that the certificate has been scaled 
   -- at a lower layer, certificates are using nums... *)
let make_certificate n_spec cert li = 
 let bint_to_cst = n_spec.bigint_to_number in
  match cert with
   | [] -> None
   | e::cert' -> 
      let cst = match compare_big_int e zero_big_int with
       | 0 -> Mc.S_Z
       | 1 ->  Mc.S_Pos (bint_to_cst e) 
       | _ -> failwith "positivity error" 
      in
      let rec scalar_product cert l =
       match cert with
	| [] -> Mc.S_Z
	| c::cert -> match l with
	   | [] -> failwith "make_certificate(1)"
	   | i::l ->  
	      let r = scalar_product cert l in
	       match compare_big_int c  zero_big_int with
		| -1 -> Mc.S_Add (
		   Mc.S_Ideal (Mc.PEc ( bint_to_cst c), Mc.S_In (Ml2C.nat i)), 
		   r)
		| 0  -> r
		| _ ->  Mc.S_Add (
		   Mc.S_Mult (Mc.S_Pos (bint_to_cst c), Mc.S_In (Ml2C.nat i)),
		   r) in
       
      Some ((factorise_linear_cone 
	      (simplify_cone n_spec (Mc.S_Add (cst, scalar_product cert' li)))))


exception Found of Monomial.t
 
let raw_certificate l = 
 let sys = build_linear_system l in
  try 
   match Fourier.find_point sys with
    | None -> None
    | Some cert ->  Some (rats_to_ints (Vect.to_list cert)) 
       (* should not use rats_to_ints *)
  with x -> 
   if debug 
   then (Printf.printf "raw certificate %s" (Printexc.to_string x);   
	 flush stdout) ;
   None


let simple_linear_prover to_constant l =
 let (lc,li) = List.split l in
  match raw_certificate lc with
   |  None -> None (* No certificate *)
   | Some cert -> make_certificate to_constant cert li
      
      

let linear_prover n_spec l  =
 let li = List.combine l (interval 0 (List.length l -1)) in
 let (l1,l') = List.partition 
  (fun (x,_) -> if snd' x = Mc.NonEqual then true else false) li in
 let l' = List.map 
  (fun (c,i) -> let (Mc.Pair(x,y)) = c in 
		 match y with 
		   Mc.NonEqual -> failwith "cannot happen" 
		  |  y -> ((dev_form n_spec x, y),i)) l' in
  
  simple_linear_prover n_spec l' 


let linear_prover n_spec l  =
 try linear_prover n_spec l with
   x -> (print_string (Printexc.to_string x); None)

(* zprover.... *)

(* I need to gather the set of variables --->
   Then go for fold 
   Once I have an interval, I need a certificate : 2 other fourier elims.
   (I could probably get the certificate directly 
   as it is done in the fourier contrib.)
*)

let make_linear_system l =
 let l' = List.map fst l in
 let monomials = List.fold_left (fun acc p -> Poly.addition p acc) 
  (Poly.constant (Int 0)) l' in
 let monomials = Poly.fold 
  (fun mn _ l -> if mn = Monomial.const then l else mn::l) monomials [] in
  (List.map (fun (c,op) -> 
   {coeffs = Vect.from_list (List.map (fun mn ->  (Poly.get mn c)) monomials) ; 
    op = op ; 
    cst = minus_num ( (Poly.get Monomial.const c))}) l
    ,monomials)


open Interval 
let pplus x y = Mc.PEadd(x,y)
let pmult x y = Mc.PEmul(x,y)
let pconst x = Mc.PEc x
let popp x = Mc.PEopp x
 
let debug = false
 
(* keep track of enumerated vectors *)
let rec mem p x  l = 
 match l with  [] -> false | e::l -> if p x e then true else mem p x l

let rec remove_assoc p x l = 
 match l with [] -> [] | e::l -> if p x (fst e) then
  remove_assoc p x l else e::(remove_assoc p x l) 

let eq x y = Vect.compare x y = 0

(* Beurk... this code is a shame *)

let rec zlinear_prover sys = xzlinear_prover [] sys

and xzlinear_prover enum l :  (Mc.proofTerm option) = 
 match linear_prover z_spec l with
  | Some prf ->  Some (Mc.RatProof prf)
  | None     ->  
     let ll = List.fold_right (fun (Mc.Pair(e,k)) r -> match k with 
       Mc.NonEqual -> r  
      | k -> (dev_form z_spec e , 
	     match k with
	      | Mc.Strict | Mc.NonStrict -> Ge 
		 (* Loss of precision -- weakness of fourier*)
	      | Mc.Equal              -> Eq
	      | Mc.NonEqual -> failwith "Cannot happen") :: r) l [] in

     let (sys,var) = make_linear_system ll in
     let res = 
      match Fourier.find_Q_interval sys with
       | Some(i,x,j) -> if i =/ j 
	 then Some(i,Vect.set x (Int 1) Vect.null,i) else None 
       | None -> None in
     let res = match res with
      | None ->
	 begin
	  let candidates = List.fold_right 
	   (fun cstr acc -> 
	    let gcd = Big_int (Vect.gcd cstr.coeffs) in
	    let vect = Vect.mul (Int 1 // gcd) cstr.coeffs in
	     if mem eq vect enum then acc
	     else ((vect,Fourier.optimise vect sys)::acc)) sys [] in
	  let candidates = List.fold_left (fun l (x,i) -> 
	   match i with 
	     None -> (x,Empty)::l 
	    | Some i ->  (x,i)::l) [] (candidates) in
	   match List.fold_left (fun (x1,i1) (x2,i2) -> 
	    if smaller_itv i1 i2 
	    then (x1,i1) else (x2,i2)) (Vect.null,Itv(None,None)) candidates 
	   with
	    | (i,Empty) -> None
	    | (x,Itv(Some i, Some j))  -> Some(i,x,j)
	    | (x,Point n) ->  Some(n,x,n)
	    |   x        ->   match Fourier.find_Q_interval sys with
		 | None -> None
		 | Some(i,x,j) -> 
		    if i =/ j 
		    then Some(i,Vect.set x (Int 1) Vect.null,i) 
		    else None 
	 end
      |   _ -> res in

      match res with 
       | Some (lb,e,ub) -> 
	  let (lbn,lbd) = 
	   (Ml2C.bigint (sub_big_int (numerator lb)  unit_big_int),
	   Ml2C.bigint (denominator lb)) in
	  let (ubn,ubd) = 
	   (Ml2C.bigint (add_big_int unit_big_int (numerator ub)) , 
	   Ml2C.bigint (denominator ub)) in
	  let expr = list_to_polynomial var (Vect.to_list e) in
	   (match 
	     (*x <= ub ->  x  > ub *)
	     linear_prover  z_spec 
	      (Mc.Pair(pplus (pmult (pconst ubd) expr) (popp (pconst  ubn)),
		      Mc.NonStrict) :: l),
	    (* lb <= x  -> lb > x *)
	    linear_prover z_spec 
	     (Mc.Pair( pplus  (popp (pmult  (pconst lbd) expr)) (pconst lbn) ,  
		     Mc.NonStrict)::l) 
	    with
	     | Some cub , Some clb  ->   
		(match zlinear_enum (e::enum)   expr 
		  (ceiling_num lb)  (floor_num ub) l 
		 with
		 | None -> None
		 | Some prf -> 
		    Some (Mc.EnumProof(Ml2C.q lb,expr,Ml2C.q ub,clb,cub,prf)))
	     | _ -> None
	   )
       |  _ -> None
and xzlinear_enum enum expr clb cub l = 
 if clb >/  cub
 then Some Mc.Nil
 else 
  let pexpr = pplus (popp (pconst (Ml2C.bigint (numerator clb)))) expr in
  let sys' = (Mc.Pair(pexpr, Mc.Equal))::l in
   match xzlinear_prover enum sys' with
    | None -> if debug then print_string "zlp?"; None
    | Some prf -> if debug then print_string "zlp!";
    match zlinear_enum enum expr (clb +/ (Int 1)) cub l with
     | None -> None
     | Some prfl -> Some (Mc.Cons(prf,prfl))

and zlinear_enum enum expr clb cub l = 
 let res = xzlinear_enum enum expr clb cub l in
  if debug then Printf.printf "zlinear_enum %s %s -> %s\n" 
   (string_of_num clb) 
   (string_of_num cub) 
   (match res with
    | None -> "None"
    | Some r -> "Some") ; res

