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
constant C-EMPTYQUERY           = -3;
constant C-EMPTYPROJECTION      = -4;

# document failure types
subset DocFail of Int where 0 <= $_ <= 3;
constant C-DOCUMENT-RECORDFAIL          = 0;
constant C-DOCUMENT-QUERYFAIL           = 1;
constant C-DOCUMENT-CRITERIAFAIL        = 2;
constant C-DOCUMENT-PROJECTIONFAIL      = 3;

#-----------------------------------------------------------------------------
role HL::CollectionRole {

  # Schema is a document to describe a table. Its keys are the fields in the table
  # The value of a field is an Array or BSON::Document. When an Array, it holds
  # the following info
  # - Mandatory field if True(Bool)
  # - Type of field,
  # -
  # When BSON::Document is used, it means the structure is nested and is always
  # mandatory.
  #
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
  has BSON::Document $!schema;

  # Records to read in data or write to database, Initialize to one empty record
  has Int $!current-record = 0;
  has Array $!records = [BSON::Document.new];
  has Array $!failed-fields;

  # Query holder for other operations
  has Int $!current-query = 0;
  has Array $!queries = [BSON::Document.new];
  has Array $!failed-query-fields;

  has Array $!failed-projection-fields;

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

    $!current-record = 0;
    $!records = [BSON::Document.new];
    $!failed-fields[0] = [ '-', C-EMPTYRECORD,];

    $!current-query = 0;
    $!queries = [BSON::Document.new];
    $!failed-query-fields[0] = [ '-', C-EMPTYQUERY,];

    $!failed-projection-fields[0] = [ '-', C-EMPTYPROJECTION,];

    $!append-unknown-fields = False;
    $!check-collection = False;
  }

  #-----------------------------------------------------------------------------
  method set-next( *%fields --> Int ) {

    # check done at reset(), set() and BUILD
    return $!failed-fields.elems if $!failed-fields.elems;
    if $!records[$!current-record].elems == 0 {
      $!failed-fields[0] = [ '-', C-EMPTYRECORD,];
      return 1;
    }

    $!current-record++;
    $!records[$!current-record] = BSON::Document.new;
    self.set(|%fields);
  }

  #-----------------------------------------------------------------------------
  method set ( *%fields --> Int ) {

    # Define the record in the same order as noted in schema
    my BSON::Document $record := $!records[$!current-record];
    for $!schema.keys -> $field-name {
      if %fields{$field-name}:exists {
        $record{$field-name} = %fields{$field-name};
      }
    }

    # Add the rest of the fields not found in schema. These fail later
    # depending on option $!append-unknown-fields.
    for %fields.keys -> $field-name {
      if $!schema{$field-name}:!exists {
        $record{$field-name} = %fields{$field-name};
      }
    }

    $!failed-fields = [];
    if $record.elems {
      self!check-record( $!schema, $record, :type(C-DOCUMENT-RECORDFAIL));
    }

    else {
      $!failed-fields[0] = [ '-', C-EMPTYRECORD,];
    }

    $!failed-fields.elems;
  }

  #-----------------------------------------------------------------------------
  method query-set-next( *%fields --> Int ) {

    # check done at reset(), set() and BUILD
    return $!failed-query-fields.elems if $!failed-query-fields.elems;
    if $!queries[$!current-query].elems == 0 {
      $!failed-query-fields[0] = [ '-', C-EMPTYQUERY,];
      return 1;
    }

    $!current-query++;
    $!queries[$!current-query] = BSON::Document.new;
    self.query-set(|%fields);
  }

  #-----------------------------------------------------------------------------
  method query-set ( *%fields --> Int ) {

    # Define the record in the same order as noted in schema
    my BSON::Document $query := $!queries[$!current-query];
    for $!schema.keys -> $field-name {
      if %fields{$field-name}:exists {
        $query{$field-name} = %fields{$field-name};
      }
    }

    # Add the rest of the fields not found in schema. These fail later
    # depending on option $!append-unknown-fields.
    for %fields.keys -> $field-name {
      if $!schema{$field-name}:!exists {
        $query{$field-name} = %fields{$field-name};
      }
    }

    $!failed-query-fields = [];
    if $query.elems {
      self!check-record( $!schema, $query, :type(C-DOCUMENT-QUERYFAIL));
    }

    else {
      $!failed-query-fields[0] = [ '-', C-EMPTYQUERY,];
    }

    $!failed-query-fields.elems;
  }

  #-----------------------------------------------------------------------------
  method record-count ( --> Int ) {

    $!records.elems;
  }

  #-----------------------------------------------------------------------------
  method query-count ( --> Int ) {

    $!queries.elems;
  }

  #-----------------------------------------------------------------------------
  method read (
    BSON::Document :$criteria = BSON::Document.new,
    BSON::Document :$projection,
    Int :$number-to-skip, Int :$number-to-return,
#TODO    Int :$flags = 0, BSON::Document :$read-concern, :$server is copy

    --> BSON::Document
  ) {

    my %args = %();

    $!failed-projection-fields = [];
    if $criteria.elems {
      self!check-record( $!schema, $criteria, :type(C-DOCUMENT-PROJECTIONFAIL));
      return self!document-failures(:type(C-DOCUMENT-CRITERIAFAIL))
        if $!failed-projection-fields.elems;

      %args<criteria> = $criteria;
    }

    $!failed-projection-fields = [];
    if $projection.elems {
      self!check-record( $!schema, $projection, :type(C-DOCUMENT-PROJECTIONFAIL));
      return self!document-failures(:type(C-DOCUMENT-PROJECTIONFAIL))
        if $!failed-projection-fields.elems;

      %args<projection> = $projection;
    }

    %args<number-to-skip> = $number-to-skip if $number-to-skip;
    %args<number-to-return> = $number-to-return if $number-to-return;

    $!cursor = $!cl.find(%args);
    $!cursor.fetch;
  }

  #-----------------------------------------------------------------------------
  method read-next ( --> BSON::Document ) {

    $!cursor.fetch;
  }

  #-----------------------------------------------------------------------------
  method insert ( --> BSON::Document ) {

    my BSON::Document $doc;

    # Check if there are leftover errors from previous set() calls
    if $!failed-fields.elems {
      $doc = self!document-failures(:type(C-DOCUMENT-RECORDFAIL));
    }

    else {
      $doc = $!db.run-command(
        BSON::Document.new: (
          insert => $!cl.name,
          documents => [
            @$!records
          ]
        )
      );
    }

    # clear all data and set defaults
    self.reset;

    $doc;
  }

  #-----------------------------------------------------------------------------
  method update ( --> BSON::Document ) {

  }

  #-----------------------------------------------------------------------------
  method delete (
    Bool :$ordered = True,
    Bool :$limit = True
    --> BSON::Document
  ) {

    my BSON::Document $doc;

    # Check if there are leftover errors from previous set-query() calls
    if $!failed-query-fields.elems {
      $doc = self!document-failures(:type(C-DOCUMENT-QUERYFAIL));
    }

    else {
      my BSON::Document $req .= new: (
        delete => $!cl.name,
        deletes => [
          map {
            BSON::Document.new((
              q => $_,
              limit => $limit ?? 1 !! 0;
            ))
          }, @$!queries
        ],
        ordered => $ordered,
#TODO writeconcern
      );

say "Req: $req.perl()";
      $doc = $!db.run-command($req);
    }

    # clear all data and set defaults
    self.reset;

    $doc;
  }

  #-----------------------------------------------------------------------------
  # Records for writing must be checked for
  # - missing mandatory fields
  # - extra fields
  # - wrong typed fields
  # Query checks are the same as record checks except for missing fields
  # Criteria for reading tests as queries
  # Projections are checked extra fields only and must be boolean
  #
  method !check-record (
    BSON::Document:D $schema,
    BSON::Document:D $record,
    DocFail :$type = C-DOCUMENT-RECORDFAIL
  ) {

    # Variable is bound to real location to take care for recursive loops
    my @failed-fields;
    if $type ~~ C-DOCUMENT-RECORDFAIL {
      @failed-fields := @$!failed-fields;
    }

    elsif $type ~~ C-DOCUMENT-QUERYFAIL {
      @failed-fields := @$!failed-query-fields;
    }

    elsif $type ~~ C-DOCUMENT-CRITERIAFAIL {
      @failed-fields := @$!failed-query-fields;
    }

    elsif $type ~~ C-DOCUMENT-PROJECTIONFAIL {
      @failed-fields := @$!failed-projection-fields;
    }

    # Check all names from schema
    for $!schema.keys -> $field-name {

      # Check if used in record
      if $record{$field-name}:exists {

        next if $type ~~ C-DOCUMENT-CRITERIAFAIL;

        # See if this ia projection data. If so the values must be boolean
        if $type ~~ C-DOCUMENT-PROJECTIONFAIL {
          if $record{$field-name} !~~ Bool {
            @failed-fields.push: [
              $field-name,                      # failed fieldname
              C-TYPE,                           # failed on type
              $record{$field-name}.WHAT,        # has type
              Bool                              # should be of type Bool
            ];
          }
        }

        # Check type of field value with type in schema
        elsif $record{$field-name} !~~ $!schema{$field-name}[C-TYPE] {
          @failed-fields.push: [
            $field-name,                        # failed fieldname
            C-TYPE,                             # failed on type
            $record{$field-name}.WHAT,          # has type
            $!schema{$field-name}[C-TYPE]       # should be type
          ];
        }

        # Check if nested, if so, do recursive call
        if $record{$field-name} ~~ BSON::Document {
          self!check-record( $!schema{$field-name}, $record{$field-name});
        }
      }

      # If field not found in record
      else {
        # Check if field is mandatory. Only needed on record checks,
        # not for queries, criteria or projections
        #
        if $type ~~ C-DOCUMENT-RECORDFAIL {
          if $!schema{$field-name}[C-MANDATORY] {
            @failed-fields.push: [
              $field-name,                      # failed fieldname
              C-MANDATORY,                      # field is missing
            ];
          }
        }
      }
    }

    # Test for extra fields. Check option $!append-unknown-fields which is
    # False by default.
    unless $!append-unknown-fields {

      # Check for all fields in record
      for $record.keys -> $field-name {

        # Check if field is described in schema, but ignore '_id'. This field is
        # generated always and can be used in insertions,projections and
        # criteria.
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
  method !check-schema ( BSON::Document:D $schema --> Bool ) {

#check on field usage
#check if records in database still conform to schema
  }

  #-----------------------------------------------------------------------------
  method !document-failures ( DocFail :$type --> BSON::Document ) {

    my BSON::Document $error-doc .= new;
    $error-doc<ok> = 0;

    my @failed-fields;
    if $type ~~ C-DOCUMENT-RECORDFAIL {
      @failed-fields := @$!failed-fields;
      $error-doc<reason> = 'Failing record fields';
    }

    elsif $type ~~ C-DOCUMENT-QUERYFAIL {
      @failed-fields := @$!failed-query-fields;
      $error-doc<reason> = 'Failing query fields';
    }

    elsif $type ~~ C-DOCUMENT-CRITERIAFAIL {
      @failed-fields := @$!failed-projection-fields;
      $error-doc<reason> = 'Failing criteria fields';
    }

    elsif $type ~~ C-DOCUMENT-PROJECTIONFAIL {
      @failed-fields := @$!failed-projection-fields;
      $error-doc<reason> = 'Failing projection fields';
    }

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

      elsif $field-spec[1] ~~ C-EMPTYQUERY {
        $error-doc<fields>{$field-spec[0]} = 'current query/criteria is empty';
      }

      elsif $field-spec[1] ~~ C-EMPTYPROJECTION {
        $error-doc<fields>{$field-spec[0]} = 'current projection is empty';
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

    $!schema = $schema;
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
