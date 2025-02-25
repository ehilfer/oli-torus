# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
use Mix.Config

config :elixir, :time_zone_database, Tzdata.TimeZoneDatabase

world_universities_and_domains_json =
  case File.read("./priv/data/world_universities_and_domains.json") do
    {:ok, body} ->
      body

    _ ->
      "[]"
  end

default_sha = if Mix.env() == :dev, do: "DEV BUILD", else: "UNKNOWN BUILD"

config :oli,
  node_js_pool_size: String.to_integer(System.get_env("NODE_JS_POOL_SIZE", "10")),
  load_testing_mode: :disabled,
  problematic_query_detection: :disabled,
  problematic_query_cost_threshold: 150,
  ecto_repos: [Oli.Repo],
  build: %{
    version: Mix.Project.config()[:version],
    sha: System.get_env("SHA", default_sha),
    date: DateTime.now!("Etc/UTC"),
    env: Mix.env()
  },
  local_activity_manifests:
    Path.wildcard(File.cwd!() <> "/assets/src/components/activities/*/manifest.json")
    |> Enum.map(&File.read!/1),
  local_part_component_manifests:
    Path.wildcard(File.cwd!() <> "/assets/src/components/parts/*/manifest.json")
    |> Enum.map(&File.read!/1),
  email_from_name: System.get_env("EMAIL_FROM_NAME", "OLI Torus"),
  email_from_address: System.get_env("EMAIL_FROM_ADDRESS", "admin@example.edu"),
  email_reply_to: System.get_env("EMAIL_REPLY_TO", "admin@example.edu"),
  world_universities_and_domains_json: world_universities_and_domains_json,
  branding: [
    name: System.get_env("BRANDING_NAME", "OLI Torus"),
    logo: System.get_env("BRANDING_LOGO", "/images/oli_torus_logo.png"),
    logo_dark:
      System.get_env(
        "BRANDING_LOGO_DARK",
        System.get_env("BRANDING_LOGO", "/images/oli_torus_logo_dark.png")
      ),
    favicons: System.get_env("BRANDING_FAVICONS_DIR", "/favicons")
  ],
  payment_provider: System.get_env("PAYMENT_PROVIDER", "none")

default_description = """
The Open Learning Initiative enables research and experimentation with all aspects of the learning experience.
As a leader in higher education's innovation of online learning, we're a growing research and production project exploring effective approaches since the early 2000s.
"""

config :oli, :vendor_property,
  workspace_logo: System.get_env("VENDOR_PROPERTY_WORKSPACE_LOGO", "/images/torus-icon.png"),
  product_full_name:
    System.get_env("VENDOR_PROPERTY_PRODUCT_FULL_NAME", "Open Learning Initiative"),
  product_short_name: System.get_env("VENDOR_PROPERTY_PRODUCT_SHORT_NAME", "OLI Torus"),
  product_description:
    System.get_env(
      "VENDOR_PROPERTY_PRODUCT_DESCRIPTION",
      default_description
    ),
  product_learn_more_link:
    System.get_env("VENDOR_PROPERTY_PRODUCT_LEARN_MORE_LINK", "https://oli.cmu.edu"),
  company_name: System.get_env("VENDOR_PROPERTY_COMPANY_NAME", "Carnegie Mellon University"),
  company_address:
    System.get_env(
      "VENDOR_PROPERTY_COMPANY_ADDRESS",
      "5000 Forbes Ave, Pittsburgh, PA 15213 US"
    )

config :oli, :stripe_provider,
  public_secret: System.get_env("STRIPE_PUBLIC_SECRET"),
  private_secret: System.get_env("STRIPE_PRIVATE_SECRET")

# Configure database
config :oli, Oli.Repo, migration_timestamps: [type: :timestamptz]

# Configures the endpoint
config :oli, OliWeb.Endpoint,
  live_view: [signing_salt: System.get_env("LIVE_VIEW_SALT", "LIVE_VIEW_SALT")],
  url: [host: "localhost"],
  secret_key_base: "GE9cpXBwVXNaplyUCYbIWqERmC/OlcR5iVMwLX9/W7gzQRxkD1ETjda9E0jW/BW1",
  render_errors: [view: OliWeb.ErrorView, accepts: ~w(html json)],
  pubsub_server: Oli.PubSub

config :oli, Oban,
  repo: Oli.Repo,
  plugins: [Oban.Plugins.Pruner],
  queues: [default: 10, snapshots: 20, selections: 2, updates: 10]

config :ex_money,
  auto_start_exchange_rate_service: false,
  default_cldr_backend: Oli.Cldr,
  json_library: Jason

config :surface, :components, [
  {Surface.Components.Form.ErrorTag, default_translator: {OliWeb.ErrorHelpers, :translate_error}}
]

# Configure reCAPTCHA
config :oli, :recaptcha,
  verify_url: "https://www.google.com/recaptcha/api/siteverify",
  timeout: 5000,
  site_key: System.get_env("RECAPTCHA_SITE_KEY"),
  secret: System.get_env("RECAPTCHA_PRIVATE_KEY")

# Configure help
# HELP_PROVIDER env var must be a string representing an existing provider module, such as "EmailHelp"
help_provider =
  case System.get_env("HELP_PROVIDER") do
    nil -> Oli.Help.Providers.EmailHelp
    provider -> Module.concat([Oli, Help, Providers, provider])
  end

config :oli, :help, dispatcher: help_provider

config :lti_1p3,
  provider: Lti_1p3.DataProviders.EctoProvider,
  ecto_provider: [
    repo: Oli.Repo,
    schemas: [
      user: Oli.Accounts.User,
      registration: Oli.Lti_1p3.Tool.Registration,
      deployment: Oli.Lti_1p3.Tool.Deployment
    ]
  ]

config :ex_aws,
  access_key_id: [{:system, "AWS_ACCESS_KEY_ID"}, :instance_role],
  secret_access_key: [{:system, "AWS_SECRET_ACCESS_KEY"}, :instance_role]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

if Mix.env() == :dev do
  config :mix_test_watch,
    clear: true
end

# Configure Mnesia directory (used by pow persistent sessions)
config :mnesia, :dir, to_charlist(System.get_env("MNESIA_DIR", ".mnesia"))

config :appsignal, :config, revision: System.get_env("SHA", default_sha)

config :surface, :components, [
  {
    Surface.Components.Form.ErrorTag,
    default_class: "help-block", default_translator: {OliWeb.ErrorHelpers, :translate_error}
  }
]

# Configure Privacy Policies link
config :oli, :privacy_policies,
  url: System.get_env("PRIVACY_POLICIES_URL", "https://www.cmu.edu/legal/privacy-notice.html")

# Configure footer text and links
config :oli, :footer,
  text: System.get_env("FOOTER_TEXT", ""),
  link_1_location: System.get_env("FOOTER_LINK_1_LOCATION", ""),
  link_1_text: System.get_env("FOOTER_LINK_1_TEXT", ""),
  link_2_location: System.get_env("FOOTER_LINK_2_LOCATION", ""),
  link_2_text: System.get_env("FOOTER_LINK_2_TEXT", "")

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"
