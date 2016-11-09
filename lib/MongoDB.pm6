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
  enum QueryFindFlags is export (
    :C-NO-FLAGS(0x00), :C-QF-RESERVED(0x01),
    :C-QF-TAILABLECURSOR(0x02), :C-QF-SLAVEOK(0x04),
    :C-QF-OPLOGREPLAY(0x08), :C-QF-NOCURSORTIMOUT(0x10), :C-QF-AWAITDATA(0x20),
    :C-QF-EXHAUST(0x40), :C-QF-PORTAIL(0x80),
  );

  #-----------------------------------------------------------------------------
  # Response flags
  enum ResponseFlags is export (
    :C-RF-CursorNotFound(0x01), :C-RF-QueryFailure(0x02),
    :C-RF-ShardConfigStale(0x04), :C-RF-AwaitCapable(0x08),
  );

  #-----------------------------------------------------------------------------
  # Socket values
  constant C-MAX-SOCKET-UNUSED-OPEN is export = 900; # Quarter of an hour unused

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
