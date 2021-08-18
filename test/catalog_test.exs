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

  describe "markdown" do
    test "builds all matching entries" do
      defmodule Example do
        use Catalog

        markdown(
          build: Builder,
          from: "test/fixtures/**/*.md",
          as: :examples
        )

        assert [
                 %{filename: "crlf.md"},
                 %{filename: "markdown.md"},
                 %{filename: "nosyntax.md"},
                 %{filename: "syntax.md"}
               ] =
                 @examples
                 |> update_in([Access.all(), :filename], &Path.basename/1)
                 |> Enum.sort_by(& &1.filename)
      end
    end

    test "converts to markdown" do
      defmodule Example do
        use Catalog

        markdown(
          build: Builder,
          from: "test/fixtures/markdown.{md,markdown}",
          as: :examples
        )

        Enum.each(@examples, fn example ->
          assert example.attrs == %{hello: "world"}
          assert example.body == "<p>\nThis is a markdown <em>document</em>.</p>\n"
        end)
      end
    end

    test "handles code blocks" do
      defmodule Example do
        use Catalog

        markdown(
          build: Builder,
          from: "test/fixtures/nosyntax.md",
          as: :examples
        )

        assert hd(@examples).attrs == %{syntax: "nohighlight"}
        assert hd(@examples).body =~ "<pre><code>IO.puts &quot;syntax&quot;</code></pre>"
      end
    end

    test "passes earmark options to earmark - smartypants off" do
      defmodule Example do
        use Catalog

        markdown(
          build: Builder,
          from: "test/fixtures/nosyntax.md",
          as: :examples,
          earmark_options: %Earmark.Options{smartypants: false}
        )

        assert hd(@examples).body =~ "<pre><code>IO.puts &quot;syntax&quot;</code></pre>"

        assert hd(@examples).body =~
                 "And inline code: <code class=\"inline\">IO.puts &quot;syntax&quot;</code>"

        assert hd(@examples).body =~ "&quot;Smartypants quotes without inline code&quot;"
      end
    end

    test "passes earmark options to earmark - smartypants on" do
      defmodule Example do
        use Catalog

        markdown(
          build: Builder,
          from: "test/fixtures/nosyntax.md",
          as: :examples,
          earmark_options: %Earmark.Options{smartypants: true}
        )

        assert hd(@examples).body =~ "<pre><code>IO.puts &quot;syntax&quot;</code></pre>"

        # Earmark changed between 1.4.10 and 1.4.15 ...
        # assert hd(@examples).body =~
        #          "And inline code: <code class=\"inline\">IO.puts “syntax”</code>"

        assert hd(@examples).body =~ "“Smartypants quotes without inline code”"
      end
    end

    test "handles highlight blocks" do
      defmodule Example do
        use Catalog

        markdown(
          build: Builder,
          from: "test/fixtures/syntax.md",
          as: :highlights,
          highlighters: [:makeup_elixir]
        )

        assert hd(@highlights).attrs == %{syntax: "highlight"}
        assert hd(@highlights).body =~ "<pre><code class=\"makeup elixir\">"
      end
    end

    test "does not require recompilation unless paths changed" do
      defmodule Example do
        use Catalog

        markdown(as: :highlights, from: "test/fixtures/syntax.md", build: Builder)
      end

      refute Example.__mix_recompile__?()
    end

    test "requires recompilation if paths change" do
      defmodule Example do
        use Catalog

        markdown(
          as: :highlights,
          from: "test/tmp/**/*.md",
          build: Builder,
          highlighters: [:makeup_elixir]
        )
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

        json :examples, "test/fixtures/**/*.json", build: Builder

        assert [
                 %{filename: "json.json"}
               ] =
                 @examples
                 |> update_in([Access.all(), :filename], &Path.basename/1)
                 |> Enum.sort_by(& &1.filename)
      end
    end
  end
end
