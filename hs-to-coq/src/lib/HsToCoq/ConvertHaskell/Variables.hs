{-# LANGUAGE MultiWayIf, OverloadedStrings, FlexibleContexts #-}

module HsToCoq.ConvertHaskell.Variables (
  -- * Generate variable names
  var', var,
  freeVar', freeVar,
  -- * Avoiding reserved words/names
  tryEscapeReservedWord, escapeReservedNames
  ) where

import Control.Lens
import Data.Semigroup (Semigroup(..))
import Data.Monoid hiding ((<>))
import Data.Maybe
import qualified Data.Text as T

import Control.Monad

import GHC hiding (Name)
import Outputable (OutputableBndr)
import OccName

import HsToCoq.Util.GHC

import HsToCoq.Coq.Gallina
import HsToCoq.ConvertHaskell.Parameters.Renamings
import HsToCoq.ConvertHaskell.Monad

--------------------------------------------------------------------------------

tryEscapeReservedWord :: Ident -> Ident -> Maybe Ident
tryEscapeReservedWord reserved name = do
  suffix <- T.stripPrefix reserved name
  guard $ T.all (== '_') suffix
  pure $ name <> "_"

escapeReservedNames :: Ident -> Ident
escapeReservedNames x =
  fromMaybe x . getFirst $
    foldMap (First . flip tryEscapeReservedWord x)
            (T.words "Set Type Prop fun fix forall return mod as cons pair")
    <> if | T.all (== '.') x -> pure $ T.map (const '∘') x
          | T.all (== '∘') x -> pure $ "⟨" <> x <> "⟩"
          | otherwise        -> mempty

--------------------------------------------------------------------------------

freeVar' :: Ident -> Ident
freeVar' = escapeReservedNames

freeVar :: (GhcMonad m, OutputableBndr name) => name -> m Ident
freeVar = fmap freeVar' . ghcPpr

var' :: ConversionMonad m => HsNamespace -> Ident -> m Ident
var' ns x = use $ renamed ns x . non (escapeReservedNames x)

var :: (ConversionMonad m, HasOccName name, OutputableBndr name) => HsNamespace -> name -> m Ident
var ns name =
  let ns' | ns == TypeNS && occNameSpace (occName name) `nameSpacesRelated` dataName = ExprNS
          | otherwise                                                                = ns
  in var' ns' =<< ghcPpr name -- TODO Check module part?
