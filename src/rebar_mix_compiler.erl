-module(rebar_mix_compiler).

-export([build/1,
         format_error/1]).

%% ===================================================================
%% Public API
%% ===================================================================
build(AppInfo) ->
  MixEnv = get_mix_env(AppInfo),
  SystemEnv = get_system_env(AppInfo),
  AppDir = rebar_app_info:dir(AppInfo),
  BuildDir = filename:join(AppDir, "../"),
  BuildElixirDir = filename:join(AppDir, build_elixir_dir(MixEnv)),
  AppName = rebar_mix_utils:to_string(rebar_app_info:name(AppInfo)),

  CompileOpts = #{mix_env => MixEnv, system_env => SystemEnv},
  rebar_mix_utils:compile(AppDir, CompileOpts),

  {ok, Apps} = rebar_utils:list_dir(BuildElixirDir),
  Deps = Apps -- [AppName],
  rebar_mix_utils:move_to_path(Deps, BuildElixirDir, BuildDir),

  AppBuild = filename:join(AppDir, "_build/prod/lib/" ++ AppName ++ "/ebin"),
  AppTaget = filename:join(AppDir, "ebin"),
  ec_file:copy(AppBuild, AppTaget, [recursive]),

  Lock = rebar_mix_utils:create_rebar_lock_from_mix(AppDir, Deps),
  ElixirLock = rebar_mix_utils:elixir_to_lock(Lock),
  rebar_mix_utils:save_rebar_lock(AppDir, ElixirLock),
  rebar_mix_utils:delete(filename:join(AppDir, "_build")),

  ok.

format_error({mix_not_found, Name}) ->
  io_lib:format("Elixir and mix must be installed to build application ~ts. "
                "Install Elixir or check your path and try again.", [Name]);
format_error({mix_compile_failed, Name, _Error}) ->
  io_lib:format("Failed to compile application ~ts with mix", [Name]);
format_error(Reason) ->
  io_lib:format("~p", Reason).

get_mix_env(AppInfo) ->
    case get_dep_opt(AppInfo, env, "prod") of
        Env when is_list(Env); is_binary(Env); is_atom(Env) ->
            to_charlist(Env);
        _ ->
            "prod"
    end.

get_system_env(AppInfo) ->
    get_dep_opt(AppInfo, system_env, []).

get_dep_opt(AppInfo, Key, Default) ->
    AppOpts = rebar_app_info:opts(AppInfo),
    case dict:find(rebar_mix, AppOpts) of
        {ok, Opts} when is_list(Opts) ->
            case lists:keyfind(Key, 1, Opts) of
                {Key, Value} ->
                    Value;
                _ ->
                    Default
            end;
        _ ->
            Default
    end.

build_elixir_dir(MixEnv) ->
    filename:join(["_build", MixEnv, "lib"]) ++ "/".

to_charlist(A) when is_atom(A) -> atom_to_list(A);
to_charlist(B) when is_binary(B) -> binary_to_list(B);
to_charlist(L) when is_list(L) -> L.
