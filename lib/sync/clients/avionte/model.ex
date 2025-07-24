defmodule Sync.Clients.Avionte.Model.Address do
  @moduledoc """
  This module defines the struct for the Address model. This is how Avionte
  represents an Address in the address fields when listing or getting a Talent.
  """

  @derive Jason.Encoder

  defstruct [
    :street1,
    :street2,
    :city,
    :state_Province,
    :postalCode,
    :country,
    :county,
    :geoCode,
    :schoolDistrictCode
  ]

  @type t :: %__MODULE__{
          street1: String.t(),
          street2: String.t() | nil,
          city: String.t() | nil,
          state_Province: String.t() | nil,
          postalCode: String.t() | nil,
          country: String.t(),
          county: String.t() | nil,
          geoCode: String.t() | nil,
          schoolDistrictCode: String.t() | nil
        }

  @types %{
    street1: :string,
    street2: :string,
    city: :string,
    state_Province: :string,
    postalCode: :string,
    country: :string,
    county: :string,
    geoCode: :string,
    schoolDistrictCode: :string
  }

  def to_struct!(params) do
    {%__MODULE__{}, @types}
    |> Ecto.Changeset.cast(params, Map.keys(@types))
    |> Ecto.Changeset.apply_action!(:cast)
  end
end

defmodule Sync.Clients.Avionte.Model.Branch do
  @moduledoc """
  This module defines the struct for the Branch model. This is how Avionte
  represents a Branch when getting or listing branches.

  The Branch object with definitions for each field can be found here:
  https://developer.avionte.com/reference/getbranches
  """

  alias Sync.Clients.Avionte.Model.Address
  alias Sync.Clients.Avionte.Model.Employer
  alias Sync.Utils.Ecto.Changeset.SchemalessAssoc

  @derive Jason.Encoder

  defstruct [
    :id,
    :name,
    :employer,
    :branchAddress
  ]

  @type t :: %__MODULE__{
          id: integer(),
          name: String.t(),
          employer: Employer.t(),
          branchAddress: Address.t()
        }

  @types %{
    id: :integer,
    name: :string,
    employer: :map,
    branchAddress: :map
  }

  def to_struct!(params) do
    {%__MODULE__{}, @types}
    |> Ecto.Changeset.cast(params, Map.keys(@types))
    |> SchemalessAssoc.cast(:employer, Employer)
    |> SchemalessAssoc.cast(:branchAddress, Address)
    |> Ecto.Changeset.apply_action!(:cast)
  end
end

defmodule Sync.Clients.Avionte.Model.Employer do
  @moduledoc """
  This module defines the struct for the Employer model. This is how Avionte
  represents an Employer in the employer field when getting or listing branches.

  The Employer object with definitions for each field can be found under the `employer` field in the response:
  https://developer.avionte.com/reference/getbranches
  """

  alias Sync.Clients.Avionte.Model.Address
  alias Sync.Utils.Ecto.Changeset.SchemalessAssoc

  @derive Jason.Encoder

  defstruct [
    :name,
    :address,
    :fein
  ]

  @type t :: %__MODULE__{
          name: String.t(),
          address: Address.t(),
          fein: String.t()
        }

  @types %{
    name: :string,
    address: :map,
    fein: :string
  }

  def to_struct!(params) do
    {%__MODULE__{}, @types}
    |> Ecto.Changeset.cast(params, Map.keys(@types))
    |> SchemalessAssoc.cast(:address, Address)
    |> Ecto.Changeset.apply_action!(:cast)
  end
end

