defmodule ExSync.Mixfile do
  use Mix.Project

  def project do
    [app: :ex_sync,
     version: "0.0.1",
     elixir: "~> 1.2",
     description: description,
     package: package,
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps]
  end

  def application do
    [applications: [:logger]]
  end

  def description do
    """
    A library to handle
    [Differential Synchroniazation](https://neil.fraser.name/writing/sync/)
    in an Elixir app.
    """
  end

  def package do
    [
      files: ~w(lib mix.exs README.md LICENSE),
      maintainers: ["Michael Schaefermeyer"],
      licenses: ["Apache 2.0"],
      links: %{
        "GitHub" => "https://github.com/invrs/exsync",
        "Docs" => "http://hexdocs.pm/exsync",
      }
    ]
  end

  defp deps do
    [
      {:connection, "~> 1.0"},

      {:earmark, "~> 0.2", only: :dev},
      {:ex_doc, "~> 0.11", only: :dev},
    ]
  end
end
