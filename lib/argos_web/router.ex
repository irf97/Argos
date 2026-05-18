defmodule ArgosWeb.Router do
  use ArgosWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {ArgosWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", ArgosWeb do
    pipe_through :browser

    get "/", PageController, :home
    live "/approvals", ApprovalQueueLive
  end

  scope "/api", ArgosWeb.Api do
    pipe_through :api

    get "/health", HealthController, :show
    get "/schema", SchemaController, :show
    get "/mcp-documents/events/:id", MCPDocumentController, :show_event
    get "/mcp-documents/canons/:id", MCPDocumentController, :show_canon
    post "/capture", CaptureController, :create
    get "/events", EventController, :index
    get "/canon/:name", CanonController, :show
    post "/canon/:name/draft", CanonController, :draft
    get "/approvals", ApprovalController, :index
    post "/approvals/:id/approve", ApprovalController, :approve
    post "/approvals/:id/reject", ApprovalController, :reject
    post "/context-pack", ContextPackController, :create
    get "/context-pack/:hash", ContextPackController, :show
    post "/arms/session/start", ArmSessionController, :start
    post "/arms/session/end", ArmSessionController, :end_session
    post "/outcomes", OutcomeController, :create
    get "/proposals", ProposalController, :index
    post "/proposals/detect", ProposalController, :detect
    get "/autonomous-mutations", AutonomousMutationController, :index
    post "/autonomous-mutations/:proposal_id/rollback", AutonomousMutationController, :rollback
    post "/crawl", CrawlController, :create
    post "/crawl-and-ingest", CrawlController, :crawl_and_ingest
    get "/crawl-jobs", CrawlController, :index
    get "/crawl-jobs/:id", CrawlController, :show
  end

  scope "/", ArgosWeb.Api do
    pipe_through :api

    get "/mcp", MCPController, :stream_unavailable
    post "/mcp", MCPController, :handle
  end
end