defmodule Sync.Clients.Avionte.Model.Talent do
  @moduledoc """
  This module defines the struct for the Talent model. This is how Avionte
  represents a Talent when listing or getting a Talent.

  The Talent object with definitions for each field can be found here:
  https://developer.avionte.com/reference/querymultipletalents
  """

  alias Sync.Clients.Avionte.Model.Address
  alias Sync.Utils.Ecto.Changeset.SchemalessAssoc

  @derive Jason.Encoder

  defstruct [
    :representativeUserEmail,
    :gender,
    :referredBy,
    :id,
    :i9ValidatedDate,
    :frontOfficeId,
    :officeDivision,
    :flag,
    :status,
    :isArchived,
    :officeName,
    :representativeUser,
    :veteranStatus,
    :middleName,
    :taxIdNumber,
    :enteredByUserId,
    :electronic1099Consent,
    :filingStatus,
    :createdDate,
    :payrollAddress,
    :textConsent,
    :lastUpdatedDate,
    :rehireDate,
    :talentResume,
    :latestActivityName,
    :additionalFederalWithholding,
    :mailingAddress,
    :terminationDate,
    :latestActivityDate,
    :homePhone,
    :residentAddress,
    :w2Consent,
    :placementStatus,
    :addresses,
    :statusId,
    :enteredByUser,
    :race,
    :lastName,
    :firstName,
    :emailOptOut,
    :mobilePhone,
    :electronic1095CConsent,
    :emailAddress,
    :link,
    :birthday,
    :availabilityDate,
    :federalAllowances,
    :disability,
    :pageNumber,
    :latestWork,
    :hireDate,
    :stateAllowances,
    :workPhone,
    :lastContacted
  ]

  @type t :: %__MODULE__{
          representativeUserEmail: String.t() | nil,
          gender: String.t() | nil,
          referredBy: String.t() | nil,
          id: integer(),
          i9ValidatedDate: NaiveDateTime.t() | nil,
          frontOfficeId: integer(),
          officeDivision: String.t() | nil,
          flag: String.t() | nil,
          status: String.t() | nil,
          isArchived: boolean(),
          officeName: String.t() | nil,
          representativeUser: integer(),
          veteranStatus: String.t() | nil,
          middleName: String.t() | nil,
          taxIdNumber: String.t() | nil,
          electronic1099Consent: boolean() | nil,
          filingStatus: String.t(),
          createdDate: NaiveDateTime.t(),
          payrollAddress: Address.t() | nil,
          textConsent: String.t(),
          lastUpdatedDate: Date.t(),
          rehireDate: NaiveDateTime.t() | nil,
          talentResume: String.t() | nil,
          latestActivityName: String.t() | nil,
          additionalFederalWithholding: float(),
          mailingAddress: Address.t() | nil,
          terminationDate: NaiveDateTime.t() | nil,
          latestActivityDate: NaiveDateTime.t() | nil,
          homePhone: String.t() | nil,
          residentAddress: Address.t() | nil,
          w2Consent: boolean(),
          placementStatus: String.t(),
          addresses: [Address.t()],
          statusId: integer() | nil,
          enteredByUser: String.t() | nil,
          enteredByUserId: integer(),
          race: String.t() | nil,
          lastName: String.t(),
          firstName: String.t(),
          emailOptOut: boolean(),
          mobilePhone: String.t() | nil,
          electronic1095CConsent: boolean() | nil,
          emailAddress: String.t() | nil,
          link: String.t(),
          birthday: NaiveDateTime.t() | nil,
          availabilityDate: NaiveDateTime.t() | nil,
          federalAllowances: integer(),
          disability: String.t() | nil,
          pageNumber: String.t() | nil,
          latestWork: String.t() | nil,
          hireDate: NaiveDateTime.t() | nil,
          stateAllowances: integer(),
          workPhone: String.t() | nil,
          lastContacted: NaiveDateTime.t() | nil
        }

  @types %{
    representativeUserEmail: :string,
    gender: :string,
    referredBy: :string,
    id: :integer,
    i9ValidatedDate: :naive_datetime,
    frontOfficeId: :integer,
    officeDivision: :string,
    flag: :string,
    status: :string,
    isArchived: :boolean,
    officeName: :string,
    representativeUser: :integer,
    veteranStatus: :string,
    middleName: :string,
    taxIdNumber: :string,
    electronic1099Consent: :boolean,
    filingStatus: :string,
    createdDate: :date,
    payrollAddress: :map,
    textConsent: :string,
    lastUpdatedDate: :date,
    rehireDate: :naive_datetime,
    talentResume: :string,
    latestActivityName: :string,
    additionalFederalWithholding: :float,
    mailingAddress: :map,
    terminationDate: :naive_datetime,
    latestActivityDate: :naive_datetime,
    homePhone: :string,
    residentAddress: :map,
    w2Consent: :boolean,
    placementStatus: :string,
    addresses: {:array, :map},
    statusId: :integer,
    enteredByUser: :string,
    enteredByUserId: :integer,
    race: :string,
    lastName: :string,
    firstName: :string,
    emailOptOut: :boolean,
    mobilePhone: :string,
    electronic1095CConsent: :boolean,
    emailAddress: :string,
    link: :string,
    birthday: :naive_datetime,
    availabilityDate: :naive_datetime,
    federalAllowances: :integer,
    disability: :string,
    pageNumber: :string,
    latestWork: :string,
    hireDate: :naive_datetime,
    stateAllowances: :integer,
    workPhone: :string,
    lastContacted: :naive_datetime
  }

  def to_struct!(params) do
    {%__MODULE__{}, @types}
    |> Ecto.Changeset.cast(params, Map.keys(@types))
    |> SchemalessAssoc.cast(:addresses, {:array, Address})
    |> SchemalessAssoc.cast([:mailingAddress, :residentAddress, :payrollAddress], Address)
    |> Ecto.Changeset.apply_action!(:cast)
  end

  def to_list_of_custom_properties do
    # possible types are date, number, float, text, boolean, list, and map
    [
      %{key: "representative_user_email", label: "Representative User Email", type: "text"},
      %{key: "gender", label: "Gender", type: "text"},
      %{key: "referred_by", label: "Referred By", type: "text"},
      %{
        key: "id",
        label: "ID",
        type: "number",
        whippy_associations: [
          %{
            source_property_key: "id",
            target_property_key: "external_id",
            target_whippy_resource: "contact",
            target_property_key_prefix: nil,
            type: "one_to_one"
          }
        ]
      },
      %{key: "i9_validated_date", label: "I9 Validated Date", type: "date"},
      %{key: "front_office_id", label: "Front Office ID", type: "number"},
      %{key: "office_division", label: "Office Division", type: "text"},
      %{key: "flag", label: "Flag", type: "text"},
      %{key: "status", label: "Status", type: "text"},
      %{key: "is_archived", label: "Is Archived", type: "boolean"},
      %{key: "office_name", label: "Office Name", type: "text"},
      %{key: "representative_user", label: "Representative User", type: "number"},
      %{key: "veteran_status", label: "Veteran Status", type: "text"},
      %{key: "middle_name", label: "Middle Name", type: "text"},
      %{key: "tax_id_number", label: "Tax ID Number", type: "text"},
      %{key: "electronic_1099_consent", label: "Electronic 1099 Consent", type: "boolean"},
      %{key: "filing_status", label: "Filing Status", type: "text"},
      %{key: "created_date", label: "Created Date", type: "date"},
      %{key: "payroll_address", label: "Payroll Address", type: "map"},
      %{key: "text_consent", label: "Text Consent", type: "text"},
      %{key: "last_updated_date", label: "Last Updated Date", type: "date"},
      %{key: "rehire_date", label: "Rehire Date", type: "date"},
      %{key: "talent_resume", label: "Talent Resume", type: "text"},
      %{key: "latest_activity_name", label: "Latest Activity Name", type: "text"},
      %{key: "additional_federal_withholding", label: "Additional Federal Withholding", type: "float"},
      %{key: "mailing_address", label: "Mailing Address", type: "map"},
      %{key: "termination_date", label: "Termination Date", type: "date"},
      %{key: "latest_activity_date", label: "Latest Activity Date", type: "date"},
      %{key: "home_phone", label: "Home Phone", type: "text"},
      %{key: "resident_address", label: "Resident Address", type: "map"},
      %{key: "w2_consent", label: "W2 Consent", type: "boolean"},
      %{key: "placement_status", label: "Placement Status", type: "text"},
      %{key: "addresses", label: "Addresses", type: "list"},
      %{key: "status_id", label: "Status ID", type: "number"},
      %{key: "entered_by_user", label: "Entered By User", type: "text"},
      %{key: "entered_by_user_id", label: "Entered By User ID", type: "number"},
      %{key: "race", label: "Race", type: "text"},
      %{key: "last_name", label: "Last Name", type: "text"},
      %{key: "first_name", label: "First Name", type: "text"},
      %{key: "email_opt_out", label: "Email Opt-Out", type: "boolean"},
      %{key: "mobile_phone", label: "Mobile Phone", type: "text"},
      %{key: "electronic_1095c_consent", label: "Electronic 1095C Consent", type: "boolean"},
      %{key: "email_address", label: "Email Address", type: "text"},
      %{key: "link", label: "Link", type: "text"},
      %{key: "birthday", label: "Birthday", type: "date"},
      %{key: "availability_date", label: "Availability Date", type: "date"},
      %{key: "federal_allowances", label: "Federal Allowances", type: "number"},
      %{key: "disability", label: "Disability", type: "text"},
      %{key: "page_number", label: "Page Number", type: "text"},
      %{key: "latest_work", label: "Latest Work", type: "text"},
      %{key: "hire_date", label: "Hire Date", type: "date"},
      %{key: "state_allowances", label: "State Allowances", type: "number"},
      %{key: "work_phone", label: "Work Phone", type: "text"},
      %{key: "last_contacted", label: "Last Contacted", type: "date"}
    ]
  end
end

