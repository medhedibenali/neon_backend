defmodule AuthService.Accounts do
  @moduledoc """
  The Accounts context.
  """

  import Ecto.Query, warn: false
  alias AuthService.Accounts.Follow
  alias AuthService.Accounts.User
  alias AuthService.FileUploader
  alias AuthService.Repo

  alias Argon2

  def fetch_preloaded_user(user_id) do
    preloads = [:followers, :following]

    query = from u in User, where: u.id == ^user_id, preload: ^preloads
    Repo.one!(query)
  end

  def follow_user(follower_id, following_id) do
    follower = fetch_preloaded_user(follower_id)

    fetch_preloaded_user(following_id)
    |> User.changeset_add_follower(follower)
  end

  def unfollow_user(follower_id, following_id) do
    query = from f in Follow, where: [follower_id: ^follower_id, following_id: ^following_id]

    case Repo.delete_all(query) do
      {0, _f} ->
        {:error, "follow relationship unexistent"}

      _ ->
        {:ok, "unfollow successful"}
    end
  end


  def authenticate_user(email, plain_password) do
    query = from(u in User, where: u.email == ^email)

    case Repo.one(query) do
      nil ->
        Argon2.no_user_verify()
        {:error, :invalid_credentials}

      user ->
        if Argon2.verify_pass(plain_password, user.password) do
          {:ok, user}
        else
          {:error, :invalid_credentials}
        end
    end
  end

  @doc """
  Returns the list of users.

  ## Examples

      iex> list_users()
      [%User{}, ...]

  """
  def list_users do
    Repo.all(User)
  end

  @doc """
  Gets a single user.

  Raises `Ecto.NoResultsError` if the User does not exist.

  ## Examples

      iex> get_user!(123)
      %User{}

      iex> get_user!(456)
      ** (Ecto.NoResultsError)

  """
  def get_user!(id), do: Repo.get!(User, id)

  @doc """
  Creates a user.

  ## Examples

      iex> create_user(%{field: value})
      {:ok, %User{}}

      iex> create_user(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_user(attrs \\ %{}) do
    attrs =
      if(
        (upload = attrs["profile_picture"]) && ImageChecker.is_image?(attrs["profile_picture"])
      ) do
        path =
          :code.priv_dir(:auth_service)
          |> Path.join("static/uploads/profile_pictures/")

        file = FileUploader.upload_file(upload, path)
        %{attrs | "profile_picture" => "/uploads/#{file}"}
      else
        Map.put(attrs, "profile_picture", "/uploads/default.jpg")
      end

    %User{}
    |> User.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a user.

  ## Examples

      iex> update_user(user, %{field: new_value})
      {:ok, %User{}}

      iex> update_user(user, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_user(%User{} = user, attrs) do
    user
    |> User.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a user.

  ## Examples

      iex> delete_user(user)
      {:ok, %User{}}

      iex> delete_user(user)
      {:error, %Ecto.Changeset{}}

  """
  def delete_user(%User{} = user) do
    Repo.delete(user)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking user changes.

  ## Examples

      iex> change_user(user)
      %Ecto.Changeset{data: %User{}}

  """
  def change_user(%User{} = user, attrs \\ %{}) do
    User.changeset(user, attrs)
  end
end
