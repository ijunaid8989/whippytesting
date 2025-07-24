defmodule Sync.Clients.Aqore.Model.Candidate do
  @moduledoc """
  This module defines the struct for the Candidate model. This is how Aqore
  represents a Candidate.
  """

  @derive Jason.Encoder

  defstruct [
    :id,
    :candidateId,
    :firstName,
    :lastName,
    :middleName,
    :title,
    :entityListItemId,
    :entity,
    :status,
    :isActive,
    :address1,
    :address2,
    :city,
    :state,
    :stateCode,
    :zipCode,
    :country,
    :dateOfBirth,
    :phone,
    :phoneList,
    :optOutPhone,
    :email,
    :emailList,
    :optOutEmail,
    :hireDate,
    :recruiterId,
    :officeId,
    :office,
    :organizationId,
    :company,
    :jobId,
    :assignmentId,
    :onAssignment,
    :skills,
    :source,
    :zenopleLink
  ]

  @type t :: %__MODULE__{
          id: String.t(),
          candidateId: String.t(),
          firstName: String.t(),
          lastName: String.t(),
          middleName: String.t() | nil,
          title: String.t(),
          entityListItemId: integer(),
          entity: String.t(),
          status: String.t(),
          isActive: boolean(),
          address1: String.t(),
          address2: String.t(),
          city: String.t(),
          state: String.t(),
          stateCode: String.t(),
          zipCode: String.t(),
          country: String.t(),
          dateOfBirth: Date.t(),
          phone: String.t(),
          phoneList: String.t(),
          optOutPhone: boolean(),
          email: String.t(),
          emailList: String.t(),
          optOutEmail: boolean(),
          hireDate: Date.t() | nil,
          recruiterId: integer() | nil,
          officeId: integer(),
          office: String.t(),
          organizationId: integer(),
          company: String.t(),
          jobId: integer(),
          assignmentId: integer(),
          onAssignment: boolean(),
          skills: list(String.t()),
          source: String.t() | nil,
          zenopleLink: String.t()
        }

  @types %{
    id: :string,
    candidateId: :string,
    firstName: :string,
    lastName: :string,
    middleName: :string,
    title: :string,
    entityListItemId: :integer,
    entity: :string,
    status: :string,
    isActive: :boolean,
    address1: :string,
    address2: :string,
    city: :string,
    state: :string,
    stateCode: :string,
    zipCode: :string,
    country: :string,
    dateOfBirth: :date,
    phone: :string,
    phoneList: :string,
    optOutPhone: :boolean,
    email: :string,
    emailList: :string,
    optOutEmail: :boolean,
    hireDate: :date,
    recruiterId: :integer,
    officeId: :integer,
    office: :string,
    organizationId: :integer,
    company: :string,
    jobId: :integer,
    assignmentId: :integer,
    onAssignment: :boolean,
    skills: {:array, :string},
    source: :string,
    zenopleLink: :string
  }

  def to_struct!(params) do
    {%__MODULE__{}, @types}
    |> Ecto.Changeset.cast(params, Map.keys(@types))
    |> Ecto.Changeset.apply_action!(:cast)
  end

  def to_list_of_custom_properties do
    # possible types are date, number, float, text, boolean, list, and map
    [
      %{key: "id", label: "id", type: "text"},
      %{key: "candidate_id", label: "Candidate Id", type: "text"},
      %{key: "first_name", label: "First Name", type: "text"},
      %{key: "middle_name", label: "Middle Name", type: "text"},
      %{key: "last_name", label: "Last Name", type: "text"},
      %{key: "entity_list_item_id", label: "Entity List Item Id", type: "number"},
      %{key: "entity", label: "Entity", type: "text"},
      %{key: "title", label: "Title", type: "text"},
      %{key: "status", label: "Status", type: "text"},
      %{key: "is_active", label: "Is Active", type: "boolean"},
      %{key: "address1", label: "Address1", type: "text"},
      %{key: "address2", label: "Address2", type: "text"},
      %{key: "city", label: "City", type: "text"},
      %{key: "state", label: "State", type: "text"},
      %{key: "state_code", label: "State Code", type: "text"},
      %{key: "zip_code", label: "Zip Code", type: "text"},
      %{key: "country", label: "Country", type: "text"},
      %{key: "date_of_birth", label: "Date Of Birth", type: "date"},
      %{key: "phone", label: "Phone", type: "text"},
      %{key: "phone_list", label: "Phone List", type: "text"},
      %{key: "opt_out_phone", label: "Opt Out Phone", type: "boolean"},
      %{key: "email", label: "Email", type: "text"},
      %{key: "email_list", label: "Email List", type: "text"},
      %{key: "opt_out_email", label: "Opt Out Email", type: "boolean"},
      %{key: "hire_date", label: "Hire Date", type: "date"},
      %{key: "recruiter_id", label: "Recruiter Id", type: "number"},
      %{key: "office_id", label: "Office Id", type: "number"},
      %{key: "office", label: "Office", type: "text"},
      %{key: "organization_id", label: "Organization Id", type: "number"},
      %{key: "company", label: "Company", type: "text"},
      %{key: "job_id", label: "Job Id", type: "number"},
      %{key: "assignment_id", label: "Assignment Id", type: "number"},
      %{key: "on_assignment", label: "On Assignment", type: "boolean"},
      %{key: "skills", label: "Skills", type: "list"},
      %{key: "source", label: "Source", type: "text"},
      %{key: "zenople_link", label: "Zenople Link", type: "text"}
    ]
  end
