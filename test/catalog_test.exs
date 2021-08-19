defmodule CatalogTest do
  use ExUnit.Case, async: true

  doctest Catalog

  defmodule Builder do
    def build(filename, attrs, body) do
      %{filename: filename, attrs: attrs, body: body}
    end
  end

  alias CatalogTest.Example

  setup do
    File.rm_rf!("test/tmp")
    :code.purge(Example)
    :code.delete(Example)
    :ok
  end

  describe "toml frontmatter" do
    test "is decoded" do
      defmodule Example do
        use Catalog

        markdown(:example, "test/fixtures/toml.md")

        assert @example.attrs == %{hello: "world"}
        assert @example.body == "<p>\nThis is a markdown <em>document</em>.</p>\n"
      end
    end
  end

  describe "yaml frontmatter" do
    test "is decoded" do
      defmodule Example do
        use Catalog

        markdown(:example, "test/fixtures/yaml.md")

        assert @example.attrs == %{hello: "world"}
        assert @example.body == "<p>\nThis is a markdown <em>document</em>.</p>\n"
      end
    end
  end

  describe "markdown" do
    test "builds all matching entries" do
      defmodule Example do
        use Catalog

        markdown(:examples, "test/fixtures/**/*.md", build: Builder)

        assert [
                 %{filename: "crlf.md"},
                 %{filename: "markdown.md"},
                 %{filename: "nosyntax.md"},
                 %{filename: "syntax.md"},
                 %{filename: "toml.md"},
                 %{filename: "yaml.md"}
               ] =
                 @examples
                 |> update_in([Access.all(), :filename], &Path.basename/1)
                 |> Enum.sort_by(& &1.filename)
      end
    end

    test "converts to markdown" do
      defmodule Example do
        use Catalog

        markdown(:examples, "test/fixtures/markdown.{md,markdown}", build: Builder)

        Enum.each(@examples, fn example ->
          assert example.attrs == %{hello: "world"}
          assert example.body == "<p>\nThis is a markdown <em>document</em>.</p>\n"
        end)
      end
    end

    test "handles code blocks" do
      defmodule Example do
        use Catalog

        markdown(:example, "test/fixtures/nosyntax.md", build: Builder)

        assert @example.attrs == %{syntax: "nohighlight"}
        assert @example.body =~ "<pre><code>IO.puts &quot;syntax&quot;</code></pre>"
      end
    end

    test "passes earmark options to earmark - smartypants off" do
      defmodule Example do
        use Catalog

        markdown(:example, "test/fixtures/nosyntax.md",
          build: Builder,
          earmark_options: %Earmark.Options{smartypants: false}
        )

        assert @example.body =~ "<pre><code>IO.puts &quot;syntax&quot;</code></pre>"

        assert @example.body =~
                 "And inline code: <code class=\"inline\">IO.puts &quot;syntax&quot;</code>"

        assert @example.body =~ "&quot;Smartypants quotes without inline code&quot;"
      end
    end

    test "passes earmark options to earmark - smartypants on" do
      defmodule Example do
        use Catalog

        markdown(:example, "test/fixtures/nosyntax.md",
          build: Builder,
          earmark_options: %Earmark.Options{smartypants: true}
        )

        assert @example.body =~ "<pre><code>IO.puts &quot;syntax&quot;</code></pre>"

        # Earmark changed between 1.4.10 and 1.4.15 ...
        # assert hd(@examples).body =~
        #          "And inline code: <code class=\"inline\">IO.puts “syntax”</code>"

        assert @example.body =~ "“Smartypants quotes without inline code”"
      end
    end

    test "handles highlight blocks" do
      defmodule Example do
        use Catalog

        markdown(:highlight, "test/fixtures/syntax.md",
          build: Builder,
          highlighters: [:makeup_elixir]
        )

        assert @highlight.attrs == %{syntax: "highlight"}
        assert @highlight.body =~ "<pre><code class=\"makeup elixir\">"
      end
    end

    test "does not require recompilation unless paths changed" do
      defmodule Example do
        use Catalog

        markdown(:highlight, "test/fixtures/syntax.md", build: Builder)
      end

      refute Example.__mix_recompile__?()
    end

    test "requires recompilation if paths change" do
      defmodule Example do
        use Catalog

        markdown(:highlights, "test/tmp/**/*.md", build: Builder, highlighters: [:makeup_elixir])
      end

      refute Example.__mix_recompile__?()

      File.mkdir_p!("test/tmp")
      File.write!("test/tmp/example.md", "done!")

      assert Example.__mix_recompile__?()
    end
  end

  describe "json" do
    test "builds all matching entries" do
      defmodule Example do
        use Catalog

        json(:examples, "test/fixtures/**/{json}.json", build: Builder)

        assert [
                 %{filename: "json.json"}
               ] =
                 @examples
                 |> update_in([Access.all(), :filename], &Path.basename/1)
                 |> Enum.sort_by(& &1.filename)
      end
    end

    test "decodes json w/ frontmatter" do
      defmodule Example do
        use Catalog

        json(:example, "test/fixtures/json.json")

        assert @example.attrs == %{a: "four"}
        assert @example.body == %{"b" => 5}
      end
    end

    test "decodes json w/out frontmatter" do
      defmodule Example do
        use Catalog

        json(:example, "test/fixtures/no_frontmatter.json")

        assert @example.attrs == %{}
        assert @example.body == %{"b" => 5}
      end
    end
  end

  describe "file" do
    test "decodes file w/ frontmatter" do
      defmodule Example do
        use Catalog

        file(:example, "test/fixtures/frontmatter.txt")

        assert @example.attrs == %{hello: "world"}
        assert @example.body == "I am a text file.\n"
      end
    end

    test "decodes file w/out frontmatter" do
      defmodule Example do
        use Catalog

        file(:example, "test/fixtures/frontmatter_none.txt")

        assert @example.attrs == %{}
        assert @example.body == "I am a text file.\n"
      end
    end
  end

  describe "yaml" do
    test "decodes file" do
      defmodule Example do
        use Catalog

        yaml(:example, "test/fixtures/yaml.yaml")

        assert @example.body == %{"a" => "a", "b" => 1, "c" => true, "d" => nil, "e" => "nil"}
      end
    end
  end

  describe "toml" do
    test "decodes file" do
      defmodule Example do
        use Catalog

        toml(:example, "test/fixtures/toml.toml")

        assert @example.body == %{"database" => %{"server" => "192.168.1.1"}}
      end
    end
  end
end
