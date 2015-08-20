use v6;
use MongoDB::Database;
use Digest::MD5;

#-------------------------------------------------------------------------------
#
package MongoDB {

  #-----------------------------------------------------------------------------
  #
  class MongoDB::Database::Users {

    constant $PW-LOWERCASE = 0;
    constant $PW-UPPERCASE = 1;
    constant $PW-NUMBERS = 2;
    constant $PW-OTHER-CHARS = 3;

    has MongoDB::Database $.database;
    has Int $.min-un-length = 2;
    has Int $.min-pw-length = 2;
    has Int $.pw-attribs-code = $PW-LOWERCASE;

    #---------------------------------------------------------------------------
    #
    submethod BUILD ( MongoDB::Database :$database ) {

      # TODO validate name
      $!database = $database;
    }

    #---------------------------------------------------------------------------
    #
    method set_pw_security (
      Int :$min_un_length where $min_un_length >= 2,
      Int :$min_pw_length where $min_pw_length >= 2,
      Int :$pw_attribs = $PW-LOWERCASE
    ) {

      given $pw_attribs {
        when $PW-LOWERCASE {
          $!min-pw-length = $min_pw_length // 2;
        }

        when $PW-UPPERCASE {
          $!min-pw-length = $min_pw_length // 2;
        }

        when $PW-NUMBERS {
          $!min-pw-length = $min_pw_length // 3;
        }

        when $PW-OTHER-CHARS {
          $!min-pw-length = $min_pw_length // 4;
        }

        default {
          $!min-pw-length = $min_pw_length // 2;
        }
      }

      $!pw-attribs-code = $pw_attribs;
      $!min-un-length = $min_un_length;
    }

    #---------------------------------------------------------------------------
    # Create a user in the mongodb authentication database
    #
    method create_user (
      Str :$user, Str :$password,
      :$custom_data, Array :$roles, Int :$timeout
      --> Hash
    ) {
      # Check if username is too short
      #
      if $user.chars < $!min-un-length {
        die X::MongoDB::Database.new(
          error-text => "Username too short, must be >= $!min-un-length",
          oper-name => 'create_user',
          oper-data => $user,
          database-name => [~] $!database.name
        );
      }

      # Check if password is too short
      #
      elsif $password.chars < $!min-pw-length {
        die X::MongoDB::Database.new(
          error-text => "Password too short, must be >= $!min-pw-length",
          oper-name => 'create_user',
          oper-data => $password,
          database-name => [~] $!database.name
        );
      }

      # Check if password answers to rule given by attribute code
      #
      else {
        my Bool $pw-ok = False;
        given $!pw-attribs-code {
          when $PW-LOWERCASE {
            $pw-ok = ($password ~~ m/ <[a..z]> /).Bool;
          }

          when $PW-UPPERCASE {
            $pw-ok = (
              $password ~~ m/ <[a..z]> / and
              $password ~~ m/ <[A..Z]> /
            ).Bool;
          }

          when $PW-NUMBERS {
            $pw-ok = (
              $password ~~ m/ <[a..z]> / and
              $password ~~ m/ <[A..Z]> / and
              $password ~~ m/ \d /
            ).Bool;
          }

          when $PW-OTHER-CHARS {
            $pw-ok = (
              $password ~~ m/ <[a..z]> / and
              $password ~~ m/ <[A..Z]> / and
              $password ~~ m/ \d / and
              $password ~~ m/ <[`~!@\#\$%^&*()\-_=+[{\]};:\'\"\\\|,<.>\/\?]> /
            ).Bool;
          }
        }
        die X::MongoDB::Database.new(
          error-text => "Password does not have the proper elements",
          oper-name => 'create_user',
          oper-data => $password,
          database-name => [~] $!database.name
        ) unless $pw-ok;
      }

      my Pair @req = (
        createUser => $user,
        pwd => Digest::MD5.md5_hex( [~] $user, ':mongo:', $password),
        digestPassword => False
      );

      @req.push((roles => $roles)) if ?$roles;
      @req.push((customData => $custom_data)) if ?$custom_data;
      @req.push( (writeConcern => { j => True, wtimeout => $timeout }))
        if ?$timeout;

      my Hash $doc = $!database.run_command(@req);
      if $doc<ok>.Bool == False {
        die X::MongoDB::Database.new(
          error-text => $doc<errmsg>,
          oper-name => 'create_user',
          oper-data => @req.perl,
          database-name => [~] $!database.name
        );
      }

      # Return its value of the status document
      #
      return $doc;
    }

    #---------------------------------------------------------------------------
    #
    method drop_user ( Str :$user, Int :$timeout --> Hash ) {
      my Pair @req = (
        dropUser => $user
      );

      @req.push((writeConcern => { j => True, wtimeout => $timeout }))
        if ?$timeout;

      my Hash $doc = $!database.run_command(@req);
      if $doc<ok>.Bool == False {
        die X::MongoDB::Database.new(
          error-text => $doc<errmsg>,
          oper-name => 'drop_user',
          oper-data => @req.perl,
          database-name => [~] $!database.name
        );
      }

      # Return its value of the status document
      #
      return $doc;
    }

    #---------------------------------------------------------------------------
    #
    method drop_all_users_from_database ( Int :$timeout --> Hash ) {
      my Pair @req = (
        dropAllUsersFromDatabase => 1
      );

      @req.push(( writeConcern => { j => True, wtimeout => $timeout }))
        if ?$timeout;

      my Hash $doc = $!database.run_command(@req);
      if $doc<ok>.Bool == False {
        die X::MongoDB::Database.new(
          error-text => $doc<errmsg>,
          oper-name => 'drop_user',
          oper-data => @req.perl,
          database-name => [~] $!database.name
        );
      }

      # Return its value of the status document
      #
      return $doc;
    }

    #---------------------------------------------------------------------------
    #
    method grant_roles_to_user (
      Str :$user, Array :$roles, Int :$timeout
      --> Hash
    ) {
      my Pair @req = ( grantRolesToUser => $user );

      @req.push((roles => $roles)) if ?$roles;
      @req.push(( writeConcern => { j => True, wtimeout => $timeout }))
        if ?$timeout;

      my Hash $doc = $!database.run_command(@req);
      if $doc<ok>.Bool == False {
        die X::MongoDB::Database.new(
          error-text => $doc<errmsg>,
          oper-name => 'drop_user',
          oper-data => @req.perl,
          database-name => [~] $!database.name
        );
      }

      # Return its value of the status document
      #
      return $doc;
    }

    #---------------------------------------------------------------------------
    #
    method revoke_roles_from_user (
      Str :$user, Array :$roles, Int :$timeout
      --> Hash
    ) {
      my Pair @req = ( revokeRolesFromUser => $user );

      @req.push((roles => $roles)) if ?$roles;
      @req.push(( writeConcern => { j => True, wtimeout => $timeout }))
        if ?$timeout;

      my Hash $doc = $!database.run_command(@req);
      if $doc<ok>.Bool == False {
        die X::MongoDB::Database.new(
          error-text => $doc<errmsg>,
          oper-name => 'drop_user',
          oper-data => @req.perl,
          database-name => [~] $!database.name
        );
      }

      # Return its value of the status document
      #
      return $doc;
    }

    #---------------------------------------------------------------------------
    #
    method update_user (
      Str :$user, Str :$password,
      :$custom_data, Array :$roles, Int :$timeout
      --> Hash
    ) {
      my Pair @req = ( updateUser => $user, digestPassword => False );

      if ?$password {
        if $password.chars < $!min-pw-length {
          die X::MongoDB::Database.new(
            error-text => "Password too short, must be >= $!min-pw-length",
            oper-name => 'create_user',
            oper-data => $password,
            database-name => [~] $!database.name
          );
        }

        my Bool $pw-ok = False;
        given $!pw-attribs-code {
          when $PW-LOWERCASE {
            $pw-ok = ($password ~~ m/ <[a..z]> /).Bool;
          }

          when $PW-UPPERCASE {
            $pw-ok = (
              $password ~~ m/ <[a..z]> / and
              $password ~~ m/ <[A..Z]> /
            ).Bool;
          }

          when $PW-NUMBERS {
            $pw-ok = (
              $password ~~ m/ <[a..z]> / and
              $password ~~ m/ <[A..Z]> / and
              $password ~~ m/ \d /
            ).Bool;
          }

          when $PW-OTHER-CHARS {
            $pw-ok = (
              $password ~~ m/ <[a..z]> / and
              $password ~~ m/ <[A..Z]> / and
              $password ~~ m/ \d / and
              $password ~~ m/ <[`~!@\#\$%^&*()\-_=+[{\]};:\'\"\\\|,<.>\/\?]> /
            ).Bool;
          }
        }

        if $pw-ok {
          @req.push((pwd => Digest::MD5.md5_hex("$user:mongo:$password")));
        }

        else {
          die X::MongoDB::Database.new(
            error-text => "Password does not have the proper elements",
            oper-name => 'create_user',
            oper-data => $password,
            database-name => [~] $!database.name
          );
        }
      }

      @req.push((writeConcern => { j => True, wtimeout => $timeout }))
        if ?$timeout;

      @req.push((roles => $roles)) if ?$roles;
      @req.push((customData => $custom_data)) if ?$custom_data;

      my Hash $doc = $!database.run_command(@req);
      if $doc<ok>.Bool == False {
        die X::MongoDB::Database.new(
          error-text => $doc<errmsg>,
          oper-name => 'create_user',
          oper-data => @req.perl,
          database-name => [~] $!database.name
        );
      }

      # Return its value of the status document
      #
      return $doc;
    }

    #---------------------------------------------------------------------------
    #
    method users_info (
      Str :$user,
      Bool :$show_credentials,
      Bool :$show_privileges,
      Str :$database
      --> Hash
    ) {
      my Pair @req = (
        usersInfo => { user => $user, db => $database // $!database.name}
      );

      @req.push((showCredentials => True)) if ?$show_credentials;
      @req.push((showPrivileges => True)) if ?$show_privileges;

      my Hash $doc = $!database.run_command(@req);
      if $doc<ok>.Bool == False {
        die X::MongoDB::Database.new(
          error-text => $doc<errmsg>,
          oper-name => 'drop_user',
          oper-data => @req.perl,
          database-name => [~] $database // $!database.name
        );
      }

      # Return its value of the status document
      #
      return $doc;
    }

    #---------------------------------------------------------------------------
    #
    method get_users ( --> Hash ) {
      my Pair @req = ( usersInfo => 1 );

      my Hash $doc = $!database.run_command(@req);
      if $doc<ok>.Bool == False {
        die X::MongoDB::Database.new(
          error-text => $doc<errmsg>,
          oper-name => 'drop_user',
          oper-data => @req.perl,
          database-name => $!database.name
        );
      }

      # Return its value of the status document
      #
      return $doc;
    }
  }
}
