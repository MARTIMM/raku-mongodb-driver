use v6.c;
use MongoDB::Config;

unit package MongoDB;

class Server::Control {

  #-----------------------------------------------------------------------------
  submethod BUILD ( Str :$file ) {

    MongoDB::Config.instance(:$file);
  }

  #-----------------------------------------------------------------------------
  method start-mongod ( *@server-keys --> Bool ) {

    my Hash $config = MongoDB::Config.instance.config;
    my Hash $options = {};
    my Bool $started = False;

    for $config<Servers>.keys -> $k {
      next if $config<Servers>{$k} ~~ Hash;

      my Bool $bo = self!bool-option($config<Servers>{$k});

      # Not a boolean option
      if not $bo.defined {
        $options{$k} = " $config<Servers>{$k}";
      }

      # Boolean option and true. False booleans are ignored
      elsif $bo {
        $options{$k} = '';
      }
    }

    my Hash $s = $config<Servers> // {};
    for @server-keys -> $server-key {
      $s = $s{$server-key} // {};
      for $s.keys -> $k {
        next if $s{$k} ~~ Hash;

        my Bool $bo = self!bool-option($config<Servers>{$k});

        # Not a boolean option
        if not $bo.defined {
          $options{$k} = " $s{$k}";
        }

        # Boolean option and true. False booleans are ignored
        elsif $bo {
          $options{$k} = '';
        }
      }
    }

    my Str $cmdstr = self!get-mongod-path;
    for $options.keys -> $k {
      $cmdstr ~= " --$k$options{$k}";
    }

    my Proc $proc = shell($cmdstr);
    if $proc.exitcode != 0 {

#TODO Must remove check on NO-MONGODB-SERVER
#      spurt $server-dir ~ '/NO-MONGODB-SERVER', '';
    }

    else {
      # Remove the file if still there
      #
#      if "$server-dir/NO-MONGODB-SERVER".IO ~~ :e {
#        unlink "$server-dir/NO-MONGODB-SERVER";
#      }

      $started = True;
    }

    $started;
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
  # Download mongodb binaries before testing on TRAVIS-CI. Version of mongo on
  # Travis is still from the middle ages (2.4.12).
  #
  # Assume at first that mongod is in the users path, then we try to find a path
  # to it depending on OS. If it can be found, use the precise path.
  #
  method !get-mongod-path ( --> Str ) {

    my Hash $config = MongoDB::Config.instance.config;
    my Str $mongodb-server-path;

    # Can be configured in config file
    #
    if $config<Server-Binary>:exists
       and $config<Server-Binary><path>:exists {

      $mongodb-server-path = $config<Server-Binary><path>;
    }

    # On Travis-ci the path is known because I've put it there using the script
    # install-mongodb.sh.
    #
    elsif ? %*ENV<TRAVIS> {
      $mongodb-server-path = "$*CWD/Travis-ci/MongoDB/mongod";
    }

    # On linuxes it should be in /usr/bin
    #
    elsif $*KERNEL.name eq 'linux' {
      if '/usr/bin/mongod'.IO ~~ :x {
        $mongodb-server-path = '/usr/bin/mongod';
      }
    }

    # On windows it should be in C:/Program Files/MongoDB/Server/*/bin if the
    # user keeps the default installation directory.
    #
    elsif $*KERNEL.name eq 'win32' {
      for 2.6, 2.8 ... 10 -> $vn {
        my Str $path = "C:/Program Files/MongoDB/Server/$vn/bin/mongod.exe";
        if $path.IO ~~ :e {
          $mongodb-server-path = $path;
          last;
        }
      }
    }

    # Hopefully it can be found in any other path
    #
    else {
      $mongodb-server-path = 'mongod';
    }

    $mongodb-server-path;
  }
}

