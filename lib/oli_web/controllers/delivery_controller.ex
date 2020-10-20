defmodule OliWeb.DeliveryController do
  use OliWeb, :controller
  alias Oli.Delivery.Sections
  alias Oli.Delivery.Sections.Section
  alias Oli.Publishing
  alias Oli.Institutions
  alias Oli.Lti_1p3.ContextRoles

  def index(conn, _params) do
    user = conn.assigns.current_user
    lti_params = conn.assigns.lti_params

    context_id = lti_params["https://purl.imsglobal.org/spec/lti/claim/context"]["id"]
    section = Sections.get_section_by(context_id: context_id)

    lti_roles = lti_params["https://purl.imsglobal.org/spec/lti/claim/roles"]
    context_roles = ContextRoles.get_roles_by_uris(lti_roles)

    is_student = ContextRoles.contains_role?(context_roles, ContextRoles.get_role(:context_learner))
    case {is_student, user.author, section} do
      {true, _author, nil} ->
        render(conn, "course_not_configured.html", context_id: context_id)

      {true, _author, section} ->
        redirect(conn, to: Routes.page_delivery_path(conn, :index, section.context_id))

      {false, nil, nil} ->
        render(conn, "getting_started.html", context_id: context_id)

      {false, author, nil} ->
        publications = Publishing.available_publications(author)
        my_publications = publications |> Enum.filter(fn p -> !p.open_and_free && p.published end)
        open_and_free_publications = publications |> Enum.filter(fn p -> p.open_and_free && p.published end)
        render(conn, "configure_section.html", context_id: context_id, author: author, my_publications: my_publications, open_and_free_publications: open_and_free_publications)

      {false, _author, section} ->
        redirect(conn, to: Routes.page_delivery_path(conn, :index, section.context_id))
    end

  end

  def list_open_and_free(conn, _params) do
    open_and_free_publications = Publishing.available_publications()
    render(conn, "configure_section.html", open_and_free_publications: open_and_free_publications)
  end

  def link_account(conn, _params) do
    actions = %{
      google: Routes.auth_path(conn, :request, "google", type: "link-account"),
      facebook: Routes.auth_path(conn, :request, "facebook", type: "link-account"),
      identity: Routes.auth_path(conn, :identity_callback, type: "link-account"),
    }

    assigns = conn.assigns
    |> Map.put(:title, "Link Existing Account")
    |> Map.put(:actions, actions)
    |> Map.put(:show_remember_password, false)

    conn
    |> put_view(OliWeb.AuthView)
    |> render("signin.html", assigns)
  end

  def create_and_link_account(conn, _params) do
    actions = %{
      google: Routes.auth_path(conn, :request, "google", type: "link-account"),
      facebook: Routes.auth_path(conn, :request, "facebook", type: "link-account"),
      identity: Routes.auth_path(conn, :register_email_form, type: "link-account"),
    }

    assigns = conn.assigns
    |> Map.put(:title, "Create and Link Account")
    |> Map.put(:actions, actions)
    |> Map.put(:show_remember_password, false)

    conn
    |> put_view(OliWeb.AuthView)
    |> render("register.html", assigns)
  end

  def create_section(conn, %{"publication_id" => publication_id}) do
    lti_params = conn.assigns.lti_params
    user = conn.assigns.current_user
    institution = Institutions.get_institution!(user.institution_id)
    publication = Publishing.get_publication!(publication_id)

    {:ok, %Section{id: section_id}} = Sections.create_section(%{
      time_zone: institution.timezone,
      title: lti_params["https://purl.imsglobal.org/spec/lti/claim/context"]["title"],
      context_id: lti_params["https://purl.imsglobal.org/spec/lti/claim/context"]["id"],
      institution_id: user.institution_id,
      project_id: publication.project_id,
      publication_id: publication_id,
    })

    # Enroll this user with their proper roles (instructor)
    lti_roles = lti_params["https://purl.imsglobal.org/spec/lti/claim/roles"]
    context_roles = ContextRoles.get_roles_by_uris(lti_roles)
    Sections.enroll(user.id, section_id, context_roles)

    conn
    |> redirect(to: Routes.delivery_path(conn, :index))
  end

  def signout(conn, _params) do
    conn
    |> configure_session(drop: true)
    |> redirect(to: Routes.delivery_path(conn, :index))
  end

end
