use v6;

#------------------------------------------------------------------------------
unit package MongoDB:auth<github:MARTIMM>;

use Config::DataLang::Refine;
use MongoDB;
use MongoDB::MDBConfig;

#------------------------------------------------------------------------------
class Server::Control {

#TODO startup/shutdown on windows and apples
  #----------------------------------------------------------------------------
  submethod BUILD ( Str :$config-name, Array :$locations ) {
    MongoDB::MDBConfig.instance( :$config-name, :$locations);
  }

  #----------------------------------------------------------------------------
  method start-mongod ( *@server-keys --> Bool ) {

    my MongoDB::MDBConfig $mdbcfg .= instance;
    my Array $options = $mdbcfg.cfg.refine-str(
      'mongod',
      |@server-keys,
      :filter,
      :str-mode(Config::DataLang::Refine::C-UNIX-OPTS-T1)
    );

    my Str $cmdstr = (
      self.get-binary-path( 'mongod', |@server-keys),
      @$options
    ).join(' ');

    my Bool $started = False;

    info-message($cmdstr);

    try {
      my Proc $proc = shell $cmdstr, :err, :out;

      # when closing the channels, exceptions are thrown by Proc when there
      # were any problems
      $proc.err.close;
      $proc.out.close;
      CATCH {
        default {
          fatal-message(.message);
        }
      }
    }

    $started = True;
    debug-message('Command executed ok');

    $started;
  }

  #----------------------------------------------------------------------------
  method stop-mongod ( *@server-keys --> Bool ) {

    my MongoDB::MDBConfig $mdbcfg .= instance;
    my Hash $options = $mdbcfg.cfg.refine( 'mongod', |@server-keys);

    my Str $cmdstr = self.get-binary-path( 'mongod', |@server-keys);
    $cmdstr ~= ' --shutdown';
    $cmdstr ~= ' --dbpath ' ~ "'$options<dbpath>'" // '/data/db';
    $cmdstr ~= ' --quiet' if $options<quiet>;

    my Bool $stopped = False;
    info-message($cmdstr);

    try {
      # inconsequent server error messaging. when starting it says ERROR on stdout
      my Proc $proc = shell $cmdstr, :err, :out;
      $proc.err.close;
      $proc.out.close;
      CATCH {
        default {
          fatal-message(.message);
        }
      }
    }

    debug-message('Command executed ok');
    $stopped = True;

    $stopped;
  }

  #----------------------------------------------------------------------------
  method start-mongos ( ) {

  }

  #----------------------------------------------------------------------------
  method stop-mongos ( ) {

  }

  #----------------------------------------------------------------------------
  # Get selected port number from the config
  method get-port-number ( *@server-keys --> Int ) {

    my MongoDB::MDBConfig $mdbcfg .= instance;
    $mdbcfg.cfg.refine( 'mongod', |@server-keys)<port>;
  }

  #----------------------------------------------------------------------------
  method get-binary-path ( Str $binary, *@server-keys --> Str ) {

    my MongoDB::MDBConfig $mdbcfg .= instance;
    my Str $mongodb-server-path = $mdbcfg.cfg.refine(
      'binaries', |@server-keys
    ){$binary};


#`{{
    my Hash $config = MongoDB::MDBConfig.instance.config;
    my Str $mongodb-server-path;

    # Can be configured in config file
    if $config<binaries>:exists
       and $config<binaries>{$binary}:exists
       and $config<binaries>{$binary}.IO ~~ :x {

      $mongodb-server-path = $config<binaries>{$binary};
    }
}}

    # On linuxes it should be in /usr/bin
    if ! $mongodb-server-path and $*KERNEL.name eq 'linux' {
      if "/usr/bin/$binary".IO ~~ :x {
        $mongodb-server-path = "/usr/bin/$binary";
      }
    }

    # On windows it should be in C:/Program Files/MongoDB/Server/*/bin if the
    # user keeps the default installation directory.
    #
    if not $mongodb-server-path.defined and $*KERNEL.name eq 'win32' {

      for 2.6, 2.8 ... 10 -> $vn {
        my Str $path = "C:/Program Files/MongoDB/Server/$vn/bin/$binary.exe";
        if $path.IO ~~ :e {
          $mongodb-server-path = $path;
          last;
        }
      }
    }

    # Hopefully it can be found in any other path
    if not $mongodb-server-path.defined and %*ENV<PATH> {

      for %*ENV<PATH>.split(':') -> $path {
        if "$path/$binary".IO ~~ :x {
          $mongodb-server-path = "$path/$binary";
          last;
        }
      }
    }

    $mongodb-server-path;
  }
}
