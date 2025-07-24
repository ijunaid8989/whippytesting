defmodule Sync.Clients.Whippy.Model.Address do
  @moduledoc false
  @derive Jason.Encoder
  defstruct [:address_line_one, :address_line_two, :city, :country, :post_code, :state]

  @type t :: %__MODULE__{
          address_line_one: String.t(),
          address_line_two: String.t(),
          city: String.t(),
          country: String.t(),
          post_code: String.t(),
          state: String.t()
        }
end

defmodule Sync.Clients.Whippy.Model.BirthDate do
  @moduledoc false
  @derive Jason.Encoder
  defstruct [:day, :month, :year]

  @type t :: %__MODULE__{
          day: non_neg_integer(),
          month: non_neg_integer(),
          year: non_neg_integer()
        }
end

defmodule Sync.Clients.Whippy.Model.ContactUser do
  @moduledoc """
    Currently seperating the general user with the user refered to by the Contact
    since according to the public api there are a few differences in the object that is returned.
  """
  defstruct [:id, :name, :email, :phone]

  @type t :: %__MODULE__{
          id: binary(),
          name: String.t(),
          email: String.t() | nil,
          phone: String.t()
        }
end

defmodule Sync.Clients.Whippy.Model.Note do
  @moduledoc false
  defstruct [:body, :user, :created_at, :updated_at]

  @type t :: %__MODULE__{
          body: String.t(),
          # currently listed as an object in the public api docs
          user: map(),
          # iso formatted datetime string
          created_at: String.t(),
          # iso formatted datetime string
          updated_at: String.t()
        }
end

defmodule Sync.Clients.Whippy.Model.CommunicationPreference do
  @moduledoc false
  defstruct [
    :channel_id,
    :contact_id,
    :id,
    :last_campaign_date,
    :opt_in,
    :opt_in_date,
    :opt_out_date,
    :created_at,
    :updated_at
  ]

  @type t :: %__MODULE__{
          channel_id: String.t(),
          contact_id: String.t(),
          id: String.t(),
          last_campaign_date: String.t(),
          opt_in: boolean(),
          opt_in_date: String.t(),
          opt_out_date: String.t(),
          created_at: String.t(),
          updated_at: String.t()
        }
end

defmodule Sync.Clients.Whippy.Model.Tag do
  @moduledoc false

  alias Sync.Clients.Whippy.Model.ContactUser

  @derive Jason.Encoder

  defstruct [
    :color,
    :converted,
    :id,
    :name,
    :organization_id,
    :state,
    :system_created,
    :type,
    :created_at,
    :updated_at,
    :created_by,
    :updated_by,
    :tag_id
  ]

  @type t :: %__MODULE__{
          id: String.t(),
          name: String.t(),
          organization_id: String.t(),
          color: String.t(),
          converted: boolean(),
          state: String.t(),
          system_created: boolean(),
          type: String.t(),
          tag_id: String.t(),
          created_at: String.t(),
          updated_at: String.t(),
          created_by: ContactUser.t(),
          updated_by: ContactUser.t()
        }
end

defmodule Sync.Clients.Whippy.Model.ContactTag do
  @moduledoc false
  alias Sync.Clients.Whippy.Model.Tag

  @derive Jason.Encoder

  defstruct [
    :contact_id,
    :created_at,
    :id,
    :tag,
    :tag_id,
    :updated_at
  ]

  @type t :: %__MODULE__{
          contact_id: String.t(),
          created_at: String.t(),
          id: String.t(),
          tag: Tag.t(),
          tag_id: String.t(),
          updated_at: String.t()
        }
end

defmodule Sync.Clients.Whippy.Model.Contact do
  @moduledoc false
  alias Sync.Clients.Whippy.Model.CommunicationPreference
  alias Sync.Clients.Whippy.Model.ContactTag

  @derive Jason.Encoder

  defstruct [
    :id,
    :external_id,
    :first_name,
    :last_name,
    :name,
    :email,
    :blocked,
    :communication_preferences,
    :contact_tags,
    :address,
    :notes,
    :birth_date,
    :conversations,
    # "phone": "+19563590817",
    :phone,
    # open archived blocked
    :state,
    # iso formatted datetime string
    :created_at,
    # iso formatted datetime string
    :updated_at
  ]

  @type t :: %__MODULE__{
          id: binary(),
          first_name: String.t() | nil,
          last_name: String.t() | nil,
          name: String.t(),
          email: String.t() | nil,
          external_id: String.t() | nil,
          blocked: boolean(),
          communication_preferences: list(CommunicationPreference.t()),
          contact_tags: list(ContactTag.t()),
          address: Map.t(),
          birth_date: Date.t(),
          conversations: list(),
          notes: list(),
          # "phone": "+19563590817",
          phone: String.t(),
          # open archived blocked
          state: String.t(),
          # iso formatted datetime string
          created_at: String.t(),
          # iso formatted datetime string
          updated_at: String.t()
        }
end