defmodule Sync.Clients.Avionte.Model.TalentActivity do
  @moduledoc """
  This module defines the struct for the TalentActivity model. This is how Avionte
  represents a TalentActivity in the response of "Create a TalentActivity" endpoint.

  The TalentActivity object with definitions for each field can be found here:
  https://developer.avionte.com/reference/createtalentactivity
  """

  @derive Jason.Encoder

  defstruct [
    :typeId,
    :name,
    :show_in,
    :activityDate,
    :talentId,
    :id,
    :notes,
    :userId
  ]

  @type t :: %__MODULE__{
          typeId: integer(),
          name: String.t(),
          show_in: -2 | -1 | 0 | 1 | 2,
          activityDate: NaiveDateTime.t(),
          talentId: integer(),
          id: integer(),
          notes: String.t(),
          userId: integer()
        }

  @types %{
    typeId: :integer,
    name: :string,
    show_in: :integer,
    activityDate: :naive_datetime,
    talentId: :integer,
    id: :integer,
    notes: :string,
    userId: :integer
  }

  def to_struct!(params) do
    {%__MODULE__{}, @types}
    |> Ecto.Changeset.cast(params, Map.keys(@types))
    |> Ecto.Changeset.apply_action!(:cast)
  end
end

defmodule Sync.Clients.Avionte.Model.TalentRequirement do
  @moduledoc """
  This module defines the struct for the TalentRequirement model. This is how Avionte
  represents a TalentRequirement in the response of "Get Talent Requirements" endpoint.

  The TalentRequirement object with definitions for each field can be found here:
  https://developer.avionte.com/reference/getnewtalentrequirement
  """

  @derive Jason.Encoder

  defstruct [
    :firstName,
    :lastName,
    :country,
    :address,
    :city,
    :state,
    :zip,
    :phone,
    :email,
    :linkedInProfile,
    :personalSite,
    :custom1,
    :custom2,
    :skills,
    :applicantTags,
    :resume,
    :region,
    :currentCompany,
    :applicantSource,
    :industryExperience,
    :workHistoryCompany,
    :workHistoryPosition,
    :educationHistorySchool,
    :educationDegree,
    :educationField
  ]

  @type t :: %__MODULE__{
          firstName: boolean(),
          lastName: boolean(),
          country: boolean(),
          address: boolean(),
          city: boolean(),
          state: boolean(),
          zip: boolean(),
          phone: boolean(),
          email: boolean(),
          linkedInProfile: boolean(),
          personalSite: boolean(),
          custom1: boolean(),
          custom2: boolean(),
          skills: boolean(),
          applicantTags: boolean(),
          resume: boolean(),
          region: boolean(),
          currentCompany: boolean(),
          applicantSource: boolean(),
          industryExperience: boolean(),
          workHistoryCompany: boolean(),
          workHistoryPosition: boolean(),
          educationHistorySchool: boolean(),
          educationDegree: boolean(),
          educationField: boolean()
        }

  @types %{
    firstName: :boolean,
    lastName: :boolean,
    country: :boolean,
    address: :boolean,
    city: :boolean,
    state: :boolean,
    zip: :boolean,
    phone: :boolean,
    email: :boolean,
    linkedInProfile: :boolean,
    personalSite: :boolean,
    custom1: :boolean,
    custom2: :boolean,
    skills: :boolean,
    applicantTags: :boolean,
    resume: :boolean,
    region: :boolean,
    currentCompany: :boolean,
    applicantSource: :boolean,
    industryExperience: :boolean,
    workHistoryCompany: :boolean,
    workHistoryPosition: :boolean,
    educationHistorySchool: :boolean,
    educationDegree: :boolean,
    educationField: :boolean
  }

  def to_struct!(params) do
    {%__MODULE__{}, @types}
    |> Ecto.Changeset.cast(params, Map.keys(@types))
    |> Ecto.Changeset.apply_action!(:cast)
  end
end

defmodule Sync.Clients.Avionte.Model.TalentActivityType do
  @moduledoc """
  This module defines the struct for the TalentActivityType model. This is how Avionte
  represents a TalentActivityType in the response of "Get All Talent Activity Types" endpoint.

  The TalentActivityType object with definitions for each field can be found here:
  https://developer.avionte.com/reference/getalltalentactivitytypes
  """

  @derive Jason.Encoder

  defstruct [
    :typeId,
    :name,
    :show_in
  ]

  @type t :: %__MODULE__{
          typeId: integer(),
          name: String.t(),
          show_in: -2 | -1 | 0 | 1 | 2
        }

  @types %{
    typeId: :integer,
    name: :string,
    show_in: :integer
  }

  def to_struct!(params) do
    {%__MODULE__{}, @types}
    |> Ecto.Changeset.cast(params, Map.keys(@types))
    |> Ecto.Changeset.apply_action!(:cast)
  end
end

defmodule Sync.Clients.Avionte.Model.User do
  @moduledoc """
  This module defines the struct for the User model. This is how Avionte
  represents a User when listing or getting a User.

  The User object with definitions for each field can be found here:
  https://developer.avionte.com/reference/querymultipleusers
  """

  alias Sync.Clients.Avionte.Model.Address
  alias Sync.Utils.Ecto.Changeset.SchemalessAssoc

  @derive Jason.Encoder

  defstruct [
    :userId,
    :firstName,
    :lastName,
    :emailAddress,
    :homePhone,
    :workPhone,
    :mobilePhone,
    :faxPhone,
    :address,
    :officeName,
    :officeDivision,
    :officeRegion,
    :isArchived,
    :createdDate,
    :lastUpdatedDate,
    :smsPhoneNumber,
    :smsForwardingNumber
  ]

  @type t :: %__MODULE__{
          userId: integer(),
          firstName: String.t(),
          lastName: String.t(),
          emailAddress: String.t(),
          homePhone: String.t() | nil,
          workPhone: String.t() | nil,
          mobilePhone: String.t() | nil,
          faxPhone: String.t() | nil,
          address: Address.t(),
          officeName: String.t(),
          officeDivision: String.t(),
          officeRegion: String.t(),
          isArchived: boolean(),
          createdDate: NaiveDateTime.t(),
          lastUpdatedDate: NaiveDateTime.t(),
          smsPhoneNumber: String.t() | nil,
          smsForwardingNumber: String.t() | nil
        }

  @types %{
    userId: :integer,
    firstName: :string,
    lastName: :string,
    emailAddress: :string,
    homePhone: :string,
    workPhone: :string,
    mobilePhone: :string,
    faxPhone: :string,
    address: :map,
    officeName: :string,
    officeDivision: :string,
    officeRegion: :string,
    isArchived: :boolean,
    createdDate: :naive_datetime,
    lastUpdatedDate: :naive_datetime,
    smsPhoneNumber: :string,
    smsForwardingNumber: :string
  }

  def to_struct!(params) do
    {%__MODULE__{}, @types}
    |> Ecto.Changeset.cast(params, Map.keys(@types))
    |> SchemalessAssoc.cast(:address, Address)
    |> Ecto.Changeset.apply_action!(:cast)
  end
