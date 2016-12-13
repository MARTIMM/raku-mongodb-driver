use v6.c;

#use MongoDB;

#-------------------------------------------------------------------------------
# https://github.com/mongodb/specifications/blob/master/source/auth/auth.rst#client-implementation
unit package MongoDB:auth<https://github.com/MARTIMM>;

#-------------------------------------------------------------------------------
class Authenticate::Credential {
  has Str $.username;
  has Str $.password;
  has Str $.source;

  # preferred to use this instead of mechanism because of uri
  # option autMechanism
  #
  has Str $.auth-mechanism;
  has Str $.mechanism-properties;

  #-----------------------------------------------------------------------------
  submethod BUILD (
    Str :$username, Str :$password,
    Str :$source, Str :$auth-mechanism,
    Str :$mechanism-properties
  ) {

    $!username = $username // '';
    $!password = $password // '';
    $!source = $source // '';
    $!auth-mechanism = $auth-mechanism // '';
    $!mechanism-properties = $mechanism-properties // '';
  }

  #-----------------------------------------------------------------------------
  method auth-mechanism ( Str :$auth-mechanism --> Str ) {

    $!auth-mechanism = $auth-mechanism if ? $auth-mechanism;
    $!auth-mechanism;
  }
}

