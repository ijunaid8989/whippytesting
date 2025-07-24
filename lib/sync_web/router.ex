defmodule SyncWeb.Router do
  use SyncWeb, :router
  use Kaffy.Routes, scope: "/admin", pipe_through: [:auth]

  import Oban.Web.Router

  pipeline :browser do
    plug(:accepts, ["html"])
    plug(:fetch_session)
    plug(:fetch_live_flash)
    plug(:put_root_layout, html: {SyncWeb.Layouts, :root})
    plug(:protect_from_forgery)
    plug(:put_secure_browser_headers)
  end

  pipeline :api do
    plug(:accepts, ["json"])
  end

  pipeline :auth do
    plug(:basic_auth)
  end

  scope "/", KaffyWeb do
    pipe_through(:browser)

    get("/", HomeController, :index)
  end

  scope "/", SyncWeb do
    pipe_through(:browser)

    get("/health", HealthController, :check)

    scope "/v1" do
      scope "/hubspot", as: :hubspot, alias: Hubspot do
        scope "/auth" do
          get("/connect/:data", AuthController, :new)
          get("/redirect", AuthController, :callback)
        end
      end

      scope path: "/tempworks", as: :tempworks, alias: Tempworks do
        scope "/auth" do
          get("/integrations/:integration_id", AuthController, :new)
          get("/redirect", AuthController, :callback)
        end

        scope "/sync" do
          post("/", SyncController, :create)
        end
      end
    end
  end

  scope "/api", SyncWeb do
    pipe_through([:api, :auth])

    scope "/v1" do
      scope path: "/tempworks", as: :tempworks, alias: Tempworks do
        scope "/jobs" do
          post("/", JobController, :create)
        end
      end

      scope "/integrations", as: :integrations, alias: Integrations do
        put("/:integration_id/channels/external/:external_channel_id", ChannelController, :update)
      end

      scope path: "/admin", as: :admin, alias: Admin do
        scope "/integrations", as: :integrations, alias: Integrations do
          get("/:integration_id/activity_types", ActivityTypeController, :index)
        end
      end
    end
  end

  scope "/oban", SyncWeb do
    pipe_through([:browser, :auth])

    oban_dashboard("/")
  end

  scope "/webhooks", SyncWeb do
    pipe_through([:api])

    scope "/v1" do
      post("/hubspot", Hubspot.WebhookController, :webhook)
      post("/hubspot/send-sms", Hubspot.WebhookController, :send_sms)
      post("/hubspot/channels", Hubspot.WebhookController, :get_channels)
      post("/hubspot/whippy", Hubspot.WebhookController, :whippy)
    end

    scope "/v1" do
      post("/avionte", Avionte.WebhookController, :webhook)
      post("/tempworks", Tempworks.WebhookController, :webhook)
    end
  end

  # Other scopes may use custom stacks.
  # scope "/api", SyncWeb do
  #   pipe_through :api
  # end

  defp basic_auth(conn, _opts) do
    if Mix.env() == :prod or Mix.env() == :test do
      username = System.fetch_env!("DASHBOARD_USERNAME")
      password = System.fetch_env!("DASHBOARD_PASSWORD")

      Plug.BasicAuth.basic_auth(conn, username: username, password: password)
    else
      conn
    end
  end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:sync, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through(:browser)

      live_dashboard("/dashboard", metrics: SyncWeb.Telemetry)
      forward("/mailbox", Plug.Swoosh.MailboxPreview)
    end
  end
end
