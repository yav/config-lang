{
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE Trustworthy #-}

module Config.Parser (parse) where

import Control.Applicative
import Control.Monad
import Data.ByteString.Lazy (ByteString)
import qualified Data.ByteString.Lazy.Char8 as L8

import Config.Value   (Section(..), Value(..))
import Config.Lexer   (scanTokens)
import Config.Tokens  (PosToken(..), layoutPass)
import qualified Config.Tokens as T

}

%token

SECTION                         { PosToken _ _ (T.Section $$)   }
STRING                          { PosToken _ _ (T.String $$)    }
NUMBER                          { PosToken _ _ $$@T.Number{}    }
'yes'                           { PosToken _ _ T.Yes            }
'no'                            { PosToken _ _ T.No             }
'*'                             { PosToken _ _ T.Bullet         }
'['                             { PosToken _ _ T.OpenList       }
','                             { PosToken _ _ T.Comma          }
']'                             { PosToken _ _ T.CloseList      }
'{'                             { PosToken _ _ T.OpenMap        }
'}'                             { PosToken _ _ T.CloseMap       }
SEP                             { PosToken _ _ T.LayoutSep      }
END                             { PosToken _ _ T.LayoutEnd      }

%tokentype                      { PosToken                      }
%lexer { lexerP }               { PosToken _ _ T.EOF            }
%monad { ParseM }
%name value value

%%

value ::                        { Value                         }
  : sections END                { Sections (reverse $1)         }
  | list     END                { List     (reverse $1)         }
  | simple                      { $1                            }

simple ::                       { Value                         }
  : NUMBER                      { number $1                     }
  | STRING                      { Text   $1                     }
  | 'yes'                       { Bool True                     }
  | 'no'                        { Bool False                    }
  | '{' '}'                     { Sections []                   }
  | '[' inlinelist ']'          { List     $2                   }

sections ::                     { [Section]                     }
  :              section        { [$1]                          }
  | sections SEP section        { $3 : $1                       }

section ::                      { Section                       }
  : SECTION value               { Section $1 $2                 }

list ::                         { [Value]                       }
  :          '*' value          { [$2]                          }
  | list SEP '*' value          { $4 : $1                       }

inlinelist ::                   { [Value]                       }
  :                             { []                            }
  | inlinelist1                 { reverse $1                    }

inlinelist1 ::                  { [Value]                       }
  :                 simple      { [$1]                          }
  | inlinelist1 ',' simple      { $3 : $1                       }



{

number :: T.Token -> Value
number (T.Number base val) = Number base val
number _                   = error "Config.Parser.number: fatal error"

newtype ParseM a = ParseM
  { runParseM :: PosToken -> [PosToken] -> Either (Int,Int) (PosToken,[PosToken], a) }

-- | Parse a configuration value and return the result on the
-- right, or the position of an error on the left.
parse ::
  ByteString             {- ^ UTF-8 encoded source        -} ->
  Either (Int,Int) Value {- ^ Either (Line,Column) Result -}
parse bytes =
  do let toks = layoutPass (scanTokens bytes)
     (_,_,x) <- runParseM value (error "previous token") toks
     return x

instance Functor ParseM where
  fmap          = liftM

instance Applicative ParseM where
  (<*>)         = ap
  pure          = return

instance Monad ParseM where
  return x      = ParseM $ \t ts ->
                     do return (t,ts,x)
  m >>= f       = ParseM $ \t ts ->
                     do (t',ts',x) <- runParseM m t ts
                        runParseM (f x) t' ts'

lexerP :: (PosToken -> ParseM a) -> ParseM a
lexerP k = ParseM $ \_ toks ->
  case toks of
    []      -> error "Unexpected end of token stream"
    t:toks' -> runParseM (k t) t toks'

-- required by 'happy'
happyError :: ParseM a
happyError = ParseM $ \(PosToken line column _) _ -> Left (line,column)

}
