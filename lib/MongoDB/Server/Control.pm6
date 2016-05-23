
use v6.c;

use MongoDB;
use MongoDB::Config;

#-------------------------------------------------------------------------------
unit package MongoDB;

#-------------------------------------------------------------------------------
class Server::Control {

#TODO startup/shutdown on windows and appels
  #-----------------------------------------------------------------------------
  submethod BUILD ( Str :$file ) {

    MongoDB::Config.instance(:$file);
  }

  #-----------------------------------------------------------------------------
  method start-mongod ( *@server-keys --> Bool ) {

    my Hash $options = self!get-mongod-options(@server-keys);

    my Str $cmdstr = self!get-binary-path('mongod');
    for $options.keys -> $k {
      $cmdstr ~= " --$k {?$options{$k} ?? $options{$k} !! ''}";
    }

    my Bool $started = False;
    my Proc $proc = shell($cmdstr);
    if $proc.exitcode != 0 {

      fatal-message($cmdstr);
    }

    else {

      $started = True;
      debug-message($cmdstr);
    }

    $started;
  }

  #-----------------------------------------------------------------------------
  method stop-mongod ( *@server-keys --> Bool ) {

    my Hash $options = self!get-mongod-options(@server-keys);
    my Str $cmdstr = self!get-binary-path('mongod');
    $cmdstr ~= " --shutdown";
    $cmdstr ~= ' --dbpath ' ~ "'$options<dbpath>'" // '/data/db';
    $cmdstr ~= ' --quiet' if $options<quiet>;

    my Bool $stopped = False;
    my Proc $proc = shell($cmdstr);
    if $proc.exitcode != 0 {

      fatal-message($cmdstr);
    }

    else {

      debug-message($cmdstr);
      $stopped = True;
    }

    $stopped;
  }

  #-----------------------------------------------------------------------------
  method start-mongos ( ) {

  }

  #-----------------------------------------------------------------------------
  method stop-mongos ( ) {

  }

  #-----------------------------------------------------------------------------
  # Get selected port number from the config
  #
  method get-port-number ( *@server-keys --> Int ) {

    my Hash $config = MongoDB::Config.instance.config;
    my Int $port-number;
    my Hash $s = $config<mongod> // {};
    for @server-keys -> $server-key {
      $s = $s{$server-key} // {};

      # Overwrite at every other oportunity
      $port-number = $s<port> if $s<port>:exists;
    }

    return $port-number;
  }

  #-----------------------------------------------------------------------------
  method !get-mongod-options ( @server-keys --> Hash ) {

    my Hash $config = MongoDB::Config.instance.config;
    my Hash $options = {};
    my Hash $s = $config // {};

    for 'mongod', |@server-keys -> $server-key {

      $s = $s{$server-key} // {};

      for $s.keys -> $k {
        next if $s{$k} ~~ Hash;

        my Bool $bo = self!bool-option($s{$k});

        # Not a boolean option
        if not $bo.defined {
          $options{$k} = $s{$k};
        }

        # Boolean option and true. False booleans are ignored
        elsif $bo {
          $options{$k} = '';
        }
      }
    }

    $options;
  }

  #-----------------------------------------------------------------------------
  # Return values
  # Any) Not boolean/undefined, True) Boolean False, False) Boolean True
  #
  method !bool-option ( $v --> Bool ) {

    if $v ~~ Bool and $v {
      True;
    }

    elsif $v ~~ Bool and not $v {
      False;
    }

    else {
      Bool;
    }
  }

  #-----------------------------------------------------------------------------
  method !get-binary-path ( Str $binary --> Str ) {

    my Hash $config = MongoDB::Config.instance.config;
    my Str $mongodb-server-path;

    # Can be configured in config file
    #
    if not $mongodb-server-path.defined and $config<Binaries>:exists
       and $config<Binaries>{$binary}:exists 
       and $config<Binaries>{$binary}.IO ~~ :x {

      $mongodb-server-path = $config<Binaries>{$binary};
    }

    # On linuxes it should be in /usr/bin
    #
    if not $mongodb-server-path.defined and $*KERNEL.name eq 'linux' {
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
    #
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

