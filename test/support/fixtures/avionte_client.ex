defmodule Sync.Fixtures.AvionteClient do
  @moduledoc false

  def list_talent_ids_fixture do
    body = [
      106_494_605,
      109_336_103,
      110_186_628,
      110_188_294,
      110_230_319,
      110_230_733,
      110_241_882,
      110_887_677,
      110_945_042,
      114_555_638,
      114_555_639,
      114_555_640,
      114_555_643,
      114_555_644,
      114_555_647,
      115_270_094,
      116_737_486,
      116_737_977,
      116_751_565,
      116_751_608,
      116_751_651,
      116_865_531,
      116_883_019,
      117_099_968,
      117_555_984,
      117_556_007,
      117_556_087,
      117_556_147,
      117_556_194,
      117_583_278,
      117_585_946,
      117_863_441,
      118_507_319,
      118_581_977,
      118_601_226,
      118_870_657,
      119_007_594,
      119_116_234,
      119_116_814,
      119_118_937,
      119_119_913,
      119_120_517,
      119_120_545,
      119_120_769,
      119_143_412,
      119_143_561,
      119_143_695,
      119_143_714,
      119_143_738,
      119_143_748
    ]

    {:ok, %HTTPoison.Response{status_code: 200, body: Jason.encode!(body), request: %HTTPoison.Request{url: ""}}}
  end

  def list_talents_channel_id_fixture(opts \\ []) do
    body = [
      %{
        "id" => 109_336_103,
        "firstName" => "zzJerry",
        "middleName" => nil,
        "lastName" => "zzTester",
        "homePhone" => nil,
        "workPhone" => nil,
        "mobilePhone" => "6515554545",
        "pageNumber" => nil,
        "emailAddress" => "jkolson21@yahoo.com",
        "taxIdNumber" => nil,
        "birthday" => nil,
        "gender" => nil,
        "hireDate" => nil,
        "residentAddress" => %{
          "street1" => "5 5th St",
          "street2" => nil,
          "city" => "Eagan",
          "state_Province" => "MN",
          "postalCode" => "55121",
          "country" => "US",
          "county" => nil,
          "geoCode" => "",
          "schoolDistrictCode" => ""
        },
        "mailingAddress" => %{
          "street1" => "5 5th St",
          "street2" => nil,
          "city" => "Eagan",
          "state_Province" => "MN",
          "postalCode" => "55121",
          "country" => "US",
          "county" => nil,
          "geoCode" => "",
          "schoolDistrictCode" => ""
        },
        "payrollAddress" => nil,
        "addresses" => [
          %{
            "street1" => "5 5th St",
            "street2" => nil,
            "city" => "Eagan",
            "state_Province" => "MN",
            "postalCode" => "55121",
            "country" => "US",
            "county" => nil,
            "geoCode" => "",
            "schoolDistrictCode" => ""
          }
        ],
        "status" => "Applicant",
        "filingStatus" => "None",
        "federalAllowances" => 0,
        "stateAllowances" => 0,
        "additionalFederalWithholding" => 0.0,
        "i9ValidatedDate" => nil,
        "frontOfficeId" => 25_208,
        "latestActivityDate" => nil,
        "latestActivityName" => nil,
        "link" => "https://avionteapienvironment.myavionte.com/app/#/applicant/109336103",
        "race" => nil,
        "disability" => nil,
        "veteranStatus" => nil,
        "emailOptOut" => false,
        "isArchived" => false,
        "placementStatus" => "Not Active Contractor",
        "representativeUser" => 28_109_661,
        "w2Consent" => false,
        "electronic1095CConsent" => nil,
        "referredBy" => nil,
        "availabilityDate" => nil,
        "statusId" => 6,
        "officeName" => "avionteapienvironment",
        "officeDivision" => "Staffing",
        "enteredByUserId" => 28_109_661,
        "enteredByUser" => "jerry.olson@avionte.com",
        "representativeUserEmail" => "jerry.olson@avionte.com",
        "createdDate" => "2023-01-24T15:27:14.8",
        "lastUpdatedDate" => "2023-01-24T15:27:14.8",
        "latestWork" => nil,
        "lastContacted" => nil,
        "flag" => nil,
        "electronic1099Consent" => nil,
        "textConsent" => "No Response",
        "talentResume" => nil,
        "rehireDate" => nil,
        "terminationDate" => nil
      }
    ]

    body = if opts[:limit], do: Enum.take(body, opts[:limit]), else: body

    {:ok, %HTTPoison.Response{status_code: 201, body: Jason.encode!(body), request: %HTTPoison.Request{url: ""}}}
  end

  def list_talents_fixture(opts \\ []) do
    body = [
      %{
        "id" => 106_494_605,
        "firstName" => "zzintegration",
        "middleName" => nil,
        "lastName" => "zztester",
        "homePhone" => nil,
        "workPhone" => nil,
        "mobilePhone" => "6518675309",
        "pageNumber" => nil,
        "emailAddress" => "zzintegration@zztester.com",
        "taxIdNumber" => "867530919",
        "birthday" => "1978-06-26T00:00:00",
        "gender" => nil,
        "hireDate" => nil,
        "residentAddress" => %{
          "street1" => "12345 test blvd",
          "street2" => nil,
          "city" => "Minneapolis",
          "state_Province" => "MN",
          "postalCode" => "55401",
          "country" => "US",
          "county" => nil,
          "geoCode" => "",
          "schoolDistrictCode" => ""
        },
        "mailingAddress" => %{
          "street1" => "12345 test blvd",
          "street2" => nil,
          "city" => "Minneapolis",
          "state_Province" => "MN",
          "postalCode" => "55401",
          "country" => "US",
          "county" => nil,
          "geoCode" => "",
          "schoolDistrictCode" => ""
        },
        "payrollAddress" => nil,
        "addresses" => [
          %{
            "street1" => "12345 test blvd",
            "street2" => nil,
            "city" => "Minneapolis",
            "state_Province" => "MN",
            "postalCode" => "55401",
            "country" => "US",
            "county" => nil,
            "geoCode" => "",
            "schoolDistrictCode" => ""
          }
        ],
        "status" => "Applicant",
        "filingStatus" => "None",
        "federalAllowances" => 0,
        "stateAllowances" => 0,
        "additionalFederalWithholding" => 0.0,
        "i9ValidatedDate" => nil,
        "frontOfficeId" => 25_208,
        "latestActivityDate" => "2024-04-24T11:10:52.033Z",
        "latestActivityName" => "Text Sent",
        "link" => "https://avionteapienvironment.myavionte.com/app/#/applicant/106494605",
        "race" => nil,
        "disability" => nil,
        "veteranStatus" => nil,
        "emailOptOut" => false,
        "isArchived" => false,
        "placementStatus" => "Not Active Contractor",
        "representativeUser" => 28_109_626,
        "w2Consent" => false,
        "electronic1095CConsent" => nil,
        "referredBy" => nil,
        "availabilityDate" => nil,
        "statusId" => 6,
        "officeName" => nil,
        "officeDivision" => nil,
        "enteredByUserId" => 28_109_626,
        "enteredByUser" => "Erik.elm@avionte.com",
        "representativeUserEmail" => "Erik.elm@avionte.com",
        "createdDate" => "2022-11-30T23:13:18.587",
        "lastUpdatedDate" => "2022-11-30T23:13:18.587",
        "latestWork" => nil,
        "lastContacted" => nil,
        "flag" => nil,
        "electronic1099Consent" => nil,
        "textConsent" => "No Response",
        "talentResume" => nil,
        "rehireDate" => nil,
        "terminationDate" => nil
      },
      %{
        "id" => 109_336_103,
        "firstName" => "zzJerry",
        "middleName" => nil,
        "lastName" => "zzTester",
        "homePhone" => nil,
        "workPhone" => nil,
        "mobilePhone" => "6515554545",
        "pageNumber" => nil,
        "emailAddress" => "jkolson21@yahoo.com",
        "taxIdNumber" => nil,
        "birthday" => nil,
        "gender" => nil,
        "hireDate" => nil,
        "residentAddress" => %{
          "street1" => "5 5th St",
          "street2" => nil,
          "city" => "Eagan",
          "state_Province" => "MN",
          "postalCode" => "55121",
          "country" => "US",
          "county" => nil,
          "geoCode" => "",
          "schoolDistrictCode" => ""
        },
        "mailingAddress" => %{
          "street1" => "5 5th St",
          "street2" => nil,
          "city" => "Eagan",
          "state_Province" => "MN",
          "postalCode" => "55121",
          "country" => "US",
          "county" => nil,
          "geoCode" => "",
          "schoolDistrictCode" => ""
        },
        "payrollAddress" => nil,
        "addresses" => [
          %{
            "street1" => "5 5th St",
            "street2" => nil,
            "city" => "Eagan",
            "state_Province" => "MN",
            "postalCode" => "55121",
            "country" => "US",
            "county" => nil,
            "geoCode" => "",
            "schoolDistrictCode" => ""
          }
        ],
        "status" => "Applicant",
        "filingStatus" => "None",
        "federalAllowances" => 0,
        "stateAllowances" => 0,
        "additionalFederalWithholding" => 0.0,
        "i9ValidatedDate" => nil,
        "frontOfficeId" => 25_208,
        "latestActivityDate" => nil,
        "latestActivityName" => nil,
        "link" => "https://avionteapienvironment.myavionte.com/app/#/applicant/109336103",
        "race" => nil,
        "disability" => nil,
        "veteranStatus" => nil,
        "emailOptOut" => false,
        "isArchived" => false,
        "placementStatus" => "Not Active Contractor",
        "representativeUser" => 28_109_661,
        "w2Consent" => false,
        "electronic1095CConsent" => nil,
        "referredBy" => nil,
        "availabilityDate" => nil,
        "statusId" => 6,
        "officeName" => "avionteapienvironment",
        "officeDivision" => "Staffing",
        "enteredByUserId" => 28_109_661,
        "enteredByUser" => "jerry.olson@avionte.com",
        "representativeUserEmail" => "jerry.olson@avionte.com",
        "createdDate" => "2023-01-24T15:27:14.8",
        "lastUpdatedDate" => "2023-01-24T15:27:14.8",
        "latestWork" => nil,
        "lastContacted" => nil,
        "flag" => nil,
        "electronic1099Consent" => nil,
        "textConsent" => "No Response",
        "talentResume" => nil,
        "rehireDate" => nil,
        "terminationDate" => nil
      },
      %{
        "id" => 110_186_628,
        "firstName" => "Donna",
        "middleName" => nil,
        "lastName" => "Harrison",
        "homePhone" => nil,
        "workPhone" => nil,
        "mobilePhone" => "9176124545",
        "pageNumber" => nil,
        "emailAddress" => "donna@btnx.com",
        "taxIdNumber" => "444444444",
        "birthday" => nil,
        "gender" => nil,
        "hireDate" => nil,
        "residentAddress" => %{
          "street1" => "2121 SW Chelsea Dr.",
          "street2" => nil,
          "city" => "Topeka",
          "state_Province" => "KS",
          "postalCode" => "66614",
          "country" => "US",
          "county" => nil,
          "geoCode" => "",
          "schoolDistrictCode" => ""
        },
        "mailingAddress" => %{
          "street1" => "2121 SW Chelsea Dr.",
          "street2" => nil,
          "city" => "Topeka",
          "state_Province" => "KS",
          "postalCode" => "66614",
          "country" => "US",
          "county" => nil,
          "geoCode" => "",
          "schoolDistrictCode" => ""
        },
        "payrollAddress" => nil,
        "addresses" => [
          %{
            "street1" => "2121 SW Chelsea Dr.",
            "street2" => nil,
            "city" => "Topeka",
            "state_Province" => "KS",
            "postalCode" => "66614",
            "country" => "US",
            "county" => nil,
            "geoCode" => "",
            "schoolDistrictCode" => ""
          }
        ],
        "status" => "Applicant",
        "filingStatus" => "None",
        "federalAllowances" => 0,
        "stateAllowances" => 0,
        "additionalFederalWithholding" => 0.0,
        "i9ValidatedDate" => nil,
        "frontOfficeId" => 25_208,
        "latestActivityDate" => nil,
        "latestActivityName" => nil,
        "link" => "https://avionteapienvironment.myavionte.com/app/#/applicant/110186628",
        "race" => nil,
        "disability" => nil,
        "veteranStatus" => nil,
        "emailOptOut" => false,
        "isArchived" => false,
        "placementStatus" => "Not Active Contractor",
        "representativeUser" => 31_162_240,
        "w2Consent" => false,
        "electronic1095CConsent" => nil,
        "referredBy" => nil,
        "availabilityDate" => nil,
        "statusId" => 6,
        "officeName" => "avionteapienvironment",
        "officeDivision" => "Staffing",
        "enteredByUserId" => 31_162_240,
        "enteredByUser" => "gerard@btnx.com",
        "representativeUserEmail" => "gerard@btnx.com",
        "createdDate" => "2023-02-06T17:43:30.027",
        "lastUpdatedDate" => "2023-02-06T17:43:30.027",
        "latestWork" => nil,
        "lastContacted" => nil,
        "flag" => nil,
        "electronic1099Consent" => nil,
        "textConsent" => "No Response",
        "talentResume" => nil,
        "rehireDate" => nil,
        "terminationDate" => nil
      },
      %{
        "id" => 110_188_294,
        "firstName" => "Rayan",
        "middleName" => nil,
        "lastName" => "Wijesinghe",
        "homePhone" => nil,
        "workPhone" => nil,
        "mobilePhone" => "4167704478",
        "pageNumber" => nil,
        "emailAddress" => "rayan@btnx.com",
        "taxIdNumber" => nil,
        "birthday" => nil,
        "gender" => nil,
        "hireDate" => nil,
        "residentAddress" => %{
          "street1" => "722 Rosebank Rd",
          "street2" => nil,
          "city" => "Pickering",
          "state_Province" => nil,
          "postalCode" => "L1W 4B2",
          "country" => "CA",
          "county" => nil,
          "geoCode" => "",
          "schoolDistrictCode" => ""
        },
        "mailingAddress" => %{
          "street1" => "722 Rosebank Rd",
          "street2" => nil,
          "city" => "Pickering",
          "state_Province" => nil,
          "postalCode" => "L1W 4B2",
          "country" => "CA",
          "county" => nil,
          "geoCode" => "",
          "schoolDistrictCode" => ""
        },
        "payrollAddress" => nil,
        "addresses" => [
          %{
            "street1" => "722 Rosebank Rd",
            "street2" => nil,
            "city" => "Pickering",
            "state_Province" => nil,
            "postalCode" => "L1W 4B2",
            "country" => "CA",
            "county" => nil,
            "geoCode" => "",
            "schoolDistrictCode" => ""
          }
        ],
        "status" => "Applicant",
        "filingStatus" => "None",
        "federalAllowances" => 0,
        "stateAllowances" => 0,
        "additionalFederalWithholding" => 0.0,
        "i9ValidatedDate" => nil,
        "frontOfficeId" => 25_208,
        "latestActivityDate" => "2023-08-16T18:12:00Z",
        "latestActivityName" => "Note",
        "link" => "https://avionteapienvironment.myavionte.com/app/#/applicant/110188294",
        "race" => nil,
        "disability" => nil,
        "veteranStatus" => nil,
        "emailOptOut" => false,
        "isArchived" => true,
        "placementStatus" => "Not Active Contractor",
        "representativeUser" => 31_162_240,
        "w2Consent" => false,
        "electronic1095CConsent" => nil,
        "referredBy" => nil,
        "availabilityDate" => nil,
        "statusId" => 6,
        "officeName" => "avionteapienvironment",
        "officeDivision" => "Staffing",
        "enteredByUserId" => 31_162_240,
        "enteredByUser" => "gerard@btnx.com",
        "representativeUserEmail" => "gerard@btnx.com",
        "createdDate" => "2023-02-06T18:21:48.847",
        "lastUpdatedDate" => "2023-02-06T18:21:48.847",
        "latestWork" => nil,
        "lastContacted" => nil,
        "flag" => nil,
        "electronic1099Consent" => nil,
        "textConsent" => "No Response",
        "talentResume" => nil,
        "rehireDate" => nil,
        "terminationDate" => nil
      },
      %{
        "id" => 110_230_319,
        "firstName" => "Umang",
        "middleName" => nil,
        "lastName" => "Joshi",
        "homePhone" => nil,
        "workPhone" => nil,
        "mobilePhone" => "4169059055",
        "pageNumber" => nil,
        "emailAddress" => "umang@btnx.com",
        "taxIdNumber" => nil,
        "birthday" => nil,
        "gender" => nil,
        "hireDate" => nil,
        "residentAddress" => %{
          "street1" => nil,
          "street2" => nil,
          "city" => nil,
          "state_Province" => nil,
          "postalCode" => nil,
          "country" => "CA",
          "county" => nil,
          "geoCode" => "",
          "schoolDistrictCode" => ""
        },
        "mailingAddress" => %{
          "street1" => nil,
          "street2" => nil,
          "city" => nil,
          "state_Province" => nil,
          "postalCode" => nil,
          "country" => "CA",
          "county" => nil,
          "geoCode" => "",
          "schoolDistrictCode" => ""
        },
        "payrollAddress" => nil,
        "addresses" => [
          %{
            "street1" => nil,
            "street2" => nil,
            "city" => nil,
            "state_Province" => nil,
            "postalCode" => nil,
            "country" => "CA",
            "county" => nil,
            "geoCode" => "",
            "schoolDistrictCode" => ""
          }
        ],
        "status" => "Applicant",
        "filingStatus" => "None",
        "federalAllowances" => 0,
        "stateAllowances" => 0,
        "additionalFederalWithholding" => 0.0,
        "i9ValidatedDate" => nil,
        "frontOfficeId" => 25_208,
        "latestActivityDate" => "2023-05-04T18:49:00Z",
        "latestActivityName" => "Note",
        "link" => "https://avionteapienvironment.myavionte.com/app/#/applicant/110230319",
        "race" => nil,
        "disability" => nil,
        "veteranStatus" => nil,
        "emailOptOut" => false,
        "isArchived" => false,
        "placementStatus" => "Not Active Contractor",
        "representativeUser" => 31_162_240,
        "w2Consent" => false,
        "electronic1095CConsent" => nil,
        "referredBy" => nil,
        "availabilityDate" => nil,
        "statusId" => 6,
        "officeName" => "avionteapienvironment",
        "officeDivision" => "Staffing",
        "enteredByUserId" => 31_162_240,
        "enteredByUser" => "gerard@btnx.com",
        "representativeUserEmail" => "gerard@btnx.com",
        "createdDate" => "2023-02-07T21:46:55.063",
        "lastUpdatedDate" => "2023-02-07T21:46:55.063",
        "latestWork" => nil,
        "lastContacted" => nil,
        "flag" => nil,
        "electronic1099Consent" => nil,
        "textConsent" => "No Response",
        "talentResume" => nil,
        "rehireDate" => nil,
        "terminationDate" => nil
      },
      %{
        "id" => 110_230_733,
        "firstName" => "Iqbal",
        "middleName" => nil,
        "lastName" => "Sunderani",
        "homePhone" => nil,
        "workPhone" => nil,
        "mobilePhone" => "9059449565",
        "pageNumber" => nil,
        "emailAddress" => "ryan@lochnessmedical.com",
        "taxIdNumber" => nil,
        "birthday" => nil,
        "gender" => nil,
        "hireDate" => nil,
        "residentAddress" => %{
          "street1" => "722 Rosebank Rd",
          "street2" => nil,
          "city" => "Pickering",
          "state_Province" => nil,
          "postalCode" => "L1W 4B2",
          "country" => "CA",
          "county" => nil,
          "geoCode" => "",
          "schoolDistrictCode" => ""
        },
        "mailingAddress" => %{
          "street1" => "722 Rosebank Rd",
          "street2" => nil,
          "city" => "Pickering",
          "state_Province" => nil,
          "postalCode" => "L1W 4B2",
          "country" => "CA",
          "county" => nil,
          "geoCode" => "",
          "schoolDistrictCode" => ""
        },
        "payrollAddress" => nil,
        "addresses" => [
          %{
            "street1" => "722 Rosebank Rd",
            "street2" => nil,
            "city" => "Pickering",
            "state_Province" => nil,
            "postalCode" => "L1W 4B2",
            "country" => "CA",
            "county" => nil,
            "geoCode" => "",
            "schoolDistrictCode" => ""
          }
        ],
        "status" => "Applicant",
        "filingStatus" => "None",
        "federalAllowances" => 0,
        "stateAllowances" => 0,
        "additionalFederalWithholding" => 0.0,
        "i9ValidatedDate" => nil,
        "frontOfficeId" => 25_208,
        "latestActivityDate" => "2023-02-07T21:48:00Z",
        "latestActivityName" => "Note",
        "link" => "https://avionteapienvironment.myavionte.com/app/#/applicant/110230733",
        "race" => nil,
        "disability" => nil,
        "veteranStatus" => nil,
        "emailOptOut" => false,
        "isArchived" => false,
        "placementStatus" => "Not Active Contractor",
        "representativeUser" => 31_162_240,
        "w2Consent" => false,
        "electronic1095CConsent" => nil,
        "referredBy" => nil,
        "availabilityDate" => nil,
        "statusId" => 6,
        "officeName" => "avionteapienvironment",
        "officeDivision" => "Staffing",
        "enteredByUserId" => 31_162_240,
        "enteredByUser" => "gerard@btnx.com",
        "representativeUserEmail" => "gerard@btnx.com",
        "createdDate" => "2023-02-07T21:48:44.47",
        "lastUpdatedDate" => "2023-02-07T21:48:44.47",
        "latestWork" => nil,
        "lastContacted" => nil,
        "flag" => nil,
        "electronic1099Consent" => nil,
        "textConsent" => "No Response",
        "talentResume" => nil,
        "rehireDate" => nil,
        "terminationDate" => nil
      }
    ]

    body = if opts[:limit], do: Enum.take(body, opts[:limit]), else: body

    body =
      if opts[:ids],
        do: body |> Enum.zip(opts[:ids]) |> Enum.map(fn {talent, id} -> Map.put(talent, "id", id) end),
        else: body

    {:ok, %HTTPoison.Response{status_code: 201, body: Jason.encode!(body), request: %HTTPoison.Request{url: ""}}}
  end

  def create_talent_fixture do
    body = %{
      "id" => 2_911_805,
      "firstName" => "Rose",
      "middleName" => nil,
      "lastName" => "Bush",
      "homePhone" => nil,
      "workPhone" => nil,
      "mobilePhone" => nil,
      "pageNumber" => nil,
      "emailAddress" => "r.bush@mail.com",
      "taxIdNumber" => nil,
      "birthday" => nil,
      "gender" => nil,
      "hireDate" => nil,
      "residentAddress" => %{
        "street1" => nil,
        "street2" => nil,
        "city" => nil,
        "state_Province" => nil,
        "postalCode" => nil,
        "country" => "US",
        "county" => nil,
        "geoCode" => nil,
        "schoolDistrictCode" => nil
      },
      "mailingAddress" => %{
        "street1" => nil,
        "street2" => nil,
        "city" => nil,
        "state_Province" => nil,
        "postalCode" => nil,
        "country" => "US",
        "county" => nil,
        "geoCode" => nil,
        "schoolDistrictCode" => nil
      },
      "payrollAddress" => nil,
      "addresses" => [
        %{
          "street1" => nil,
          "street2" => nil,
          "city" => nil,
          "state_Province" => nil,
          "postalCode" => nil,
          "country" => "US",
          "county" => nil,
          "geoCode" => nil,
          "schoolDistrictCode" => nil
        }
      ],
      "status" => nil,
      "filingStatus" => "None",
      "federalAllowances" => 0,
      "stateAllowances" => 0,
      "additionalFederalWithholding" => 0,
      "i9ValidatedDate" => nil,
      "frontOfficeId" => 0,
      "latestActivityDate" => nil,
      "latestActivityName" => nil,
      "link" => nil,
      "race" => nil,
      "disability" => nil,
      "veteranStatus" => nil,
      "emailOptOut" => false,
      "isArchived" => false,
      "placementStatus" => nil,
      "representativeUser" => 151_098,
      "w2Consent" => false,
      "electronic1095CConsent" => nil,
      "referredBy" => nil,
      "availabilityDate" => nil,
      "statusId" => nil,
      "officeName" => nil,
      "officeDivision" => nil,
      "enteredByUserId" => 7,
      "enteredByUser" => nil,
      "representativeUserEmail" => nil,
      "createdDate" => "2023-04-19T18:07:14.7477579+00:00",
      "lastUpdatedDate" => "2023-04-19T18:07:14.7477579+00:00",
      "latestWork" => nil,
      "lastContacted" => nil,
      "flag" => nil,
      "electronic1099Consent" => nil
    }

    {:ok, %HTTPoison.Response{status_code: 201, body: Jason.encode!(body)}}
  end

  def list_contacts_fixture do
    body = [
      %{
        "id" => 27_320_313,
        "firstName" => "Dan",
        "middleName" => nil,
        "lastName" => "Moech",
        "workPhone" => "630-579-2000",
        "cellPhone" => "",
        "emailAddress" => "DMOECH@AMSCAN.COM",
        "emailAddress2" => nil,
        "address1" => "2727 W Diehl Road",
        "address2" => nil,
        "city" => "Naperville",
        "state" => "IL",
        "postalCode" => "60563",
        "country" => "United States of America",
        "link" => "https://allteamstaffing.myavionte.com/app/#/contact/27320313",
        "companyName" => "Factory Card Party Outlet",
        "companyId" => 10_848_979,
        "companyDepartmentId" => 12_672_830,
        "title" => "DIRECTOR OF DC OPERATIONS",
        "emailOptOut" => false,
        "isArchived" => false,
        "representativeUsers" => [
          65_648_386
        ],
        "createdDate" => "2011-12-14T11:02:43",
        "lastUpdatedDate" => "2024-10-20T05:01:51.193+00:00",
        "latestActivityDate" => "2011-12-14T11:02:43Z",
        "latestActivityName" => "Note",
        "status" => "Active",
        "statusType" => "Active",
        "origin" => nil
      },
      %{
        "id" => 27_320_314,
        "firstName" => "Joe",
        "middleName" => nil,
        "lastName" => "Moech",
        "workPhone" => "630-579-2888",
        "cellPhone" => "",
        "emailAddress" => "JOE@AMSCAN.COM",
        "emailAddress2" => nil,
        "address1" => "2727 W Diehl Road",
        "address2" => nil,
        "city" => "Naperville",
        "state" => "IL",
        "postalCode" => "60563",
        "country" => "United States of America",
        "link" => "https://allteamstaffing.myavionte.com/app/#/contact/27320314",
        "companyName" => "Factory Card Party Outlet",
        "companyId" => 10_848_979,
        "companyDepartmentId" => 12_672_830,
        "title" => "DIRECTOR OF DC OPERATIONS",
        "emailOptOut" => false,
        "isArchived" => false,
        "representativeUsers" => [
          65_648_333
        ],
        "createdDate" => "2011-12-14T11:02:43",
        "lastUpdatedDate" => "2024-10-20T05:01:51.193+00:00",
        "latestActivityDate" => "2011-12-14T11:02:43Z",
        "latestActivityName" => "Note",
        "status" => "Active",
        "statusType" => "Active",
        "origin" => nil
      }
    ]

    {:ok, %HTTPoison.Response{status_code: 200, body: Jason.encode!(body)}}
  end

  def list_contact_fixture do
    body = [
      %{
        "id" => 27_320_313,
        "firstName" => "Dan",
        "middleName" => nil,
        "lastName" => "Moech",
        "workPhone" => "630-579-2000",
        "cellPhone" => "",
        "emailAddress" => "DMOECH@AMSCAN.COM",
        "emailAddress2" => nil,
        "address1" => "2727 W Diehl Road",
        "address2" => nil,
        "city" => "Naperville",
        "state" => "IL",
        "postalCode" => "60563",
        "country" => "United States of America",
        "link" => "https://allteamstaffing.myavionte.com/app/#/contact/27320313",
        "companyName" => "Factory Card Party Outlet",
        "companyId" => 10_848_979,
        "companyDepartmentId" => 12_672_830,
        "title" => "DIRECTOR OF DC OPERATIONS",
        "emailOptOut" => false,
        "isArchived" => false,
        "representativeUsers" => [
          65_648_386
        ],
        "createdDate" => "2011-12-14T11:02:43",
        "lastUpdatedDate" => "2024-10-20T05:01:51.193+00:00",
        "latestActivityDate" => "2011-12-14T11:02:43Z",
        "latestActivityName" => "Note",
        "status" => "Active",
        "statusType" => "Active",
        "origin" => nil
      }
    ]

    {:ok, %HTTPoison.Response{status_code: 200, body: Jason.encode!(body)}}
  end

  def list_contact_ids_fixture do
    body = [
      27_320_313,
      27_320_314
    ]

    {:ok, %HTTPoison.Response{status_code: 200, body: Jason.encode!(body)}}
  end

  def create_talent_activity_fixture do
    body = %{
      "activityDate" => "2024-05-14T14:54:43.4290887Z",
      "talentId" => 106_494_605,
      "id" => 1_447_491_470,
      "notes" => "This is a test SMS message",
      "userId" => 28_109_615,
      "typeId" => -11,
      "name" => "Text Sent",
      "show_in" => 1
    }

    {:ok, %HTTPoison.Response{status_code: 200, body: Jason.encode!(body)}}
  end

  def create_contact_activity_fixture do
    body = %{
      "activityDate" => "2024-05-14T14:54:43.4290887Z",
      "contactId" => 106_494_605,
      "id" => 1_447_491_470,
      "notes" => "This is a test SMS message",
      "userId" => 28_109_615,
      "typeId" => -11,
      "name" => "Text Sent",
      "show_in" => 1
    }

    {:ok, %HTTPoison.Response{status_code: 201, body: Jason.encode!(body)}}
  end

  def list_user_ids_fixture do
    body = [
      28_109_611
    ]

    {:ok, %HTTPoison.Response{status_code: 200, body: Jason.encode!(body)}}
  end

  def list_users_fixture do
    body = [
      %{
        "userId" => 28_109_611,
        "firstName" => "Yogen",
        "lastName" => "Bista",
        "emailAddress" => "Yogen.Bista@avionte.com",
        "homePhone" => nil,
        "workPhone" => nil,
        "mobilePhone" => nil,
        "faxPhone" => nil,
        "address" => %{
          "street1" => nil,
          "street2" => nil,
          "city" => nil,
          "state_Province" => nil,
          "postalCode" => nil,
          "country" => "US",
          "county" => nil,
          "geoCode" => nil,
          "schoolDistrictCode" => nil
        },
        "officeName" => "avionteapienvironment",
        "officeDivision" => "Staffing",
        "officeRegion" => "US",
        "isArchived" => true,
        "createdDate" => "2019-12-19T16:24:42.97+00:00",
        "lastUpdatedDate" => "2022-11-02T16:01:34.207",
        "smsPhoneNumber" => nil,
        "smsForwardingNumber" => nil
      }
    ]

    {:ok, %HTTPoison.Response{status_code: 201, body: Jason.encode!(body)}}
  end

  def list_branches_fixture do
    body = [
      %{
        "id" => 25_208,
        "name" => "avionteapienvironment",
        "employer" => %{
          "name" => "Staffing",
          "address" => %{
            "street1" => nil,
            "street2" => nil,
            "city" => nil,
            "state_Province" => nil,
            "postalCode" => nil,
            "country" => nil,
            "county" => nil,
            "geoCode" => nil,
            "schoolDistrictCode" => nil
          },
          "fein" => ""
        },
        "branchAddress" => %{
          "street1" => nil,
          "street2" => nil,
          "city" => nil,
          "state_Province" => nil,
          "postalCode" => nil,
          "country" => nil,
          "county" => nil,
          "geoCode" => nil,
          "schoolDistrictCode" => nil
        }
      }
    ]

    {:ok, %HTTPoison.Response{status_code: 200, body: Jason.encode!(body)}}
  end

  def list_talent_activity_types_fixture do
    body = [
      %{
        "typeId" => -95,
        "name" => "Daily SMS Summary",
        "show_in" => 1
      },
      %{
        "typeId" => -94,
        "name" => "Pixel Bot Interview Email",
        "show_in" => 1
      },
      %{
        "typeId" => -93,
        "name" => "Happy Birthday Email",
        "show_in" => 1
      },
      %{
        "typeId" => -92,
        "name" => "How's it Going Email",
        "show_in" => 1
      },
      %{
        "typeId" => -91,
        "name" => "First Day Reminder Email",
        "show_in" => 1
      },
      %{
        "typeId" => -90,
        "name" => "Onboarding Reminder Email",
        "show_in" => 1
      },
      %{
        "typeId" => -89,
        "name" => "Onboarding Assigned Email",
        "show_in" => 1
      },
      %{
        "typeId" => -88,
        "name" => "Application Received Email",
        "show_in" => 1
      }
    ]

    {:ok, %HTTPoison.Response{status_code: 200, body: Jason.encode!(body)}}
  end

  def talent_created_webhook_event_fixture do
    %{
      "EventName" => "talent_created",
      "FrontOfficeTenantId" => 6,
      "Resource" => "{\"Id\":662,\"CorrelationId\":\"0c015041-e381-448a-b654-a398a025a2e5\"}",
      "ResourceModelType" =>
        "Avionte.Commons.CompasEventModel.ResourceModel.TalentResourceModel, Avionte.Commons.CompasEventModel, Version=1.2.4.0, Culture=neutral, PublicKeyToken=null",
      "CorrelationId" => "0c015041-e381-448a-b654-a398a025a2e5"
    }
  end

  def talent_merged_webhook_event_fixture do
    %{
      "EventName" => "talent_merged",
      "FrontOfficeTenantId" => 6,
      "Resource" =>
        "{\"GoodTalentId\":662,\"BadTalentId\":942,\"CorrelationId\":\"0c015041-e381-448a-b654-a398a025a2e5\"}",
      "ResourceModelType" =>
        "Avionte.Commons.CompasEventModel.ResourceModel.TalentResourceModel, Avionte.Commons.CompasEventModel, Version=1.2.4.0, Culture=neutral, PublicKeyToken=null",
      "CorrelationId" => "0c015041-e381-448a-b654-a398a025a2e5"
    }
  end

  def contact_created_webhook_event_fixture do
    %{
      "EventName" => "contact_created",
      "FrontOfficeTenantId" => 6,
      "Resource" => "{\"Id\":86635,\"CorrelationId\":\"ba623a16-8ecc-4a2d-a751-f796556c0c3a\"}",
      "ResourceModelType" =>
        "Avionte.Commons.CompasEventModel.ResourceModel.ContactResourceModel, Avionte.Commons.CompasEventModel, Version=1.2.4.0, Culture=neutral, PublicKeyToken=null",
      "CorrelationId" => "ba623a16-8ecc-4a2d-a751-f796556c0c3a"
    }
  end

  def contact_updated_webhook_event_fixture do
    %{
      "EventName" => "contact_updated",
      "FrontOfficeTenantId" => 6,
      "Resource" => "{\"Id\":86635,\"CorrelationId\":\"ba623a16-8ecc-4a2d-a751-f796556c0c3a\"}",
      "ResourceModelType" =>
        "Avionte.Commons.CompasEventModel.ResourceModel.ContactResourceModel, Avionte.Commons.CompasEventModel, Version=1.2.4.0, Culture=neutral, PublicKeyToken=null",
      "CorrelationId" => "ba623a16-8ecc-4a2d-a751-f796556c0c3a"
    }
  end

  def job_created_webhook_event_fixture do
    %{
      "EventName" => "job_created",
      "FrontOfficeTenantId" => 6,
      "Resource" => "{\"Id\":38870859,\"CorrelationId\":\"f765b7e3-9f23-44d5-9749-730a39664941\"}",
      "ResourceModelType" =>
        "Avionte.Commons.CompasEventModel.ResourceModel.JobResourceModel, Avionte.Commons.CompasEventModel, Version=1.2.4.0, Culture=neutral, PublicKeyToken=null",
      "CorrelationId" => "f765b7e3-9f23-44d5-9749-730a39664941"
    }
  end

  def job_updated_webhook_event_fixture do
    %{
      "EventName" => "job_updated",
      "FrontOfficeTenantId" => 6,
      "Resource" => "{\"Id\":362129,\"CorrelationId\":\"f765b7e3-9f23-44d5-9749-730a39664941\"}",
      "ResourceModelType" =>
        "Avionte.Commons.CompasEventModel.ResourceModel.JobResourceModel, Avionte.Commons.CompasEventModel, Version=1.2.4.0, Culture=neutral, PublicKeyToken=null",
      "CorrelationId" => "f765b7e3-9f23-44d5-9749-730a39664941"
    }
  end

  def placement_created_webhook_event_fixture do
    %{
      "EventName" => "placement_started",
      "FrontOfficeTenantId" => 6,
      "Resource" =>
        "{\"PlacementId\":86635, \"PlacementExtensionId\":86635,\"JobId\":159640,\"PostJobToMobileApp\":false,\"CorrelationId\":\"ba623a16-8ecc-4a2d-a751-f796556c0c3a\"}",
      "ResourceModelType" =>
        "Avionte.Commons.CompasEventModel.ResourceModel.PlacementResourceModel, Avionte.Commons.CompasEventModel, Version=1.2.4.0, Culture=neutral, PublicKeyToken=null",
      "CorrelationId" => "ba623a16-8ecc-4a2d-a751-f796556c0c3a"
    }
  end

  def placement_updated_webhook_event_fixture do
    %{
      "EventName" => "placement_updated",
      "FrontOfficeTenantId" => 6,
      "Resource" =>
        "{\"PlacementId\":86635, \"PlacementExtensionId\":86635,\"JobId\":159640,\"PostJobToMobileApp\":false,\"CorrelationId\":\"ba623a16-8ecc-4a2d-a751-f796556c0c3a\"}",
      "ResourceModelType" =>
        "Avionte.Commons.CompasEventModel.ResourceModel.PlacementResourceModel, Avionte.Commons.CompasEventModel, Version=1.2.4.0, Culture=neutral, PublicKeyToken=null",
      "CorrelationId" => "ba623a16-8ecc-4a2d-a751-f796556c0c3a"
    }
  end

  def company_updated_webhook_event_fixture do
    %{
      "EventName" => "company_updated",
      "FrontOfficeTenantId" => 6,
      "Resource" => "{\"Id\":250271,\"CorrelationId\":\"ca6b4bab-4756-492f-a178-91ea89d3c665\"}",
      "ResourceModelType" =>
        "Avionte.Commons.CompasEventModel.ResourceModel.CompanyResourceModel, Avionte.Commons.CompasEventModel, Version=1.2.4.0, Culture=neutral, PublicKeyToken=null",
      "CorrelationId" => "ca6b4bab-4756-492f-a178-91ea89d3c665"
    }
  end

  def list_companies_fixture do
    body = [
      %{
        "id" => 10_848_976,
        "name" => "Mary Carrolle Dougherty",
        "mainAddress" => %{
          "street1" => "57 S Spring Ave",
          "street2" => nil,
          "city" => "Lagrange",
          "state_Province" => "IL",
          "postalCode" => "60525",
          "country" => "US",
          "county" => "COOK",
          "geoCode" => "140311490",
          "schoolDistrictCode" => nil
        },
        "billingAddress" => nil,
        "frontOfficeId" => 37_275,
        "link" => "https://allteamstaffing.myavionte.com/app/#/company/10848976",
        "isArchived" => false,
        "representativeUsers" => [
          65_648_394
        ],
        "statusId" => 20_338,
        "status" => "Active",
        "statusType" => nil,
        "industry" => nil,
        "createdDate" => "2021-10-18T13:58:25",
        "lastUpdatedDate" => nil,
        "latestActivityDate" => nil,
        "latestActivityName" => nil,
        "openJobs" => 0,
        "phoneNumber" => "7085880886",
        "fax" => "7085881662",
        "webSite" => nil,
        "origin" => nil,
        "originRecordId" => nil,
        "weekEndDay" => nil,
        "payPeriod" => nil,
        "payCycle" => nil,
        "billingPeriod" => nil,
        "billingCycle" => nil
      }
    ]

    {:ok, %HTTPoison.Response{status_code: 200, body: Jason.encode!(body)}}
  end

  def list_companies_ids_fixture do
    body = [
      10_848_976
    ]

    {:ok, %HTTPoison.Response{status_code: 200, body: Jason.encode!(body)}}
  end

  def list_placements_fixture do
    body = [
      %{
        "id" => 96_993_923,
        "talentId" => 156_933_270,
        "jobId" => 38_871_314,
        "extensionId" => 101_073_849,
        "extensionIdList" => nil,
        "startDate" => "2015-05-19T00:00:00",
        "endDate" => "2015-06-22T00:00:00",
        "isActive" => true,
        "payRates" => %{
          "regular" => 10.0,
          "overtime" => 15.0,
          "doubletime" => 20.0
        },
        "billRates" => %{
          "regular" => 18.97,
          "overtime" => 28.46,
          "doubletime" => 37.94
        },
        "commissionUsers" => [
          %{
            "commissionPercent" => 100.0,
            "commissionUserType" => "Recruiter",
            "userFullName" => "Terry Dennis",
            "userId" => 17_629_352
          }
        ],
        "estimatedGrossProfit" => 1434.24,
        "employmentType" => "Temporary",
        "frontOfficeId" => 37_275,
        "isPermanentPlacementExtension" => false,
        "payBasis" => nil,
        "hiredDate" => "2015-05-19T11:00:00",
        "placementAdditionalRates" => [],
        "endReasonId" => 65_097,
        "endReason" => "Unknown (Converted)",
        "enteredByUserId" => 65_648_385,
        "enteredByUser" => "ptijerina@allteamstaffing.com",
        "recruiterUserId" => 65_648_385,
        "recruiterUser" => "ptijerina@allteamstaffing.com",
        "customDetails" => [],
        "createdByUserId" => 65_648_385,
        "createdDate" => "2015-05-19T11:00:00",
        "hasNoEndDate" => false,
        "originalStartDate" => "2015-05-19T11:00:00",
        "finalEndDate" => "2015-06-22T16:36:00",
        "origin" => nil,
        "reqEmploymentType" => "W-2",
        "reqEmploymentTypeName" => "W-2",
        "shiftName" => nil,
        "placementScheduleShifts" => nil,
        "placementScheduleDays" => %{
          "endTimeLocal" => "14:30:00",
          "shiftScheduleDays" => %{
            "friday" => true,
            "monday" => true,
            "saturday" => false,
            "sunday" => false,
            "thursday" => true,
            "tuesday" => true,
            "wednesday" => true
          },
          "startTimeLocal" => "06:00:00"
        }
      }
    ]

    {:ok, %HTTPoison.Response{status_code: 200, body: Jason.encode!(body)}}
  end

  def list_placements_ids_fixture do
    body = [
      96_993_923
    ]

    {:ok, %HTTPoison.Response{status_code: 200, body: Jason.encode!(body)}}
  end

  def list_jobs_fixture do
    body = [
      %{
        "id" => 38_870_859,
        "positions" => 1,
        "startDate" => "2015-05-06T00:00:00",
        "endDate" => "2015-05-12T00:00:00",
        "payRates" => %{
          "regular" => 10.0000,
          "overtime" => 15.0000,
          "doubletime" => 20.0000
        },
        "billRates" => %{
          "regular" => 19.9700,
          "overtime" => 29.9550,
          "doubletime" => 39.9400
        },
        "title" => "SODEXO @  BENEDICTINE UNIV.",
        "costCenter" => nil,
        "employeeType" => "Temporary",
        "workersCompensationClassCode" => "IL9082",
        "workerCompCode" => %{
          "id" => 634_888,
          "wcCode" => "9082",
          "wcDescription" => "Restaurants - NOC",
          "wcState" => "IL",
          "wcCountry" => "United States of America",
          "wccodeID" => 0
        },
        "workerCompCodeId" => 634_888,
        "companyId" => 10_849_331,
        "branchId" => 12_673_037,
        "frontOfficeId" => 37_275,
        "addressId" => 8_298_820,
        "worksiteAddress" => %{
          "street1" => "5700 College Road",
          "street2" => nil,
          "city" => "Lisle",
          "state_Province" => "IL",
          "postalCode" => "60532",
          "country" => "US",
          "county" => nil,
          "geoCode" => "140431630",
          "schoolDistrictCode" => nil
        },
        "poId" => 0,
        "companyName" => "Sodexo @  Benedictine Univ.",
        "link" => "https://allteamstaffing.myavionte.com/app/#/job/38870859",
        "contactId" => 27_321_291,
        "statusId" => 32_199,
        "status" => "Completed",
        "posted" => false,
        "createdDate" => "2015-05-05T11:00:00",
        "orderType" => "Contract",
        "orderTypeId" => 4,
        "representativeUsers" => [
          65_648_394
        ],
        "isArchived" => false,
        "oT_Type" => 2,
        "enteredByUserId" => 65_648_394,
        "enteredByUser" => "noEmail@gmail.com",
        "salesRepUserId" => 65_648_394,
        "salesRepUser" => "noEmail@gmail.com",
        "description" => nil,
        "customJobDetails" => [],
        "lastUpdatedDate" => nil,
        "latestActivityDate" => nil,
        "latestActivityName" => nil,
        "hasNoEndDate" => false,
        "payPeriod" => "Weekly",
        "placed" => 1,
        "overtimeRuleID" => 2_851_819,
        "startTimeLocal" => "",
        "endTimeLocal" => "",
        "shiftScheduleDays" => %{
          "monday" => nil,
          "tuesday" => nil,
          "wednesday" => nil,
          "thursday" => nil,
          "friday" => nil,
          "saturday" => nil,
          "sunday" => nil
        },
        "offer" => false,
        "pickList" => false,
        "postJobToMobileApp" => false,
        "origin" => nil,
        "worksiteaddressId" => 8_298_820,
        "worksiteAddressId" => 8_298_820,
        "ownerUserId" => 65_648_394,
        "bundled" => true,
        "startOfWeek" => "Monday",
        "shiftName" => nil,
        "scheduleLengthWeeks" => 0,
        "scheduleShifts" => [],
        "notes" => "<b>Job Description</b>: SODEXO @  BENEDICTINE UNIV.",
        "estimatedHours" => 32,
        "targetBillRate" => 19.9700,
        "targetPayRate" => 10.0000,
        "expenseType" => "PaidAndBilled",
        "useCustomOTRates" => true,
        "overtimeBillRate" => 0.0000,
        "overtimePayRate" => 0.0000,
        "doubletimeBillRate" => 0.0,
        "rateType" => 0,
        "weekDuration" => "MondayToSunday",
        "markupPercentage" => 99.7000,
        "billingManagerId" => 0,
        "billingName" => "BUDIG, FRANK",
        "billingAddress1" => "5700 College Road",
        "billingAddress2" => nil,
        "billingCity" => "Lisle",
        "billingState" => "IL",
        "billingZip" => "60532",
        "billingEmail" => "EBUDIG@BEN.EDU",
        "billingTerm" => "DueUponReceipt",
        "placementFee" => 0.0000,
        "placementPercentage" => 0.0,
        "positionCategoryId" => nil,
        "division" => nil,
        "overtimeType" => "PaidAndBilledOT",
        "maxBillRate" => 0.0000,
        "minBillRate" => 0.0000,
        "maxPayRate" => 0.0000,
        "minPayRate" => 0.0000,
        "billingPhone" => "630 209 1021",
        "department" => nil
      },
      %{
        "id" => 38_870_859,
        "positions" => 1,
        "startDate" => "2015-05-06T00:00:00",
        "endDate" => "2015-05-12T00:00:00",
        "payRates" => %{
          "regular" => 10.0000,
          "overtime" => 15.0000,
          "doubletime" => 20.0000
        },
        "billRates" => %{
          "regular" => 19.9700,
          "overtime" => 29.9550,
          "doubletime" => 39.9400
        },
        "title" => "SODEXO @  BENEDICTINE UNIV.",
        "costCenter" => nil,
        "employeeType" => "Temporary",
        "workersCompensationClassCode" => "IL9082",
        "workerCompCode" => %{
          "id" => 634_888,
          "wcCode" => "9082",
          "wcDescription" => "Restaurants - NOC",
          "wcState" => "IL",
          "wcCountry" => "United States of America",
          "wccodeID" => 0
        },
        "workerCompCodeId" => 634_888,
        "companyId" => 10_849_331,
        "branchId" => 12_673_037,
        "frontOfficeId" => 37_275,
        "addressId" => 8_298_820,
        "worksiteAddress" => %{
          "street1" => "5700 College Road",
          "street2" => nil,
          "city" => "Lisle",
          "state_Province" => "IL",
          "postalCode" => "60532",
          "country" => "US",
          "county" => nil,
          "geoCode" => "140431630",
          "schoolDistrictCode" => nil
        },
        "poId" => 0,
        "companyName" => "Sodexo @  Benedictine Univ.",
        "link" => "https://allteamstaffing.myavionte.com/app/#/job/38870859",
        "contactId" => 27_321_291,
        "statusId" => 32_199,
        "status" => "Completed",
        "posted" => false,
        "createdDate" => "2015-05-05T11:00:00",
        "orderType" => "Contract",
        "orderTypeId" => 4,
        "representativeUsers" => [
          65_648_394
        ],
        "isArchived" => false,
        "oT_Type" => 2,
        "enteredByUserId" => 65_648_394,
        "enteredByUser" => "noEmail@gmail.com",
        "salesRepUserId" => 65_648_394,
        "salesRepUser" => "noEmail@gmail.com",
        "description" => nil,
        "customJobDetails" => [],
        "lastUpdatedDate" => nil,
        "latestActivityDate" => nil,
        "latestActivityName" => nil,
        "hasNoEndDate" => false,
        "payPeriod" => "Weekly",
        "placed" => 1,
        "overtimeRuleID" => 2_851_819,
        "startTimeLocal" => "",
        "endTimeLocal" => "",
        "shiftScheduleDays" => %{
          "monday" => nil,
          "tuesday" => nil,
          "wednesday" => nil,
          "thursday" => nil,
          "friday" => nil,
          "saturday" => nil,
          "sunday" => nil
        },
        "offer" => false,
        "pickList" => false,
        "postJobToMobileApp" => false,
        "origin" => nil,
        "worksiteaddressId" => 8_298_820,
        "worksiteAddressId" => 8_298_820,
        "ownerUserId" => 65_648_394,
        "bundled" => true,
        "startOfWeek" => "Monday",
        "shiftName" => nil,
        "scheduleLengthWeeks" => 0,
        "scheduleShifts" => [],
        "notes" => "<b>Job Description</b>: SODEXO @  BENEDICTINE UNIV.",
        "estimatedHours" => 32,
        "targetBillRate" => 19.9700,
        "targetPayRate" => 10.0000,
        "expenseType" => "PaidAndBilled",
        "useCustomOTRates" => true,
        "overtimeBillRate" => 0.0000,
        "overtimePayRate" => 0.0000,
        "doubletimeBillRate" => 0.0,
        "rateType" => "HourlyRate",
        "weekDuration" => "MondayToSunday",
        "markupPercentage" => 99.7000,
        "billingManagerId" => 0,
        "billingName" => "BUDIG, FRANK",
        "billingAddress1" => "5700 College Road",
        "billingAddress2" => nil,
        "billingCity" => "Lisle",
        "billingState" => "IL",
        "billingZip" => "60532",
        "billingEmail" => "EBUDIG@BEN.EDU",
        "billingTerm" => "DueUponReceipt",
        "placementFee" => 0.0000,
        "placementPercentage" => 0.0,
        "positionCategoryId" => nil,
        "division" => nil,
        "overtimeType" => "PaidAndBilledOT",
        "maxBillRate" => 0.0000,
        "minBillRate" => 0.0000,
        "maxPayRate" => 0.0000,
        "minPayRate" => 0.0000,
        "billingPhone" => "630 209 1021",
        "department" => nil
      }
    ]

    {:ok, %HTTPoison.Response{status_code: 200, body: Jason.encode!(body)}}
  end

  def list_jobs_ids_fixture do
    body = [
      38_870_859
    ]

    {:ok, %HTTPoison.Response{status_code: 200, body: Jason.encode!(body)}}
  end

  def list_contact_activity_types_fixture do
    body = [
      %{
        "typeId" => -12,
        "name" => "Text Received",
        "show_in" => 1
      },
      %{
        "typeId" => -11,
        "name" => "Text Sent",
        "show_in" => 1
      },
      %{
        "typeId" => -10,
        "name" => "Profile Updated",
        "show_in" => 1
      },
      %{
        "typeId" => 1,
        "name" => "Call Completed",
        "show_in" => 1
      },
      %{
        "typeId" => 2,
        "name" => "Email Sent",
        "show_in" => 1
      },
      %{
        "typeId" => 3,
        "name" => "Email Received",
        "show_in" => 1
      },
      %{
        "typeId" => 4,
        "name" => "Message Left",
        "show_in" => 1
      },
      %{
        "typeId" => 5,
        "name" => "Call Returned",
        "show_in" => 1
      },
      %{
        "typeId" => 6,
        "name" => "Meeting Scheduled",
        "show_in" => 1
      },
      %{
        "typeId" => 7,
        "name" => "Note",
        "show_in" => 1
      },
      %{
        "typeId" => 8,
        "name" => "Merge Contact",
        "show_in" => 1
      },
      %{
        "typeId" => 9,
        "name" => "Meeting Completed",
        "show_in" => 1
      },
      %{
        "typeId" => 10,
        "name" => "Call Scheduled",
        "show_in" => 1
      },
      %{
        "typeId" => 12,
        "name" => "Web Meeting",
        "show_in" => 1
      },
      %{
        "typeId" => 43_510,
        "name" => "Client Visit",
        "show_in" => 1
      },
      %{
        "typeId" => 43_511,
        "name" => "Collection Call",
        "show_in" => 1
      },
      %{
        "typeId" => 45_196,
        "name" => "Agreement Sent",
        "show_in" => 1
      }
    ]

    {:ok, %HTTPoison.Response{status_code: 200, body: Jason.encode!(body)}}
  end
end
