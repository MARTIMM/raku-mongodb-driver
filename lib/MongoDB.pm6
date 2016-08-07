use v6.c;
use MongoDB::Log :ALL;

sub EXPORT { {
    '&set-exception-process-level'      => &set-exception-process-level,
    '&set-exception-processing'         => &set-exception-processing,
    '&set-logfile'                      => &set-logfile,
    '&open-logfile'                     => &open-logfile,

    '&trace-message'                    => &trace-message,
    '&debug-message'                    => &debug-message,
    '&info-message'                     => &info-message,
    '&warn-message'                     => &warn-message,
    '&error-message'                    => &error-message,
    '&fatal-message'                    => &fatal-message,
  }
};

#-------------------------------------------------------------------------------
package MongoDB {

  #-----------------------------------------------------------------------------
  # Client object topology types
  #
  subset TopologyType of Int is export where 40 <= $_ <= 43;

  constant C-UNKNOWN-TPLGY                 = 40;   # Start value
  constant C-STANDALONE-TPLGY              = 41;   # Standalone, one server
  constant C-REPLSET-WITH-PRIMARY-TPLGY    = 42;   # Replicaset with prim
  constant C-REPLSET-NO-PRIMARY-TPLGY      = 43;   # Replicaset without prim

  #-----------------------------------------------------------------------------
  # Status values of a Server.object
  #
  subset ServerStatus of Int where 10 <= $_ <= 22;

  constant C-UNKNOWN-SERVER          = 10;   # Start value
  constant C-NON-EXISTENT-SERVER     = 11;   # DNS problems
  constant C-DOWN-SERVER             = 12;   # Connection problems
  constant C-RECOVERING-SERVER       = 13;   # -

  constant C-REJECTED-SERVER         = 14;   # Client status of Server object
  constant C-GHOST-SERVER            = 15;   # -

  constant C-REPLICA-PRE-INIT        = 16;   # Standalone start with option
  constant C-REPLICASET-PRIMARY      = 17;   # Primary after replSetInitiate
  constant C-REPLICASET-SECONDARY    = 18;   # Secondary after replSetReconfig
  constant C-REPLICASET-ARBITER      = 19;   # -

  constant C-SHARDING-SERVER         = 20;   # -
  constant C-MASTER-SERVER           = 21;   # Standalone master
  constant C-SLAVE-SERVER            = 22;   # -

  #-----------------------------------------------------------------------------
  # Constants. See http://www.mongodb.org/display/DOCS/Mongo+Wire+Protocol#MongoWireProtocol-RequestOpcodes
  #
  subset WireOpcode of Int where ($_ == 1 or $_ == 1000 or 2001 <= $_ <= 2007);

  constant C-OP-REPLY           = 1;    # Reply to a client request.responseTo is set
  constant C-OP-MSG             = 1000; # generic msg command followed by a string. deprecated
  constant C-OP-UPDATE          = 2001; # update document
  constant C-OP-INSERT          = 2002; # insert new document
  constant C-OP-RESERVED        = 2003; # formerly used for OP_GET_BY_OID
  constant C-OP-QUERY           = 2004; # query a collection
  constant C-OP-GET-MORE        = 2005; # Get more data from a query. See Cursors
  constant C-OP-DELETE          = 2006; # Delete documents
  constant C-OP-KILL-CURSORS    = 2007; # Tell database client is done with a cursor

  #-----------------------------------------------------------------------------
  # Query flags
  #
  subset QueryFindFlags of Int where $_ ~~ any(0x02,0x04...0x80);

  constant C-QF-RESERVED        = 0x01;
  constant C-QF-TAILABLECURSOR  = 0x02; # corresponds to TailableCursor. Tailable means cursor is not closed when the last data is retrieved. Rather, the cursor marks the final object\u2019s position. You can resume using the cursor later, from where it was located, if more data were received. Like any \u201clatent cursor\u201d, the cursor may become invalid at some point (CursorNotFound) \u2013 for example if the final object it references were deleted.
  constant C-QF-SLAVEOK         = 0x04; # corresponds to SlaveOk.Allow query of replica slave. Normally these return an error except for namespace \u201clocal\u201d.
  constant C-QF-OPLOGREPLAY     = 0x08; # corresponds to OplogReplay. Internal replication use only - driver should not set.
  constant C-QF-NOCURSORTIMOUT  = 0x10; # corresponds to NoCursorTimeout. The server normally times out idle cursors after an inactivity period (10 minutes) to prevent excess memory use. Set this option to prevent that.
  constant C-QF-AWAITDATA       = 0x20; # corresponds to AwaitData. Use with TailableCursor. If we are at the end of the data, block for a while rather than returning no data. After a timeout period, we do return as normal.
  constant C-QF-EXHAUST         = 0x40; # corresponds to Exhaust. Stream the data down full blast in multiple \u201cmore\u201d packages, on the assumption that the client will fully read all data queried. Faster when you are pulling a lot of data and know you want to pull it all down. Note: the client is not allowed to not read all the data unless it closes the connection.
  constant C-QF-PORTAIL         = 0x80; # corresponds to Partial. Get partial results from a mongos if some shards are down (instead of throwing an error)

  #-----------------------------------------------------------------------------
  # Response flags
  #
  constant C-RF-CursorNotFound  = 0x01; # corresponds to CursorNotFound. Is set when getMore is called but the cursor id is not valid at the server. Returned with zero results.
  constant C-RF-QueryFailure    = 0x02; # corresponds to QueryFailure. Is set when query failed. Results consist of one document containing an \u201c$err\u201d field describing the failure.
  constant C-RF-ShardConfigStale= 0x04; # corresponds to ShardConfigStale. Drivers should ignore this. Only mongos will ever see this set, in which case, it needs to update config from the server.
  constant C-RF-AwaitCapable    = 0x08; # corresponds to AwaitCapable. Is set when the server supports the AwaitData Query option. If it doesn\u2019t, a client should sleep a little between getMore\u2019s of a Tailable cursor. Mongod version 1.6 supports AwaitData and thus always sets AwaitCapable.

  #-----------------------------------------------------------------------------
  # Other types

  # See also https://en.wikipedia.org/wiki/List_of_TCP_and_UDP_port_numbers
  subset PortType of Int where 0 < $_ <= 65535;

  # Helper constraints when module cannot be loaded(use)
  subset ClientType where .^name eq 'MongoDB::Client';
  subset DatabaseType where .^name eq 'MongoDB::Database';
  subset CollectionType where .^name eq 'MongoDB::Collection';
  subset ServerType where .^name eq 'MongoDB::Server';
  subset SocketType where .^name eq 'MongoDB::Socket';

  #-----------------------------------------------------------------------------
  #
  signal(Signal::SIGTERM).tap: {say "Hi"; die "Stopped by user"};

}
