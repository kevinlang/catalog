defmodule CatalogTest do
  use ExUnit.Case
  doctest Catalog

  test "greets the world" do
    assert Catalog.hello() == :world
  end
end
