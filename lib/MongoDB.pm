use v6;

#-------------------------------------------------------------------------------
#
package MongoDB:ver<0.25.7> {

  #-----------------------------------------------------------------------------
  #
  our $version = Nil;

  enum Severity <Trace Debug Info Warn Error Fatal>;
  our $severity-throw-level = Fatal;
  our $severity-process-level = Info;
  our $log-fn = 'MongoDB.log';
  our $log-fh;

  #-----------------------------------------------------------------------------
  #
  sub set-exception-throw-level ( Severity:D $s ) is export {
    $severity-throw-level = $s;
  }

  #-----------------------------------------------------------------------------
  #
  sub set-exception-process-level ( Severity:D $s ) is export {
    $severity-process-level = $s;
  }

  #-----------------------------------------------------------------------------
  #
  sub set-logfile-name ( Str:D $filename ) is export {
    $log-fn = $filename;
  }

  #-----------------------------------------------------------------------------
  #
  sub open-logfile (  ) is export {
    $log-fh.close if ?$log-fh;
    $log-fh = $log-fn.IO.open: :a;
  }

  #-----------------------------------------------------------------------------
  # A role to be used to handle exceptions. It is parameterized with the
  # exception and the exception is then visible in all methods.
  #
  role Logging [ Exception $e ] {

    #---------------------------------------------------------------------------
    #
    method log ( --> Exception ) {
      return $e unless ?$e;
      return $e unless $e.severity >= $severity-process-level;

      open-logfile() unless ?$log-fh;

      my Str $etxt = [~] "\n", $e.date-time.Str, " [{uc $e.severity}]";
      $etxt ~= $e."{lc($e.severity)}"();
      $log-fh.print($etxt);
      return $e;
    }

    #---------------------------------------------------------------------------
    #
    method test-severity (  ) {
      return unless ?$e;

      die $e if $e.severity >= $severity-throw-level;
    }
  }
}

#-------------------------------------------------------------------------------
#
class X::MongoDB is Exception {
  has Str $.error-text;         # Error text and error code are data mostly
  has Str $.error-code;         # originated from the mongod server
  has Str $.oper-name;          # Used operation or server request
  has Str $.oper-data;          # Operation data are items sent to the server
  has Str $.database-name;      # Database name involved
  has Str $.collection-name;    # Collection name involved
  has Str $.method;             # Method or routine name
  has Str $.line;               # Line number where X::MongoDB is created
  has Str $.file;               # File in which that happened
  has MongoDB::Severity $.severity;
                                # Severity level
  has DateTime $.date-time .= now;
                                # Date and time of creation.

  #-----------------------------------------------------------------------------
  #
  submethod BUILD (
    Str:D :$error-text,
    Str :$error-code,
    Str:D :$oper-name,
    Str :$oper-data,
    Str :$database-name,
    Str :$collection-name,
    MongoDB::Severity :$severity = MongoDB::Severity::Warn
  ) {

    for 0..Inf -> $fn {
      my $cf = callframe($fn);

      # End loop with the program that starts on line 1
      #
      last if $cf.file ~~ m/perl6/ and $cf.line == 1;

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

    $!error-text        = $error-text;
    $!error-code        = $error-code // '---';
    $!oper-name         = $oper-name;
    $!oper-data         = $oper-data;
    $!database-name     = $database-name;
    $!collection-name   = $collection-name;
    $!severity          = $severity;
  }

  #-----------------------------------------------------------------------------
  #
  method trace ( --> Str ) {
    return [~] ? $!method ?? "Method $!method" !! '',
               " at $!file\:$!line\n"
               ;
  }

  #-----------------------------------------------------------------------------
  #
  method debug ( --> Str ) {
    return [~] "\n  {$!oper-name}\() {$!error-text}\({$!error-code})",
               ? $!database-name ?? "\n  Database '$!database-name'" !! '',
               ? $!collection-name ?? "\n  Collection $!collection-name" !! '',
               " at $!file\:$!line\n"
               ;
  }

  #-----------------------------------------------------------------------------
  #
  method info ( --> Str ) {
    return [~] "\n  {$!oper-name}\() {$!error-text}\({$!error-code})",
               " at $!file\:$!line\n"
               ;
  }

  #-----------------------------------------------------------------------------
  #
  method warn ( --> Str ) {
    return [~] "\n  {$!oper-name}\() {$!error-text}\({$!error-code})",
               ? $!database-name ?? "\n  Database '$!database-name'" !! '',
               ? $!collection-name ?? "\n  Collection $!collection-name" !! '',
               ? $!method ?? "\n  In method $!method" !! '',
               " at $!file\:$!line\n"
               ;
  }

  #-----------------------------------------------------------------------------
  #
  method error ( --> Str ) {
    return self.message;
  }

  #-----------------------------------------------------------------------------
  #
  method fatal ( --> Str ) {
    return self.message;
  }

  #-----------------------------------------------------------------------------
  #
  method message ( --> Str ) {
    return [~] "\n  $!oper-name\(): $!error-text\($!error-code)",
               ? $!oper-data ?? "\n  Request data $!oper-data" !! '',
               ? $!database-name ?? "\n  Database '$!database-name'" !! '',
               ? $!collection-name ?? "\n  Collection $!collection-name" !! '',
               ? $!method ?? "\n  In method $!method" !! '',
               " at $!file\:$!line\n"
               ;
  }
}

