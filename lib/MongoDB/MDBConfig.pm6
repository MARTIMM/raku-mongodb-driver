use v6.c;

use MongoDB;
use Config::DataLang::Refine;

#-------------------------------------------------------------------------------
unit package MongoDB:auth<https://github.com/MARTIMM>;

#-------------------------------------------------------------------------------
# Singleton class used to maintain config for whole of mongodb
#
class MDBConfig {

  my MongoDB::MDBConfig $instance;
  has Config::DataLang::Refine $.cfg handles 'config';

  #-----------------------------------------------------------------------------
  submethod BUILD (
    Str :$config-name,
    Bool :$merge,
    Array :$locations,
    Str :$data-module
  ) {
    $!cfg = Config::DataLang::Refine.new(
      :$config-name,
      :$merge,
      :$locations,
      :$data-module
    );
  }

  #-----------------------------------------------------------------------------
  # Forbidden method
  #
  method new ( ) { !!! }

  #-----------------------------------------------------------------------------
  # File can be set once a lifitime of the object
  #
  method instance (
    Str :$config-name,
    Bool :$merge,
    Array :$locations,
    Str :$data-module = 'Config::TOML'

    --> MongoDB::MDBConfig
  ) {

    if not $instance.defined {
      $instance = MongoDB::MDBConfig.bless(
        :$config-name,
        :$merge,
        :$locations,
        :$data-module
      );
    }

    $instance;
  }
}