end

defmodule Sync.Clients.Avionte.Model.Representative do
  @moduledoc """
  This module defines the struct for the Address model. This is how Avionte
  represents an Address in the address fields when listing or getting a Talent.
  """

  @derive Jason.Encoder

  defstruct [
    :id
  ]

  @type t :: %__MODULE__{
          id: integer()
        }

  @types %{
    id: :integer
  }

  def to_struct!(params) do
    {%__MODULE__{}, @types}
    |> Ecto.Changeset.cast(params, Map.keys(@types))
    |> Ecto.Changeset.apply_action!(:cast)
  end
end

defmodule Sync.Clients.Avionte.Model.AvionteContact do
  @moduledoc """
  This module defines the struct for the Talent model. This is how Avionte
  represents a Talent when listing or getting a Talent.

  The Talent object with definitions for each field can be found here:
  https://developer.avionte.com/reference/querymultipletalents
  """

  alias Sync.Clients.Avionte.Model.Address
  alias Sync.Clients.Avionte.Model.Representative
  alias Sync.Utils.Ecto.Changeset.SchemalessAssoc

  @derive Jason.Encoder

  defstruct [
    :id,
    :firstName,
    :middleName,
    :lastName,
    :workPhone,
    :cellPhone,
    :emailAddress,
    :emailAddress2,
    :address1,
    :address2,
    :city,
    :state,
    :postalCode,
    :country,
    :link,
    :companyName,
    :companyId,
    :companyDepartmentId,
    :title,
    :emailOptOut,
    :isArchived,
    :representativeUsers,
    :createdDate,
    :lastUpdatedDate,
    :latestActivityDate,
    :latestActivityName,
    :status,
    :statusType,
    :origin,
    :officeName
  ]

  @type t :: %__MODULE__{
          id: integer(),
          firstName: String.t() | nil,
          middleName: String.t() | nil,
          lastName: String.t() | nil,
          workPhone: String.t() | nil,
          cellPhone: String.t() | nil,
          emailAddress: String.t() | nil,
          emailAddress2: String.t() | nil,
          address1: String.t() | nil,
          address2: String.t() | nil,
          city: String.t() | nil,
          state: String.t() | nil,
          postalCode: String.t() | nil,
          country: String.t() | nil,
          link: String.t() | nil,
          companyName: String.t() | nil,
          companyId: integer() | nil,
          companyDepartmentId: integer() | nil,
          title: String.t() | nil,
          emailOptOut: boolean(),
          isArchived: boolean(),
          representativeUsers: [Representative.t()],
          createdDate: Date.t(),
          lastUpdatedDate: Date.t(),
          latestActivityDate: Date.t() | nil,
          latestActivityName: String.t() | nil,
          status: String.t() | nil,
          statusType: String.t() | nil,
          origin: String.t() | nil,
          officeName: String.t() | nil
        }

  @types %{
    id: :integer,
    firstName: :string,
    middleName: :string,
    lastName: :string,
    workPhone: :string,
    cellPhone: :string,
    emailAddress: :string,
    emailAddress2: :string,
    address1: :string,
    address2: :string,
    city: :string,
    state: :string,
    postalCode: :string,
    country: :string,
    link: :string,
    companyName: :string,
    companyId: :integer,
    companyDepartmentId: :integer,
    title: :string,
    emailOptOut: :boolean,
    isArchived: :boolean,
    representativeUsers: {:array, :integer},
    createdDate: :date,
    lastUpdatedDate: :date,
    latestActivityDate: :date,
    latestActivityName: :string,
    status: :string,
    statusType: :string,
    origin: :string,
    officeName: :string
  }

  def to_struct!(params) do
    {%__MODULE__{}, @types}
    |> Ecto.Changeset.cast(params, Map.keys(@types))
    |> Ecto.Changeset.apply_action!(:cast)
  end

  def to_list_of_custom_properties do
    # possible types are date, number, float, text, boolean, list, and map
    [
      %{key: "id", label: "ID", type: "number"},
      %{key: "first_name", label: "First Name", type: "text"},
      %{key: "middle_name", label: "Middle Name", type: "text"},
      %{key: "last_name", label: "Last Name", type: "text"},
      %{key: "work_phone", label: "Work Phone", type: "text"},
      %{key: "cell_phone", label: "Cell Phone", type: "text"},
      %{key: "email_address", label: "Email Address", type: "text"},
      %{key: "email_address2", label: "Email Address 2", type: "text"},
      %{key: "address1", label: "Address 1", type: "text"},
      %{key: "address2", label: "Address 2", type: "text"},
      %{key: "city", label: "City", type: "text"},
      %{key: "state", label: "State", type: "text"},
      %{key: "postal_code", label: "Postal Code", type: "text"},
      %{key: "country", label: "Country", type: "text"},
      %{key: "link", label: "Link", type: "text"},
      %{key: "company_name", label: "Company Name", type: "text"},
      %{key: "company_id", label: "Company ID", type: "number"},
      %{key: "company_department_id", label: "Company Department ID", type: "number"},
      %{key: "title", label: "Title", type: "text"},
      %{key: "email_opt_out", label: "Email Opt Out", type: "boolean"},
      %{key: "is_archived", label: "Is Archived", type: "boolean"},
      %{key: "representative_users", label: "Representative Users", type: "list"},
      %{key: "created_date", label: "Created Date", type: "date"},
      %{key: "last_updated_date", label: "Last Updated Date", type: "date"},
      %{key: "latest_activity_date", label: "Latest Activity Date", type: "date"},
      %{key: "latest_activity_name", label: "Latest Activity Name", type: "text"},
      %{key: "status", label: "Status", type: "text"},
      %{key: "status_type", label: "Status Type", type: "text"},
      %{key: "origin", label: "Origin", type: "text"},
      %{key: "office_name", label: "Office Name", type: "text"}
    ]
  end
end

