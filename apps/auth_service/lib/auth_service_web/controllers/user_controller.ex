defmodule AuthServiceWeb.UserController do
  use AuthServiceWeb, :controller

  alias AuthService.Accounts
  alias AuthService.ImageChecker
  alias AuthService.FileUploader
  alias AuthService.Accounts.User
  alias AuthService.Guardian
  alias Argon2

  action_fallback(AuthServiceWeb.FallbackController)

  # def new(conn, _) do
  #   changeset = Accounts.change_user(%User{})
  #   maybe_user = Guardian.Plug.current_resource(conn)

  #   if maybe_user do
  #     redirect(conn, to: "/protected")
  #   else
  #     render(conn, "new.html", changeset: changeset, action: Routes.session_path(conn, :login))
  #   end
  # end

  def follow(conn, %{"follower_id" => follower_id, "following_id" => following_id}) do
    Accounts.follow_user(follower_id, following_id)

    conn
    |> put_status(:created)
    |> json(%{"message" => "follow successful"})
  end

  def unfollow(conn, %{"follower_id" => follower_id, "following_id" => following_id}) do
    case Accounts.unfollow_user(follower_id, following_id) do
      {:ok, message} ->
        conn
        |> put_status(:ok)
        |> json(%{"message" => message})

      {:error, message} ->
        conn
        |> put_status(:bad_request)
        |> json(%{"error" => message})
    end
  end

  def register(conn, user_params) do
    with {:ok, %User{} = user} <- Accounts.create_user(user_params) do
      conn
      |> put_status(:created)
      |> auth_reply(user)
    end
  end

  def login(conn, %{"email" => email, "password" => password}) do
    Accounts.authenticate_user(email, password)
    |> auth_reply(conn)
  end

  def logout(conn, _) do
    conn
    # This module's full name is Auth.Accounts.Guardian.Plug,
    |> Guardian.Plug.sign_out()

    # and the arguments specified in the Guardian.Plug.sign_out()
    |> json(:ok)
  end

  defp auth_reply({:ok, user}, conn) do
    conn
    |> Guardian.Plug.sign_in(user, %{username: user.username})
    |> parse_auth_response()
  end

  defp auth_reply({:error, reason}, conn) do
    conn
    |> put_status(:unauthorized)
    |> json(%{"error" => reason})
  end

  defp auth_reply(conn, user) do
    auth_reply({:ok, user}, conn)
  end

  defp parse_auth_response(conn) do
    json(conn, %{"token" => conn.private.guardian_default_token})
  end

  def index(conn, _params) do
    users = Accounts.list_users()
    render(conn, :index, users: users)
  end

  def create(conn, %{"user" => user_params}) do
    with {:ok, %User{} = user} <- Accounts.create_user(user_params) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", ~p"/users/#{user}")
      |> render(:show, user: user)
    end
  end

  def show(conn, %{"id" => id}) do
    user = Accounts.get_user!(id)
    render(conn, :show, user: user)
  end

  def update(conn, %{"id" => id} = user_params) do
    user = Accounts.get_user!(id)
    %{"confirmPassword" => plain_password} = user_params

    if Argon2.verify_pass(plain_password, user.password) do
      user_params =
        if(
          (upload = user_params["profile_picture"]) &&
            ImageChecker.is_image?(user_params["profile_picture"])
        ) do
          path =
            :code.priv_dir(:auth_service)
            |> Path.join("static/uploads/profile_pictures/")

          file = FileUploader.upload_file(upload, path)
          %{user_params | "profile_picture" => "/uploads/#{file}"}
        else
          user_params
        end

      with {:ok, %User{} = user} <- Accounts.update_user(user, user_params) do
        render(conn, :show, user: user)
      end
    else
      conn
      |> put_status(:invalid_credentials)
      |> json(%{"error" => "wrong password"})
    end
  end

  def delete(conn, %{"id" => id}) do
    user = Accounts.get_user!(id)

    with {:ok, %User{}} <- Accounts.delete_user(user) do
      send_resp(conn, :no_content, "")
    end
  end
end
