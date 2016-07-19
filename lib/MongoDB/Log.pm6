use v6.c;

package MongoDB {

#TODO Make a singleton exception processor

  #-----------------------------------------------------------------------------
  # Definition of all severity types
  #
  enum Severity <Trace Debug Info Warn Error Fatal>;

  # Must keep the following variables here because it must be possible to set
  # these before creating the exception.
  #
  our $severity-process-level = Info;

  our $do-log = True;
  our $do-check = True;

  our $log-fh;
  our $log-fn = 'MongoDB.log';

  #-----------------------------------------------------------------------------
  # Logging always for Errors and Fatal
  #
  sub set-exception-process-level (
    Severity:D $s where Trace <= $s <= Warn
  ) is export {
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

#note "Mlog: {self.severity} >= $severity-process-level: ",
#    self.severity >= $severity-process-level;

      return unless ($do-log and (self.severity >= $severity-process-level));
#note "log message: {self.message}";

      # Check if file is open.
      #
      open-logfile() unless ? $log-fh;

      # Define log text. If severity > Info insert empty line
      #
      my Str $dt-str = $.date-time.utc.Str;
      $dt-str ~~ s/\.\d+Z$//;
      $dt-str ~~ s/T/ /;
      my Str $etxt ~= [~] $*THREAD.id().fmt('%2d '), $dt-str,
                   " [{(uc self.severity).substr(0,1)}] ",
                   self."{lc(self.severity)}"(),
                   "\n";
      $log-fh.print($etxt);
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
    has Str $.message;            # Error text and error code are data mostly
    has Str $.code;               # originated from the mongod server
    has Str $.oper-data;          # Operation data are items sent to the server
    has Str $.collection-ns;      # Collection name space == dbname.clname
    has Str $.method;             # Method or routine name
    has Int $.line;               # Line number where Message is called
    has Str $.file;               # File in which that happened

    has MongoDB::Severity $.severity;   # Severity level
    has DateTime $.date-time;           # Date and time of creation.

    has Semaphore $control-logging;

    #-----------------------------------------------------------------------------
    #
    submethod BUILD ( ) {
      $control-logging .= new(1);
    }

    #-----------------------------------------------------------------------------
    #
    method log (
      Str:D :$message,
      :$code where $_ ~~ any(Int|Str) = '',
      Str :$oper-data = '',
      Str :$collection-ns = '',
      MongoDB::Severity :$severity = MongoDB::Severity::Warn,
    ) {
#say 'l 0';
      return
        unless ($do-log and ($severity >= $severity-process-level));


#say "l 1: {callframe(3).line} {callframe(3).file}";
      $control-logging.acquire;
#say "l 2";
#say "Severity $severity, $message";
      my CallFrame $cf = self!search-callframe(Method);
      $cf = self!search-callframe(Submethod) unless $cf.defined;
      $cf = self!search-callframe(Sub) unless $cf.defined;
      $cf = self!search-callframe(Block) unless $cf.defined;

      if $cf.defined {
        $!line = $cf.line.Int // 1;
        $!file = $cf.file // '';
        $!file ~~ s/$*CWD/\./;
        $!method = $cf.code.name // '';
      }

      else {
        $!line = 0;
        $!file = $!method = '';
      }

      $!message           = $message;
      $!code              = ~$code;
      $!oper-data         = $oper-data;
      $!collection-ns     = $collection-ns;

      $!severity          = $severity;
      $!date-time         .= now;

      self.mlog;

      # Must release the lock here because after a catched message the software
      # can again call log(). We clone this object so that a waiting thread is not
      # messing up the data
      #
      my $copy = self.clone;
#say "l 3";
      $control-logging.release;

#      return unless (
#        $do-check
#        and ($copy.severity >= MongoDB::Severity::Fatal)
#      );
#say "l 4";
      return $do-check ?? $copy !! Any;
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

        # End loop with the program that starts on line 1 and code object is
        # a hollow shell.
        #
        if ?$cf and $cf.line == 1  and $cf.code ~~ Mu {
          $cf = Nil;
          last;
        }

        # Cannot pass sub THREAD-ENTRY either
        #
        if ?$cf and $cf.code.^can('name') and $cf.code.name eq 'THREAD-ENTRY' {
          $cf = Nil;
          last;
        }

#say "cf $fn: ", $cf.line, ', ', $cf.code.WHAT, ', ', $cf.code.^name,
#', ', ($cf.code.^can('name') ?? $cf.code.name !! '-');

        # Try to find a better place instead of dispatch, BUILDALL etc:...
        #
        next if $cf.code ~~ $type
            and $cf.code.name ~~ m/dispatch/;
#            and $cf.code.name ~~ m/dispatch|BUILDALL|bless/;

        last if $cf.code ~~ $type;
      }

      return $cf;
    }

    #-----------------------------------------------------------------------------
    #
    method dump-callframes ( ) {

      my $fn = 1;
      while my CallFrame $cf = callframe($fn++) {

        # End loop with the program that starts on line 1 and code object is
        # a hollow shell.
        #
        if ?$cf and $cf.line == 1  and $cf.code ~~ Mu {
          last;
        }

        # Cannot pass sub THREAD-ENTRY either
        #
        if ?$cf and $cf.code.^can('name') and $cf.code.name eq 'THREAD-ENTRY' {
          last;
        }

        say $fn.fmt('%02d'), ': ' , $cf.line, ', ', $cf.code.WHAT,
            ', ', $cf.code.^name,
            ', ', ($cf.code.^can('name') ?? $cf.code.name !! '-');
      }
    }

    #-----------------------------------------------------------------------------
    #
    method trace ( --> Str ) {
      $!message;
#      [~] " $!message ", "[{$!method // ''}:$!line]";
    }

    #-----------------------------------------------------------------------------
    #
    method debug ( --> Str ) {
      $!message
#      return [~] " $!message ", "[{$!method // ''}:$!line]"
#                 ? $!code ?? " \({$!code})" !! '',
#                 ? $!collection-ns ?? "c-ns=$!collection-ns" !! '',
#                 ? $!method ?? " From method $!method" !! '',
#                 " at $!file\:$!line"
                 ;
    }

    #-----------------------------------------------------------------------------
    #
    method info ( --> Str ) {
      $!message
#      return [~] "$!message ", "[{$!method // ''}:$!line]"
#                 ? $!code ?? " \({$!code})" !! '',
#                 ? $!collection-ns ?? " Collection namespace $!collection-ns." !! '',
#                 ? $!method ?? " From method $!method" !! '',
#                 " at $!file\:$!line"
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
      return [~] "\n  $!message.",
                 ? $!code ?? " \({$!code})" !! '',
                 ? $!oper-data ?? "\n  Request data: $!oper-data" !! '',
                 ? $!collection-ns
                   ?? "\n  Collection namespace $!collection-ns" !! '',
                 ? $!method ?? "\n  From method $!method" !! '',
                 " at $!file\:$!line"
                 ;
    }
  }



  # Declare a message object to be used anywhere
  #
  state MongoDB::Message $logger .= new;

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
    $logger.log(|combine-args( c, MongoDB::Severity::Trace));
  }

  sub debug-message ( |c ) is export {
    $logger.log(|combine-args( c, MongoDB::Severity::Debug));
  }

  sub info-message ( |c ) is export {
    $logger.log(|combine-args( c, MongoDB::Severity::Info));
  }

  sub warn-message ( |c ) is export {
    $logger.log(|combine-args( c, MongoDB::Severity::Warn));
  }

  sub error-message ( |c ) is export {
    $logger.log(|combine-args( c, MongoDB::Severity::Error));
  }

  sub fatal-message ( |c ) is export {
    my $mobj = $logger.log(|combine-args( c, MongoDB::Severity::Fatal));
    die $mobj if $mobj.defined;
  }

#  class Log {
#
#
#  }
}
