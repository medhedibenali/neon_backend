defmodule AuthServiceWeb.Router do
  alias AuthServiceWeb.UserController
  alias AuthServiceWeb.KeyController
  use AuthServiceWeb, :router

  pipeline :api do
    plug(:accepts, ["json"])
  end

  scope "/" do
    pipe_through(:api)

    scope "/" do
      resources("/users", UserController)
      post("/login", UserController, :login)
      post("/logout", UserController, :logout)
      post("/register", UserController, :register)
      post("/follow/:follower_id/:following_id", UserController, :follow)
      delete("/unfollow/:follower_id/:following_id", UserController, :unfollow)

      get("/getKey", KeyController, :getKey)
      
    end
  end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:auth_service, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through([:fetch_session, :protect_from_forgery])

      live_dashboard("/dashboard", metrics: AuthServiceWeb.Telemetry)
      forward("/mailbox", Plug.Swoosh.MailboxPreview)
    end
  end
end