end

defmodule Sync.Clients.Aqore.Model.AqoreContact do
  @moduledoc """
  This module defines the struct for the Contact model. This is how Aqore
  represents a Contact.
  """

  @derive Jason.Encoder

  defstruct [
    :id,
    :clientContactId,
    :firstName,
    :lastName,
    :email,
    :phone,
    :title,
    :organizationId,
    :status,
    :isActive,
    :workPhone,
    :preferredContactMethod,
    :dateAdded,
    :role1,
    :role2,
    :role3
  ]

  @type t :: %__MODULE__{
          id: String.t(),
          clientContactId: String.t(),
          firstName: String.t(),
          lastName: String.t(),
          email: String.t() | nil,
          phone: String.t(),
          title: String.t(),
          organizationId: String.t(),
          status: String.t(),
          isActive: boolean(),
          workPhone: String.t(),
          preferredContactMethod: String.t(),
          dateAdded: DateTime.t(),
          role1: String.t(),
          role2: String.t(),
          role3: String.t()
        }

  @types %{
    id: :string,
    clientContactId: :string,
    firstName: :string,
    lastName: :string,
    email: :string,
    phone: :string,
    title: :string,
    organizationId: :string,
    status: :string,
    isActive: :boolean,
    workPhone: :string,
    preferredContactMethod: :string,
    dateAdded: :utc_datetime,
    role1: :string,
    role2: :string,
    role3: :string
  }

  def to_struct!(params) do
    {%__MODULE__{}, @types}
    |> Ecto.Changeset.cast(params, Map.keys(@types))
    |> Ecto.Changeset.apply_action!(:cast)
  end

  def to_list_of_custom_properties do
    # possible types are date, number, float, text, boolean, list, and map
    [
      %{
        key: "id",
        label: "id",
        type: "text",
        whippy_associations: [
          %{
            target_whippy_resource: "contact",
            target_property_key: "external_id",
            target_property_key_prefix: "cont-",
            source_property_key: "id",
            type: "one_to_one"
          }
        ]
      },
      %{key: "client_contact_id", label: "Client Contact Id", type: "text"},
      %{key: "first_name", label: "First Name", type: "text"},
      %{key: "last_name", label: "Last Name", type: "text"},
      %{key: "email", label: "Email", type: "text"},
      %{key: "phone", label: "Phone", type: "text"},
      %{key: "title", label: "Title", type: "text"},
      %{key: "organization_id", label: "Organization Id", type: "text"},
      %{key: "status", label: "Status", type: "text"},
      %{key: "is_active", label: "Is Active", type: "boolean"},
      %{key: "work_phone", label: "Work Phone", type: "text"},
      %{key: "preferred_contact_method", label: "Preferred Contact Method", type: "text"},
      %{key: "date_added", label: "Date Added", type: "date"},
      %{key: "role_1", label: "Role 1", type: "text"},
      %{key: "role_2", label: "Role 2", type: "text"},
      %{key: "role_3", label: "Role 3", type: "text"}
    ]
  end
