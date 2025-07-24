defmodule Sync.Clients.Tempworks.Model.Employee do
  @moduledoc """
    This represents a the Employee that is returned from Tempworks when listing employees.

  ## Note
  There are three different forms of Employee that Tempworks returns depending on the request.
  1. Employee - Returned when we list employees
  2. EmployeeDetail - Returned when we get a specific employee by id
  3. CustomData - Returned when we get a specific employee by id AND request for that employee's
  custom data
  """

  @derive Jason.Encoder

  defstruct [
    :employeeId,
    :firstName,
    :lastName,
    :branch,
    :phoneNumber,
    :isActive,
    :isAssigned,
    :lastMessage,
    :postalCode,
    :hasResumeOnFile,
    :cellPhoneNumber,
    :emailAddress,
    :governmentPersonalId,
    :municipality,
    :serviceRep
  ]

  @type t :: %__MODULE__{
          employeeId: integer(),
          firstName: String.t(),
          lastName: String.t(),
          branch: String.t(),
          phoneNumber: String.t(),
          isActive: boolean(),
          isAssigned: boolean(),
          lastMessage: String.t(),
          postalCode: String.t() | nil,
          hasResumeOnFile: boolean(),
          cellPhoneNumber: String.t() | nil,
          emailAddress: String.t(),
          governmentPersonalId: String.t() | nil,
          municipality: String.t(),
          serviceRep: String.t()
        }

  def to_list_of_custom_properties do
    [
      %{key: "employee_id", label: "Employee Id", type: "number"},
      %{key: "last_name", label: "Last Name", type: "text"},
      %{key: "first_name", label: "First Name", type: "text"},
      %{key: "branch", label: "Branch", type: "text"},
      %{key: "phone_number", label: "Phone Number", type: "text"},
      %{key: "is_active", label: "Is Active", type: "boolean"},
      %{key: "is_assigned", label: "Is Assigned", type: "boolean"},
      %{key: "last_message", label: "Last Message", type: "text"},
      %{key: "postal_code", label: "Postal Code", type: "text"},
      %{key: "has_resume_on_file", label: "Has Resume On File", type: "boolean"},
      %{key: "cell_phone_number", label: "Cell Phone Number", type: "text"},
      %{key: "email_address", label: "Email Address", type: "text"},
      %{key: "government_personal_id", label: "Government Personal Id", type: "text"},
      %{key: "municipality", label: "Municipality", type: "text"},
      %{key: "service_rep", label: "Service Rep", type: "text"}
    ]
  end
end

defmodule Sync.Clients.Tempworks.Model.EmployeeStatus do
  @moduledoc """
  Represents the employee status data structure returned from the Tempworks API.

  This module defines the structure and types for employee status information, including:
  - Washing status and eligibility
  - Employment category and order type
  - Important dates (orientation, anniversary, interview)
  - Interview and verification details
  - WOTC (Work Opportunity Tax Credit) eligibility

  ## Fields

  - `washedStatusId` - Integer ID for the washing status
  - `washedStatus` - String description of the washing status
  - `isWashed` - Boolean indicating if the employee is washed
  - `employeeStatusId` - String ID for the employee status
  - `employeeStatus` - String description of the employee status
  - `employmentCategoryId` - String ID for employment category (optional)
  - `employmentCategory` - String description of employment category (optional)
  - `orderTypeId` - Integer ID for the order type
  - `orderType` - String description of the order type
  - `orientationGivenDate` - NaiveDateTime when orientation was given (optional)
  - `anniversaryDate` - NaiveDateTime of employment anniversary (optional)
  - `interviewDate` - NaiveDateTime of interview (optional)
  - `interviewedBySrIdent` - String ID of interviewer (optional)
  - `interviewedBy` - String name of interviewer (optional)
  - `wotcEligibilityStatusId` - String ID for WOTC eligibility (optional)
  - `wotcEligibilityStatus` - String description of WOTC eligibility (optional)
  - `isFaceVerificationOnboardingRequired` - Boolean indicating if face verification is required

  ## Usage

  This struct is typically used when retrieving detailed employee status information
  from Tempworks. It provides a standardized way to handle employee status data
  across the application.

  ## Example

      %EmployeeStatus{
        washedStatusId: 1,
        washedStatus: "Cleared",
        isWashed: true,
        employeeStatusId: "ACTIVE",
        employeeStatus: "Active",
        orderTypeId: 1,
        orderType: "Regular",
        isFaceVerificationOnboardingRequired: false
      }
  """

  @derive Jason.Encoder

  defstruct [
    :washedStatusId,
    :washedStatus,
    :isWashed,
    :employmentCategoryId,
    :employmentCategory,
    :orderTypeId,
    :orderType,
    :orientationGivenDate,
    :anniversaryDate,
    :interviewDate,
    :interviewedBySrIdent,
    :interviewedBy,
    :wotcEligibilityStatusId,
    :wotcEligibilityStatus,
    :isFaceVerificationOnboardingRequired
  ]

  @type t :: %__MODULE__{
          washedStatusId: integer(),
          washedStatus: String.t(),
          isWashed: boolean(),
          employmentCategoryId: String.t() | nil,
          employmentCategory: String.t() | nil,
          orderTypeId: integer(),
          orderType: String.t(),
          orientationGivenDate: NaiveDateTime.t() | nil,
          anniversaryDate: NaiveDateTime.t() | nil,
          interviewDate: NaiveDateTime.t() | nil,
          interviewedBySrIdent: NaiveDateTime.t() | nil,
          interviewedBy: String.t() | nil,
          wotcEligibilityStatusId: String.t() | nil,
          wotcEligibilityStatus: String.t() | nil,
          isFaceVerificationOnboardingRequired: boolean()
        }

  def to_list_of_custom_properties do
    [
      %{key: "washed_status_id", label: "Washed Status Id", type: "number"},
      %{key: "washed_status", label: "Washed Status", type: "text"},
      %{key: "is_washed", label: "Is Washed", type: "boolean"},
      %{key: "employment_category_id", label: "Employment Category Id", type: "text"},
      %{key: "employment_category", label: "Employment Category", type: "text"},
      %{key: "order_type_id", label: "Order Type Id", type: "number"},
      %{key: "orientation_given_date", label: "Orientation Given Date", type: "date"},
      %{key: "anniversary_date", label: "Anniversary Date", type: "date"},
      %{key: "interview_date", label: "Interview Date", type: "date"},
      %{key: "interviewed_by_sr_ident", label: "Interviewed By Sr Ident", type: "number"},
      %{key: "interviewed_by", label: "Interviewed By", type: "text"},
      %{key: "wotc_eligibility_status_id", label: "Wotc Eligibility Status Id", type: "text"},
      %{key: "wotc_eligibility_status", label: "Wotc Eligibility Status", type: "text"},
      %{
        key: "is_face_verification_onboarding_required",
        label: "Is Face Verification Onboarding Required",
        type: "boolean"
      }
    ]
  end
