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
