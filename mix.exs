defmodule Catalog.MixProject do
  use Mix.Project

  @version "0.1.2"
  @url "https://github.com/kevinlang/catalog"

  def project do
    [
      app: :catalog,
      version: @version,
      elixir: "~> 1.11",
      name: "Catalog",
      description:
        "Compile time content and data processing engine for markdown, json, yaml, and more.",
      deps: deps(),
      docs: docs(),
      package: package()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp docs do
    [
      main: "Catalog",
      source_ref: "v#{@version}",
      source_url: @url
    ]
  end

  defp package do
    %{
      licenses: ["Apache 2"],
      maintainers: ["Kevin Lang"],
      links: %{"GitHub" => @url}
    }
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:earmark, "~> 1.4", optional: true},
      {:makeup, "~> 1.0", optional: true},
      {:makeup_elixir, ">= 0.0.0", optional: true},
      {:jason, "~> 1.2", optional: true},
      {:yaml_elixir, "~> 2.8", optional: true},
      {:toml, "~> 0.6.2", optional: true},
      {:csv, "~> 2.4", optional: true},

      # docs
      {:ex_doc, "~> 0.21", only: :docs}
    ]
  end
end
