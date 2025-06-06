defmodule Glific.Flows.FlowLabel do
  @moduledoc """
  The flow label object
  """
  use Ecto.Schema
  import Ecto.Changeset

  import Ecto.Query, warn: false

  alias __MODULE__

  alias Glific.{
    Flows.FlowLabel,
    Partners.Organization,
    Repo
  }

  @required_fields [:uuid, :name, :organization_id]
  @optional_fields [:type]

  @type t() :: %__MODULE__{
          __meta__: Ecto.Schema.Metadata.t(),
          id: non_neg_integer | nil,
          uuid: Ecto.UUID.t() | nil,
          name: String.t() | nil,
          type: String.t() | nil,
          organization_id: non_neg_integer | nil,
          organization: Organization.t() | Ecto.Association.NotLoaded.t() | nil,
          inserted_at: :utc_datetime | nil,
          updated_at: :utc_datetime | nil
        }

  schema "flow_labels" do
    field :uuid, Ecto.UUID
    field :name, :string
    field :type, :string

    belongs_to :organization, Organization

    timestamps(type: :utc_datetime)
  end

  @doc """
  Glific.Flows.FlowLabel.list_flow_label()
  Standard changeset pattern we use for all data types

  """
  @spec changeset(any(), map()) :: Ecto.Changeset.t()
  def changeset(flow_label, attrs) do
    flow_label
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> unique_constraint([:name, :organization_id])
  end

  @doc """
  Given a organization id, retrieve all the flow labels for organization
  """
  @spec get_all_flowlabel(non_neg_integer) :: [FlowLabel.t()]
  def get_all_flowlabel(organization_id) do
    query =
      FlowLabel
      |> where([m], m.organization_id == ^organization_id)
      |> select([m], %{uuid: m.uuid, name: m.name})

    Repo.all(query)
  end

  @doc """
  Creates a flow_label.

  ## Examples

      iex> create_flow_label(%{field: value})
      {:ok, %FlowLabel{}}

      iex> create_flow_label(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  @spec create_flow_label(map()) ::
          {:ok, FlowLabel.t()} | {:error, Ecto.Changeset.t()}
  def create_flow_label(%{organization_id: organization_id} = attrs) do
    uuid = Ecto.UUID.generate()

    attrs =
      attrs
      |> Map.put(:uuid, uuid)
      |> Map.put(:organization_id, organization_id)

    %FlowLabel{}
    |> FlowLabel.changeset(attrs)
    |> Repo.insert(
      on_conflict: [set: [name: attrs.name]],
      conflict_target: [:name, :organization_id],
      returning: true
    )
  end

  @doc """
  Try to first get the flow label, if not present, create it. We don't use the upsert function, since
  it consumes id's for every failure. we expect a lot more gets, than inserts
  """
  @spec get_or_create_flow_label(map()) :: {:ok, FlowLabel.t()} | {:error, Ecto.Changeset.t()}
  def get_or_create_flow_label(attrs) do
    case Repo.fetch_by(FlowLabel, attrs) do
      {:ok, flow_label} -> {:ok, flow_label}
      _ -> create_flow_label(attrs)
    end
  end

  @doc """
  Return the count of flow labels, using the same filter as list_flow_labels
  """
  @spec list_flow_labels(map()) :: list()
  def list_flow_labels(args) do
    Repo.list_filter(args, FlowLabel, &Repo.opts_with_inserted_at/2, &Repo.filter_with/2)
  end

  @doc """
  Return the count of flow labels, using the same filter as list_flow_labels
  """
  @spec count_flow_labels(map()) :: integer
  def count_flow_labels(args),
    do: Repo.count_filter(args, FlowLabel, &Repo.filter_with/2)
end