end

defmodule Sync.Clients.Tempworks.Model.TempworkContact do
  @moduledoc """
    This represents a the Contact that is returned from Tempworks when listing contacts.

  ## Note
  There are three different forms of Contact that Tempworks returns depending on the request.
  1. Contact - Returned when we list contacts
  2. ContactDetail - Returned when we get a specific contact by id
  3. CustomData - Returned when we get a specific contact by id AND request for that contact's
  custom data
  """

  @derive Jason.Encoder

  defstruct [
    :contactId,
    :lastName,
    :firstName,
    :customerId,
    :customerName,
    :departmentName,
    :title,
    :isActive,
    :status,
    :officePhone,
    :emailAddress,
    :branchName,
    :serviceRep
  ]

  @type t :: %__MODULE__{
          contactId: integer(),
          lastName: String.t(),
          firstName: String.t(),
          customerId: integer(),
          customerName: String.t(),
          departmentName: String.t(),
          title: String.t(),
          isActive: boolean(),
          status: String.t() | nil,
          officePhone: String.t() | nil,
          emailAddress: String.t(),
          branchName: String.t() | nil,
          serviceRep: String.t()
        }

  def to_list_of_custom_properties do
    [
      %{key: "contact_id", label: "Contact Id", type: "number"},
      %{key: "last_name", label: "Last Name", type: "text"},
      %{key: "first_name", label: "First Name", type: "text"},
      %{key: "customer_id", label: "Customer Id", type: "number"},
      %{key: "customer_name", label: "Customer Name", type: "text"},
      %{key: "department_name", label: "Department Name", type: "text"},
      %{key: "title", label: "Title", type: "text"},
      %{key: "is_active", label: "Is Active", type: "boolean"},
      %{key: "status", label: "Status", type: "text"},
      %{key: "office_phone", label: "Office Phone", type: "text"},
      %{key: "email_address", label: "Email Address", type: "text"},
      %{key: "branch_name", label: "Branch Name", type: "text"},
      %{key: "service_rep", label: "Service Rep", type: "text"}
    ]
  end
end

defmodule Sync.Clients.Tempworks.Model.TempworkContactDetail do
  @moduledoc """
    The TempworkContactDetail that is returned when we request information about a specific contact without
    their custom data.

    ## Note
    There are three different forms of contacts that Tempworks returns depending on the request.
    1. Contact - Returned when we list contacts
    2. TempworkContactDetail - Returned when we get a specific contact by id
    3. CustomData - Returned when we get a specific contact by id AND request for that user's
    custom data
  """

  alias Sync.Clients.Tempworks.Model.Address

  @derive Jason.Encoder

  defstruct [
    :contactId,
    :firstName,
    :lastName,
    :title,
    :nickname,
    :honorific,
    :birthday,
    :customerId,
    :customerName,
    :departmentName,
    :dateCreated,
    :note,
    :contactStatusId,
    :contactStatus,
    :isActive,
    :branchId,
    :branchName,
    :address,
    :worksiteId,
    :worksiteName,
    :worksiteAddress,
    :howHeardOfId,
    :howHeardOf,
    :howHeardOfDetail,
    :companyId,
    :companyName,
    :companyTypeId,
    :companyType,
    :serviceRepId,
    :serviceRep,
    :employeeId,
    :employeeLastName,
    :employeeFirstName
  ]

  @type t :: %__MODULE__{
          contactId: integer(),
          firstName: String.t(),
          lastName: String.t(),
          title: String.t(),
          nickname: String.t(),
          honorific: String.t(),
          birthday: String.t(),
          customerId: integer(),
          customerName: String.t(),
          departmentName: String.t() | nil,
          dateCreated: NaiveDateTime.t() | nil,
          note: String.t() | nil,
          contactStatusId: String.t() | nil,
          contactStatus: String.t() | nil,
          isActive: boolean(),
          branchId: integer() | nil,
          branchName: String.t() | nil,
          address: Address.t(),
          worksiteId: integer(),
          worksiteName: String.t() | nil,
          worksiteAddress: Address.t(),
          howHeardOfId: integer(),
          howHeardOf: String.t() | nil,
          howHeardOfDetail: String.t() | nil,
          companyId: integer(),
          companyName: String.t() | nil,
          companyTypeId: String.t(),
          companyType: String.t() | nil,
          serviceRepId: integer(),
          serviceRep: String.t() | nil,
          employeeId: integer(),
          employeeLastName: String.t() | nil,
          employeeFirstName: String.t() | nil
        }

  def to_list_of_custom_properties do
    [
      %{
        key: "contact_id",
        label: "Contact ID",
        type: "number",
        references: [
          %{
            external_entity_type: "tempwork_contact_custom_data",
            external_entity_property_key: "contact_id",
            type: "one_to_one"
          },
          %{external_entity_type: "assignment", external_entity_property_key: "contact_id", type: "many_to_one"}
        ],
        whippy_associations: [
          %{
            source_property_key: "contact_id",
            target_property_key: "external_id",
            target_whippy_resource: "contact",
            target_property_key_prefix: "contact-",
            type: "one_to_one"
          }
        ]
      },
      %{key: "first_name", label: "First Name", type: "text"},
      %{key: "last_name", label: "Last Name", type: "text"},
      %{key: "title", label: "Title", type: "text"},
      %{key: "nickname", label: "Nickname", type: "text"},
      %{key: "honorific", label: "Honorific", type: "text"},
      %{key: "birthday", label: "Birthday", type: "text"},
      %{key: "customer_id", label: "Customer Id", type: "number"},
      %{key: "customer_name", label: "Customer Name", type: "text"},
      %{key: "department_name", label: "Department Name", type: "text"},
      %{key: "date_created", label: "Date Created", type: "date"},
      %{key: "note", label: "Note", type: "text"},
      %{key: "contact_status_id", label: "Contact Status Id", type: "text"},
      %{key: "contact_status", label: "Contact Status", type: "text"},
      %{key: "is_active", label: "Is Active", type: "boolean"},
      %{key: "branch_id", label: "Branch Id", type: "number"},
      %{key: "branch_name", label: "Branch Name", type: "text"},
      %{key: "address", label: "Address", type: "map"},
      %{key: "worksite_id", label: "Worksite ID", type: "number"},
      %{key: "worksite_name", label: "Worksite Name", type: "text"},
      %{key: "worksite_address", label: "Worksite Address", type: "map"},
      %{key: "how_heard_of_id", label: "How Heard Of ID", type: "number"},
      %{key: "how_heard_of", label: "How Heard Of", type: "text"},
      %{key: "how_heard_of_detail", label: "How Heard Of Detail", type: "text"},
      %{key: "company_id", label: "Company ID", type: "number"},
      %{key: "company_name", label: "Company Name", type: "text"},
      %{key: "company_type_id", label: "Company Type Id", type: "text"},
      %{key: "company_type", label: "Company Type", type: "text"},
      %{key: "service_rep_id", label: "Service Rep ID", type: "number"},
      %{key: "service_rep", label: "Service Rep", type: "text"},
      %{key: "employer_id", label: "Employer ID", type: "number"},
      %{key: "employee_last_name", label: "Employee Last Name", type: "text"},
      %{key: "employee_first_name", label: "Employee First Name", type: "text"}
    ]
  end
