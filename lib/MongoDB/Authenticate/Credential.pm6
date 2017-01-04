use v6.c;

use MongoDB;

#-------------------------------------------------------------------------------
# https://github.com/mongodb/specifications/blob/master/source/auth/auth.rst#client-implementation
unit package MongoDB:auth<https://github.com/MARTIMM>;

#-------------------------------------------------------------------------------
class Authenticate::Credential {
  has Str $.username;
  has Str $.password;

  # preferred to use auth-xyz instead of xyz because of uri options autXyz
  has Str $.auth-source;
  has Str $.auth-mechanism;
  has Hash $.auth-mechanism-properties;

  #-----------------------------------------------------------------------------
  submethod BUILD (
    Str :$username = '', Str :$password = '',
    Str :$auth-source = 'admin', Str :$auth-mechanism = '',
    Str :$auth-mechanism-properties = ''
  ) {

    $!username = $username;
    $!password = $password;
    $!auth-source = $auth-source;
    $!auth-mechanism = $auth-mechanism;

    $!auth-mechanism-properties = {};
    my Str $auth-prop = $auth-mechanism-properties;
    for $auth-prop.split(',') -> $prop {
      my Str ( $key, $value) = $prop.split(':');
      $!auth-mechanism-properties{$key} = $value if ?$key and ?$value;
    }

    self!check-credential;
  }

  #-----------------------------------------------------------------------------
  method auth-mechanism ( Str :$auth-mechanism --> Str ) {

    $!auth-mechanism = $auth-mechanism if ? $auth-mechanism;
    self!check-credential;
    $!auth-mechanism;
  }

  #-----------------------------------------------------------------------------
  method !check-credential ( Str :$auth-mechanism ) {

    my Str $e0 = "with $!auth-mechanism, ";
    my Str $e1 = "be specified";

    given $!auth-mechanism {

      when 'MONGODB-CR' {

        fatal-message("$e0 username must $e1") unless ? $!username;
        fatal-message("$e0 password must $e1") unless ? $!password;
        fatal-message("$e0 source must $e1") unless ? $!auth-source;
        fatal-message("$e0 mechanism properties must not $e1")
          if ? $!auth-mechanism-properties;
      }

      when 'MONGODB-X509' {

        # username is optional

        fatal-message("$e0 password must not $e1") if ? $!password;
        fatal-message("$e0 source must be '\$external'")
          unless ? $!auth-source eq '$external';
        fatal-message("$e0 mechanism properties must not $e1")
          if ? $!auth-mechanism-properties;
      }

      when 'GSSAPI' {

        # password is optional

        fatal-message("$e0 username must $e1") unless ? $!username;
        fatal-message("$e0 source must be '\$external'")
          unless ? $!auth-source eq '$external';

        # $!mechanism-properties can have keys service-name,
        # canonicalize-host-name and service-realm

      }

      when 'PLAIN' {

        fatal-message("$e0 username must $e1") unless ? $!username;
        fatal-message("$e0 password must $e1") unless ? $!password;
        fatal-message("$e0 source must $e1") unless ? $!auth-source;
        fatal-message("$e0 mechanism properties must not $e1")
          if ? $!auth-mechanism-properties;
      }

      when 'SCRAM-SHA-1' {

        fatal-message("$e0 username must $e1") unless ? $!username;
        fatal-message("$e0 password must $e1") unless ? $!password;
        fatal-message("$e0 source must $e1") unless ? $!auth-source;
        fatal-message("$e0 mechanism properties must not $e1")
          if ? $!auth-mechanism-properties;
      }

      default {

        fatal-message("Unknown mechanism '$!auth-mechanism'")
          if ? $!auth-mechanism;
      }
    }
  }
}