defmodule Sync.Clients.Whippy.Model.OpeningHours do
  @moduledoc false

  @derive Jason.Encoder

  defstruct [
    :closes_at,
    :opens_at,
    :state,
    :weekday
  ]

  @type t :: %__MODULE__{
          # iso formatted datetime string
          closes_at: String.t(),
          # iso formatted datetime string
          opens_at: String.t(),
          # Setting for the open or closed status of the business on a certain weekday
          state: String.t(),
          # Monday Tuesday Wednesday Thursday Friday Saturday Sunday
          weekday: String.t()
        }
end

defmodule Sync.Clients.Whippy.Model.Channel do
  @moduledoc false
  alias Sync.Clients.Whippy.Model.OpeningHours

  @derive Jason.Encoder

  defstruct [
    :address,
    :automatic_response_closed,
    :automatic_response_open,
    :id,
    :name,
    :opening_hours,
    :phone,
    :send_automatic_response_when,
    :timezone,
    # iso formatted datetime string
    :created_at,
    # iso formatted datetime string
    :updated_at,
    :is_hosted_sms,
    :support_ai_agent,
    :emoji,
    :description,
    :color,
    :type
  ]

  @type t :: %__MODULE__{
          address: String.t(),
          automatic_response_closed: String.t(),
          automatic_response_open: String.t(),
          id: String.t(),
          name: String.t(),
          opening_hours: OpeningHours.t(),
          phone: String.t(),
          # Setting that determines when to send automatic responses
          # Values can be: always never open closed
          send_automatic_response_when: String.t(),
          timezone: String.t(),
          # iso formatteddatetime: String. string
          created_at: String.t(),
          # iso formatted datetime string
          updated_at: String.t(),
          is_hosted_sms: boolean(),
          support_ai_agent: boolean(),
          emoji: String.t(),
          description: String.t(),
          color: String.t()
        }
end

defmodule Sync.Clients.Whippy.Model.Attachment do
  @moduledoc false

  @derive Jason.Encoder

  defstruct [:content_type, :url]

  @type t :: %__MODULE__{
          content_type: String.t(),
          url: String.t()
        }
end

defmodule Sync.Clients.Whippy.Model.User do
  @moduledoc false
  alias Sync.Clients.Whippy.Model.Attachment

  @derive Jason.Encoder

  defstruct [
    :attachment,
    :channels,
    :type,
    :email,
    :id,
    :name,
    :phone,
    :role,
    :state
  ]

  @type t :: %__MODULE__{
          attachment: Attachment.t(),
          channels: String.t(),
          type: String.t(),
          email: String.t(),
          id: String.t(),
          name: String.t(),
          phone: String.t(),
          role: String.t(),
          state: String.t()
        }
end

defmodule Sync.Clients.Whippy.Model.Conversation do
  @moduledoc false

  @derive Jason.Encoder

  defstruct [
    :assigned_team_id,
    :assigned_user_id,
    :channel_id,
    :channel_type,
    :contact_id,
    :contact_language,
    :created_at,
    :id,
    :language,
    :last_message_date,
    :last_message_timestamp,
    :messages,
    :status,
    :unread_count,
    :updated_at
  ]

  @type t :: %__MODULE__{
          assigned_team_id: String.t() | nil,
          assigned_user_id: non_neg_integer() | nil,
          channel_id: String.t(),
          # phone email
          channel_type: String.t(),
          contact_id: String.t(),
          contact_language: String.t(),
          created_at: String.t(),
          id: String.t(),
          language: String.t(),
          last_message_date: String.t(),
          last_message_timestamp: String.t(),
          messages: [term()],
          # open closed automated spam
          status: String.t(),
          unread_count: non_neg_integer(),
          updated_at: String.t()
        }
end

defmodule Sync.Clients.Whippy.Model.CustomObject do
  @moduledoc false

  alias Sync.Clients.Whippy.Model.Association
  alias Sync.Clients.Whippy.Model.CustomProperty
  alias Sync.Utils.Ecto.Changeset.SchemalessAssoc

  @derive Jason.Encoder

  defstruct [
    :created_at,
    :custom_properties,
    :id,
    :key,
    :label,
    :updated_at,
    :color,
    :emoji,
    :description,
    :editable,
    :hidden,
    :created_by,
    :updated_by,
    :associations,
    :whippy_associations
  ]

  @type t :: %__MODULE__{
          created_at: String.t(),
          custom_properties: [CustomProperty.t()],
          id: String.t(),
          key: String.t(),
          label: String.t(),
          updated_at: String.t(),
          color: String.t(),
          emoji: String.t(),
          description: String.t(),
          editable: boolean(),
          hidden: boolean(),
          created_by: map(),
          updated_by: map(),
          associations: [String.t()],
          whippy_associations: [map()]
        }

  @types %{
    created_at: :string,
    custom_properties: {:array, :map},
    associations: {:array, :map},
    whippy_associations: {:array, :map},
    id: :string,
    key: :string,
    label: :string,
    updated_at: :string,
    color: :string,
    emoji: :string,
    description: :string,
    editable: :boolean,
    hidden: :boolean,
    created_by: :map,
    updated_by: :map
  }

  def to_struct!(params) do
    {%__MODULE__{}, @types}
    |> Ecto.Changeset.cast(params, Map.keys(@types))
    |> SchemalessAssoc.cast(:custom_properties, {:array, CustomProperty})
    |> SchemalessAssoc.cast(:associations, {:array, Association})
    |> Ecto.Changeset.apply_action!(:cast)
  end
