use v6.c;

use BSON::Document;

use MongoDB;
use MongoDB::Client;
use MongoDB::Database;
use MongoDB::Collection;
use MongoDB::Cursor;

#-------------------------------------------------------------------------------
unit package MongoDB;


# Array index and error codes
constant C-MANDATORY            = 0;
constant C-TYPE                 = 1;

# error code, other than above -> negative
constant C-NOTINSCHEMA          = -1;
constant C-EMPTYRECORD          = -2;

#-----------------------------------------------------------------------------
role HL::CollectionRole {

  # Schema is a document to describe a table. Its keys are the fields in the
  # table. The value of a field is an Array or BSON::Document. When an Array,
  # it holds the following info
  # - Mandatory field
  # - Type of field,
  #TODO - Default value. Useful when not mandatory.
  #
  # When BSON::Document is used, it means the structure is nested.
  #
  # E.g.
  # BSON::Document.new: (
  #   contact => BSON::Document.new((
  #     name => [ True, Str],
  #     surname => [True, Str]
  #   )),
  #   address => BSON::Document.new((
  #     street => [ True, Str],
  #     number => [ False, Int],
  #   ))
  # )
  #
  #TODO mongo document validation
  # Version 3.2 of mongo server offers document validation which is quite good
  # So in 3.2 when a schema is offered it should be translated into a validation
  # doc and set on the collection.
  #
  has BSON::Document $!schema;

  # Records to read in data or write to database, Initialize to one empty record
  has Array $!failed-fields;

  has MongoDB::Cursor $!cursor;

  # Can add unknown fields when True
  has Bool $.append-unknown-fields is rw = False;

  # Do collection check when schema check
  has Bool $.check-collection is rw = False;

  # Server data
  has MongoDB::Client $!client;
  has MongoDB::Database $!db;
  has MongoDB::Collection $!cl;

  #-----------------------------------------------------------------------------
  method reset ( ) {

    $!failed-fields[0] = [ '-', C-EMPTYRECORD,];

    $!append-unknown-fields = False;
    $!check-collection = False;
  }

  #-----------------------------------------------------------------------------
  method count ( Hash :$criteria --> BSON::Document ) {

    my $query = BSON::Document.new;
    if $criteria.keys {
      self!copy-fields( $!schema, $criteria, $query);
    }

    my BSON::Document $req .= new: ( :count($!cl.name), :$query);
    $!db.run-command($req);
  }

  #-----------------------------------------------------------------------------
  method read (
    Hash :$criteria, Hash :$projection,
    Int :$number-to-skip, Int :$number-to-return,
#TODO    Int :$flags = 0, BSON::Document :$read-concern, :$server is copy

    --> BSON::Document
  ) {

    my Hash $args = %();

    if $criteria.keys {
      $args<criteria> = BSON::Document.new;
      self!copy-fields( $!schema, $criteria, $args<criteria>);
    }

    if $projection.keys {
      $args<projection> = BSON::Document.new;
      self!copy-fields( $!schema, $projection, $args<projection>);
    }

    $args<number-to-skip> = $number-to-skip if $number-to-skip;
    $args<number-to-return> = $number-to-return if $number-to-return;

    # clear all data and set defaults
    self.reset;

    $!cursor = $!cl.find(|$args);

    $!cursor.fetch;
  }

  #-----------------------------------------------------------------------------
  method read-next ( --> BSON::Document ) {

    $!cursor.fetch;
  }

  #-----------------------------------------------------------------------------
  method insert ( 
    Array:D :$inserts

    --> BSON::Document
  ) {

    my Array $mod-inserts = [];
    for @$inserts {
      my Hash $ins = %$_;
      
      my BSON::Document $record .= new;

      if $ins.defined {
        self!copy-fields( $!schema, $ins, $record);

        $!failed-fields = [];
        if $record.elems {
          self!check-record( $!schema, $record);
        }

        else {
          $!failed-fields[0] = [ '-', C-EMPTYRECORD,];
        }

        if $!failed-fields.elems {
          my BSON::Document $doc = self!document-failures;
          self.reset;
          return $doc;
        }

        $mod-inserts.push: $record;
      }

      else {
        fatal-message("No insert specification found");
      }
    }

    my BSON::Document $doc = $!db.run-command(
      BSON::Document.new: (
        insert => $!cl.name,
        documents => $mod-inserts,
#TODO writeconcern
      )
    );

    # clear all data and set defaults
    self.reset;

    $doc;
  }

  #-----------------------------------------------------------------------------
  # updates is [ {
  #   q: <query>,
  #   u: <update>,
  #   upsert: <boolean>,
  #   multi: <boolean>
  # }, ... ]
  #
  method update (
    Array:D :$updates,
    Bool :$ordered = True,

    --> BSON::Document
  ) {

    my Array $mod-updates = [];
    for @$updates {
      my Hash $us = %$_;

      my BSON::Document $query-spec .= new;
#      my BSON::Document $query .= new;

      if $us<q>:exists and $us<q>.defined {
        $query-spec<q> = $us<q>;
      }

      else {
        fatal-message("No q-field found in update specification entry");
      }


      if $us<u>:exists and $us<u>.defined {
        $query-spec<u> = $us<u>;
      }
      
      else {
        fatal-message("No update specification found");
      }

      if $us<upsert>:exists and $us<upsert>.defined {
        $query-spec<upsert> = $us<upsert>;
      }

      if $us<multi>:exists and $us<multi>.defined {
        $query-spec<multi> = $us<multi>;
      }

      $mod-updates.push: $query-spec;
    }

    my $req = BSON::Document.new: (
      update => $!cl.name,
      updates => $mod-updates,
      :$ordered,
#TODO writeconcern
#TODO bypass validation
    );

    my BSON::Document $doc = $!db.run-command($req);
  }

  #-----------------------------------------------------------------------------
  # replaces is [ {
  #   q: <query>,
  #   r: <fields-values expressions>,
  #   upsert: <boolean>,
  #   multi: False
  # }, ... ]
  #
  method replace (
    Array:D :$replaces,
    Bool :$ordered = True,

    --> BSON::Document
  ) {

    my Array $mod-replace = [];
    for @$replaces {
      my Hash $rs = %$_;

      my BSON::Document $query-spec .= new;
      my BSON::Document $query .= new;
      my BSON::Document $replce .= new;

      if $rs<q>:exists and $rs<q>.defined {
        $query-spec<q> = $rs<q>;
      }

      else {
        fatal-message("No q-field found in update specification entry");
      }

      if $rs<r>:exists and $rs<r>.defined {
        self!copy-fields( $!schema, $rs<r>, $replce);

        $!failed-fields = [];
        if $replce.elems {
          self!check-record( $!schema, $replce);
        }

        else {
          $!failed-fields[0] = [ '-', C-EMPTYRECORD,];
        }

        if $!failed-fields.elems {
          my BSON::Document $doc = self!document-failures;
          self.reset;
          return $doc;
        }

        $query-spec<u> = $replce;
      }

      else {
        fatal-message("No replace specification found");
      }

      if $rs<upsert>:exists and $rs<upsert>.defined {
        $query-spec<upsert> = $rs<upsert>;
      }

      $mod-replace.push: $query-spec;
    }

    my BSON::Document $doc = $!db.run-command(
      BSON::Document.new: (
        update => $!cl.name,
        updates => $mod-replace,
        :$ordered,
#TODO writeconcern
#TODO bypass validation
      )
    );

    # clear all data and set defaults
    self.reset;
    
    $doc;
  }

  #-----------------------------------------------------------------------------
  # deletes is [ { q : <query>, limit : <integer> }, ...]
  method delete ( Array:D :$deletes, Bool :$ordered = True --> BSON::Document ) {

    my Array $mod-deletes = [];
    for @$deletes {
      my Hash $ds = %$_;
#say $ds.perl;
      my BSON::Document $query-spec .= new;
      my BSON::Document $query .= new;

      if $ds<q>:exists and $ds<q>.defined {
        self!copy-fields( $!schema, $ds<q>, $query);
        $query-spec<q> = $query;
      }

      else {
        fatal-message("No q-field found in delete specification entry");
      }


      if $ds<limit>:exists and $ds<limit>.defined {
        $query-spec<limit> = $ds<limit> ?? 1 !! 0;
      }

      else {
        $query-spec<limit> = 1;
      }

      $mod-deletes.push: $query-spec;
    }

    my BSON::Document $req .= new: (
      delete => $!cl.name,
      deletes => $mod-deletes,
      ordered => $ordered,
#TODO writeconcern
    );
#say $req.perl;

    my BSON::Document $doc = $!db.run-command($req);

    # clear all data and set defaults
    self.reset;

    $doc;
  }

  #-----------------------------------------------------------------------------
  method !copy-fields (
    BSON::Document:D $schema,
    $fields where $_ ~~ any(Hash|Pair),
    BSON::Document:D $record,
  ) {

    # Check all names from schema
    for $!schema.keys -> $field-name {

      # Check if used in record
      if $fields{$field-name}:exists {

        # Check if it is a nested structure
        if $!schema{$field-name} ~~ BSON::Document
           and $fields{$field-name} ~~ Hash {

          $record{$field-name} = BSON::Documen.new;
          self!copy-fields(
            $!schema{$field-name},
            $record{$field-name},
            $fields{$field-name}
          );
        }

        else {

          $record{$field-name} = $fields{$field-name};
        }
      }
    }

    # Test for extra fields. Check option $!append-unknown-fields which is
    # False by default.
    unless $!append-unknown-fields {

      for $record.keys -> $field-name {

        if $schema{$field-name}:!exists {
          $record{$field-name} = $fields{$field-name};
        }
      }
    }
  }

  #-----------------------------------------------------------------------------
  # Records for writing must be checked for
  # - missing mandatory fields
  # - extra fields
  # - wrong typed fields
  #
  method !check-record (
    BSON::Document:D $schema,
    BSON::Document:D $record,
  ) {

    # Variable is bound to real location to take care for recursive loops
    my @failed-fields := @$!failed-fields;

    # Check all names from schema
    for $!schema.keys -> $field-name {

      # Check if used in record
      if $record{$field-name}:exists {

        # Check type of field value with type in schema
        if $record{$field-name} !~~ $!schema{$field-name}[C-TYPE] {
          @failed-fields.push: [
            $field-name,                        # failed fieldname
            C-TYPE,                             # failed on type
            $record{$field-name}.WHAT,          # has type
            $!schema{$field-name}[C-TYPE]       # should be type
          ];
        }

        # Check if nested, if so, do recursive call
        elsif $record{$field-name} ~~ BSON::Document {
          self!check-record( $!schema{$field-name}, $record{$field-name});
        }
      }

      # If field not found in record
      else {

        # Check if field is mandatory.
        if $!schema{$field-name}[C-MANDATORY] {
          @failed-fields.push: [
            $field-name,                        # failed fieldname
            C-MANDATORY,                        # field is missing
          ];
        }
      }
    }

    # Test for extra fields. Check option $!append-unknown-fields which is
    # False by default.
    unless $!append-unknown-fields {

      # Check for all fields in record
      for $record.keys -> $field-name {

        # Check if field is described in schema
        if $schema{$field-name}:!exists {
          @failed-fields.push: [
            $field-name,                        # failed fieldname
            C-NOTINSCHEMA,                      # field not in schema
          ];
        }
      }
    }
  }

  #-----------------------------------------------------------------------------
  method !check-schema ( BSON::Document:D $schema --> BSON::Document ) {

    my BSON::Document $mod-schema .= new;

    # insert non mandatory _id field of type Any
    $mod-schema<_id> = [ False, Any];

    # Copy all other fields
    for $schema.kv -> $k, $v {

      if $v ~~ Array and $v[0] ~~ Bool {
        $mod-schema{$k} = $v;
      }

      elsif $v ~~ BSON::Document {
        $mod-schema{$k} = $v;
      }

      else {
        fatal-message("Field $k in schema has problems: " ~ $v.perl);
      }
    }
#check on field usage
#check if records in database still conform to schema
    $mod-schema;
  }

  #-----------------------------------------------------------------------------
  method !document-failures ( --> BSON::Document ) {

    my BSON::Document $error-doc .= new;
    my @failed-fields := @$!failed-fields;

    $error-doc<ok> = 0;
    $error-doc<reason> = 'Failing record fields';
    $error-doc<fields> = BSON::Document.new;

    for @failed-fields -> $field-spec {

      if $field-spec[1] ~~ C-MANDATORY {
        $error-doc<fields>{$field-spec[0]} = 'missing';
      }

      elsif $field-spec[1] ~~ C-TYPE {
        $error-doc<fields>{$field-spec[0]} = 
          [~] 'type failure, is ', $field-spec[2].WHAT.perl, " but must be ",
          $field-spec[3].WHAT.perl;
      }

      elsif $field-spec[1] ~~ C-NOTINSCHEMA {
        $error-doc<fields>{$field-spec[0]} = 'not described in schema';
      }

      elsif $field-spec[1] ~~ C-EMPTYRECORD {
        $error-doc<fields>{$field-spec[0]} = 'current record is empty';
      }
    }

    $error-doc;
  }
}

