use v6;

use MongoDB;
use Config::DataLang::Refine;

#------------------------------------------------------------------------------
unit package MongoDB:auth<github:MARTIMM>;

#------------------------------------------------------------------------------
# Singleton class used to maintain config for whole of mongodb
class MDBConfig {

  my MongoDB::MDBConfig $instance;
  has Config::DataLang::Refine $.cfg handles 'config';

  #----------------------------------------------------------------------------
  submethod BUILD ( Str :$config-name, Bool :$merge, Array :$locations ) {
    $!cfg = Config::DataLang::Refine.new(
      :$config-name, :$merge, :$locations,
    );
  }

  #----------------------------------------------------------------------------
  # Forbidden method
  method new ( ) { !!! }

  #----------------------------------------------------------------------------
  # File can be set once a lifetime of the object
  method instance (
    Str :$config-name = 'config.toml',
    Bool :$merge = False,
    Array :$locations = []

    --> MongoDB::MDBConfig
  ) {
    $instance = MongoDB::MDBConfig.bless( :$config-name, :$merge, :$locations)
      unless $instance.defined;

    $instance;
  }
}
