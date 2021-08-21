# Catalog

[Online Documentation](https://hexdocs.pm/catalog).

<!-- MDOC !-->

`Catalog` does compile-time transformation and processing of data and content files
in your codebase and embeds the result into the module in which it was used.

It intends to make integrating non-code files within your Elixir projects 
as pleasant as a developer experience as possible, taking inspiration from
the seamless integration static site generators provide for editing in-repo 
data and content files.

It supports the following content types:

* `markdown/3`
* `json/3`
* `csv/3`
* `file/3`
* `yaml/3`
* `toml/3`

## Comparison to other approaches

Because the content is preprocessed at compile time, any expensive transformations
are no longer done at runtime, such as transforming markdown to HTML in response to
a web request. Likewise, since everything is stored in memory, no disk lookups need
to be made to access the processed entries. This compile-time approach means any processing
are easily detected during development or in a basic CI system, instead of encountering issues
in response to a request or at boot time. 

## Example

We can install Catalog into our application by updating our `deps()` in our `mix.exs`
to include `:catalog`.
Since we will be processing markdown files here with Toml frontmatter, we will also need
to install `:earmark` and `:toml`, respectively.

```elixir
def deps() do
  [
    {:catalog, "~> 0.1.1"},
    {:earmark, "~> 1.4"},
    {:toml, "~> 0.6.2"}
  ]
end
```

With that done, we can define a new module in our application:

```elixir
defmodule MyApp.Catalog do
  use Catalog

  markdown(:posts, "posts/**.md")

  def all_posts(), do: @posts
end
```

In the example above, we defined a new module for our Elixir application, `MyApp.Catalog`,
that will serve as the API for our processed assets. We then use the `markdown/2` macro,
specifying first the name of the module attribute, `:posts`, we want to stored the processed markdown file,
then specifying the wildcard path for where those files are stored, `"posts/**.md"`.

If our specified directory has only the following markdown file at `posts/hello.md`:

```markdown
+++
author = "Kevin Lang"
title = "Hello World"
date: 2021-08-19
+++
This is a markdown *document*.
```

Then the `@posts` attribute above will look like the following:

```elixir
[%{
  content: "<p>\nThis is a markdown <em>document</em>.</p>\n"
  frontmatter: %{
    author: "Kevin Lang",
    title: "Hello World",
    date: ~D[2021-08-19]
  },
  path: "posts/hello.md"
}]
```

We can customize how we build each entry by specifying our own `:build` option.

```elixir 
defmodule MyApp.Catalog.Post
  @enforce_keys [:id, :author, :title, :date, :content]
  defstruct [:id, :author, :title, :date, :content]

  def build(path, frontmatter, content) do
    [id] = path |> Path.rootname() |> Path.split() |> Enum.take(-1)
    struct!(__MODULE__, [id: id, content: content] ++ Map.to_list(frontmatter))
  end
end
```

Then our `@posts` attribute will look like:

```elixir
[%MyApp.Catalog.Post{
  id: "hello",
  content: "<p>\nThis is a markdown <em>document</em>.</p>\n",
  date: ~D[2021-08-19],
  title: "Hello World",
  author: "Kevin Lang"
}]
```

Additionally, we can add syntax highlighting and customize our markdown to HTML
transformation. See `markdown/2` for more info.

### Using and modifying the module attribute

After the module attribute is defined, as shown in the example above, you may want to
modify it further. For example, you may want to sort all of the `@posts` according to
their date. This can be done like so:

```elixir
defmodule MyApp.Catalog do
  use Catalog

  markdown(:posts, "posts/**.md")

  # The @posts variable is first defined by the markdown macro above.
  # Let's further modify it by sorting all posts by descending date.
  @posts Enum.sort_by(@posts, & &1.date, {:desc, Date})

  def all_posts(), do: @posts
end
```

**Important**: Avoid injecting the `@posts` attribute into multiple functions,
as each call will make a complete copy of all posts. For example, if you want
to show define `recent_posts()` as well as `all_posts()`, DO NOT do this:

```elixir
def all_posts, do: @posts
def recent_posts, do: Enum.take(@posts, 3)
```

Instead do this:

```elixir
def all_posts, do: @posts
def recent_posts, do: Enum.take(all_posts(), 3)
```

## Frontmatter

All of our content types support frontmatter. Frontmatter is a block at the top of your
content file that contains additional data about the file. They are commonly used for markdown
files, but are supported for all of our macros.

### TOML frontmatter

TOML frontmatter can be used by specifying a TOML block fenced in by the `+++` seperator:

```markdown
+++
hello = "toml"
+++
This markdown *document* has TOML frontmatter!
```

TOML frontmatter is processed by the `Toml` libary. You can customize the TOML processing by providing 
`:toml_options` in your macro call, which will be passed along to `Toml.decode!/1`. 

### Elixir frontmatter

Elixir frontmatter can be used by including Elixir code fenced in by the `===` seperator.

```markdown
===
%{
  hello: "elixir"
}
===
This markdown *document* has Elxiir frontmatter!
```

The code in the block is passed to `Code.eval_string/1`. It must return a `Map`.

### YAML frontmatter (not recommended)

You can use YAML frontmatter by specifying a YAML block fenced in by the `---` seperator.

```markdown
---
hello: yaml
---
This markdown *document* has YAML frontmatter!
```

YAML frontmatter parsing is handled by `YamlElixir`. You can customize the YAML processing by providing
`:yaml_options` in your macro call, which will be passed along to `YamlElixir.read_from_string!/2`.

Unfortunately, this library does not allow us to have the keys returned as atoms instead of strings, which
makes it slightly more cumbersome to use. Because of this, we do not recommend using YAML frontmatter.

## Live reloading

If you are using Phoenix, you can enable live reloading by simply telling Phoenix to watch the “posts” directory. Open up "config/dev.exs", search for `live_reload:` and add this to the list of patterns:

```elixir
live_reload: [
  patterns: [
    ...,
    ~r"posts/*/.*(md)$"
  ]
]
```

## Credits

This work draws heavily on the [NimblePublisher](https://github.com/dashbitco/nimble_publisher) library by Dashbit.