end

defmodule Sync.Clients.Whippy.Model.CustomProperty do
  @moduledoc false

  @derive Jason.Encoder

  defstruct [
    :created_at,
    :custom_object_id,
    :default,
    :id,
    :key,
    :label,
    :required,
    :type,
    :editable,
    :updated_at
  ]

  @type t :: %__MODULE__{
          created_at: String.t(),
          custom_object_id: String.t(),
          default: String.t() | nil,
          id: String.t(),
          key: String.t(),
          label: String.t(),
          required: boolean(),
          editable: boolean(),
          type: String.t(),
          updated_at: String.t()
        }

  @types %{
    created_at: :string,
    custom_object_id: :string,
    default: :string,
    id: :string,
    key: :string,
    label: :string,
    required: :boolean,
    type: :string,
    editable: :boolean,
    updated_at: :string
  }

  def to_struct!(params) do
    {%__MODULE__{}, @types}
    |> Ecto.Changeset.cast(params, Map.keys(@types))
    |> Ecto.Changeset.apply_action!(:cast)
  end
end

defmodule Sync.Clients.Whippy.Model.Reference do
  @moduledoc false
  # TODO: delete this, as it's deprecated in favor of Association

  @derive Jason.Encoder

  defstruct [
    :id,
    :type,
    :custom_object_id,
    :custom_property_id
  ]

  @type t :: %__MODULE__{
          id: String.t(),
          # "one_to_one" | "one_to_many" | "many_to_one" | "many_to_many",
          type: String.t(),
          custom_object_id: String.t(),
          custom_property_id: String.t()
        }

  @types %{
    id: :string,
    type: :string,
    custom_object_id: :string,
    custom_property_id: :string
  }

  def to_struct!(params) do
    {%__MODULE__{}, @types}
    |> Ecto.Changeset.cast(params, Map.keys(@types))
    |> Ecto.Changeset.apply_action!(:cast)
  end
end

defmodule Sync.Clients.Whippy.Model.Association do
  @moduledoc false

  @derive Jason.Encoder

  defstruct [
    :id,
    :type,
    :source_property_key,
    :target_property_key,
    :target_data_type_id
  ]

  @type t :: %__MODULE__{
          id: String.t(),
          # "one_to_one" | "one_to_many" | "many_to_one" | "many_to_many",
          type: String.t(),
          source_property_key: String.t(),
          target_property_key: String.t(),
          target_data_type_id: String.t()
        }

  @types %{
    id: :string,
    type: :string,
    source_property_key: :string,
    target_property_key: :string,
    target_data_type_id: :string
  }

  def to_struct!(params) do
    {%__MODULE__{}, @types}
    |> Ecto.Changeset.cast(params, Map.keys(@types))
    |> Ecto.Changeset.apply_action!(:cast)
  end
end

defmodule Sync.Clients.Whippy.Model.CustomObjectRecord do
  @moduledoc false

  @derive Jason.Encoder

  defstruct [
    :associated_resource_id,
    :associated_resource_type,
    :created_at,
    :custom_object_id,
    :external_id,
    :id,
    :key,
    :label,
    :properties,
    :updated_at
  ]

  @type t :: %__MODULE__{
          associated_resource_id: String.t(),
          associated_resource_type: String.t(),
          created_at: String.t(),
          custom_object_id: String.t(),
          external_id: String.t(),
          id: String.t(),
          key: String.t(),
          label: String.t(),
          properties: map(),
          updated_at: String.t()
        }

  @types %{
    associated_resource_id: :string,
    associated_resource_type: :string,
    created_at: :string,
    custom_object_id: :string,
    external_id: :string,
    id: :string,
    key: :string,
    label: :string,
    properties: :map,
    updated_at: :string
  }

  def to_struct!(params) do
    {%__MODULE__{}, @types}
    |> Ecto.Changeset.cast(params, Map.keys(@types))
    |> Ecto.Changeset.apply_action!(:cast)
  end
end

defmodule Sync.Clients.Whippy.Model.CustomPropertyValue do
  @moduledoc false

  # TODO: delete this, as it's deprecated

  alias Sync.Utils.Ecto.SerializedValue

  @derive Jason.Encoder

  defstruct [
    :created_at,
    :custom_object_record_id,
    :custom_property_id,
    :id,
    :value,
    :updated_at
  ]

  @type t :: %__MODULE__{
          created_at: String.t(),
          custom_object_record_id: String.t(),
          custom_property_id: String.t(),
          id: String.t(),
          value: term(),
          updated_at: String.t()
        }

  @types %{
    created_at: :string,
    custom_object_record_id: :string,
    custom_property_id: :string,
    id: :string,
    value: SerializedValue,
    updated_at: :string
  }

  def to_struct!(params) do
    {%__MODULE__{}, @types}
    |> Ecto.Changeset.cast(params, Map.keys(@types))
    |> Ecto.Changeset.apply_action!(:cast)
  end
end
