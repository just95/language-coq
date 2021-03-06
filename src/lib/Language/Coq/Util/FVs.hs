{-# LANGUAGE DefaultSignatures #-}
{-# LANGUAGE DeriveTraversable #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE MultiParamTypeClasses #-}

module Language.Coq.Util.FVs where

import           Control.Applicative
import           Control.Lens
import           Control.Monad
import           Control.Monad.Error.Class
import           Control.Monad.Fix
import           Data.Bifoldable
import           Data.Bitraversable
import           Data.Foldable
import           Data.Set                  ( Set )
import qualified Data.Set                  as Set

-- | Set of free variables.
newtype FVs i = FVs { getFVs :: Set i }
 deriving ( Eq, Ord, Show, Read, Semigroup, Monoid )

-- | An object capable of binding something has a set of variables.
data BVs i = BVs { getBVars :: Set i -- ^ Variables bound by this binder.
                 , getBFVs  :: Set i -- ^ Free variables of this object.
                 }
 deriving ( Eq, Ord, Show, Read )

instance Ord i => Semigroup (BVs i) where
  BVs bv1 fv1 <> BVs bv2 fv2 = BVs (bv1 <> bv2) (fv1 <> fv2)

instance Ord i => Monoid (BVs i) where
  mempty = BVs Set.empty Set.empty

binder :: i -> BVs i
binder x = BVs (Set.singleton x) Set.empty

binders :: (Ord i, Foldable f) => f i -> BVs i
binders s = BVs (Set.fromList (toList s)) Set.empty

occurrence :: i -> FVs i
occurrence x = FVs (Set.singleton x)

bindsNothing :: FVs i -> BVs i
bindsNothing (FVs fvs) = BVs Set.empty fvs

forgetBinders :: BVs i -> FVs i
forgetBinders bv = FVs (getBFVs bv)

scopesOver :: Ord i => BVs i -> FVs i -> FVs i
scopesOver (BVs bvs fvs1) (FVs fvs2) = FVs
  $ fvs1 <> (fvs2 `Set.difference` bvs)

scopesMutually :: (Ord i, Foldable f) => (a -> BVs i) -> f a -> BVs i
scopesMutually f xs = binders (foldMap (getBVars . f) xs)
  `telescope` bindsNothing (foldMap (forgetBinders . f) xs)

telescope :: Ord i => BVs i -> BVs i -> BVs i
telescope (BVs bvs1 fvs1) (BVs bvs2 fvs2) = BVs (bvs1 <> bvs2)
  (fvs1 <> (fvs2 `Set.difference` bvs1))

foldTelescope :: (Ord i, Foldable f) => (a -> BVs i) -> f a -> BVs i
foldTelescope f = foldr (telescope . f) mempty

foldScopes :: (Ord i, Foldable f) => (a -> BVs i) -> f a -> FVs i -> FVs i
foldScopes f xs x = foldr (scopesOver . f) x xs

class HasBV i a where
  bvOf :: a -> BVs i

class HasFV i a where
  fvOf :: a -> FVs i
  default fvOf :: HasBV i a => a -> FVs i
  fvOf = forgetBinders . bvOf

instance HasBV i (BVs i) where
  bvOf = id

-- | Convenient functions for things that don’t bind variables, but occur
--   as subterms in binders
fvOf' :: HasFV i a => a -> BVs i
fvOf' x = bindsNothing (fvOf x)

-- | Wraps 'HasBV' and 'HasFV' for the 'Right' values, and reports that the
--   left values contain nothing.
newtype ErrOrVars e a = ErrOrVars { getErrOrVars :: Either e a }
 deriving (
            -- Stock
            Eq, Ord, Show, Read
            -- Iterating
          , Foldable, Traversable, Bifoldable
            -- Functor, monad, etc.
          , Functor, Applicative, Monad, Bifunctor, Alternative, MonadPlus
          , MonadFix, MonadError e )

instance Bitraversable ErrOrVars where
  bitraverse l r (ErrOrVars e) = ErrOrVars <$> bitraverse l r e

  {-# INLINE bitraverse #-}

instance Swapped ErrOrVars where
  swapped = iso swap swap
   where
    swap (ErrOrVars e) = ErrOrVars (either Right Left e)

    {-# INLINE swap #-}

  {-# INLINE swapped #-}

instance HasBV i a => HasBV i (ErrOrVars e a) where
  bvOf = either (const $ BVs Set.empty Set.empty) bvOf . getErrOrVars

instance HasFV i a => HasFV i (ErrOrVars e a) where
  fvOf = either (const $ FVs Set.empty) fvOf . getErrOrVars
