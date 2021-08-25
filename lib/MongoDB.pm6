use v6;

use MongoDB::Log;

sub EXPORT { {
    '&add-send-to'                      => &add-send-to,
    '&modify-send-to'                   => &modify-send-to,
    '&drop-send-to'                     => &drop-send-to,
    '&drop-all-send-to'                 => &drop-all-send-to,

    '&set-filter'                       => &set-filter,
    '&reset-filter'                     => &reset-filter,
    '&clear-filter'                     => &clear-filter,

    '&trace-message'                    => &trace-message,
    '&debug-message'                    => &debug-message,
    '&info-message'                     => &info-message,
    '&warn-message'                     => &warn-message,
    '&error-message'                    => &error-message,
    '&fatal-message'                    => &fatal-message,

    'X::MongoDB'               => X::MongoDB,
  }
};

#------------------------------------------------------------------------------
unit package MongoDB:auth<github:MARTIMM>:ver<0.1.0>;

#------------------------------------------------------------------------------
constant SERVER-VERSION1 is export = '4.0.5';
constant SERVER-VERSION2 is export = '4.0.18';


#------------------------------------------------------------------------------
# Wire versions, TopologyType, ServerType, TopologyDescription and
# ServerDescription are described here: https://github.com/mongodb/specifications/blob/master/source/server-discovery-and-monitoring/server-discovery-and-monitoring.rst#data-structures
#------------------------------------------------------------------------------
# wire versions
constant clientMinWireVersion is export = 0;
constant clientMaxWireVersion is export = 7;

#------------------------------------------------------------------------------
#TE:1:TopologyType
=begin pod
=head2 enum TopologyType

Topology types

=item TT-Single; The first server with no faulty responses will set the topology to single. Any new ST-Standalone server will flip the topology to TT-Unknown.
=item TT-ReplicaSetNoPrimary; When there are no primary servers found (yet) in a group of replicaservers, the topology is one of replicaset without a primary. When only one server is provided in the uri, the topology would first be TT-Single. Then the Client will gather more data from the server to find the primary and or other secondary servers. The topology might then change into this topology or the TT-ReplicaSetWithPrimary described below.
=item TT-ReplicaSetWithPrimary; When in a group of replica servers a primary is found, this topology is selected.
=item TT-Sharded; When mongos servers are provided in the uri, this topology applies. When there is only one server, the type would become TT-Single.
=item TT-Unknown; Any set of servers which are ST-Unknown will set the topology to TT-Unknown. Depending on the problems of these servers their states can change, and with that, the topology. When there is a set of servers which are not mixable, the topology becomes also TT-Unknown. Examples are more than one standalone server, mongos and replica servers, replicaservers from different replica sets etc.

=end pod

enum TopologyType is export <
  TT-Single TT-ReplicaSetNoPrimary TT-ReplicaSetWithPrimary
  TT-Sharded TT-Unknown TT-NotSet
>;

#------------------------------------------------------------------------------
enum TopologyDescription is export <
  Topo-type Topo-setName Topo-maxSetVersion
  Topo-maxElectionId Topo-servers Topo-stale Topo-compatible
  Topo-compatibilityError Topo-logicalSessionTimeoutMinutes
>;

#------------------------------------------------------------------------------
#TE:1:ServerType
=begin pod
=head2 enum ServerType

Status values of a Server object

=item ST-Mongos; Field 'msg' in returned resuld of ismaster request is 'isdbgrid'.
=item ST-RSGhost; Field 'isreplicaset' is set. Server is in an initialization state.
=item ST-RSPrimary; Replicaset primary server. Field 'setName' is the replicaset name and 'ismaster' is True.
=item ST-RSSecondary; Replicaset secondary server. Field 'setName' is the replicaset name and 'secondary' is True.
=item ST-RSArbiter; Replicaset arbiter. Field 'setName' is the replicaset name and 'arbiterOnly' is True.
=item ST-RSOther; An other type of replicaserver is found. Possibly in transition between states.
=item ST-Standalone;  Any other server being master or slave.
=item ST-Unknown; Servers which are down or with errors.
=item ST-PossiblePrimary; not implemeted in this driver.

=end pod

enum ServerType is export <
  ST-Standalone ST-Mongos ST-PossiblePrimary ST-RSPrimary ST-RSSecondary
  ST-RSArbiter ST-RSOther ST-RSGhost ST-Unknown
>;

#------------------------------------------------------------------------------
enum ServerDescription is export <
  Srv-address Srv-error Srv-roundTripTime Srv-lastWriteDate Srv-opTime
  Srv-type Srv-minWireVersion, Srv-maxWireVersion Srv-me Srv-hosts
  Srv-passives Srv-arbiters Srv-tags Srv-setName Srv-setVersion
  Srv-electionId Srv-primary Srv-lastUpdateTime
  Srv-logicalSessionTimeoutMinutes Srv-topologyVersion
>;

#------------------------------------------------------------------------------
# See also https://www.mongodb.com/blog/post/server-selection-next-generation-mongodb-drivers
# read concern mode values
#TODO pod doc arguments
enum ReadConcernModes is export <
  RCM-Primary RCM-Secondary RCM-Primary-preferred
  RCM-Secondary-preferred RCM-Nearest
