use MongoDB::Wire;

role MongoDB::Protocol {

    state MongoDB::Wire $wp = MongoDB::Wire.new;

    method ^wire ( --> MongoDB::Wire ) { return $wp };
};
