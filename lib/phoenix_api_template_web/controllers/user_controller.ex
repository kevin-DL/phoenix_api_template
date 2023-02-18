defmodule PhoenixApiTemplateWeb.UserController do
  use PhoenixApiTemplateWeb, :controller

  alias PhoenixApiTemplateWeb.Auth.ErrorResponse
  alias PhoenixApiTemplateWeb.Auth.ErrorResponse.Unauthorized
  alias PhoenixApiTemplateWeb.Auth.Guardian
  alias PhoenixApiTemplate.Accounts
  alias PhoenixApiTemplate.Accounts.User
  alias PhoenixApiTemplate.Profiles
  alias PhoenixApiTemplate.Profiles.Profile

  plug :is_authorized_user when action in [:update, :delete]

  action_fallback(PhoenixApiTemplateWeb.FallbackController)

  defp is_authorized_user(conn, _options) do
    %{params: %{"id" => id}} = conn
    user = Accounts.get_user!(id)

    if conn.assigns.user.id == user.id do
      conn
    else
      raise ErrorResponse.Forbidden
    end
  end

  def index(conn, _params) do
    users = Accounts.list_users()
    render(conn, "index.json", users: users)
  end

  def create(conn, %{"user" => %{"profile" => profile_params} = user_params}) do
    with {:ok, %User{} = user} <- Accounts.create_user(user_params),
         {:ok, token, _claims} <- Guardian.encode_and_sign(user),
         {:ok, %Profile{} = _profile} <- Profiles.create_profile(user, profile_params) do
      conn
      |> put_status(:created)
      |> render("user_token.json", user: user, token: token)
    end
  end

  def sign_in(conn, %{"email" => email, "password" => password}) do
    case Guardian.authenticate(email, password) do
      {:ok, user, token} ->
        conn
        |> Plug.Conn.put_session(:user_id, user.id)
        |> put_status(:ok)
        |> render("user_token.json", %{user: user, token: token})

      {:error, :unauthorized} ->
        raise Unauthorized, message: "Invalid credentials"
    end
  end

  def show(conn, %{"id" => id}) do
    user = Accounts.get_user!(id)
    render(conn, "show.json", user: user)
  end

  def update(conn, %{"id" => id, "user" => user_params}) do
    user = Accounts.get_user!(id)

    with {:ok, %User{} = user} <- Accounts.update_user(user, user_params) do
      render(conn, "show.json", user: user)
    end
  end

  def delete(conn, %{"id" => id}) do
    user = Accounts.get_user!(id)

    with {:ok, %User{}} <- Accounts.delete_user(user) do
      send_resp(conn, :no_content, "")
    end
  end
end
