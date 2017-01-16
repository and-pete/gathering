{- | Handle the configuration of the app

We'll use the functions defined in this module to parse
command line arguments and config files to provide the configuration
for this program, the configuration contains:

- Command: how to run the app: http, https or both
- AppConfig: configuration for the app which contains
    - Title
    - Description
    - DB connection string

Use `parseArgs` at the start of the program to get the configuration.
from the command line arguments

The defaults are defined in defaultConfig

-}

module Web.Gathering.Config
  ( parseArgs
  , parseConfig
  , Config(..)
  , AppConfig(..)
  , Command(..)
  , TLSConfig(..)
  , defaultConfig
  , getPort
  , getProtocol
  )
where

import Data.ByteString.Char8 (ByteString, pack)
import Options.Applicative
import qualified Data.Text as T
import qualified Data.Configurator as C

-- | Will parse the arguments to the program and will produce
--   A configuration to run spock
--
--   May throw an error on bad configuration file or arguments
--
--   This is all you need from this module basically
parseArgs :: IO (AppConfig, Command)
parseArgs = do
  args <- execParser paramsParserInfo
  case (parseConfig <$> pFileCfg args, pCfg args, pCmd args) of
    (Just _, Just cfg, Just cmd') ->
      pure (cfg, cmd')

    (Just fc, Just cfg, Nothing) -> do
      (_, cmd') <- fc
      pure (cfg, cmd')

    (Just fc, Nothing, Nothing) -> do
      (cfg, cmd') <- fc
      pure (cfg, cmd')

    _ ->
      pure (defaultConfig, HTTP 8080)

-- | Parse configuration file
parseConfig :: FilePath -> IO (AppConfig, Command)
parseConfig cfgFile = do
  cfg <- C.load [C.Required cfgFile]
  name <- C.require cfg "name"
  desc <- C.require cfg "description"
  domain <- C.require cfg "domain"
  db <- C.require cfg "db"

  port <- C.lookup cfg "http.port"
  tlsport <- C.lookup cfg "https.port"
  tlscert <- C.lookup cfg "https.cert"
  tlskey  <- C.lookup cfg "https.key"

  cmd' <- case (port, (,,) <$> tlsport <*> tlscert <*> tlskey) of
    (Just port', Just (p,c,k)) ->
      pure $ Both port' (TLSConfig p c k)
    (Nothing, Just (p,c,k)) ->
      pure $ HTTPS (TLSConfig p c k)
    (Just port', _) ->
      pure $ HTTP port'
    _ ->
      error "http or https configuration missing from configuration file."

  pure (AppConfig name desc domain db, cmd')


------------
-- Config --
------------

-- | Configuration to run the website
data Config = Config
  { cConfig :: AppConfig
  , cCmd :: Command
  }
  deriving (Show)

-- | Application Configuration
data AppConfig = AppConfig
  { cfgTitle  :: T.Text -- ^Title of the website
  , cfgDesc   :: T.Text -- ^Description of the website
  , cfgDomain :: T.Text -- ^Domain of the site to appear in email links
  , cfgDbConnStr :: ByteString -- ^db connection string
  }
  deriving (Show, Eq, Ord)

-- | Which mode to run spock
data Command
  = HTTP Int
  | HTTPS TLSConfig
  | Both Int TLSConfig
  deriving (Show, Read, Eq, Ord)

-- | Requires the needed values for runTLS
data TLSConfig = TLSConfig
  { tlsPort :: Int
  , tlsCert :: FilePath
  , tlsKey  :: FilePath
  }
  deriving (Show, Read, Eq, Ord)

-- | returns the port of the command. favors https
getPort :: Command -> Int
getPort = \case
  HTTP p -> p
  HTTPS tls -> tlsPort tls
  Both _ tls -> tlsPort tls

-- | returns the protocol of the command. favors https
getProtocol :: Command -> T.Text
getProtocol = \case
  HTTP _ -> "http"
  HTTPS _ -> "https"
  Both _ _ -> "https"


-- | Default configuration to run gather
defaultConfig :: AppConfig
defaultConfig = AppConfig
  { cfgTitle  = "Gathering"
  , cfgDesc   = "Get together!"
  , cfgDomain = "localhost"
  , cfgDbConnStr = "host=localhost dbname=gather port=5432 user=gather password=gather"
  }

--------------------
-- Options Parser --
--------------------

data Params = Params
  { pFileCfg :: Maybe FilePath
  , pCfg :: Maybe AppConfig
  , pCmd :: Maybe Command
  }
  deriving (Show)

paramsParserInfo :: ParserInfo Params
paramsParserInfo =
  info (helper <*> (Params <$> optional fromFile <*> optional config <*> optional cmd)) $
     fullDesc
  <> header "Gathering - Publish your events"

config :: Parser AppConfig
config = AppConfig
  <$> fmap T.pack ttl
  <*> fmap T.pack desc
  <*> fmap T.pack domain
  <*> fmap pack dbconnstr
  where
    ttl =
      strOption
        (long "title"
         <> short 't'
         <> metavar "NAME"
         <> help "Website title"
        )
    desc =
      strOption
        (long "description"
         <> short 'D'
         <> metavar "DESC"
         <> help "Website description"
        )
    domain =
      strOption
        (long "domain"
         <> short 'd'
         <> metavar "Domain"
         <> help "Domain for the site to be sent with email links"
        )
    dbconnstr =
      strOption
        (long "dbconnection"
         <> short 'c'
         <> metavar "DBCONN"
         <> help "Database connection string"
        )



cmd :: Parser Command
cmd =
  subparser
  ( command "http" (info (HTTP <$> httpConfig <**> helper)
      ( progDesc "Run only in HTTP mode" ))
 <> command "https" (info (HTTPS <$> tlsConfig <**> helper)
      ( progDesc "Run only in TLS mode" ))
 <> command "both" (info (Both <$> httpConfig <*> tlsConfig <**> helper)
      ( progDesc "Run both in HTTP and TLS modes" ))
  )

httpConfig :: Parser Int
httpConfig =
  option auto
  (long "port"
   <> short 'p'
   <> metavar "PORT"
   <> help "Port for HTTP"
   <> showDefault
   <> value 80
  )

tlsConfig :: Parser TLSConfig
tlsConfig = TLSConfig
  <$> option auto (long "tls-port" <> short 'P' <> metavar "PORT" <> help "Port for TLS" <> showDefault <> value 443)
  <*> strOption (long "tls-key"  <> short 'k' <> metavar "KEY"  <> help "Key file for for TLS")
  <*> strOption (long "tls-cert" <> short 'c' <> metavar "CERT" <> help "Cert file for for TLS")

fromFile :: Parser FilePath
fromFile =
  strOption
  (long "config"
   <> short 'f'
   <> metavar "FILE"
   <> help "Path to configuration file"
  )

