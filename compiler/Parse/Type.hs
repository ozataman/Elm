module Parse.Type where

import Control.Applicative ((<$>),(<*>))
import Control.Monad (liftM,mapM)
import Data.Char (isLower)
import Data.List (lookup,intercalate)
import Text.Parsec
import Text.Parsec.Indent

import SourceSyntax.Location as Located
--import SourceSyntax.PrettyPrint
import SourceSyntax.Type as T
--import qualified SourceSyntax.Expression as Expr
--import qualified SourceSyntax.Declaration as Decl
import Parse.Helpers
import Unique

tvar :: IParser T.Type
tvar = T.Var <$> lowVar <?> "type variable"

list :: IParser T.Type
list = listOf <$> braces expr

tuple :: IParser T.Type
tuple = do ts <- parens (commaSep expr)
           return $ case ts of
                      [t] -> t
                      _   -> tupleOf ts

record :: IParser T.Type
record = brackets $ do
           ext <- extend
           fs <- fields
           return (T.Record (fieldMap fs) ext)
  where
    extend = option T.EmptyRecord . try $ do
               t <- tvar
               whitespace >> string "|" >> whitespace
               return t
    fields = commaSep $ do
               lbl <- rLabel
               whitespace >> hasType >> whitespace
               (,) lbl <$> expr

constructor0 :: IParser T.Type
constructor0 =
  do name <- capVar
     return (T.Data name [])

term :: IParser T.Type
term = list <|> tuple <|> record <|> tvar <|> constructor0

app :: IParser T.Type
app =
  do name <- capVar <?> "type constructor"
     args <- spacePrefix term
     return (T.Data name args)

expr :: IParser T.Type
expr =
  do t1 <- app <|> term
     whitespace
     arr <- optionMaybe arrow
     whitespace
     case arr of
       Just _  -> T.Lambda t1 <$> expr
       Nothing -> return t1

constructor :: IParser (String, [T.Type])
constructor = (,) <$> (capVar <?> "another type constructor")
                  <*> spacePrefix term