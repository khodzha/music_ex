defmodule MusicExFrontend.Web do
  @moduledoc """
  The entrypoint for defining your web interface, such
  as controllers, views, channels and so on.

  This can be used in your application as:

      use MusicExFrontend.Web, :controller
      use MusicExFrontend.Web, :view

  The definitions below will be executed for every view,
  controller, etc, so keep them short and clean, focused
  on imports, uses and aliases.

  Do NOT define functions inside the quoted expressions
  below. Instead, define any helper function in modules
  and import those modules here.
  """

  def model do
    quote do
      use Ecto.Schema

      import Ecto
      import Ecto.Changeset
      import Ecto.Query
    end
  end

  def controller do
    quote do
      use Phoenix.Controller

      alias MusicExFrontend.Repo
      import Ecto
      import Ecto.Query

      import MusicExFrontend.Router.Helpers
      import MusicExFrontend.Gettext

      alias Plug.Crypto.KeyGenerator
      alias Plug.Crypto.MessageEncryptor

      def read_private_cookie(%Plug.Conn{} = conn, cookie_name) do
        enc_key = key(conn, :encryption_salt)
        sgn_key = key(conn, :signing_salt)

        case conn.cookies[cookie_name] do
          nil -> nil
          value ->
            {:ok, serialized_value} = MessageEncryptor.decrypt(value, enc_key, sgn_key)
            Plug.Crypto.safe_binary_to_term(serialized_value)
        end
      end

      def put_private_cookie(%Plug.Conn{} = conn, key, value, params \\ []) do
        enc_key = key(conn, :encryption_salt)
        sgn_key = key(conn, :signing_salt)

        serialized_value = :erlang.term_to_binary(value)
        cookie = MessageEncryptor.encrypt(serialized_value, enc_key, sgn_key)

        put_resp_cookie(conn, key, cookie, params)
      end

      defp key(conn, :encryption_salt) do
        KeyGenerator.generate(
          conn.secret_key_base,
          Application.get_env(:music_ex_frontend, :encryption_salt)
        )
      end

      defp key(conn, :signing_salt) do
        KeyGenerator.generate(
          conn.secret_key_base,
          Application.get_env(:music_ex_frontend, :signing_salt)
        )
      end
    end
  end

  def view do
    quote do
      use Phoenix.View, root: "web/templates"

      # Import convenience functions from controllers
      import Phoenix.Controller, only: [get_flash: 2, view_module: 1]

      # Use all HTML functionality (forms, tags, etc)
      use Phoenix.HTML

      import MusicExFrontend.Router.Helpers
      import MusicExFrontend.ErrorHelpers
      import MusicExFrontend.Gettext
    end
  end

  def router do
    quote do
      use Phoenix.Router
    end
  end

  def channel do
    quote do
      use Phoenix.Channel

      alias MusicExFrontend.Repo
      import Ecto
      import Ecto.Query
      import MusicExFrontend.Gettext
    end
  end

  @doc """
  When used, dispatch to the appropriate controller/view/etc.
  """
  defmacro __using__(which) when is_atom(which) do
    apply(__MODULE__, which, [])
  end
end
