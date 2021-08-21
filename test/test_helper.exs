optional_dep_apps = [:makeup, :makeup_elixir]
Enum.map(optional_dep_apps, &Application.ensure_all_started/1)

ExUnit.start()
