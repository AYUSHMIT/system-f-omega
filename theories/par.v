Require Export degree.
From Ltac2 Require Import Ltac2.
Import Ltac2.Constr.
Import Ltac2.Constr.Unsafe.
Require Ltac2.Control.
Set Default Proof Mode "Classic".

Inductive Par Ξ : Term -> Term -> Prop :=
| P_Var i :
  Par Ξ (VarTm i) (VarTm i)
| P_Sort s :
  Par Ξ (ISort s) (ISort s)
| P_Abs A0 A1 a0 a1 :
  Par Ξ A0 A1 ->
  Par (degree Ξ A0 - 1 .: Ξ) a0 a1 ->
  (* ------------------- *)
  Par Ξ (Abs A0 a0) (Abs A1 a1)
| P_Pi A0 A1 B0 B1 :
  Par Ξ A0 A1 ->
  Par (degree Ξ A0 - 1 .: Ξ) B0 B1 ->
  (* ------------------- *)
  Par Ξ (Pi A0 B0) (Pi A1 B1)
| P_App a0 a1 b0 b1 :
  Par Ξ a0 a1 ->
  Par Ξ b0 b1 ->
  Par Ξ (App a0 b0) (App a1 b1)
| P_AppAbs A a0 a1 b0 b1 :
  Par (degree Ξ A - 1 .: Ξ) a0 a1 ->
  Par Ξ b0 b1 ->
  degree Ξ b1 = degree Ξ A - 1 ->
  (* -------------------- *)
  Par Ξ (App (Abs A a0) b0) a1[b1…].

#[export]Hint Constructors Par : par.

Notation Pars := (fun Ξ => rtc (Par Ξ)).

Lemma par_refl Ξ a : Par Ξ a a.
Proof. elim : a Ξ; eauto with par. Qed.

Ltac2 binder_map (f : constr -> constr) (b : binder) : binder :=
  Binder.make (Binder.name b) (f (Binder.type b)).

Local Ltac2 map_invert (f : constr -> constr) (iv : case_invert) : case_invert :=
  match iv with
  | NoInvert => NoInvert
  | CaseInvert indices => CaseInvert (Array.map f indices)
  end.

Ltac2 map (f : constr -> constr) (c : constr) : constr :=
  match Unsafe.kind c with
  | Rel _ | Meta _ | Var _ | Sort _ | Constant _ _ | Ind _ _
  | Constructor _ _ | Uint63 _ | Float _  => c
  | Cast c k t =>
      let c := f c
      with t := f t in
      make (Cast c k t)
  | Prod b c =>
      let b := binder_map f b
      with c := f c in
      make (Prod b c)
  | Lambda b c =>
      let b := binder_map f b
      with c := f c in
      make (Lambda b c)
  | LetIn b t c =>
      let b := binder_map f b
      with t := f t
      with c := f c in
      make (LetIn b t c)
  | App c l =>
      let c := f c
      with l := Array.map f l in
      make (App c l)
  | Evar e l =>
      let l := Array.map f l in
      make (Evar e l)
  | Case info x iv y bl =>
      let x := match x with (x,x') => (f x, x') end
      with iv := map_invert f iv
      with y := f y
      with bl := Array.map f bl in
      make (Case info x iv y bl)
  | Proj p r c =>
      let c := f c in
      make (Proj p r c)
  | Fix structs which tl bl =>
      let tl := Array.map (binder_map f) tl
      with bl := Array.map f bl in
      make (Fix structs which tl bl)
  | CoFix which tl bl =>
      let tl := Array.map (binder_map f) tl
      with bl := Array.map f bl in
      make (CoFix which tl bl)
  | Array u t def ty =>
      let ty := f ty
      with t := Array.map f t
      with def := f def in
      make (Array u t def ty)
  end.

Ltac2 par_cong_rel c r :=
  let rec go c :=
    lazy_match! c with
    | Par => r
    | _ => map go c
    end in go (type c).

Ltac revert_all_terms :=
  repeat (progress
            (match goal with
               [_x : Term |- _] => (revert _x)
             end)).

Ltac2 Notation "gen_cong" x(constr) r(constr) := Control.refine (fun _ => par_cong_rel x r).

Lemma preservation Ξ a b : Par Ξ a b -> degree Ξ a = degree Ξ b.
Proof.
  move => h .
  elim : Ξ a b / h => //=.
  - qauto.
  - qauto.
  - move => Ξ A a0 a1 b0 b1 ha iha hb ihb h.
    rewrite iha.
    rewrite -h.
    by apply subst_one.
Qed.

Ltac solve_s_rec :=
  move => *; eapply rtc_l; eauto;
         hauto lq:on ctrs:Par use:par_refl, preservation.