end

defmodule Sync.Clients.Aqore.Model.OrganizationData do
  @moduledoc """
  This module defines the struct for the Contact model. This is how Aqore
  represents a Contact.
  """

  @derive Jason.Encoder

  defstruct [
    :id,
    :organizationId,
    :entityListItemId,
    :entity,
    :enteredBy,
    :address1,
    :address2,
    :city,
    :organization,
    :phone,
    :zipcode,
    :state,
    :department,
    :office,
    :status,
    :workflow,
    :stage,
    :industry,
    :organizationType,
    :salesLevel,
    :source,
    :entityCreatedDate,
    :insertDate
  ]

  @type t :: %__MODULE__{
          id: String.t(),
          organizationId: String.t(),
          entityListItemId: integer(),
          entity: String.t(),
          enteredBy: String.t(),
          address1: String.t(),
          address2: String.t(),
          city: String.t(),
          organization: String.t(),
          phone: String.t(),
          zipcode: String.t(),
          state: String.t(),
          department: String.t(),
          office: String.t(),
          status: String.t(),
          workflow: String.t(),
          stage: String.t(),
          industry: String.t(),
          organizationType: String.t(),
          salesLevel: String.t(),
          source: String.t(),
          entityCreatedDate: DateTime.t(),
          insertDate: DateTime.t()
        }

  @types %{
    id: :string,
    organizationId: :string,
    entityListItemId: :integer,
    entity: :string,
    enteredBy: :string,
    address1: :string,
    address2: :string,
    city: :string,
    organization: :string,
    phone: :string,
    zipcode: :string,
    state: :string,
    department: :string,
    office: :string,
    status: :string,
    workflow: :string,
    stage: :string,
    industry: :string,
    organizationType: :string,
    salesLevel: :string,
    source: :string,
    entityCreatedDate: :utc_datetime,
    insertDate: :utc_datetime
  }

  def to_struct!(params) do
    {%__MODULE__{}, @types}
    |> Ecto.Changeset.cast(params, Map.keys(@types))
    |> Ecto.Changeset.apply_action!(:cast)
  end

  def to_list_of_custom_properties do
    # possible types are date, number, float, text, boolean, list, and map
    [
      %{key: "id", label: "id", type: "text"},
      %{key: "organization_id", label: "Organization Id", type: "text"},
      %{key: "entity_list_item_id", label: "Entity List Item Id", type: "number"},
      %{key: "entity", label: "Entity", type: "text"},
      %{key: "entered_by", label: "Entered By", type: "text"},
      %{key: "address_1", label: "Address 1", type: "text"},
      %{key: "address_2", label: "Address 2", type: "text"},
      %{key: "city", label: "City", type: "text"},
      %{key: "organization", label: "Organization", type: "text"},
      %{key: "phone", label: "Phone", type: "text"},
      %{key: "zipcode", label: "Zipcode", type: "text"},
      %{key: "state", label: "State", type: "text"},
      %{key: "department", label: "Department", type: "text"},
      %{key: "office", label: "Office", type: "text"},
      %{key: "status", label: "Status", type: "text"},
      %{key: "workflow", label: "Workflow", type: "text"},
      %{key: "stage", label: "Stage", type: "text"},
      %{key: "industry", label: "Industry", type: "text"},
      %{key: "organization_type", label: "Organization Type", type: "text"},
      %{key: "sales_level", label: "Sales Level", type: "text"},
      %{key: "source", label: "Source", type: "text"},
      %{key: "entity_created_date", label: "Entity Created Date", type: "date"},
      %{key: "insert_date", label: "Insert Date", type: "date"}
    ]
  end
