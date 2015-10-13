use v6;
use MongoDB::Wire;

package MongoDB {
  role Protocol {

    state MongoDB::Wire $wp = MongoDB::Wire.new;

    method wire ( --> MongoDB::Wire ) { return $wp };
  }
}
