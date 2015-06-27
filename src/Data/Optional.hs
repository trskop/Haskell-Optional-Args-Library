{-# LANGUAGE CPP               #-}
{-# LANGUAGE DeriveFunctor     #-}
{-# LANGUAGE DeriveFoldable    #-}
{-# LANGUAGE DeriveTraversable #-}

-- | Use the `Optional` type for optional function arguments.  For example:
--
-- > import Data.Optional
-- >
-- > greet :: Optional String -> String
-- > greet (Specific name) = "Hello, " ++ name
-- > greet  Default        = "Hello"
--
-- >>> greet (Specific "John")
-- "Hello, John"
-- >>> greet Default
-- "Hello"
--
--     The `Optional` type overloads as many Haskell literals as possible so
--     that you do not need to wrap values in `Specific`.  For example, if you
--     enable the `OverloadedStrings` extension you can use a naked string
--     literal instead:
--
-- >>> :set -XOverloadedStrings
-- >>> greet "John"
-- "Hello, John"
--
--     The `Optional` type also implements `Num` and `Fractional`, so you can
--     use numeric literals in place of `Optional` values:
--
-- > birthday :: Optional Int -> String
-- > birthday (Specific age) = "You are " ++ show age ++ " years old!"
-- > birthday  Default       = "You are one year older!"
--
-- >>> birthday 20
-- "You are 20 years old!"
-- >>> birthday Default
-- "You are one year older!"
--
--     The `IsString`, `Num`, and `Fractional` instances are recursive, so you
--     can wrap your types in a more descriptive newtype and derive `IsString`,
--     `Num` or `Fractional`:
--
-- > {-# LANGUAGE GeneralizedNewtypeDeriving #-}
-- >
-- > import Data.Optional
-- > import Data.String (IsString)
-- >
-- > newtype Name = Name { getName :: String } deriving (IsString)
-- >
-- > greet :: Optional Name -> String
-- > greet (Specific name) = "Hello, " ++ getName name
-- > greet  Default        = "Hello"
-- >
-- > newtype Age = Age { getAge :: Int } deriving (Num)
-- >
-- > birthday :: Optional Age -> String
-- > birthday (Specific age) = "You are " ++ show (getAge age) ++ " years old!"
-- > birthday  Default       = "You are one year older!"
--
--     ... and you would still be able to provide naked numeric or string
--     literals:
--
-- >>> :set -XOverloadedStrings
-- >>> greet "John"
-- "Hello, John"
-- >>> birthday 20
-- "You are 20 years old!"
--
--     You can use `empty` as a short-hand for a `Default` argument:
--
-- >>> greet empty
-- "Hello"
-- >>> birthday empty
-- "You are one year older!"
--
--     You can also use `pure` as a short-hand for a `Specific` argument:
--
-- >>> greet (pure "John")
-- "Hello, John"
-- >>> birthday (pure 20)
-- "You are 20 years old!"

module Data.Optional (
    -- * Optional
      Optional(..)
    , defaultTo
    , fromOptional
    , optional

    -- * Re-exports
    , empty
    , pure
    ) where

import Control.Applicative (Alternative(..), liftA2)
import Control.Monad (MonadPlus(..))
import Data.String (IsString(..))

#if __GLASGOW_HASKELL__ < 710
import Control.Applicative (Applicative(..))
import Data.Foldable (Foldable)
import Data.Traversable (Traversable)
import Data.Monoid (Monoid(..))
#endif

import Data.Default.Class as Class (Default(def))

-- | A function argument that has a `Default` value
data Optional a = Default | Specific a
    deriving (Eq, Functor, Foldable, Traversable, Show)

instance Applicative Optional where
    pure = Specific

    Specific f <*> Specific x = Specific (f x)
    _          <*> _          = Default

instance Monad Optional where
    return = Specific

    Default    >>= _ = Default
    Specific x >>= f = f x

instance Alternative Optional where
    empty = Default

    Default <|> x = x
    x       <|> _ = x

instance MonadPlus Optional where
    mzero = empty
    mplus = (<|>)

instance Monoid a => Monoid (Optional a) where
    mempty = pure mempty

    mappend = liftA2 mappend

instance IsString a => IsString (Optional a) where
    fromString str = pure (fromString str)

instance Num a => Num (Optional a) where
    fromInteger n = pure (fromInteger n)

    (+) = liftA2 (+)
    (*) = liftA2 (*)
    (-) = liftA2 (-)

    negate = fmap negate
    abs    = fmap abs
    signum = fmap signum

instance Fractional a => Fractional (Optional a) where
    fromRational n = pure (fromRational n)

    recip = fmap recip

    (/) = liftA2 (/)

instance Class.Default (Optional a) where
    def = Default

-- | The 'optional' function takes a default value, a function, and an
-- 'Optional' value. If the 'Optional' value is 'Default', the function returns
-- the default value. Otherwise, it applies the function to the value inside the
-- 'Optional' and returns the result.
optional :: b -> (a -> b) -> Optional a -> b
optional n _ Default      = n
optional _ f (Specific x) = f x

-- | The 'defaultTo' function takes a default value and an 'Optional'
-- value.  If the 'Optional' is 'Default', it returns the default value;
-- otherwise, it returns the value contained in the 'Optional'.
defaultTo :: a -> Optional a -> a
defaultTo d Default      = d
defaultTo _ (Specific v) = v

-- | Convert an 'Optional' value into an instance of 'Alternative'.
fromOptional :: Alternative f => Optional a -> f a
fromOptional  Default     = empty
fromOptional (Specific x) = pure x