end

defmodule Sync.Clients.Tempworks.Model.Address do
  @moduledoc false

  @derive Jason.Encoder

  defstruct [
    :street1,
    :street2,
    :municipality,
    :region,
    :postalCode,
    :countryCode,
    :country,
    :attentionTo,
    :location,
    :dateAddressStandardized
  ]

  @type t :: %__MODULE__{
          street1: String.t(),
          street2: String.t() | nil,
          municipality: String.t(),
          region: String.t(),
          postalCode: String.t(),
          countryCode: integer(),
          country: String.t(),
          attentionTo: String.t() | nil,
          location: any() | nil,
          dateAddressStandardized: NaiveDateTime.t() | nil
        }
end

defmodule Sync.Clients.Tempworks.Model.Branch do
  @moduledoc false
  alias Sync.Clients.Tempworks.Model.Address

  @derive Jason.Encoder

  defstruct [
    :branchId,
    :branchName,
    :branchFullName,
    :isActive,
    :emailAddress,
    :phoneNumber,
    :address,
    :region,
    :employerId,
    :employer,
    :hierId,
    :distanceUnit,
    :distanceToLocation
  ]

  @type t :: %__MODULE__{
          branchId: integer(),
          branchName: String.t(),
          branchFullName: String.t(),
          isActive: boolean(),
          emailAddress: String.t() | nil,
          phoneNumber: String.t(),
          address: Address.t(),
          region: String.t() | nil,
          employerId: integer(),
          employer: String.t(),
          hierId: integer(),
          distanceUnit: String.t(),
          distanceToLocation: integer()
        }
end

