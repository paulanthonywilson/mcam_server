defmodule McamServerWeb.Router do
  use McamServerWeb, :router

  import McamServerWeb.UserAuth

  host =
    :mcam_server
    |> Application.compile_env(McamServerWeb.Endpoint)
    |> Keyword.fetch!(:url)
    |> Keyword.fetch!(:host)

  @content_security_policy (case(Mix.env()) do
                              :prod ->
                                "default-src 'self'; connect-src 'self' wss://#{host}; img-src 'self' blob:;"

                              _ ->
                                "default-src 'self' 'unsafe-eval' 'unsafe-inline';" <>
                                  "connect-src 'self' ws://#{host}:*;" <>
                                  "img-src 'self' blob: data:;" <>
                                  "font-src data:;"
                            end)

  pipeline :browser do
    plug(:accepts, ["html"])
    plug(:fetch_session)
    plug(:fetch_live_flash)
    plug(:put_root_layout, {McamServerWeb.LayoutView, :root})
    plug(:protect_from_forgery)
    plug(:put_secure_browser_headers, %{"content-security-policy" => @content_security_policy})
    plug(:fetch_current_user)
  end

  pipeline :api do
    plug(:accepts, ["json"])
  end

  pipeline :fullscreen do
    plug :put_root_layout, {McamServerWeb.LayoutView, :fullscreen_root}
  end

  scope "/", McamServerWeb do
    pipe_through([:browser])

    get("/", RootController, :index)
    live("/landing", PageLive, :index)

    get("/ok", RootController, :ok)
  end

  scope "/api", McamServerWeb do
    pipe_through(:api)
    post("/register_camera", Camera.CameraRegistrationController, :create)
    post("/unregistered_camera", Camera.CameraRegistrationController, :unregistered_camera)
  end

  if Mix.env() in [:dev, :test] do
    import Phoenix.LiveDashboard.Router

    scope "/" do
      pipe_through(:browser)
      live_dashboard("/dashboard", metrics: McamServerWeb.Telemetry)
    end
  end

  ## Authentication routes
  scope "/", McamServerWeb do
    pipe_through([:browser, :redirect_if_user_is_authenticated])

    get("/users/register", UserRegistrationController, :new)
    post("/users/register", UserRegistrationController, :create)

    get("/users/log_in", UserSessionController, :new)
    post("/users/log_in", UserSessionController, :create)
    get("/users/reset_password", UserResetPasswordController, :new)
    post("/users/reset_password", UserResetPasswordController, :create)
    get("/users/reset_password/:token", UserResetPasswordController, :edit)
    put("/users/reset_password/:token", UserResetPasswordController, :update)
  end

  ##  Protected routes
  scope "/", McamServerWeb do
    pipe_through([:browser, :require_confirmed_user])

    live("/cameras", CameraLive, :index)
    live("/camera/:camera_id", CameraLive, :show)

    # This needs to go in the LiveView https://hexdocs.pm/phoenix_live_view/live-layouts.html
    # or maybe use ``
    # in a separate scope
    # ,
    #   layout: {McamServerWeb.LayoutView, :fullscreen_root}
    # )

    live("/camera/:camera_id/:from_camera_id/edit", CameraLive, :edit)

    live("/guest_camera/:camera_id", GuestCameraLive, :show)

    live("/guest_invitations/:invitation_token", AcceptGuestInvitationLive, :new)

    get("/unregistered_cameras", UnregisteredCamerasController, :index)

    get("/users/settings", UserSettingsController, :edit)
    put("/users/settings", UserSettingsController, :update)
    get("/users/settings/confirm_email/:token", UserSettingsController, :confirm_email)
  end

  scope "/fullscreen", McamServerWeb do
    pipe_through([:browser, :require_confirmed_user, :fullscreen])

    live("/camera/:camera_id", CameraLive, :fullscreen)
    live("/guest_camera/:camera_id", GuestCameraLive, :fullscreen)
  end

  # For unconfirmed but authenticated
  scope "/", McamServerWeb do
    pipe_through([:browser, :require_authenticated_user])

    get(
      "/users/registration_confirmation",
      UserRegistrationController,
      :registration_confirmation
    )
  end

  scope "/", McamServerWeb do
    pipe_through [:browser]

    delete "/users/log_out", UserSessionController, :delete
    get "/users/confirm", UserConfirmationController, :new
    post "/users/confirm", UserConfirmationController, :create
    get "/users/confirm/:token", UserConfirmationController, :edit
    post "/users/confirm/:token", UserConfirmationController, :update
  end
end
