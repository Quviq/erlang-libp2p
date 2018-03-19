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
          received = <<>>,
          inflight=0  %% remove
         }).

%% This is a test model, export all functions to avoid problems when one is overlooked. 
-compile([export_all, nowarn_export_all]).
-import(eqc_statem, [tag/2]).

initial_state() ->
    #state{}.



serve_stream(Connection, _Path, _TID, [Parent]) ->
    Parent ! {hello, self(), Connection},
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
  [elements([denver, los_angeles, stockholm, goteborg])].

start_swarm(Name) ->
  {ok, Pid} = libp2p_swarm:start(Name, 0),
  %% Check the type, but only use the Pid in model
  Pid.

start_swarm_next(S, Value, [_]) ->
  S#state{swarm = S#state.swarm ++ [Value]}.  %% add at tail for better shrinking

start_swarm_post(_S, [_], Res) ->
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
start_client_pre(S, [ServerSwarm, _ClientSwarm]) ->
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
  S#state.client =/= undefined andalso 
    S#state.server =/= undefined.  
    %% The model should have started monitoring the server process

close_client_args(S) ->
  [S#state.client, S#state.server].

close_client(Client, Server) ->
  Server ! stop,
  libp2p_connection:close(Client).

close_client_next(S, _Value, [_Client, _Server]) ->
  S#state{client = undefined, server = undefined, sent = <<>>, packet = <<>>}.

close_client_post(_S, [_Client, _Server], Res) ->
  eq(Res, ok).

close_client_features(S, [_Client, _Server], _Res) ->
  [closed_in_progress || byte_size(S#state.packet) > 0 ] ++
    [closed || byte_size(S#state.packet) == 0 ].

%% opertion: verify that the server has been started
%% only needed to obtain the server pid.

server_started_pre(S) ->
  S#state.client =/= undefined andalso S#state.server == undefined.

server_started_args(_) ->
  [].

server_started() ->
  receive
    {hello, Server, _Client} ->
      erlang:monitor(process, Server),
      Server
  after 2000 ->
      error_starting_server
  end.

server_started_next(S, Value, []) ->
  S#state{server = Value}.

server_started_post(_S, [], Res) ->
  is_pid(Res).


%% operation: Prepare a packet

packet_pre(S) ->
  S#state.packet == <<>>.

packet_args(_S) ->
  [?LET(Size, choose(1, 10 %%?DEFAULT_MAX_WINDOW_SIZE*3
                    ), noshrink(binary(Size)))].

packet(_) ->
  ok.

packet_next(S, _, [Bin]) ->
  S#state{packet = Bin}.

%% operation: Sending a part of a packet

send_pre(S) ->
    S#state.client =/= undefined andalso S#state.server =/= undefined
      andalso byte_size(S#state.packet) > 0.

send_args(S) ->  
  ?LET(Size, choose(1, byte_size(S#state.packet)), 
       begin
         <<Data:Size/binary, _Rest/binary>> = S#state.packet,
         [S#state.client, Size, Data]
       end).

send_pre(S, [Client, Size, Data]) ->
  %% for shrinking
  case S#state.packet of
    <<Data:Size/binary, _/binary>> -> S#state.client == Client;
    _ -> false
  end.

%% If size shrinks, we need to adapt the prefix
send_adapt(S, [_Client, Size, _]) ->
  case S#state.packet of
    <<Data:Size/binary, _/binary>> -> [S#state.client, Size, Data];
    _ -> false
  end.

send(Client, _Size, Data) ->
  libp2p_connection:send(Client, Data, 100).

send_next(S, _Result, [_, Size, Data]) ->
    <<_:Size/binary, Rest/binary>> = S#state.packet,
    S#state{sent = <<(S#state.sent)/binary, Data/binary>>,
            packet = Rest}.


send_post(S, [_, Size, _], Result) ->
    case Size + byte_size(S#state.sent) > ?DEFAULT_MAX_WINDOW_SIZE of
        true ->
            case Result of
                {error, timeout} -> tru;
                _ -> expected_timeout
            end;
        false ->
            eqc_statem:eq(Result, ok)
    end.

send_features(_S, [_Client, Size, _Data], Res) ->
  [ {sent, Size} || Res == ok ] ++
   [ {try_sent, Size, Res} || Res =/= ok ].



%% operation: Receiving part of a packet

recv_pre(S) ->
  S#state.client =/= undefined andalso S#state.server =/= undefined.

recv_args(S) ->
    [choose(1, byte_size(S#state.sent)+5),
     S#state.server].

recv_pre(S, [_, Server]) ->
  %% Shrink away recv when server stopped
  S#state.server == Server.

recv(Size, Server) ->
    Server ! {recv, Size},
    receive
        {recv, Size, Result} -> Result;
        {'DOWN', _, _, Server, Error} -> {'DOWN', Error}
    end.

recv_post(S, [Size, _], Result) ->
    case Result of 
      %% {error, closed} -> Size > byte_size(S#state.sent);
      {error, timeout} -> Size > byte_size(S#state.sent);
      {ok, Data} ->
        <<Pre:Size/binary, _/binary>> = S#state.sent,
        Size =< byte_size(S#state.sent) andalso Pre == Data;
      Other -> Other
    end.

recv_next(S, _Result, [Size, _]) ->
    case S#state.sent of
      <<_:Size/binary, Rest/binary>> ->
        S#state{sent = Rest};
      _ ->
        S
    end.

recv_features(_S, [Size, _], {ok, _}) ->
  [ {recv, Size, ok} ];
recv_features(_S, [Size, _], Error) ->
  [ {recv, Size, Error} ].



%% Observe process killed during test
invariant(S) ->
  conj([tag(server_died, S#state.server == undefined orelse erlang:is_process_alive(S#state.server))]).

%% Increase the probability to have something in flight.
weight(_S, send) -> 30;
weight(_S, recv) -> 8;
weight(_S, client_close) -> 1;
weight(_, _) -> 5. 


prop_correct() ->
  prop_correct([]).

prop_correct(Flags) ->
    eqc:dont_print_counterexample(
     ?SETUP(
        fun() ->
            application:ensure_all_started(ranch),
            application:ensure_all_started(lager),
            %% both are guaranteed by rebar.config
            %% {shell, [{apps, [lager, ranch]}]}.
            Level = lager:get_loglevel(lager_console_backend),
            case lists:member(verbose, Flags) of
              true -> lager:set_loglevel(lager_console_backend, debug);
              false -> lager:set_loglevel(lager_console_backend, error)
            end,
            fun() -> lager:set_loglevel(lager_console_backend, Level) end
        end,
        ?FORALL(Cmds, commands(?MODULE),
        ?SOMETIMES(2,
                begin
                  os:cmd("rm -r data/*"), %% Remove all swarm related files
                  lager_eqc_backend:bounce([{level, error}]),
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
                  Log = lager_eqc_backend:get_logs(),
                  
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
                                                            {cleanup, equals(lists:usort(Close ++ Stop) -- [ok], [])},
                                                            {log_not_empty, not lists:member(log_empty, Flags) orelse lager_log_empty(Log)},
                                                            {result, eqc:equals(Res, ok)}])))))
                end)))).

lager_log_empty(Log) ->
  ?WHENFAIL(eqc:format("~s", [Log]), Log == []).
    
%% poll processes N times to see if we are ready cleaning up
wait_for_stop(N, Processes) ->
  Poll = 100,
  timer:sleep(Poll),
  Zombies = erlang:processes() -- Processes,

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
      
