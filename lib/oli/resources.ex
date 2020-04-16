defmodule Oli.Resources do
  @moduledoc """
  The Resources context.
  """

  import Ecto.Query, warn: false
  alias Oli.Repo

  alias Oli.Course.Project
  alias Oli.Accounts.Author
  alias Oli.Resources.Resource
  alias Oli.Resources.ResourceType
  alias Oli.Resources.ResourceRevision
  alias Oli.Resources.ResourceFamily
  alias Oli.Publishing
  alias Oli.Course.Utils

  def create_resource_family(attrs \\ %{}) do
    %ResourceFamily{}
    |> ResourceFamily.changeset(attrs)
    |> Repo.insert()
  end

  def new_resource_family() do
    %ResourceFamily{}
      |> ResourceFamily.changeset(%{
      })
  end

  @doc """
  Returns the list of resources.

  ## Examples

      iex> list_resources()
      [%Resource{}, ...]

  """
  def list_resources do
    Repo.all(Resource)
  end

  @doc """
  Gets a single resource.

  Raises `Ecto.NoResultsError` if the Resource does not exist.

  ## Examples

      iex> get_resource!(123)
      %Resource{}

      iex> get_resource!(456)
      ** (Ecto.NoResultsError)

  """
  def get_resource!(id), do: Repo.get!(Resource, id)


  @doc """
  Gets a single resource, based on a revision and project slug.
  """
  @spec get_resource_from_slugs(String.t, String.t) :: any
  def get_resource_from_slugs(project, revision) do
    query = from r in Resource,
          distinct: r.id,
          join: p in Project, on: r.project_id == p.id,
          join: v in ResourceRevision, on: v.resource_id == r.id,
          where: p.slug == ^project and v.slug == ^revision,
          select: r
    Repo.one(query)
  end

  def new_project_resource(project, family) do
    %Resource{}
      |> Resource.changeset(%{
        project_id: project.id, family_id: family.id
      })
  end

  def create_project_resource(
    %{objectives: _, children: _, content: _, title: _} = attrs,
    %ResourceType{} = resource_type,
    %Author{} = author,
    %Project{} = project
  ) do
    {:ok, family} = create_resource_family()
    create_project_resource(attrs, resource_type, author, project, family)
  end

  def create_project_resource(
    %{objectives: _, children: _, content: _, title: title} = attrs,
    %ResourceType{} = resource_type,
    %Author{} = author,
    %Project{} = project,
    %ResourceFamily{} = family
  ) do
    with {:ok, resource} <- new_project_resource(project, family) |> Repo.insert,
         attrs <- Map.merge(attrs, %{
           author_id: author.id,
           resource_type_id: resource_type.id,
           resource_id: resource.id,
           slug: Utils.generate_slug("resource_revisions", title)
         }),
         {:ok, revision} <- create_resource_revision(attrs),
         publication <- Publishing.get_unpublished_publication_by_slug!(project.slug),
         {:ok, mapping} <- Publishing.create_resource_mapping(%{ publication_id: publication.id, resource_id: resource.id, revision_id: revision.id})
    do
      {:ok, %{resource: resource, revision: revision, project: project, family: family, mapping: mapping}}
    else
      error -> error
    end
  end

  @doc """
  Updates a resource.

  ## Examples

      iex> update_resource(resource, %{field: new_value})
      {:ok, %Resource{}}

      iex> update_resource(resource, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_resource(%Resource{} = resource, attrs) do
    resource
    |> Resource.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a resource.

  ## Examples

      iex> delete_resource(resource)
      {:ok, %Resource{}}

      iex> delete_resource(resource)
      {:error, %Ecto.Changeset{}}

  """
  def delete_resource(%Resource{} = resource) do
    Repo.delete(resource)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking resource changes.

  ## Examples

      iex> change_resource(resource)
      %Ecto.Changeset{source: %Resource{}}

  """
  def change_resource(%Resource{} = resource) do
    Resource.changeset(resource, %{})
  end

  def get_latest_resource_revision(resource, project) do
    publication = Publishing.get_unpublished_publication_by_slug!(project.slug)
    mapping = Publishing.get_resource_mapping!(publication.id, resource.id)

    get_resource_revision!(mapping.revision_id)
  end

  alias Oli.Resources.ResourceType

  @doc """
  Enumerates all the resource_types
  """
  def resource_type, do: %{
    unscored_page: Oli.Repo.get(ResourceType, 1),
    scored_page: Oli.Repo.get(ResourceType, 2),
    container: Oli.Repo.get(ResourceType, 3),
  }

  @doc """
  Returns the list of resource_types.

  ## Examples

      iex> list_resource_types()
      [%ResourceType{}, ...]

  """
  def list_resource_types do
    Repo.all(ResourceType)
  end

  @doc """
  Gets a single resource_type.

  Raises `Ecto.NoResultsError` if the Resource type does not exist.

  ## Examples

      iex> get_resource_type!(123)
      %ResourceType{}

      iex> get_resource_type!(456)
      ** (Ecto.NoResultsError)

  """
  def get_resource_type!(id), do: Repo.get!(ResourceType, id)

  @doc """
  Creates a resource_type.

  ## Examples

      iex> create_resource_type(%{field: value})
      {:ok, %ResourceType{}}

      iex> create_resource_type(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_resource_type(attrs \\ %{}) do
    %ResourceType{}
    |> ResourceType.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a resource_type.

  ## Examples

      iex> update_resource_type(resource_type, %{field: new_value})
      {:ok, %ResourceType{}}

      iex> update_resource_type(resource_type, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_resource_type(%ResourceType{} = resource_type, attrs) do
    resource_type
    |> ResourceType.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a resource_type.

  ## Examples

      iex> delete_resource_type(resource_type)
      {:ok, %ResourceType{}}

      iex> delete_resource_type(resource_type)
      {:error, %Ecto.Changeset{}}

  """
  def delete_resource_type(%ResourceType{} = resource_type) do
    Repo.delete(resource_type)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking resource_type changes.

  ## Examples

      iex> change_resource_type(resource_type)
      %Ecto.Changeset{source: %ResourceType{}}

  """
  def change_resource_type(%ResourceType{} = resource_type) do
    ResourceType.changeset(resource_type, %{})
  end

  alias Oli.Resources.ResourceRevision

  @doc """
  Returns the list of resource_revisions.

  ## Examples

      iex> list_resource_revisions()
      [%ResourceRevision{}, ...]

  """
  def list_resource_revisions do
    Repo.all(ResourceRevision)
  end

  @doc """
  Gets a single resource_revision.

  Raises `Ecto.NoResultsError` if the Resource revision does not exist.

  ## Examples

      iex> get_resource_revision!(123)
      %ResourceRevision{}

      iex> get_resource_revision!(456)
      ** (Ecto.NoResultsError)

  """
  def get_resource_revision!(id), do: Repo.get!(ResourceRevision, id)

  @doc """
  Creates a resource_revision.

  ## Examples

      iex> create_resource_revision(%{field: value})
      {:ok, %ResourceRevision{}}

      iex> create_resource_revision(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_resource_revision(attrs \\ %{}) do
    %ResourceRevision{}
    |> ResourceRevision.changeset(attrs)
    |> Repo.insert()
  end

  def new_project_resource_revision(author, project, resource) do
    %ResourceRevision{}
      |> ResourceRevision.changeset(%{
        slug: project.slug <> "_root_container",
        title: project.title <> " root container",
        author_id: author.id,
        resource_id: resource.id,
        resource_type_id: Repo.one!(
          from rt in "resource_types",
          where: rt.type == "container",
          select: rt.id)
      })
  end

  @doc """
  Updates a resource_revision.

  ## Examples

      iex> update_resource_revision(resource_revision, %{field: new_value})
      {:ok, %ResourceRevision{}}

      iex> update_resource_revision(resource_revision, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_resource_revision(%ResourceRevision{} = resource_revision, attrs) do
    resource_revision
    |> ResourceRevision.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a resource_revision.

  ## Examples

      iex> delete_resource_revision(resource_revision)
      {:ok, %ResourceRevision{}}

      iex> delete_resource_revision(resource_revision)
      {:error, %Ecto.Changeset{}}

  """
  def delete_resource_revision(%ResourceRevision{} = resource_revision) do
    Repo.delete(resource_revision)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking resource_revision changes.

  ## Examples

      iex> change_resource_revision(resource_revision)
      %Ecto.Changeset{source: %ResourceRevision{}}

  """
  def change_resource_revision(%ResourceRevision{} = resource_revision) do
    ResourceRevision.changeset(resource_revision, %{})
  end
end