defmodule Sync.Clients.Tempworks.Model.EmployeeDetail do
  @moduledoc """
    The EmployeeDetail that is returned when we request information about a specific employee without
    their custom data.

    ## Note
    There are three different forms of Employee that Tempworks returns depending on the request.
    1. Employee - Returned when we list employees
    2. EmployeeDetail - Returned when we get a specific employee by id
    3. CustomData - Returned when we get a specific employee by id AND request for that user's
    custom data
  """

  alias Sync.Clients.Tempworks.Model.Address

  @derive Jason.Encoder

  defstruct [
    :employeeId,
    :employeeGuid,
    :branchId,
    :branch,
    :hierTypeId,
    :hierType,
    :firstName,
    :middleName,
    :lastName,
    :alias,
    :namePrefix,
    :nameSuffix,
    :governmentPersonalId,
    :isActive,
    :activationDate,
    :deactivationDate,
    :resumeDocumentId,
    :resumeFileName,
    :isAssigned,
    :isI9OnFile,
    :i9ExpirationDate,
    :jobTitle,
    :note,
    :numericRating,
    :serviceRepId,
    :serviceRep,
    :serviceRepChatName,
    :serviceRepEmail,
    :createdByServiceRepId,
    :createdByServiceRep,
    :companyId,
    :company,
    :companyIsVendor,
    :alternateEmployeeId,
    :employerId,
    :employer,
    :driverLicenseNumber,
    :driverLicenseState,
    :driverLicenseClass,
    :driverLicenseExpire,
    :primaryPhoneNumberContactMethodId,
    :primaryPhoneNumber,
    :primaryPhoneNumberContactMethodTypeId,
    :primaryPhoneNumberContactMethodType,
    :primaryPhoneNumberCountryCallingCode,
    :primaryEmailAddressContactMethodId,
    :primaryEmailAddress,
    :primaryEmailAddressContactMethodTypeId,
    :primaryEmailAddressContactMethodType,
    :employeeStatusId,
    :employeeStatus,
    :governmentPersonalIdIsScrubbed,
    :address,
    :birthday
  ]

  @type t :: %__MODULE__{
          employeeId: integer(),
          employeeGuid: String.t(),
          branchId: integer(),
          branch: String.t(),
          hierTypeId: integer(),
          hierType: String.t(),
          firstName: String.t(),
          middleName: String.t() | nil,
          lastName: String.t(),
          alias: String.t() | nil,
          namePrefix: String.t() | nil,
          nameSuffix: String.t() | nil,
          governmentPersonalId: String.t() | nil,
          isActive: boolean(),
          activationDate: NaiveDateTime.t(),
          deactivationDate: NaiveDateTime.t() | nil,
          resumeDocumentId: integer() | nil,
          resumeFileName: String.t() | nil,
          isAssigned: boolean(),
          isI9OnFile: boolean(),
          i9ExpirationDate: NaiveDateTime.t() | nil,
          jobTitle: String.t() | nil,
          note: String.t() | nil,
          numericRating: integer(),
          serviceRepId: integer(),
          serviceRep: String.t(),
          serviceRepChatName: String.t() | nil,
          serviceRepEmail: String.t() | nil,
          createdByServiceRepId: integer(),
          createdByServiceRep: String.t(),
          companyId: integer() | nil,
          company: String.t() | nil,
          companyIsVendor: boolean() | nil,
          alternateEmployeeId: integer() | nil,
          employerId: integer(),
          employer: String.t(),
          driverLicenseNumber: String.t() | nil,
          driverLicenseState: String.t() | nil,
          driverLicenseClass: String.t() | nil,
          driverLicenseExpire: NaiveDateTime.t(),
          primaryPhoneNumberContactMethodId: integer(),
          primaryPhoneNumber: String.t(),
          primaryPhoneNumberContactMethodTypeId: integer(),
          primaryPhoneNumberContactMethodType: String.t(),
          primaryPhoneNumberCountryCallingCode: integer(),
          primaryEmailAddressContactMethodId: integer(),
          primaryEmailAddress: String.t(),
          primaryEmailAddressContactMethodTypeId: integer(),
          primaryEmailAddressContactMethodType: String.t(),
          employeeStatusId: String.t(),
          employeeStatus: String.t(),
          governmentPersonalIdIsScrubbed: boolean(),
          address: Address.t(),
          birthday: String.t()
        }

  def to_list_of_custom_properties do
    [
      %{
        key: "employee_id",
        label: "Employee ID",
        type: "number",
        references: [
          %{
            external_entity_type: "employee_custom_data",
            external_entity_property_key: "employee_id",
            type: "one_to_one"
          },
          %{external_entity_type: "assignment", external_entity_property_key: "employee_id", type: "many_to_one"}
        ],
        whippy_associations: [
          %{
            source_property_key: "employee_id",
            target_property_key: "external_id",
            target_whippy_resource: "contact",
            target_property_key_prefix: nil,
            type: "one_to_one"
          }
        ]
      },
      %{key: "employee_guid", label: "Employee GUID", type: "text"},
      %{key: "branch_id", label: "Branch ID", type: "number"},
      %{key: "branch", label: "Branch", type: "text"},
      %{key: "hier_type_id", label: "Hier Type ID", type: "number"},
      %{key: "hier_type", label: "Hier Type", type: "text"},
      %{key: "first_name", label: "First Name", type: "text"},
      %{key: "middle_name", label: "Middle Name", type: "text"},
      %{key: "last_name", label: "Last Name", type: "text"},
      %{key: "alias", label: "Alias", type: "text"},
      %{key: "name_prefix", label: "Name Prefix", type: "text"},
      %{key: "name_suffix", label: "Name Suffix", type: "text"},
      %{key: "government_personal_id", label: "Government Personal ID", type: "text"},
      %{key: "is_active", label: "Is Active", type: "boolean"},
      %{key: "activation_date", label: "Activation Date", type: "date"},
      %{key: "deactivation_date", label: "Deactivation Date", type: "date"},
      %{key: "resume_document_id", label: "Resume Document ID", type: "number"},
      %{key: "resume_file_name", label: "Resume File Name", type: "text"},
      %{key: "is_assigned", label: "Is Assigned", type: "boolean"},
      %{key: "is_i9_on_file", label: "Is I9 On File", type: "boolean"},
      %{key: "i9_expiration_date", label: "I9 Expiration Date", type: "date"},
      %{key: "job_title", label: "Job Title", type: "text"},
      %{key: "note", label: "Note", type: "text"},
      %{key: "numeric_rating", label: "Numeric Rating", type: "number"},
      %{key: "service_rep_id", label: "Service Rep ID", type: "number"},
      %{key: "service_rep", label: "Service Rep", type: "text"},
      %{key: "service_rep_chat_name", label: "Service Rep Chat Name", type: "text"},
      %{key: "service_rep_email", label: "Service Rep Email", type: "text"},
      %{key: "created_by_service_rep_id", label: "Created By Service Rep ID", type: "number"},
      %{key: "created_by_service_rep", label: "Created By Service Rep", type: "text"},
      %{key: "company_id", label: "Company ID", type: "number"},
      %{key: "company", label: "Company", type: "text"},
      %{key: "company_is_vendor", label: "Company Is Vendor", type: "boolean"},
      %{key: "alternate_employee_id", label: "Alternate Employee ID", type: "number"},
      %{key: "employer_id", label: "Employer ID", type: "number"},
      %{key: "employer", label: "Employer", type: "text"},
      %{key: "driver_license_number", label: "Driver License Number", type: "text"},
      %{key: "driver_license_state", label: "Driver License State", type: "text"},
      %{key: "driver_license_class", label: "Driver License Class", type: "text"},
      %{key: "driver_license_expire", label: "Driver License Expire", type: "date"},
      %{
        key: "primary_phone_number_contact_method_id",
        label: "Primary Phone Number Contact Method ID",
        type: "number"
      },
      %{key: "primary_phone_number", label: "Primary Phone Number", type: "text"},
      %{
        key: "primary_phone_number_contact_method_type_id",
        label: "Primary Phone Number Contact Method Type ID",
        type: "number"
      },
      %{
        key: "primary_phone_number_contact_method_type",
        label: "Primary Phone Number Contact Method Type",
        type: "text"
      },
      %{
        key: "primary_phone_number_country_calling_code",
        label: "Primary Phone Number Country Calling Code",
        type: "number"
      },
      %{
        key: "primary_email_address_contact_method_id",
        label: "Primary Email Address Contact Method ID",
        type: "number"
      },
      %{key: "primary_email_address", label: "Primary Email Address", type: "text"},
      %{
        key: "primary_email_address_contact_method_type_id",
        label: "Primary Email Address Contact Method Type ID",
        type: "number"
      },
      %{
        key: "primary_email_address_contact_method_type",
        label: "Primary Email Address Contact Method Type",
        type: "text"
      },
      %{key: "employee_status_id", label: "Employee Status ID", type: "text"},
      %{key: "employee_status", label: "Employee Status", type: "text"},
      %{
        key: "government_personal_id_is_scrubbed",
        label: "Government Personal ID Is Scrubbed",
        type: "boolean"
      },
      %{key: "address", label: "Address", type: "map"},
      %{key: "birthday", label: "Birthday", type: "text"}
    ]
  end
end

defmodule Sync.Clients.Tempworks.Model.EmployeeEeoDetail do
  @moduledoc false

  @derive Jason.Encoder

  defstruct [
    :employeeId,
    :birthPlace,
    :dateEntered,
    :dateOfBirth,
    :gender,
    :genderId,
    :i9DateVerified,
    :isCitizen,
    :isDisabled,
    :isEVerified,
    :nationality,
    :nationalityId,
    :veteranStatus,
    :veteranStatusId
  ]

  @type t :: %__MODULE__{
          employeeId: integer(),
          birthPlace: String.t(),
          dateEntered: NaiveDateTime | nil,
          dateOfBirth: NaiveDateTime | nil,
          gender: String.t() | nil,
          genderId: integer(),
          i9DateVerified: NaiveDateTime | nil,
          isCitizen: boolean(),
          isDisabled: boolean(),
          isEVerified: boolean(),
          nationality: String.t(),
          nationalityId: integer(),
          veteranStatus: String.t(),
          veteranStatusId: integer()
        }
