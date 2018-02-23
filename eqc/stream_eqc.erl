-module(stream_eqc).

-include_lib("eqc/include/eqc.hrl").
-include_lib("eqc/include/eqc_statem.hrl").

-include("src/libp2p_yamux.hrl").

-record(state, {
          swarm = [],
          client,
          server,
          packet,
          inflight=0
         }).

%% This is a test model, export all functions to avoid problems when one is overlooked. 
-compile([export_all, nowarn_export_all]).

initial_state() ->
    #state{packet={var, packet}}.

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
            libp2p_connection:close(Connection),
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


%% operation: make one swarm the client

start_client_pre(S) ->
  length(S#state.swarm) == 2 andalso S#state.client == undefined.

start_client_args(S) ->
  [shuffle(S#state.swarm)].
 
start_client([Swarm1, Swarm2]) ->
  ok = libp2p_swarm:add_stream_handler(Swarm2, "eqc", {?MODULE, serve_stream, [self()]}),
  
  [S2Addr] = libp2p_swarm:listen_addrs(Swarm2),
  {ok, StreamClient} = libp2p_swarm:dial(Swarm1, S2Addr, "eqc"),  
  StreamClient.

start_client_next(S, Value, [_]) ->
  S#state{client = Value}.

%% opertion: make the other swarm server

sync_start_pre(S) ->
  length(S#state.swarm) == 2 andalso S#state.client =/= undefined andalso
    S#state.server == undefined.

sync_start_args(_S) ->
  [].

sync_start() ->
  receive
    {hello, Server} -> 
      erlang:monitor(process, Server),
      Server
  after 300 ->
      exit(error_sync)
  end.

sync_start_next(S, Value, []) ->
  S#state{server = Value}.

send_pre(S) ->
    S#state.client =/= undefined andalso S#state.server =/= undefined.

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


recv_pre(S) ->
  S#state.client =/= undefined andalso S#state.server =/= undefined.

recv_args(S) ->
    [?SUCHTHAT(Size, eqc_gen:oneof([eqc_gen:int(), eqc_gen:largeint()]), Size > 0),
     S#state.server].

recv(Size, Server) ->
    Server ! {recv, Size},
    receive
        {recv, Size, Result} -> Result;
        {'DOWN', _, _, Server, Error} -> Error
    end.

recv_post(S, [Size, _], Result) ->
    case Size > S#state.inflight of
        true -> eqc_statem:eq(Result, {error, timeout});
        false -> eqc_statem:eq(element(1, Result), ok)
    end.

recv_next(S, _Result, [Size, _]) ->
    S#state{inflight={call, ?MODULE, recv_update_inflight, [Size, S#state.inflight]}}.

recv_update_inflight(Size, Inflight) ->
    case Size > Inflight of
        true -> Inflight;
        false -> Inflight - Size
    end.

prop_correct() ->
  prop_correct(silent).

check() ->
  eqc:check(prop_correct(verbose)).

prop_correct(Mode) ->
    eqc:dont_print_counterexample(
     ?SETUP(
        fun() ->
            application:ensure_all_started(ranch),
            application:ensure_all_started(lager),
            case Mode of
              verbose -> lager:set_loglevel(lager_console_backend, debug);
              _ -> ok
            end,
            fun() -> lager:set_loglevel(lager_console_backend, error) end
        end,
        ?FORALL({Packet, Cmds},
                {eqc_gen:largebinary(500000), commands(?MODULE)},
                begin

                  {H, S, Res} = run_commands(?MODULE, Cmds, [{packet, Packet}]),
                  ServerDied = S#state.server =/= undefined andalso not erlang:is_process_alive(S#state.server),
                  [ catch libp2p_connection:close(S#state.client) || S#state.client =/= undefined ],
                  [ catch libp2p_swarm:stop(Swarm) || Swarm <- S#state.swarm ],
                  pretty_commands(?MODULE, Cmds, {H, S, Res},
                                  aggregate(command_names(Cmds),
                                            ?WHENFAIL(
                                               begin
                                                 eqc:format("packet size: ~p~n", [byte_size(S#state.packet)]),
                                                 eqc:format("state ~p~n", [S#state{packet= <<>>}])
                                               end,
                                               conjunction([{server, not ServerDied},
                                                            {result, eqc:equals(Res, ok)}]))))
                end))).


