defmodule MusicEx.Song do
  alias MusicEx.Song

  @enforce_keys [:title, :uuid]
  defstruct [:title, :uuid, :metadata]

  def build(title) do
    %Song{title: title, uuid: UUID.uuid4()}
  end

  def set_metadata(%Song{} = song, metadata) do
    %Song{song | metadata: metadata}
  end
end
