use v6;
use MongoDB::Database;
use Digest::MD5;

#-------------------------------------------------------------------------------
#
package MongoDB {

  #-----------------------------------------------------------------------------
  #
  class MongoDB::Users {

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
      Int:D :$min-un-length where $min-un-length >= 2,
      Int:D :$min-pw-length where $min-pw-length >= 2,
      Int :$pw_attribs = $PW-LOWERCASE
    ) is DEPRECATED('set-pw-security') {

      self.set-pw-security( :$min-un-length, :$min-pw-length, :$pw_attribs);
    }

    method set-pw-security (
      Int:D :$min-un-length where $min-un-length >= 2,
      Int:D :$min-pw-length where $min-pw-length >= 2,
      Int :$pw_attribs = $PW-LOWERCASE
    ) {

      given $pw_attribs {
        when $PW-LOWERCASE {
          $!min-pw-length = $min-pw-length // 2;
        }

        when $PW-UPPERCASE {
          $!min-pw-length = $min-pw-length // 2;
        }

        when $PW-NUMBERS {
          $!min-pw-length = $min-pw-length // 3;
        }

        when $PW-OTHER-CHARS {
          $!min-pw-length = $min-pw-length // 4;
        }

        default {
          $!min-pw-length = $min-pw-length // 2;
        }
      }

      $!pw-attribs-code = $pw_attribs;
      $!min-un-length = $min-un-length;
    }

    #---------------------------------------------------------------------------
    # Create a user in the mongodb authentication database
    #
    method create_user (
      Str:D :$user, Str:D :$password,
      :$custom-data, Array :$roles, Int :timeout($wtimeout)
      --> Hash
    ) is DEPRECATED('create-user') {
    
      my $h = self.create-user(
        :$user, :$password, :$custom-data, :$roles, :timeout($wtimeout)
      );
      return $h;
    }

    method create-user (
      Str:D :$user, Str:D :$password,
      :$custom-data, Array :$roles, Int :timeout($wtimeout)
      --> Hash
    ) {
      # Check if username is too short
      #
      if $user.chars < $!min-un-length {
        die X::MongoDB.new(
          error-text => "Username too short, must be >= $!min-un-length",
          oper-name => 'create-user',
          oper-data => $user,
          collection-ns => $!database.name
        );
      }

      # Check if password is too short
      #
      elsif $password.chars < $!min-pw-length {
        die X::MongoDB.new(
          error-text => "Password too short, must be >= $!min-pw-length",
          oper-name => 'create-user',
          oper-data => $password,
          collection-ns => $!database.name
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
        die X::MongoDB.new(
          error-text => "Password does not have the proper elements",
          oper-name => 'create-user',
          oper-data => $password,
          collection-ns => $!database.name
        ) unless $pw-ok;
      }

      # Create user where digestPassword is set false
      #
      my Pair @req =
        :createUser($user),
        :pwd(Digest::MD5.md5_hex( [~] $user, ':mongo:', $password)),
        :!digestPassword
      ;

      @req.push: (:$roles) if ?$roles;
      @req.push: (:customData($custom-data)) if ?$custom-data;
      @req.push: (:writeConcern({ :j, :$wtimeout})) if ?$wtimeout;

      my Hash $doc = $!database.run-command(@req);
      if $doc<ok>.Bool == False {
        die X::MongoDB.new(
          error-text => $doc<errmsg>,
          oper-name => 'create-user',
          oper-data => @req.perl,
          collection-ns => $!database.name
        );
      }

      # Return its value of the status document
      #
      return $doc;
    }

    #---------------------------------------------------------------------------
    #
    method drop_user (
      Str:D :$user, Int :timeout($wtimeout)
      --> Hash
    ) is DEPRECATED('drop-user') {
      
      my $h = self.drop-user( $user, :timeout($wtimeout));
      return $h;
    }

    method drop-user ( Str:D :$user, Int :timeout($wtimeout) --> Hash ) {

      my Pair @req = dropUser => $user;
      @req.push: (:writeConcern({ :j, :$wtimeout})) if ?$wtimeout;

      my Hash $doc = $!database.run-command(@req);
      if $doc<ok>.Bool == False {
        die X::MongoDB.new(
          error-text => $doc<errmsg>,
          oper-name => 'drop-user',
          oper-data => @req.perl,
          collection-ns => $!database.name
        );
      }

      # Return its value of the status document
      #
      return $doc;
    }

    #---------------------------------------------------------------------------
    #
    method drop_all_users_from_database (
      Int :timeout($wtimeout)
      --> Hash
    ) is DEPRECATED('drop-all-users-from-database') {

      my $h = self.drop-all-users-from-database(:timeout($wtimeout));
      return $h;
    }

    method drop-all-users-from-database ( Int :timeout($wtimeout) --> Hash ) {

      my Pair @req = dropAllUsersFromDatabase => 1;
      @req.push: (:writeConcern({ :j, :$wtimeout})) if ?$wtimeout;

      my Hash $doc = $!database.run-command(@req);
      if $doc<ok>.Bool == False {
        die X::MongoDB.new(
          error-text => $doc<errmsg>,
          oper-name => 'drop_all_users_from_database',
          oper-data => @req.perl,
          collection-ns => $!database.name
        );
      }

      # Return its value of the status document
      #
      return $doc;
    }

    #---------------------------------------------------------------------------
    #
    method grant_roles_to_user (
      Str:D :$user, Array:D :$roles, Int :timeout($wtimeout)
      --> Hash
    ) is DEPRECATED('grant-roles-to-user') {
      my $h = self.grant-roles-to-user( :$user, :$roles, :timeout($wtimeout));
      return $h;
    }

    method grant-roles-to-user (
      Str:D :$user, Array:D :$roles, Int :timeout($wtimeout)
      --> Hash
    ) {

      my Pair @req = grantRolesToUser => $user;
      @req.push: (:$roles) if ?$roles;
      @req.push: (:writeConcern({ :j, :$wtimeout})) if ?$wtimeout;

      my Hash $doc = $!database.run-command(@req);
      if $doc<ok>.Bool == False {
        die X::MongoDB.new(
          error-text => $doc<errmsg>,
          oper-name => 'grant_roles_to_user',
          oper-data => @req.perl,
          collection-ns => $!database.name
        );
      }

      # Return its value of the status document
      #
      return $doc;
    }

    #---------------------------------------------------------------------------
    #
    method revoke_roles_from_user (
      Str:D :$user, Array:D :$roles, Int :timeout($wtimeout)
      --> Hash
    ) is DEPRECATED('revoke-roles-from-user') {
      my $h = self.revoke-roles-from-user( :$user, :$roles, :timeout($wtimeout));
      return $h;
    }

    method revoke-roles-from-user (
      Str:D :$user, Array:D :$roles, Int :timeout($wtimeout)
      --> Hash
    ) {

      my Pair @req = :revokeRolesFromUser($user);
      @req.push: (:$roles) if ?$roles;
      @req.push: (:writeConcern({ :j, :$wtimeout})) if ?$wtimeout;

      my Hash $doc = $!database.run-command(@req);
      if $doc<ok>.Bool == False {
        die X::MongoDB.new(
          error-text => $doc<errmsg>,
          oper-name => 'revoke-roles-from-user',
          oper-data => @req.perl,
#          oper-doc => $doc.perl,
          collection-ns => $!database.name
        );
      }

      # Return its value of the status document
      #
      return $doc;
    }

    #---------------------------------------------------------------------------
    #
    method update_user (
      Str:D :$user, Str :$password,
      :custom-data($customData), Array :$roles, Int :timeout($wtimeout)
      --> Hash
    ) is DEPRECATED('update-user') {
      my $h = self.update-user(
        :$user, :$password, :custom-data($customData),
        :$roles, :timeout($wtimeout)
      );
      return $h;
    }

    method update-user (
      Str:D :$user, Str :$password,
      :custom-data($customData), Array :$roles, Int :timeout($wtimeout)
      --> Hash
    ) {

      my Pair @req = :updateUser($user), :digestPassword;

      if ?$password {
        if $password.chars < $!min-pw-length {
          die X::MongoDB.new(
            error-text => "Password too short, must be >= $!min-pw-length",
            oper-name => 'update-user',
            oper-data => $password,
            collection-ns => $!database.name
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
          @req.push: (:pwd(Digest::MD5.md5_hex("$user:mongo:$password")));
        }

        else {
          die X::MongoDB.new(
            error-text => "Password does not have the proper elements",
            oper-name => 'update-user',
            oper-data => $password,
            collection-ns => $!database.name
          );
        }
      }

      @req.push: (:writeConcern({ :j, :$wtimeout})) if ?$wtimeout;
      @req.push: (:$roles) if ?$roles;
      @req.push: (:$customData) if ?$customData;

      my Hash $doc = $!database.run-command(@req);
      if $doc<ok>.Bool == False {
        die X::MongoDB.new(
          error-text => $doc<errmsg>,
          oper-name => 'update-user',
          oper-data => @req.perl,
          collection-ns => $!database.name
        );
      }

      # Return its value of the status document
      #
      return $doc;
    }

    #---------------------------------------------------------------------------
    #
    method users_info (
      Str:D :$user,
      Bool :$show-credentials,
      Bool :$show-privileges,
      Str :$database
      --> Hash
    ) is DEPRECATED('users-info') {
      
      my $h = self.users(
        :$user, :$show-credentials, :$show-privileges, :$database
      );
    }

    method users-info (
      Str:D :$user,
      Bool :$show-credentials,
      Bool :$show-privileges,
      Str :$database
      --> Hash
    ) {

      my Pair @req = :usersInfo({ :$user, :db($database // $!database.name)});
      @req.push: (:showCredentials) if ?$show-credentials;
      @req.push: (:showPrivileges) if ?$show-privileges;

      my Hash $doc = $!database.run-command(@req);
      if $doc<ok>.Bool == False {
        die X::MongoDB.new(
          error-text => $doc<errmsg>,
          oper-name => 'users-info',
          oper-data => @req.perl,
          collection-ns => $database // $!database.name
        );
      }

      # Return its value of the status document
      #
      return $doc;
    }

    #---------------------------------------------------------------------------
    #
    method get_users ( --> Hash ) is DEPRECATED('get-users') {
      return self.get-users;
    }

    method get-users ( --> Hash ) {

      my Pair @req = usersInfo => 1;

      my Hash $doc = $!database.run-command(@req);
      if $doc<ok>.Bool == False {
        die X::MongoDB.new(
          error-text => $doc<errmsg>,
          oper-name => 'get-users',
          oper-data => @req.perl,
          collection-ns => $!database.name
        );
      }

      # Return its value of the status document
      #
      return $doc;
    }
  }
}
