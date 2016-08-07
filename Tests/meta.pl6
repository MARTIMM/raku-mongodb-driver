#!/usr/bin/env perl6

use v6.c;

use Test;

use BSON::Document;

use MongoDB;
use MongoDB::Client;
use MongoDB::Database;
use MongoDB::Collection;

#-------------------------------------------------------------------------------
class MdbMeta {

  #-----------------------------------------------------------------------------
  class MdbTable {

    has Hash $.attr-list;

    #---------------------------------------------------------------------------
    method check( :%fields) {

    }

    #---------------------------------------------------------------------------
    method read () {
say self;
say self.^attributes;
#say "$!db.name, $!cl.name";
      $!attr-list.keys;
    }

    #---------------------------------------------------------------------------
    method read-next () {

    }

    #---------------------------------------------------------------------------
    method write () {

    }

    #---------------------------------------------------------------------------
    method update () {

    }

    #---------------------------------------------------------------------------
    method delete () {

    }
  }

  #-----------------------------------------------------------------------------
  method gen-table-class (
    Str:D $uri,
    Str:D $db-name,
    Str:D $cl-name,
#    MongoDB::Client $client,
#    MongoDB::Database:D $db,
#    MongoDB::Collection:D $cl,
    BSON::Document:D $schema

    --> MdbTable
  ) {

    # class $db-$cl is MdbTable {
    my $name = "$db-name.tc()::$cl-name.tc()";
    my $A := Metamodel::ClassHOW.new_type(:$name);
    $A.^add_parent( MdbTable, :!hides);

#`{{
    my $attr-list-attr = Attribute.new(
      :name<$!attr-list>,
      :type(Hash),
      :package($name)
    );
}}

    my $client-attr = Attribute.new(
      :name<$!client>,
      :type(MongoDB::Client),
      :package($name)
    );

    my $db-attr = Attribute.new(
      :name<$!db>,
      :type(MongoDB::Database),
      :package($name)
    );

    my $cl-attr = Attribute.new(
      :name<$!cl>,
      :type(MongoDB::Collection),
      :package($name)
    );

    my $schema-attr = Attribute.new(
      :name<$!schema>,
      :type(BSON::Document),
      :package($name)
    );

#    $A.^add_attribute($attr-list-attr);
    $A.^add_attribute($client-attr);
    $A.^add_attribute($db-attr);
    $A.^add_attribute($cl-attr);
    $A.^add_attribute($schema-attr);

    # Make it so
    $A.^compose;

    my $blessed = $A.bless;
say "Blessed: ", $blessed.WHAT;

    my Attribute $attr-list-attr;
    my Hash $attrs = {};
    for $blessed.^attributes -> $a {
say "Attr: $a.name() = ", $a;
      $attrs{$a.name} = $a;
      $attr-list-attr = $a if $a.name eq '$attr-list';
    }
say "Attr meth: ", $attr-list-attr.^methods;
say "Defs: ", $attr-list-attr.defined, ', ', $attrs.defined;
    $attr-list-attr.set_value( $blessed, $attrs);

    $db-attr.set_value( $blessed, my $client = MongoDB::Client.new(:$uri));
    $db-attr.set_value( $blessed, my $db = $client.database($db-name));
    $cl-attr.set_value( $blessed, $db.collection($cl-name));
    $schema-attr.set_value( $blessed, $schema);

#`{{
    # Need a new to bless the object after which the BUILD can access the
    # attributes
    #
    $A.^add_method(
      'new',
      method new ( $A: ) {
say "Self new: ", self, ', ', $A;
        # Bless the object into the proper class
#        "$name".bless;

        # Return proper object
        $A.bless;
#        $A;
#        self.bless;
#        my $x = self.CREATE;
#        $x.BUILD;
      }
    );

    $A.^add_method(
      'BUILD',
      submethod BUILD ( $A: ) {
say "Self BUILD: ", self;
        my Attribute $attr-list-attr;
        my Hash $attrs;
        for self.^attributes -> $a {
          $attrs{$a.name} = $a;
          $attr-list-attr = $a if $a.name eq '$attr-list';
        }
say "Attr meth: ", $attr-list-attr.^methods;
#        $attr-list-attr.set-value( $A, $attrs);

        $db-attr.set_value( $A, my $client = MongoDB::Client.new(:$uri));
        $db-attr.set_value( $A, my $db = $client.database($db-name));
        $cl-attr.set_value( $A, $db.collection($cl-name));
        $schema-attr.set_value( $A, $schema);
      }
    );
    # Make it so
    $A.^compose;

}}
#`{{
    augment class $A {
      submethod BUILD ( ) {
say self.^name;
      }
    }
}}

say "0: $A.^parents(:all).perl()";
say "1: ", $A.^attributes.Str();
say "2: ", $A.^methods();

    $A;
  }
}


my Str $uri = 'mongodb://:65010';
my Str $db-name = 'contacts';
my Str $cl-name = 'address';

my BSON::Document $schema .= new: (
  street => [ 1, Str],
  number => [ 1, Int],
  city => [ 1, Str],
  zip => [ 0, Str],
  state => [ 0, Str],
  country => [ 1, Str],
);

my MdbMeta $table-class .= gen-table-class( $uri, $db-name, $cl-name, $schema);
is $table-class.^name, 'Contacts::Address', "class type is $table-class.^name()";

#my $table = $table-class.new;
my $table = $table-class;
say $table.^name;
say $table.^methods;
say $table.defined;

ok $table.^can('read'), 'table can read';
ok $table.^can('write'), 'table can write';

say $table.attr-list;

$table.read();

done-testing;
