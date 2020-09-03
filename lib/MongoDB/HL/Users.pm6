#tl:1:MongoDB::HL::Users:

use v6;

use OpenSSL::Digest;
use MongoDB;
use MongoDB::Database;
use BSON::Document;
use Unicode::PRECIS;
use Unicode::PRECIS::Identifier::UsernameCasePreserved;
use Unicode::PRECIS::FreeForm::OpaqueString;

#-------------------------------------------------------------------------------
unit class MongoDB::HL::Users:auth<hgithub:MARTIMM>;

#tm:1:database:
has MongoDB::Database $.database;

#tm:1:min-un-length:
has Int $.min-un-length = MongoDB::C-PW-MIN-UN-LEN;

#tm:1:min-pw-length:
has Int $.min-pw-length = MongoDB::C-PW-MIN-PW-LEN;

#tm:1:pw-attribs:
has Int $.pw-attribs = MongoDB::C-PW-OTHER-CHARS;

#-------------------------------------------------------------------------------
#tm:1:new:
submethod BUILD ( MongoDB::Database :$database ) {

#TODO validate name
  $!database = $database;
}

#-------------------------------------------------------------------------------
#tm:1:set-pw-security:
method set-pw-security (
  Int:D :$min-un-length where $_ >= 2,
  Int:D :$min-pw-length where $_ >= 6,
  Int :$pw-attribs = MongoDB::C-PW-OTHER-CHARS
) {

  given $pw-attribs {
    when MongoDB::C-PW-LOWERCASE {
      $!min-pw-length = $min-pw-length // 10;
    }

    when MongoDB::C-PW-UPPERCASE {
      $!min-pw-length = $min-pw-length // 10;
    }

    when MongoDB::C-PW-NUMBERS {
      $!min-pw-length = $min-pw-length // 8;
    }

    when MongoDB::C-PW-OTHER-CHARS {
      $!min-pw-length = $min-pw-length // 6;
    }

    default {
      $!min-pw-length = $min-pw-length // 6;
    }
  }

  $!pw-attribs = $pw-attribs;
  $!min-un-length = $min-un-length;
}

#-------------------------------------------------------------------------------
# Create a user in the mongodb authentication database
#tm:1:create-user:
method create-user (
  Str:D $user, Str:D $password,
  List :$custom-data, Array :$roles,
#      Int :timeout($wtimeout)
  --> BSON::Document
) {

  # Check if username is too short
  if $user.chars < $!min-un-length {
    fatal-message("Username too short, must be >= $!min-un-length");
  }

  # Check if password is too short
  #
  elsif $password.chars < $!min-pw-length {
    fatal-message("Password too short, must be >= $!min-pw-length");
  }

  # Check if password answers to rule given by attribute code
  #
  else {
    my Bool $pw-ok = False;
    given $!pw-attribs {
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

    fatal-message("Password does not have the right properties")
      unless $pw-ok;
  }

#TODO normalization done here or on server? assume on server.
#`{{}}
  # Normalize username and password
  my Unicode::PRECIS::Identifier::UsernameCasePreserved $upi-ucp .= new;
  my TestValue $tv-un = $upi-ucp.prepare($user);
  fatal-message("Username $user not accepted") if $tv-un ~~ Bool;
  info-message("Username '$user' accepted as '$tv-un'");

  my Unicode::PRECIS::FreeForm::OpaqueString $upf-os .= new;
  my TestValue $tv-pw = $upf-os.prepare($password);
  fatal-message("Password not accepted") if $tv-pw ~~ Bool;
  info-message("Password accepted");

  # Create user where digestPassword is set false
  my BSON::Document $req .= new: (
    createUser => $user,
#      pwd => md5(([~] $tv-un, ':mongo:', $tv-pw).encode)>>.fmt('%02x').join(''),
    pwd => $tv-pw,
#      digestPassword => False
  );

#`{{
  # Create user where digestPassword is set false
  my BSON::Document $req .= new: (
    createUser => $user,
    pwd => md5(([~] $user, ':mongo:', $password).encode)>>.fmt('%02x').join(''),
    digestPassword => False
  );
}}
  $req<roles> = $roles if ?$roles;
  $req<customData> = $custom-data if ?$custom-data;
#      $req<writeConcern> = ( :j, :$wtimeout) if ?$wtimeout;

#note "request: ", $req.perl;
  return $!database.run-command($req);
}

#-------------------------------------------------------------------------------
#tm:1:update-user:
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
    given $!pw-attribs {
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
      $req<pwd> = md5(([~] $user, ':mongo:', $password).encode)>>.fmt('%02x').join('');
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




=finish

#TODO install below routines again and test

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
