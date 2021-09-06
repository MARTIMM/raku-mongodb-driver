BSON::Regex
===========

Container for regular expressions

Description
===========

Provides regular expression capabilities for pattern matching strings in queries. MongoDB uses Perl 5 compatible regular expressions (i.e. "PCRE" ) version 8.42 with UTF-8 support.

The class can be used in queries to find documents on a database. However, it is also possible to provide the regex in string format nowadays.

Synopsis
========

Declaration
-----------

    unit class BSON::Regex:auth<github:MARTIMM>;

Example
-------

    given my BSON::Document $request .= new {
      .<findAndModify> = 'famous-people';
      .<query> = (:surname(
        '$regex' => BSON::Regex.new( :regex<hendrix|james>, :options<i>)
      ));
      .<update> = ( '$set' => (:type<employee>));
    }

    my BSON::Document $result = $database.run-command($request);

The query part can be made different with newer servers and can be written as (See also [mongodb query](https://docs.mongodb.com/v4.4/reference/operator/query/regex/#mongodb-query-op.-regex))

    .<query> = (:surname( '$regex' => 'hendrix|james', '$options' => '<i>')),

It looks that the object form is a bit simpler to write.

Methods
=======

new
---

Create a new **BSON::Regex** object.

    new( Str:D :$regex, Str :$options = '' )

  * Str:D :$regex; Perl 5 like regular expresion.

  * Str :$options; Options to control the regex.

Options are

  * **i**; Case insensitivity to match upper and lower cases. For an example, see Perform Case-Insensitive Regular Expression Match.

  * **g**; The global option. However, the `$regex` does not support it.

  * **m**; For patterns that include anchors (i.e. ^ for the start, $ for the end), match at the beginning or end of each line for strings with multiline values. Without this option, these anchors match at beginning or end of the string. For an example, see Multiline Match for Lines Starting with Specified Pattern.

    If the pattern contains no anchors or if the string value has no newline characters (e.g. \n), the m option has no effect.

  * **s**; Allows the dot character (i.e. .) to match all characters including newline characters. For an example, see Use the . Dot Character to Match New Line.

  * **x**; "Extended" capability to ignore all white space characters in the $regex pattern unless escaped or included in a character class.

    Additionally, it ignores characters in-between and including an un-escaped hash/pound (#) character and the next new line, so that you may include comments in complicated patterns. This only applies to data characters; white space characters may never appear within special character sequences in a pattern.

    The x option does not affect the handling of the VT character (i.e. code 11).

raku, perl
----------

Show the structure of a Regex

    method raku ( Int :$indent --> Str ) is also<perl>

  * Int $indent; setting the starting indentation.