end

defmodule Sync.Clients.Tempworks.Model.CustomData do
  @moduledoc """
    The CustomData that is returned when we request it for a specific employee or assignment

   Assignment Custom Data Doc: https://api.ontempworks.com/swagger/index.html#/Assignment/AssignmentsByIdCustomDataGet
  """

  @derive Jason.Encoder

  defstruct [
    :propertyDefinitionId,
    :propertyName,
    :propertyValue,
    :propertyValueId,
    :propertyType,
    :categoryId,
    :categoryName,
    :isActive,
    :isRequired,
    :isReadOnly,
    :allowMultipleValues,
    :hasDatalist
  ]

  @type t :: %__MODULE__{
          propertyDefinitionId: String.t(),
          propertyName: String.t(),
          # 'any()' because 'propertyValue' can be of any type or nil
          propertyValue: any() | nil,
          propertyValueId: String.t() | nil,
          propertyType: String.t(),
          categoryId: String.t() | nil,
          categoryName: String.t() | nil,
          isActive: boolean(),
          isRequired: boolean(),
          isReadOnly: boolean(),
          allowMultipleValues: boolean(),
          hasDatalist: boolean()
        }
end

defmodule Sync.Clients.Tempworks.Model.WebhookCustomData do
  @moduledoc false
  @derive Jason.Encoder

  defstruct [
    :propertyDefinitionId,
    :propertyName,
    :propertyValue
  ]

  @type t :: %__MODULE__{
          propertyDefinitionId: String.t(),
          propertyName: String.t(),
          # 'any()' because 'propertyValue' can be of any type or nil
          propertyValue: any() | nil
        }
end

defmodule Sync.Clients.Tempworks.Model.EmployeeAssignment do
  @moduledoc """
  This represents an Assignment that belongs to an Employee, that is returned from Tempworks when listing assignments.

  Link to Swagger Doc: https://api.ontempworks.com/swagger/index.html#/Employees/EmployeesByIdAssignmentsGet
  """

  @derive Jason.Encoder

  defstruct [
    :assignmentId,
    :lastName,
    :firstName,
    :middleName,
    :employeePrimaryEmailAddress,
    :employeePrimaryPhoneNumber,
    :employeeId,
    :customerId,
    :customerName,
    :departmentName,
    :jobTitle,
    :payRate,
    :billRate,
    :startDate,
    :endDate,
    :branchId,
    :branchName,
    :isActive,
    :isDeleted,
    :jobOrderId,
    :supervisorId,
    :supervisor,
    :supervisorContactInfo,
    :originalStartDate,
    :expectedEndDate,
    :activeStatus,
    :assignmentStatusId,
    :assignmentStatus,
    :performanceNote,
    :isTimeclockOrder,
    :serviceRep,
    :alternateAssignmentId,
    :temporaryPhoneNumber,
    :replacesAssignmentId,
    :customerHasBlacklistedEmployee,
    :employeeHasBlacklistedCustomer,
    :jobTitleId,
    :employerId,
    :companyId,
    :doNotAutoClose,
    :serviceRepId,
    :accountManagerServiceRepId,
    :createdByServiceRepId,
    :dateCreated,
    :salesTeamId,
    :assignmentRootGuid,
    :employeeRootGuid,
    :identifier
  ]

  @type t :: %__MODULE__{
          assignmentId: integer(),
          lastName: String.t(),
          firstName: String.t(),
          middleName: String.t() | nil,
          employeePrimaryEmailAddress: String.t(),
          employeePrimaryPhoneNumber: String.t(),
          employeeId: integer(),
          customerId: integer(),
          customerName: String.t(),
          departmentName: String.t(),
          jobTitle: String.t(),
          payRate: float(),
          billRate: float(),
          startDate: NaiveDateTime.t(),
          endDate: NaiveDateTime.t() | nil,
          branchId: integer(),
          branchName: String.t(),
          isActive: boolean(),
          isDeleted: boolean(),
          jobOrderId: integer(),
          supervisorId: integer(),
          supervisor: String.t(),
          supervisorContactInfo: String.t(),
          originalStartDate: String.t(),
          expectedEndDate: String.t(),
          activeStatus: integer(),
          assignmentStatusId: integer(),
          assignmentStatus: String.t(),
          performanceNote: String.t(),
          isTimeclockOrder: boolean(),
          serviceRep: String.t(),
          alternateAssignmentId: String.t(),
          temporaryPhoneNumber: String.t(),
          replacesAssignmentId: String.t(),
          customerHasBlacklistedEmployee: boolean(),
          employeeHasBlacklistedCustomer: boolean(),
          jobTitleId: integer(),
          employerId: integer(),
          companyId: integer(),
          doNotAutoClose: boolean(),
          serviceRepId: integer(),
          accountManagerServiceRepId: integer(),
          createdByServiceRepId: integer(),
          dateCreated: NaiveDateTime.t(),
          salesTeamId: integer(),
          assignmentRootGuid: String.t(),
          employeeRootGuid: String.t(),
          identifier: String.t()
        }

  def to_list_of_custom_properties do
    [
      %{
        key: "assignment_id",
        label: "Assignment ID",
        type: "number",
        references: [
          %{
            external_entity_type: "assignment_custom_data",
            external_entity_property_key: "assignment_id",
            type: "one_to_one"
          }
        ]
      },
      %{key: "last_name", label: "Last Name", type: "text"},
      %{key: "first_name", label: "First Name", type: "text"},
      %{key: "middle_name", label: "Middle Name", type: "text"},
      %{
        key: "employee_primary_email_address",
        label: "Employee Primary Email Address",
        type: "text"
      },
      %{
        key: "employee_primary_phone_number",
        label: "Employee Primary Phone Number",
        type: "text"
      },
      %{
        key: "employee_id",
        label: "Employee ID",
        type: "number",
        whippy_associations: [
          %{
            source_property_key: "employee_id",
            target_property_key: "external_id",
            target_whippy_resource: "contact",
            target_property_key_prefix: nil,
            type: "one_to_one"
          }
        ]
      },
      %{key: "customer_id", label: "Customer ID", type: "number"},
      %{key: "customer_name", label: "Customer Name", type: "text"},
      %{key: "department_name", label: "Department Name", type: "text"},
      %{key: "job_title", label: "Job Title", type: "text"},
      %{key: "pay_rate", label: "Pay Rate", type: "float"},
      %{key: "bill_rate", label: "Bill Rate", type: "float"},
      %{key: "start_date", label: "Start Date", type: "date"},
      %{key: "end_date", label: "End Date", type: "date"},
      %{key: "branch_id", label: "Branch ID", type: "number"},
      %{key: "branch_name", label: "Branch Name", type: "text"},
      %{key: "is_active", label: "Is Active", type: "boolean"},
      %{key: "is_deleted", label: "Is Deleted", type: "boolean"},
      %{key: "job_order_id", label: "Job Order ID", type: "number"},
      %{key: "supervisor_id", label: "Supervisor ID", type: "number"},
      %{key: "supervisor", label: "Supervisor", type: "text"},
      %{key: "supervisor_contact_info", label: "Supervisor Contact Info", type: "text"},
      %{key: "original_start_date", label: "Original Start Date", type: "date"},
      %{key: "expected_end_date", label: "Expected End Date", type: "date"},
      %{key: "active_status", label: "Active Status", type: "number"},
      %{key: "assignment_status_id", label: "Assignment Status ID", type: "number"},
      %{key: "assignment_status", label: "Assignment Status", type: "text"},
      %{key: "performance_note", label: "Performance Note", type: "text"},
      %{key: "is_timeclock_order", label: "Is Timeclock Order", type: "boolean"},
      %{key: "service_rep", label: "Service Rep", type: "text"},
      %{key: "alternate_assignment_id", label: "Alternate Assignment Id", type: "text"},
      %{key: "temporary_phone_number", label: "Temporary Phone Number", type: "text"},
      %{key: "replaces_assignment_id", label: "Replaces Assignment Id", type: "text"},
      %{key: "customer_has_blacklisted_employee", label: "Customer Has Blacklisted Employee", type: "boolean"},
      %{key: "employee_has_blacklisted_customer", label: "Employee Has Blacklisted Customer", type: "boolean"},
      %{key: "job_title_id", label: "Job Title Id", type: "number"},
      %{key: "employer_id", label: "Employer Id", type: "number"},
      %{key: "company_id", label: "Company Id", type: "number"},
      %{key: "do_not_auto_close", label: "Do Not Auto Close", type: "boolean"},
      %{key: "service_rep_id", label: "Service Rep Id", type: "number"},
      %{key: "account_manager_service_rep_id", label: "Account Manager Service Rep Id", type: "number"},
      %{key: "created_by_service_rep_id", label: "Created By Service Rep Id", type: "number"},
      %{key: "date_created", label: "Date Created", type: "date"},
      %{key: "sales_team_id", label: "Sales Team Id", type: "number"},
      %{key: "assignment_root_guid", label: "Assignment Root Guid", type: "text"},
      %{key: "employee_root_guid", label: "Employee Root Guid", type: "text"},
      %{key: "identifier", label: "Identifier", type: "text"}
    ]
  end
