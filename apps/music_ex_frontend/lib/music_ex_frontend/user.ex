defmodule MusicExFrontend.User do
  use Ecto.Schema
  import Ecto.Changeset
  alias MusicExFrontend.User
  alias MusicExFrontend.Repo
  import Ecto.Query, only: [from: 2]


  schema "users" do
    field :avatar, :string
    field :discriminator, :string
    field :user_id, :string
    field :username, :string
    many_to_many :guilds, MusicExFrontend.Guild, join_through: "guilds_users"

    timestamps()
  end

  def update_or_create(attrs) do
    uid = attrs["user_id"]
    query = from u in User,
      where: u.user_id == ^uid

    case Repo.one(query) do
      nil ->
        changeset = User.changeset(%User{}, attrs)
        Repo.insert(changeset)
      user ->
        changeset = User.changeset(user, attrs)
        Repo.update(changeset)
    end
  end

  @doc false
  def changeset(%User{} = user, attrs) do
    user
    |> cast(attrs, [:user_id, :discriminator, :username, :avatar])
    |> validate_required([:user_id, :username])
  end
end
