# ExSync

A suite of Elixir libraries for a Diff Sync backend.

Based off of
[Jan Moschke's Diffsync library](https://github.com/janmonschke/diffsync) (and
consequently works great with his javascript client).

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed as:

  1. Add exsync to your list of dependencies in `mix.exs`:

        def deps do
          [{:exsync, "~> 0.0.1"}]
        end

  2. Ensure exsync is started before your application:

        def application do
          [applications: [:exsync]]
        end
