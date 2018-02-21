-module(libp2p_peerbook).

-include_lib("bitcask/include/bitcask.hrl").

-export([start_link/1, init/1, handle_call/3, handle_info/2, handle_cast/2, terminate/2]).
-export([keys/1, put/2, put/3, get/2, is_key/2]).

-behviour(gen_server).

-record(state, {
          store :: reference()
         }).

%%
%% API
%%

-spec put(pid(), string() | binary(), [string()]) -> true.
put(Pid, ID, Addrs) ->
    gen_server:call(Pid, {put, id_to_binary(ID), Addrs}).

-spec put(pid(), string()) -> true.
put(Pid, P2PAddr) ->
    Protocols = multiaddr:protocols(multiaddr:new(P2PAddr)),
    case lists:keytake("p2p", 1, Protocols) of
        false -> error(bad_arg);
        {value, {"p2p", ID}, AddrProtos} ->
            put(Pid, id_to_binary(ID), [multiaddr:to_string(AddrProtos)])
    end.

-spec get(pid(), string() | binary()) -> [string()].
get(Pid, ID) ->
    gen_server:call(Pid, {get, id_to_binary(ID)}).

-spec is_key(pid(), string() | binary()) -> boolean().
is_key(Pid, ID) ->
    gen_server:call(Pid, {is_key, id_to_binary(ID)}).

-spec keys(pid()) -> [binary()].
keys(Pid) ->
    gen_server:call(Pid, keys).

%%
%% gen_server
%%

start_link(TID) ->
    gen_server:start_link(?MODULE, [TID], []).


init([_TID]) ->
    DataDir = libp2p_config:get_env(peerbook, data_dir, "data/peerbook"),
    case bitcask:open(DataDir, [read_write]) of
        {error, Reason} -> {error, Reason};
        Ref ->
            process_flag(trap_exit, true),
            {ok, #state{store=Ref}}
    end.


handle_call({is_key, ID}, _From, State=#state{store=Store}) ->
    Found = try
                bitcask:fold_keys(Store, fun(#bitcask_entry{key=SID}, _) when SID == ID ->
                                                 throw({ok, ID});
                                            (_, Acc) -> Acc
                                         end, false)
            catch
                throw:{ok, ID} -> true
            end,
    {reply, Found, State};
handle_call(keys, _From, State=#state{store=Store}) ->
    {reply, bitcask:list_keys(Store), State};
handle_call({get, ID}, _From, State=#state{store=Store}) ->
    Result = case bitcask:get(Store, ID) of
                 {ok, Value} -> binary_to_term(Value);
                 not_found -> [];
                 {error, _} -> []
             end,
    {reply, Result, State};
handle_call({put, ID, Addrs}, _From,State=#state{store=Store}) ->
    case bitcask:put(Store, ID, term_to_binary(Addrs)) of
        {error, Reason} -> error(Reason);
        ok ->{reply, true, State}
    end;

handle_call(Msg, _From, State) ->
    lager:warning("Unhandled call: ~p~n", [Msg]),
    {reply, ok, State}.

handle_cast(Msg, State) ->
    lager:warning("Unhandled cast: ~p~n", [Msg]),
    {noreply, State}.

handle_info(Msg, State) ->
    lager:warning("Unhandled info: ~p~n", [Msg]),
    {noreply, State}.

terminate(_Reason, #state{store=Store}) ->
    bitcask:close(Store).

%%
%% Internal
%%

-spec id_to_binary(string() | binary()) -> binary().
id_to_binary(ID) when is_binary(ID) ->
    ID;
id_to_binary(ID) when is_list(ID) ->
    libp2p_crypto:b58_to_address(ID).
