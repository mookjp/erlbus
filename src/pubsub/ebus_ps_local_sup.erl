%%%-------------------------------------------------------------------
%%% @doc
%%% This is an Erlang clone of the original
%%% `Phoenix.PubSub.LocalSupervisor' module.
%%% Copyright (c) 2014 Chris McCord
%%%
%%% Local PubSub server supervisor.
%%%
%%% Used by PubSub adapters to handle "local" subscriptions.
%%% Defines an ets dispatch table for routing subscription
%%% requests. Extendable by PubSub adapters by providing
%%% a list of `dispatch_rules' to extend the dispatch table.
%%%
%%% @see ebus_ps_pg2.
%%%
%%% @reference See
%%% <a href="https://github.com/phoenixframework/phoenix">Phoenix</a>
%%% @end
%%%-------------------------------------------------------------------
-module(ebus_ps_local_sup).

-behaviour(supervisor).

%% API
-export([start_link/3]).

%% Supervisor callbacks
-export([init/1]).

%%%===================================================================
%%% Types
%%%===================================================================

-type command()       :: broadcast | subscribe | unsubscribe.
-type dispatch_rule() :: {command(), module(), [term()]}.

-export_type([dispatch_rule/0]).

%%%===================================================================
%%% API functions
%%%===================================================================

-spec start_link(
  atom(), pos_integer(), [dispatch_rule()]
) -> supervisor:startlink_ret().
start_link(Server, PoolSize, DispatchRules) ->
  supervisor:start_link(?MODULE, [Server, PoolSize, DispatchRules]).

%%%===================================================================
%%% Supervisor callbacks
%%%===================================================================

%% @hidden
init([Server, PoolSize, DispatchRules]) ->
  % Define a dispatch table so we don't have to go through
  % a bottleneck to get the instruction to perform.
  % dispatch tablesを定義することによって
  % 実行時のボトルネックに対処する必要がなくなる

  %% etsにsubscribe情報を格納する
  %% read が多いのでread_concurrencyをtrueにしているものと思われる
  Server = ets:new(Server, [set, named_table, {read_concurrency, true}]),
  true = ets:insert(Server, {subscribe, ebus_ps_local, [Server, PoolSize]}),
  true = ets:insert(Server, {unsubscribe, ebus_ps_local, [Server, PoolSize]}),
  true = ets:insert(Server, {subscribers, ebus_ps_local, [Server, PoolSize]}),
  true = ets:insert(Server, {list, ebus_ps_local, [Server, PoolSize]}),
  true = ets:insert(Server, DispatchRules),

  %% Shardは数字。
  ChildrenFun = fun(Shard) ->
    %% Shard=1なら、ebus_ps_local_1のようになる
    LocalShardName = ebus_ps_local:local_name(Server, Shard),
    %% Shard=1なら、ebus_ps_gc_1のようになる
    GCShardName    = ebus_ps_local:gc_name(Server, Shard),
    %% Shardテーブルに登録する
    true = ets:insert(Server, {Shard, {LocalShardName, GCShardName}}),

    %% Shardのspecを作成する
    ShardChildren = [
      ebus_supervisor_spec:worker(ebus_ps_gc, [GCShardName, LocalShardName]),
      ebus_supervisor_spec:worker(ebus_ps_local, [LocalShardName, GCShardName])
    ],

    %% Shardのspecは、ebus_supervisourの子プロセスとして使うようにして
    %% supervisor specを生成
    ebus_supervisor_spec:supervisor(
      ebus_supervisor,
      [ShardChildren, #{strategy => one_for_all}],
      #{id => Shard}
    )
  end,
  %% プールサイズ分Shard数をChildrenFunに渡す
  Children = [ChildrenFun(C) || C <- lists:seq(0, PoolSize - 1)],

  ebus_supervisor_spec:supervise(Children, #{strategy => one_for_one}).