end

defmodule Sync.Clients.Tempworks.Model.Customers do
  @moduledoc """
  Link to Swagger Doc: https://api.ontempworks.com/swagger/index.html#/Customer
  """
  @derive Jason.Encoder

  defstruct [
    :customerId,
    :customerName,
    :departmentName,
    :branchName,
    :isActive,
    :status,
    :officePhone,
    :municipality,
    :region,
    :serviceRep,
    :salesContact,
    :salesContactId,
    :accountManagerServiceRepId,
    :accountManagerServiceRep,
    :accountManagerServiceRepFullName
  ]

  @type t :: %__MODULE__{
          customerId: integer(),
          customerName: String.t(),
          departmentName: String.t(),
          branchName: String.t(),
          isActive: boolean(),
          status: String.t(),
          officePhone: String.t(),
          municipality: String.t(),
          region: String.t(),
          serviceRep: String.t(),
          salesContact: String.t(),
          salesContactId: integer(),
          accountManagerServiceRepId: integer(),
          accountManagerServiceRep: String.t(),
          accountManagerServiceRepFullName: String.t()
        }

  def to_list_of_custom_properties do
    [
      %{
        key: "customer_id",
        label: "Customer Id",
        type: "number",
        references: [
          %{
            external_entity_type: "customer_custom_data",
            external_entity_property_key: "customer_id",
            type: "one_to_one"
          }
        ]
      },
      %{key: "customer_name", label: "Customer Name", type: "text"},
      %{key: "department_name", label: "Department Name", type: "text"},
      %{key: "branch_name", label: "Branch Name", type: "text"},
      %{key: "is_active", label: "Is Active", type: "boolean"},
      %{key: "status", label: "Status", type: "text"},
      %{key: "office_phone", label: "Office Phone", type: "text"},
      %{key: "municipality", label: "Municipality", type: "text"},
      %{key: "region", label: "Region", type: "text"},
      %{key: "service_rep", label: "Service Rep", type: "text"},
      %{key: "sales_contact", label: "Sales Contact", type: "text"},
      %{key: "sales_contact_id", label: "Sales Contact Id", type: "number"},
      %{key: "account_manager_service_rep_id", label: "Account Manager Service Rep Id", type: "number"},
      %{key: "account_manager_service_rep", label: "Account Manager Service Rep", type: "text"},
      %{key: "account_manager_service_rep_full_name", label: "Account Manager Service Rep Full Name", type: "text"}
    ]
  end
end

defmodule Sync.Clients.Tempworks.Model.WebhookCustomers do
  @moduledoc """
  Link to Swagger Doc: https://api.ontempworks.com/swagger/index.html#/Customer
  """
  @derive Jason.Encoder

  defstruct [
    :customerId,
    :customerName,
    :departmentName,
    :parentCustomerId,
    :rootCustomerId,
    :branchId,
    :customerStatusId,
    :website,
    :isActive,
    :dateActivated,
    :address,
    :billingAddress,
    :worksiteId,
    :note,
    :nationalIndustryClassificationSystemCode
  ]

  @type t :: %__MODULE__{
          customerId: integer(),
          customerName: String.t(),
          departmentName: String.t(),
          parentCustomerId: String.t(),
          rootCustomerId: integer(),
          branchId: integer(),
          customerStatusId: String.t(),
          website: String.t(),
          isActive: boolean(),
          dateActivated: NaiveDateTime.t(),
          address: Address.t(),
          billingAddress: Address.t(),
          worksiteId: String.t(),
          note: String.t(),
          nationalIndustryClassificationSystemCode: String.t()
        }

  def to_list_of_custom_properties do
    [
      %{
        key: "customer_id",
        label: "Customer Id",
        type: "number",
        references: [
          %{
            external_entity_type: "customer_custom_data",
            external_entity_property_key: "customer_id",
            type: "one_to_one"
          }
        ]
      },
      %{key: "customer_name", label: "Customer Name", type: "text"},
      %{key: "department_name", label: "Department Name", type: "text"},
      %{key: "parent_customer_id", label: "Parent Customer Id", type: "text"},
      %{key: "root_customer_id", label: "Root Customer Id", type: "number"},
      %{key: "branch_id", label: "Branch Id", type: "number"},
      %{key: "customer_status_id", label: "Customer Status Id", type: "text"},
      %{key: "website", label: "Website", type: "text"},
      %{key: "is_active", label: "Is Active", type: "boolean"},
      %{key: "date_activated", label: "Date Activated", type: "text"},
      %{key: "address", label: "Address", type: "map"},
      %{key: "billing_address", label: "Billing Address", type: "map"},
      %{key: "worksite_id", label: "Worksite Id", type: "text"},
      %{key: "note", label: "Note", type: "text"},
      %{
        key: "national_industry_classification_system_code",
        label: "National Industry Classification System Code",
        type: "text"
      }
    ]
  end
