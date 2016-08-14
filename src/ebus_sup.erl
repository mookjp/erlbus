%%%-------------------------------------------------------------------
%%% @doc
%%% Starts main supervisor.
%%% @end
%%%-------------------------------------------------------------------
-module(ebus_sup).

%% API
-export([start_link/0]).

%%%===================================================================
%%% API functions
%%%===================================================================

-spec start_link() -> supervisor:startlink_ret().
start_link() ->
  %% ebusのpubsubパラメータを読み込む。デフォルト値は[]
  PubSub = application:get_env(ebus, pubsub, []),
  %% PubSubリストから、nameキーの値を取得する
  %% デフォルト値（PubSubが[]だった場合も）はebus:default_ps_server()で`ebus_ps`を返す
  Name = ebus_common:keyfind(name, PubSub, ebus:default_ps_server()),
  %% 上記と同様。デフォルトはebus_ps_pg2
  Adapter = ebus_common:keyfind(adapter, PubSub, ebus_ps_pg2),
  %% デフォルトの場合はebus_ps_pg2をsupervisorとして、childrenをebus_ps、オプション[]を渡して起動
  Adapter:start_link(Name, PubSub).