defmodule Sync.Clients.Avionte.Model.Company do
  @moduledoc """
  This module defines the struct for the Company model. This is how Avionte
  represents a Company when listing or getting a Company.
  """

  alias Sync.Clients.Avionte.Model.Address
  alias Sync.Clients.Avionte.Model.Representative
  alias Sync.Utils.Ecto.Changeset.SchemalessAssoc

  @derive Jason.Encoder

  defstruct [
    :id,
    :name,
    :mainAddress,
    :billingAddress,
    :frontOfficeId,
    :link,
    :isArchived,
    :representativeUsers,
    :statusId,
    :status,
    :statusType,
    :industry,
    :createdDate,
    :lastUpdatedDate,
    :latestActivityDate,
    :latestActivityName,
    :openJobs,
    :phoneNumber,
    :fax,
    :webSite,
    :origin,
    :originRecordId,
    :weekEndDay,
    :payPeriod,
    :payCycle,
    :billingPeriod,
    :billingCycle
  ]

  @type t :: %__MODULE__{
          id: integer(),
          name: String.t(),
          mainAddress: Address.t(),
          billingAddress: Address.t(),
          frontOfficeId: integer(),
          link: String.t(),
          isArchived: boolean(),
          representativeUsers: [Representative.t()],
          statusId: integer(),
          status: String.t(),
          statusType: String.t(),
          industry: String.t(),
          createdDate: Date.t(),
          lastUpdatedDate: Date.t(),
          latestActivityDate: Date.t(),
          latestActivityName: String.t(),
          openJobs: integer(),
          phoneNumber: String.t(),
          fax: String.t(),
          webSite: String.t(),
          origin: String.t(),
          originRecordId: String.t(),
          weekEndDay: String.t(),
          payPeriod: String.t(),
          payCycle: String.t(),
          billingPeriod: String.t(),
          billingCycle: String.t()
        }

  @types %{
    id: :integer,
    name: :string,
    mainAddress: :map,
    billingAddress: :map,
    frontOfficeId: :integer,
    link: :string,
    isArchived: :boolean,
    representativeUsers: {:array, :integer},
    statusId: :integer,
    status: :string,
    statusType: :string,
    industry: :string,
    createdDate: :date,
    lastUpdatedDate: :date,
    latestActivityDate: :date,
    latestActivityName: :string,
    openJobs: :integer,
    phoneNumber: :string,
    fax: :string,
    webSite: :string,
    origin: :string,
    originRecordId: :string,
    weekEndDay: :string,
    payPeriod: :string,
    payCycle: :string,
    billingPeriod: :string,
    billingCycle: :string
  }

  def to_struct!(params) do
    {%__MODULE__{}, @types}
    |> Ecto.Changeset.cast(params, Map.keys(@types))
    |> SchemalessAssoc.cast(:mainAddress, Address)
    |> SchemalessAssoc.cast(:billingAddress, Address)
    |> Ecto.Changeset.apply_action!(:cast)
  end

  def to_list_of_custom_properties do
    # possible types are date, number, float, text, boolean, list, and map
    [
      %{key: "id", label: "ID", type: "number"},
      %{key: "name", label: "Name", type: "text"},
      %{key: "main_address", label: "Main Address", type: "map"},
      %{key: "billing_address", label: "Billing Address", type: "map"},
      %{key: "front_office_id", label: "Front Office ID", type: "number"},
      %{key: "link", label: "Link", type: "text"},
      %{key: "is_archived", label: "Is Archived", type: "boolean"},
      %{key: "representative_users", label: "Representative Users", type: "list"},
      %{key: "status_id", label: "Status ID", type: "number"},
      %{key: "status", label: "Status", type: "text"},
      %{key: "status_type", label: "Status Type", type: "text"},
      %{key: "industry", label: "Industry", type: "text"},
      %{key: "created_date", label: "Created Date", type: "date"},
      %{key: "last_updated_date", label: "Last Updated Date", type: "date"},
      %{key: "latest_activity_date", label: "Latest Activity Date", type: "date"},
      %{key: "latest_activity_name", label: "Latest Activity Name", type: "text"},
      %{key: "open_jobs", label: "Open Jobs", type: "number"},
      %{key: "phone_number", label: "Phone Number", type: "text"},
      %{key: "fax", label: "Fax", type: "text"},
      %{key: "web_site", label: "Web Site", type: "text"},
      %{key: "origin", label: "Origin", type: "text"},
      %{key: "origin_record_id", label: "Origin Record ID", type: "text"},
      %{key: "week_end_day", label: "Week End Day", type: "text"},
      %{key: "pay_period", label: "Pay Period", type: "text"},
      %{key: "pay_cycle", label: "Pay Cycle", type: "text"},
      %{key: "billing_period", label: "Billing Period", type: "text"},
      %{key: "billing_cycle", label: "Billing Cycle", type: "text"}
    ]
  end
end

