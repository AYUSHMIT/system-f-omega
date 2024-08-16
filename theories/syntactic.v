Require Export typing.
From Equations Require Import Equations.

Lemma ty_renaming {Δ0 A k} (h : TyWt Δ0 A k):
  forall {Δ1 ξ},
    (forall i k, Lookup i Δ0 k -> Lookup (ξ i)  Δ1 k ) ->
    TyWt Δ1 (ren_Ty ξ A) k.
Proof.
  induction h; sauto l:on ctrs:TyWt.
Defined.

Lemma ty_weakening Δ A k k0 (h : TyWt Δ A k) :
  TyWt (k0 :: Δ) (ren_Ty S A) k.
Proof.
  sauto lq:on use:ty_renaming.
Qed.

Lemma ty_morphing Δ0 A k (h : TyWt Δ0 A k):
  forall Δ1 ρ,
    (forall i k, Lookup i Δ0 k -> TyWt Δ1 (ρ i) k) ->
    TyWt Δ1 (subst_Ty ρ A) k.
Proof.
  induction h; sauto l:on use:ty_weakening.
Qed.

Lemma ty_subst {Δ A B k0 k} (h : TyWt (k :: Δ) A k0) (h0 : TyWt Δ B k) :
  TyWt Δ (subst_Ty (B…) A) k0.
Proof.
  sauto lq:on use:ty_morphing.
Qed.

Equations length {A} (a : list A) : nat :=
  length nil := O ;
  length (x :: a) := S (length a).

Equations regularity {Δ Γ a A} (h : Wt Δ Γ a A) : TyWt Δ A Star :=
regularity (a := ?(VarTm i)) (A := ?(A)) (T_Var i A hwf hl) := hwf _ _ hl ;
regularity (a := ?(TmAbs a)) (A := ?(TyFun A B)) (T_Abs A a B hA ha) :=
  TyT_Fun Δ A B hA (regularity ha) ;
regularity (a := ?(TmApp b a)) (A := ?(B)) (T_App a b A B ha hb)
  with regularity hb  := { | TyT_Fun A B h0 h1 => h1} ;
regularity (T_Forall k a A ha) :=
  TyT_Forall Δ k A (regularity ha) ;
regularity (T_Inst k a A B hB ha)
  with regularity ha := { | TyT_Forall k A hA => ty_subst hA hB } ;
regularity (A := ?(B)) (T_Conv a A B ha hB hAB) := hB.

(* Lemma regularity_irrel {Δ Γ a A} (h h0 : Wt Δ Γ a A ) : *)
(*   regularity h = regularity h0. *)
(* Proof. *)
(*   move : h0. *)
(*   funelim (regularity h). *)
(*   - move => h0. *)
(*     funelim (regularity h0). *)
(*     simp regularity. *)
(*     move : hwf hwf0. *)
(*     rewrite /BasisWf. *)

(*   admit. *)
(*   ad *)

Fixpoint int_kind k :=
  match k with
  | Star => Prop
  | Arr k0 k1 => int_kind k0 -> int_kind k1
  end.

Definition ty_val Δ :=
  forall i k (l : Lookup i Δ k), int_kind k.

Equations V_Nil : ty_val nil := V_Nil i k !.

Equations V_Cons {Δ k} (h : int_kind k) (ξ : ty_val Δ) : ty_val (k :: Δ) :=
  V_Cons h ξ ?(0) ?(k) (Here k Δ) := h ;
  V_Cons h ξ ?(S n) ?(k0) (There n Δ0 k0 k1 l) := ξ n k0 l.

