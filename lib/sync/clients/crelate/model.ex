defmodule Sync.Clients.Crelate.Model.Contact do
  @moduledoc false

  @derive Jason.Encoder
  defstruct [
    :AccountId,
    :Addresses_Business,
    :Addresses_Home,
    :Addresses_Other,
    :ContactNum,
    :ContactNumber,
    :ContactSourceId,
    :CreatedById,
    :CreatedOn,
    :CurrentPosition,
    :Description,
    :DesiredSalaryMax,
    :DesiredSalaryMin,
    :Education,
    :EmailAddresses_Other,
    :EmailAddresses_Other_Alternate,
    :EmailAddresses_Personal,
    :EmailAddresses_Personal_Other,
    :EmailAddresses_Potential,
    :EmailAddresses_Work,
    :EmailAddresses_Work_Other,
    :EntityStatus,
    :EthnicityId,
    :ExternalPrimaryKey,
    :FirstName,
    :GenderId,
    :IconAttachmentId,
    :Id,
    :InstantAddresses_AIM,
    :InstantAddresses_FacebookChat,
    :InstantAddresses_FaceTime,
    :InstantAddresses_GoogleTalk,
    :InstantAddresses_ICQ,
    :InstantAddresses_Other,
    :InstantAddresses_Skype,
    :InstantAddresses_Twitter,
    :InstantAddresses_Yahoo_Msg,
    :JobTypeIds,
    :KeyDates_Anniversary,
    :KeyDates_Birthday,
    :KeyDates_Other,
    :LastActionDate,
    :LastActivityDate,
    :LastActivityOrModifiedOn,
    :LastActivityRegardingId,
    :LastEngagementDate,
    :LastEnrichmentDate,
    :LastName,
    :LastReachOutBy,
    :LastReachOutDate,
    :LatestPinnedNote,
    :MiddleName,
    :ModifiedOn,
    :Name,
    :NickName,
    :Owners,
    :PhoneNumbers_Fax,
    :PhoneNumbers_Home,
    :PhoneNumbers_Mobile,
    :PhoneNumbers_Mobile_Other,
    :PhoneNumbers_Other,
    :PhoneNumbers_Other_Alternate,
    :PhoneNumbers_Potential,
    :PhoneNumbers_Skype,
    :PhoneNumbers_Work_Direct,
    :PhoneNumbers_Work_Main,
    :PhoneNumbers_Work_Other,
    :PreferredContactMethodTypeId,
    :PrimaryDocumentAttachmentId,
    :RecordType,
    :RelatedContacts_Assistant,
    :RelatedContacts_OtherContact,
    :RelatedContacts_ReferredBy,
    :RelatedContacts_Spouse,
    :Salary,
    :SalaryDetails,
    :Salutation,
    :SpokenTo,
    :StatusReason,
    :SuffixId,
    :Tags,
    :TwitterName,
    :UpdatedById,
    :UserId,
    :Websites_Blog,
    :Websites_Business,
    :Websites_Facebook,
    :Websites_GitHub,
    :Websites_LinkedIn,
    :Websites_Other,
    :Websites_Other_Alternate,
    :Websites_Personal,
    :Websites_Portfolio,
    :Websites_Quora,
    :Websites_RSSFeed
  ]

  @type t :: %__MODULE__{
          AccountId: IdTitle.t(),
          Addresses_Business: Address.t(),
          Addresses_Home: Address.t(),
          Addresses_Other: Address.t(),
          ContactNum: integer(),
          ContactNumber: String.t(),
          ContactSourceId: IdTitle.t(),
          CreatedById: IdTitle.t(),
          CreatedOn: String.t(),
          CurrentPosition: CurrentPosition.t(),
          Description: String.t(),
          DesiredSalaryMax: float(),
          DesiredSalaryMin: float(),
          Education: Education.t(),
          EmailAddresses_Other: Email.t(),
          EmailAddresses_Other_Alternate: Email.t(),
          EmailAddresses_Personal: Email.t(),
          EmailAddresses_Personal_Other: Email.t(),
          EmailAddresses_Potential: Email.t(),
          EmailAddresses_Work: Email.t(),
          EmailAddresses_Work_Other: Email.t(),
          EntityStatus: integer(),
          EthnicityId: IdTitle.t(),
          ExternalPrimaryKey: String.t(),
          FirstName: String.t(),
          GenderId: IdTitle.t(),
          IconAttachmentId: IdTitle.t(),
          Id: String.t(),
          InstantAddresses_AIM: InstantAddress.t(),
          InstantAddresses_FacebookChat: InstantAddress.t(),
          InstantAddresses_FaceTime: InstantAddress.t(),
          InstantAddresses_GoogleTalk: InstantAddress.t(),
          InstantAddresses_ICQ: InstantAddress.t(),
          InstantAddresses_Other: InstantAddress.t(),
          InstantAddresses_Skype: InstantAddress.t(),
          InstantAddresses_Twitter: InstantAddress.t(),
          InstantAddresses_Yahoo_Msg: InstantAddress.t(),
          JobTypeIds: [IdTitle.t()],
          KeyDates_Anniversary: KeyDates.t(),
          KeyDates_Birthday: KeyDates.t(),
          KeyDates_Other: KeyDates.t(),
          LastActionDate: NaiveDateTime.t(),
          LastActivityDate: NaiveDateTime.t(),
          LastActivityOrModifiedOn: NaiveDateTime.t(),
          LastActivityRegardingId: NaiveDateTime.t(),
          LastEngagementDate: NaiveDateTime.t(),
          LastEnrichmentDate: NaiveDateTime.t(),
          LastName: String.t(),
          LastReachOutBy: IdTitle.t(),
          LastReachOutDate: NaiveDateTime.t(),
          LatestPinnedNote: String.t(),
          MiddleName: String.t(),
          ModifiedOn: NaiveDateTime.t(),
          Name: String.t(),
          NickName: String.t(),
          Owners: [IdTitle.t()],
          PhoneNumbers_Fax: PhoneNumber.t(),
          PhoneNumbers_Home: PhoneNumber.t(),
          PhoneNumbers_Mobile: PhoneNumber.t(),
          PhoneNumbers_Mobile_Other: PhoneNumber.t(),
          PhoneNumbers_Other: PhoneNumber.t(),
          PhoneNumbers_Other_Alternate: PhoneNumber.t(),
          PhoneNumbers_Potential: PhoneNumber.t(),
          PhoneNumbers_Skype: PhoneNumber.t(),
          PhoneNumbers_Work_Direct: PhoneNumber.t(),
          PhoneNumbers_Work_Main: PhoneNumber.t(),
          PhoneNumbers_Work_Other: PhoneNumber.t(),
          PreferredContactMethodTypeId: IdTitle.t(),
          PrimaryDocumentAttachmentId: IdTitle.t(),
          RecordType: integer(),
          RelatedContacts_Assistant: RelatedContacts.t(),
          RelatedContacts_OtherContact: RelatedContacts.t(),
          RelatedContacts_ReferredBy: RelatedContacts.t(),
          RelatedContacts_Spouse: RelatedContacts.t(),
          Salary: float(),
          SalaryDetails: String.t(),
          Salutation: IdTitle.t(),
          SpokenTo: boolean(),
          StatusReason: String.t(),
          SuffixId: IdTitle.t(),
          Tags: Property.t(),
          TwitterName: String.t(),
          UpdatedById: IdTitle.t(),
          UserId: IdTitle.t(),
          Websites_Blog: KeyDates.t(),
          Websites_Business: KeyDates.t(),
          Websites_Facebook: KeyDates.t(),
          Websites_GitHub: KeyDates.t(),
          Websites_LinkedIn: KeyDates.t(),
          Websites_Other: KeyDates.t(),
          Websites_Other_Alternate: KeyDates.t(),
          Websites_Personal: KeyDates.t(),
          Websites_Portfolio: KeyDates.t(),
          Websites_Quora: KeyDates.t(),
          Websites_RSSFeed: KeyDates.t()
        }