end

defmodule Sync.Clients.Aqore.Model.JobCandidate do
  @moduledoc """
  This module defines the struct for the Job Candidate model. This is how Aqore
  represents a Job Candidate.
  """

  @derive Jason.Encoder

  defstruct [
    :id,
    :jobCandidateId,
    :personId,
    :candidateId,
    :jobId,
    :entity,
    :currentEntity,
    :currentEntityStage,
    :currentEntityStatus,
    :jobCandidateStage,
    :jobCandidateStatus,
    :source,
    :jobCandidateDate,
    :dateAdded,
    :previouslyWorkedForThisOrganization,
    :previouslyWorkedForThisJobPosition,
    :personRating,
    :candidateRating,
    :priority,
    :name,
    :phone,
    :email,
    :dateOfBirth,
    :address,
    :jobModule,
    :skills,
    :educationHistory,
    :workHistory,
    :job,
    :dateApplication,
    :jobType,
    :status,
    :clientContactId
  ]

  @type t :: %__MODULE__{
          id: String.t(),
          jobCandidateId: String.t(),
          personId: integer(),
          candidateId: String.t(),
          jobId: String.t(),
          entity: String.t(),
          currentEntity: String.t(),
          currentEntityStage: String.t(),
          currentEntityStatus: String.t(),
          jobCandidateStage: String.t(),
          jobCandidateStatus: String.t(),
          source: String.t(),
          jobCandidateDate: Date.t(),
          dateAdded: Date.t(),
          previouslyWorkedForThisOrganization: boolean(),
          previouslyWorkedForThisJobPosition: boolean(),
          personRating: String.t(),
          candidateRating: String.t(),
          priority: integer(),
          name: String.t(),
          phone: String.t(),
          email: String.t(),
          dateOfBirth: Date.t(),
          address: Map.t(),
          jobModule: String.t(),
          skills: list(),
          educationHistory: list(),
          workHistory: list(),
          job: map(),
          dateApplication: Date.t(),
          jobType: String.t(),
          status: String.t(),
          clientContactId: String.t()
        }

  @types %{
    id: :string,
    jobCandidateId: :string,
    personId: :integer,
    candidateId: :string,
    jobId: :string,
    entity: :string,
    currentEntity: :string,
    currentEntityStage: :string,
    currentEntityStatus: :string,
    jobCandidateStage: :string,
    jobCandidateStatus: :string,
    source: :string,
    jobCandidateDate: :date,
    dateAdded: :date,
    previouslyWorkedForThisOrganization: :boolean,
    previouslyWorkedForThisJobPosition: :boolean,
    personRating: :string,
    candidateRating: :string,
    priority: :integer,
    name: :string,
    phone: :string,
    email: :string,
    dateOfBirth: :date,
    address: :map,
    jobModule: :string,
    skills: {:array, :map},
    educationHistory: {:array, :map},
    workHistory: {:array, :map},
    job: :map,
    dateApplication: :date,
    jobType: :string,
    status: :string,
    clientContactId: :string
  }

  def to_struct!(params) do
    {%__MODULE__{}, @types}
    |> Ecto.Changeset.cast(params, Map.keys(@types))
    |> Ecto.Changeset.apply_action!(:cast)
  end

  def to_list_of_custom_properties do
    # possible types are date, number, float, text, boolean, list, and map
    [
      %{key: "id", label: "id", type: "text"},
      %{key: "job_candidate_id", label: "Job Candidate Id", type: "text"},
      %{key: "person_id", label: "Person Id", type: "number"},
      %{
        key: "candidate_id",
        label: "Candidate Id",
        type: "text",
        references: [
          %{
            external_entity_type: "candidate",
            external_entity_property_key: "candidate_id",
            type: "many_to_one"
          }
        ]
      },
      %{
        key: "job_id",
        label: "Job Id",
        type: "text",
        references: [
          %{
            external_entity_type: "job",
            external_entity_property_key: "job_id",
            type: "many_to_one"
          }
        ]
      },
      %{key: "entity", label: "Entity", type: "text"},
      %{key: "current_entity", label: "Current Entity", type: "text"},
      %{key: "current_entity_stage", label: "Current Entity Stage", type: "text"},
      %{key: "current_entity_status", label: "Current Entity Status", type: "text"},
      %{key: "job_candidate_stage", label: "Job Candidate Stage", type: "text"},
      %{key: "job_candidate_status", label: "Job Candidate Status", type: "text"},
      %{key: "source", label: "Source", type: "text"},
      %{key: "job_candidate_date", label: "Job Candidate Date", type: "date"},
      %{key: "date_added", label: "Date Added", type: "date"},
      %{
        key: "previously_worked_for_this_organization",
        label: "Previously Worked For This Organization",
        type: "boolean"
      },
      %{
        key: "previously_worked_for_this_job_position",
        label: "Previously Worked For This Job Position",
        type: "boolean"
      },
      %{key: "person_rating", label: "Person Rating", type: "text"},
      %{key: "candidate_rating", label: "Candidate Rating", type: "text"},
      %{key: "priority", label: "Priority", type: "number"},
      %{key: "name", label: "Name", type: "text"},
      %{key: "phone", label: "Phone", type: "text"},
      %{key: "email", label: "Email", type: "text"},
      %{key: "date_of_birth", label: "Date Of Birth", type: "date"},
      %{key: "address", label: "Address", type: "map"},
      %{key: "job_module", label: "Job Module", type: "text"},
      %{key: "skills", label: "Skills", type: "list"},
      %{key: "education_history", label: "Education History", type: "list"},
      %{key: "work_history", label: "Work History", type: "list"},
      %{key: "job", label: "Job", type: "map"},
      %{key: "date_application", label: "Date Application", type: "date"},
      %{key: "job_type", label: "Job Type", type: "text"},
      %{key: "status", label: "Status", type: "text"},
      %{key: "client_contact_id", label: "Client Contact Id", type: "text"}
    ]
  end
