defmodule Sync.Admin.Kaffy.Extension do
  @moduledoc false
  def stylesheets(_conn) do
    [
      {:safe, ~s(<link rel="stylesheet" href="/assets/app.css" />)}
    ]
  end

  #  def javascripts(_conn) do
  #    [
  #      {:safe, ~s(<script src="https://example.com/javascript.js"></script>)}
  #    ]
  #  end
end