defmodule Sync.Clients.Avionte.Model.Placement do
  @moduledoc """
  This module defines the struct for the Placement model. This is how Avionte
  represents a Placement when listing or getting a Placement.
  """

  alias Sync.Clients.Avionte.Model.Representative

  @derive Jason.Encoder

  defstruct [
    :id,
    :talentId,
    :jobId,
    :extensionId,
    :extensionIdList,
    :startDate,
    :endDate,
    :isActive,
    :payRates,
    :billRates,
    :commissionUsers,
    :estimatedGrossProfit,
    :employmentType,
    :frontOfficeId,
    :isPermanentPlacementExtension,
    :payBasis,
    :hiredDate,
    :endReasonId,
    :endReason,
    :enteredByUserId,
    :enteredByUser,
    :recruiterUserId,
    :recruiterUser,
    :customDetails,
    :createdByUserId,
    :createdDate,
    :hasNoEndDate,
    :originalStartDate,
    :finalEndDate,
    :origin,
    :reqEmploymentType,
    :reqEmploymentTypeName,
    :shiftName,
    :placementScheduleShifts,
    :placementScheduleDays
  ]

  @type t :: %__MODULE__{
          id: integer(),
          talentId: integer(),
          jobId: integer(),
          extensionId: integer(),
          extensionIdList: [integer()],
          startDate: Date.t(),
          endDate: Date.t(),
          isActive: boolean(),
          payRates: map(),
          billRates: map(),
          commissionUsers: [map()],
          estimatedGrossProfit: float(),
          employmentType: String.t(),
          frontOfficeId: integer(),
          isPermanentPlacementExtension: boolean(),
          payBasis: String.t(),
          hiredDate: Date.t(),
          endReasonId: integer(),
          endReason: String.t(),
          enteredByUserId: integer(),
          enteredByUser: String.t(),
          recruiterUserId: integer(),
          recruiterUser: String.t(),
          customDetails: [map()],
          createdByUserId: integer(),
          createdDate: Date.t(),
          hasNoEndDate: boolean(),
          originalStartDate: Date.t(),
          finalEndDate: Date.t(),
          origin: String.t(),
          reqEmploymentType: String.t(),
          reqEmploymentTypeName: String.t(),
          shiftName: String.t(),
          placementScheduleShifts: [map()],
          placementScheduleDays: map()
        }

  @types %{
    id: :integer,
    talentId: :integer,
    jobId: :integer,
    extensionId: :integer,
    extensionIdList: {:array, :integer},
    startDate: :date,
    endDate: :date,
    isActive: :boolean,
    payRates: :map,
    billRates: :map,
    commissionUsers: {:array, :map},
    estimatedGrossProfit: :float,
    employmentType: :string,
    frontOfficeId: :integer,
    isPermanentPlacementExtension: :boolean,
    payBasis: :string,
    hiredDate: :date,
    endReasonId: :integer,
    endReason: :string,
    enteredByUserId: :integer,
    enteredByUser: :string,
    recruiterUserId: :integer,
    recruiterUser: :string,
    customDetails: {:array, :map},
    createdByUserId: :integer,
    createdDate: :date,
    hasNoEndDate: :boolean,
    originalStartDate: :date,
    finalEndDate: :date,
    origin: :string,
    reqEmploymentType: :string,
    reqEmploymentTypeName: :string,
    shiftName: :string,
    placementScheduleShifts: {:array, :map},
    placementScheduleDays: :map
  }

  def to_struct!(params) do
    {%__MODULE__{}, @types}
    |> Ecto.Changeset.cast(params, Map.keys(@types))
    |> Ecto.Changeset.apply_action!(:cast)
  end

  def to_list_of_custom_properties do
    [
      %{key: "id", label: "ID", type: "number"},
      %{key: "talent_id", label: "Talent ID", type: "number"},
      %{key: "job_id", label: "Job ID", type: "number"},
      %{key: "extension_id", label: "Extension ID", type: "number"},
      %{key: "extension_id_list", label: "Extension ID List", type: "list"},
      %{key: "start_date", label: "Start Date", type: "date"},
      %{key: "end_date", label: "End Date", type: "date"},
      %{key: "is_active", label: "Is Active", type: "boolean"},
      %{key: "pay_rates", label: "Pay Rates", type: "map"},
      %{key: "bill_rates", label: "Bill Rates", type: "map"},
      %{key: "commission_users", label: "Commission Users", type: "list"},
      %{key: "estimated_gross_profit", label: "Estimated Gross Profit", type: "float"},
      %{key: "employment_type", label: "Employment Type", type: "text"},
      %{key: "front_office_id", label: "Front Office ID", type: "number"},
      %{key: "is_permanent_placement_extension", label: "Is Permanent Placement Extension", type: "boolean"},
      %{key: "pay_basis", label: "Pay Basis", type: "text"},
      %{key: "hired_date", label: "Hired Date", type: "date"},
      %{key: "end_reason_id", label: "End Reason ID", type: "number"},
      %{key: "end_reason", label: "End Reason", type: "text"},
      %{key: "entered_by_user_id", label: "Entered By User ID", type: "number"},
      %{key: "entered_by_user", label: "Entered By User", type: "text"},
      %{key: "recruiter_user_id", label: "Recruiter User ID", type: "number"},
      %{key: "recruiter_user", label: "Recruiter User", type: "text"},
      %{key: "custom_details", label: "Custom Details", type: "list"},
      %{key: "created_by_user_id", label: "Created By User ID", type: "number"},
      %{key: "created_date", label: "Created Date", type: "date"},
      %{key: "has_no_end_date", label: "Has No End Date", type: "boolean"},
      %{key: "original_start_date", label: "Original Start Date", type: "date"},
      %{key: "final_end_date", label: "Final End Date", type: "date"},
      %{key: "origin", label: "Origin", type: "text"},
      %{key: "req_employment_type", label: "Req Employment Type", type: "text"},
      %{key: "req_employment_type_name", label: "Req Employment Type Name", type: "text"},
      %{key: "shift_name", label: "Shift Name", type: "text"},
      %{key: "placement_schedule_shifts", label: "Placement Schedule Shifts", type: "list"},
      %{key: "placement_schedule_days", label: "Placement Schedule Days", type: "map"}
    ]
  end
end

