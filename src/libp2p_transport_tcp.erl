-module(libp2p_transport_tcp).

-behaviour(libp2p_connection).
-behavior(gen_server).


-export([start_listener/2, new_connection/1, connect/4, match_addr/1, discover/3]).

% gen_server
-export([start_link/1, init/1, handle_call/3, handle_info/2, handle_cast/2, terminate/2]).

% libp2p_onnection
-export([send/3, recv/3, acknowledge/2, addr_info/1,
         close/1, close_state/1, controlling_process/2,
         fdset/1, fdclr/1
        ]).

-record(tcp_state, {
          socket :: gen_tcp:socket(),
          transport :: atom()
         }).

-type tcp_state() :: #tcp_state{}.

-record(state, {
          tid :: ets:tab()
         }).


-define(CONFIG_SECTION, tcp).

%%
%% API
%%

-spec new_connection(inet:socket()) -> libp2p_connection:connection().
new_connection(Socket) ->
    libp2p_connection:new(?MODULE, #tcp_state{socket=Socket, transport=ranch_tcp}).

-spec start_listener(pid(), string()) -> {ok, [string()], pid()} | {error, term()}.
start_listener(Pid, Addr) ->
    gen_server:call(Pid, {start_listener, Addr}).

-spec connect(pid(), string(), [libp2p_swarm:connect_opt()], pos_integer()) -> {ok, libp2p_session:pid()} | {error, term()}.
connect(Pid, MAddr, Options, Timeout) ->
    gen_server:call(Pid, {connect, MAddr, Options, Timeout}, infinity).


-spec match_addr(string()) -> {ok, string()} | false.
match_addr(Addr) when is_list(Addr) ->
    match_protocols(multiaddr:protocols(multiaddr:new(Addr))).

match_protocols([A={_, _}, B={"tcp", _} | _]) ->
    {ok, multiaddr:to_string([A, B])};
match_protocols(_) ->
    false.

%%
%% gen_server
%%

start_link(TID) ->
    gen_server:start_link(?MODULE, [TID], []).

init([TID]) ->
    erlang:process_flag(trap_exit, true),

    Swarm = libp2p_swarm:swarm(TID),
    libp2p_swarm:add_stream_handler(Swarm, "stungun/1.0.0",
                                    {libp2p_stream_stungun, server, []}),
    {ok, #state{tid=TID}}.


handle_call({start_listener, Addr}, _From, State=#state{tid=TID}) ->
    {reply, listen_on(Addr, TID), State};
handle_call({connect, MAddr, DialOptions, Timeout}, _From, State=#state{tid=TID}) ->
    {reply, connect_to(MAddr, DialOptions, Timeout, TID), State};
handle_call(Msg, _From, State) ->
    lager:warning("Unhandled call: ~p~n", [Msg]),
    {reply, ok, State}.


handle_cast(Msg, State) ->
    lager:warning("Unhandled cast: ~p~n", [Msg]),
    {noreply, State}.

handle_info(Msg, _State) ->
    lager:warning("Unhandled message ~p", [Msg]).

terminate(_Reason, #state{}) ->
    ok.

-spec listen_on(string(), ets:tab()) -> {ok, [string()], pid()} | {error, term()}.
listen_on(Addr, TID) ->
    Sup = libp2p_swarm_listener_sup:sup(TID),
    case tcp_addr(Addr) of
        {IP, Port, Type} ->
            OptionDefaults = [
                              % Listen options
                              {ip, IP},
                              {backlog, 1024},
                              {nodelay, true},
                              {send_timeout, 30000},
                              {send_timeout_close, true},

                              % Transport options. Add new transport
                              % default options to TransportKeys below
                              {max_connections, 1024}
                             ],
            TransportKeys = sets:from_list([max_connections]),
            Options = libp2p_config:get_config(?CONFIG_SECTION, OptionDefaults),
            {TransportOpts, ListenOpts0} =
                lists:partition(fun({Key, _}) ->
                                        sets:is_element(Key, TransportKeys)
                                end, Options),
            % Non-overidable options, taken from ranch_tcp:listen
            DefaultListenOpts = [binary, {active, false}, {packet, raw}, {reuseaddr, true}, reuseport()],
            % filter out disallowed options and supply default ones
            ListenOpts = ranch:filter_options(ListenOpts0, ranch_tcp:disallowed_listen_options(),
                                              DefaultListenOpts),
            % Dialyzer severely dislikes ranch_tcp:listen so we
            % emulate it's behavior here
            case gen_tcp:listen(Port, [Type | ListenOpts]) of
                {ok, Socket} ->
                    ListenAddrs = tcp_listen_addrs(Socket),
                    ChildSpec = ranch:child_spec(ListenAddrs,
                                                 ranch_tcp, [{socket, Socket} | TransportOpts],
                                                 libp2p_transport_ranch_protocol, {?MODULE, TID}),
                    case supervisor:start_child(Sup, ChildSpec) of
                        {ok, Pid} ->
                            ok = gen_tcp:controlling_process(Socket, Pid),
                            Parent = self(),
                            %% kickoff some background NAT mapping discovery...
                            spawn(fun() -> try_nat_upnp(Parent, ListenAddrs) end),
                            spawn(fun() -> try_nat_pmp(Parent, ListenAddrs) end),
                            {ok, ListenAddrs, Pid};
                        {error, Reason} -> {error, Reason}
                    end;
                {error, Reason} -> {error, Reason}
            end;
        {error, Error} -> {error, Error}
    end.


-spec connect_to(string(), [libp2p_swarm:connect_opt()], pos_integer(), ets:tab())
                -> {ok, libp2p_session:pid()} | {error, term()}.
connect_to(Addr, UserOptions, Timeout, TID) ->
    case tcp_addr(Addr) of
        {IP, Port, Type} ->
            UniqueSession = proplists:get_value(unique_session, UserOptions, false),
            UniquePort = proplists:get_value(unique_port, UserOptions, false),
            ListenAddrs = libp2p_config:listen_addrs(TID),
            Options = connect_options(Type, Addr, ListenAddrs, UniqueSession, UniquePort),
            case ranch_tcp:connect(IP, Port, Options, Timeout) of
                {ok, Socket} ->
                    libp2p_transport:start_client_session(TID, Addr, new_connection(Socket));
                {error, Error} ->
                    {error, Error}
            end;
        {error, Reason} -> {error, Reason}
    end.


connect_options(Type, _, _, UniqueSession, _UniquePort) when UniqueSession == true ->
    [Type];
connect_options(Type, _, _, false, _UniquePort) when Type /= inet ->
    [Type];
connect_options(Type, _, _, false, UniquePort) when UniquePort == true ->
    [Type, {reuseaddr, true}];
connect_options(Type, Addr, ListenAddrs, false, false) ->
    MAddr = multiaddr:new(Addr),
    [Type, {reuseaddr, true}, reuseport(), {port, find_matching_listen_port(MAddr, ListenAddrs)}].

find_matching_listen_port(_Addr, []) ->
    0;
find_matching_listen_port(Addr, [H|ListenAddrs]) ->
    TheirAddr = multiaddr:new(H),
    MyProtocols = [ element(1, T) || T <- multiaddr:protocols(Addr)],
    TheirProtocols = [ element(1, T) || T <- multiaddr:protocols(TheirAddr)],
    case MyProtocols == TheirProtocols of
        true ->
            %% TODO we assume the port is the second element of the second tuple, this is not safe
            list_to_integer(element(2, lists:nth(2, multiaddr:protocols(TheirAddr))));
        false ->
            find_matching_listen_port(Addr, ListenAddrs)
    end.


discover(Swarm, Parent, PeerAddr) ->
    %% try to discover our external IP in the background using the identify service...
    case libp2p_identify:identify(Swarm, PeerAddr) of
        {ok, Identify} ->
            libp2p_swarm_server:record_observed_address(Parent, PeerAddr, multiaddr:to_string(libp2p_identify:observed_addr(Identify)));
        {error, Reason} ->
            {error, Reason}
    end.

tcp_listen_addrs(Socket) ->
    {ok, SockAddr={IP, Port}} = inet:sockname(Socket),
    case lists:all(fun(D) -> D == 0 end, tuple_to_list(IP)) of
        false ->
            [multiaddr(SockAddr)];
        true ->
            % all 0 address, collect all non loopback interface addresses
            {ok, IFAddrs} = inet:getifaddrs(),
            [multiaddr({Addr, Port}) ||
             {_, Opts} <- IFAddrs, {addr, Addr} <- Opts, {flags, Flags} <- Opts,
             size(Addr) == size(IP),
             not lists:member(loopback, Flags),
             %% filter out ipv6 link-local addresses
             not (size(Addr) == 8 andalso element(1, Addr) == 16#fe80)
            ]
    end.


-spec tcp_addr(string()) -> {inet:ip_address(), non_neg_integer(), inet | inet6} | {error, term()}.
tcp_addr(MAddr) when is_list(MAddr) ->
    tcp_addr(MAddr, multiaddr:protocols(multiaddr:new(MAddr))).

tcp_addr(Addr, [{AddrType, Address}, {"tcp", PortStr}]) ->
    Port = list_to_integer(PortStr),
    case AddrType of
        "ip4" ->
            {ok, IP} = inet:parse_ipv4_address(Address),
            {IP, Port, inet};
        "ip6" ->
            {ok, IP} = inet:parse_ipv6_address(Address),
            {IP, Port, inet6};
        _ -> {error, {unsupported_address, Addr}}
    end;
tcp_addr(Addr, _Protocols) ->
    {error, {unsupported_address, Addr}}.


multiaddr({IP, Port}) when is_tuple(IP) andalso is_integer(Port) ->
    Prefix  = case size(IP) of
                  4 -> "/ip4";
                  8 -> "/ip6"
              end,
    lists:flatten(io_lib:format("~s/~s/tcp/~b", [Prefix, inet:ntoa(IP), Port ])).



%%
%% libp2p_connection
%%

-spec send(tcp_state(), iodata(), non_neg_integer()) -> ok | {error, term()}.
send(#tcp_state{socket=Socket, transport=Transport}, Data, Timeout) ->
    Transport:setopts(Socket, [{send_timeout, Timeout}]),
    Transport:send(Socket, Data).

-spec recv(tcp_state(), non_neg_integer(), pos_integer()) -> {ok, binary()} | {error, term()}.
recv(#tcp_state{socket=Socket, transport=Transport}, Length, Timeout) ->
    Transport:recv(Socket, Length, Timeout).

-spec close(tcp_state()) -> ok.
close(#tcp_state{socket=Socket, transport=Transport}) ->
    Transport:close(Socket).

-spec close_state(tcp_state()) -> open | closed.
close_state(#tcp_state{socket=Socket}) ->
    case inet:peername(Socket) of
        {ok, _} -> open;
        {error, _} -> closed
    end.

-spec acknowledge(tcp_state(), reference()) -> ok.
acknowledge(#tcp_state{}, Ref) ->
    ranch:accept_ack(Ref).

-spec fdset(tcp_state()) -> ok | {error, term()}.
fdset(#tcp_state{socket=Socket}) ->
    case inet:getfd(Socket) of
        {error, Error} -> {error, Error};
        {ok, FD} -> inert:fdset(FD)
    end.

-spec fdclr(tcp_state()) -> ok.
fdclr(#tcp_state{socket=Socket}) ->
    case inet:getfd(Socket) of
        {error, Error} -> {error, Error};
        {ok, FD} -> inert:fdclr(FD)
    end.

-spec addr_info(tcp_state()) -> {string(), string()}.
addr_info(#tcp_state{socket=Socket}) ->
    {ok, LocalAddr} = inet:sockname(Socket),
    {ok, RemoteAddr} = inet:peername(Socket),
    {multiaddr(LocalAddr), multiaddr(RemoteAddr)}.


-spec controlling_process(tcp_state(), pid()) ->  ok | {error, closed | not_owner | atom()}.
controlling_process(#tcp_state{socket=Socket}, Pid) ->
    gen_tcp:controlling_process(Socket, Pid).

reuseport() ->
    %% TODO provide a more complete mapping of SOL_SOCKET and SO_REUSEPORT
    {Protocol, Option} = case os:type() of
                             {unix, linux} ->
                                 {1, 15};
                             {unix, freebsd} ->
                                 {16#ffff, 16#200};
                             {unix, darwin} ->
                                 {16#ffff, 16#200}
                         end,
    {raw, Protocol, Option, <<1:32/native>>}.


try_nat_upnp(Parent, MultiAddrs) ->
    lager:info("MultiAddrs ~p", [MultiAddrs]),
    case lists:filtermap(fun(M) -> case multiaddr:protocols(multiaddr:new(M)) of
                                       [{"ip4", Address}, {"tcp", Port}] ->
                                           {ok, Parsed} = inet_parse:address(Address),
                                           lager:info("parsed ~p", [Parsed]),
                                           case is_rfc1918(Parsed) of
                                               true ->
                                                   {true, {M, Parsed, list_to_integer(Port)}};
                                               false ->
                                                   false
                                           end;
                                       _ ->
                                           false
                                   end
                         end, MultiAddrs) of
        [] ->
            lager:info("no RFC1918 addresses"),
            ok;
        [{MA, _Address, Port}|_] ->
            %% ok we have some RFC1918 addresses, let's try to NAT uPNP one of them
            %% TODO we should make a port mapping for EACH address here, for weird multihomed machines, but nat_upnp doesn't support issuing a particular request from a particular interface yet
            case nat_upnp:discover() of
                {ok, Context} ->
                    case nat_upnp:add_port_mapping(Context, tcp, Port, Port, "erlang-libp2p", 0) of
                        ok ->
                            %% figure out the external IP
                            %% TODO we need to clean this up later.. somehow
                            {ok, ExtAddress} = nat_upnp:get_external_ip_address(Context),
                            {ok, ParsedExtAddress} = inet_parse:address(ExtAddress),
                            lager:info("added upnp port mapping from ~s to ~s", [MA, multiaddr({ParsedExtAddress, Port})]),
                            libp2p_swarm_server:add_external_listen_addr(Parent, MA, multiaddr({ParsedExtAddress, Port}));
                        _ ->
                            lager:warning("unable to add upnp mapping"),
                            ok
                    end;
                _ ->
                    lager:info("no upnp discovered"),
                    ok
            end
    end.

try_nat_pmp(Parent, MultiAddrs) ->
    lager:info("MultiAddrs ~p", [MultiAddrs]),
    case lists:filtermap(fun(M) -> case multiaddr:protocols(multiaddr:new(M)) of
                                       [{"ip4", Address}, {"tcp", Port}] ->
                                           {ok, Parsed} = inet_parse:address(Address),
                                           lager:info("parsed ~p", [Parsed]),
                                           case is_rfc1918(Parsed) of
                                               true ->
                                                   {true, {M, Parsed, list_to_integer(Port)}};
                                               false ->
                                                   false
                                           end;
                                       _ ->
                                           false
                                   end
                         end, MultiAddrs) of
        [] ->
            lager:info("no RFC1918 addresses"),
            ok;
        [{MA, _Address, Port}|_] ->
            %% ok we have some RFC1918 addresses, let's try to NAT PMP one of them
            %% TODO we should make a port mapping for EACH address here, for weird multihomed machines, but nat_upnp doesn't support issuing a particular request from a particular interface yet
            case natpmp:discover() of
                {ok, Gateway} ->
                    case natpmp:add_port_mapping(Gateway, tcp, Port, Port, 3600) of
                        {ok, _, _, _, _} ->
                            %% figure out the external IP
                            %% TODO we need to clean this up later.. somehow
                            {ok, ExtAddress} = natpmp:get_external_address(Gateway),
                            {ok, ParsedExtAddress} = inet_parse:address(ExtAddress),
                            lager:info("added PMP port mapping from ~s to ~s", [MA, multiaddr({ParsedExtAddress, Port})]),
                            libp2p_swarm_server:add_external_listen_addr(Parent, MA, multiaddr({ParsedExtAddress, Port}));
                        _ ->
                            lager:warning("unable to add PMP mapping"),
                            ok
                    end;
                _ ->
                    lager:info("no PMP discovered"),
                    ok
            end
    end.

%% @doc Get the subnet mask as an integer, stolen from an old post on
%%      erlang-questions.
-spec mask_address(inet:ip_address(), pos_integer()) -> integer().
mask_address(Addr={_, _, _, _}, Maskbits) ->
    B = list_to_binary(tuple_to_list(Addr)),
    lager:debug("address as binary: ~w ~w", [B,Maskbits]),
    <<Subnet:Maskbits, _Host/bitstring>> = B,
    Subnet.
%mask_address(_, _) ->
    %% presumably ipv6, don't have a function for that one yet
    %undefined.

%% return RFC1918 mask for IP or false if not in RFC1918 range
rfc1918({10, _, _, _}) ->
    8;
rfc1918({192,168, _, _}) ->
    16;
rfc1918(IP={172, _, _, _}) ->
    %% this one is a /12, not so simple
    case mask_address({172, 16, 0, 0}, 12) == mask_address(IP, 12) of
        true ->
            12;
        false ->
            false
    end;
rfc1918(_) ->
    false.

%% true/false if IP is RFC1918
is_rfc1918(IP) ->
    case rfc1918(IP) of
        false ->
            false;
        _ ->
            true
end.
