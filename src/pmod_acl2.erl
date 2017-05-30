-module(pmod_acl2).

-behaviour(gen_server).

% API
-export([start_link/1]).
-export([raw/0]).
-export([raw/1]).
-export([g/0]).
-export([g/1]).

% Callbacks
-export([init/1]).
-export([handle_call/3]).
-export([handle_cast/2]).
-export([handle_info/2]).
-export([code_change/3]).
-export([terminate/2]).

-include("pmod_acl2.hrl").

%--- Records -------------------------------------------------------------------

-record(state, {
    slot,
    mode = '2g'
}).

%--- API -----------------------------------------------------------------------

start_link(Slot) ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, Slot, []).

raw() -> raw([]).

raw(Opts) -> gen_server:call(?MODULE, {raw, Opts}).

g() -> g([]).
g(Opts) -> gen_server:call(?MODULE, {g, Opts}).

%--- Callbacks -----------------------------------------------------------------

init(Slot) ->
    Req = <<?WRITE_REGISTER, ?POWER_CTL, 0:6, ?MEASUREMENT_MODE:2>>,
    grisp_spi:send_recv(Slot, Req),
    {ok, #state{slot = Slot}}.

handle_call({raw, Opts}, _From, State) ->
    Raw = xyz(State#state.slot, Opts),
    {reply, Raw, State};
handle_call({g, Opts}, _From, State) ->
    Raw = xyz(State#state.slot, Opts),
    {reply, scale(State#state.mode, Raw), State}.

handle_cast(Request, _State) -> error({unknown_cast, Request}).

handle_info(Info, _State) -> error({unknown_info, Info}).

code_change(_OldVsn, State, _Extra) -> {ok, State}.

terminate(_Reason, _State) -> ok.

%--- Internal ------------------------------------------------------------------

xyz(Slot, []) ->
    <<X/signed, Y/signed, Z/signed>>
        = grisp_spi:send_recv(Slot, <<?READ_REGISTER, ?XDATA>>, 2, 3),
    {X * 16, Y * 16, Z * 16};
xyz(Slot, [high_precision]) ->
    <<
        XDATA_L,
        _:4, XDATA_H:4,
        YDATA_L,
        _:4, YDATA_H:4,
        ZDATA_L,
        _:4, ZDATA_H:4
    >> = grisp_spi:send_recv(Slot, <<?READ_REGISTER, ?XDATA_L>>, 2, 6),
    <<X:12/signed>> = <<XDATA_H:4, XDATA_L>>,
    <<Y:12/signed>> = <<YDATA_H:4, YDATA_L>>,
    <<Z:12/signed>> = <<ZDATA_H:4, ZDATA_L>>,
    {X, Y, Z}.

scale('2g', {X, Y, Z}) -> {X / 1000, Y / 1000, Z / 1000}.
