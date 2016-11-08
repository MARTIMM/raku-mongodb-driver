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
  enum TopologyType is export <
    C-UNKNOWN-TPLGY C-STANDALONE-TPLGY C-REPLSET-WITH-PRIMARY-TPLGY
    C-REPLSET-NO-PRIMARY-TPLGY
  >;

  #-----------------------------------------------------------------------------
  # Status values of a Server.object
  enum ServerStatus is export <
    C-UNKNOWN-SERVER C-NON-EXISTENT-SERVER C-DOWN-SERVER C-RECOVERING-SERVER       = 13;   # -
    C-REJECTED-SERVER C-GHOST-SERVER

    C-REPLICA-PRE-INIT C-REPLICASET-PRIMARY C-REPLICASET-SECONDARY
    C-REPLICASET-ARBITER

    C-SHARDING-SERVER C-MASTER-SERVER C-SLAVE-SERVER
  >;

  #-----------------------------------------------------------------------------
  # Constants. See http://www.mongodb.org/display/DOCS/Mongo+Wire+Protocol#MongoWireProtocol-RequestOpcodes
  enum WireOpcode is export (
    :C-OP-REPLY(1),
    :C-OP-MSG(1000), :C-OP-UPDATE(2001), :C-OP-INSERT(2002),
    :C-OP-RESERVED(2003), :C-OP-QUERY(2004), :C-OP-GET-MORE(2005),
    :C-OP-DELETE(2006), :C-OP-KILL-CURSORS(2007),
  );

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
  # Socket values
  constant C-MAX-SOCKET-UNUSED-OPEN is export   = 900; # Quarter of an hour unused

  #-----------------------------------------------------------------------------
  # Other types

  # See also https://en.wikipedia.org/wiki/List_of_TCP_and_UDP_port_numbers
  subset PortType of Int is export where 0 < $_ <= 65535;

  # Helper constraints when module cannot be loaded(use)
  subset ClientType is export where .^name eq 'MongoDB::Client';
  subset DatabaseType is export where .^name eq 'MongoDB::Database';
  subset CollectionType is export where .^name eq 'MongoDB::Collection';
  subset ServerType is export where .^name eq 'MongoDB::Server';
  subset SocketType is export where .^name eq 'MongoDB::Socket';

  #-----------------------------------------------------------------------------
  #
  signal(Signal::SIGTERM).tap: {say "Hi"; die "Stopped by user"};

}