defmodule Sync.Clients.Avionte.Model.Jobs do
  @moduledoc """
  This module defines the struct for the Job model. This is how Avionte
  represents a Job when listing or getting a Job.
  """

  alias Sync.Clients.Avionte.Model.Address
  alias Sync.Clients.Avionte.Model.Representative
  alias Sync.Utils.Ecto.Changeset.SchemalessAssoc

  @derive Jason.Encoder

  defstruct [
    :id,
    :positions,
    :startDate,
    :endDate,
    :payRates,
    :billRates,
    :title,
    :costCenter,
    :employeeType,
    :workersCompensationClassCode,
    :workerCompCode,
    :workerCompCodeId,
    :companyId,
    :branchId,
    :frontOfficeId,
    :addressId,
    :worksiteAddress,
    :poId,
    :companyName,
    :link,
    :contactId,
    :statusId,
    :status,
    :posted,
    :createdDate,
    :orderType,
    :orderTypeId,
    :representativeUsers,
    :isArchived,
    :oT_Type,
    :enteredByUserId,
    :enteredByUser,
    :salesRepUserId,
    :salesRepUser,
    :description,
    :customJobDetails,
    :lastUpdatedDate,
    :latestActivityDate,
    :latestActivityName,
    :hasNoEndDate,
    :payPeriod,
    :placed,
    :overtimeRuleID,
    :startTimeLocal,
    :endTimeLocal,
    :shiftScheduleDays,
    :offer,
    :pickList,
    :postJobToMobileApp,
    :origin,
    :worksiteAddressId,
    :ownerUserId,
    :bundled,
    :startOfWeek,
    :shiftName,
    :scheduleLengthWeeks,
    :scheduleShifts,
    :notes,
    :estimatedHours,
    :targetBillRate,
    :targetPayRate,
    :expenseType,
    :useCustomOTRates,
    :overtimeBillRate,
    :overtimePayRate,
    :doubletimeBillRate,
    :doubletimePayRate,
    :rateType,
    :weekDuration,
    :markupPercentage,
    :billingManagerId,
    :billingName,
    :billingAddress1,
    :billingAddress2,
    :billingCity,
    :billingState,
    :billingZip,
    :billingEmail,
    :billingTerm,
    :placementFee,
    :placementPercentage,
    :positionCategoryId,
    :division,
    :overtimeType,
    :maxBillRate,
    :minBillRate,
    :maxPayRate,
    :minPayRate,
    :billingPhone,
    :department
  ]

  @type t :: %__MODULE__{
          id: integer(),
          positions: integer(),
          startDate: Date.t(),
          endDate: Date.t(),
          payRates: map(),
          billRates: map(),
          title: String.t(),
          costCenter: String.t(),
          employeeType: String.t(),
          workersCompensationClassCode: String.t(),
          workerCompCode: map(),
          workerCompCodeId: integer(),
          companyId: integer(),
          branchId: integer(),
          frontOfficeId: integer(),
          addressId: integer(),
          worksiteAddress: Address.t(),
          poId: integer(),
          companyName: String.t(),
          link: String.t(),
          contactId: integer(),
          statusId: integer(),
          status: String.t(),
          posted: boolean(),
          createdDate: Date.t(),
          orderType: String.t(),
          orderTypeId: integer(),
          representativeUsers: [Representative.t()],
          isArchived: boolean(),
          oT_Type: integer(),
          enteredByUserId: integer(),
          enteredByUser: String.t(),
          salesRepUserId: integer(),
          salesRepUser: String.t(),
          description: String.t() | nil,
          customJobDetails: [map()],
          lastUpdatedDate: Date.t() | nil,
          latestActivityDate: Date.t() | nil,
          latestActivityName: String.t() | nil,
          hasNoEndDate: boolean(),
          payPeriod: String.t() | nil,
          placed: integer(),
          overtimeRuleID: integer(),
          startTimeLocal: String.t() | nil,
          endTimeLocal: String.t(),
          shiftScheduleDays: map(),
          offer: boolean(),
          pickList: boolean(),
          postJobToMobileApp: boolean(),
          origin: String.t() | nil,
          worksiteAddressId: integer(),
          ownerUserId: integer(),
          bundled: boolean(),
          startOfWeek: String.t() | nil,
          shiftName: String.t() | nil,
          scheduleLengthWeeks: integer(),
          scheduleShifts: [map()],
          notes: String.t(),
          estimatedHours: integer(),
          targetBillRate: float(),
          targetPayRate: float(),
          expenseType: String.t(),
          useCustomOTRates: boolean(),
          overtimeBillRate: float(),
          overtimePayRate: float(),
          doubletimeBillRate: float(),
          doubletimePayRate: float(),
          rateType: String.t() | nil,
          weekDuration: String.t(),
          markupPercentage: float(),
          billingManagerId: integer(),
          billingName: String.t(),
          billingAddress1: String.t(),
          billingAddress2: String.t() | nil,
          billingCity: String.t(),
          billingState: String.t(),
          billingZip: String.t(),
          billingEmail: String.t(),
          billingTerm: String.t(),
          placementFee: float(),
          placementPercentage: float(),
          positionCategoryId: integer() | nil,
          division: String.t() | nil,
          overtimeType: String.t(),
          maxBillRate: float(),
          minBillRate: float(),
          maxPayRate: float(),
          minPayRate: float(),
          billingPhone: String.t(),
          department: String.t() | nil
        }

  @types %{
    id: :integer,
    positions: :integer,
    startDate: :date,
    endDate: :date,
    payRates: :map,
    billRates: :map,
    title: :string,
    costCenter: :string,
    employeeType: :string,
    workersCompensationClassCode: :string,
    workerCompCode: :map,
    workerCompCodeId: :integer,
    companyId: :integer,
    branchId: :integer,
    frontOfficeId: :integer,
    addressId: :integer,
    worksiteAddress: :map,
    poId: :integer,
    companyName: :string,
    link: :string,
    contactId: :integer,
    statusId: :integer,
    status: :string,
    posted: :boolean,
    createdDate: :date,
    orderType: :string,
    orderTypeId: :integer,
    representativeUsers: {:array, :integer},
    isArchived: :boolean,
    oT_Type: :integer,
    enteredByUserId: :integer,
    enteredByUser: :string,
    salesRepUserId: :integer,
    salesRepUser: :string,
    description: :string,
    customJobDetails: {:array, :map},
    lastUpdatedDate: :date,
    latestActivityDate: :date,
    latestActivityName: :string,
    hasNoEndDate: :boolean,
    payPeriod: :string,
    placed: :integer,
    overtimeRuleID: :integer,
    startTimeLocal: :string,
    endTimeLocal: :string,
    shiftScheduleDays: :map,
    offer: :boolean,
    pickList: :boolean,
    postJobToMobileApp: :boolean,
    origin: :string,
    worksiteAddressId: :integer,
    ownerUserId: :integer,
    bundled: :boolean,
    startOfWeek: :string,
    shiftName: :string,
    scheduleLengthWeeks: :integer,
    scheduleShifts: {:array, :map},
    notes: :string,
    estimatedHours: :integer,
    targetBillRate: :float,
    targetPayRate: :float,
    expenseType: :string,
    useCustomOTRates: :boolean,
    overtimeBillRate: :float,
    overtimePayRate: :float,
    doubletimeBillRate: :float,
    doubletimePayRate: :float,
    rateType: :string,
    weekDuration: :string,
    markupPercentage: :float,
    billingManagerId: :integer,
    billingName: :string,
    billingAddress1: :string,
    billingAddress2: :string,
    billingCity: :string,
    billingState: :string,
    billingZip: :string,
    billingEmail: :string,
    billingTerm: :string,
    placementFee: :float,
    placementPercentage: :float,
    positionCategoryId: :integer,
    division: :string,
    overtimeType: :string,
    maxBillRate: :float,
    minBillRate: :float,
    maxPayRate: :float,
    minPayRate: :float,
    billingPhone: :string,
    department: :string
  }

  def to_struct!(params) do
    {%__MODULE__{}, @types}
    |> Ecto.Changeset.cast(params, Map.keys(@types))
    |> Ecto.Changeset.apply_action!(:cast)
  end

  def to_list_of_custom_properties do
    [
      %{key: "id", label: "ID", type: "number"},
      %{key: "positions", label: "Positions", type: "number"},
      %{key: "start_date", label: "Start Date", type: "date"},
      %{key: "end_date", label: "End Date", type: "date"},
      %{key: "pay_rates", label: "Pay Rates", type: "map"},
      %{key: "bill_rates", label: "Bill Rates", type: "map"},
      %{key: "title", label: "Title", type: "text"},
      %{key: "cost_center", label: "Cost Center", type: "text"},
      %{key: "employee_type", label: "Employee Type", type: "text"},
      %{key: "workers_compensation_class_code", label: "Workers Compensation Class Code", type: "text"},
      %{key: "worker_comp_code", label: "Worker Comp Code", type: "map"},
      %{key: "worker_comp_code_id", label: "Worker Comp Code ID", type: "number"},
      %{key: "company_id", label: "Company ID", type: "number"},
      %{key: "branch_id", label: "Branch ID", type: "number"},
      %{key: "front_office_id", label: "Front Office ID", type: "number"},
      %{key: "address_id", label: "Address ID", type: "number"},
      %{key: "worksite_address", label: "Worksite Address", type: "map"},
      %{key: "po_id", label: "PO ID", type: "number"},
      %{key: "company_name", label: "Company Name", type: "text"},
      %{key: "link", label: "Link", type: "text"},
      %{key: "contact_id", label: "Contact ID", type: "number"},
      %{key: "status_id", label: "Status ID", type: "number"},
      %{key: "status", label: "Status", type: "text"},
      %{key: "posted", label: "Posted", type: "boolean"},
      %{key: "created_date", label: "Created Date", type: "date"},
      %{key: "order_type", label: "Order Type", type: "text"},
      %{key: "order_type_id", label: "Order Type ID", type: "number"},
      %{key: "representative_users", label: "Representative Users", type: "map"},
      %{key: "is_archived", label: "Is Archived", type: "boolean"},
      %{key: "o_t__type", label: "O/T Type", type: "number"},
      %{key: "entered_by_user_id", label: "Entered By User ID", type: "number"},
      %{key: "entered_by_user", label: "Entered By User", type: "text"},
      %{key: "sales_rep_user_id", label: "Sales Rep User ID", type: "number"},
      %{key: "sales_rep_user", label: "Sales Rep User", type: "text"},
      %{key: "description", label: "Description", type: "text"},
      %{key: "custom_job_details", label: "Custom Job Details", type: "list"},
      %{key: "last_updated_date", label: "Last Updated Date", type: "date"},
      %{key: "latest_activity_date", label: "Latest Activity Date", type: "date"},
      %{key: "latest_activity_name", label: "Latest Activity Name", type: "text"},
      %{key: "has_no_end_date", label: "Has No End Date", type: "boolean"},
      %{key: "pay_period", label: "Pay Period", type: "text"},
      %{key: "placed", label: "Placed", type: "number"},
      %{key: "overtime_rule_id", label: "Overtime Rule ID", type: "number"},
      %{key: "start_time_local", label: "Start Time Local", type: "text"},
      %{key: "end_time_local", label: "End Time Local", type: "text"},
      %{key: "shift_schedule_days", label: "Shift Schedule Days", type: "map"},
      %{key: "offer", label: "Offer", type: "boolean"},
      %{key: "pick_list", label: "Pick List", type: "boolean"},
      %{key: "post_job_to_mobile_app", label: "Post Job To Mobile App", type: "boolean"},
      %{key: "origin", label: "Origin", type: "text"},
      %{key: "worksite_address_id", label: "Worksite Address ID", type: "number"},
      %{key: "owner_user_id", label: "Owner User ID", type: "number"},
      %{key: "bundled", label: "Bundled", type: "boolean"},
      %{key: "start_of_week", label: "Start Of Week", type: "text"},
      %{key: "shift_name", label: "Shift Name", type: "text"},
      %{key: "schedule_length_weeks", label: "Schedule Length Weeks", type: "number"},
      %{key: "schedule_shifts", label: "Schedule Shifts", type: "map"},
      %{key: "notes", label: "Notes", type: "text"},
      %{key: "estimated_hours", label: "Estimated Hours", type: "number"},
      %{key: "target_bill_rate", label: "Target Bill Rate", type: "number"},
      %{key: "target_pay_rate", label: "Target Pay Rate", type: "number"},
      %{key: "expense_type", label: "Expense Type", type: "text"},
      %{key: "use_custom_ot_rates", label: "Use Custom O/T Rates", type: "boolean"},
      %{key: "overtime_bill_rate", label: "Overtime Bill Rate", type: "number"},
      %{key: "overtime_pay_rate", label: "Overtime Pay Rate", type: "number"},
      %{key: "doubletime_bill_rate", label: "Doubletime Bill Rate", type: "number"},
      %{key: "doubletime_pay_rate", label: "Doubletime Pay Rate", type: "number"},
      %{key: "rate_type", label: "Rate Type", type: "text"},
      %{key: "week_duration", label: "Week Duration", type: "text"},
      %{key: "markup_percentage", label: "Markup Percentage", type: "number"},
      %{key: "billing_manager_id", label: "Billing Manager ID", type: "number"},
      %{key: "billing_name", label: "Billing Name", type: "text"},
      %{key: "billing_address_1", label: "Billing Address 1", type: "text"},
      %{key: "billing_address_2", label: "Billing Address 2", type: "text"},
      %{key: "billing_city", label: "Billing City", type: "text"},
      %{key: "billing_state", label: "Billing State", type: "text"},
      %{key: "billing_zip", label: "Billing Zip", type: "text"},
      %{key: "billing_email", label: "Billing Email", type: "text"},
      %{key: "billing_term", label: "Billing Term", type: "text"},
      %{key: "placement_fee", label: "Placement Fee", type: "number"},
      %{key: "placement_percentage", label: "Placement Percentage", type: "number"},
      %{key: "position_category_id", label: "Position Category ID", type: "number"},
      %{key: "division", label: "Division", type: "text"},
      %{key: "overtime_type", label: "Overtime Type", type: "text"},
      %{key: "max_bill_rate", label: "Max Bill Rate", type: "number"},
      %{key: "min_bill_rate", label: "Min Bill Rate", type: "number"},
      %{key: "max_pay_rate", label: "Max Pay Rate", type: "number"},
      %{key: "min_pay_rate", label: "Min Pay Rate", type: "number"},
      %{key: "billing_phone", label: "Billing Phone", type: "text"},
      %{key: "department", label: "Department", type: "text"}
    ]
  end
