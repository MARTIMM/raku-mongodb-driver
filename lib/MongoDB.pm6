use v6;

#-------------------------------------------------------------------------------
#
package MongoDB:ver<0.25.10> {

  #-----------------------------------------------------------------------------
  #
  our $version = Nil;

  enum Severity <Trace Debug Info Warn Error Fatal>;

  #-----------------------------------------------------------------------------
  # A role to be used to handle exceptions.
  #
  role Logging {

    my $severity-throw-level = Fatal;
    my $severity-process-level = Info;

    my $do-log = True;
    my $do-check = True;

    my $log-fh;
    my $log-fn = 'MongoDB.log';

    #---------------------------------------------------------------------------
    #
    method log (  ) {
#say "L: $do-log, self.severity, $severity-process-level";
      return unless $do-log and self.severity >= $severity-process-level;

      # Check if file is open.
      open-logfile() unless ? $log-fh;

      # Define log text. If severity > Info insert empty line
      #
      my Str $etxt;
      $etxt ~= "\n" if self.severity > Info;
      $etxt ~= [~] self.date-time.Str, " [{uc self.severity}]", self."{lc(self.severity)}"();
      $log-fh.print($etxt);
    }

    #---------------------------------------------------------------------------
    #
    method test-severity (  ) {
#say "S: $do-check, self.severity, $severity-throw-level";
      return unless $do-check and self.severity >= $severity-throw-level;

      die self;
    }

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
    sub set-exception-processing (
      Bool :$logging = True,
      Bool :$checking = True
    ) is export {
      $do-log = $logging;
      $do-check = $checking;
    }

    #-----------------------------------------------------------------------------
    #
    multi sub set-logfile ( Str:D $filename! ) is export {
      $log-fn = $filename;
    }

    #-----------------------------------------------------------------------------
    #
    multi sub set-logfile ( IO::Handle:D $file-handle! ) is export {
      $log-fh.close if ? $log-fh and $log-fh !eqv $*OUT and $log-fh !eqv $*ERR;
      $log-fh = $file-handle;
    }

    #-----------------------------------------------------------------------------
    #
    sub open-logfile (  ) is export {
      $log-fh.close if ? $log-fh and $log-fh !eqv $*OUT and $log-fh !eqv $*ERR;
      $log-fh = $log-fn.IO.open: :a;
    }

    #-----------------------------------------------------------------------------
    # Absolute methods. Must be defined by user of this role
    #
    method trace ( --> Str ) { ... }
    method debug ( --> Str ) { ... }
    method info ( --> Str ) { ... }
    method warn ( --> Str ) { ... }
    method error ( --> Str ) { ... }
    method fatal ( --> Str ) { ... }

    method message ( --> Str ) { ... }
  }

  #-------------------------------------------------------------------------------
  #
  class X::MongoDB is Exception does MongoDB::Logging {
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
    has DateTime $.date-time;
                                  # Date and time of creation.

    #-----------------------------------------------------------------------------
    #
    submethod BUILD (
      Str:D :$error-text,
      :$error-code where $_ ~~ any(Int|Str) = '',
      Str:D :$oper-name,
      Str :$oper-data,
      Str :$collection-ns,
      MongoDB::Severity :$severity = MongoDB::Severity::Warn,
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
      $!date-time         .= now;

      self.log( );
      self.test-severity( );
    }

    #-----------------------------------------------------------------------------
    #
    method trace ( --> Str ) {
      return [~] ? $!method ?? " Method $!method" !! '',
                 " at $!file\:$!line\n"
                 ;
    }

    #-----------------------------------------------------------------------------
    #
    method debug ( --> Str ) {
      return [~] " {$!oper-name}\() $!error-text",
                 ? $!error-code ?? " \({$!error-code})" !! '',
                 ? $!collection-ns ?? "c-ns=$!collection-ns" !! '',
                 " at $!file\:$!line\n"
                 ;
    }

    #-----------------------------------------------------------------------------
    #
    method info ( --> Str ) {
      return [~] " {$!oper-name}\() $!error-text",
                 ? $!error-code ?? " \({$!error-code})" !! '',
                 " at $!file\:$!line\n"
                 ;
    }

    #-----------------------------------------------------------------------------
    #
    method warn ( --> Str ) {
      return [~] "\n  {$!oper-name}\() $!error-text",
                 ? $!error-code ?? " \({$!error-code})" !! '',
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
      return [~] "\n  $!oper-name\(): $!error-text",
                 ? $!error-code ?? " \({$!error-code})" !! '',
                 ? $!oper-data ?? "\n  Request data $!oper-data" !! '',
                 ? $!collection-ns ?? "\n  Collection namespace $!collection-ns" !! '',
                 ? $!method ?? "\n  In method $!method" !! '',
                 " at $!file\:$!line\n"
                 ;
    }
  }
}

