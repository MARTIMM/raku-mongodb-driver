use v6.c;

use BSON::Document;

use MongoDB;
use MongoDB::Client;
use MongoDB::Database;
use MongoDB::Collection;

#-------------------------------------------------------------------------------
unit package MongoDB;


# Array index and error codes
constant C-MANDATORY          = 0;
constant C-TYPE               = 1;

# error code
constant C-NOTINSCHEMA        = -1;

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
  has Array $!records = [BSON::Document.new];

  # Current record to write(set)
  has Int $!current-record = 0;

  # Check results
  has Array $!failed-fields;

  # Can add unknown fields when True
  has Bool $.append-unknown-fields is rw = False;

  # Server data
  has MongoDB::Client $!client;
  has MongoDB::Database $!db;
  has MongoDB::Collection $!cl;

  #-----------------------------------------------------------------------------
  method reset ( ) {
    $!records = [];
    $!append-unknown-fields = False;

    $!current-record = 0;
    $!records[$!current-record] = BSON::Document.new;

    $!failed-fields = [];
    self!check-record( $!schema, $!records[$!current-record]);
  }

  #-----------------------------------------------------------------------------
  method set-next( *%fields --> Int ) {

    # check done at reset(), set() and BUILD
    return $!failed-fields.elems if $!failed-fields.elems;

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
    self!check-record( $!schema, $record);
    $!failed-fields.elems;
  }

  #-----------------------------------------------------------------------------
  method record-count ( --> Int ) {

    $!records.elems;
  }

  #-----------------------------------------------------------------------------
  method read ( --> BSON::Document ) {

  }

  #-----------------------------------------------------------------------------
  method read-next ( --> BSON::Document ) {

  }

  #-----------------------------------------------------------------------------
  method insert ( --> BSON::Document ) {

    my BSON::Document $doc;

    # Check if there are records
    if $!records.elems == 0 {
      $doc = BSON::Document.new: (
        :!ok,
        :reason{'No records to write'}
      );
    }

    # Check if there are leftover errors from previous set() calls
    elsif $!failed-fields.elems {
      $doc = self!document-failures;
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
  method delete ( --> BSON::Document ) {

  }

  #-----------------------------------------------------------------------------
  method !check-record (
    BSON::Document:D $schema,
    BSON::Document:D $record
  ) {

    for $!schema.keys -> $field-name {
      if $record{$field-name}:exists {
        if $record{$field-name} ~~ BSON::Document {
          self!check-record( $!schema{$field-name}, $record{$field-name});
        }

        elsif $record{$field-name} !~~ $!schema{$field-name}[C-TYPE] {
          $!failed-fields.push: [
            $field-name,                      # failed fieldname
            C-TYPE,                           # failed on type
            $record{$field-name}.WHAT,        # has type
            $!schema{$field-name}[C-TYPE]     # should be type
          ];
        }
      }

      else {
        if $!schema{$field-name}[C-MANDATORY] {
          $!failed-fields.push: [
            $field-name,                      # failed fieldname
            C-MANDATORY,                      # field is missing
          ];
        }
      }
    }

    unless $!append-unknown-fields {
      for $record.keys -> $field-name {
        if $schema{$field-name}:!exists {
          $!failed-fields.push: [
            $field-name,                      # failed fieldname
            C-NOTINSCHEMA,                    # field not in schema
          ];
        }
      }
    }
  }

  #-----------------------------------------------------------------------------
  method !check-schema ( BSON::Document:D $schema --> Bool ) {

  }

  #-----------------------------------------------------------------------------
  method !document-failures ( --> BSON::Document ) {

    my BSON::Document $error-doc .= new;
    $error-doc<ok> = 0;
    $error-doc<reason> = 'Missing fields or fields having wrong types';
    $error-doc<fields> = BSON::Document.new;

    for @$!failed-fields -> $field-spec {

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

sub gen-table-class (
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
