use v6;

#-------------------------------------------------------------------------------
#
package MongoDB:ver<0.26.6> {

  #-----------------------------------------------------------------------------
  # Definition of all severity types
  #
  enum Severity <Trace Debug Info Warn Error Fatal>;

  # Must keep the following variables here because it must be possible to set
  # these before creating the exception.
  #
  our $severity-throw-level = Fatal;
  our $severity-process-level = Info;

  our $do-log = True;
  our $do-check = True;

  our $log-fh;
  our $log-fn = 'MongoDB.log';

  #-----------------------------------------------------------------------------
  # Exceptions only thrown at Error or Fatal
  #
  sub set-exception-throw-level (
    Severity:D $s where Error <= $s <= Fatal
  ) is export {
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
  # A role to be used to handle exceptions.
  #
  role Logging {

    #---------------------------------------------------------------------------
    #
    method mlog ( ) {
      return unless $do-log and self.severity >= $severity-process-level;
      # Check if file is open.
      open-logfile() unless ? $log-fh;

      # Define log text. If severity > Info insert empty line
      #
      my Str $etxt;
#      $etxt ~= "\n" if $.severity > Info;
      my Str $dt-str = $.date-time.utc.Str;
      $dt-str ~~ s/\.\d+Z$//;
      $dt-str ~~ s/T/ /;
      $etxt ~= [~] $dt-str,
                   " [{uc self.severity}]",
                   self."{lc(self.severity)}"(),
                   "\n";
      $log-fh.print($etxt);
    }

    #---------------------------------------------------------------------------
    #
    method test-severity (  ) {
      return self unless $do-check and self.severity >= $severity-throw-level;

      die self;
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
  class Message is Exception does MongoDB::Logging {
    has Str $.message;         # Error text and error code are data mostly
    has Str $.code;         # originated from the mongod server
    has Str $.oper-name;          # Used operation or server request
    has Str $.oper-data;          # Operation data are items sent to the server
    has Str $.collection-ns;      # Collection name space == dbname.clname
    has Str $.method;             # Method or routine name
    has Int $.line;               # Line number where Message is called
    has Str $.file;               # File in which that happened

    has MongoDB::Severity $.severity;   # Severity level
    has DateTime $.date-time;           # Date and time of creation.

    state Semaphore $control-logging .= new(1);

    #-----------------------------------------------------------------------------
    #
    method log (
      Str:D :$message,
      :$code where $_ ~~ any(Int|Str) = '',
      Str :$oper-name = '',
      Str :$oper-data = '',
      Str :$collection-ns = '',
      MongoDB::Severity :$severity = MongoDB::Severity::Warn,
    ) {

      $control-logging.acquire;

      my CallFrame $cf = self!search-callframe(Method);
      $cf = self!search-callframe(Submethod) unless $cf.defined;
      $cf = self!search-callframe(Sub) unless $cf.defined;
      $cf = self!search-callframe(Block) unless $cf.defined;
      $!line = $cf.line.Int // 1;
      $!file = $cf.file // '';
      $!file ~~ s/$*CWD/\./;
      $!method = $cf.code.name // '';

      $!message        = $message;
      $!code        = ~$code;
      $!oper-data         = $oper-data;
      $!collection-ns     = $collection-ns;

      $!severity          = $severity;
      $!date-time         .= now;

      self.mlog;
      $control-logging.release;

      self.test-severity;
      return self.clone;
    }

    #-----------------------------------------------------------------------------
    #
    method !search-callframe ( $type --> CallFrame ) {

      # Skip callframes for
      # 0  search-callframe(method)
      # 1  log(method)
      # 2  *-message(sub) helper functions
      #    Can be bypassed by using $MongoDB::logger.log() directly.
      #
      my $fn = 3;
      while my CallFrame $cf = callframe($fn++) {

        # End loop with the program that starts on line 1
        #
        if $cf.line == 1 and $cf.code ~~ Mu {
          $cf = Nil;
          last;
        }

say "cf $fn: ", $cf.line, ', ', $cf.code.WHAT, ', ', $cf.code.^name;
        last if $cf.code ~~ $type;
      }

      return $cf;
    }

    #-----------------------------------------------------------------------------
    #
    method trace ( --> Str ) {
      return [~] " $!message",
                 ? $!method ?? " In method $!method" !! '',
#                 " at $!file\:$!line",
                 ;
    }

    #-----------------------------------------------------------------------------
    #
    method debug ( --> Str ) {
      return [~] " $!message",
                 ? $!code ?? " \({$!code})" !! '',
                 ? $!collection-ns ?? "c-ns=$!collection-ns" !! '',
                 ? $!method ?? " In method $!method" !! '',
#                 " at $!file\:$!line"
                 ;
    }

    #-----------------------------------------------------------------------------
    #
    method info ( --> Str ) {
      return [~] " $!message",
                 ? $!code ?? " \({$!code})" !! '',
                 ? $!collection-ns ?? " Collection namespace $!collection-ns." !! '',
                 ? $!method ?? " In method $!method" !! '',
                 " at $!file\:$!line"
                 ;
    }

    #-----------------------------------------------------------------------------
    #
    method warn ( --> Str ) {
      return self.message;
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
      return [~] "\n  $!message",
                 ? $!code ?? " \({$!code})" !! '',
                 ? $!oper-data ?? "\n  Request data: $!oper-data" !! '',
                 ? $!collection-ns
                   ?? "\n  Collection namespace $!collection-ns" !! '',
                 ? $!method ?? "\n  In method $!method" !! '',
                 " at $!file\:$!line"
                 ;
    }
  }

#TODO Make a singleton exception processor
#TODO Make a singleton logger

  # Declare a message object to be used anywhere
  #
  our $logger = MongoDB::Message.new unless $logger.defined;

  sub combine-args ( $c, $s) {
    my %args = $c.kv;
    if $c.elems and $c<message>:!exists {
      my Str $msg = $c[0] // '';
      %args<message> = $msg;
    }
    %args<severity> = $s;
    return %args;
  }

  sub trace-message ( |c ) is export {
    $logger.log(|combine-args( c, Severity::Trace));
  }

  sub debug-message ( |c ) is export {
    $logger.log(|combine-args( c, Severity::Debug));
  }

  sub info-message ( |c ) is export {
    $logger.log(|combine-args( c, Severity::Info));
  }

  sub warn-message ( |c ) is export {
    $logger.log(|combine-args( c, Severity::Warn));
  }

  sub error-message ( |c ) is export {
    $logger.log(|combine-args( c, Severity::Error));
  }

  sub fatal-message ( |c ) is export {
    $logger.log(|combine-args( c, Severity::Fatal));
  }
}