Ltac solve_pars_cong :=
  repeat (  let x := fresh "x" in
            intros * x;
            revert_all_terms;
            induction x; last by solve_s_rec);
  firstorder using rtc_refl.

Lemma PS_App : ltac2:(gen_cong P_App Pars).
Proof. solve_pars_cong. Qed.

Lemma PS_Pi : ltac2:(gen_cong P_Pi Pars).
Proof.
  move => Ξ A0 A1 ++ h.
  induction h.
  induction 1; auto using rtc_refl.
  solve_s_rec.
  move => B0 B1.
  simpl.
Qed.

Lemma PS_Sort : ltac2:(gen_cong P_Sort Pars).
Proof. solve_pars_cong. Qed.

Lemma P_AppAbs' Ξ A a0 a1 b0 b1 u :
  u = a1[b1…] ->
  Par Ξ a0 a1 ->
  Par Ξ b0 b1 ->
  degree Ξ b1 = degree Ξ A - 1 ->
  (* -------------------- *)
  Par Ξ (App (Abs A a0) b0) u.
Proof. move =>> ->. apply P_AppAbs. Qed.

Lemma par_renaming Ξ0 Ξ1 a b ξ :
  ξ_ok ξ Ξ0 Ξ1 ->
  Par Ξ0 a b ->
  Par Ξ1 a⟨ξ⟩ b⟨ξ⟩.
Proof.
  move => + h. move : Ξ1  ξ. elim : Ξ0 a b/h; try solve [simpl;eauto with par].
  - hauto lq:on ctrs:Par use:renaming, ξ_ok_up.
  - move => Ξ A0 A1 B0 B1 hA ihA hB ihB Ξ1 ξ hξ /=.
    apply P_Pi.
  (* Abs *)
  - move => *. apply : P_AppAbs'; eauto. by asimpl.
Qed.

Lemma par_ρ_ext a b ρ0 ρ1 :
  a ⇒ b ->
  (forall i, ρ0 i ⇒ ρ1 i) ->
  (forall i, (a .: ρ0) i ⇒ (b .: ρ1) i).
Proof. qauto l:on inv:nat. Qed.

Lemma par_ρ_id ρ :
  forall (i : nat), ρ i ⇒ ρ i.
Proof. eauto using par_refl. Qed.

Lemma par_ρ_up ρ0 ρ1 :
  (forall i, ρ0 i ⇒ ρ1 i) ->
  (forall i, (up_Term_Term ρ0) i ⇒ (up_Term_Term ρ1) i).
Proof. hauto l:on use:par_renaming, par_ρ_ext, P_Var unfold:up_Term_Term. Qed.

Lemma par_morphing a b ρ0 ρ1 :
  (forall i, ρ0 i ⇒ ρ1 i) ->
  a ⇒ b ->
  a[ρ0] ⇒ b[ρ1].
Proof.
  move => + h. move : ρ0 ρ1.
  elim : a b /h=>//=; eauto using par_ρ_up with par.
  (* App *)
  - move => *.
    apply : P_AppAbs'; eauto using par_ρ_up. by asimpl.
Qed.

Function tstar a :=
  match a with
  | ISort _ => a
  | VarTm _ => a
  | Abs A a => Abs (tstar A) (tstar a)
  | Pi A B => Pi (tstar A) (tstar B)
  | App (Abs A a) b => (tstar a)[tstar b …]
  | App a b => App (tstar a) (tstar b)
  end.

Lemma par_cong a0 a1 b0 b1 (h : a0 ⇒ a1) (h1 : b0 ⇒ b1) :
  a0 [b0…] ⇒ a1 [b1…].
Proof. auto using par_morphing, par_ρ_ext, par_ρ_id. Qed.

Local Ltac solve_triangle := qauto use:par_refl, par_cong ctrs:Par inv:Par.

Lemma par_triangle a b : a ⇒ b -> b ⇒ tstar a.
Proof.
  move : b. apply tstar_ind;
    hauto lq:on use:par_refl, par_cong ctrs:Par inv:Par.
Qed.

Lemma par_diamond a b c : a ⇒ b -> a ⇒ c -> b ⇒ tstar a /\ c ⇒ tstar a.
Proof. auto using par_triangle. Qed.

Lemma pars_diamond : confluent Par.
Proof.
  hauto lq:on use:par_diamond, @diamond_confluent unfold:confluent, diamond.
Qed.

Lemma pars_renaming a b ξ :
  a ⇒* b ->
  a⟨ξ⟩ ⇒* b⟨ξ⟩.
Proof.
  induction 1; hauto lq:on ctrs:rtc use:par_renaming.
