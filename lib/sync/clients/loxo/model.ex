defmodule Sync.Clients.Loxo.Model.ActivityType do
  @moduledoc """
  This module defines the struct for the ActivityType model. This is how Lexo
  represents a ActivityType in the response of "Get Activity Types" endpoint.

  An example request can be found here:
  https://whippy-ai.postman.co/workspace/Whippy-API-Workspace~9cf2c9ab-d8a3-49fd-8c90-1e584625b59f/request/11837100-bb43bd2d-3a81-4268-8882-66a98acead52
  """

  @derive Jason.Encoder

  defstruct [:id, :key, :name, :position, :children, :hidden]

  @type t :: %__MODULE__{
          id: integer(),
          key: String.t(),
          name: String.t(),
          position: integer(),
          children: list(),
          hidden: boolean()
        }

  @types %{
    id: :integer,
    key: :string,
    name: :string,
    position: :integer,
    children: {:array, :map},
    hidden: :boolean
  }

  def to_struct!(params) do
    {%__MODULE__{}, @types}
    |> Ecto.Changeset.cast(params, Map.keys(@types))
    |> Ecto.Changeset.apply_action!(:cast)
  end
end

defmodule Sync.Clients.Loxo.Model.Person do
  @moduledoc """
  This module defines the struct for the Person model. This is how Lexo
  represents a Person in the response of "Get People" endpoint.
  """

  @derive Jason.Encoder

  defstruct [
    :id,
    :name,
    :profile_picture_thumb_url,
    :location,
    :address,
    :city,
    :state,
    :zip,
    :country,
    :current_title,
    :current_company,
    :current_compensation,
    :compensation,
    :compensation_notes,
    :compensation_currency_id,
    :salary,
    :salary_type_id,
    :bonus_payment_type_id,
    :bonus_type_id,
    :bonus,
    :equity_type_id,
    :equity,
    :person_types,
    :owned_by_id,
    :created_at,
    :updated_at,
    :created_by_id,
    :updated_by_id,
    :emails,
    :phones,
    :blocked,
    :blocked_until,
    :list_ids,
    :candidate_jobs,
    :linkedin_url,
    :person_global_status,
    :all_raw_tags,
    :skillsets,
    :source_type
  ]

  @type t :: %__MODULE__{
          id: integer(),
          name: String.t(),
          profile_picture_thumb_url: String.t(),
          location: any(),
          address: any(),
          city: any(),
          state: any(),
          zip: any(),
          country: any(),
          current_title: any(),
          current_company: any(),
          current_compensation: any(),
          compensation: any(),
          compensation_notes: any(),
          compensation_currency_id: any(),
          salary: any(),
          salary_type_id: any(),
          bonus_payment_type_id: any(),
          bonus_type_id: any(),
          bonus: any(),
          equity_type_id: any(),
          equity: any(),
          person_types: list(map()),
          owned_by_id: any(),
          created_at: String.t(),
          updated_at: String.t(),
          created_by_id: any(),
          updated_by_id: any(),
          emails: list(map()),
          phones: list(map()),
          blocked: boolean(),
          blocked_until: any(),
          list_ids: list(),
          candidate_jobs: list(),
          linkedin_url: String.t(),
          person_global_status: any(),
          all_raw_tags: String.t(),
          skillsets: any(),
          source_type: map()
        }

  @types %{
    id: :integer,
    name: :string,
    profile_picture_thumb_url: :string,
    location: :any,
    address: :any,
    city: :any,
    state: :any,
    zip: :any,
    country: :any,
    current_title: :any,
    current_company: :any,
    current_compensation: :any,
    compensation: :any,
    compensation_notes: :any,
    compensation_currency_id: :any,
    salary: :any,
    salary_type_id: :any,
    bonus_payment_type_id: :any,
    bonus_type_id: :any,
    bonus: :any,
    equity_type_id: :any,
    equity: :any,
    person_types: {:array, :map},
    owned_by_id: :any,
    created_at: :string,
    updated_at: :string,
    created_by_id: :any,
    updated_by_id: :any,
    emails: {:array, :map},
    phones: {:array, :map},
    blocked: :boolean,
    blocked_until: :any,
    list_ids: {:array, :any},
    candidate_jobs: {:array, :any},
    linkedin_url: :string,
    person_global_status: :any,
    all_raw_tags: :string,
    skillsets: :any,
    source_type: :map
  }

  def to_struct!(params) do
    {%__MODULE__{}, @types}
    |> Ecto.Changeset.cast(params, Map.keys(@types))
    |> Ecto.Changeset.apply_action!(:cast)
  end
end

defmodule Sync.Clients.Loxo.Model.PersonEvent do
  @moduledoc """
  This module defines the struct for the PersonEvent model. This is how Lexo
  represents a PersonEvent in the response of "Get Person Events" endpoint.
  """

  @derive Jason.Encoder

  defstruct [
    :id,
    :notes,
    :pinned,
    :person_id,
    :activity_type_id,
    :job_id,
    :company_id,
    :created_at,
    :created_by_id,
    :updated_at,
    :updated_by_id,
    :documents
  ]

  @type t :: %__MODULE__{
          id: integer(),
          notes: String.t(),
          pinned: any(),
          person_id: integer(),
          activity_type_id: integer(),
          job_id: any(),
          company_id: any(),
          created_at: String.t(),
          created_by_id: any(),
          updated_at: String.t(),
          updated_by_id: any(),
          documents: list()
        }

  @types %{
    id: :integer,
    notes: :string,
    pinned: :any,
    person_id: :integer,
    activity_type_id: :integer,
    job_id: :any,
    company_id: :any,
    created_at: :string,
    updated_at: :string,
    updated_by_id: :any,
    documents: {:array, :any}
  }

  def to_struct!(params) do
    {%__MODULE__{}, @types}
    |> Ecto.Changeset.cast(params, Map.keys(@types))
    |> Ecto.Changeset.apply_action!(:cast)
  end
end

defmodule Sync.Clients.Loxo.Model.Users do
  @moduledoc """
  This module defines the struct for the User model. This is how Lexo
  represents a User in the response of "Get Users" endpoint.
  """

  @derive Jason.Encoder

  defstruct [
    :id,
    :name,
    :email,
    :created_at,
    :updated_at,
    :avatar_thumb_url,
    :twilio_phone_number
  ]

  @type t :: %__MODULE__{
          id: integer(),
          name: String.t(),
          email: String.t(),
          created_at: String.t(),
          updated_at: String.t(),
          avatar_thumb_url: String.t(),
          twilio_phone_number: any()
        }

  @types %{
    id: :integer,
    name: :string,
    email: :string,
    created_at: :string,
    updated_at: :string,
    avatar_thumb_url: :string,
    twilio_phone_number: :any
  }

  def to_struct!(params) do
    {%__MODULE__{}, @types}
    |> Ecto.Changeset.cast(params, Map.keys(@types))
    |> Ecto.Changeset.apply_action!(:cast)
  end
end
