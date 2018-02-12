(** * Counting ones in [positive] and [N] *)

(**
The standard library lacks a popcount operation.
*)

Require Import Coq.PArith.PArith.
Require Import Coq.NArith.NArith.
Require Import Omega.

(** First for [positive], where the function is nicely total. *)

Fixpoint Pos_popcount (p : positive) : positive :=
  match p with
  | 1%positive => 1%positive
  | (p~1)%positive => Pos.succ (Pos_popcount p)
  | (p~0)%positive => Pos_popcount p
  end.

Lemma Pos_popcount_pow2:
  forall n, Pos_popcount (Pos.pow 2 n) = 1%positive.
Proof.
  apply Pos.peano_ind; intros.
  * reflexivity.
  * rewrite Pos.pow_succ_r.
    apply H.
Qed.

(** And now for [N] *)

Definition N_popcount (a : N) : N :=
  match a with
  | 0%N => 0%N
  | N.pos p => N.pos (Pos_popcount p)
  end.

Lemma N_popcount_double:
  forall n, N_popcount (N.double n) = N_popcount n.
Proof.
  intros.
  destruct n.
  * reflexivity.
  * reflexivity.
Qed.

Lemma N_popcount_Ndouble:
  forall n, N_popcount (Pos.Ndouble n) = N_popcount n.
Proof.
  intros.
  destruct n.
  * reflexivity.
  * reflexivity.
Qed.

Lemma N_popcount_Nsucc_double:
  forall n, N_popcount (Pos.Nsucc_double n) = N.succ (N_popcount n).
Proof.
  intros.
  destruct n.
  * reflexivity.
  * reflexivity.
Qed.


Lemma N_popcount_pow2:
  forall n, N_popcount (N.pow 2 n) = 1%N.
Proof.
  apply N.peano_ind; intros.
  * reflexivity.
  * rewrite N.pow_succ_r by apply N.le_0_l.
    rewrite <- N.double_spec.
    rewrite N_popcount_double.
    assumption.
Qed.

Lemma N_double_succ:
  forall n,
  N.double (N.succ n) = N.succ (N.succ (N.double n)).
Proof.
  destruct n.
  * reflexivity.
  * reflexivity.
Qed.

Lemma Pop_popcount_diff:
  forall p1 p2,
  (N.pos (Pos_popcount p1) + N.pos (Pos_popcount p2) =
  N_popcount (Pos.ldiff p1 p2) + N_popcount (Pos.ldiff p2 p1) + N.double (N_popcount (Pos.land p2 p1)))%N.
Proof.
  induction p1; intros; destruct p2.
  all: try (
    simpl;
    try specialize (IHp1 p2);
    rewrite ?N_popcount_Ndouble, ?N_popcount_Nsucc_double,
            ?N_double_succ;
    zify; omega
  ).
  * simpl.
    destruct (Pos_popcount p2); simpl in *; try rewrite <- Pplus_one_succ_r; try reflexivity.
Qed.


Lemma N_popcount_diff:
  forall n1 n2,
  (N_popcount n1 + N_popcount n2 =
  N_popcount (N.ldiff n1 n2) + N_popcount (N.ldiff n2 n1) + N.double (N_popcount (N.land n2 n1)))%N.
Proof.
  intros. destruct n1, n2; try reflexivity.
  apply Pop_popcount_diff.
Qed.

