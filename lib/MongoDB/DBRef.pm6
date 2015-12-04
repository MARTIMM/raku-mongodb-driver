use v6;

use MongoDB::Connection;
use BSON::ObjectId-old;
use BSON::EDCTools;

#-------------------------------------------------------------------------------
#
package MongoDB {
  class MongoDB::DBRef {

    has Str $.database;
    has Str $.collection;
    has BSON::ObjectId $.id;
    has Hash $.searched;

    my Pair @dbref;

    #-----------------------------------------------------------------------------
    # my MongoDB::DBRef $dbref .= new( :id($id), :collection($cl),
    #                                  :database($db)
    #                                );
    # $collection.insert({ doc => $dbref });
    #
    # 1) only id;
    #    { doc => $id }
    # 2) + collection
    #    { doc => { '$ref' => $cl, '$id' => $id}
    # 3) + database
    #    { doc => { '$ref' => $cl, '$id' => $id, '$db' => $db}
    #
    multi submethod BUILD ( Str :$database, Str:D :$collection,
                            BSON::ObjectId:D :$id
                          ) {

      $!database = $database // $collection.database.name;
      $!collection = $collection;
      $!id = $id;
    }

    #-----------------------------------------------------------------------------
    #
    method encode-dbref ( Str $key-name, $bson-obj --> Buf ) {

      @dbref = Nil;
      @dbref.push: ( '$ref' => $!collection, '$id' => $!id);
      @dbref.push: ('$db' => $!database);

      
    }

    #-----------------------------------------------------------------------------
    #
    method decode-dbref ( Array $a, $index is rw --> Pair ) {

      my Str $key-name = decode-e-name( $a, $index);

#      return $key-name => MongoDB::DBRef.new( ... );
    }

#`{{
    #-----------------------------------------------------------------------------
    #
    multi method infix:<=>( Hash $doc is rw, MongoDB::DBRef $dbr ) {
     $dbref = {};
     if ?$!collection {
        $dbref = { '$id' => $!id, '$ref' => $!collection };
      }

     $doc = $dbref;
    }

    multi method infix:<=>( BSON::ObjectId $id is rw, MongoDB::DBRef $dbr ) {
      $id = $!id;
    }
}}

    #-----------------------------------------------------------------------------
    #
    method doc ( --> Pair ) {

  #say "DBR: {@dbref.perl}";
      return @dbref;
    }
  }
}
