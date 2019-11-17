{-# LANGUAGE OverloadedStrings #-}


module Main (main) where

import Control.Monad
import Data.List (intercalate)
import Data.Int
import Data.Word
import Data.List
import Data.Maybe
import System.Environment
import System.Exit
import System.IO
import System.Console.GetOpt
import System.Process
import DBus
import DBus.Socket
import System.Command

data Bus = Session | System
    deriving (Show)

data Option = BusOption Bus | AddressOption String
    deriving (Show)

findSocket :: [Option] -> IO Socket
findSocket opts = getAddress opts >>= open where
    session = do
        got <- getSessionAddress
        case got of
            Just addr -> return addr
            Nothing -> error "DBUS_SESSION_BUS_ADDRESS is not a valid address"
    
    system = do
        got <- getSystemAddress
        case got of
            Just addr -> return addr
            Nothing -> error "DBUS_SYSTEM_BUS_ADDRESS is not a valid address"
    
    getAddress [] = session
    getAddress ((BusOption Session):_) = session
    getAddress ((BusOption System):_) = system
    getAddress ((AddressOption addr):_) = case parseAddress addr of
        Nothing -> error (show addr ++ " is not a valid address")
        Just parsed -> return parsed

addMatch :: Socket -> String -> IO ()
addMatch sock match = send sock (methodCall "/org/freedesktop/DBus" "org.freedesktop.DBus" "AddMatch")
    { methodCallDestination = Just "org.freedesktop.DBus"
    , methodCallBody = [toVariant match]
    } (\_ -> return ())

isSCDRunning :: IO Bool
isSCDRunning = do
    Stdout rst <- command [] "gpg-connect-agent" ["scd getinfo card_list","/bye 2>/dev/null"]
    let parsedRst = lines rst
    if parsedRst!!0 == "OK" then return False else return True

--find sub string in string
find_string :: (Eq a) => [a] -> [a] -> Int
find_string search str = fromMaybe (-1) $ findIndex (isPrefixOf search) (tails str)

-- checks for ActiveChangedSignal Type
isActiveChangedSignal:: ReceivedMessage -> Bool
isActiveChangedSignal (ReceivedSignal serial msg) = 
    if formatMemberName (signalMember msg) == "ActiveChanged" 
        then True 
        else False

isActiveChangedSignal msg = False

--gets ActiveChangedSignal as Bool type
getActiveChangedSignal :: ReceivedMessage -> Bool
getActiveChangedSignal (ReceivedSignal serial msg) =
    if (find_string "boolean true" (formatBody (signalBody msg))) == (-1) then False else True

getActiveChangedSignal msg = False

formatBody :: [Variant] -> String
formatBody body = formatted where
    tree = Children (map formatVariant body)
    formatted = intercalate "\n" ("" : collapseTree 0 tree)

-- A string tree allows easy indentation of nested structures
data StringTree = Line String | MultiLine [StringTree] | Children [StringTree]
    deriving (Show)

collapseTree :: Int -> StringTree -> [String]
collapseTree d (Line x)       = [replicate (d*3) ' ' ++ x]
collapseTree d (MultiLine xs) = concatMap (collapseTree d) xs
collapseTree d (Children xs)  = concatMap (collapseTree (d + 1)) xs

-- Formatting for various kinds of variants, keyed to their signature type.
formatVariant :: Variant -> StringTree
formatVariant x = case variantType x of
    
    TypeBoolean -> Line $ let
        Just x' = fromVariant x
        in "boolean " ++ if x' then "true" else "false"
    
    TypeWord8 -> Line $ let
        Just x' = fromVariant x
        in "byte " ++ show (x' :: Word8)
    
    TypeWord16 -> Line $ let
        Just x' = fromVariant x
        in "uint16 " ++ show (x' :: Word16)
    
    TypeWord32 -> Line $ let
        Just x' = fromVariant x
        in "uint32 " ++ show (x' :: Word32)
    
    TypeWord64 -> Line $ let
        Just x' = fromVariant x
        in "uint64 " ++ show (x' :: Word64)
    
    TypeInt16 -> Line $ let
        Just x' = fromVariant x
        in "int16 " ++ show (x' :: Int16)
    
    TypeInt32 -> Line $ let
        Just x' = fromVariant x
        in "int32 " ++ show (x' :: Int32)
    
    TypeInt64 -> Line $ let
        Just x' = fromVariant x
        in "int64 " ++ show (x' :: Int64)
    
    TypeDouble -> Line $ let
        Just x' = fromVariant x
        in "double " ++ show (x' :: Double)
    
    TypeString -> Line $ let
        Just x' = fromVariant x
        in "string " ++ show (x' :: String)
    
    TypeObjectPath -> Line $ let
        Just x' = fromVariant x
        in "object path " ++ show (formatObjectPath x')
    
    TypeSignature -> Line $ let
        Just x' = fromVariant x
        in "signature " ++ show (formatSignature x')
    
    TypeArray _ -> MultiLine $ let
        Just x' = fromVariant x
        items = arrayItems x'
        lines' = [ Line "array ["
                 , Children (map formatVariant items)
                 , Line "]"
                 ]
        in lines'
    
    TypeDictionary _ _ -> MultiLine $ let
        Just x' = fromVariant x
        items = dictionaryItems x'
        lines' = [ Line "dictionary {"
                 , Children (map formatItem items)
                 , Line "}"
                 ]
        formatItem (k, v) = MultiLine (firstLine : vTail) where
            Line k' = formatVariant k
            v' = collapseTree 0 (formatVariant v)
            vHead = head v'
            vTail = map Line (tail v')
            firstLine = Line (k' ++ " -> " ++ vHead)
        in lines'
    
    TypeStructure _ -> MultiLine $ let
        Just x' = fromVariant x
        items = structureItems x'
        lines' = [ Line "struct ("
                 , Children (map formatVariant items)
                 , Line ")"
                 ]
        in lines'
    
    TypeVariant -> let
        Just x' = fromVariant x
        in MultiLine [Line "variant", Children [formatVariant x']]


--entry point
main :: IO ()
main = do
    sock <- findSocket [(BusOption Session)]
    
    send sock (methodCall "/org/freedesktop/DBus" "org.freedesktop.DBus" "Hello")
        { methodCallDestination = Just "org.freedesktop.DBus"
        } (\_ -> return ())
    
    addMatch sock  "type='signal',interface='org.freedesktop.ScreenSaver'"
    
    forever $ do
        received <- receive sock
        scdRunning <- isSCDRunning

        if isActiveChangedSignal received then
            if getActiveChangedSignal received then
                if scdRunning then
                    system "gpg-connect-agent \"SCD KILLSCD\" \"SCD BYE\" /bye 2>&1 >> /dev/null"  >>= \exitCode -> putStr ""
                else return ()
            else return ()
        else return ()
