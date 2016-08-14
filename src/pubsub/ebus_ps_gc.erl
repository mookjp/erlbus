%%%-------------------------------------------------------------------
%%% @doc
%%% This is an Erlang clone of the original `Phoenix.PubSub.GC'
%%% module.
%%% Copyright (c) 2014 Chris McCord
%%% @reference See
%%% <a href="https://github.com/phoenixframework/phoenix">Phoenix</a>
%%% @end
%%%-------------------------------------------------------------------
-module(ebus_ps_gc).

-behaviour(gen_server).

%% API
-export([
  start_link/2,
  down/2,
  unsubscribe/4
]).

%% gen_server callbacks
-export([
  init/1,
  handle_call/3,
  handle_cast/2,
  handle_info/2,
  terminate/2,
  code_change/3
]).

%%%===================================================================
%%% API
%%%===================================================================

%% @doc
%% Starts the server.
%%
%% <ul>
%% <li>`ServerName': The name to register the server under.</li>
%% <li>`LocalName': The name of the local table.</li>
%% </ul>
%% @end
-spec start_link(atom(), atom()) -> gen:start_ret().
start_link(ServerName, LocalName) ->
  gen_server:start_link(
    {local, ServerName}, ?MODULE, [ServerName, LocalName], []
  ).

%% @doc
%% Force table clean up because the given pid is down asynchronously.
%%
%% <ul>
%% <li>`GCServer': The registered server name or pid.</li>
%% <li>`Pid': The subscriber pid.</li>
%% </ul>
%%
%% Examples:
%%
%% ```
%% > down(gc_server, self()).
%% ok
%%% '''
%% @end
-spec down(atom(), pid()) -> ok.
down(GCServer, Pid) when is_atom(GCServer) ->
  gen_server:cast(GCServer, {down, Pid}).

%% @doc
%% Removes subscriber's subscription for topic
%% @end
-spec unsubscribe(pid(), binary(), atom(), atom()) -> ok.
unsubscribe(Pid, Topic, TopicsTable, PidsTable) ->
  true = ets:match_delete(TopicsTable, {Topic, {Pid, '_'}}),
  true = ets:delete_object(PidsTable, {Pid, Topic}),
  ok.

%%%===================================================================
%%% gen_server callbacks
%%%===================================================================

%% @hidden
init([ServerName, LocalName]) ->
  %% ServerNameは`ebus_ps_gc_1`のような形式, LocalNameは`ebus_ps_local_1`のような形式
  {ok, #{topics => LocalName, pids => ServerName}}.

%% @hidden
%% ebus_ps_localからgen_server:callされる
handle_call({subscription, Pid}, _From, #{pids := Pids} = State) ->
  try
    {reply, ets:lookup_element(Pids, Pid, 2), State}
  catch
    error:badarg -> {reply, [], State}
  end;
handle_call(_Request, _From, State) ->
  {reply, ok, State}.

%% @hidden
%% pidsはServerName, topicsはLocalName
%% down()が呼ばれたらetsのebus_ps_local_X（Topis）、ebus_pa_gc_X（Pids）テーブルから
%% 該当Pidのvalueを削除
handle_cast({down, Pid}, #{pids := Pids, topics := Topics} = State) ->
  try
    %% e.g. ebus_ps_gc_1テーブルからPidを探す
    %% keyにはtopicsのリストがvalueとして格納されていると思われる
    Topics0 = ets:lookup_element(Pids, Pid, 2),
    %% e.g. ebus_ps_local_1テーブル（トピック管理テーブル？）から、
    %% 該当Pidのtopicと該当pidのタプルを削除
    lists:foreach(fun(Topic) ->
      true = ets:match_delete(Topics, {Topic, {Pid, '_'}})
    end, Topics0),
    %% e.g. ebus_ps_gc_1テーブル（Pidとトピックのひも付けテーブル？）から、
    %% 該当Pidを削除
    true = ets:match_delete(Pids, {Pid, '_'})
  catch
    error:badarg -> badarg
  end,
  {noreply, State};
handle_cast(_Request, State) ->
  {noreply, State}.

%% @hidden
handle_info(_Info, State) ->
  {noreply, State}.

%% @hidden
terminate(_Reason, _State) ->
  ok.

%% @hidden
code_change(_OldVsn, State, _Extra) ->
  {ok, State}.
