use v6.c;
use MongoDB;
use Config::TOML;
#use Config::DataLang::Refine;

#-------------------------------------------------------------------------------
unit package MongoDB;

#-------------------------------------------------------------------------------
# Singleton class used to maintain config for whole of mongodb
#
class Config {

  has Hash $.config;
#  has Config::DataLang::Refine  $.cfg handles 'config';
  my MongoDB::Config $instance;

  #-----------------------------------------------------------------------------
  submethod BUILD ( Str :$file ) {

    $!config = from-toml(:$file);
#    $!cfg .= new(:config-name($file));
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
