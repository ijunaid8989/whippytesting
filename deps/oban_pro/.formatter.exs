locals_without_parens = [
  args_schema: 1,
  field: 2,
  field: 3,
  embeds_one: 2,
  embeds_many: 2
]

[
  import_deps: [:ecto, :ecto_sql, :oban, :stream_data],
  export: [locals_without_parens: locals_without_parens],
  locals_without_parens: locals_without_parens,
  inputs: ["{mix,.formatter}.exs", "{config,lib,test}/**/*.{ex,exs}"]
]
