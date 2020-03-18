defmodule OliWeb.Router do
  use OliWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_flash
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug Oli.Plugs.SetCurrentUser
  end

  pipeline :protected do
    plug Oli.Plugs.Protect
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :lti do
    plug :put_layout, {OliWeb.LayoutView, :lti}
  end

  pipeline :www_url_form do
    plug Plug.Parsers, parsers: [:urlencoded]
  end

  # open access routes
  scope "/", OliWeb do
    pipe_through :browser

    get "/", PageController, :index
  end

  # authorization protected routes
  scope "/", OliWeb do
    pipe_through [:browser, :protected]

    resources "/institutions", InstitutionController
  end

  # auth routes, only accessable to guest users who are not logged in
  scope "/auth", OliWeb do
    pipe_through [:browser, OliWeb.Plugs.Guest]

    get "/signin", AuthController, :signin

    get "/register", AuthController, :register
    get "/register/email", AuthController, :register_email_form
    post "/register/email", AuthController, :register_email_submit
  end

  scope "/auth", OliWeb do
    pipe_through [:browser]

    get "/signout", AuthController, :signout

    post "/identity/callback", AuthController, :identity_callback

    get "/:provider", AuthController, :request
    get "/:provider/callback", AuthController, :callback
  end

  # LTI routes
  scope "/lti", OliWeb do
    pipe_through [:lti, :www_url_form]

    post "/basic_launch", LtiController, :basic_launch
  end

  # routes only accessable to developers
  if "#{Mix.env}" === "dev" or "#{Mix.env}" === "test" do
    scope "/dev", OliWeb do
      pipe_through :browser

      get "/uipalette", UIPaletteController, :index
    end

    scope "/test", OliWeb do
      pipe_through :browser

      get "/editor", EditorTestController, :index

    end
  end

  # Other scopes may use custom stacks.
  # scope "/api", OliWeb do
  #   pipe_through :api
  # end
end
