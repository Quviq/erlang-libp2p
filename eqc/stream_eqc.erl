-module(stream_eqc).

-include_lib("eqc/include/eqc.hrl").
-include_lib("eqc/include/eqc_statem.hrl").

-include("src/libp2p_yamux.hrl").

-record(state, {
          swarm = [],
          client,
          client_swarm,
          server,
          server_swarm,
          packet = <<>>,
          sent = <<>>,  %% formerly known as inflight
          to_send = <<>>,
          received = <<>>,
          inflight=0  %% remove
         }).

%% This is a test model, export all functions to avoid problems when one is overlooked. 
-compile([export_all, nowarn_export_all]).
-import(eqc_statem, [tag/2]).

initial_state() ->
    #state{}.

serve_stream(Connection, _Path, _TID, [Parent]) ->
    Parent ! {hello, self()},
    serve_loop(Connection, Parent).

serve_loop(Connection, Parent) ->
    receive
        {recv, N} ->
            Result = libp2p_connection:recv(Connection, N, 100),
            Parent ! {recv, N, Result},
            serve_loop(Connection, Parent);
         stop ->
            libp2p_connection:close(Connection)
      after 10000 ->
          stop %% cleanup if we don't manage to stop it as part of the test
    end.


%% QuickCheck commands

%% operation: start a swarm

