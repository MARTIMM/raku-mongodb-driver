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
    has Str $.line;             # Line number where X::MongoDB is created
    has Str $.file;             # File in which that happened

    submethod BUILD (
      Str :$error-text!,
      Str :$error-code,
      Str :$oper-name,
      Str :$oper-data,
      Str :$class-name,
      Str :$method,
      Str :$database-name,
      Str :$collection-name
    ) {
#`{{
my $cf = callframe(0);
say "CF: ";
say $cf.^methods;
say $cf.^attributes;
say '';
}}
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

#`{{
        say "\nFrom: ", $fn.fmt('[%02d] '), $cf.file, ', ', $cf.line;
        say "Type: ", $cf.code.^name;
        say "Methods: ", $cf.code.^methods;
}}
        if $cf.code.^name ~~ m/ [ 'Sub' | 'Method' | 'Submethod' ] / {
#`{{
          say "Name: ", ~&($cf.code);
          say "  Methods: ", $cf.code.^methods;
#          say "O attr: ", $cf.code.Str.^attributes;
          say "  Perl: ", $cf.code.perl;
          say "  Pack: ", $cf.code.WHO;
#          say "  Outer: ", $cf.OUTER::.keys;
          say "  class: ", $cf.code.WHAT;
#          say "  outer: ", ~&$cf.code.outer.code;
}}

#          say "  Perl: ", $cf.code.perl;

          $!line = $cf.line;
          $!file = $cf.file;

          $cf = callframe($fn + 1);
          %h<method> = ~&($cf.code);
          say "  name: ", ~&($cf.code);
          say "  class: ", $cf.code.WHAT;
        }

        # We have our info so stop
        #
        last;
      }

      $!error-text      = $error-text;
      $!error-code      = $error-code;
      $!oper-name       = $oper-name;
      $!oper-data       = $oper-data;
      $!class-name      = $class-name;
      $!method          = $method // %h<method>;
      $!database-name   = $database-name;
      $!collection-name = $collection-name;
    }

    method message () {
      return [~] "\n$!oper-name\() error:\n  $!error-text",
                 ? $!error-code ?? "\($!error-code)" !! '',
                 ? $!oper-data ?? "\n  Request data $!oper-data" !! '',
                 ? $!database-name ?? "\n  Database '$!database-name'" !! '',
                 ? $!collection-name ?? "\n  Collection $!collection-name" !! '',
                 ? $!class-name ?? "\n  Class name $!class-name" !! '',
                 ? $!method ?? "\n  In method $!method" !! '',
                 "\n  At: $!file\:$!line\n"
                 ;
    }
  }
}

