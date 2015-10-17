use v6;

package MongoDB:ver<0.25.6> {

  #-----------------------------------------------------------------------------
  #
  our $version = Nil;
}

#-------------------------------------------------------------------------------
#
class X::MongoDB is Exception {
  has Str $.error-text;       # Error text and error code are data mostly
  has Str $.error-code;       # originated from the mongod server
  has Str $.oper-name;        # Used operation or server request
  has Str $.oper-data;        # Operation data are items sent to the server
  has Str $.database-name;    # Database name involved
  has Str $.collection-name;  # Collection name involved
  has Str $.method;           # Method or routine name
  has Str $.line;             # Line number where X::MongoDB is created
  has Str $.file;             # File in which that happened

  submethod BUILD (
    Str:D :$error-text,
    Str:D :$error-code,
    Str:D :$oper-name,
    Str :$oper-data,
    Str :$database-name,
    Str :$collection-name
  ) {

    my %h;
    for 0..Inf -> $fn {
      my $cf = callframe($fn);

      # End loop with the program that starts on line 1
      #
      last if $cf.file ~~ m/perl6.moar/ and $cf.line == 1;

      # Skip all in between modules of perl
      # THIS DEPENDS ON MOARVM OR JVM INSTALLED IN 'gen/' !!
      #
      next if $cf.file ~~ m/ ^ 'gen/' [ 'moar' || 'jvm' ] /;

      # Skip this module too
      #
      next if $cf.file ~~ m/ 'MongoDB.pm' $ /;

      # Get info when we see a Sub, Method or Submethod. Other types are
      # skipped. This will get us to the calling function.
      #
      if $cf.code.^name ~~ m/ [ 'Sub' | 'Method' | 'Submethod' ] / {
        $!line = $cf.line;
        $!file = $cf.file;

        $cf = callframe($fn + 1);
        $!method = $cf.code.name;

        # We have our info so stop
        #
        last;
      }
    }

    $!error-text      = $error-text;
    $!error-code      = $error-code;
    $!oper-name       = $oper-name;
    $!oper-data       = $oper-data;
    $!database-name   = $database-name;
    $!collection-name = $collection-name;
  }

  method message () {
    return [~] "\n$!oper-name\() error:\n  $!error-text",
               ? $!error-code ?? "\($!error-code)" !! '',
               ? $!oper-data ?? "\n  Request data $!oper-data" !! '',
               ? $!database-name ?? "\n  Database '$!database-name'" !! '',
               ? $!collection-name ?? "\n  Collection $!collection-name" !! '',
               ? $!method ?? "\n  In method $!method" !! '',
               "\n  At: $!file\:$!line\n"
               ;
  }
}

