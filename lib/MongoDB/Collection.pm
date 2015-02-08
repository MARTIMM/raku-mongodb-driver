use v6;
use MongoDB::Protocol;
use MongoDB::Cursor;

class MongoDB::Collection does MongoDB::Protocol;

has $.database is rw;
has Str $.name is rw;

submethod BUILD ( :$database, Str :$name ) {

    $!database = $database;

    # TODO validate name
    $!name = $name;
}

method insert ( **@documents, Bool :$continue_on_error = False --> Nil ) {

    my $flags = +$continue_on_error;

    my @docs;
    if @documents.isa(LoL) {
      if @documents[0].isa(Array) and [&&] @documents[0].list>>.isa(Hash) {
        @docs = @documents[0].list;
      }

      elsif @documents.list>>.isa(Hash) {
        @docs = @documents.list;
      }

      else {
        die "Error: Document type not handled by insert";
      }
    }

    else {
      die "Error: Document type not handled by insert";
    }

    self.wire.OP_INSERT( self, $flags, @docs );
    
    return;
}

method find (
    %criteria = { }, %projection = { },
    Int :$number_to_skip = 0, Int :$number_to_return = 0,
    Bool :$no_cursor_timeout = False
    --> MongoDB::Cursor
) {

    my $flags = +$no_cursor_timeout +< 4;
    my $OP_REPLY;
      $OP_REPLY = self.wire.OP_QUERY( self, $flags, $number_to_skip,
                                      $number_to_return, %criteria,
                                      %projection
                                    );

    return MongoDB::Cursor.new(
        collection  => self,
        OP_REPLY    => $OP_REPLY,
        :%criteria
    );
}

method find_one ( %criteria = { }, %projection = { } --> Hash ) {

    my MongoDB::Cursor $cursor = self.find( %criteria, %projection
                                          , :number_to_return(1)
                                          );
    return $cursor.fetch();
}

#-------------------------------------------------------------------------------
# Add indexes for collection
#
# Steps done by the mongo shell
#
# * Insert a document into a system table <dbname>.system.indexes
# * Run get_last_error to see result
# * Run get_last_error again, now with flag w => 1, replicas
# * Run run_command on the admin database and $cmd collection with
#   replSetGetStatus => 1 and forShell => 1
#
# * According to documentation indexes cannot be changed. They must be deleted
#   first. Therefore check first. drop index if exists then set new index.
#
method ensure_index ( %key_spec, %options = {} --> Nil ) {

    my Str $name = '';
    my Bool $idx-exists = False;

    # Check if index exists
    if %options<name>:exists {
        $name = %options<name>;
    }
    
    else {
        # If no name for the index is set then imitate the default of MongoDB
        # or keyname1_dir1_keyname2_dir2_..._keynameN_dirN.
        #
        for %key_spec.keys -> $k {
            $name ~= [~] ($name ?? '_' !! ''), $k, '_', %key_spec{$k};
        }

    }
    # ....

#say "KI: $name, $idx-exists";

    # Insert index if not exists
    if !$idx-exists {
        my $system-indexes = $!database.collection('system.indexes');
        my %doc = %( ns => self.name,
                     key => %key_spec,
                     %options.kv
                   );
#say "Insert: {%doc.perl}";
        $system-indexes.insert(%doc);
    }

}

method update (
    %selector, %update,
    Bool :$upsert = False, Bool :$multi_update = False
    --> Nil
) {

    my $flags = +$upsert
        + +$multi_update +< 1;

    self.wire.OP_UPDATE( self, $flags, %selector, %update );
    
    return;
}

method remove (
    %selector = { },
    Bool :$single_remove = False
    --> Nil
) {

    my $flags = +$single_remove;

    self.wire.OP_DELETE( self, $flags, %selector );
    
    return;
}
