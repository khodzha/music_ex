defmodule MusicEx.Song do
  alias MusicEx.Song

  @enforce_keys [:title, :uuid]
  defstruct [:title, :uuid]

  def build(title) do
    %Song{title: title, uuid: UUID.uuid4()}
  end
end
