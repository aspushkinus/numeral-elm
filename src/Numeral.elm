module Numeral where

import String
import Array
import Regex exposing (HowMany(All), regex)


type alias Delimiters =
  { thousands:String
  , decimal:String
  }

type alias Abbreviations =
  { thousand:String
  , million:String
  , billion:String
  , trillion:String
  }

type alias Ordinal = String -> String

type alias Currency =
  { symbol:String
  }

type alias Language =
  { delimiters:Delimiters
  , abbreviations:Abbreviations
  , ordinal:Ordinal
  , currency:Currency
  }


enLang : Language
enLang =
  { delimiters=
    { thousands=","
    , decimal="."
    }
  , abbreviations=
    { thousand="k"
    , million="m"
    , billion="b"
    , trillion="t"
    }
  -- TODO!
  , ordinal=(\str -> "th")
  , currency=
    { symbol="$"
    }
  }


type alias NumberTypeFormatter =
  Language -> String -> Float -> String -> String


suffixes =
  ["B", "KB", "MB", "GB", "TB", "PB", "EB", "ZB", "YB"]
  |> Array.fromList


indexOf : String -> String -> Int
indexOf part word  =
  String.indexes part word
  |> List.head
  |> Maybe.withDefault -1


emptyReplace str =
  Regex.replace All (regex str) (\_ -> "")


formatWithoutCurrency : String -> (String, String)
formatWithoutCurrency format =
  if String.contains " $" format then
    (" ", emptyReplace " $" format)
  else if String.contains "$ " format then
    (" ", emptyReplace "$ " format)
  else
    ("", emptyReplace "$" format)


formatCurrency : NumberTypeFormatter
formatCurrency lang format value strValue =
  let
    symbolIndex = indexOf "$" format
    openParenIndex = indexOf "(" format
    minusSignIndex = indexOf "-" format
    (space, format') = formatWithoutCurrency format
    formatted = formatNumber lang format' value strValue
  in
    if symbolIndex <= 1 then
      if String.contains "(" formatted || String.contains "-" formatted then
        -- TODO
        ""
      else
        lang.currency.symbol ++ space ++ formatted
    else
      if String.contains ")" formatted then
        -- TODO
        ""
      else
        formatted ++ space ++ lang.currency.symbol


formatWithoutPercent : String -> (String, String)
formatWithoutPercent format =
  if String.contains " %" format then
    (" ", emptyReplace " %" format)
  else
    ("", emptyReplace "%" format)


formatPercentage : NumberTypeFormatter
formatPercentage lang format value strValue =
  let
    value' = value * 100
    (space, format') = formatWithoutPercent format
    formatted = formatNumber lang format' value' (toString value')
  in
    if String.contains ")" formatted then
      -- TODO
      ""
    else
      formatted ++ space ++ "%"


formatTime : NumberTypeFormatter
formatTime lang format value strValue =
  let
    hasOneDigit val =
      if String.length val < 2 then
        "0" ++ val
      else
        val
    hours =
      value / 60 / 60
      |> floor
      |> toFloat
    minutes =
      (value - (hours * 60 * 60))/60
      |> floor
      |> toFloat
    seconds =
      (value - (hours * 60 * 60) - (minutes * 60))
      |> round
  in
    [ (hours |> toString)
    , (minutes |> toString |> hasOneDigit)
    , (seconds |> toString |> hasOneDigit)
    ] |> String.join ":"


checkParensAndSign : String -> (String, Bool, Bool)
checkParensAndSign format =
  if String.contains "(" format then
    (String.slice 1 -1 format, True, False)
  else
    (emptyReplace "\\+" format, False, True)


checkAbbreviation : Language -> String -> Float -> (String, String, Float)
checkAbbreviation lang format value =
  let
    abbrK = String.contains "aK" format
    abbrM = String.contains "aM" format
    abbrB = String.contains "aB" format
    abbrT = String.contains "aT" format
    abbrForce = abbrK || abbrM || abbrB || abbrT |> not
    absValue = abs value
    (abbr, format') =
      if String.contains " a" format then
        (" ", emptyReplace " a" format)
      else
        ("", emptyReplace "a" format)
  in
    if absValue >= 10^12 && abbrForce || abbrT then
      (format', abbr ++ lang.abbreviations.trillion, value / 10^12)
    else if absValue < 10^12 && absValue >= 10^9 && abbrForce || abbrB then
      (format', abbr ++ lang.abbreviations.billion, value / 10^9)
    else if absValue < 10^9 && absValue >= 10^6 && abbrForce || abbrM then
      (format', abbr ++ lang.abbreviations.million, value / 10^6)
    else if absValue < 10^6 && absValue >= 10^3 && abbrForce || abbrK then
      (format', abbr ++ lang.abbreviations.thousand, value / 10^3)
    else
      (format', abbr, value)


checkByte format value =
  let
    (bytes, format') =
      if String.contains " b" format then
        (" ", emptyReplace " b" format)
      else
        ("", emptyReplace "b" format)

    suffixIndex' power =
      let
        minValue = 1024^power
        maxValue = 1024^(power + 1)
      in
        if value >= minValue && value < maxValue then
          if minValue > 0 then
            (power, value / minValue)
          else
            (power, value)
        else
          suffixIndex' (power + 1)
    (suffixIndex, value') = suffixIndex' 0
    suffix =
      Array.get suffixIndex suffixes
      |> Maybe.withDefault ""
  in
    (format', value', bytes ++ suffix)


checkOrdinal lang format value =
  let
    (ord, format') =
      if String.contains " o" format then
        (" ", emptyReplace " o" format)
      else
        ("", emptyReplace "o" format)
  in
    (format', ord ++ (toString value |> lang.ordinal))


checkOptionalDec format =
  if String.contains "[.]" format then
    (Regex.replace All (regex "[.]") (\_ -> ".") format, True)
  else
    (format, False)


toFixed value precision optionals =
  let
    power = 10^precision
    -- output =
  in
    ""


processPrecision lang format value precision =
  let
    fst =
      if String.contains "[" precision then
        emptyReplace "]" precision
        |> String.split "["
        |> toFixed value
      else
        toFixed value precision
    w =
      String.split "." fst
      |> List.head
      |> Maybe.withDefault ""
  -- TODO!
  in
    ("","")


formatNumber : NumberTypeFormatter
formatNumber lang format value strValue =
  let
    (format', negP, signed) = checkParensAndSign format
    (format'', abbr, value') = checkAbbreviation lang format' value
    (format''', value'', bytes) = checkByte format'' value'
    -- this is a stupid mess...
    (format'''', ord) = checkOrdinal lang format''' value''
    (finalFormat, optDec) = checkOptionalDec format''''
    strValue' = toString value''
    w =
      String.split "." strValue'
      |> List.head
      |> Maybe.withDefault ""
    precision =
      String.split "." finalFormat
      |> List.drop 1
      |> List.head
      |> Maybe.withDefault ""
    thousands =
      String.contains "," finalFormat
    (w', d) = processPrecision lang format value precision
  in
    ""


formatWithLanguage : Language -> String -> Float -> String
formatWithLanguage lang format value =
  let
    numberType =
      if String.contains "$" format then
        formatCurrency
      else if String.contains "%" format then
        formatPercentage
      else if String.contains ":" format then
        formatTime
      else
        formatNumber
  in
    numberType lang format value (toString value)


format : String -> Float -> String
format =
  formatWithLanguage enLang