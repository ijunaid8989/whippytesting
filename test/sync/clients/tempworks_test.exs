defmodule Sync.Clients.TempworksTest do
  use ExUnit.Case, async: false

  import Mock
  import Sync.Fixtures.TempworksClient

  alias Sync.Clients.Tempworks
  alias Sync.Clients.Tempworks.Model
  alias Sync.Clients.Tempworks.Model.Branch
  alias Sync.Utils.Http.Retry

  # We log an error when we get a non-success status code
  # and this tag captures the log so it does not clutter the test output
  @moduletag capture_log: true

  @list_assignments_endpoint "https://api.ontempworks.com/Search/Assignments"
  @list_branches_endpoint "https://api.ontempworks.com/Branches"
  @create_employee_endpoint "https://api.ontempworks.com/Employees"
  @list_employees_endpoint "https://api.ontempworks.com/Search/Employees"
  @webhooks_endpoint "https://webhooks-api.ontempworks.com/api/Subscriptions"
  @list_contacts_endpoint "https://api.ontempworks.com/Search/Contacts"

  # We mock the Retry module for all tests to enable testing error responses without delays
  setup_with_mocks([{Retry, [], [request: fn function, _opts -> function.() end]}]) do
    :ok
  end

  describe "list_assignments/2" do
    test "list_assignments will make a request to the correct tempworks endpoint" do
      with_mock HTTPoison,
        get: fn url, _header, _opts ->
          assert url == @list_assignments_endpoint
          {:ok, %HTTPoison.Response{}}
        end do
        Tempworks.list_assignments("api_key", limit: 5)
      end
    end

    test "if we pass it a limit, it will be received as a 'take' in the tempworks request" do
      with_mock HTTPoison,
        get: fn url, _header, opts ->
          assert url == @list_assignments_endpoint
          [params: params, recv_timeout: _] = opts
          assert Keyword.get(params, :take) == 5
          {:ok, %HTTPoison.Response{}}
        end do
        Tempworks.list_assignments("api_key", limit: 5)
      end
    end

    test "if we do not pass a limit, the default of 100 will be applied" do
      with_mock HTTPoison,
        get: fn url, _header, opts ->
          assert url == @list_assignments_endpoint
          [params: params, recv_timeout: _] = opts
          assert Keyword.get(params, :take) == 100
          {:ok, %HTTPoison.Response{}}
        end do
        Tempworks.list_assignments("api_key")
      end
    end

    test "if we apply an offset, tempworks request will receive a 'skip' instead" do
      with_mock HTTPoison,
        get: fn url, _header, opts ->
          assert url == @list_assignments_endpoint
          [params: params, recv_timeout: _] = opts
          assert Keyword.get(params, :skip) == 20
          {:ok, %HTTPoison.Response{}}
        end do
        Tempworks.list_assignments("api_key", offset: 20)
      end
    end

    test "if we do not pass an offset, the default of 0 will be applied" do
      with_mock HTTPoison,
        get: fn url, _header, opts ->
          assert url == @list_assignments_endpoint
          [params: params, recv_timeout: _] = opts
          assert Keyword.get(params, :skip) == 0
          {:ok, %HTTPoison.Response{}}
        end do
        Tempworks.list_assignments("api_key")
      end
    end

    test "if we pass is_active true or false, tempworks request will receive an 'isActive' instead" do
      with_mock HTTPoison,
        get: fn _url, _header, opts ->
          [params: params, recv_timeout: _] = opts
          assert Keyword.get(params, :isActive) == true
          {:ok, %HTTPoison.Response{}}
        end do
        Tempworks.list_assignments("api_key", is_active: true)
      end

      with_mock HTTPoison,
        get: fn _url, _header, opts ->
          [params: params, recv_timeout: _] = opts
          assert Keyword.get(params, :isActive) == false
          {:ok, %HTTPoison.Response{}}
        end do
        Tempworks.list_assignments("api_key", is_active: false)
      end
    end

    test "if we do not pass is_active in the params, it will be included in the request as null" do
      with_mock HTTPoison,
        get: fn _url, _header, opts ->
          [params: params, recv_timeout: _] = opts
          assert Keyword.get(params, :isActive) == nil
          {:ok, %HTTPoison.Response{}}
        end do
        Tempworks.list_assignments("api_key")
      end
    end

    test "if we get back a 200, we should receive the data and totalCount" do
      with_mock HTTPoison,
        get: fn
          _url, _header, _opts ->
            list_employee_assignments_fixture()
        end do
        {:ok, data} = Tempworks.list_assignments("api_key")
        %{assignments: assignments, total: 1} = data
        Enum.member?(assignments, %Model.EmployeeAssignment{assignmentId: 1})
      end
    end

    test "if we get back a non 200 status code, it counts as an error" do
      with_mock HTTPoison,
        get: fn
          _url, _header, _opts ->
            {:ok, %HTTPoison.Response{status_code: 202, body: %{}}}
        end do
        assert {:error, "HTTP error, status code: 202, body: %{}"} = Tempworks.list_assignments("api_key")
      end
    end
  end

  describe "get_assignment_custom_data/2" do
    test "if we make a request to get_assignment_custom_data, it will make the request to the correct tempworks endpoint" do
      with_mock HTTPoison,
        get: fn url, _header, _opts ->
          assert url == "https://api.ontempworks.com/Assignments/1234/CustomData"
          {:ok, %HTTPoison.Response{}}
        end do
        Tempworks.get_assignment_custom_data("api_key", 1234)
      end
    end

    test "if we receive a 200 response, we get an :ok tuple" do
      with_mock HTTPoison,
        get: fn _url, _header, _opts ->
          # both assignment and employee custom data have the same format
          get_employee_custom_data_fixture()
        end do
        {:ok, %{custom_data: custom_data, total: 3}} = Tempworks.get_assignment_custom_data("api_key", 1234)

        [custom_data_one, custom_data_two, custom_data_three] = Enum.sort_by(custom_data, & &1.propertyDefinitionId)

        assert %Model.CustomData{
                 propertyDefinitionId: "0d2a430b-1d99-4e1a-be50-63b41789bde5"
               } = custom_data_one

        assert %Model.CustomData{
                 propertyDefinitionId: "361b6e5a-abb1-4678-ba5c-60f5420c6029"
               } = custom_data_two

        assert %Model.CustomData{
                 propertyDefinitionId: "ff07e058-ac2d-44cf-aeec-ce495a5a7143"
               } = custom_data_three
      end
    end

    test "if we receive a valid Http response with a non-success status, we get an :error tuple" do
      with_mock HTTPoison,
        get: fn _url, _header, _opts ->
          {:ok, %HTTPoison.Response{status_code: 400, body: %{}}}
        end do
        assert {:error, "HTTP error, status code: 400, body: %{}"} = Tempworks.get_assignment_custom_data("api_key", 1234)
      end
    end
  end

  describe "list_branches/2" do
    test "list_branches will make a request to the correct tempworks endpoint" do
      with_mock HTTPoison,
        get: fn url, _header, _opts ->
          assert url == @list_branches_endpoint
          {:ok, %HTTPoison.Response{}}
        end do
        Tempworks.list_branches("api_key", limit: 5)
      end
    end

    test "if we pass it a limit, it will be received as a 'take' in the tempworks request" do
      with_mock HTTPoison,
        get: fn url, _header, opts ->
          assert url == @list_branches_endpoint
          [params: params, recv_timeout: _] = opts
          assert Keyword.get(params, :take) == 5
          {:ok, %HTTPoison.Response{}}
        end do
        Tempworks.list_branches("api_key", limit: 5)
      end
    end

    test "if we do not pass a limit, the default of 10 will be applied" do
      with_mock HTTPoison,
        get: fn _url, _header, opts ->
          [params: params, recv_timeout: _] = opts
          assert Keyword.get(params, :take) == 10
          {:ok, %HTTPoison.Response{}}
        end do
        Tempworks.list_branches("api_key")
      end
    end

    test "if we apply an offset, tempworks request will receive a 'skip' instead" do
      with_mock HTTPoison,
        get: fn _url, _header, opts ->
          [params: params, recv_timeout: _] = opts
          assert Keyword.get(params, :skip) == 20
          {:ok, %HTTPoison.Response{}}
        end do
        Tempworks.list_branches("api_key", offset: 20)
      end
    end

    test "if we do not pass an offset, the default of 0 will be applied" do
      with_mock HTTPoison,
        get: fn _url, _header, opts ->
          [params: params, recv_timeout: _] = opts
          assert Keyword.get(params, :skip) == 0
          {:ok, %HTTPoison.Response{}}
        end do
        Tempworks.list_branches("api_key")
      end
    end

    test "if we get back a 200, we should receive the data and totalCount" do
      with_mock HTTPoison,
        get: fn
          _url, _header, _opts ->
            list_branches_fixture()
        end do
        # the fixture returns two elements where the branch id is 1 and 2
        {:ok, data} = Tempworks.list_branches("api_key")
        %{branches: branches, total: 2} = data
        Enum.member?(branches, %Branch{branchId: 1})
        Enum.member?(branches, %Branch{branchId: 2})
      end
    end

    test "if we get back a non 200 status code, it counts as an error" do
      with_mock HTTPoison,
        get: fn
          _url, _header, _opts ->
            {:ok, %HTTPoison.Response{status_code: 202, body: %{}}}
        end do
        assert {:error, "HTTP error, status code: 202, body: %{}"} = Tempworks.list_branches("api_key")
      end
    end
  end

  describe "list_employees/2" do
    test "if we make a request to list_employees, it will make the request to the correct tempworks endpoint" do
      with_mock HTTPoison,
        get: fn url, _header, _opts ->
          assert url == @list_employees_endpoint
          {:ok, %HTTPoison.Response{request: %HTTPoison.Request{url: ""}}}
        end do
        Tempworks.list_employees("api_key")
      end
    end

    test "if we pass it a limit, it will be received as a 'take' in the tempworks request" do
      with_mock HTTPoison,
        get: fn _url, _header, opts ->
          [params: params, recv_timeout: _] = opts
          assert Keyword.get(params, :take) == 5
          {:ok, %HTTPoison.Response{request: %HTTPoison.Request{url: ""}}}
        end do
        Tempworks.list_employees("api_key", limit: 5)
      end
    end

    test "if we do not pass a limit, the default of 10 will be applied" do
      with_mock HTTPoison,
        get: fn _url, _header, opts ->
          [params: params, recv_timeout: _] = opts
          assert Keyword.get(params, :take) == 10
          {:ok, %HTTPoison.Response{request: %HTTPoison.Request{url: ""}}}
        end do
        Tempworks.list_employees("api_key")
      end
    end

    test "if we apply an offset, tempworks request will receive a 'skip' instead" do
      with_mock HTTPoison,
        get: fn _url, _header, opts ->
          [params: params, recv_timeout: _] = opts
          assert Keyword.get(params, :skip) == 20
          {:ok, %HTTPoison.Response{request: %HTTPoison.Request{url: ""}}}
        end do
        Tempworks.list_employees("api_key", offset: 20)
      end
    end

    test "if we do not pass an offset, the default of 0 will be applied" do
      with_mock HTTPoison,
        get: fn _url, _header, opts ->
          [params: params, recv_timeout: _] = opts
          assert Keyword.get(params, :skip) == 0
          {:ok, %HTTPoison.Response{request: %HTTPoison.Request{url: ""}}}
        end do
        Tempworks.list_employees("api_key")
      end
    end

    test "if we get back a 200, we should receive the data and totalCount" do
      with_mock HTTPoison,
        get: fn
          _url, _header, _opts ->
            list_employees_fixture()
        end do
        {:ok, data} = Tempworks.list_employees("api_key")
        assert %{employees: employees, total: 2} = data
        sorted = Enum.sort_by(employees, & &1.external_contact_id)

        assert [
                 %{external_contact_id: "12", external_contact: _external_contact},
                 %{external_contact_id: "13", external_contact: _external_contact_two}
               ] = sorted
      end
    end

    test "if we get back a non-success status code, it counts as an error" do
      with_mock HTTPoison,
        get: fn
          _url, _header, _opts ->
            {:ok, %HTTPoison.Response{status_code: 400, body: %{}, request: %HTTPoison.Request{url: ""}}}
        end do
        assert {:error, "HTTP error, status code: 400, body: %{}"} = Tempworks.list_employees("api_key")
      end
    end
  end

  describe "list_contacts/2" do
    test "if we make a request to list_contacts, it will make the request to the correct tempworks endpoint" do
      with_mock HTTPoison,
        get: fn url, _header, _opts ->
          assert url == @list_contacts_endpoint
          {:ok, %HTTPoison.Response{request: %HTTPoison.Request{url: ""}}}
        end do
        Tempworks.list_contacts("api_key")
      end
    end

    test "if we pass it a limit, it will be received as a 'take' in the tempworks request" do
      with_mock HTTPoison,
        get: fn _url, _header, opts ->
          [params: params, recv_timeout: _] = opts
          assert Keyword.get(params, :take) == 5
          {:ok, %HTTPoison.Response{request: %HTTPoison.Request{url: ""}}}
        end do
        Tempworks.list_contacts("api_key", limit: 5)
      end
    end

    test "if we do not pass a limit, the default of 10 will be applied" do
      with_mock HTTPoison,
        get: fn _url, _header, opts ->
          [params: params, recv_timeout: _] = opts
          assert Keyword.get(params, :take) == 10
          {:ok, %HTTPoison.Response{request: %HTTPoison.Request{url: ""}}}
        end do
        Tempworks.list_contacts("api_key")
      end
    end

    test "if we apply an offset, tempworks request will receive a 'skip' instead" do
      with_mock HTTPoison,
        get: fn _url, _header, opts ->
          [params: params, recv_timeout: _] = opts
          assert Keyword.get(params, :skip) == 20
          {:ok, %HTTPoison.Response{request: %HTTPoison.Request{url: ""}}}
        end do
        Tempworks.list_contacts("api_key", offset: 20)
      end
    end

    test "if we do not pass an offset, the default of 0 will be applied" do
      with_mock HTTPoison,
        get: fn _url, _header, opts ->
          [params: params, recv_timeout: _] = opts
          assert Keyword.get(params, :skip) == 0
          {:ok, %HTTPoison.Response{request: %HTTPoison.Request{url: ""}}}
        end do
        Tempworks.list_contacts("api_key")
      end
    end

    test "if we get back a 200, we should receive the data and totalCount" do
      with_mock HTTPoison,
        get: fn
          _url, _header, _opts ->
            list_contacts_fixture()
        end do
        {:ok, data} = Tempworks.list_contacts("api_key")
        assert %{contacts: contacts, total: 2} = data
        sorted = Enum.sort_by(contacts, & &1.external_contact_id)

        assert [
                 %{external_contact_id: "contact-12", external_contact: _external_contact},
                 %{external_contact_id: "contact-56", external_contact: _external_contact_two}
               ] = sorted
      end
    end

    test "if we get back a non-success status code, it counts as an error" do
      with_mock HTTPoison,
        get: fn
          _url, _header, _opts ->
            {:ok, %HTTPoison.Response{status_code: 400, body: %{}, request: %HTTPoison.Request{url: ""}}}
        end do
        assert {:error, "HTTP error, status code: 400, body: %{}"} = Tempworks.list_contacts("api_key")
      end
    end
  end

  describe "get_employee/2" do
    test "a request will go to the correct tempworks endpoint" do
      user_id = 12_000

      with_mock HTTPoison,
        get: fn url, _header ->
          assert url == get_employee_endpoint(user_id)
          {:ok, %HTTPoison.Response{}}
        end do
        Tempworks.get_employee("api_key", user_id)
      end
    end

    test "if we get back a 200, we should receive an ok tuple with an employee struct with a nested address struct" do
      with_mock HTTPoison,
        get: fn
          _url, _header ->
            get_employee_fixture()
        end do
        # the fixture returns two elements where the branch id is 1 and 2
        {:ok, employee} = Tempworks.get_employee("api_key", 20_000)
        assert %Model.EmployeeDetail{address: address} = employee
        assert %Model.Address{} = address
      end
    end

    test "we should receive an ok tuple with an employee eeo struct" do
      with_mock HTTPoison,
        get: fn
          _url, _header ->
            get_employee_eeo_fixture()
        end do
        {:ok, employee} = Tempworks.get_employee_eeo("api_key", 20_000)
        assert %Model.EmployeeEeoDetail{dateOfBirth: _date_of_birth} = employee
      end
    end

    test "we should receive an ok tuple with an employee eeo struct from endpoint" do
      with_mock HTTPoison,
        get: fn url, _header ->
          assert url == get_employee_eeo_endpoint(20_000)
          {:ok, %HTTPoison.Response{}}
        end do
        Tempworks.get_employee_eeo("api_key", 20_000)
      end
    end

    test "if we get back a valid HTTP Response but with a non-success status code, it counts as an error" do
      with_mock HTTPoison,
        get: fn
          _url, _header ->
            {:ok, %HTTPoison.Response{status_code: 400, body: %{}}}
        end do
        assert {:error, "HTTP error, status code: 400, body: %{}"} = Tempworks.get_employee("api_key", 1200)
      end
    end
  end

  describe "get_employee_custom_data/2" do
    test "if we make a request to get_employee_custom_data, it will make the request to the correct tempworks endpoint" do
      user_id = 12_000

      with_mock HTTPoison,
        get: fn url, _header, _opts ->
          assert url == get_employee_custom_data_endpoint(user_id)
          {:ok, %HTTPoison.Response{}}
        end do
        Tempworks.get_employee_custom_data("api_key", user_id)
      end
    end

    test "if we receive a 200 response, we get an :ok tuple" do
      user_id = 12_000

      with_mock HTTPoison,
        get: fn _url, _header, _opts ->
          get_employee_custom_data_fixture()
        end do
        {:ok, %{custom_data: custom_data, total: 3}} = Tempworks.get_employee_custom_data("api_key", user_id)

        [custom_data_one, custom_data_two, custom_data_three] = Enum.sort_by(custom_data, & &1.propertyDefinitionId)

        assert %Model.CustomData{
                 propertyDefinitionId: "0d2a430b-1d99-4e1a-be50-63b41789bde5"
               } = custom_data_one

        assert %Model.CustomData{
                 propertyDefinitionId: "361b6e5a-abb1-4678-ba5c-60f5420c6029"
               } = custom_data_two

        assert %Model.CustomData{
                 propertyDefinitionId: "ff07e058-ac2d-44cf-aeec-ce495a5a7143"
               } = custom_data_three
      end
    end

    test "if we receive a valid Http response with a non-success status, we get an :error tuple" do
      user_id = 12_000

      with_mock HTTPoison,
        get: fn _url, _header, _opts ->
          {:ok, %HTTPoison.Response{status_code: 400, body: %{}, request: %HTTPoison.Request{url: ""}}}
        end do
        assert {:error, "HTTP error, status code: 400, body: %{}"} =
                 Tempworks.get_employee_custom_data("api_key", user_id)
      end
    end
  end

  describe "create_employee/2" do
    test "if we make a request to get_employee_custom_data, it will make the request to the correct tempworks endpoint" do
      with_mock HTTPoison,
        post: fn url, _body, _headers, _opts ->
          assert url == @create_employee_endpoint
          {:ok, %HTTPoison.Response{}}
        end do
        Tempworks.create_employee("api_key", %{})
      end
    end

    test "if we receive a 201 response, we get an :ok tuple" do
      with_mock HTTPoison,
        post: fn _url, _body, _headers, _opts ->
          create_employee_response_fixture()
        end do
        {:ok, %{"employeeId" => 1234}} = Tempworks.create_employee("api_key", %{})
      end
    end
  end

  describe "create_employee_message/4" do
    test "if we make a request to create_employee_message, it will make the request to the correct tempworks endpoint" do
      with_mock HTTPoison,
        post: fn url, _body, _headers, _opts ->
          assert url == "https://api.ontempworks.com/Employees/1234/messages"
          {:ok, %HTTPoison.Response{}}
        end do
        Tempworks.create_employee_message("api_key", "1234", 1, "message")
      end
    end

    test "if we receive a 201 response, we get an :ok tuple" do
      with_mock HTTPoison,
        post: fn _url, _body, _headers, _opts ->
          create_employee_message_response_fixture()
        end do
        {:ok, %{"messageId" => 1234}} = Tempworks.create_employee_message("api_key", 1234, 1, "message")
      end
    end

    test "if we receive a valid Http response with a non-success status, we get an :error tuple" do
      with_mock HTTPoison,
        post: fn _url, _body, _headers, _opts ->
          {:ok, %HTTPoison.Response{status_code: 400, body: %{}}}
        end do
        assert {:error, "HTTP error, status code: 400, body: %{}"} =
                 Tempworks.create_employee_message("api_key", 1234, 1, "message")
      end
    end
  end

  describe "list_message_actions/2" do
    test "if we make a request to list_message_actions, it will make the request to the correct tempworks endpoint" do
      with_mock HTTPoison,
        get: fn url, _header, _opts ->
          assert url == "https://api.ontempworks.com/DataLists/messageActions"
          {:ok, %HTTPoison.Response{}}
        end do
        Tempworks.list_message_actions("api_key")
      end
    end

    test "if we receive a 200 response, we get an :ok tuple" do
      with_mock HTTPoison,
        get: fn _url, _header, _opts ->
          list_message_actions_fixture()
        end do
        {:ok, %{message_actions: message_actions}} = Tempworks.list_message_actions("api_key")

        assert [
                 %{name: "1st Interview w/ client", activity_type_id: 1},
                 %{name: "1st Recruiting Call", activity_type_id: 2},
                 %{name: "Absence", activity_type_id: 3},
                 %{name: "Absent (Sick)", activity_type_id: 4},
                 %{name: "Accepted", activity_type_id: 5}
               ] = message_actions
      end
    end

    test "if we receive a valid Http response with a non success status, we get an :error tuple" do
      with_mock HTTPoison,
        get: fn _url, _header, _opts ->
          {:ok, %HTTPoison.Response{status_code: 400, body: %{}}}
        end do
        assert {:error, "HTTP error, status code: 400, body: %{}"} = Tempworks.list_message_actions("api_key")
      end
    end
  end

  describe "list_employee_assignments/1" do
    test "if we make a request to list_employee_assignments, it will make the request to the correct tempworks endpoint" do
      with_mock HTTPoison,
        get: fn url, _header, _opts ->
          assert url == "https://api.ontempworks.com/Employees/1234/assignments"
          {:ok, %HTTPoison.Response{}}
        end do
        Tempworks.list_employee_assignments("api_key", 1234)
      end
    end

    test "if we receive a 200 response, we get an :ok tuple" do
      with_mock HTTPoison,
        get: fn _url, _header, _opts ->
          list_employee_assignments_fixture()
        end do
        {:ok,
         %{
           assignments: [
             %Sync.Clients.Tempworks.Model.EmployeeAssignment{
               assignmentId: 1,
               branchId: 1030,
               employeeId: 1234,
               activeStatus: 0,
               assignmentStatus: "string",
               assignmentStatusId: 0,
               billRate: 0,
               branchName: "WhippyDemoBranch",
               customerId: 1,
               customerName: "WhippyDemoCustomer",
               departmentName: "WhippyDemoDepartment",
               employeePrimaryEmailAddress: "",
               employeePrimaryPhoneNumber: "32324249459",
               endDate: "2024-07-15T16:33:56.124Z",
               expectedEndDate: "2024-07-15T16:33:56.124Z",
               firstName: "John",
               isActive: true,
               isDeleted: false,
               isTimeclockOrder: true,
               jobOrderId: 1,
               jobTitle: "WhippyDemoJobTitle",
               lastName: "Doe",
               middleName: nil,
               originalStartDate: "2024-07-15T16:33:56.124Z",
               payRate: 0,
               performanceNote: "string",
               serviceRep: "some-user",
               startDate: "2024-07-15T16:33:56.124Z",
               supervisor: "WhippyDemoSupervisor",
               supervisorContactInfo: "WhippyDemoSupervisorContactInfo",
               supervisorId: 1
             }
           ],
           total: 1
         }} = Tempworks.list_employee_assignments("api_key", 1234)
      end
    end

    test "if we receive a valid Http response with a non-success status, we get an :error tuple" do
      with_mock HTTPoison,
        get: fn _url, _header, _opts ->
          {:ok, %HTTPoison.Response{status_code: 400, body: %{}}}
        end do
        assert {:error, "HTTP error, status code: 400, body: %{}"} = Tempworks.list_employee_assignments("api_key", 1234)
      end
    end
  end

  test "if we receive a http error response, we get an :error tuple" do
    with_mock HTTPoison,
      get: fn _url, _header, _opts ->
        {:error, %HTTPoison.Error{reason: :econnrefused}}
      end do
      assert {:error, %HTTPoison.Error{reason: :econnrefused}} = Tempworks.list_message_actions("api_key")
    end
  end

  describe "list_subscriptions/2" do
    test "if we make a request to get_employee_custom_data, it will make the request to the correct tempworks endpoint" do
      with_mock HTTPoison,
        get: fn url, _headers, _opts ->
          assert url == @webhooks_endpoint
          {:ok, %HTTPoison.Response{}}
        end do
        Tempworks.list_subscriptions("api_key")
      end
    end

    test "if we receive a 200 response, we get an :ok tuple" do
      with_mock HTTPoison,
        get: fn _url, _headers, _opts ->
          list_subscriptions_response_fixture()
        end do
        assert {:ok, [%{"subscriptionId" => 13}]} = Tempworks.list_subscriptions("api_key")
      end
    end
  end

  describe "Universal Phone and Email" do
    test "if we make a request to get universal phone with country code, it will make the request to the correct tempworks endpoint" do
      phone = "17862672753"

      with_mock HTTPoison,
        get: fn url, _header ->
          assert url == get_universal_phone_endpoint(phone)
          {:ok, %HTTPoison.Response{}}
        end do
        Tempworks.get_employee_universal_phone("api_key", phone)
      end
    end

    test "if we make a request to get universal phone without country code, it will make the request to the correct tempworks endpoint" do
      phone = "7862672753"

      with_mock HTTPoison,
        get: fn url, _header ->
          assert url == get_universal_phone_endpoint(phone)
          {:ok, %HTTPoison.Response{}}
        end do
        Tempworks.get_employee_universal_phone("api_key", phone)
      end
    end

    test "if we receive a 200 response, we get an :ok tuple" do
      with_mock HTTPoison,
        get: fn _url, _header ->
          list_universal_phone_fixture()
        end do
        {:ok, _universal_phone} = Tempworks.get_employee_universal_phone("api_key", "17862672753")
      end
    end

    test "if we receive a valid Http response with a non success status, we get an :error tuple" do
      with_mock HTTPoison,
        get: fn _url, _header ->
          {:ok, %HTTPoison.Response{status_code: 400, body: %{}}}
        end do
        assert {:error, "HTTP error, status code: 400, body: %{}"} =
                 Tempworks.get_employee_universal_phone("api_key", "17862672753")
      end
    end

    test "if we make a request to get universal email, it will make the request to the correct tempworks endpoint" do
      email = "jack@whippy.co"

      with_mock HTTPoison,
        get: fn url, _header ->
          assert url == get_universal_email_endpoint(email)
          {:ok, %HTTPoison.Response{}}
        end do
        Tempworks.get_employee_universal_email("api_key", email)
      end
    end

    test "if we receive a 200 response, we get an :ok tuple for universal email" do
      with_mock HTTPoison,
        get: fn _url, _header ->
          list_universal_email_fixture()
        end do
        {:ok, _universal_email} = Tempworks.get_employee_universal_email("api_key", "jack@whippy.co")
      end
    end

    test "if we receive a valid Http response with a non success status, we get an :error tuple for email" do
      with_mock HTTPoison,
        get: fn _url, _header ->
          {:ok, %HTTPoison.Response{status_code: 400, body: %{}}}
        end do
        assert {:error, "HTTP error, status code: 400, body: %{}"} =
                 Tempworks.get_employee_universal_email("api_key", "jack@whippy.co")
      end
    end
  end

  defp get_employee_endpoint(id), do: "https://api.ontempworks.com/Employees/#{id}"

  defp get_employee_custom_data_endpoint(id), do: "https://api.ontempworks.com/Employees/#{id}/CustomData"

  defp get_universal_phone_endpoint(phone), do: "https://api.ontempworks.com/Search/UniversalPhone/?phone=#{phone}"

  defp get_universal_email_endpoint(email), do: "https://api.ontempworks.com/Search/UniversalEmail/?emailAddress=#{email}"

  defp get_employee_eeo_endpoint(id), do: "https://api.ontempworks.com/Employees/#{id}/eeo"
end