end

defmodule Sync.Clients.Aqore.Model.NewCandidate do
  @moduledoc """
  This module defines the struct for the NewCandidate model. This is how Aqore
  represents a NewCandidate.
  """

  @derive Jason.Encoder

  defstruct [:id, :entitytype, :action, :message, :status]

  @type t :: %__MODULE__{
          id: integer(),
          entitytype: String.t(),
          action: String.t(),
          message: String.t(),
          status: String.t()
        }

  @types %{
    id: :integer,
    entitytype: :string,
    action: :string,
    message: :string,
    status: :string
  }

  def to_struct!(params) do
    {%__MODULE__{}, @types}
    |> Ecto.Changeset.cast(params, Map.keys(@types))
    |> Ecto.Changeset.apply_action!(:cast)
  end
end

defmodule Sync.Clients.Aqore.Model.Comment do
  @moduledoc """
  This module defines the struct for the Comment model. This is how Aqore
  represents a Comment.
  """

  @derive Jason.Encoder

  defstruct [:commentId, :success]

  @type t :: %__MODULE__{
          commentId: integer(),
          success: boolean()
        }

  @types %{
    commentId: :integer,
    success: :boolean
  }

  def to_struct!(params) do
    {%__MODULE__{}, @types}
    |> Ecto.Changeset.cast(params, Map.keys(@types))
    |> Ecto.Changeset.apply_action!(:cast)
  end
end