Qed.

Lemma par_subst a b ρ :
  a ⇒ b ->
  a[ρ] ⇒ b[ρ].
Proof.
  auto using par_refl, par_morphing.
Qed.

Lemma pars_subst a b ρ :
  a ⇒* b ->
  a[ρ] ⇒* b[ρ].
Proof.
  induction 1; hauto lq:on ctrs:rtc use:par_subst.
Qed.

Definition Coherent a b := exists c, a ⇒* c /\ b ⇒* c.
Infix "⇔" := Coherent (at level 70, no associativity).

Lemma coherent_renaming a b ξ :
  a ⇔ b ->
  a⟨ξ⟩ ⇔ b⟨ξ⟩.
Proof. hauto lq:on use:pars_renaming unfold:Coherent. Qed.

Lemma coherent_subst a b ρ :
  a ⇔ b ->
  a[ρ] ⇔ b[ρ].
Proof. hauto lq:on use:pars_subst unfold:Coherent. Qed.

Lemma coherent_refl : forall a, a ⇔ a.
Proof. hauto lq:on use:rtc_refl unfold:Coherent. Qed.

Lemma coherent_sym : forall a b, a ⇔ b -> b ⇔ a.
Proof. rewrite /Coherent. firstorder. Qed.

Lemma coherent_trans : forall a b c, a ⇔ b -> b ⇔ c -> a ⇔ c.
Proof.
  rewrite /Coherent.
  have h := pars_diamond. rewrite /confluent /diamond in h.
  move => a b c [ab [ha0 hb0]] [bc [ha1 hb1]].
  have [abc [hab hbc]] : exists abc, ab ⇒* abc /\ bc ⇒* abc by firstorder.
  exists abc. eauto using rtc_transitive.
Qed.

Lemma C_App : ltac2:(gen_cong P_App Coherent).
Proof. hauto lq:on use:PS_App unfold:Coherent. Qed.

Lemma C_Pi : ltac2:(gen_cong P_Pi Coherent).
Proof. hauto lq:on use:PS_Pi unfold:Coherent. Qed.

Lemma pars_pi_inv A B U :
  Pi A B ⇒* U -> exists A0 B0, U = Pi A0 B0 /\ A ⇒* A0 /\ B ⇒* B0.
Proof.
  move E : (Pi A B) => T h.
  move : A B E.
  elim : T U/h.
  hauto lq:on ctrs:rtc, Par.
  hauto lq:on rew:off inv:Par ctrs:Par,rtc.
Qed.

Lemma pars_sort_inv s U :
  ISort s ⇒* U -> U = ISort s.
Proof.
  move E : (ISort s) => T h.
  move : s E.
  elim : T U/h.
  hauto lq:on ctrs:rtc, Par.
  hauto lq:on rew:off inv:Par ctrs:Par,rtc.
Qed.

Lemma coherent_pi_inj A0 A1 B0 B1 :
  Pi A0 B0 ⇔ Pi A1 B1 ->
  A0 ⇔ A1 /\
  B0 ⇔ B1.
Proof. hauto l:on inv:eq rew:off  ctrs:rtc use:pars_pi_inv unfold:Coherent. Qed.

Lemma coherent_sort_inj s0 s1 :
  ISort s0 ⇔ ISort s1 ->
  s0 = s1.
Proof.
  move => [u][/pars_sort_inv h0 /pars_sort_inv h1].
  congruence.
Qed.

(* Based on https://poplmark-reloaded.github.io/coq/well-scoped/PR.sn_defs.html *)
Inductive SN : Term -> Prop :=
| S_Neu a : SNe a -> SN a
| S_Abs A a : SN A -> SN a -> SN (Abs A a)
| S_Sort s : SN (ISort s)
| S_Pi A B : SN A -> SN B -> SN (Pi A B)
| S_Red a0 a1 : SNRed a0 a1 -> SN a1 -> SN a0
with SNe : Term -> Prop :=
| S_Var i : SNe (VarTm i)
| S_App a b : SNe a -> SN b -> SNe (App a b)
with SNRed : Term -> Term -> Prop :=
| S_AppL a0 a1 b :
  SNRed a0 a1 ->
  SNRed (App a0 b) (App a1 b)
| S_AppAbs A a b :
  SN A ->
  SN b ->
  SNRed (App (Abs A a) b) a[b…].

Scheme SN_ind_2 := Minimality for SN Sort Prop
                   with SNe_ind_2 := Minimality for SNe Sort Prop
                    with redSN_ind_2 := Minimality for SNRed Sort Prop.
Combined Scheme SN_multind from SN_ind_2, SNe_ind_2, redSN_ind_2.
