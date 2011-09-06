class MongoDB::Cursor;

# int64 (8 byte buffer)
has Buf $!cid;

submethod BUILD ( Buf $b ) {
	$!cid = Buf.new( );
	
	$!cid.contents.push( $b.contents.shift ) for ^ 8;
}