end

defmodule Sync.Clients.Avionte.Model.ContactActivity do
  @moduledoc """
  This module defines the struct for the ContactActivity model. This is how Avionte
  represents a ContactActivity in the response of "Create a ContactActivity" endpoint.
  """
  @derive Jason.Encoder

  defstruct [
    :typeId,
    :name,
    :show_in,
    :activityDate,
    :contactId,
    :id,
    :notes,
    :userId
  ]

  @type t :: %__MODULE__{
          typeId: integer(),
          name: String.t(),
          show_in: -2 | -1 | 0 | 1 | 2,
          activityDate: NaiveDateTime.t(),
          contactId: integer(),
          id: integer(),
          notes: String.t(),
          userId: integer()
        }

  @types %{
    typeId: :integer,
    name: :string,
    show_in: :integer,
    activityDate: :naive_datetime,
    contactId: :integer,
    id: :integer,
    notes: :string,
    userId: :integer
  }

  def to_struct!(params) do
    {%__MODULE__{}, @types}
    |> Ecto.Changeset.cast(params, Map.keys(@types))
    |> Ecto.Changeset.apply_action!(:cast)
  end
end

defmodule Sync.Clients.Avionte.Model.ContactActivityType do
  @moduledoc """
  This module defines the struct for the ContactActivityType model. This is how Avionte
  represents a ContactActivityType in the response of "Get All Contact Activity Types" endpoint.

  The ContactActivityType object with definitions for each field can be found here:
  https://developer.avionte.com/reference/getallcontactactivitytypes
  """

  @derive Jason.Encoder

  defstruct [
    :typeId,
    :name,
    :show_in
  ]

  @type t :: %__MODULE__{
          typeId: integer(),
          name: String.t(),
          show_in: -2 | -1 | 0 | 1 | 2
        }

  @types %{
    typeId: :integer,
    name: :string,
    show_in: :integer
  }

  def to_struct!(params) do
    {%__MODULE__{}, @types}
    |> Ecto.Changeset.cast(params, Map.keys(@types))
    |> Ecto.Changeset.apply_action!(:cast)
  end
end