start_swarm_pre(S) ->
  length(S#state.swarm) =/= 2.  %% extend later to any N >= 2

start_swarm_args(_S) ->
  [].

start_swarm() ->
  {ok, Pid} = libp2p_swarm:start(0),
  %% Check the type, but only use the Pid in model
  Pid.

start_swarm_next(S, Value, []) ->
  S#state{swarm = S#state.swarm ++ [Value]}.  %% add at tail for better shrinking

start_swarm_post(_S, [], Res) ->
  is_pid(Res).

%% operation: make one swarm the server

start_handler_pre(S) ->
  length(S#state.swarm) >= 2 andalso S#state.server == undefined.

start_handler_args(S) ->
  [elements(S#state.swarm)].

start_handler(Swarm) ->
  libp2p_swarm:add_stream_handler(Swarm, "eqc", {?MODULE, serve_stream, [self()]}).

%% ServerRef is symbolic here, don't match on it!
start_handler_next(S, _Value, [Swarm]) ->
  S#state{server_swarm = Swarm}.

start_handler_post(_S, [_Swarm], Res) ->
  eq(Res,ok).

%% operation: make one swarm the client

start_client_pre(S) ->
  length(S#state.swarm) >= 2 andalso S#state.client == undefined andalso S#state.server_swarm =/= undefined.

start_client_args(S) ->
  Swarm = S#state.server_swarm,
  [Swarm, elements(S#state.swarm -- [Swarm])].

%% For shrinking we need to double check that server is on the same swarm
start_client_pre(S, [ServerSwarm, ClientSwarm]) ->
  S#state.server_swarm == ServerSwarm.
 
start_client(ServerSwarm, ClientSwarm) ->
  [S2Addr] = libp2p_swarm:listen_addrs(ServerSwarm),
  {ok, StreamClient} = libp2p_swarm:dial(ClientSwarm, S2Addr, "eqc"),
  StreamClient.

start_client_next(S, Value, [_, ClientSwarm]) ->
  S#state{client = Value,
          client_swarm = ClientSwarm}.



%% opertion: close connection to a client

close_client_pre(S) ->
  S#state.client =/= undefined.

%% close_client_args(S) ->
%%   [S#state.client].

close_client(Client) ->
  libp2p_connection:close(Client).

close_client_next(S, _Value, _Args) ->
  S#state{client = undefined}.

close_client_post(_S, [_Client], Res) ->
  eq(Res, ok).

close_client_features(S, [_Client], _Res) ->
  [closed_in_progress || byte_size(S#state.to_send) > 0 ] ++
    [closed || byte_size(S#state.to_send) == 0 ].

%% opertion: verify that the server has been started
%% only needed to obtain the server pid.

server_started_pre(S) ->
  S#state.client =/= undefined andalso S#state.server == undefined.

server_started_args(_) ->
  [].

server_started() ->
  receive
    {hello, Server} ->
      erlang:monitor(process, Server),
      Server
  after 2000 ->
      error_starting_server
  end.

server_started_next(S, Value, []) ->
  S#state{server = Value}.

server_started_post(_S, [], Res) ->
  is_pid(Res).




%% operation: Sending a part of a packet

send_pre(S) ->
    S#state.client =/= undefined andalso S#state.server =/= undefined 
    andalso size(S#state.to_send) > 0.

send_args(S) ->
    [?SUCHTHAT(Size, eqc_gen:oneof([eqc_gen:int(), eqc_gen:largeint()]), Size > 0),
    S].

send(Size0, S) ->
    Size = min(byte_size(S#state.packet), Size0),
    <<Data:Size/binary, Rest/binary>> = S#state.packet,
    {catch libp2p_connection:send(S#state.client, Data, 100), Rest}.

send_post(S, [Size0, _], {Result, _}) ->
    Size = min(byte_size(S#state.packet), Size0),
    case Size + S#state.inflight > ?DEFAULT_MAX_WINDOW_SIZE of
        true ->
            case Result of
                {error, timeout} -> true;
                _ -> expected_timeout
            end;
        false ->
            eqc_statem:eq(Result, ok)
    end.

send_next(S, _Result, [Size, _]) ->
    S#state{inflight={call, ?MODULE, send_update_inflight, [Size, S#state.inflight, S#state.packet]},
            packet={call, ?MODULE, send_update_packet, [Size, S#state.inflight, S#state.packet]}}.

send_update_inflight(Size0, Inflight, Packet) ->
    Size = min(Size0, byte_size(Packet)),
    case Size + Inflight > ?DEFAULT_MAX_WINDOW_SIZE of
        true -> ?DEFAULT_MAX_WINDOW_SIZE;
        false -> Inflight + Size
    end.

send_update_packet(Size0, Inflight, Packet) ->
    Size = min(Size0, byte_size(Packet)),
    case Size + Inflight > ?DEFAULT_MAX_WINDOW_SIZE of
        true ->
            Start = min(byte_size(Packet), ?DEFAULT_MAX_WINDOW_SIZE - Inflight),
            Length = byte_size(Packet) - Start;
        false ->
            Start = min(byte_size(Packet), Size),
            Length = byte_size(Packet) - Start
    end,
    binary:part(Packet, Start, Length).


%% operation: Receiving part of a packet

recv_pre(S) ->
  S#state.client =/= undefined andalso S#state.server =/= undefined.

recv_args(S) ->
    [?SUCHTHAT(Size, eqc_gen:oneof([eqc_gen:int(), eqc_gen:largeint()]), Size > 0),
     S#state.server].

recv(Size, Server) ->
    Server ! {recv, Size},
    receive
        {recv, Size, Result} -> Result;
        {'DOWN', _, _, Server, Error} -> {'DOWN', Error}
    end.

recv_post(S, [Size, _], Result) ->
    case Result of 
      {error, closed} -> false andalso Size > byte_size(S#state.sent);
      {error, timeout} -> Size > byte_size(S#state.sent);
      {ok, _} -> Size =< byte_size(S#state.sent);
      Other -> Other
    end.

recv_next(S, _Result, [Size, _]) ->
    S#state{inflight={call, ?MODULE, recv_update_inflight, [Size, S#state.inflight]}}.

recv_update_inflight(Size, Inflight) ->
    case Size > Inflight of
        true -> Inflight;
        false -> Inflight - Size
    end.

%% Observe process killed during test
invariant(S) ->
  conj([tag(server_died, S#state.server == undefined orelse erlang:is_process_alive(S#state.server))]).



prop_correct() ->
    eqc:dont_print_counterexample(
     ?SETUP(
        fun() ->
            application:ensure_all_started(ranch),
            fun() -> ok end
        end,
        ?FORALL(Cmds, commands(?MODULE),
                begin
                  lager_common_test_backend:bounce(error),  %% should write own handler in similar fashion
                  Processes = erlang:processes(),

                  {H, S, Res} = run_commands(Cmds),
                  ServerDied = is_pid(S#state.server) andalso not erlang:is_process_alive(S#state.server),
                  Close = [ catch libp2p_connection:close(S#state.client) || S#state.client =/= undefined ],
                  Stop = [ catch libp2p_swarm:stop(Swarm) || Swarm <- S#state.swarm ],

                  %% Stopping the swarm will not stop the handler. BUG??
                  [ catch (S#state.server ! stop) || S#state.server =/= undefined ],
                  flush([]),

                  %% Specify when we expect to be able to restart in clean state
                  Zombies = wait_for_stop(2500, Processes),
                  Log = lager_common_test_backend:get_logs(),
                 
                  pretty_commands(?MODULE, Cmds, {H, S, Res},
                                  aggregate(command_names(Cmds),
                                  aggregate(call_features(H),
                                            ?WHENFAIL(
                                               begin
                                                 eqc:format("packet size: ~p~n", [byte_size(S#state.packet)]),
                                                 eqc:format("state ~p~n", [S#state{packet= <<>>}])
                                               end,
                                               conjunction([{process_leak, equals([{Proc, erlang:process_info(Proc, current_function)} || Proc <- Zombies], [])},
                                                            {server, not ServerDied},
                                                            {log_not_empty, lager_log_empty(Log)},
                                                            {result, eqc:equals(Res, ok)}])))))
                end))).

lager_log_empty(Log) ->
  ?WHENFAIL(eqc:format("~s", [Log]), Log == []).
    
%% poll processes N times to see if we are ready cleaning up
wait_for_stop(N, Processes) ->
  Poll = 100,
  timer:sleep(Poll),
  Zombies = erlang:processes() -- Processes,
  %% io:format("procs: "), 
  %%   [  io:format("~p ", [Pid]) || Pid <- Zombies ],
  %% io:format("\n"),

  %% swarm handler is not always identified (server_started may not be called in sequence).
  [ Pid ! stop || Pid <- Zombies, 
                  erlang:process_info(Pid, current_function) == {current_function, {?MODULE, serve_loop, 2}}],
  case Zombies == [] orelse N =< 0 of
    true -> Zombies;
    false -> wait_for_stop(N - Poll, Processes)
  end.

flush(Msgs) ->
  receive
    X -> flush([X | Msgs ])
  after 0 ->
      lists:reverse(Msgs)
  end.
      
