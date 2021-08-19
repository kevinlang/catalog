defmodule Catalog do
  @doc false
  defmacro __using__(_) do
    quote do
      @before_compile unquote(__MODULE__)
      Module.register_attribute(__MODULE__, :catalog_from_with_md5, accumulate: true)
      import Catalog
    end
  end

  defmacro __before_compile__(_) do
    quote do
      def __mix_recompile__? do
        Enum.any?(@catalog_from_with_md5, fn {from, md5} ->
          from |> Path.wildcard() |> Enum.sort() |> :erlang.md5() != md5
        end)
      end
    end
  end

  defmacro markdown(as, from, opts \\ []),
    do: macro(&Catalog.__extract_markdown__/2, as, from, opts)

  defmacro json(as, from, opts \\ []),
    do: macro(&Catalog.__extract_json__/2, as, from, opts)

  defmacro file(as, from, opts \\ []),
    do: macro(&Catalog.__extract_file__/2, as, from, opts)

  defp macro(fun, as, from, opts) do
    quote bind_quoted: [fun: fun, as: as, from: from, opts: opts] do
      {paths, entries} = fun.(from, opts)

      if [from] == paths do
        [entry] = entries
        Module.put_attribute(__MODULE__, as, entry)
      else
        Module.put_attribute(__MODULE__, as, entries)
      end

      for path <- paths do
        @external_resource Path.relative_to_cwd(path)
      end

      @catalog_from_with_md5 {from, :erlang.md5(paths)}
    end
  end

  def __extract_markdown__(from, opts) do
    earmark_opts = Keyword.get(opts, :earmark_options, %Earmark.Options{})
    highlighters = Keyword.get(opts, :highlighters, [])
    decoder = &(&1 |> Earmark.as_html!(earmark_opts) |> highlight(highlighters))
    extract(decoder, from, opts)
  end

  defp highlight(html, []) do
    html
  end

  defp highlight(html, _) do
    Catalog.Highlighter.highlight(html)
  end

  def __extract_json__(from, opts) do
    jason_options = Keyword.get(opts, :jason_options, [])
    parser = &Jason.decode!(&1, jason_options)
    extract(parser, from, opts)
  end

  def __extract_file__(from, opts) do
    extract(& &1, from, opts)
  end

  defp extract(decoder, from, opts) do
    builder = Keyword.get(opts, :build)

    paths = from |> Path.wildcard() |> Enum.sort()

    entries =
      for path <- paths do
        {attrs, body} = parse_contents!(File.read!(path), path)

        body = decoder.(body)

        if builder do
          builder.build(path, attrs, body)
        else
          %{
            path: path,
            attrs: attrs,
            body: body
          }
        end
      end

    {paths, entries}
  end

  defp parse_contents!("===" <> rest, path) do
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

  defp parse_contents!("---" <> rest, path) do
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

  defp parse_contents!("+++" <> rest, path) do
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

  defp parse_contents!(content, _path) do
    {%{}, content}
  end
end