end

defmodule Sync.Clients.Tempworks.Model.TempworksJobOrders do
  @moduledoc """
  Link to Swagger Doc: https://api.ontempworks.com/swagger/index.html#/Searches/SearchJobOrdersGet
  """
  @derive Jason.Encoder

  defstruct [
    :orderId,
    :customerId,
    :customerName,
    :departmentName,
    :jobTitle,
    :orderType,
    :payRate,
    :billRate,
    :startDate,
    :orderStatus,
    :positionsRequired,
    :positionsFilled,
    :workSiteId,
    :worksite,
    :isActive,
    :branchId,
    :branchName,
    :serviceRepId,
    :serviceRep
  ]

  @type t :: %__MODULE__{
          orderId: integer(),
          customerId: integer(),
          customerName: String.t(),
          departmentName: String.t() | nil,
          jobTitle: String.t(),
          orderType: String.t(),
          payRate: integer(),
          billRate: integer(),
          startDate: NaiveDateTime | nil,
          orderStatus: String.t(),
          positionsRequired: integer(),
          positionsFilled: integer(),
          workSiteId: integer(),
          worksite: String.t(),
          isActive: boolean(),
          branchId: integer(),
          branchName: String.t(),
          serviceRepId: integer(),
          serviceRep: String.t()
        }

  def to_list_of_custom_properties do
    [
      %{
        key: "order_id",
        label: "Order ID",
        type: "number",
        references: [
          %{
            external_entity_type: "job_order_custom_data",
            external_entity_property_key: "job_order_id",
            type: "one_to_one"
          }
        ]
      },
      %{key: "customer_id", label: "Customer Id", type: "number"},
      %{key: "customer_name", label: "Customer Name", type: "text"},
      %{key: "department_name", label: "Department Name", type: "text"},
      %{key: "job_title", label: "Job Title", type: "text"},
      %{key: "order_type", label: "Order Type", type: "text"},
      %{key: "pay_rate", label: "Pay Rate", type: "number"},
      %{key: "bill_rate", label: "Bill Rate", type: "number"},
      %{key: "start_date", label: "Start Date", type: "date"},
      %{key: "order_status", label: "Order Status", type: "text"},
      %{key: "positions_required", label: "Positions Required", type: "number"},
      %{key: "positions_filled", label: "Positions Filled", type: "number"},
      %{key: "work_site_id", label: "Work Site Id", type: "number"},
      %{key: "worksite", label: "Worksite", type: "text"},
      %{key: "is_active", label: "Is Active", type: "boolean"},
      %{key: "branch_id", label: "Branch ID", type: "number"},
      %{key: "branch_name", label: "Branch Name", type: "text"},
      %{key: "service_rep_id", label: "Service Rep Id", type: "number"},
      %{key: "service_rep", label: "Service Rep", type: "text"}
    ]
  end
end