Definition ty_val_ren {Δ Δ'}
  (ξ : ty_val Δ') f
  (hf : forall i k, Lookup i Δ k -> Lookup (f i) Δ' k) : ty_val Δ :=
  fun i k l => ξ (f i) k (hf _ _ l).

Lemma int_type {Δ A k} (h : TyWt Δ A k) (ξ : ty_val Δ) : int_kind k.
Proof.
  induction h.
  - apply : ξ l.
  - intros s0; apply : IHh (V_Cons s0 ξ).
  - apply : IHh1 ξ (IHh2 ξ).
  - apply : (IHh1 ξ -> IHh2 ξ).
  - apply : (forall (a : int_kind k), IHh (V_Cons a ξ)).
Defined.

Lemma kind_unique Δ A k (h0 : TyWt Δ A k ) : forall k0, TyWt Δ A k0 -> k = k0.
Proof.
  induction h0; hauto lq:on rew:off inv:TyWt use:@lookup_functional.
Qed.

Derive EqDec for Ki.
Set Equations With UIP.

Lemma lookup_unique {U} i (Γ : list U) A (h0 h1 : Lookup i Γ A) : h0 = h1.
  move : h1.
  induction h0; hauto lq:on dep:on inv:Lookup.
Qed.

Lemma int_type_irrel {Δ A k} (h h0 : TyWt Δ A k) (ξ : ty_val Δ) :
  int_type h ξ = int_type h0 ξ.
Proof.
  move : ξ h0.
  elim : Δ A k /h.
  - intros .
    dependent elimination h0.
    hauto lq:on use:lookup_unique.
  - intros Δ A k0 k1 t iht ξ h0.
    dependent elimination h0.
    simpl.
    extensionality x.
    apply iht.
  - intros.
    dependent elimination h0.
    simpl.
    have ? : k4 = k0 by eauto using kind_unique. subst.
    scongruence.
  - intros.
    dependent elimination h0.
    simpl.
    scongruence.
  - intros.
    dependent elimination h0.
    simpl.
    extensionality h.
    apply H.
Qed.


Lemma int_type_ren {Δ Δ' A k} (h : TyWt Δ A k)
  (ξ : ty_val Δ') f
  (hf : forall i k, Lookup i Δ k -> Lookup (f i) Δ' k) :
  int_type (ty_renaming h hf) ξ = int_type h (ty_val_ren ξ f hf).
  move : Δ' ξ f hf.
  elim : Δ A k /h.
  - reflexivity.
Admitted.

Definition tm_val Δ ξ Γ :=
  forall i A (l : Lookup i Γ A) (h : TyWt Δ A Star), int_type h ξ.

Lemma tm_val_ren_ty {Δ Δ' Γ} (ξ : ty_val Δ') (ρ : tm_val Δ' ξ Γ) f
  (hf : forall i k, Lookup i Δ k -> Lookup (f i) Δ' k) :
  tm_val Δ (ty_val_ren ξ f hf) (map (ren_Ty f) Γ).
Admitted.

Equations T_Nil {Δ ξ} : tm_val Δ ξ nil :=
  T_Nil i A !.

Equations T_Cons Δ (ξ : ty_val Δ) A Γ (h : TyWt Δ A Star)
  (ρ : tm_val Δ ξ Γ) (s : int_type h ξ) : tm_val Δ ξ (A :: Γ) :=
  T_Cons Δ ξ ?(A) ?(Γ) h ρ s ?(0) A (Here A Γ) h0
    with int_type_irrel h h0 ξ, int_type h ξ := { | eq_refl , _ := s } ;
  T_Cons Δ ξ ?(A) ?(Γ) h ρ s i A0 (There n Γ A0 A l) h0 := ρ n A0 l h0.

Fail Equations apply_eq (a b : nat) (F : nat -> Type) (h : F (a + b)) :
  F (b + a) :=
  apply_eq a b F h with (a + b), PeanoNat.Nat.add_comm a b :=
    { | ?(b + a) , eq_refl := h }.

Equations apply_eq (a b : nat) (F : nat -> Type) (h : F (a + b)) :
  F (b + a) :=
  apply_eq a b F h with PeanoNat.Nat.add_comm a b, (a + b) :=
    { | eq_refl,  ?(plus b a)  := h }.

(* Definition ty_val_ren Δ ξ Γ *)
(*   (ξ : ty_val Δ') f *)
(*   (hf : forall i k, Lookup i Δ k -> Lookup (f i) Δ' k) : ty_val Δ := *)
(*   fun i k l => ξ (f i) k (hf _ _ l). *)


(* Equations tm_val_lookup {i Δ Γ A ξ} *)
(*   (ρ : tm_val Δ ξ Γ) (l : Lookup i Γ A) (h : TyWt Δ A Star) : int_type h ξ := *)
(*   tm_val_lookup (T_Cons A Γ h' r t) (Here A Γ) h *)
(*     with int_type_irrel h' h ξ,  int_type h' ξ  := *)
(*     { | eq_refl, _ := r} ; *)
(*   tm_val_lookup (T_Cons A Γ h' r t) (There n Γ A B l) h := tm_val_lookup t l h. *)

(* Definition ty_val_ren Δ ξ (f : nat -> nat) Δ' : *)
(*   (forall i k, Lookup i Δ k -> Lookup (ξ i) Δ' k) -> *)
(*   ty_val Δ'. *)


(* Inductive ty_val_ren Δ (ξ : ty_val Δ) : TyBasis -> Type := *)
(* | TR_Nil : *)
(*   ty_val_lookup *)
(*   ty_val_ren Δ ξ *)

Lemma int_term {Δ Γ a A} (h : Wt Δ Γ a A) :
  forall ξ (ρ : tm_val Δ ξ Γ),
    int_type (regularity h) ξ.
Proof.
  induction h.
  - simp regularity => ξ ρ.
    apply (ρ _ _ l).
  - hauto q:on use:T_Cons rew:db:regularity.
  - move => ξ ρ.
    move E : (regularity h2) => S.
    dependent elimination S.
    hauto lq:on use:int_type_irrel rew:db:regularity.
  - move => ξ ρ.
    simp regularity => /=.
    move => a0. apply IHh.
    rewrite /tm_val.
    rewrite /up_Basis.
    move => i A0 hA0.
    have A1 : Ty by admit.
    have  ? : ren_Ty S A1 =  A0 by admit.
    have hl : Lookup i Γ A1 by admit.
    subst.
    apply ρ in hl.
    intros h0.
    have h1 : TyWt Δ A1 Star by admit.
    specialize (hl h1).
t    rewrite /up_Basis.
    apply tm_val_ren_ty.
    (* tm_val weakening *)
    admit.
  - move => ξ ρ.
    move E :  (regularity h) => S.
    dependent elimination S.
    simp regularity.
    specialize IHh with (1 := ρ).
    move : IHh.
    rewrite E.
    simp regularity. simpl.
    (* int_type substitution *)
    admit.
  - move => ξ hξ.
Admitted.


intros ξ ρ.
    simp regularity.

    simp regularity.


    simp regularity.

    funelim (regularity h2).

intros ξ ρ.
    specialize IHh1 with (1 := ρ).
    specialize IHh2 with (1 := ρ).

dependent elimination h2.
move /regularity in h2.
    inversion h2; subst.
inversion h2; subst. simpl.
    intros ξ. simpl.
Print int_type.
Lemma Here' : forall {U} A (Γ : list U) T,  Lookup 0 (A :: Γ) T.
Proof. move => > ->. by apply Here. Qed.

Lemma There' : forall n A Γ B T, T = A ⟨shift⟩ ->
    Lookup n Γ A -> Lookup (S n) (B :: Γ) T.
Proof. move => > ->. by apply There. Qed.

Lemma T_App' Γ a b A B u :
  u = B[a…] ->
  Γ ⊢ a ∈ A ->
  Γ ⊢ b ∈ Pi A B ->
  (* --------------- *)
  Γ ⊢ App b a ∈ u.
Proof. move => ->. apply T_App. Qed.

Definition ξ_ok ξ Γ Δ := forall i A, Lookup i Γ A -> Lookup (ξ i) Δ A⟨ξ⟩.

Lemma ξ_ok_id Γ : ξ_ok ids Γ Γ.
Proof.
  rewrite /ξ_ok. by asimpl.
Qed.

Lemma ξ_ok_up ξ Γ Δ A :
  ξ_ok ξ Γ Δ -> ξ_ok (upRen_Term_Term ξ) (A::Γ) (A⟨ξ⟩::Δ).
Proof.
  rewrite /ξ_ok => h.
  inversion 1; subst.
  - apply LookupIff=>//=. by asimpl.
  - apply : There'; last by eauto. by asimpl.
Qed.

Lemma renaming Γ a A (h : Γ ⊢ a ∈ A) :
  forall ξ Δ, ⊢ Δ -> ξ_ok ξ Γ Δ -> Δ ⊢ a⟨ξ⟩ ∈ A⟨ξ⟩.
Proof.
  elim : Γ a A /h.
  - qauto use:T_Var unfold:ξ_ok.
  - auto using T_Star.
  - hauto q:on use:T_Abs, Wf_Cons use:ξ_ok_up.
  - move => * /=.
    apply : T_App'; eauto.
    rewrite -/ren_Term. by asimpl.
  - hauto q:on use:T_Pi, Wf_Cons use:ξ_ok_up.
  - hauto l:on use:T_Conv use:coherent_renaming.
Qed.

Lemma renaming_sort
  Γ A s (h : Γ ⊢ A ∈ ISort s) : forall Δ ξ,
    ξ_ok ξ Γ Δ ->
    ⊢ Δ ->  Δ ⊢ A⟨ξ⟩  ∈ ISort s.
Proof. qauto use:renaming. Qed.

Lemma wt_wf Γ a A (h : Γ ⊢ a ∈ A) : ⊢ Γ.
Proof. elim : Γ a A / h => //. Qed.

#[export]Hint Resolve wt_wf : wf.
#[export]Hint Constructors Wf : wf.

Lemma weakening Γ a A B s
  (h0 : Γ ⊢ B ∈ ISort s)
  (h1 : Γ ⊢ a  ∈ A) :
  (B :: Γ) ⊢ a ⟨S⟩ ∈ A ⟨S⟩.
Proof.
  apply : renaming; eauto with wf.
  hauto lq:on ctrs:Lookup unfold:ξ_ok.
Qed.

Lemma weakening_sort Γ a B s s0
  (h0 : Γ ⊢ B ∈ ISort s)
  (h1 : Γ ⊢ a  ∈ ISort s0) :
  (B :: Γ) ⊢ a ⟨S⟩ ∈ ISort s0.
Proof.
  change (ISort s0) with (ISort s0) ⟨ S ⟩.
  eauto using weakening.
Qed.

Definition ρ_ok ρ Γ Δ :=
  forall i A, Lookup i Γ A -> Δ ⊢ ρ i ∈ A [ ρ ].

Lemma ρ_ok_id Γ : ⊢ Γ -> ρ_ok ids Γ Γ.
Proof. hauto l:on use:T_Var unfold:ρ_ok simp+:asimpl. Qed.

Lemma ρ_ext ρ Γ Δ a A :
  Δ ⊢ a ∈ A[ρ] ->
  ρ_ok ρ Γ Δ ->
  ρ_ok (a.:ρ) (A::Γ) Δ.
Proof.
  hauto q:on inv:Lookup, Wf unfold:ρ_ok db:wf simp+:asimpl.
Qed.

Lemma ρ_ξ_comp ρ ξ Γ Δ Ξ
  (hρ : ρ_ok ρ Γ Δ)
  (hξ : ξ_ok ξ Δ Ξ)
  (hΞ : ⊢ Ξ) :
  ρ_ok (ρ >> ren_Term ξ) Γ Ξ.
Proof.
  move => i A hA.
  suff : Ξ ⊢ (ρ i)⟨ξ⟩ ∈ A[ρ]⟨ξ⟩ by asimpl.
  rewrite /ρ_ok /ξ_ok.
  eauto using renaming.
Qed.

Lemma ρ_suc ρ Γ Δ A s
  (h : ρ_ok ρ Γ Δ) (hA : Δ ⊢ A ∈ ISort s) :
  ρ_ok (ρ >> ren_Term S) Γ (A :: Δ).
Proof.
  apply : ρ_ξ_comp; eauto with wf.
  rewrite /ξ_ok.
  hauto lq:on ctrs:Lookup.
Qed.

Lemma ρ_up ρ Γ Δ A s :
  ρ_ok ρ Γ Δ ->
  Δ ⊢ A[ρ] ∈ ISort s ->
  ρ_ok (up_Term ρ) (A :: Γ) (A[ρ] :: Δ).
Proof.
  move => hρ hA.
  apply ρ_ext.
  apply : T_Var; eauto with wf.
  apply LookupIff=>//=. by asimpl.
  eauto using ρ_suc.
Qed.

Lemma morphing Γ a A (h : Γ ⊢ a ∈ A) : forall Δ ρ,
    ρ_ok ρ Γ Δ ->
    ⊢ Δ ->
    Δ ⊢ a[ρ] ∈ A[ρ].
Proof.
  elim : Γ a A /h.
  - qauto use:T_Var unfold:ρ_ok.
  - qauto use:T_Star.
  - hauto q:on use:ρ_up, T_Abs db:wf.
  - move => *.
    apply : T_App'; eauto. rewrite -/subst_Term. by asimpl.
  - hauto q:on use:ρ_up, T_Pi db:wf.
  - hauto q:on use:coherent_subst, T_Conv.
Qed.

Lemma morphing_sort Γ a s (h : Γ ⊢ a ∈ ISort s) : forall Δ ρ,
    ρ_ok ρ Γ Δ ->
    ⊢ Δ ->
    Δ ⊢ a[ρ] ∈ ISort s.
Proof. hauto lq:on use:morphing. Qed.

Lemma wt_subst Γ a A b B
  (h : Γ ⊢ a ∈ A )
  (h0 : A :: Γ ⊢ b ∈ B) :
  Γ ⊢ b[a…] ∈ B[a…].
Proof.
  apply : morphing; eauto with wf.
  apply ρ_ext. by asimpl.
  apply ρ_ok_id; eauto with wf.
Qed.

Lemma wt_subst_sort Γ a A b s
  (h : Γ ⊢ a ∈ A )
  (h0 : A :: Γ ⊢ b ∈ ISort s) :
  Γ ⊢ b[a…] ∈ ISort s.
Proof.
  change (ISort s) with (ISort s)[a…].
  eauto using wt_subst.
Qed.

Variant Coherent' Γ : Term -> Term -> Prop :=
| C_Refl a :
  Coherent' Γ a a
| C_Coherent a b s :
  a ⇔ b ->
  Γ ⊢ b ∈ ISort s ->
  Coherent' Γ a b .

Definition inv_spec Γ a A : Prop :=
  match a with
  | ISort Kind => False
  | ISort Star => Coherent' Γ (ISort Kind) A
  | VarTm i => exists A0, Lookup i Γ A0 /\ Coherent' Γ A0 A
  | Abs A0 a => exists B s1 s2, Γ ⊢ A0 ∈ ISort s1 /\ A0 :: Γ ⊢ a ∈ B /\ A0 :: Γ ⊢ B ∈ ISort s2 /\ Coherent' Γ (Pi A0 B) A
  | App b a => exists A0 B, Γ ⊢ b ∈ Pi A0 B /\ Γ ⊢ a ∈ A0 /\
                        Coherent' Γ B[a…] A
  | Pi A0 B => exists s1 s2, Γ ⊢ A0 ∈ ISort s1 /\ A0::Γ ⊢ B ∈ ISort s2 /\ Coherent' Γ (ISort s2) A
  end.

Lemma Coherent'_Coherent Γ A B C s :
  Coherent' Γ A B -> B ⇔ C -> Γ ⊢ C ∈ ISort s -> Coherent' Γ A C.
Proof.
  hauto l:on inv:Coherent' ctrs:Coherent' use:coherent_trans.
Qed.

Lemma coherent'_coherent Γ A B s C :
  Coherent' Γ A B -> Γ ⊢ A ∈ ISort s -> C ⇔ A -> Coherent' Γ C B.
Proof.
  inversion 1;
    qauto l:on ctrs:Coherent' inv:Coherent' use:coherent_trans.
Qed.

Lemma coherent'_forget Γ A B :
  Coherent' Γ A B -> Coherent A B.
Proof.  qauto l:on inv:Coherent' use:coherent_refl. Qed.

Lemma inv_spec_conv Γ a A B s :
  inv_spec Γ a A -> A ⇔ B -> Γ ⊢ B ∈ ISort s -> inv_spec Γ a B.
Proof.
  case : a => //=; hauto lq:on ctrs:Coherent' use:Coherent'_Coherent.
Qed.

Lemma wt_inv Γ a A (h : Γ ⊢ a ∈ A) : inv_spec Γ a A.
Proof.
  elim : Γ a A /h=>//=; eauto 10 using C_Refl, coherent_refl, inv_spec_conv.
Qed.

Lemma kind_imp Γ A :
  ~ Γ ⊢ ISort Kind ∈ A.
Proof. firstorder using wt_inv. Qed.

Lemma wt_unique Γ t T U :
  Γ ⊢ t ∈ T ->
  Γ ⊢ t ∈ U ->
  T ⇔ U.
Proof.
  move => h. move : U.
  elim : Γ t T /h.
  - move => Γ i A hΓ hi U /wt_inv //=.
    move => [A0][hA0]?.
    suff : A = A0 by qauto l:on use:coherent'_forget.
    eauto using lookup_functional.
  - qauto use:wt_inv, coherent'_forget.
  - move => Γ A s1 a B s2 hA ihA ha iha hB ihB U /wt_inv/=.
    move => [B0][s3][s4][hA'][ha'][hB0]hU.
    eauto using C_Pi, coherent_refl, coherent_trans, coherent'_forget.
  - move => Γ a b A B ha iha hb ihb U /wt_inv/=.
    move => [A0][B0][?][?]?.
    apply : coherent_trans; eauto using coherent'_forget.
    apply coherent_subst.
    hauto lq:on use:coherent_pi_inj.
  - move => Γ A s1 B s2 hA ihA hB ihB U /wt_inv/=.
    move => [s3][s4][hA0][hB0]h.
    suff : ISort s2 ⇔ ISort s4 by eauto using coherent_trans, coherent'_forget.
    firstorder.
  - eauto using coherent_trans, coherent_sym.
Qed.

Lemma wf_lookup i Γ A : Lookup i Γ A -> ⊢ Γ -> exists s, Γ ⊢ A ∈ ISort s.
Proof.
  induction 1.
  - hauto lq:on inv:Wf use:weakening_sort.
  - inversion 1; subst.
    hauto lq:on use:weakening_sort db:wf.
Qed.

Lemma regularity Γ a A  (h : Γ ⊢ a ∈ A) :
  (exists s, Γ ⊢ A ∈ ISort s) \/ (A = ISort Kind).
Proof.
  elim : Γ a A /h.
  - firstorder using wf_lookup.
  - tauto.
  - qauto use:T_Pi.
  - move => Γ a b A B ha iha hb ihb.
    case : ihb => //=.
    move => [s]/wt_inv/=.
    move => [s1][s2][hA][hB]/coherent'_forget/coherent_sort_inj ?. subst.
    eauto using wt_subst_sort.
  - move => Γ A s1 B s2 hA ihA hB ihB.
    case : ihB; last by tauto.
    move => [s hs].
    left.
    move /wt_inv : hs => /=.
    case  : {hB} s2 => //= h.
    eauto using T_Star with wf.
  - qauto use:coherent_sort_inj.
Qed.

Lemma T_Conv' Γ a A B : Γ ⊢ a ∈ A -> Coherent' Γ A B -> Γ ⊢ a ∈ B.
Proof. hauto l:on inv:Coherent' use:T_Conv. Qed.

Lemma par_coherent a b : a ⇒ b \/ b ⇒ a -> a ⇔ b.
Proof. hauto q:on ctrs:rtc unfold:Coherent. Qed.

Lemma context_equiv A0 A1 s Γ a B :
  A1 ⇔ A0 ->
  Γ ⊢ A1 ∈ ISort s ->
  A0 :: Γ ⊢ a ∈ B ->
  A1 :: Γ ⊢ a ∈ B.
Proof.
  move => ? ? /[dup] /wt_wf ?.
  have ? : ⊢ A1 :: Γ by eauto with wf.
  have ? : ⊢ Γ by hauto lq:on inv:Wf.
  have [s0 ?] : exists s, Γ ⊢ A0 ∈ ISort s by hauto lq:on inv:Wf db:wf.
  move /morphing.
  move /(_ _ ids). asimpl. apply=>//.
  rewrite /ρ_ok.
  move => i A.
  elim /lookup_inv=>//=_.
  - move => A2 Γ0 ? [*]. subst.
    asimpl. renamify.
    apply T_Conv with (A := A1⟨S⟩) (s := s0).
    apply T_Var; eauto using Here.
    apply : weakening_sort; eauto.
    by apply coherent_renaming.
  - move => n Γ0 A2 B0 ? ? [*]. subst.
    asimpl.
    renamify.
    change (VarTm (S n)) with (VarTm n)⟨S⟩.
    apply : weakening; eauto.
    apply T_Var => //=.
Qed.

Lemma context_par A0 A1 s Γ a B :
  A0 ⇒ A1 ->
  Γ ⊢ A1 ∈ ISort s ->
  A0 :: Γ ⊢ a ∈ B ->
  A1 :: Γ ⊢ a ∈ B.
Proof. eauto using context_equiv, par_coherent. Qed.

Lemma subject_reduction a b (h : a ⇒ b) :
  forall Γ A, Γ ⊢ a ∈ A -> Γ ⊢ b ∈ A.
Proof.
  elim:a b/h=>//=.
  - move => A0 A1 a0 a1 hA ihA ha iha Γ A /wt_inv/=.
    move => [B][s1][s2][hA0][ha0][hB]hE.
    eapply T_Conv' with (A := Pi A1 B).
    apply T_Abs with (s1 := s1) (s2 := s2); eauto.
    apply iha.
    by eauto using context_par.
    qauto l:on use:context_par.
    apply : coherent'_coherent; eauto using T_Pi.
    eauto using C_Pi, coherent_refl, par_coherent.
  - move => A0 A1 B0 B1 hA ihA hB ihB Γ A /wt_inv //=.
    move => [s1][s2][hA0][hB0]hE.
    apply : T_Conv'; eauto.
    apply : T_Pi; eauto.
    apply ihB.
    qauto l:on use:context_par.
  - move => a0 a1 b0 b1 ha iha hb ihb Γ A /wt_inv //=.
    move => [A0][B][ha0][hb0]hE.
    apply T_Conv' with (A := B[b1…]).
    apply : T_App; eauto.
    move /regularity : ha0 => []//.
    move => [s].
    move /wt_inv => //=.
    move => [s1][s2][hA0][hB0]hE'.
    have ? : s2 = s by eauto using coherent'_forget, coherent_sort_inj.
    subst.
    eapply coherent'_coherent with (s := s) ; eauto.
    eauto using wt_subst_sort.
    qauto use:par_cong, par_refl, par_coherent.
  - move => A a0 a1 b0 b1 ha iha hb ihb Γ A0 /wt_inv /=.
    move => [A1][B][/wt_inv/=].
    move => [B0][s1][s2][hA][ha0][hB0]hE [hb0]hE'.
    have /iha h := (ha0).
    have h2 : Γ ⊢ b1 ∈ A1 by eauto.
    apply : T_Conv'; eauto.
    have [? ?] : B0 ⇔ B /\ A ⇔ A1 by qauto l:on use:coherent'_forget, coherent_pi_inj.
    have ? : Γ ⊢ b1 ∈ A by hauto lq:on use:T_Conv, coherent'_forget, coherent_sym.
    have : Γ ⊢ a1[b1…] ∈ B0[b1…] by eauto using wt_subst.
    have [s] : exists s, Γ ⊢ Pi A1 B ∈ ISort s
        by inversion hE; subst; eauto using T_Pi.
    move /wt_inv => //=.
    move => [s3][s4][hA0][hB1]hE0.
    have : Γ ⊢ B[b0…] ∈ ISort s4 by eauto using wt_subst_sort.
    move => *.
    apply : T_Conv; eauto.
    have /coherent_sym ? : B [b0…] ⇔ B[b1…]
      by eauto using par_coherent, par_cong, par_refl.
    apply : coherent_trans; eauto.
    qauto l:on use:coherent_subst.
Qed.

Lemma subject_reduction_star a b (h : a ⇒* b) :
  forall Γ A, Γ ⊢ a ∈ A -> Γ ⊢ b ∈ A.
Proof.
  induction h; eauto using subject_reduction, rtc_refl, rtc_l.
Qed.
