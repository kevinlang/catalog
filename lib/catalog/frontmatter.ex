defmodule Catalog.FrontMatter do
  @moduledoc false

  def process!("===" <> rest, path) do
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

  def process!("---" <> rest, path) do
    [yaml, body] = String.split(rest, ["---\n", "---\r\n"], parts: 2)

    case YamlElixir.read_from_string(yaml, atoms: true) do
      {:ok, attrs} ->
        {attrs, body}

      {:error, msg} ->
        raise """
        Failed to process YAML frontmatter in #{inspect(path)}

        #{msg}
        """
    end
  end

  def process!("+++" <> rest, path) do
    [toml, body] = String.split(rest, ["+++\n", "+++\r\n"], parts: 2)

    case Toml.decode(toml, keys: :atoms) do
      {:ok, attrs} ->
        {attrs, body}

      {:error, msg} ->
        raise """
        Failed to process TOML frontmatter in #{inspect(path)}

        #{msg}
        """
    end
  end

  def process!(content, _path) do
    {%{}, content}
  end
end
