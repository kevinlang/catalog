defmodule Catalog.FrontMatter do
  @moduledoc false

  def process!("===" <> rest, path, _opts) do
    [code, body] = String.split(rest, ["===\n", "===\r\n"], parts: 2)

    case Code.eval_string(code, []) do
      {%{} = attrs, _} ->
        {attrs, body}

      {other, _} ->
        raise """
        Failed to process Elixir frontmatter in #{inspect(path)}

        Expected evaluated frontmatter to return a map, got: #{inspect(other)}
        """
    end
  end

  def process!("---" <> rest, path, opts) do
    yaml_options = Keyword.merge([atoms: true], Keyword.get(opts, :yaml_options, []))
    [yaml, body] = String.split(rest, ["---\n", "---\r\n"], parts: 2)

    case YamlElixir.read_from_string(yaml, yaml_options) do
      {:ok, attrs} ->
        {attrs, body}

      {:error, msg} ->
        raise """
        Failed to process YAML frontmatter in #{inspect(path)}

        #{msg}
        """
    end
  end

  def process!("+++" <> rest, path, opts) do
    toml_options = Keyword.merge([keys: :atoms], Keyword.get(opts, :toml_options, []))
    [toml, body] = String.split(rest, ["+++\n", "+++\r\n"], parts: 2)

    case Toml.decode(toml, toml_options) do
      {:ok, attrs} ->
        {attrs, body}

      {:error, msg} ->
        raise """
        Failed to process TOML frontmatter in #{inspect(path)}

        #{msg}
        """
    end
  end

  def process!(content, _path, _opts) do
    {%{}, content}
  end
end
