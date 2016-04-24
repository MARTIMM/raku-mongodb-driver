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

    for $config<mongod>.keys -> $k {
      next if $config<mongod>{$k} ~~ Hash;

      my Bool $bo = self!bool-option($config<mongod>{$k});

      # Not a boolean option
      if not $bo.defined {
        $options{$k} = " $config<mongod>{$k}";
      }

      # Boolean option and true. False booleans are ignored
      elsif $bo {
        $options{$k} = '';
      }
    }

    my Hash $s = $config<mongod> // {};
    for @server-keys -> $server-key {
      $s = $s{$server-key} // {};
      for $s.keys -> $k {
        next if $s{$k} ~~ Hash;

        my Bool $bo = self!bool-option($config<mongod>{$k});

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

    my Str $cmdstr = self!get-binary-path('mongod');
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

    # On linuxes it should be in /usr/bin
    #
    if !?$mongodb-server-path and $*KERNEL.name eq 'linux' {
      if "/usr/bin/$binary".IO ~~ :x {
        $mongodb-server-path = "/usr/bin/$binary";
      }
    }

    # On windows it should be in C:/Program Files/MongoDB/Server/*/bin if the
    # user keeps the default installation directory.
    #
    if !?$mongodb-server-path and $*KERNEL.name eq 'win32' {

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
    if !?$mongodb-server-path and %*ENV<PATH> {
      
      for %*ENV<PATH>.split(':') -> $path {
        if "$path/$binary".IO ~~ :x {
          $mongodb-server-path = "$path/$binary";
          last;
        }
      }
    }

    # Can be configured in config file
    #
    if !?$mongodb-server-path and $config<Binaries>:exists
       and $config<Binaries>{$binary}:exists {

      $mongodb-server-path = $config<Binaries>{$binary};
    }

    $mongodb-server-path;
  }
}

