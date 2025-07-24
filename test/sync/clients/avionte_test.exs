defmodule Sync.Clients.AvionteTest do
  use ExUnit.Case, async: false

  import Mock
  import Sync.Fixtures.AvionteClient

  alias Sync.Clients.Avionte
  alias Sync.Clients.Avionte.Model.Address
  alias Sync.Clients.Avionte.Model.Branch
  alias Sync.Clients.Avionte.Model.ContactActivity
  alias Sync.Clients.Avionte.Model.Employer
  alias Sync.Clients.Avionte.Model.Talent
  alias Sync.Clients.Avionte.Model.TalentActivity
  alias Sync.Utils.Http.Retry

  # We log an error when we get a non-success status code
  # and this tag captures the log so it does not clutter the test output
  @moduletag capture_log: true

  @list_talent_ids_url "https://api.avionte.com/front-office/v1/talents/ids"
  @list_contact_ids_url "https://api.avionte.com/front-office/v1/contacts/ids"
  @list_placement_ids_url "https://api.avionte.com/front-office/v1/placements/ids"
  @list_job_ids_url "https://api.avionte.com/front-office/v1/jobs/ids"
  @list_company_ids_url "https://api.avionte.com/front-office/v1/companies/ids"

  setup_with_mocks([{Retry, [], [request: fn function, _opts -> function.() end]}]) do
    :ok
  end

  describe "list_talent_ids/4" do
    test "makes request to the correct endpoint with default page and page_zise" do
      with_mock HTTPoison,
        get: fn url, _header, _opts ->
          assert url == @list_talent_ids_url <> "/1/50/"
          {:ok, %HTTPoison.Response{request: %HTTPoison.Request{url: url}}}
        end do
        Avionte.list_talent_ids("api_key", "bearer_token", "tenant")
      end
    end

    test "if we pass it a limit and offset, it will be reflected in the request" do
      with_mock HTTPoison,
        get: fn url, _header, _opts ->
          assert url == @list_talent_ids_url <> "/2/100/"
          {:ok, %HTTPoison.Response{request: %HTTPoison.Request{url: url}}}
        end do
        Avionte.list_talent_ids("api_key", "bearer_token", "tenant", limit: 100, offset: 100)
      end
    end

    test "returns a list of talent ids" do
      with_mock HTTPoison,
        get: fn _url, _header, _opts -> list_talent_ids_fixture() end do
        {:ok, result} = Avionte.list_talent_ids("api_key", "bearer_token", "tenant")
        assert Enum.all?(result, &is_integer/1)
      end
    end

    test "returns an error tuple if the request fails with status code different than 200" do
      error =
        {:ok,
         %HTTPoison.Response{
           status_code: 400,
           body: Jason.encode!([]),
           request: %HTTPoison.Request{url: @list_talent_ids_url}
         }}

      with_mock HTTPoison,
        get: fn _url, _header, _opts -> error end do
        assert {:error, error} == Avionte.list_talent_ids("api_key", "bearer_token", "tenant")
      end
    end

    test "returns an error tuple if the request fails" do
      error = {:error, %HTTPoison.Error{reason: :timeout}}

      with_mock HTTPoison,
        get: fn _url, _header, _opts -> error end do
        assert {:error, :timeout} == Avionte.list_talent_ids("api_key", "bearer_token", "tenant")
      end
    end
  end

  describe "list_talents/4" do
    test "makes request to the correct endpoint" do
      with_mock HTTPoison,
        post: fn url, _header, _body, _opts ->
          assert url == "https://api.avionte.com/front-office/v1/talents/multi-query"
          {:ok, %HTTPoison.Response{request: %HTTPoison.Request{url: url}}}
        end do
        Avionte.list_talents("api_key", "bearer_token", "tenant", talent_ids: [1, 2, 3])
      end
    end

    test "returns a list of contact maps with the talent as external_contact" do
      with_mock HTTPoison, post: fn _url, _header, _body, _opts -> list_talents_fixture() end do
        assert {:ok,
                [
                  %{
                    external_contact_id: "106494605",
                    external_contact: %Talent{
                      additionalFederalWithholding: _,
                      addresses: [
                        %Address{
                          city: "Minneapolis",
                          country: "US",
                          county: nil,
                          geoCode: nil,
                          postalCode: "55401",
                          schoolDistrictCode: nil,
                          state_Province: "MN",
                          street1: "12345 test blvd",
                          street2: nil
                        }
                      ],
                      availabilityDate: nil,
                      birthday: ~N[1978-06-26 00:00:00],
                      createdDate: ~D[2022-11-30],
                      disability: nil,
                      electronic1095CConsent: nil,
                      electronic1099Consent: nil,
                      emailAddress: "zzintegration@zztester.com",
                      emailOptOut: false,
                      enteredByUser: "Erik.elm@avionte.com",
                      enteredByUserId: 28_109_626,
                      federalAllowances: 0,
                      filingStatus: "None",
                      firstName: "zzintegration",
                      flag: nil,
                      frontOfficeId: 25_208,
                      gender: nil,
                      hireDate: nil,
                      homePhone: nil,
                      i9ValidatedDate: nil,
                      id: 106_494_605,
                      isArchived: false,
                      lastContacted: nil,
                      lastName: "zztester",
                      lastUpdatedDate: ~D[2022-11-30],
                      latestActivityDate: ~N[2024-04-24 11:10:52],
                      latestActivityName: "Text Sent",
                      latestWork: nil,
                      link: "https://avionteapienvironment.myavionte.com/app/#/applicant/106494605",
                      mailingAddress: %Address{
                        city: "Minneapolis",
                        country: "US",
                        county: nil,
                        geoCode: nil,
                        postalCode: "55401",
                        schoolDistrictCode: nil,
                        state_Province: "MN",
                        street1: "12345 test blvd",
                        street2: nil
                      },
                      middleName: nil,
                      mobilePhone: "6518675309",
                      officeDivision: nil,
                      officeName: nil,
                      pageNumber: nil,
                      payrollAddress: nil,
                      placementStatus: "Not Active Contractor",
                      race: nil,
                      referredBy: nil,
                      rehireDate: nil,
                      representativeUser: 28_109_626,
                      representativeUserEmail: "Erik.elm@avionte.com",
                      residentAddress: %Address{
                        city: "Minneapolis",
                        country: "US",
                        county: nil,
                        geoCode: nil,
                        postalCode: "55401",
                        schoolDistrictCode: nil,
                        state_Province: "MN",
                        street1: "12345 test blvd",
                        street2: nil
                      },
                      stateAllowances: 0,
                      status: "Applicant",
                      statusId: 6,
                      talentResume: nil,
                      taxIdNumber: "867530919",
                      terminationDate: nil,
                      textConsent: "No Response",
                      veteranStatus: nil,
                      w2Consent: false,
                      workPhone: nil
                    }
                  }
                  | _tail
                ]} = Avionte.list_talents("api_key", "bearer_token", "tenant", talent_ids: [1, 2, 3])
      end
    end

    test "returns an error tuple if the request fails with status code different than 200" do
      error = {:ok, %HTTPoison.Response{status_code: 400, body: Jason.encode!([]), request: %HTTPoison.Request{url: ""}}}

      with_mock HTTPoison,
        post: fn _url, _header, _body, _opts -> error end do
        assert {:error, error} == Avionte.list_talents("api_key", "bearer_token", "tenant", talent_ids: [1, 2, 3])
      end
    end

    test "returns an error tuple if the request fails" do
      error = {:error, %HTTPoison.Error{reason: :timeout}}

      with_mock HTTPoison,
        post: fn _url, _header, _body, _opts -> error end do
        assert {:error, :timeout} == Avionte.list_talents("api_key", "bearer_token", "tenant", talent_ids: [1, 2, 3])
      end
    end
  end

  describe "create_talent/4" do
    test "makes request to the correct endpoint" do
      with_mock HTTPoison,
        post: fn url, _header, _body, _opts ->
          assert url == "https://api.avionte.com/front-office/v1/talent?useNewTalentRequirements=false"
          create_talent_fixture()
        end do
        Avionte.create_talent("api_key", "bearer_token", "tenant", %{
          firstName: "John",
          lastName: "Doe",
          emailAddress: "example@example.com",
          mobilePhone: "+1234567890"
        })
      end
    end

    test "returns a contact map containing the Talent as external_contact" do
      with_mock HTTPoison, post: fn _url, _header, _body, _opts -> create_talent_fixture() end do
        assert {:ok, %{name: "Rose Bush", external_contact: %Talent{}}} =
                 Avionte.create_talent("api_key", "bearer_token", "tenant", %{
                   firstName: "Rose",
                   lastName: "Bush",
                   emailAddress: "example@example.com",
                   mobilePhone: "+1234567890"
                 })
      end
    end
  end

  describe "create_talent_activity/4" do
    test "makes request to the correct endpoint" do
      with_mock HTTPoison,
        post: fn url, _header, _body, _opts ->
          assert url == "https://api.avionte.com/front-office/v1/talent/106494605/activity"
          {:ok, %HTTPoison.Response{}}
        end do
        Avionte.create_talent_activity("api_key", "bearer_token", "tenant",
          talent_id: 106_494_605,
          body: %{
            notes: "This is a test SMS message",
            typeId: -11
          }
        )
      end
    end

    test "returns a talent activity" do
      with_mock HTTPoison, post: fn _url, _header, _body, _opts -> create_talent_activity_fixture() end do
        assert {:ok,
                %TalentActivity{
                  activityDate: ~N[2024-05-14 14:54:43],
                  id: 1_447_491_470,
                  name: "Text Sent",
                  notes: "This is a test SMS message",
                  show_in: 1,
                  talentId: 106_494_605,
                  typeId: -11,
                  userId: 28_109_615
                }} =
                 Avionte.create_talent_activity("api_key", "bearer_token", "tenant",
                   talent_id: 106_494_605,
                   body: %{
                     notes: "This is a test SMS message",
                     typeId: -11
                   }
                 )
      end
    end

    test "returns an error tuple if the request fails with status code different than 200" do
      error = {:ok, %HTTPoison.Response{status_code: 400, body: Jason.encode!([])}}

      with_mock HTTPoison,
        post: fn _url, _header, _body, _opts -> error end do
        assert {:error, error} ==
                 Avionte.create_talent_activity("api_key", "bearer_token", "tenant",
                   talent_id: 106_494_605,
                   body: %{
                     notes: "This is a test SMS message",
                     typeId: -11
                   }
                 )
      end
    end

    test "returns an error tuple if the request fails due to timeout" do
      error = {:error, %HTTPoison.Error{reason: :timeout}}

      with_mock HTTPoison,
        post: fn _url, _header, _body, _opts -> error end do
        assert {:error, :timeout} ==
                 Avionte.create_talent_activity("api_key", "bearer_token", "tenant",
                   talent_id: 106_494_605,
                   body: %{
                     notes: "This is a test SMS message",
                     typeId: -11
                   }
                 )
      end
    end
  end

  describe "list_user_ids/4" do
    test "makes request to the correct endpoint" do
      with_mock HTTPoison,
        get: fn url, _header, _opts ->
          assert url == "https://api.avionte.com/front-office/v1/users/ids/1/50/"
          {:ok, %HTTPoison.Response{}}
        end do
        Avionte.list_user_ids("api_key", "bearer_token", "tenant")
      end
    end

    test "if we pass it a page and page_size, it will be reflected in the request" do
      with_mock HTTPoison,
        get: fn url, _header, _opts ->
          assert url == "https://api.avionte.com/front-office/v1/users/ids/3/100/"
          {:ok, %HTTPoison.Response{}}
        end do
        Avionte.list_user_ids("api_key", "bearer_token", "tenant", limit: 100, offset: 200)
      end
    end

    test "returns a list of user ids" do
      with_mock HTTPoison,
        get: fn _url, _header, _opts -> list_user_ids_fixture() end do
        {:ok, result} = Avionte.list_user_ids("api_key", "bearer_token", "tenant", limit: 100, offset: 200)
        assert Enum.all?(result, &is_integer/1)
      end
    end

    test "returns an error tuple if the request fails with status code different than 200" do
      error = {:ok, %HTTPoison.Response{status_code: 400, body: Jason.encode!([])}}

      with_mock HTTPoison,
        get: fn _url, _header, _opts -> error end do
        assert {:error, error} == Avionte.list_user_ids("api_key", "bearer_token", "tenant")
      end
    end

    test "returns an error tuple if the request fails due to timeout" do
      error = {:error, %HTTPoison.Error{reason: :timeout}}

      with_mock HTTPoison,
        get: fn _url, _header, _opts -> error end do
        assert {:error, :timeout} == Avionte.list_user_ids("api_key", "bearer_token", "tenant")
      end
    end
  end

  describe "list_users/3" do
    test "makes request to the correct endpoint" do
      with_mock HTTPoison,
        get: fn url, _header, _opts ->
          assert url == "https://api.avionte.com/front-office/v1/users"
          {:ok, %HTTPoison.Response{}}
        end do
        Avionte.list_users("api_key", "bearer_token", "tenant")
      end
    end

    test "returns a list of user maps in `sync-user` format with lowercase email and external ID as string" do
      with_mock HTTPoison,
        get: fn _url, _header, _opts -> list_users_fixture() end do
        assert {:ok,
                [
                  %{
                    external_user_id: "28109611",
                    first_name: "Yogen",
                    last_name: "Bista",
                    email: "yogen.bista@avionte.com"
                  }
                ]} = Avionte.list_users("api_key", "bearer_token", "tenant")
      end
    end

    test "returns an error tuple if the request fails with status code different than 200" do
      error = {:ok, %HTTPoison.Response{status_code: 400, body: Jason.encode!([])}}

      with_mock HTTPoison,
        get: fn _url, _header, _opts -> error end do
        assert {:error, error} == Avionte.list_users("api_key", "bearer_token", "tenant")
      end
    end

    test "returns an error tuple if the request fails due to timeout" do
      error = {:error, %HTTPoison.Error{reason: :timeout}}

      with_mock HTTPoison,
        get: fn _url, _header, _opts -> error end do
        assert {:error, :timeout} == Avionte.list_users("api_key", "bearer_token", "tenant")
      end
    end
  end

  describe "list_branches/2" do
    test "makes request to the correct endpoint" do
      with_mock HTTPoison,
        get: fn url, _header, _opts ->
          assert url == "https://api.avionte.com/front-office/v1/branch"
          {:ok, %HTTPoison.Response{}}
        end do
        Avionte.list_branches("api_key", "bearer_token", "tenant")
      end
    end

    test "returns a list of branches" do
      with_mock HTTPoison,
        get: fn _url, _header, _opts -> list_branches_fixture() end do
        assert {:ok,
                [
                  %{
                    external_channel_id: "25208",
                    external_channel: %Branch{
                      id: 25_208,
                      name: "avionteapienvironment",
                      branchAddress: %Address{
                        street1: nil,
                        street2: nil,
                        city: nil,
                        state_Province: nil,
                        postalCode: nil,
                        country: nil,
                        county: nil,
                        geoCode: nil,
                        schoolDistrictCode: nil
                      },
                      employer: %Employer{
                        name: "Staffing",
                        address: %Address{
                          street1: nil,
                          street2: nil,
                          city: nil,
                          state_Province: nil,
                          postalCode: nil,
                          country: nil,
                          county: nil,
                          geoCode: nil,
                          schoolDistrictCode: nil
                        },
                        fein: nil
                      }
                    }
                  }
                ]} = Avionte.list_branches("api_key", "bearer_token", "tenant")
      end
    end

    test "returns an error tuple if the request fails with status code different than 200" do
      error = {:ok, %HTTPoison.Response{status_code: 400, body: Jason.encode!([])}}

      with_mock HTTPoison,
        get: fn _url, _header, _opts -> error end do
        assert {:error, error} == Avionte.list_branches("api_key", "bearer_token", "tenant")
      end
    end

    test "returns an error tuple if the request fails due to timeout" do
      error = {:error, %HTTPoison.Error{reason: :timeout}}

      with_mock HTTPoison,
        get: fn _url, _header, _opts -> error end do
        assert {:error, :timeout} == Avionte.list_branches("api_key", "bearer_token", "tenant")
      end
    end
  end

  describe "list_talent_activity_types/3" do
    test "makes request to the correct endpoint" do
      with_mock HTTPoison,
        get: fn url, _header, _opts ->
          assert url == "https://api.avionte.com/front-office/v1/talent/activity-types"
          {:ok, %HTTPoison.Response{}}
        end do
        Avionte.list_talent_activity_types("api_key", "bearer_token", "tenant")
      end
    end

    test "returns a list of talent activity types" do
      with_mock HTTPoison,
        get: fn _url, _header, _opts -> list_talent_activity_types_fixture() end do
        assert {:ok,
                [
                  %{name: "Daily SMS Summary", activity_type_id: -95},
                  %{name: "Pixel Bot Interview Email", activity_type_id: -94},
                  %{name: "Happy Birthday Email", activity_type_id: -93},
                  %{name: "How's it Going Email", activity_type_id: -92},
                  %{name: "First Day Reminder Email", activity_type_id: -91},
                  %{name: "Onboarding Reminder Email", activity_type_id: -90},
                  %{name: "Onboarding Assigned Email", activity_type_id: -89},
                  %{name: "Application Received Email", activity_type_id: -88}
                ]} = Avionte.list_talent_activity_types("api_key", "bearer_token", "tenant")
      end
    end

    test "returns an error tuple if the request fails with status code different than 200" do
      error = {:ok, %HTTPoison.Response{status_code: 400, body: Jason.encode!([])}}

      with_mock HTTPoison,
        get: fn _url, _header, _opts -> error end do
        assert {:error, error} == Avionte.list_talent_activity_types("api_key", "bearer_token", "tenant")
      end
    end

    test "returns an error tuple if the request fails due to timeout" do
      error = {:error, %HTTPoison.Error{reason: :timeout}}

      with_mock HTTPoison,
        get: fn _url, _header, _opts -> error end do
        assert {:error, :timeout} == Avionte.list_talent_activity_types("api_key", "bearer_token", "tenant")
      end
    end
  end

  describe "list_contact_ids/4" do
    test "makes request to the correct endpoint with default page and page_zise" do
      with_mock HTTPoison,
        get: fn url, _header, _opts ->
          assert url == @list_contact_ids_url <> "/1/50/"
          {:ok, %HTTPoison.Response{request: %HTTPoison.Request{url: url}}}
        end do
        Avionte.list_contact_ids("api_key", "bearer_token", "tenant")
      end
    end

    test "if we pass it a limit and offset, it will be reflected in the request" do
      with_mock HTTPoison,
        get: fn url, _header, _opts ->
          assert url == @list_contact_ids_url <> "/2/100/"
          {:ok, %HTTPoison.Response{request: %HTTPoison.Request{url: url}}}
        end do
        Avionte.list_contact_ids("api_key", "bearer_token", "tenant", limit: 100, offset: 100)
      end
    end

    test "returns a list of contact ids" do
      with_mock HTTPoison,
        get: fn _url, _header, _opts -> list_contact_ids_fixture() end do
        {:ok, result} = Avionte.list_contact_ids("api_key", "bearer_token", "tenant")
        assert Enum.all?(result, &is_integer/1)
      end
    end

    test "returns an error tuple if the request fails with status code different than 200" do
      error =
        {:ok,
         %HTTPoison.Response{
           status_code: 400,
           body: Jason.encode!([]),
           request: %HTTPoison.Request{url: @list_talent_ids_url}
         }}

      with_mock HTTPoison,
        get: fn _url, _header, _opts -> error end do
        assert {:error, error} == Avionte.list_contact_ids("api_key", "bearer_token", "tenant")
      end
    end

    test "returns an error tuple if the request fails" do
      error = {:error, %HTTPoison.Error{reason: :timeout}}

      with_mock HTTPoison,
        get: fn _url, _header, _opts -> error end do
        assert {:error, :timeout} == Avionte.list_contact_ids("api_key", "bearer_token", "tenant")
      end
    end
  end

  describe "list_contacts/4" do
    test "makes request to the correct endpoint" do
      with_mock HTTPoison,
        post: fn url, _header, _body, _opts ->
          assert url == "https://api.avionte.com/front-office/v1/contacts/multi-query"
          {:ok, %HTTPoison.Response{request: %HTTPoison.Request{url: url}}}
        end do
        Avionte.list_contacts("api_key", "bearer_token", "tenant", contact_ids: [1, 2, 3])
      end
    end

    test "returns a list of contact maps with the contact as external_contact" do
      with_mock HTTPoison, post: fn _url, _header, _body, _opts -> list_contacts_fixture() end do
        assert {:ok,
                [
                  %{
                    external_contact: %Sync.Clients.Avionte.Model.AvionteContact{
                      createdDate: ~D[2011-12-14],
                      emailAddress: "DMOECH@AMSCAN.COM",
                      emailOptOut: false,
                      firstName: "Dan",
                      id: 27_320_313,
                      isArchived: false,
                      lastName: "Moech",
                      lastUpdatedDate: ~D[2024-10-20],
                      latestActivityDate: ~D[2011-12-14],
                      latestActivityName: "Note",
                      link: "https://allteamstaffing.myavionte.com/app/#/contact/27320313",
                      middleName: nil,
                      status: "Active",
                      workPhone: "630-579-2000",
                      address1: "2727 W Diehl Road",
                      address2: nil,
                      cellPhone: nil,
                      city: "Naperville",
                      companyDepartmentId: 12_672_830,
                      companyId: 10_848_979,
                      companyName: "Factory Card Party Outlet",
                      country: "United States of America",
                      emailAddress2: nil,
                      origin: nil,
                      postalCode: "60563",
                      representativeUsers: [65_648_386],
                      state: "IL",
                      statusType: "Active",
                      title: "DIRECTOR OF DC OPERATIONS"
                    },
                    external_contact_id: "contact-27320313",
                    address: %{
                      state: "IL",
                      city: "Naperville",
                      country: "United States of America",
                      address_line_one: "2727 W Diehl Road",
                      address_line_two: nil,
                      post_code: "60563"
                    },
                    archived: false,
                    email: "dmoech@amscan.com",
                    name: "Dan Moech",
                    phone: "630-579-2000"
                  },
                  %{
                    name: "Joe Moech",
                    address: %{
                      state: "IL",
                      city: "Naperville",
                      country: "United States of America",
                      address_line_one: "2727 W Diehl Road",
                      address_line_two: nil,
                      post_code: "60563"
                    },
                    external_contact_id: "contact-27320314",
                    external_contact: %Sync.Clients.Avionte.Model.AvionteContact{
                      id: 27_320_314,
                      firstName: "Joe",
                      middleName: nil,
                      lastName: "Moech",
                      workPhone: "630-579-2888",
                      cellPhone: nil,
                      emailAddress: "JOE@AMSCAN.COM",
                      emailAddress2: nil,
                      address1: "2727 W Diehl Road",
                      address2: nil,
                      city: "Naperville",
                      state: "IL",
                      postalCode: "60563",
                      country: "United States of America",
                      link: "https://allteamstaffing.myavionte.com/app/#/contact/27320314",
                      companyName: "Factory Card Party Outlet",
                      companyId: 10_848_979,
                      companyDepartmentId: 12_672_830,
                      title: "DIRECTOR OF DC OPERATIONS",
                      emailOptOut: false,
                      isArchived: false,
                      representativeUsers: [65_648_333],
                      createdDate: ~D[2011-12-14],
                      lastUpdatedDate: ~D[2024-10-20],
                      latestActivityDate: ~D[2011-12-14],
                      latestActivityName: "Note",
                      status: "Active",
                      statusType: "Active",
                      origin: nil
                    },
                    email: "joe@amscan.com",
                    archived: false,
                    phone: "630-579-2888"
                  }
                  | _tail
                ]} = Avionte.list_contacts("api_key", "bearer_token", "tenant", contact_ids: [1, 2])
      end
    end

    test "returns an error tuple if the request fails with status code different than 200" do
      error = {:ok, %HTTPoison.Response{status_code: 400, body: Jason.encode!([]), request: %HTTPoison.Request{url: ""}}}

      with_mock HTTPoison,
        post: fn _url, _header, _body, _opts -> error end do
        assert {:error, error} == Avionte.list_contacts("api_key", "bearer_token", "tenant", contact_ids: [1, 2])
      end
    end

    test "returns an error tuple if the request fails" do
      error = {:error, %HTTPoison.Error{reason: :timeout}}

      with_mock HTTPoison,
        post: fn _url, _header, _body, _opts -> error end do
        assert {:error, :timeout} == Avionte.list_contacts("api_key", "bearer_token", "tenant", contact_ids: [1, 2])
      end
    end
  end

  describe "list_placement_ids/4" do
    test "makes request to the correct endpoint with default page and page_zise" do
      with_mock HTTPoison,
        get: fn url, _header, _opts ->
          assert url == @list_placement_ids_url <> "/1/50/"
          {:ok, %HTTPoison.Response{request: %HTTPoison.Request{url: url}}}
        end do
        Avionte.list_placement_ids("api_key", "bearer_token", "tenant")
      end
    end

    test "if we pass it a limit and offset, it will be reflected in the request" do
      with_mock HTTPoison,
        get: fn url, _header, _opts ->
          assert url == @list_placement_ids_url <> "/2/100/"
          {:ok, %HTTPoison.Response{request: %HTTPoison.Request{url: url}}}
        end do
        Avionte.list_placement_ids("api_key", "bearer_token", "tenant", limit: 100, offset: 100)
      end
    end

    test "returns a list of placement ids" do
      with_mock HTTPoison,
        get: fn _url, _header, _opts -> list_placements_ids_fixture() end do
        {:ok, result} = Avionte.list_placement_ids("api_key", "bearer_token", "tenant")
        assert Enum.all?(result, &is_integer/1)
      end
    end

    test "returns an error tuple if the request fails with status code different than 200" do
      error =
        {:ok,
         %HTTPoison.Response{
           status_code: 400,
           body: Jason.encode!([]),
           request: %HTTPoison.Request{url: @list_placement_ids_url}
         }}

      with_mock HTTPoison,
        get: fn _url, _header, _opts -> error end do
        assert {:error, error} == Avionte.list_placement_ids("api_key", "bearer_token", "tenant")
      end
    end

    test "returns an error tuple if the request fails" do
      error = {:error, %HTTPoison.Error{reason: :timeout}}

      with_mock HTTPoison,
        get: fn _url, _header, _opts -> error end do
        assert {:error, :timeout} == Avionte.list_placement_ids("api_key", "bearer_token", "tenant")
      end
    end
  end

  describe "list_placements/4" do
    test "makes request to the correct endpoint" do
      with_mock HTTPoison,
        post: fn url, _header, _body, _opts ->
          assert url == "https://api.avionte.com/front-office/v1/placements/multi-query"
          {:ok, %HTTPoison.Response{request: %HTTPoison.Request{url: url}}}
        end do
        Avionte.list_placements("api_key", "bearer_token", "tenant", placement_ids: [1, 2, 3])
      end
    end

    test "returns a list of placements" do
      with_mock HTTPoison, post: fn _url, _header, _body, _opts -> list_placements_fixture() end do
        assert {:ok,
                [
                  %Sync.Clients.Avionte.Model.Placement{
                    billRates: %{"doubletime" => 37.94, "overtime" => 28.46, "regular" => 18.97},
                    commissionUsers: [
                      %{
                        "commissionPercent" => 100.0,
                        "commissionUserType" => "Recruiter",
                        "userFullName" => "Terry Dennis",
                        "userId" => 17_629_352
                      }
                    ],
                    createdByUserId: 65_648_385,
                    createdDate: ~D[2015-05-19],
                    customDetails: [],
                    employmentType: "Temporary",
                    endDate: ~D[2015-06-22],
                    endReason: "Unknown (Converted)",
                    endReasonId: 65_097,
                    enteredByUser: "ptijerina@allteamstaffing.com",
                    enteredByUserId: 65_648_385,
                    estimatedGrossProfit: 1434.24,
                    extensionId: 101_073_849,
                    extensionIdList: nil,
                    finalEndDate: ~D[2015-06-22],
                    frontOfficeId: 37_275,
                    hasNoEndDate: false,
                    hiredDate: ~D[2015-05-19],
                    id: 96_993_923,
                    isActive: true,
                    isPermanentPlacementExtension: false,
                    jobId: 38_871_314,
                    origin: nil,
                    originalStartDate: ~D[2015-05-19],
                    payBasis: nil,
                    payRates: %{"doubletime" => 20.0, "overtime" => 15.0, "regular" => 10.0},
                    placementScheduleDays: %{
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
                    },
                    placementScheduleShifts: nil,
                    recruiterUser: "ptijerina@allteamstaffing.com",
                    recruiterUserId: 65_648_385,
                    reqEmploymentType: "W-2",
                    reqEmploymentTypeName: "W-2",
                    shiftName: nil,
                    startDate: ~D[2015-05-19],
                    talentId: 156_933_270
                  }
                  | _tail
                ]} = Avionte.list_placements("api_key", "bearer_token", "tenant", placement_ids: [1, 2])
      end
    end

    test "returns an error tuple if the request fails with status code different than 200" do
      error = {:ok, %HTTPoison.Response{status_code: 400, body: Jason.encode!([]), request: %HTTPoison.Request{url: ""}}}

      with_mock HTTPoison,
        post: fn _url, _header, _body, _opts -> error end do
        assert {:error, error} == Avionte.list_placements("api_key", "bearer_token", "tenant", placement_ids: [1, 2])
      end
    end

    test "returns an error tuple if the request fails" do
      error = {:error, %HTTPoison.Error{reason: :timeout}}

      with_mock HTTPoison,
        post: fn _url, _header, _body, _opts -> error end do
        assert {:error, :timeout} == Avionte.list_placements("api_key", "bearer_token", "tenant", placement_ids: [1, 2])
      end
    end
  end

  describe "list_job_ids/4" do
    test "makes request to the correct endpoint with default page and page_zise" do
      with_mock HTTPoison,
        get: fn url, _header, _opts ->
          assert url == @list_job_ids_url <> "/1/50/"
          {:ok, %HTTPoison.Response{request: %HTTPoison.Request{url: url}}}
        end do
        Avionte.list_job_ids("api_key", "bearer_token", "tenant")
      end
    end

    test "if we pass it a limit and offset, it will be reflected in the request" do
      with_mock HTTPoison,
        get: fn url, _header, _opts ->
          assert url == @list_job_ids_url <> "/2/100/"
          {:ok, %HTTPoison.Response{request: %HTTPoison.Request{url: url}}}
        end do
        Avionte.list_job_ids("api_key", "bearer_token", "tenant", limit: 100, offset: 100)
      end
    end

    test "returns a list of jobs ids" do
      with_mock HTTPoison,
        get: fn _url, _header, _opts -> list_jobs_ids_fixture() end do
        {:ok, result} = Avionte.list_job_ids("api_key", "bearer_token", "tenant")
        assert Enum.all?(result, &is_integer/1)
      end
    end

    test "returns an error tuple if the request fails with status code different than 200" do
      error =
        {:ok,
         %HTTPoison.Response{
           status_code: 400,
           body: Jason.encode!([]),
           request: %HTTPoison.Request{url: @list_job_ids_url}
         }}

      with_mock HTTPoison,
        get: fn _url, _header, _opts -> error end do
        assert {:error, error} == Avionte.list_job_ids("api_key", "bearer_token", "tenant")
      end
    end

    test "returns an error tuple if the request fails" do
      error = {:error, %HTTPoison.Error{reason: :timeout}}

      with_mock HTTPoison,
        get: fn _url, _header, _opts -> error end do
        assert {:error, :timeout} == Avionte.list_job_ids("api_key", "bearer_token", "tenant")
      end
    end
  end

  describe "list_jobs/4" do
    test "makes request to the correct endpoint" do
      with_mock HTTPoison,
        post: fn url, _header, _body, _opts ->
          assert url == "https://api.avionte.com/front-office/v1/jobs/multi-query"
          {:ok, %HTTPoison.Response{request: %HTTPoison.Request{url: url}}}
        end do
        Avionte.list_jobs("api_key", "bearer_token", "tenant", job_ids: [1, 2, 3])
      end
    end

    test "returns a list of jobs" do
      with_mock HTTPoison, post: fn _url, _header, _body, _opts -> list_jobs_fixture() end do
        assert {:ok,
                [
                  %Sync.Clients.Avionte.Model.Jobs{
                    addressId: 8_298_820,
                    billRates: %{"doubletime" => 39.94, "overtime" => 29.955, "regular" => 19.97},
                    billingAddress1: "5700 College Road",
                    billingAddress2: nil,
                    billingCity: "Lisle",
                    billingEmail: "EBUDIG@BEN.EDU",
                    billingManagerId: 0,
                    billingName: "BUDIG, FRANK",
                    billingPhone: "630 209 1021",
                    billingState: "IL",
                    billingTerm: "DueUponReceipt",
                    billingZip: "60532",
                    branchId: 12_673_037,
                    bundled: true,
                    companyId: 10_849_331,
                    companyName: "Sodexo @  Benedictine Univ.",
                    contactId: 27_321_291,
                    costCenter: nil,
                    createdDate: ~D[2015-05-05],
                    customJobDetails: [],
                    department: nil,
                    description: nil,
                    division: nil,
                    doubletimeBillRate: +0.0,
                    doubletimePayRate: nil,
                    employeeType: "Temporary",
                    endDate: ~D[2015-05-12],
                    endTimeLocal: nil,
                    enteredByUser: "noEmail@gmail.com",
                    enteredByUserId: 65_648_394,
                    estimatedHours: 32,
                    expenseType: "PaidAndBilled",
                    frontOfficeId: 37_275,
                    hasNoEndDate: false,
                    id: 38_870_859,
                    isArchived: false,
                    lastUpdatedDate: nil,
                    latestActivityDate: nil,
                    latestActivityName: nil,
                    link: "https://allteamstaffing.myavionte.com/app/#/job/38870859",
                    markupPercentage: 99.7,
                    maxBillRate: +0.0,
                    maxPayRate: +0.0,
                    minBillRate: +0.0,
                    minPayRate: +0.0,
                    notes: "<b>Job Description</b>: SODEXO @  BENEDICTINE UNIV.",
                    oT_Type: 2,
                    offer: false,
                    orderType: "Contract",
                    orderTypeId: 4,
                    origin: nil,
                    overtimeBillRate: +0.0,
                    overtimePayRate: +0.0,
                    overtimeRuleID: 2_851_819,
                    overtimeType: "PaidAndBilledOT",
                    ownerUserId: 65_648_394,
                    payPeriod: "Weekly",
                    payRates: %{"doubletime" => 20.0, "overtime" => 15.0, "regular" => 10.0},
                    pickList: false,
                    placed: 1,
                    placementFee: +0.0,
                    placementPercentage: +0.0,
                    poId: 0,
                    positionCategoryId: nil,
                    positions: 1,
                    postJobToMobileApp: false,
                    posted: false,
                    rateType: "HourlyRate",
                    representativeUsers: [65_648_394],
                    salesRepUser: "noEmail@gmail.com",
                    salesRepUserId: 65_648_394,
                    scheduleLengthWeeks: 0,
                    scheduleShifts: [],
                    shiftName: nil,
                    shiftScheduleDays: %{
                      "friday" => nil,
                      "monday" => nil,
                      "saturday" => nil,
                      "sunday" => nil,
                      "thursday" => nil,
                      "tuesday" => nil,
                      "wednesday" => nil
                    },
                    startDate: ~D[2015-05-06],
                    startOfWeek: "Monday",
                    startTimeLocal: nil,
                    status: "Completed",
                    statusId: 32_199,
                    targetBillRate: 19.97,
                    targetPayRate: 10.0,
                    title: "SODEXO @  BENEDICTINE UNIV.",
                    useCustomOTRates: true,
                    weekDuration: "MondayToSunday",
                    workerCompCode: %{
                      "id" => 634_888,
                      "wcCode" => "9082",
                      "wcCountry" => "United States of America",
                      "wcDescription" => "Restaurants - NOC",
                      "wcState" => "IL",
                      "wccodeID" => 0
                    },
                    workerCompCodeId: 634_888,
                    workersCompensationClassCode: "IL9082",
                    worksiteAddress: %{
                      "city" => "Lisle",
                      "country" => "US",
                      "county" => nil,
                      "geoCode" => "140431630",
                      "postalCode" => "60532",
                      "schoolDistrictCode" => nil,
                      "state_Province" => "IL",
                      "street1" => "5700 College Road",
                      "street2" => nil
                    },
                    worksiteAddressId: 8_298_820
                  }
                  | _tail
                ]} = Avionte.list_jobs("api_key", "bearer_token", "tenant", job_ids: [1, 2])
      end
    end

    test "returns an error tuple if the request fails with status code different than 200" do
      error = {:ok, %HTTPoison.Response{status_code: 400, body: Jason.encode!([]), request: %HTTPoison.Request{url: ""}}}

      with_mock HTTPoison,
        post: fn _url, _header, _body, _opts -> error end do
        assert {:error, error} == Avionte.list_jobs("api_key", "bearer_token", "tenant", job_ids: [1, 2])
      end
    end

    test "returns an error tuple if the request fails" do
      error = {:error, %HTTPoison.Error{reason: :timeout}}

      with_mock HTTPoison,
        post: fn _url, _header, _body, _opts -> error end do
        assert {:error, :timeout} == Avionte.list_jobs("api_key", "bearer_token", "tenant", job_ids: [1, 2])
      end
    end
  end

  describe "list_company_ids/4" do
    test "makes request to the correct endpoint with default page and page_zise" do
      with_mock HTTPoison,
        get: fn url, _header, _opts ->
          assert url == @list_company_ids_url <> "/1/50/"
          {:ok, %HTTPoison.Response{request: %HTTPoison.Request{url: url}}}
        end do
        Avionte.list_company_ids("api_key", "bearer_token", "tenant")
      end
    end

    test "if we pass it a limit and offset, it will be reflected in the request" do
      with_mock HTTPoison,
        get: fn url, _header, _opts ->
          assert url == @list_company_ids_url <> "/2/100/"
          {:ok, %HTTPoison.Response{request: %HTTPoison.Request{url: url}}}
        end do
        Avionte.list_company_ids("api_key", "bearer_token", "tenant", limit: 100, offset: 100)
      end
    end

    test "returns a list of company ids" do
      with_mock HTTPoison,
        get: fn _url, _header, _opts -> list_companies_ids_fixture() end do
        {:ok, result} = Avionte.list_company_ids("api_key", "bearer_token", "tenant")
        assert Enum.all?(result, &is_integer/1)
      end
    end

    test "returns an error tuple if the request fails with status code different than 200" do
      error =
        {:ok,
         %HTTPoison.Response{
           status_code: 400,
           body: Jason.encode!([]),
           request: %HTTPoison.Request{url: @list_company_ids_url}
         }}

      with_mock HTTPoison,
        get: fn _url, _header, _opts -> error end do
        assert {:error, error} == Avionte.list_company_ids("api_key", "bearer_token", "tenant")
      end
    end

    test "returns an error tuple if the request fails" do
      error = {:error, %HTTPoison.Error{reason: :timeout}}

      with_mock HTTPoison,
        get: fn _url, _header, _opts -> error end do
        assert {:error, :timeout} == Avionte.list_company_ids("api_key", "bearer_token", "tenant")
      end
    end
  end

  describe "list_companies/4" do
    test "makes request to the correct endpoint" do
      with_mock HTTPoison,
        post: fn url, _header, _body, _opts ->
          assert url == "https://api.avionte.com/front-office/v1/companies/multi-query"
          {:ok, %HTTPoison.Response{request: %HTTPoison.Request{url: url}}}
        end do
        Avionte.list_companies("api_key", "bearer_token", "tenant", company_ids: [1, 2, 3])
      end
    end

    test "returns a list of companies" do
      with_mock HTTPoison, post: fn _url, _header, _body, _opts -> list_companies_fixture() end do
        assert {:ok,
                [
                  %Sync.Clients.Avionte.Model.Company{
                    createdDate: ~D[2021-10-18],
                    frontOfficeId: 37_275,
                    id: 10_848_976,
                    isArchived: false,
                    lastUpdatedDate: nil,
                    latestActivityDate: nil,
                    latestActivityName: nil,
                    link: "https://allteamstaffing.myavionte.com/app/#/company/10848976",
                    origin: nil,
                    payPeriod: nil,
                    representativeUsers: [65_648_394],
                    status: "Active",
                    statusId: 20_338,
                    billingAddress: nil,
                    billingCycle: nil,
                    billingPeriod: nil,
                    fax: "7085881662",
                    industry: nil,
                    mainAddress: %Sync.Clients.Avionte.Model.Address{
                      city: "Lagrange",
                      country: "US",
                      county: "COOK",
                      geoCode: "140311490",
                      postalCode: "60525",
                      schoolDistrictCode: nil,
                      state_Province: "IL",
                      street1: "57 S Spring Ave",
                      street2: nil
                    },
                    name: "Mary Carrolle Dougherty",
                    openJobs: 0,
                    originRecordId: nil,
                    payCycle: nil,
                    phoneNumber: "7085880886",
                    statusType: nil,
                    webSite: nil,
                    weekEndDay: nil
                  }
                  | _tail
                ]} = Avionte.list_companies("api_key", "bearer_token", "tenant", company_ids: [1, 2])
      end
    end

    test "returns an error tuple if the request fails with status code different than 200" do
      error = {:ok, %HTTPoison.Response{status_code: 400, body: Jason.encode!([]), request: %HTTPoison.Request{url: ""}}}

      with_mock HTTPoison,
        post: fn _url, _header, _body, _opts -> error end do
        assert {:error, error} == Avionte.list_companies("api_key", "bearer_token", "tenant", company_ids: [1, 2])
      end
    end

    test "returns an error tuple if the request fails" do
      error = {:error, %HTTPoison.Error{reason: :timeout}}

      with_mock HTTPoison,
        post: fn _url, _header, _body, _opts -> error end do
        assert {:error, :timeout} == Avionte.list_companies("api_key", "bearer_token", "tenant", company_ids: [1, 2])
      end
    end
  end

  describe "create_contact_activity/4" do
    test "makes request to the correct endpoint" do
      with_mock HTTPoison,
        post: fn url, _header, _body, _opts ->
          assert url == "https://api.avionte.com/front-office/v1/contact/106494605/activity"
          {:ok, %HTTPoison.Response{}}
        end do
        Avionte.create_contact_activity("api_key", "bearer_token", "tenant",
          contact_id: 106_494_605,
          body: %{
            notes: "This is a test SMS message",
            typeId: -11
          }
        )
      end
    end

    test "returns a contact activity" do
      with_mock HTTPoison, post: fn _url, _header, _body, _opts -> create_contact_activity_fixture() end do
        assert {:ok,
                %ContactActivity{
                  activityDate: ~N[2024-05-14 14:54:43],
                  id: 1_447_491_470,
                  name: "Text Sent",
                  notes: "This is a test SMS message",
                  show_in: 1,
                  contactId: 106_494_605,
                  typeId: -11,
                  userId: 28_109_615
                }} =
                 Avionte.create_contact_activity("api_key", "bearer_token", "tenant",
                   contact_id: 106_494_605,
                   body: %{
                     notes: "This is a test SMS message",
                     typeId: -11
                   }
                 )
      end
    end

    test "returns an error tuple if the request fails with status code different than 200" do
      error = {:ok, %HTTPoison.Response{status_code: 400, body: Jason.encode!([])}}

      with_mock HTTPoison,
        post: fn _url, _header, _body, _opts -> error end do
        assert {:error, error} ==
                 Avionte.create_contact_activity("api_key", "bearer_token", "tenant",
                   contact_id: 106_494_605,
                   body: %{
                     notes: "This is a test SMS message",
                     typeId: -11
                   }
                 )
      end
    end

    test "returns an error tuple if the request fails due to timeout" do
      error = {:error, %HTTPoison.Error{reason: :timeout}}

      with_mock HTTPoison,
        post: fn _url, _header, _body, _opts -> error end do
        assert {:error, :timeout} ==
                 Avionte.create_contact_activity("api_key", "bearer_token", "tenant",
                   contact_id: 106_494_605,
                   body: %{
                     notes: "This is a test SMS message",
                     typeId: -11
                   }
                 )
      end
    end
  end
end