defmodule Sync.Clients.Aqore.Model.User do
  @moduledoc """
  This module defines the struct for the User model. This is how Aqore
  represents a User.
  """

  @derive Jason.Encoder

  defstruct [
    :id,
    :userId,
    :firstName,
    :lastName,
    :middleName,
    :title,
    :userName,
    :entityListItemId,
    :entity,
    :statusListItemId,
    :status,
    :isActive,
    :address1,
    :address2,
    :city,
    :state,
    :stateCode,
    :zipcode,
    :country,
    :dateOfBirth,
    :email,
    :emailList,
    :phone,
    :phoneList,
    :optOutSms,
    :optOutEmail,
    :dateAdded
  ]

  @type t :: %__MODULE__{
          id: String.t(),
          userId: String.t(),
          firstName: String.t(),
          lastName: String.t(),
          middleName: String.t() | nil,
          title: String.t(),
          userName: String.t(),
          entityListItemId: integer(),
          entity: String.t(),
          statusListItemId: integer(),
          status: String.t(),
          isActive: boolean(),
          address1: String.t(),
          address2: String.t(),
          city: String.t(),
          state: String.t(),
          stateCode: String.t(),
          zipcode: String.t(),
          country: String.t(),
          dateOfBirth: Date.t(),
          email: String.t(),
          emailList: String.t(),
          phone: String.t(),
          phoneList: String.t(),
          optOutSms: boolean(),
          optOutEmail: boolean(),
          dateAdded: DateTime.t()
        }

  @types %{
    id: :string,
    userId: :string,
    firstName: :string,
    lastName: :string,
    middleName: :string,
    title: :string,
    userName: :string,
    entityListItemId: :integer,
    entity: :string,
    statusListItemId: :integer,
    status: :string,
    isActive: :boolean,
    address1: :string,
    address2: :string,
    city: :string,
    state: :string,
    stateCode: :string,
    zipcode: :string,
    country: :string,
    dateOfBirth: :date,
    email: :string,
    emailList: :string,
    phone: :string,
    phoneList: :string,
    optOutSms: :boolean,
    optOutEmail: :boolean,
    dateAdded: :utc_datetime
  }

  def to_struct!(params) do
    {%__MODULE__{}, @types}
    |> Ecto.Changeset.cast(params, Map.keys(@types))
    |> Ecto.Changeset.apply_action!(:cast)
  end
end

defmodule Sync.Clients.Aqore.Model.Job do
  @moduledoc """
  This module defines the struct for the Job model. This is how Aqore
  represents a Job.
  """

  @derive Jason.Encoder

  defstruct [
    :id,
    :jobId,
    :entity,
    :jobType,
    :address1,
    :address2,
    :title,
    :organizationId,
    :city,
    :zipcode,
    :state,
    :payRate,
    :billRate,
    :skills,
    :salary,
    :dateStart,
    :dateEnd,
    :shift,
    :status,
    :placementRequired,
    :officeId,
    :office,
    :startTime,
    :endTime,
    :dateAdded,
    :internalUserId,
    :description,
    :jobPostingDescription
  ]

  @type t :: %__MODULE__{
          id: String.t(),
          jobId: String.t(),
          entity: String.t(),
          jobType: String.t(),
          address1: String.t(),
          address2: String.t(),
          title: String.t(),
          organizationId: String.t(),
          city: String.t(),
          zipcode: String.t(),
          state: String.t(),
          payRate: float(),
          billRate: float(),
          skills: {:array, :string},
          salary: float(),
          dateStart: Date.t(),
          dateEnd: Date.t(),
          shift: String.t(),
          status: String.t(),
          placementRequired: integer(),
          officeId: integer(),
          office: String.t(),
          dateAdded: Date.t(),
          internalUserId: String.t(),
          description: String.t() | nil,
          jobPostingDescription: String.t() | nil
        }

  @types %{
    id: :string,
    jobId: :string,
    entity: :string,
    jobType: :string,
    address1: :string,
    address2: :string,
    title: :string,
    organizationId: :string,
    city: :string,
    zipcode: :string,
    state: :string,
    payRate: :float,
    billRate: :float,
    skills: :list,
    salary: :float,
    dateStart: :date,
    dateEnd: :date,
    shift: :string,
    status: :string,
    placementRequired: :integer,
    officeId: :integer,
    office: :string,
    dateAdded: :date,
    internalUserId: :string,
    description: :string,
    jobPostingDescription: :string
  }

  def to_struct!(params) do
    {%__MODULE__{}, @types}
    |> Ecto.Changeset.cast(params, Map.keys(@types))
    |> Ecto.Changeset.apply_action!(:cast)
  end

  def to_list_of_custom_properties do
    # possible types are date, number, float, text, boolean, list, and map
    [
      %{key: "id", label: "id", type: "text"},
      %{
        key: "job_id",
        label: "Job Id",
        type: "text",
        references: [
          %{
            external_entity_type: "job_candidate",
            external_entity_property_key: "job_id",
            type: "one_to_many"
          }
        ]
      },
      %{key: "entity", label: "Entity", type: "text"},
      %{key: "job_type", label: "Job Type", type: "text"},
      %{key: "address1", label: "Address1", type: "text"},
      %{key: "address2", label: "Address2", type: "text"},
      %{key: "title", label: "Title", type: "text"},
      %{
        key: "organization_id",
        label: "Organization Id",
        type: "text",
        references: [
          %{
            external_entity_type: "organization_data",
            external_entity_property_key: "organization_id",
            type: "many_to_one"
          }
        ]
      },
      %{key: "city", label: "City", type: "text"},
      %{key: "zipcode", label: "Zipcode", type: "text"},
      %{key: "state", label: "State", type: "text"},
      %{key: "pay_rate", label: "Pay Rate", type: "float"},
      %{key: "bill_rate", label: "Bill Rate", type: "float"},
      %{key: "skills", label: "Skills", type: "list"},
      %{key: "salary", label: "Salary", type: "float"},
      %{key: "date_start", label: "Date Start", type: "date"},
      %{key: "date_end", label: "Date End", type: "date"},
      %{key: "shift", label: "Shift", type: "text"},
      %{key: "status", label: "Status", type: "text"},
      %{key: "placement_required", label: "Placement Required", type: "number"},
      %{key: "office_id", label: "Office Id", type: "number"},
      %{key: "office", label: "Office", type: "text"},
      %{key: "date_added", label: "Date Added", type: "date"},
      %{key: "internal_user_id", label: "Internal User Id", type: "text"},
      %{key: "description", label: "Description", type: "text"},
      %{key: "job_posting_description", label: "Job Posting Description", type: "text"}
    ]
  end