end

# Education struct
defmodule Education do
  @moduledoc "Represents education details."

  defstruct [
    :AcademicHonorIds,
    :AccreditationId,
    :AccreditingInstitutionId,
    :Details,
    :Id,
    :IsPrimary,
    :WhenEnd,
    :WhenStart
  ]

  @type t :: %__MODULE__{
          AcademicHonorIds: [IdTitle.t()],
          AccreditationId: IdTitle.t(),
          AccreditingInstitutionId: IdTitle.t(),
          Details: String.t(),
          Id: String.t(),
          IsPrimary: boolean(),
          WhenEnd: NaiveDateTime.t(),
          WhenStart: NaiveDateTime.t()
        }
end

# Email struct
defmodule Email do
  @moduledoc "Represents an email address with metadata."

  defstruct [
    :CreatedOnSystem,
    :EmailFlagError,
    :EmailFlaggedOn,
    :EmailFlagTypeId,
    :Id,
    :IsPrimary,
    :Value
  ]

  @type t :: %__MODULE__{
          CreatedOnSystem: NaiveDateTime.t(),
          EmailFlagError: String.t(),
          EmailFlaggedOn: NaiveDateTime.t(),
          EmailFlagTypeId: IdTitle.t(),
          Id: String.t(),
          IsPrimary: boolean(),
          Value: String.t()
        }
