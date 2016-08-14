%%%-------------------------------------------------------------------
%%% @doc
%%% This is an Erlang clone of the original `Phoenix.PubSub.PG2'
%%% module.
%%% Copyright (c) 2014 Chris McCord
%%%
%%% Phoenix PubSub adapter based on PG2.
%%% To use it as your PubSub adapter, simply add it to your
%%% Endpoint's config file (see e.g.: test/test.config):
%%%
%%% ```
%%% [
%%%  {ebus,
%%%   [
%%%    {pubsub,
%%%     [
%%%      {adapter, ebus_ps_pg2},
%%%      {pool_size, 5},
%%%      {name, ebus_ps_test}
%%%     ]
%%%    }
%%%   ]
%%%  }
%%% ].
%%% '''
%%%
%%% Options:
%%% <ul>
%%% <li>`name': The name to register the PubSub processes,
%%% ie: `ebus_ps'.</li>
%%% <li>`pool_size': Both the size of the local pubsub server pool and
%%% subscriber shard size. Defaults `1'. A single pool is often enough
%%% for most use cases, but for high subscriber counts on a single
%%% topic or greater than 1M clients, a pool size equal to the number
%%% of schedulers (cores) is a well rounded size.</li>
%%% </ul>
%%%
%%% @reference See
%%% <a href="https://github.com/phoenixframework/phoenix">Phoenix</a>
%%% @end
%%%-------------------------------------------------------------------
-module(ebus_ps_pg2).

-behaviour(supervisor).

%% API
-export([start_link/2]).

%% Supervisor callbacks
-export([init/1]).

%%%===================================================================
%%% API functions
%%%===================================================================

-spec start_link(atom(), [term()]) -> supervisor:startlink_ret().
start_link(Name, Opts) ->
  %% `ebus_common:build_name(List, Separator)`はリストをSeparatorで区切って
  %% atomとして返す
  %% Nameがebus_psなのでsup_ebus_psというatomが返る
  SupName = ebus_common:build_name([Name, <<"sup">>], <<"_">>),
  %% start_link(SupName, Mdule, Args)
  %% ArgsはModuleの`init/1`に渡すパラメータ
  %% この場合はsup_ebus_psがSupName, Nameがebus_ps
  supervisor:start_link({local, SupName}, ?MODULE, [Name, Opts]).

%%%===================================================================
%%% Supervisor callbacks
%%%===================================================================

%% @hidden
init([Server, Opts]) ->
  PoolSize = ebus_common:keyfind(pool_size, Opts, 1),
  DispatchRules = [{broadcast, ebus_ps_pg2_server, [Server, PoolSize]}],

  Children = [
    %% supervisor用のspecを返すutil
    %% ebus_ps_local_supはebus_psを子プロセスとして起動
    ebus_supervisor_spec:supervisor(
      ebus_ps_local_sup, [Server, PoolSize, DispatchRules]
    ),
    %% worker用のspecを返すutil
    %% ebus_ps_pg2_serverを起動
    ebus_supervisor_spec:worker(ebus_ps_pg2_server, [Server])
  ],

  %% strategyを作成
  ebus_supervisor_spec:supervise(Children, #{strategy => rest_for_one}).
