#use MongoDB;
use YAMLish;

#------------------------------------------------------------------------------
# Singleton class used to maintain config for whole of mongodb
unit class TestLib::MDBConfig:auth<github:MARTIMM>;

constant SERVER_PATH = './xt/TestServers';

my TestLib::MDBConfig $instance;

has Hash $.cfg;

#----------------------------------------------------------------------------
submethod BUILD ( Str :$config-name ) {
  $!cfg = load-yaml(SERVER_PATH ~ "/$config-name");
note 'cfg: ', $!cfg.gist;
}

#----------------------------------------------------------------------------
# Forbidden method
method new ( ) { !!! }

#----------------------------------------------------------------------------
# File can be set once a lifetime of the object
method instance ( Str :$config-name = 'config.toml' --> TestLib::MDBConfig ) {
  $instance //= TestLib::MDBConfig.bless(:$config-name);

  $instance;
}