end

defmodule Address do
  @moduledoc "Struct and type for Business Address details."

  defstruct [
    :City,
    :CountryId,
    :CreatedOnSystem,
    :Id,
    :IsPrimary,
    :Line1,
    :Line2,
    :Location,
    :State,
    :ZipCode
  ]

  @type t :: %__MODULE__{
          City: String.t(),
          CountryId: Account.t(),
          CreatedOnSystem: String.t(),
          Id: String.t(),
          IsPrimary: boolean(),
          Line1: String.t(),
          Line2: String.t(),
          Location: Location.t(),
          State: String.t(),
          ZipCode: String.t()
        }
end

defmodule Location do
  @moduledoc "Struct and type for Location details."

  defstruct [:Lat, :Lon]

  @type t :: %__MODULE__{
          Lat: float(),
          Lon: float()
        }
end

defmodule CurrentPosition do
  @moduledoc false

  defstruct [:CompanyId, :Details, :Id, :IsPrimary, :JobTitle, :WhenEnd, :WhenStart]

  @type t :: %__MODULE__{
          CompanyId: IdTitle.t(),
          Details: String.t(),
          Id: String.t(),
          IsPrimary: boolean(),
          JobTitle: String.t(),
          WhenEnd: NaiveDateTime.t(),
          WhenStart: NaiveDateTime.t()
        }
end

defmodule Property do
  @moduledoc false

  defstruct [:property1, :property2]

  @type t :: %__MODULE__{
          property1: [IdTitle.t()],
          property2: [IdTitle.t()]
        }
end

defmodule IdTitle do
  @moduledoc "Struct and type for IdTitle objects in CustomField31-35."

  defstruct [:Id, :Title]

  @type t :: %__MODULE__{
          Id: String.t(),
          Title: String.t()
        }
end

defmodule InstantAddress do
  @moduledoc false

  defstruct [:Id, :IsPrimary, :Value]

  @type t :: %__MODULE__{
          Id: String.t(),
          IsPrimary: boolean(),
          Value: String.t()
        }
end

defmodule KeyDates do
  @moduledoc false

  defstruct [:CreatedOnSystem, :Id, :IsPrimary, :Value]

  @type t :: %__MODULE__{
          CreatedOnSystem: NaiveDateTime.t(),
          Id: String.t(),
          IsPrimary: boolean(),
          Value: String.t()
        }
end

defmodule PhoneNumber do
  @moduledoc """
  Represents a phone number with associated metadata.
  """

  defstruct [:CreatedOnSystem, :Extension, :Id, :IsPrimary, :PhoneFlagTypeId, :Value]

  @type t :: %__MODULE__{
          CreatedOnSystem: NaiveDateTime.t(),
          Extension: String.t(),
          Id: String.t(),
          IsPrimary: boolean(),
          PhoneFlagTypeId: IdTitle.t(),
          Value: String.t()
        }
end

defmodule RelatedContacts do
  @moduledoc false

  defstruct [:CreatedOnSystem, :Id, :IsPrimary, :Value]

  @type t :: %__MODULE__{
          CreatedOnSystem: NaiveDateTime.t(),
          Id: String.t(),
          IsPrimary: boolean(),
          Value: Value.t()
        }
end

defmodule Value do
  @moduledoc false

  defstruct [:Id, :Title, :EntityName]

  @type t :: %__MODULE__{
          Id: String.t(),
          Title: String.t(),
          EntityName: String.t()
        }
end
