-module(libp2p_connection).

-record(connection, {
          module :: module(),
          state :: any()
         }).

-type connection() :: #connection{}.
-type shutdown() :: read | write | read_write.

-export_type([connection/0]).

-export([new/2, send/2, recv/1, recv/2, recv/3, acknowledge/2, fdset/1, fdclr/1,
         addr_info/1, close/1, shutdown/2, controlling_process/2]).


-callback acknowledge(any(), any()) -> ok.
-callback send(any(), iodata()) -> ok | {error, term()}.
-callback recv(any(), non_neg_integer(), pos_integer()) -> {ok, binary()} | {error, term()}.
-callback close(any()) -> ok.
-callback shutdown(any(), shutdown()) -> ok | {error, term()}.
-callback fdset(any()) -> ok | {error, term()}.
-callback fdclr(any()) -> ok.
-callback addr_info(any()) -> {multiaddr:multiaddr(), multiaddr:multiaddr()}.
-callback controlling_process(any(), pid()) ->  ok | {error, closed | not_owner | atom()}.

-define(RECV_TIMEOUT, 5000).

-spec new(atom(), any()) -> connection().
new(Module, State) ->
    #connection{module=Module, state=State}.

-spec send(connection(), iodata()) -> ok | {error, term()}.
send(#connection{module=Module, state=State}, Data) ->
    Module:send(State, Data).

-spec recv(connection()) -> {ok, binary()} | {error, term()}.
recv(Conn=#connection{}) ->
    recv(Conn, 0).

-spec recv(connection(), non_neg_integer()) -> {ok, binary()} | {error, term()}.
recv(Conn=#connection{}, Length) ->
    recv(Conn, Length, ?RECV_TIMEOUT).

-spec recv(connection(), non_neg_integer(), pos_integer()) -> {ok, binary()} | {error, term()}.
recv(#connection{module=Module, state=State}, Length, Timeout) ->
    Module:recv(State, Length, Timeout).

-spec acknowledge(connection(), any()) -> ok.
acknowledge(#connection{module=Module, state=State}, Ref) ->
    Module:acknowledge(State, Ref).

-spec close(connection()) -> ok.
close(#connection{module=Module, state=State}) ->
    Module:close(State).

-spec shutdown(connection(), shutdown()) -> ok | {error, term()}.
shutdown(#connection{module=Module, state=State}, How) ->
    Module:shutdown(State, How).

-spec fdset(connection()) -> ok | {error, term()}.
fdset(#connection{module=Module, state=State}) ->
    Module:fdset(State).

-spec fdclr(connection()) -> ok | {error, term()}.
fdclr(#connection{module=Module, state=State}) ->
    Module:fdclr(State).

-spec addr_info(connection()) -> {multiaddr:multiaddr(), multiaddr:multiaddr()}.
addr_info(#connection{module=Module, state=State}) ->
    Module:addr_info(State).

-spec controlling_process(connection(), pid())-> ok | {error, closed | not_owner | atom()}.
controlling_process(#connection{module=Module, state=State}, Pid) ->
    Module:controlling_process(State, Pid).
