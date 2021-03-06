-- | Pretty-printing implementation for 'Value'
module Config.Pretty where

import           Data.Char (isPrint, isDigit,intToDigit)
import           Data.List (mapAccumL)
import qualified Data.Text as Text
import           Text.PrettyPrint
import           Numeric(showIntAtBase)

import Config.Value

-- | Pretty-print a 'Value' as shown in the example.
-- Sections will nest complex values underneath with
-- indentation and simple values will be rendered on
-- the same line as their section.
pretty :: Value -> Doc
pretty value =
  case value of
    Sections [] -> text "{}"
    Sections xs -> prettySections xs
    Number b n  -> prettyNum b n
    Text t      -> prettyText (Text.unpack t)
    Bool b      -> if b then text "yes" else text "no"
    List []     -> text "[]"
    List xs     -> vcat [ char '*' <+> pretty x | x <- xs ]


prettyNum :: Int -> Integer -> Doc
prettyNum b n
  | b == 16   = pref <> text "0x" <> num
  | b ==  8   = pref <> text "0o" <> num
  | b ==  2   = pref <> text "0b" <> num
  | otherwise = integer n
  where
  pref = if n < 0 then char '-' else empty
  num  = text (showIntAtBase (fromIntegral b) intToDigit (abs n) "")



prettyText :: String -> Doc
prettyText = doubleQuotes . cat . snd . mapAccumL ppChar True

  where ppChar s x
          | isDigit x = (True, if not s then text "\\&" <> char x else char x)
          | isPrint x = (True, char x)
          | otherwise = (False, char '\\' <> int (fromEnum x))


prettySections :: [Section] -> Doc
prettySections ss = prettySmallSections small $$ rest
  where
  (small,big) = break (isBig . sectionValue) ss
  rest        = case big of
                  []     -> empty
                  b : bs -> prettyBigSection b $$ prettySections bs

prettyBigSection :: Section -> Doc
prettyBigSection s =
  text (Text.unpack (sectionName s)) <> colon
  $$ nest 2 (pretty (sectionValue s))

prettySmallSections :: [Section] -> Doc
prettySmallSections ss = vcat (map pp annotated)
  where
  annotate s = (Text.length (sectionName s), s)
  annotated  = map annotate ss
  indent     = 1 + maximum (0 : map fst annotated)
  pp (l,s)   = prettySmallSection (indent - l) s

prettySmallSection :: Int -> Section -> Doc
prettySmallSection n s =
  text (Text.unpack (sectionName s)) <> colon <>
    text (replicate n ' ') <> pretty (sectionValue s)

isBig :: Value -> Bool
isBig (Sections (_:_))  = True
isBig (List (_:_))      = True
isBig _                 = False



