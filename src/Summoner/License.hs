module Summoner.License
       ( LicenseName(..)
       , License(..)
       , cabalLicense
       , customizeLicense
       , githubLicenseQueryNames
       , parseLicenseName
       , fetchLicense
       , licenseShortDesc
       ) where

import Data.Aeson (FromJSON (..), decodeStrict, withObject, (.:))
import Data.ByteString.Char8 (pack)
import System.Process (readProcess)

import qualified Data.Text as T
import qualified Text.Show as TS

----------------------------------------------------------------------------
-- License
----------------------------------------------------------------------------

data LicenseName
    = MIT
    | BSD2
    | BSD3
    | GPL2
    | GPL3
    | LGPL21
    | LGPL3
    | AGPL3
    | Apache20
    | MPL20
    | None
    deriving (Eq, Ord, Enum, Bounded, Generic)

instance Show LicenseName where
    show MIT      = "MIT"
    show BSD2     = "BSD2"
    show BSD3     = "BSD3"
    show GPL2     = "GPL-2"
    show GPL3     = "GPL-3"
    show LGPL21   = "LGPL-2.1"
    show LGPL3    = "LGPL-3"
    show AGPL3    = "AGPL-3"
    show Apache20 = "Apache-2.0"
    show MPL20    = "MPL-2.0"
    show None     = "None"

newtype License = License { unLicense :: Text }
    deriving (IsString, Show, Generic)

instance FromJSON License where
    parseJSON = withObject "License" $ \o -> License <$> o .: "body"

-- | As it will be shown in @cabal@ file.
cabalLicense :: LicenseName -> Text
cabalLicense None = "AllRightsReserved"
cabalLicense l    = show l

githubLicenseQueryNames :: LicenseName -> Text
githubLicenseQueryNames = \case
    MIT      -> "mit"
    BSD2     -> "bsd-2-clause"
    BSD3     -> "bsd-3-clause"
    GPL2     -> "gpl-2.0"
    GPL3     -> "gpl-3.0"
    LGPL21   -> "lgpl-2.1"
    LGPL3    -> "lgpl-3.0"
    AGPL3    -> "agpl-3.0"
    Apache20 -> "apache-2.0"
    MPL20    -> "mpl-2.0"
    None     -> "none"

parseLicenseName :: Text -> Maybe LicenseName
parseLicenseName = inverseMap show

customizeLicense :: LicenseName -> License -> Text -> Text -> License
customizeLicense l license@(License licenseText) nm year
    | l `elem` [MIT, BSD2, BSD3] = License updateLicenseText
    | otherwise                  = license
  where
    updateLicenseText =
        let (beforeY, withY) = T.span (/= '[') licenseText
            afterY           = T.tail $ T.dropWhile (/= ']') withY
            (beforeN, withN) = T.span (/= '[') afterY
            afterN           = T.tail $ T.dropWhile (/= ']') withN
        in  beforeY <> year <> beforeN <> nm <> afterN

fetchLicense :: LicenseName -> IO License
fetchLicense None = pure $ License $ licenseShortDesc None
fetchLicense name = do
    let licenseLink = "https://api.github.com/licenses/" <> githubLicenseQueryNames name
    licenseJson <- readProcess
        "curl" [ toString licenseLink, "-H", "Accept: application/vnd.github.drax-preview+json"] ""
    pure $ fromMaybe (error "Broken predefined license list") (decodeStrict $ pack licenseJson)

-- | Show short information for the 'LicenseName'.
licenseShortDesc :: LicenseName -> Text
licenseShortDesc = \case
    MIT      -> "MIT license"
    BSD2     -> "2-clause BSD license"
    BSD3     -> "3-clause BSD license"
    GPL2     -> "GNU General Public License, version 2"
    GPL3     -> "GNU General Public License, version 3"
    LGPL21   -> "GNU Lesser General Public License, version 2.1"
    LGPL3    -> "GNU Lesser General Public License, version 3"
    AGPL3    -> "GNU Affero General Public License, version 3"
    Apache20 -> "Apache License, version 2.0"
    MPL20    -> "Mozilla Public License, version 2.0."
    None     -> "License file won't be added. Explicitly 'All Rights Reserved', eg \
        \for proprietary software. The package may not be legally modified or \
        \redistributed by anyone but the rightsholder"
