use v6.c;
use Config::TOML;

#-------------------------------------------------------------------------------
unit package MongoDB;

#-------------------------------------------------------------------------------
# Singleton class used to maintain config for whole of mongodb
#
class Config {

  has Hash $.config;
  my MongoDB::Config $instance;

  #-----------------------------------------------------------------------------
  submethod BUILD ( Str :$file ) {

    $!config = from-toml(:$file);
  }

  #-----------------------------------------------------------------------------
  # Forbidden method
  #
  method new ( ) { !!! }

  #-----------------------------------------------------------------------------
  # File can be set once a lifitime of the object
  #
  method instance ( Str :$file --> MongoDB::Config ) {

    if not $instance.defined {
      $instance = MongoDB::Config.bless(:$file);
    }

    $instance;
  }
}