>;

#------------------------------------------------------------------------------
# Constants. See http://www.mongodb.org/display/DOCS/Mongo+Wire+Protocol#MongoWireProtocol-RequestOpcodes
enum WireOpcode is export (
  :OP-REPLY(1),
  :OP-MSG(1000), :OP-UPDATE(2001), :OP-INSERT(2002),
  :OP-RESERVED(2003), :OP-QUERY(2004), :OP-GET-MORE(2005),
  :OP-DELETE(2006), :OP-KILL-CURSORS(2007),
);

#------------------------------------------------------------------------------
=begin pod

Query flags.

=item bit 0 is reserved. Must be set to 0.
=item C-QF-TAILABLECURSOR corresponds to TailableCursor. Tailable means cursor is not closed when the last data is retrieved. Rather, the cursor marks the final object's position. You can resume using the cursor later, from where it was located, if more data were received. Like any "latent cursor", the cursor may become invalid at some point (CursorNotFound) – for example if the final object it references were deleted.
=item C-QF-SLAVEOK corresponds to SlaveOk. Allow query of replica slave. Normally these return an error except for namespace "local".
=item C-QF-OPLOGREPLAY corresponds to OplogReplay. Starting in MongoDB 4.4, you need not specify this flag because the optimization automatically happens for eligible queries on the oplog. See oplogReplay for more information.
=item C-QF-NOCURSORTIMOUT corresponds to NoCursorTimeout. The server normally times out idle cursors after an inactivity period (10 minutes) to prevent excess memory use. Set this option to prevent that.
=item C-QF-AWAITDATA corresponds to AwaitData. Use with TailableCursor. If we are at the end of the data, block for a while rather than returning no data. After a timeout period, we do return as normal.
=item C-QF-EXHAUST corresponds to Exhaust. Stream the data down full blast in multiple "more" packages, on the assumption that the client will fully read all data queried. Faster when you are pulling a lot of data and know you want to pull it all down. Note: the client is not allowed to not read all the data unless it closes the connection.
=item C-QF-PORTAIL corresponds to Partial. Get partial results from a mongos if some shards are down (instead of throwing an error)
=item bits 8-31 are reserved. Must be set to 0.
=end pod

#TT:1:QueryFindFlags:
enum QueryFindFlags is export (
  :C-NO-FLAGS(0x00), :C-QF-RESERVED(0x01),
  :C-QF-TAILABLECURSOR(0x02), :C-QF-SLAVEOK(0x04),
  :C-QF-OPLOGREPLAY(0x08), :C-QF-NOCURSORTIMOUT(0x10), :C-QF-AWAITDATA(0x20),
  :C-QF-EXHAUST(0x40), :C-QF-PORTAIL(0x80),
);

#------------------------------------------------------------------------------
# Response flags
enum ResponseFlags is export (
  :RF-CURSORNOTFOUND(0x01), :RF-QUERYFAILURE(0x02),
  :RF-SHARDCONFIGSTALE(0x04), :RF-AWAITCAPABLE(0x08),
);

#------------------------------------------------------------------------------
# Socket values
constant MAX-SOCKET-UNUSED-OPEN is export = 300; # 5 minutes unused

#------------------------------------------------------------------------------
# Server defaults

#------------------------------------------------------------------------------
# Client configuration defaults
constant C-LOCALTHRESHOLDMS is export = 15;
constant C-SERVERSELECTIONTIMEOUTMS is export = 30_000;
constant C-HEARTBEATFREQUENCYMS is export = 10_000;
constant C-SMALLEST-MAX-STALENEST-SECONDS = 90;

#------------------------------------------------------------------------------
# User admin defaults
constant C-PW-LOWERCASE is export = 0;
constant C-PW-UPPERCASE is export = 1;
constant C-PW-NUMBERS is export = 2;
constant C-PW-OTHER-CHARS is export = 3;

constant C-PW-MIN-UN-LEN is export = 6;
constant C-PW-MIN-PW-LEN is export = 6;

#------------------------------------------------------------------------------
# Other types

# See also https://en.wikipedia.org/wiki/List_of_TCP_and_UDP_port_numbers
subset PortType of Int is export where 0 < $_ <= 65535;

# Helper constraints when module cannot be loaded(use)
subset ClientType is export where .^name eq 'MongoDB::Client';
subset DatabaseType is export where .^name eq 'MongoDB::Database';
subset CollectionType is export where .^name eq 'MongoDB::Collection';
#subset ServerClassType is export where .^name eq 'MongoDB::Server';
#subset SocketType is export where .^name eq 'MongoDB::Server::Socket';

#------------------------------------------------------------------------------
#signal(Signal::SIGTERM).tap: {say "Hi"; die "Stopped by user"};

#------------------------------------------------------------------------------
sub mongodb-driver-version ( --> Version ) is export {
  MongoDB.^ver;
}

#------------------------------------------------------------------------------
sub mongodb-driver-author ( --> Str ) is export {
  MongoDB.^auth;
}
