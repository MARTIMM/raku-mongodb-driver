use MongoDB::Wire;

role MongoDB::Protocol {

    our $wp = MongoDB::Wire.new;

    method ^wire { return $wp };
};
