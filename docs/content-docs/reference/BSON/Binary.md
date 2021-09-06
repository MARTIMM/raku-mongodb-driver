BSON::Binary
============

Container for binary data

Description
===========

The BSON specification describes several types of binary data of which a few are deprecated. In the table below, you can see what is defined and what is supported by this class.

<table class="pod-table">
<thead><tr>
<th>SubCode</th> <th>Constant</th> <th>Note</th>
</tr></thead>
<tbody>
<tr> <td>0x00</td> <td>BSON::C-GENERIC</td> <td>Generic binary subtype.</td> </tr> <tr> <td>0x01</td> <td>BSON::C-FUNCTION</td> <td>Function.</td> </tr> <tr> <td>0x02</td> <td>BSON::C-BINARY-OLD</td> <td>Binary, deprecated.</td> </tr> <tr> <td>0x03</td> <td>BSON::C-UUID-OLD</td> <td>UUID, deprecated.</td> </tr> <tr> <td>0x04</td> <td>BSON::C-UUID</td> <td>UUID.</td> </tr> <tr> <td>0x05</td> <td>BSON::C-MD5</td> <td>MD5.</td> </tr> <tr> <td>0x06</td> <td>BSON::C-ENCRIPT</td> <td>Encrypted BSON value. This new and not yet implemented.</td> </tr> <tr> <td>… 0x7F</td> <td></td> <td>All other codes to 0x80 are reserved.</td> </tr> <tr> <td>0x80</td> <td></td> <td>User may define their own code from 0x80 … 0xFF.</td> </tr> <tr> <td>0xFF</td> <td></td> <td>End of the range.</td> </tr>
</tbody>
</table>

Synopsis
========

Declaration
-----------

    unit class BSON::Binary:auth<github:MARTIMM>;

Example
-------

    # A Universally Unique IDentifier
    my BSON::Document $doc .= new;
    $doc<uuid> = BSON::Binary.new(
      :data(UUID.new(:version(4).Blob)), :type(BSON::C-UUID)
    );

    # My own complex number type. Can be done easier, but well you know,
    # I needed some example …
    enum MyBinDataTypes ( :COMPLEX(0x80), …);
    my Complex $c = 2.4 + 3.3i;
    my Buf $data .= new;
    $data.write-num64( 0, $c.re, LittleEndian);
    $data.write-num64( BSON::C-DOUBLE-SIZE, $c.im, LittleEndian);
    $doc<complex> = BSON::Binary.new( :$data, :type(COMPLEX));

Methods
=======

new
---

Create a container to hold binary data.

    new ( Buf :$data, Int :$type = BSON::C-GENERIC )

  * Buf :$data; the binary data.

  * Int :$type; the type of the data. By default it is set to BSON::C-GENERIC.

raku, perl
----------

Show the structure of a Binary

    method raku ( Int :$indent --> Str ) is also<perl>

  * Int $indent; setting the starting indentation.

encode
------

Encode a BSON::Binary object. This is called from the BSON::Document encode method.

    method encode ( --> Buf )

decode
------

Decode a Buf object. This is called from the BSON::Document decode method.

    method decode (
      Buf:D $b, Int:D $index is copy, Int:D :$buf-size
      --> BSON::Binary
    )

  * Buf $b; the binary data

  * Int $index; index into a larger document where binary starts

  * Int :$buf-size; size of binary, only checked for UUID and MD5