#-------------------------------------------------------------------------------
#TODO See if class can be generated in $class below
class HL::Collection does HL::CollectionRole {

  #-----------------------------------------------------------------------------
  submethod BUILD (
    Str:D :$uri,
    Str:D :$db-name,
    Str:D :$cl-name,
    BSON::Document:D :$schema,
    Bool :$append-unknown-fields = False
  ) {

    $!client = MongoDB::Client.new(:$uri);
    $!db = $!client.database($db-name);
    $!cl = $!db.collection($cl-name);

    $!schema = self!check-schema($schema);
    $!append-unknown-fields = $append-unknown-fields;
  }
}

sub collection-object (
  Str :$uri,
  Str:D :$db-name,
  Str:D :$cl-name,
  BSON::Document :$schema

  --> MongoDB::HL::Collection
) is export {

  state Hash $objects = {};
  my $name = "MongoDB::HL::Collection::$cl-name.tc()";

  my $object;
  if $objects{$name}:exists {
    $object = $objects{$name}.clone;
  }

  else {
    my $class := Metamodel::ClassHOW.new_type(:$name);
    $class.^add_parent( MongoDB::HL::Collection, :!hides);
    $class.^compose;
    $object = $class.new( :$uri, :$db-name, :$cl-name, :$schema);
    $objects{$name} = $object;
  }

  $object.reset;
  $object;
}
