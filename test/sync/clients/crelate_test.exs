defmodule Sync.Clients.CrelateTest do
  use ExUnit.Case, async: false

  import Mock
  import Sync.Fixtures.CrelateClient

  alias Sync.Clients.Crelate
  alias Sync.Utils.Http.Retry

  # We log an error when we get a non-success status code
  # and this tag captures the log so it does not clutter the test output
  @moduletag capture_log: true
  @initial_limit 100
  @offset 0

  @get_contacts_endpoint "https://sandbox.crelate.com/api3/contacts?api_key=sx9fgdr8c7gn4tdpyds1fmfybo&"

  # We mock the Retry module for all tests to enable testing error responses without delays
  setup_with_mocks([{Retry, [], [request: fn function, _opts -> function.() end]}]) do
    :ok
  end

  describe "get_contacts/1" do
    test "get_contacts will make a request to the correct crelate endpoint" do
      with_mock HTTPoison,
        get: fn url, _headers, _opts ->
          assert url == @get_contacts_endpoint
          {:ok, %HTTPoison.Response{request: %HTTPoison.Request{url: url}}}
        end do
        Crelate.get_contacts("sx9fgdr8c7gn4tdpyds1fmfybo", limit: @initial_limit, offset: @offset, url_mode: false)
      end
    end

    test "returns a list of contacts" do
      with_mock HTTPoison,
        get: fn _url, _headers, _opts -> list_contacts_fixture() end do
        Crelate.get_contacts("sx9fgdr8c7gn4tdpyds1fmfybo", limit: @initial_limit, offset: @offset, url_mode: false)
      end
    end

    test "returns an error tuple if the request fails with status code different than 200" do
      error =
        {:ok,
         %HTTPoison.Response{
           status_code: 400,
           body: Jason.encode!([]),
           request: %HTTPoison.Request{url: @get_contacts_endpoint}
         }}

      with_mock HTTPoison,
        get: fn _url, _headers, _opts -> error end do
        assert {:error, _error} =
                 Crelate.get_contacts("sx9fgdr8c7gn4tdpyds1fmfybo",
                   limit: @initial_limit,
                   offset: @offset,
                   url_mode: false
                 )
      end
    end

    test "returns an error tuple if the request fails" do
      error = {:error, %HTTPoison.Error{reason: :timeout}}

      with_mock HTTPoison,
        get: fn _url, _headers, _opts -> error end do
        assert {:error, %HTTPoison.Error{reason: :timeout}} ==
                 Crelate.get_contacts("sx9fgdr8c7gn4tdpyds1fmfybo",
                   limit: @initial_limit,
                   offset: @offset,
                   url_mode: false
                 )
      end
    end
  end

  describe "push_contact/2" do
    test "push_contacts will make a request to the correct crelate endpoint" do
      with_mock HTTPoison,
        post: fn _url, _body, _opts ->
          create_contact_response_fixture()
        end do
        Crelate.create_contact(%{}, "sx9fgdr8c7gn4tdpyds1fmfybo", false)
      end
    end

    test "push bulk contacts will make a request to the correct crelate endpoint" do
      with_mock HTTPoison,
        post: fn _url, _body, _opts ->
          create_bulk_contacts_response_fixture()
        end do
        Crelate.create_bulk_contacts(%{}, "sx9fgdr8c7gn4tdpyds1fmfybo", false)
      end
    end
  end
end
