use v6;
use Digest::MD5;
use MongoDB::Database;
use BSON::Document;

#-------------------------------------------------------------------------------
#
package MongoDB {

  #-----------------------------------------------------------------------------
  #
  class MongoDB::Users {

    constant C-PW-LOWERCASE = 0;
    constant C-PW-UPPERCASE = 1;
    constant C-PW-NUMBERS = 2;
    constant C-PW-OTHER-CHARS = 3;

    has MongoDB::Database $.database;
    has Int $.min-un-length = 2;
    has Int $.min-pw-length = 2;
    has Int $.pw-attribs-code = C-PW-LOWERCASE;

    #---------------------------------------------------------------------------
    #
    submethod BUILD ( MongoDB::Database :$database ) {

#TODO validate name
      $!database = $database;
    }

    #---------------------------------------------------------------------------
    #
    method set-pw-security (
      Int:D :$min-un-length where $min-un-length >= 2,
      Int:D :$min-pw-length where $min-pw-length >= 2,
      Int :$pw_attribs = C-PW-LOWERCASE
    ) {

      given $pw_attribs {
        when C-PW-LOWERCASE {
          $!min-pw-length = $min-pw-length // 2;
        }

        when C-PW-UPPERCASE {
          $!min-pw-length = $min-pw-length // 2;
        }

        when C-PW-NUMBERS {
          $!min-pw-length = $min-pw-length // 3;
        }

        when C-PW-OTHER-CHARS {
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
    method create-user (
      Str:D $user, Str:D $password,
      List :$custom-data, Array :$roles, Int :timeout($wtimeout)
      --> BSON::Document
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
          when C-PW-LOWERCASE {
            $pw-ok = ($password ~~ m/ <[a..z]> /).Bool;
          }

          when C-PW-UPPERCASE {
            $pw-ok = (
              $password ~~ m/ <[a..z]> / and
              $password ~~ m/ <[A..Z]> /
            ).Bool;
          }

          when C-PW-NUMBERS {
            $pw-ok = (
              $password ~~ m/ <[a..z]> / and
              $password ~~ m/ <[A..Z]> / and
              $password ~~ m/ \d /
            ).Bool;
          }

          when C-PW-OTHER-CHARS {
            $pw-ok = (
              $password ~~ m/ <[a..z]> / and
              $password ~~ m/ <[A..Z]> / and
              $password ~~ m/ \d / and
              $password ~~ m/ <[`~!@\#\$%^&*()\-_=+[{\]};:\'\"\\\|,<.>\/\?]> /
            ).Bool;
          }
        }
        die X::MongoDB.new(
          error-text => "Password does not have the right properties",
          oper-name => 'create-user',
          oper-data => $password,
          collection-ns => $!database.name
        ) unless $pw-ok;
      }

      # Create user where digestPassword is set false
      #
      my BSON::Document $req .= new: (
        createUser => $user,
        pwd => (Digest::MD5.md5_hex( [~] $user, ':mongo:', $password)),
        digestPassword => False
      );

      $req<roles> = $roles if ?$roles;
      $req<customData> = $custom-data if ?$custom-data;
      $req<writeConcern> = ( :j, :$wtimeout) if ?$wtimeout;
      return $!database.run-command($req);
    }

    #---------------------------------------------------------------------------
    #
    method update-user (
      Str:D $user, Str :$password,
      :custom-data($customData), Array :$roles, Int :timeout($wtimeout)
      --> BSON::Document
    ) {

      my BSON::Document $req .= new: (
        updateUser => $user,
        digestPassword => True
      );

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
          when C-PW-LOWERCASE {
            $pw-ok = ($password ~~ m/ <[a..z]> /).Bool;
          }

          when C-PW-UPPERCASE {
            $pw-ok = (
              $password ~~ m/ <[a..z]> / and
              $password ~~ m/ <[A..Z]> /
            ).Bool;
          }

          when C-PW-NUMBERS {
            $pw-ok = (
              $password ~~ m/ <[a..z]> / and
              $password ~~ m/ <[A..Z]> / and
              $password ~~ m/ \d /
            ).Bool;
          }

          when C-PW-OTHER-CHARS {
            $pw-ok = (
              $password ~~ m/ <[a..z]> / and
              $password ~~ m/ <[A..Z]> / and
              $password ~~ m/ \d / and
              $password ~~ m/ <[`~!@\#\$%^&*()\-_=+[{\]};:\'\"\\\|,<.>\/\?]> /
            ).Bool;
          }
        }

        if $pw-ok {
          $req<pwd> = (Digest::MD5.md5_hex([~] $user, ':mongo:', $password));
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

      $req<writeConcern> = ( :j, :$wtimeout) if ?$wtimeout;
      $req<roles> = $roles if ?$roles;
      $req<customData> = $customData if ?$customData;
      return $!database.run-command($req);
    }
  }
}


=finish
#`{{

    #---------------------------------------------------------------------------
    #
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

}}
