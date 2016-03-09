use v6.c;
use MongoDB::Log :ALL;

  sub EXPORT { {
      '&set-exception-process-level'    => &set-exception-process-level,
      '&set-logfile'                    => &set-logfile
    }
  };

#-------------------------------------------------------------------------------
#
package MongoDB:ver<0.28.7> {

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
}

