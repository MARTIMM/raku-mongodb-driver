use v6;

#-------------------------------------------------------------------------------
unit package MongoDB:auth<github:MARTIMM>;

use Config::DataLang::Refine;
use MongoDB;
use MongoDB::MDBConfig;

#-------------------------------------------------------------------------------
class Server::Control {

#TODO startup/shutdown on windows and apples
  #-----------------------------------------------------------------------------
  submethod BUILD ( Str :$config-name, Array :$locations = [] ) {
    # one time init can provide some data. later only instantiate without
    # arguments is possible
    MongoDB::MDBConfig.instance( :$config-name, :$locations);
  }

  #-----------------------------------------------------------------------------
  method start-mongod (
    *@server-keys, Bool :$create-environment = False
    --> Bool
  ) {
    # check for windows or other os to get proper path delimiter
    my Bool $is-win = $*KERNEL.name eq 'win32';
    my Str $path-delim = ($is-win ?? '\\' !! '/');

    my MongoDB::MDBConfig $mdbcfg .= instance;

    # get server data locations and create directories if needed
    my Hash $locations = $mdbcfg.cfg.refine( 'locations', |@server-keys);
    my Str $server-path = $locations<server-path>;
    $server-path ~~ s:g/ \/ /\\/ if $is-win;
    my Str $server-subdir =
       [~] $server-path, $path-delim, ($locations<server-subdir> // '');

    unless ?$locations<server-subdir> {
      fatal-message(
        "Server keys '@server-keys[*]' did not have a server sub directory"
      );
    }

    my Str $binary-path = self.get-binary-path( 'mongod', $locations<mongod>);
    $binary-path ~~ s:g/ \/ /\\/ if $is-win;

    my Hash $options = $mdbcfg.cfg.refine( 'server', |@server-keys, :filter);
    $options<logpath> = [~] $server-subdir, $path-delim, $locations<logpath>;
    $options<pidfilepath> =
      [~] $server-subdir, $path-delim, $locations<pidfilepath>;
    $options<dbpath> = [~] $server-subdir, $path-delim, $locations<dbpath>;

    if $create-environment {
      mkdir( $server-path, 0o700) unless $server-path.IO ~~ :d;
      mkdir( $server-subdir, 0o700) unless $server-subdir.IO ~~ :d;
      mkdir( $options<dbpath>, 0o700) unless $options<dbpath>.IO ~~ :d;
    }

    my Str $cmdstr = $binary-path ~ ' ';
    for $options.kv -> $key, $value {
      $cmdstr ~= "--$key" ~ ($value ~~ Bool ?? '' !! " \"$value\"") ~ " ";
    }

    # when ready, remove last space from the commandline
    $cmdstr ~~ s/ \s+ $//;
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

    $started
  }

  #-----------------------------------------------------------------------------
  method stop-mongod ( *@server-keys --> Bool ) {

    my Bool $is-win = $*KERNEL.name eq 'win32';
    my Str $path-delim = ($is-win ?? '\\' !! '/');

    my MongoDB::MDBConfig $mdbcfg .= instance;

    my Hash $locations = $mdbcfg.cfg.refine( 'locations', |@server-keys);
    my Str $server-path = $locations<server-path>;
    $server-path ~~ s:g/ \/ /\\/ if $is-win;
    my Str $server-subdir =
       [~] $server-path, $path-delim, ($locations<server-subdir> // '');

    unless ?$locations<server-subdir> {
      fatal-message(
        "Server keys '@server-keys[*]' did not have a server sub directory"
      );
    }

    my Str $binary-path = self.get-binary-path( 'mongod', $locations<mongod>);
    $binary-path ~~ s:g/ \/ /\\/ if $is-win;

    # get options. to shutdown we only need a subset and --shutdown added
    my Hash $options = $mdbcfg.cfg.refine( 'server', |@server-keys, :filter);
    $options<dbpath> = [~] $server-subdir, $path-delim, $locations<dbpath>;

    my Str $cmdstr = $binary-path ~ ' ';
    $cmdstr ~= '--shutdown ';
    $cmdstr ~= '--dbpath ' ~ "'$options<dbpath>' " // '/data/db ';
    $cmdstr ~= '--quiet ' if $options<quiet>;

    # when ready, remove last space from the commandline
    $cmdstr ~~ s/ \s+ $//;
    my Bool $stopped = False;
    info-message($cmdstr);

    try {
      # inconsequent server error messaging. when starting it says ERROR
      # on stdout
      my Proc $proc = shell $cmdstr, :err, :out;
      $proc.err.close;
      $proc.out.close;
      CATCH {
        default {
          fatal-message(.message);
        }
      }
    }

    $stopped = True;
    debug-message('Command executed ok');

    $stopped
  }

  #-----------------------------------------------------------------------------
  method start-mongos ( ) {

  }

  #-----------------------------------------------------------------------------
  method stop-mongos ( ) {

  }

  #-----------------------------------------------------------------------------
  # Get selected port number from the config
  method get-port-number ( *@server-keys --> Int ) {

    my MongoDB::MDBConfig $mdbcfg .= instance;

    # try remote port number first, then the server number
    $mdbcfg.cfg.refine( 'remote', |@server-keys)<port> //
      $mdbcfg.cfg.refine( 'server', |@server-keys)<port>
  }

  #-----------------------------------------------------------------------------
  # Get selected port number from the config
  method get-hostname ( *@server-keys --> Str ) {

    # hostnames are only in remote tables
    my MongoDB::MDBConfig $mdbcfg .= instance;
    $mdbcfg.cfg.refine( 'remote', |@server-keys)<host>;
  }

  #-----------------------------------------------------------------------------
  method get-binary-path (
    Str $binaryname, Str $mongodb-server-path is copy
    --> Str
  ) {

    # On linuxes it should be in /usr/bin
    if not $mongodb-server-path.defined and $*KERNEL.name eq 'linux' {
      my Str $path = "/usr/bin/$binaryname";
      if $path.IO ~~ :e {
        $mongodb-server-path = $path;
      }
    }

    # On windows it should be in C:/Program Files/MongoDB/Server/*/bin if the
    # user keeps the default installation directory.
    if not $mongodb-server-path.defined and $*KERNEL.name eq 'win32' {
      for 2.6, 2.8 ... 10 -> $vn {
        my Str $path =
          "C:/Program Files/MongoDB/Server/$vn/bin/$binaryname.exe";

        if $path.IO ~~ :e {
          $mongodb-server-path = $path;
          last;
        }
      }
    }

    # Hopefully it can be found in any other path
    if not $mongodb-server-path.defined and %*ENV<PATH> {

      for %*ENV<PATH>.split(':') -> $path {
        if "$path/$binaryname".IO ~~ :x {
          $mongodb-server-path = "$path/$binaryname";
          last;
        }
      }
    }

    $mongodb-server-path;
  }
}
