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

  defmacro markdown(opts) do
    quote bind_quoted: [opts: opts] do
      {from, paths} = Catalog.__extract__(__MODULE__, opts)

      for path <- paths do
        @external_resource Path.relative_to_cwd(path)
      end

      @catalog_from_with_md5 {from, :erlang.md5(paths)}
    end
  end

  # def __extract_markdown__(as, from, opts) do
  #   earmark_opts = Keyword.get(opts, :earmark_options, %Earmark.Options{})
  #   highlighters = Keyword.get(opts, :highlighters, [])
  #   decoder = &(&1 |> Earmark.as_html!(earmark_opts) |> highlight(highlighters))
  #   extract(decoder, as, from, opts)
  # end

  defp highlight(html, []) do
    html
  end

  defp highlight(html, _) do
    Catalog.Highlighter.highlight(html)
  end

  defmacro json(as, from, opts) do
    quote bind_quoted: [as: as, from: from, opts: opts] do
      {paths, entries} = Catalog.__extract_json__(from, opts)

      # if the path provided is not a wildcard, store it as a single val
      # instead of as a list
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

  def __extract_json__(from, opts) do
    jason_options = Keyword.get(opts, :jason_options, [])
    parser = &(Jason.decode(&1, jason_options))
    extract(parser, from, opts)
  end

  defp extract(decoder, from, opts) do
    builder = Keyword.get(opts, :build)

    paths = from |> Path.wildcard() |> Enum.sort()

    entries =
      for path <- paths do
        {attrs, body} = parse_contents!(path, File.read!(path))

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

  def __extract__(module, opts) do
    builder = Keyword.fetch!(opts, :build)
    from = Keyword.fetch!(opts, :from)
    as = Keyword.fetch!(opts, :as)

    for highlighter <- Keyword.get(opts, :highlighters, []) do
      Application.ensure_all_started(highlighter)
    end

    paths = from |> Path.wildcard() |> Enum.sort()

    entries =
      for path <- paths do
        {attrs, body} = parse_contents!(path, File.read!(path))

        body =
          path
          |> Path.extname()
          |> String.downcase()
          |> convert_body(body, opts)

        builder.build(path, attrs, body)
      end

    Module.put_attribute(module, as, entries)
    {from, paths}
  end

  defp parse_contents!(path, contents) do
    case parse_contents(path, contents) do
      {:ok, attrs, body} ->
        {attrs, body}

      {:error, message} ->
        raise """
        #{message}

        Each entry must have a map with attributes, followed by --- and a body. For example:

            %{
              title: "Hello World"
            }
            ---
            Hello world!

        """
    end
  end

  defp parse_contents(path, contents) do
    case :binary.split(contents, ["\n---\n", "\r\n---\r\n"]) do
      [_] ->
        {:error, "could not find separator --- in #{inspect(path)}"}

      [code, body] ->
        case Code.eval_string(code, []) do
          {%{} = attrs, _} ->
            {:ok, attrs, body}

          {other, _} ->
            {:error,
             "expected attributes for #{inspect(path)} to return a map, got: #{inspect(other)}"}
        end
    end
  end

  defp convert_body(extname, body, opts) when extname in [".md", ".markdown"] do
    earmark_opts = Keyword.get(opts, :earmark_options, %Earmark.Options{})
    highlighters = Keyword.get(opts, :highlighters, [])
    body |> Earmark.as_html!(earmark_opts) |> highlight(highlighters)
  end

  defp convert_body(_extname, body, _opts) do
    body
  end
end
