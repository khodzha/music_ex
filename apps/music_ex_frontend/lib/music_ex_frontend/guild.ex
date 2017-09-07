defmodule MusicExFrontend.Guild do
  use Ecto.Schema
  import Ecto.Changeset
  alias MusicExFrontend.Guild


  schema "guilds" do
    field :guild_id, :string
    field :text_channel_id, :string
    field :voice_channel_id, :string
    many_to_many :users, MusicExFrontend.User, join_through: "guilds_users"

    timestamps()
  end

  @doc false
  def changeset(%Guild{} = guild, attrs \\ %{}) do
    guild
    |> cast(attrs, [:guild_id, :text_channel_id, :voice_channel_id])
    |> validate_required([:guild_id])
  end
end
