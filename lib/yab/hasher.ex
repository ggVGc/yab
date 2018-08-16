defmodule YAB.Hasher do
  def hash(data) do
    :crypto.hash(:sha256, data)
  end
end
