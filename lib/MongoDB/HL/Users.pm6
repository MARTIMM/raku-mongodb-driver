use v6.c;
use Digest::MD5;
use MongoDB;
use MongoDB::Database;
use BSON::Document;
#use Unicode::PRECIS;
#use Unicode::PRECIS::Identifier::UsernameCasePreserved;
#use Unicode::PRECIS::FreeForm::OpaqueString;

#-------------------------------------------------------------------------------
#
unit package MongoDB:auth<https://github.com/MARTIMM>;

constant C-PW-LOWERCASE is export = 0;
constant C-PW-UPPERCASE is export = 1;
constant C-PW-NUMBERS is export = 2;
constant C-PW-OTHER-CHARS is export = 3;

#-----------------------------------------------------------------------------
#
class MongoDB::HL::Users {

  has MongoDB::Database $.database;
  has Int $.min-un-length = 2;
  has Int $.min-pw-length = 2;
  has Int $.pw-attribs-code = MongoDB::C-PW-LOWERCASE;

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
    Int :$pw_attribs = MongoDB::C-PW-LOWERCASE
  ) {

    given $pw_attribs {
      when MongoDB::C-PW-LOWERCASE {
        $!min-pw-length = $min-pw-length // 2;
      }

      when MongoDB::C-PW-UPPERCASE {
        $!min-pw-length = $min-pw-length // 2;
      }

      when MongoDB::C-PW-NUMBERS {
        $!min-pw-length = $min-pw-length // 3;
      }

      when MongoDB::C-PW-OTHER-CHARS {
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
    List :$custom-data, Array :$roles,
#      Int :timeout($wtimeout)
    --> BSON::Document
  ) {
    # Check if username is too short
    #
    if $user.chars < $!min-un-length {
      fatal-message(
        "Username too short, must be >= $!min-un-length",
        oper-data => $user,
        collection-ns => $!database.name
      );
    }

    # Check if password is too short
    #
    elsif $password.chars < $!min-pw-length {
      fatal-message(
        "Password too short, must be >= $!min-pw-length",
        oper-data => $password,
        collection-ns => $!database.name
      );
    }

    # Check if password answers to rule given by attribute code
    #
    else {
      my Bool $pw-ok = False;
      given $!pw-attribs-code {
        when MongoDB::C-PW-LOWERCASE {
          $pw-ok = ($password ~~ m/ <[a..z]> /).Bool;
        }

        when MongoDB::C-PW-UPPERCASE {
          $pw-ok = (
            $password ~~ m/ <[a..z]> / and
            $password ~~ m/ <[A..Z]> /
          ).Bool;
        }

        when MongoDB::C-PW-NUMBERS {
          $pw-ok = (
            $password ~~ m/ <[a..z]> / and
            $password ~~ m/ <[A..Z]> / and
            $password ~~ m/ \d /
          ).Bool;
        }

        when MongoDB::C-PW-OTHER-CHARS {
          $pw-ok = (
            $password ~~ m/ <[a..z]> / and
            $password ~~ m/ <[A..Z]> / and
            $password ~~ m/ \d / and
            $password ~~ m/ <[`~!@\#\$%^&*()\-_=+[{\]};:\'\"\\\|,<.>\/\?]> /
          ).Bool;
        }
      }

      fatal-message(
        "Password does not have the right properties",
        oper-data => $password,
        collection-ns => $!database.name
      ) unless $pw-ok;
    }

#TODO normalization done here or on server? assume on server.
#`{{
    # Normalize username and password
    my Unicode::PRECIS::Identifier::UsernameCasePreserved $upi-ucp .= new;
    my TestValue $tv-un = $upi-ucp.prepare($user);
    fatal-message("Username $user not accepted") if $tv-un ~~ Bool;
    info-message("Username '$user' accepted as '$tv-un'");

    my Unicode::PRECIS::FreeForm::OpaqueString $upf-os .= new;
    my TestValue $tv-pw = $upf-os.prepare($password);
    fatal-message("Password not accepted") if $tv-un ~~ Bool;
    info-message("Password accepted");

    # Create user where digestPassword is set false
    my BSON::Document $req .= new: (
      createUser => $user,
      pwd => (Digest::MD5.md5_hex( [~] $tv-un, ':mongo:', $tv-pw)),
      digestPassword => False
    );
}}

    # Create user where digestPassword is set false
    my BSON::Document $req .= new: (
      createUser => $user,
      pwd => (Digest::MD5.md5_hex( [~] $user, ':mongo:', $password)),
      digestPassword => False
    );

    $req<roles> = $roles if ?$roles;
    $req<customData> = $custom-data if ?$custom-data;
#      $req<writeConcern> = ( :j, :$wtimeout) if ?$wtimeout;
    return $!database.run-command($req);
  }

  #---------------------------------------------------------------------------
  #
  method update-user (
    Str:D $user, Str :$password,
    :$custom-data, Array :$roles,
#      Int :timeout($wtimeout)
    --> BSON::Document
  ) {

    my BSON::Document $req .= new: (
      updateUser => $user,
      digestPassword => True
    );

    if ?$password {
      if $password.chars < $!min-pw-length {
        fatal-message(
          "Password too short, must be >= $!min-pw-length",
          oper-data => $password,
          collection-ns => $!database.name
        );
      }

      my Bool $pw-ok = False;
      given $!pw-attribs-code {
        when MongoDB::C-PW-LOWERCASE {
          $pw-ok = ($password ~~ m/ <[a..z]> /).Bool;
        }

        when MongoDB::C-PW-UPPERCASE {
          $pw-ok = (
            $password ~~ m/ <[a..z]> / and
            $password ~~ m/ <[A..Z]> /
          ).Bool;
        }

        when MongoDB::C-PW-NUMBERS {
          $pw-ok = (
            $password ~~ m/ <[a..z]> / and
            $password ~~ m/ <[A..Z]> / and
            $password ~~ m/ \d /
          ).Bool;
        }

        when MongoDB::C-PW-OTHER-CHARS {
          $pw-ok = (
            $password ~~ m/ <[a..z]> / and
            $password ~~ m/ <[A..Z]> / and
            $password ~~ m/ \d / and
            $password ~~ m/ <[`~!@\#\$%^&*()\-_=+[{\]};:\'\"\\\|,<.>\/\?]> /
          ).Bool;
        }
      }

      if $pw-ok {

#TODO normalization done here or on server? assume on server.
#`{{
        # Normalize username and password
        my Unicode::PRECIS::Identifier::UsernameCasePreserved $upi-ucp .= new;
        my TestValue $tv-un = $upi-ucp.prepare($user);
        fatal-message("Username $user not accepted") if $tv-un ~~ Bool;
        info-message("Username '$user' accepted as '$tv-un'");

        my Unicode::PRECIS::FreeForm::OpaqueString $upf-os .= new;
        my TestValue $tv-pw = $upf-os.prepare($password);
        fatal-message("Password not accepted") if $tv-un ~~ Bool;
        info-message("Password accepted");

        $req<pwd> = (Digest::MD5.md5_hex([~] $tv-un, ':mongo:', $tv-pw));
}}
        $req<pwd> = (Digest::MD5.md5_hex([~] $user, ':mongo:', $password));
      }

      else {
        fatal-message(
          "Password does not have the proper elements",
          oper-data => $password,
          collection-ns => $!database.name
        );
      }
    }

#      $req<writeConcern> = ( :j, :$wtimeout) if ?$wtimeout;
    $req<roles> = $roles if ?$roles;
    $req<customData> = $custom-data if ?$custom-data;
    return $!database.run-command($req);
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
        warn-message(
          $doc<errmsg>,
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
        warn-message(
          $doc<errmsg>,
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
        warn-message(
          $doc<errmsg>,
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
        warn-message(
          $doc<errmsg>,
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
        warn-message(
          $doc<errmsg>,
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
        warn-message(
          $doc<errmsg>,
          oper-data => @req.perl,
          collection-ns => $!database.name
        );
      }

      # Return its value of the status document
      #
      return $doc;
    }

}}
