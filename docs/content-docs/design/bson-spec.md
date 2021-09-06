---
title: BSON Specification
layout: sidebar
nav_menu: default-nav
sidebar_menu: design-sidebar
---
# Specification of BSON Version 1.1

_For the original document, [look here](https://bsonspec.org/spec.html)._

BSON is a binary format in which zero or more ordered key/value pairs are stored as a single entity. We call this entity a document.

The following grammar specifies version 1.1 of the BSON standard. We've written the grammar using a pseudo-BNF syntax. Valid BSON data is represented by the document non-terminal.


## Basic Types

The following basic types are used as terminals in the rest of the grammar. Each type must be serialized in little-endian format.

byte 	  1 byte (8-bits)
int32 	4 bytes (32-bit signed integer, two's complement)
int64 	8 bytes (64-bit signed integer, two's complement)
uint64 	8 bytes (64-bit unsigned integer)
double 	8 bytes (64-bit IEEE 754-2008 binary floating point)
decimal128 	16 bytes (128-bit IEEE 754-2008 decimal floating point)


## Non-terminals

The following specifies the rest of the BSON grammar. Note that quoted strings represent terminals, and should be interpreted with C semantics (e.g. "0x01" represents the byte 0000 0001). Also note that we use the * operator as shorthand for repetition (e.g. ("0x01"*2) is "0x010x01"). When used as a unary operator, * means that the repetition can occur 0 or more times.

```
document ::=
    int32 e_list "0x00" ①

element-list ::=
    element element-list 	
	| "" 	

element ::=
    "0x01" e_name double 	     64-bit binary floating point
	| "0x02" e_name string 	     UTF-8 string
	| "0x03" e_name document     Embedded document
	| "0x04" e_name document     Array
	| "0x05" e_name binary 	     Binary data
	| "0x06" e_name Undefined    (value) — Deprecated
	| "0x07" e_name (byte*12)    ObjectId
	| "0x08" e_name "0x00" 	     Boolean "false"
	| "0x08" e_name "0x01" 	     Boolean "true"
	| "0x09" e_name int64        UTC datetime
	| "0x0A" e_name Null value
	| "0x0B" e_name cstring cstring    Regular expression
	| "0x0C" e_name string (byte*12)   DBPointer — Deprecated
	| "0x0D" e_name string       JavaScript code
	| "0x0E" e_name string       Symbol. — Deprecated
	| "0x0F" e_name code_w_s     JavaScript code w/ scope — Deprecated
	| "0x10" e_name int32        32-bit integer
	| "0x11" e_name uint64       Timestamp
	| "0x12" e_name int64        64-bit integer
	| "0x13" e_name decimal128   128-bit decimal floating point
	| "0xFF" e_name Min key
	| "0x7F" e_name Max key

e_name ::=
    cstring 	Key name

string ::=
  int32 (byte*) "0x00"	String - The int32 is the number bytes in the (byte*) + 1 (for the trailing '0x00'). The (byte*) is zero or more UTF-8 encoded characters.

cstring ::= (byte*) "0x00" 	Zero or more modified UTF-8 encoded characters followed by '0x00'. The (byte*) MUST NOT contain '0x00', hence it is not full UTF-8.

binary 	::= int32 subtype (byte*) 	Binary - The int32 is the number of bytes in the (byte*).

subtype 	::= "0x00" 	Generic binary subtype
        	| 	"0x01" 	Function
        	| 	"0x02" 	Binary (Old)
        	| 	"0x03" 	UUID (Old)
        	| 	"0x04" 	UUID
        	| 	"0x05" 	MD5
        	| 	"0x06" 	Encrypted BSON value
        	| 	"0x80" 	User defined

code_w_s 	::= int32 string document 	Code w/ scope — Deprecated
```


### Notes
① BSON Document. int32 is the total number of bytes comprising the document.
* Array - The document for an array is a normal BSON document with integer values for the keys, starting with 0 and continuing sequentially. For example, the array ['red', 'blue'] would be encoded as the document {'0': 'red', '1': 'blue'}. The keys must be in ascending numerical order.
* UTC datetime - The int64 is UTC milliseconds since the Unix epoch.
* Regular expressions - The first cstring is the regex pattern, the second is the regex options string. Options are identified by characters, which must be stored in alphabetical order. Valid options are 'i' for case insensitive matching, 'm' for multiline matching, 'x' for verbose mode, 'l' to make \w, \W, etc. locale dependent, 's' for dotall mode ('.' matches everything), and 'u' to make \w, \W, etc. match unicode.
* Timestamp - Special internal type used by MongoDB replication and sharding. First 4 bytes are an increment, second 4 are a timestamp.
* Min key - Special type which compares lower than all other possible BSON element values.
* Max key - Special type which compares higher than all other possible BSON element values.
* Generic binary subtype - This is the most commonly used binary subtype and should be the 'default' for drivers and tools.
* The BSON "binary" or "BinData" datatype is used to represent arrays of bytes. BSON binary values have a subtype. This is used to indicate what kind of data is in the byte array. Subtypes from zero to 0x7f are predefined or reserved. Subtypes from 0x80 - 0xFF are user-defined. The types are only used to specify several types of binary data so the data can be checked on e.g. size (UUID and MD5). The mongodb server does not work with the data.
  * 0x01 - Function; There is a discussion about this [here on stackoverflow](https://stackoverflow.com/questions/34586432/understanding-binary-subtypes-in-bson-what-is-a-function-x01-and-what-poss) mentioning that this type is ancient and perhaps should be deprecated.
  * 0x02 - Binary (Old) - This used to be the default subtype, but was deprecated in favor of 0x00. Drivers and tools should be sure to handle 0x02 appropriately. The structure of the binary data (the byte* array in the binary non-terminal) must be an int32 followed by a (byte*). The int32 is the number of bytes in the repetition.
  * 0x03 UUID (Old) - This used to be the UUID subtype, but was deprecated in favor of 0x04. Drivers and tools for languages with a native UUID type should handle 0x03 appropriately.
  * 0x80-0xFF "User defined" subtypes. The binary data can be anything.
* Code w/ scope - Deprecated. The int32 is the length in bytes of the entire code_w_s value. The string is JavaScript code. The document is a mapping from identifiers to values, representing the scope in which the string should be evaluated.

<!--
#### Example 1
```
( a => 1, b => 2 )

doc-len
  0x10 'a' 0x00 1
  0x10 'b' 0x00 2
0x00
```

#### Example 2
```
( q => (b => 2) )

doc-len
  0x03 'q' 0x00
    subdoc-len
      0x10 'b' 0x00 2
    0x00
0x00
```

#### Example 3
```
( a => [ 'p', 'q'] )

doc-len
  0x04 'a' 0x00
    subdoc-len
      0x02 '0' 0x00 str-len 'p' 0x00
      0x02 '1' 0x00 str-len 'q' 0x00
    0x00
0x00
```

#### Example 4
Not possible?
```
( a => [ 'p', q => 'x'] )
( a => [ p => 'r', q => 'x'] )
( a => [ 'p', [ 12, 13, 14]] )
```

# Mapping of Raku types to BSON

Keys with values as is used for a document could be represented by a **Hash**. That would be the easiest way to implement them. The problem is however, that the sequence of keys may not be altered the way a Hash does. So the next possible representation would be a **List** of **Pair**
-->
