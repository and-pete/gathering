{- | Module describing the model for the application
-}

module Web.Gathering.Model where

import Data.Int (Int32)
import Data.Time (UTCTime, DiffTime)
import Data.Map.Strict (Map)
import Data.Text (Text)

type UserId = Int32

-- | Describing a user of the system
data User = User
  { userId :: Int32
  , userName :: Text
  , userEmail :: Text
  , userIsAdmin :: Bool
  , userWantsUpdates :: Bool
  }
  deriving (Show, Read, Eq, Ord)

-- | Describing a gathering event
data Event = Event
  { eventId :: Int32
  , eventName :: Text
  , eventDesc :: Text
  , eventLocation :: Text
  , eventDateTime :: UTCTime
  , eventDuration :: DiffTime
  }
  deriving (Show, Eq, Ord)

-- | Describing a user in the system that might attend an event
data Attendant = Attendant
  { attendantUser :: User
  , attendantAttending :: Bool
  , attendantFollowsChanges :: Bool
  }
  deriving (Show, Read, Eq, Ord)

-- | A mapping from events to attendants
type Attendants = Map Event [Attendant]