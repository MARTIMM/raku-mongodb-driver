use v6;

package MongoDB:ver<0.25.6> {

  #-----------------------------------------------------------------------------
  #
  our $version = Nil;



  #-----------------------------------------------------------------------------
  #
  class X::MongoDB is Exception {
    has Str $.error-text;       # Error text and error code are data mostly
    has Str $.error-code;       # originated from the mongod server
    has Str $.oper-name;        # Used operation or server request
    has Str $.oper-data;        # Operation data are items sent to the server
    has Str $.class-name;       # Class name
    has Str $.method;           # Method or routine name
    has Str $.database-name;    # Database name involved
    has Str $.collection-name;  # Collection name involved

    submethod BUILD (
      Str :$error-text,
      Str :$error-code,
      Str :$oper-name,
      Str :$oper-data,
      Str :$class-name,
      Str :$method,
      Str :$database-name,
      Str :$collection-name
    ) {
      $!error-text      = $error-text;
      $!error-code      = $error-code;
      $!oper-name       = $oper-name;
      $!oper-data       = $oper-data;
      $!class-name      = $class-name;
      $!method          = $method;
      $!database-name   = $database-name;
      $!collection-name = $collection-name;
    }

    method message () {
      return [~] "\n$!oper-name\() error:\n  $!error-text",
                 ? $!error-code ?? "\($!error-code)" !! '',
                 ? $!oper-data ?? "\n  Data $!oper-data" !! '',
                 ? $!class-name ?? "\n  Data $!class-name" !! '',
                 ? $!method ?? "\n  Data $!method" !! '',
                 ? $!database-name ?? "\n  Database '$!database-name'\n" !! '',
                 ? $!collection-name ?? "\n  Data $!collection-name" !! ''
                 ;
    }
  }
}

