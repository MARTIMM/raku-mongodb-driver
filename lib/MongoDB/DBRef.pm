use v6;
use MongoDB::Connection;

#-------------------------------------------------------------------------------
#
package MongoDB {
  class MongoDB::DBRef {

    has Str $.database;
    has Str $.collection;
    has BSON::ObjectId $.id;
    has Hash $.searched;

    my Any $dbref;

    #-----------------------------------------------------------------------------
    # my MongoDB::DBRef $dbref .= new( :id($id), :collection($cl),
    #                                  :database($db), :search($sdoc),
    #                                  :connection($cnn)
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
    multi submethod BUILD ( Str :$database, Str :$collection,
                            BSON::ObjectId :$id!
  #                          Hash :$search,
  #                          MongoDB::Connection :$connection
                          ) {

      $!database = $database;
      $!collection = $collection;
      $!id = $id;

      $dbref = {};
      if ?$!collection {
        $dbref = { '$id' => $!id, '$ref' => $!collection };
        if ?$!database {
          $dbref{'$db'} = $database;
        }
      }

      else {
        $dbref = $!id;
      }
    }

  #`{{
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

    method doc ( --> Any ) {

  #say "DBR: {$dbref.perl}";
      return $dbref;
    }
  }
}
