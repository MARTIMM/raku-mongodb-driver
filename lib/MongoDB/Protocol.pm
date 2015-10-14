use v6;
use MongoDB::Wire;

package MongoDB {
  role Protocol {

    state MongoDB::Wire:D $wp = MongoDB::Wire.new;
    has MongoDB::Wire:D $.wire = $wp;

#    method wire ( --> MongoDB::Wire ) { return $wp };
  }
}
