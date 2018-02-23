%% Modification of lager_common_test_backend
%% Assumes lager to be running already and adds this event handler 
%% dynamically using bounce/1. The command bounce clears the log when
%% already running,
%%
%% Typically lager_eqc_backend:bounce(error) is used at the beginning of
%% each test. 


-module(lager_eqc_backend).

-behavior(gen_event).

%% gen_event callbacks
-export([init/1,
         handle_call/2,
         handle_event/2,
         handle_info/2,
         terminate/2,
         code_change/3]).
-export([get_logs/0,
         reset/0,
         bounce/0,
         bounce/1]).

%% holds the log messages for retreival on terminate
-record(state, {level :: {mask, integer()},
                formatter :: atom(),
                format_config :: any(),
                log = [] :: list()}).

-include_lib("lager/include/lager.hrl").
-define(TERSE_FORMAT,[time, " ", color, "[", severity,"] ", message]).

%% @doc Before every test, just
%% lager_eqc_backend:bounce(Level) with the log level of your
%% choice. You can now call
%% lager_eqc_backend:get_logs/0 to get a list of all log
%% messages this backend has received during your test. You can then
%% search that list for expected log messages.


-spec get_logs() -> [iolist()] | {error, term()}.
get_logs() ->
    gen_event:call(lager_event, ?MODULE, get_logs).

bounce() ->
    bounce([{level, error}]).

bounce(Config) when is_list(Config) ->
    case lists:member(?MODULE, gen_event:which_handlers(lager_event)) of
        true ->
            reset();
        false ->
            gen_event:add_handler(lager_event, ?MODULE, Config)
    end.

reset() ->
    gen_event:call(lager_event, ?MODULE, reset).

-spec(init([{atom(), term()}]) -> {ok, #state{}} | {error, atom()}).
%% @private
%% @doc Initializes the event handler
init(Config) -> 
  Level = proplists:get_value(Config, level, error),
  {Formatter,FormatterConfig} = 
    proplists:get_value(Config, formatter, 
                        {lager_default_formatter, ?TERSE_FORMAT ++ ["\n"]}),
    case lists:member(Level, ?LEVELS) andalso is_atom(Formatter) of
        true ->
            {ok, #state{level=lager_util:config_to_mask(Level),
                    formatter=Formatter,
                    format_config=FormatterConfig}};
        _ ->
            {error, bad_config}
    end.

-spec(handle_event(tuple(), #state{}) -> {ok, #state{}}).
%% @private
handle_event({log, Message},
    #state{level=L,formatter=Formatter,format_config=FormatConfig,log=Logs} = State) ->
    case lager_util:is_loggable(Message,L,?MODULE) of
        true ->
            Log = Formatter:format(Message,FormatConfig),
            {ok, State#state{log=[Log|Logs]}};
        false ->
            {ok, State}
    end;
handle_event(Event, State) ->
    {ok, State#state{log = [Event|State#state.log]}}.

-spec(handle_call(any(), #state{}) -> {ok, any(), #state{}}).
%% @private
%% @doc gets and sets loglevel. This is part of the lager backend api.
handle_call(get_loglevel, #state{level=Level} = State) ->
    {ok, Level, State};
handle_call({set_loglevel, Level}, State) ->
    case lists:member(Level, ?LEVELS) of
        true ->
            {ok, ok, State#state{level=lager_util:config_to_mask(Level)}};
        _ ->
            {ok, {error, bad_log_level}, State}
    end;
handle_call(get_logs, #state{log = Logs} = State) ->
    {ok, lists:reverse(Logs), State};
handle_call(reset, State) ->
    {ok, ok, State#state{log = []}};
handle_call(_, State) ->
    {ok, ok, State}.

-spec(handle_info(any(), #state{}) -> {ok, #state{}}).
%% @private
%% @doc gen_event callback, does nothing.
handle_info(_, State) ->
    {ok, State}.

-spec(code_change(any(), #state{}, any()) -> {ok, #state{}}).
%% @private
%% @doc gen_event callback, does nothing.
code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

-spec(terminate(any(), #state{}) -> {ok, list()}).
%% @doc gen_event callback, does nothing.
terminate(_Reason, #state{log=Logs}) ->
    {ok, lists:reverse(Logs)}.


