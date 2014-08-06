
module Test.Config(main) where

import Development.Shake
import Development.Shake.FilePath
import Development.Shake.Config
import Test.Type
import Data.Char
import qualified Data.HashMap.Strict as Map
import Data.Maybe
import System.Directory


main = shaken test $ \args obj -> do
    want $ map obj ["hsflags.var","cflags.var","none.var"]
    usingConfigFile $ obj "config"
    obj "*.var" *> \out -> do
        cfg <- getConfig $ map toUpper $ takeBaseName out
        liftIO $ appendFile (out -<.> "times") "X"
        writeFile' out $ fromMaybe "" cfg


test build obj = do
    build ["clean"]
    createDirectoryIfMissing True $ obj ""
    writeFile (obj "config") $ unlines
        ["HEADERS_DIR = /path/to/dir"
        ,"CFLAGS = -O2 -I${HEADERS_DIR} -g"
        ,"HSFLAGS = -O2"]
    build []
    assertContents (obj "cflags.var") "-O2 -I/path/to/dir -g"
    assertContents (obj "hsflags.var") "-O2"
    assertContents (obj "none.var") ""

    appendFile (obj "config") $ unlines
        ["CFLAGS = $CFLAGS -w"]
    build []
    assertContents (obj "cflags.var") "-O2 -I/path/to/dir -g -w"
    assertContents (obj "hsflags.var") "-O2"
    assertContents (obj "cflags.times") "XX"
    assertContents (obj "hsflags.times") "X"
    assertContents (obj "none.times") "X"

    -- Test readConfigFileWithEnv
    build ["clean"]
    writeFile (obj "config") $ unlines
      ["HEADERS_DIR = ${SOURCE_DIR}/path/to/dir"
      ,"CFLAGS = -O2 -I${HEADERS_DIR} -g"]
    vars <- readConfigFileWithEnv [("SOURCE_DIR", "/path/to/src")]
                                  (obj "config")
    assert (Map.lookup "HEADERS_DIR" vars == Just "/path/to/src/path/to/dir")
        $ "readConfigFileWithEnv:"
            ++ " Expected: " ++ show (Just "/path/to/src/path/to/dir")
            ++ " Got: " ++ show (Map.lookup "HEADERS_DIR" vars)
    assert (Map.lookup "CFLAGS" vars == Just "-O2 -I/path/to/src/path/to/dir -g")
        $ "readConfigFileWithEnv:"
            ++ " Expected: " ++ show (Just "-O2 -I/path/to/src/path/to/dir -g")
            ++ " Got: " ++ show (Map.lookup "CFLAGS" vars)