defmodule Sync.Clients.Tempworks.Model.JobOrdersWebhook do
  @moduledoc false
  @derive Jason.Encoder

  defstruct [
    :worksiteId,
    :jobOrderId,
    :branchId,
    :jobOrderTypeId,
    :jobTitleId,
    :jobTitle,
    :jobDescription,
    :payRate,
    :billRate,
    :jobOrderStatusId,
    :isActive,
    :positionsRequired,
    :positionsFilled,
    :customerId,
    :jobOrderDurationId,
    :dateOrderTaken,
    :startDate,
    :supervisorContactId,
    :doNotAutoClose,
    :usesTimeClock,
    :usesPeopleNet,
    :notes,
    :alternateJobOrderId,
    :dressCode,
    :safetyNotes,
    :directions,
    :serviceRepId,
    :salesTeamId,
    :publicJobTitle,
    :publicPostingDate,
    :doNotPostPublicly,
    :publicJobDescriptionContentType,
    :publicEducationSummary,
    :publicExperienceSummary,
    :showPayRate,
    :showWorksiteAddress,
    :isDirectHireJobOrder,
    :localizedJobOrderDetails,
    :remoteWorkStatusId,
    :remoteWorkStatus
  ]

  @type t :: %__MODULE__{
          worksiteId: integer(),
          jobOrderId: integer(),
          branchId: integer(),
          jobOrderTypeId: integer(),
          jobTitleId: integer(),
          jobTitle: String.t(),
          jobDescription: String.t(),
          payRate: String.t(),
          billRate: String.t(),
          jobOrderStatusId: integer(),
          isActive: boolean(),
          positionsRequired: integer(),
          positionsFilled: integer(),
          customerId: integer(),
          jobOrderDurationId: integer(),
          dateOrderTaken: NaiveDateTime | nil,
          startDate: String.t(),
          supervisorContactId: integer(),
          doNotAutoClose: boolean(),
          usesTimeClock: boolean(),
          usesPeopleNet: boolean(),
          notes: String.t(),
          alternateJobOrderId: String.t(),
          dressCode: String.t(),
          safetyNotes: String.t(),
          directions: String.t(),
          serviceRepId: integer(),
          salesTeamId: integer(),
          publicJobTitle: String.t(),
          publicPostingDate: NaiveDateTime.t() | nil,
          doNotPostPublicly: boolean(),
          publicJobDescriptionContentType: String.t(),
          publicEducationSummary: String.t(),
          publicExperienceSummary: String.t(),
          showPayRate: boolean(),
          showWorksiteAddress: boolean(),
          isDirectHireJobOrder: boolean(),
          localizedJobOrderDetails: String.t(),
          remoteWorkStatusId: String.t(),
          remoteWorkStatus: String.t()
        }

  def to_list_of_custom_properties do
    [
      %{key: "worksite_id", label: "Worksite Id", type: "number"},
      %{
        key: "job_order_id",
        label: "Job Order ID",
        type: "number",
        references: [
          %{
            external_entity_type: "job_order_custom_data",
            external_entity_property_key: "job_order_id",
            type: "one_to_one"
          }
        ]
      },
      %{key: "branch_id", label: "Branch ID", type: "number"},
      %{key: "job_order_type_id", label: "Job Order Type Id", type: "number"},
      %{key: "job_title_id", label: "Job Title Id", type: "number"},
      %{key: "job_title", label: "Job Title", type: "text"},
      %{key: "job_description", label: "Job Description", type: "text"},
      %{key: "pay_rate", label: "Pay Rate", type: "text"},
      %{key: "bill_rate", label: "Bill Rate", type: "text"},
      %{key: "job_order_status_id", label: "Job Order Status Id", type: "number"},
      %{key: "is_active", label: "Is Active", type: "boolean"},
      %{key: "positions_required", label: "Positions Required", type: "number"},
      %{key: "positions_filled", label: "Positions Filled", type: "number"},
      %{key: "customer_id", label: "Customer Id", type: "number"},
      %{key: "job_order_duration_id", label: "Job Order Duration Id", type: "number"},
      %{key: "date_order_taken", label: "Date Order Taken", type: "date"},
      %{key: "start_date", label: "Start Date", type: "date"},
      %{key: "supervisor_contact_id", label: "supervisor Contact Id", type: "text"},
      %{key: "do_not_auto_close", label: "Do Not Auto Close", type: "boolean"},
      %{key: "uses_time_clock", label: "Uses Time Clock", type: "boolean"},
      %{key: "uses_people_net", label: "Uses People Net", type: "boolean"},
      %{key: "notes", label: "Notes", type: "text"},
      %{key: "alternate_job_order_id", label: "Alternate Job Order Id", type: "text"},
      %{key: "dress_code", label: "Dress Code", type: "text"},
      %{key: "safety_notes", label: "Safety Notes", type: "text"},
      %{key: "directions", label: "Directions", type: "text"},
      %{key: "service_rep_id", label: "Service Rep Id", type: "number"},
      %{key: "sales_team_id", label: "Sales Team Id", type: "number"},
      %{key: "public_job_title", label: "Public Job Title", type: "text"},
      %{key: "public_posting_date", label: "Public Posting Date", type: "date"},
      %{key: "do_not_post_publicly", label: "Do Not Post Publicly", type: "boolean"},
      %{key: "public_job_description_content_type", label: "Public Job Description Content Type", type: "text"},
      %{key: "public_education_summary", label: "Public Education Summary", type: "text"},
      %{key: "public_experience_summary", label: "Public Experience Summary", type: "text"},
      %{key: "show_pay_rate", label: "Show Pay Rate", type: "boolean"},
      %{key: "show_worksite_address", label: "Show Worksite Address", type: "boolean"},
      %{key: "is_direct_hire_job_order", label: "Is Direct Hire Job Order", type: "boolean"},
      %{key: "localized_job_order_details", label: "Localized Job Order Details", type: "text"},
      %{key: "remote_work_status_id", label: "Remote Work Status Id", type: "text"},
      %{key: "remote_work_status", label: "Remote Work Status", type: "text"}
    ]
  end
end

defmodule Sync.Clients.Tempworks.Model.MessageAction do
  @moduledoc false

  @derive Jason.Encoder

  defstruct [
    :actionId,
    :action,
    :actionDescription,
    :isDefault,
    :isEmployeeRelevant,
    :isCustomerRelevant,
    :isContactRelevant,
    :isDeact,
    :isReact,
    :isAvailability,
    :isDefaultDeactCode,
    :isDefaultReactCode,
    :isDefaultEmailCode,
    :isDefaultLMTC,
    :isActive,
    :isDoNotAssign,
    :messageActionTypeId,
    :messageActionType,
    :displayColor,
    :canRead,
    :canWrite
  ]

  @type t :: %__MODULE__{
          actionId: integer(),
          action: String.t(),
          actionDescription: String.t(),
          isDefault: boolean(),
          isEmployeeRelevant: boolean(),
          isCustomerRelevant: boolean(),
          isContactRelevant: boolean(),
          isDeact: boolean(),
          isReact: boolean(),
          isAvailability: boolean(),
          isDefaultDeactCode: boolean(),
          isDefaultReactCode: boolean(),
          isDefaultEmailCode: boolean(),
          isDefaultLMTC: boolean(),
          isActive: boolean(),
          isDoNotAssign: boolean(),
          messageActionTypeId: String.t(),
          messageActionType: String.t(),
          displayColor: String.t(),
          canRead: boolean(),
          canWrite: boolean()
        }
end

defmodule Sync.Clients.Tempworks.Model.UniversalPhone do
  @moduledoc false

  @derive Jason.Encoder

  defstruct [
    :employeeId,
    :firstName,
    :lastName,
    :branchName,
    :phoneNumber,
    :phoneType,
    :isAssigned,
    :isActive,
    :lastMsg,
    :lastDate,
    :postalCode,
    :eCurrentAssignment
  ]

  @type t :: %__MODULE__{
          employeeId: integer(),
          firstName: String.t(),
          lastName: String.t(),
          branchName: String.t(),
          phoneNumber: String.t(),
          phoneType: String.t(),
          isAssigned: boolean(),
          isActive: boolean(),
          lastMsg: String.t(),
          lastDate: NaiveDateTime.t() | nil,
          postalCode: String.t() | nil,
          eCurrentAssignment: String.t() | nil
        }
end

defmodule Sync.Clients.Tempworks.Model.UniversalEmail do
  @moduledoc false

  @derive Jason.Encoder

  defstruct [
    :employeeId,
    :firstName,
    :lastName,
    :branchName,
    :phoneNumber,
    :isAssigned,
    :isActive,
    :lastMsg,
    :lastDate,
    :postalCode,
    :eCurrentAssignment
  ]

  @type t :: %__MODULE__{
          employeeId: integer(),
          firstName: String.t(),
          lastName: String.t(),
          branchName: String.t(),
          phoneNumber: String.t(),
          isAssigned: boolean(),
          isActive: boolean(),
          lastMsg: String.t(),
          lastDate: NaiveDateTime.t() | nil,
          postalCode: String.t() | nil,
          eCurrentAssignment: String.t() | nil
        }
end
