use v6;
use MongoDB::Collection;

package MongoDB {

  class CommandCll is MongoDB::Collection {

    #---------------------------------------------------------------------------
    method BUILD ( :$database! ) {

      self._set-name('$cmd');
    }
  }
}
