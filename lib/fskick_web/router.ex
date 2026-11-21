defmodule FskickWeb.Router do
  use FskickWeb, :router

  import FskickWeb.UserAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {FskickWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_scope_for_user
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", FskickWeb do
    pipe_through :browser

    post "/users/log-in", UserSessionController, :create
    delete "/users/log-out", UserSessionController, :delete

    # Write-side pages. Any logged-in user may manage data for now; restricting
    # this later means changing only this on_mount. Declared before
    # :current_user so "/players/new" is not swallowed by "/players/:id".
    live_session :manage,
      on_mount: [{FskickWeb.UserAuth, :require_authenticated_user}] do
      live "/players/new", PlayerNewLive, :new
    end

    live_session :current_user,
      on_mount: [{FskickWeb.UserAuth, :mount_current_scope}] do
      live "/", HomeLive, :home
      live "/players", PlayersLive, :index
      live "/players/:id", PlayerDetailLive, :show
      live "/streaks", StreaksLive, :show
      live "/imprint", ImprintLive, :show
    end

    live_session :redirect_if_authenticated,
      on_mount: [{FskickWeb.UserAuth, :redirect_if_authenticated}] do
      live "/users/log-in", UserLoginLive, :new
      live "/users/reset-password", UserForgotPasswordLive, :new
      live "/users/reset-password/:token", UserResetPasswordLive, :edit
    end

    live_session :require_authenticated,
      on_mount: [{FskickWeb.UserAuth, :require_authenticated_user}] do
      live "/users/profile", UserProfileLive, :show
      live "/users/profile/edit", UserProfileEditLive, :edit
    end
  end

  # Other scopes may use custom stacks.
  # scope "/api", FskickWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:fskick, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: FskickWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
