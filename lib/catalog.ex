defmodule Catalog do
  @external_resource "README.md"
  @moduledoc "README.md"
             |> File.read!()
             |> String.split("<!-- MDOC !-->")
             |> Enum.fetch!(1)

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

  @doc """
  Processes all markdown files in `from` and stores them in the
  module attribute `as`.

  To use this macro, you must install `Earmark` as a dependency in your
  application:

      {:earmark, "~> 1.14"}

  Additionally, if you want to use use `Makeup` syntax highlighting via
  the `:highlighters` option outlined below, you will need to install it
  along with any relevant language lexers you will need:

      {:makeup, "~> 1.0"},
      {:makeup_elixir, ">= 0.0.0"}

  ## Example

      defmodule MyApp.Catalog do
        use Catalog

        markdown(:posts, "posts/**.md", build: Article)

        def all_posts(), do: @posts
      end

  ## Options

    * `:build` - the name of the module that will build each entry

    * `:highlighters` - which code highlighters to use. `Catalog`
      uses `Makeup` for syntax highlighting and you will need to add its
      `.css` classes. You can generate the CSS classes by calling
      `Makeup.stylesheet(:vim_style, "makeup")` inside `iex -S mix`.
      You can replace `:vim_style` by any style of your choice
      [defined here](https://hexdocs.pm/makeup/Makeup.Styles.HTML.StyleMap.html).

    * `:earmark_options` - an [`%Earmark.Options{}`](https://hexdocs.pm/earmark/Earmark.Options.html) struct.
  """
  defmacro markdown(as, from, opts \\ []),
    do: macro(&Catalog.__extract_markdown__/2, as, from, opts)

  @doc """
  Processes all json files in `from` and stores them in the
  module attribute `as`.

  This macro uses `Jason` to process the content of the file.
  To use it, you must have `Jason` added as a dependency:

      {:jason, "~> 1.2"}

  ## Example

      defmodule MyApp.Catalog do
        use Catalog

        json(:countries, "countries/**.json")

        def all_countries(), do: @countries
      end

  ## Options

    * `:build` - the name of the module that will build each entry.

    * `:jason_options` - options that will be passed along to the
      `Jason.decode!/2` call.

  """
  defmacro json(as, from, opts \\ []),
    do: macro(&Catalog.__extract_json__/2, as, from, opts)

  @doc """
  Processes all files in `from` and stores them in the
  module attribute `as`. This processor merely reads the file contents
  into a string. It is commonly used for text or HTML files.

  ## Example

      defmodule MyApp.Catalog do
        use Catalog

        file(:notes, "notes/**.txt")

        def all_notes(), do: @notes
      end

  ## Options

    * `:build` - the name of the module that will build each entry.

  """
  defmacro file(as, from, opts \\ []),
    do: macro(&Catalog.__extract_file__/2, as, from, opts)

  @doc """
  Processes all YAML files in `from` and stores them in the
  module attribute `as`.

  This macro uses `YamlElixir` for processing the content of the
  file. To use it, you must have `YamlElixir` added as a dependency:

      {:yaml_elixir, "~> 2.8"}

  ## Example

      defmodule MyApp.Catalog do
        use Catalog

        yaml(:cities, "cities/**.yaml")

        def all_cities(), do: @cities
      end

  ## Options

    * `:build` - the name of the module that will build each entry.

    * `:yaml_options` - options that will be passed along to the
      `YamlElixir.read_from_string!/2` call.

  """
  defmacro yaml(as, from, opts \\ []),
    do: macro(&Catalog.__extract_yaml__/2, as, from, opts)

  @doc """
  Processes all TOML files in `from` and stores them in the
  module attribute `as`.

  This macro uses `Toml` for processing the content of the file.
  To use it, you must install `Toml` as a dependency:

      {:toml, "~> 0.6.2"}

  ## Example

  If we have a `authors.toml` file with the following contents:

      ["Graham Greene"]
      best_work = "The Quiet American"

      ["Fernando Pessoa"]
      best_work = "Book of Disquiet

  We can include it in our module like so:

      defmodule MyApp.Catalog do
        use Catalog

        toml(:authors, "authors.toml")

        def all_authors(), do: @authors
      end

  The value of `@authors` will be:

      %{
        frontmatter: %{},
        path: "authors.toml",
        content: %{
          "Graham Greene" => %{"best_work" => "The Quiet American"},
          "Fernando Pessoa" => %{"best_work" => "Book of Disquiet}
        }
      }

  ## Options

    * `:build` - the name of the module that will build each entry.

    * `:toml_options` - options that will be passed along to the
      `Toml.decode!/2` call.

  """
  defmacro toml(as, from, opts \\ []),
    do: macro(&Catalog.__extract_toml__/2, as, from, opts)

  @doc """
  Processes all CSV files in `from` and stores them in the
  module attribute `as`.

  This macro uses `CSV` for processing the content of the file.
  To use it, you must install `CSV` as a dependency:

      {:csv, "~> 2.4"}

  ## Example

  If we have a `people.csv` file with the following contents:

      name,age
      john,27
      steve,20

  We can include it in our module like so:

      defmodule MyApp.Catalog do
        use Catalog

        csv(:people, "people.csv")

        def all_people(), do: @people
      end

  The resulting value of `@movies` will be:

      %{
        frontmatter: %{},
        path: "people.csv",
        content: [
          %{"name" => "john", "age" => "27"},
          %{"name" => "steve", "age" => "20"}
        ]
      }

  ## Options

    * `:build` - the name of the module that will build each entry.

    * `:csv_options` - options that will be passed along to the
      `CSV.decode!/2` call. By default we pass along `headers: true`
      to the call.

  """
  defmacro csv(as, from, opts \\ []),
    do: macro(&Catalog.__extract_csv__/2, as, from, opts)

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

  if Code.ensure_loaded?(Jason) do
    def __extract_json__(from, opts) do
      jason_options = Keyword.get(opts, :jason_options, [])
      parser = &Jason.decode!(&1, jason_options)
      extract(parser, from, opts)
    end
  else
    def __extract_json__(_from, _opts),
      do: raise(ArgumentError, "json/3 requires :jason to be installed and loaded")
  end

  def __extract_file__(from, opts) do
    extract(& &1, from, opts)
  end

  if Code.ensure_loaded?(YamlElixir) do
    def __extract_yaml__(from, opts) do
      yaml_options = Keyword.get(opts, :yaml_options, [])
      parser = &YamlElixir.read_from_string!(&1, yaml_options)
      extract(parser, from, opts)
    end
  else
    def __extract_yaml__(_from, _opts),
      do: raise(ArgumentError, "yaml/3 requires :yaml_elixir to be installed and loaded")
  end

  if Code.ensure_loaded?(Toml) do
    def __extract_toml__(from, opts) do
      toml_options = Keyword.get(opts, :toml_options, [])
      parser = &Toml.decode!(&1, toml_options)
      extract(parser, from, opts)
    end
  else
    def __extract_toml__(_from, _opts),
      do: raise(ArgumentError, "toml/3 requires :toml to be installed and loaded")
  end

  if Code.ensure_loaded?(CSV) do
    def __extract_csv__(from, opts) do
      csv_options = Keyword.merge([headers: true], Keyword.get(opts, :csv_otpions, []))
      parser = &(String.split(&1) |> CSV.decode!(csv_options) |> Enum.to_list())
      extract(parser, from, opts)
    end
  else
    def __extract_csv__(_from, _opts),
      do: raise(ArgumentError, "csv/3 requires :csv to be installed and loaded")
  end

  defp extract(decoder, from, opts) do
    builder = Keyword.get(opts, :build)

    paths = from |> Path.wildcard() |> Enum.sort()

    entries =
      for path <- paths do
        {frontmatter, content} = Catalog.FrontMatter.process!(File.read!(path), path, opts)

        content = decoder.(content)

        if builder do
          builder.build(path, frontmatter, content)
        else
          %{
            path: path,
            frontmatter: frontmatter,
            content: content
          }
        end
      end

    {paths, entries}
  end
end