end

defmodule Sync.Clients.Aqore.Model.Assignment do
  @moduledoc """
  This module defines the struct for the Assignment model. This is how Aqore
  represents a Assignment.
  """

  @derive Jason.Encoder

  defstruct [
    :id,
    :assignmentId,
    :entityListItemId,
    :entity,
    :candidateId,
    :organizationId,
    :jobId,
    :overTimePayRate,
    :overTimeBillRate,
    :payRate,
    :billRate,
    :salary,
    :shift,
    :status,
    :candidateName,
    :organizationName,
    :office,
    :cityState,
    :wcCode,
    :assignmentType,
    :address1,
    :address2,
    :city,
    :state,
    :zipCode,
    :fullAddress,
    :startDate,
    :endDate,
    :endReason,
    :performance,
    :payPeriod,
    :dateAdded,
    :ShiftStartDateTime,
    :shiftEndDateTime,
    :recruiterUserId
  ]

  @type t :: %__MODULE__{
          id: String.t(),
          assignmentId: String.t(),
          entityListItemId: Integer.t(),
          entity: String.t(),
          candidateId: String.t(),
          organizationId: String.t(),
          jobId: String.t(),
          overTimePayRate: float(),
          overTimeBillRate: float(),
          payRate: float(),
          billRate: float(),
          salary: float(),
          shift: String.t(),
          status: String.t(),
          candidateName: String.t(),
          organizationName: String.t(),
          office: String.t(),
          cityState: String.t(),
          wcCode: String.t(),
          assignmentType: String.t(),
          address1: String.t(),
          address2: String.t(),
          city: String.t(),
          state: String.t(),
          zipCode: String.t(),
          fullAddress: String.t(),
          startDate: Date.t(),
          endDate: Date.t(),
          endReason: String.t(),
          performance: String.t(),
          payPeriod: String.t(),
          dateAdded: Date.t(),
          ShiftStartDateTime: Date.t(),
          shiftEndDateTime: Date.t(),
          recruiterUserId: String.t()
        }

  @types %{
    id: :string,
    assignmentId: :string,
    entityListItemId: :integer,
    entity: :string,
    candidateId: :string,
    organizationId: :string,
    jobId: :string,
    overTimePayRate: :float,
    overTimeBillRate: :float,
    payRate: :float,
    billRate: :float,
    salary: :float,
    shift: :string,
    status: :string,
    candidateName: :string,
    organizationName: :string,
    office: :string,
    cityState: :string,
    wcCode: :string,
    assignmentType: :string,
    address1: :string,
    address2: :string,
    city: :string,
    state: :string,
    zipCode: :string,
    fullAddress: :string,
    startDate: :date,
    endDate: :date,
    endReason: :string,
    performance: :string,
    payPeriod: :string,
    dateAdded: :date,
    ShiftStartDateTime: :date,
    shiftEndDateTime: :date,
    recruiterUserId: :string
  }

  def to_struct!(params) do
    {%__MODULE__{}, @types}
    |> Ecto.Changeset.cast(params, Map.keys(@types))
    |> Ecto.Changeset.apply_action!(:cast)
  end

  def to_list_of_custom_properties do
    # possible types are date, number, float, text, boolean, list, and map
    [
      %{key: "id", label: "id", type: "text"},
      %{key: "assignment_id", label: "Assignment Id", type: "text"},
      %{key: "entity_list_item_id", label: "Entity List Item Id", type: "number"},
      %{key: "entity", label: "Entity", type: "text"},
      %{
        key: "candidate_id",
        label: "Candidate Id",
        type: "text",
        references: [
          %{
            external_entity_type: "candidate",
            external_entity_property_key: "candidate_id",
            type: "many_to_one"
          }
        ]
      },
      %{
        key: "organization_id",
        label: "Organization Id",
        type: "text",
        references: [
          %{
            external_entity_type: "organization_data",
            external_entity_property_key: "organization_id",
            type: "many_to_one"
          }
        ]
      },
      %{
        key: "job_id",
        label: "Job Id",
        type: "text",
        references: [
          %{
            external_entity_type: "job",
            external_entity_property_key: "job_id",
            type: "many_to_one"
          }
        ]
      },
      %{key: "over_time_pay_rate", label: "Over Time Pay Rate", type: "float"},
      %{key: "over_time_bill_rate", label: "Over Time Bill Rate", type: "float"},
      %{key: "pay_rate", label: "Pay Rate", type: "float"},
      %{key: "bill_rate", label: "Bill Rate", type: "float"},
      %{key: "salary", label: "Salary", type: "float"},
      %{key: "shift", label: "Shift", type: "text"},
      %{key: "status", label: "Status", type: "text"},
      %{key: "candidate_name", label: "Candidate Name", type: "text"},
      %{key: "organization_name", label: "Organization Name", type: "text"},
      %{key: "office", label: "Office", type: "text"},
      %{key: "city_state", label: "City State", type: "text"},
      %{key: "wc_code", label: "Wc Code", type: "text"},
      %{key: "assignment_type", label: "Assignment Type", type: "text"},
      %{key: "address1", label: "Address1", type: "text"},
      %{key: "address2", label: "Address2", type: "text"},
      %{key: "city", label: "City", type: "text"},
      %{key: "state", label: "State", type: "text"},
      %{key: "zip_code", label: "Zip Code", type: "text"},
      %{key: "full_address", label: "Full Address", type: "text"},
      %{key: "start_date", label: "Start Date", type: "date"},
      %{key: "end_date", label: "End Date", type: "date"},
      %{key: "end_reason", label: "End Reason", type: "text"},
      %{key: "performance", label: "Performance", type: "text"},
      %{key: "pay_period", label: "Pay Period", type: "text"},
      %{key: "date_added", label: "Date Added", type: "date"},
      %{key: "shift_start_date_time", label: "Shift Start Date Time", type: "date"},
      %{key: "shift_end_date_time", label: "Shift End Date Time", type: "date"},
      %{key: "recruiter_user_id", label: "Recruiter User Id", type: "text"}
    ]
  end
end
