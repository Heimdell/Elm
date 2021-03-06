{-# OPTIONS_GHC -W #-}
module Build.Source (build) where

import qualified Data.Map as Map
import Text.PrettyPrint (Doc)

import AST.Module as Module
import qualified Parse.Parse as Parse
import qualified Metadata.Prelude as Prelude
import qualified Transform.Check as Check
import qualified Type.Inference as TI
import qualified Transform.Canonicalize as Canonical

build :: Bool -> Interfaces -> String -> Either [Doc] CanonicalModule
build noPrelude interfaces source =
  do let infixes = Map.fromList . map (\(assoc,lvl,op) -> (op,(lvl,assoc)))
                 . concatMap iFixities $ Map.elems interfaces

     -- Parse the source code and validate that it is well formed.
     validModule <- do
       modul <- Prelude.add noPrelude `fmap` Parse.program infixes source
       case Check.mistakes (body modul) of
         [] -> return modul
         ms -> Left ms

     -- Canonicalize all variables, pinning down where they came from.
     canonicalModule <- Canonical.module' interfaces validModule

     -- Run type inference on the program.
     types <- TI.infer interfaces canonicalModule

     -- Trim down the set of exported values to the stuff that is actually exported.
     let types' = Canonical.filterExports types (Module.exports canonicalModule)
         body'  = (body canonicalModule) { types = types' }

     return $ canonicalModule { body = body' }
