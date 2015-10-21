use v6;

#-------------------------------------------------------------------------------
#
package MongoDB:ver<0.25.8> {

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
  has Str $.collection-ns;      # Collection name space == dbname.clname
  has Str $.method;             # Method or routine name
  has Int $.line;               # Line number where X::MongoDB is created
  has Str $.file;               # File in which that happened
  has MongoDB::Severity $.severity;
                                # Severity level
  has DateTime $.date-time .= now;
                                # Date and time of creation.

  #-----------------------------------------------------------------------------
  #
  submethod BUILD (
    Str:D :$error-text,
    :$error-code where $_ ~~ any(Int|Str) = '',
    Str:D :$oper-name,
    Str :$oper-data,
    Str :$collection-ns,
    MongoDB::Severity :$severity = MongoDB::Severity::Warn
  ) {

    my $fn = 0;
    while my $cf = callframe($fn++) {
#say "A F,l: {$cf.file}:{$cf.line} {$cf.code.^name} {$cf.code.name}";

      # End loop with the program that starts on line 1
      #
      last if $cf.line == 1;

      # Skip all in between modules of perl
      # THIS DEPENDS ON MOARVM OR JVM INSTALLED IN 'gen/' !!
      #
      next if $cf.file ~~ m/ ^ 'gen/' [ 'moar' || 'jvm' ] /;

      # Skip this module too
      #
      next if $cf.file ~~ m/ 'MongoDB.pm6' $ /;

      # Get info when we see a Sub, Method or Submethod. Other types are
      # skipped. This will get us to the calling function.
      #
      if $cf.code.^name ~~ m/ [ 'Sub' | 'Method' | 'Submethod' ] / {
        $!line = +$cf.line;
        $!file = $cf.file;

        # Problem is that the callframe here is not the same as the callframe
        # above because of adding new blocks (if, for, while etc) to the stack.
        # It is however extended, so look first for the entry found above and
        # then search for the method/sub/submethod below it.
        #
        # We can start at least at level $fn.
        #
        my Bool $found-entry = False;
        while my $cfx = callframe($fn++) {
#say "B F,l: [$found-entry]",
#    " {$cfx.file}:{$cfx.line} {$cfx.code.^name} {$cfx.code.name}";

          # If we find the entry then go to the next frame to check for the
          # Routine we need to know.
          #
          if $!line == $cfx.line and $!file eq $cfx.file {
            $found-entry = True;
            next;
          }

          if $found-entry
             and $cfx.code.^name ~~ m/ [ 'Sub' | 'Method' | 'Submethod' ] / {
            $!method = $cfx.code.name;
            last;
          }
        }

        # When we have our info then stop
        #
        last if ? $!method;
      }
    }

    $!error-text        = $error-text;
    $!error-code        = ~$error-code;
    $!oper-name         = $oper-name;
    $!oper-data         = $oper-data;
    $!collection-ns     = $collection-ns;
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
               ? $!collection-ns ?? "\n  Collection namespace $!collection-ns" !! '',
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
               ? $!collection-ns ?? "\n  Collection namespace $!collection-ns" !! '',
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
               ? $!collection-ns ?? "\n  Collection namespace $!collection-ns" !! '',
               ? $!method ?? "\n  In method $!method" !! '',
               " at $!file\:$!line\n"
               ;
  }
}

