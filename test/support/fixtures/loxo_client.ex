defmodule Sync.Fixtures.LoxoClient do
  @moduledoc false

  @person_id 166_640_410

  def list_activity_types_fixture do
    body = [
      %{
        "id" => 1_676_385,
        "key" => "marked_as_maybe",
        "name" => "Marked as Maybe",
        "position" => nil,
        "children" => [],
        "hidden" => false
      },
      %{
        "id" => 1_676_386,
        "key" => "marked_as_yes",
        "name" => "Marked as Yes",
        "position" => nil,
        "children" => [],
        "hidden" => false
      },
      %{
        "id" => 1_676_387,
        "key" => "longlisted",
        "name" => "Longlisted",
        "position" => nil,
        "children" => [],
        "hidden" => false
      },
      %{
        "id" => 1_676_388,
        "key" => "general_note",
        "name" => "Note Update",
        "position" => nil,
        "children" => [],
        "hidden" => false
      },
      %{
        "id" => 1_676_389,
        "key" => "sent_automated_email",
        "name" => "Sent Automated Email",
        "position" => nil,
        "children" => [],
        "hidden" => false
      }
    ]

    {:ok,
     %HTTPoison.Response{
       body: Jason.encode!(body),
       status_code: 200
     }}
  end

  def list_users_fixture do
    body = [
      %{
        "name" => "Timothy Cooked",
        "id" => 150_101,
        "email" => "tim@apple.com",
        "created_at" => "2021-06-24T13:39:13.152Z",
        "updated_at" => "2024-07-16T15:31:03.318Z",
        "avatar_thumb_url" => "/profile_pictures/thumb/missing.png",
        "twilio_phone_number" => nil
      }
    ]

    {:ok,
     %HTTPoison.Response{
       body: Jason.encode!(body),
       status_code: 200
     }}
  end

  def list_people_fixture do
    body = %{
      # set to nil to prevent pagination, if its set to a string - it will paginate
      "scroll_id" => nil,
      "people" => [
        %{
          "id" => @person_id,
          "name" => "Adriana Weber",
          "profile_picture_thumb_url" => "/profile_pictures/thumb/missing.png",
          "location" => nil,
          "address" => nil,
          "city" => nil,
          "state" => nil,
          "zip" => nil,
          "country" => nil,
          "current_title" => nil,
          "current_company" => nil,
          "current_compensation" => nil,
          "compensation" => nil,
          "compensation_notes" => nil,
          "compensation_currency_id" => nil,
          "salary" => nil,
          "salary_type_id" => nil,
          "bonus_payment_type_id" => nil,
          "bonus_type_id" => nil,
          "bonus" => nil,
          "equity_type_id" => nil,
          "equity" => nil,
          "person_types" => [
            %{
              "id" => 84_390,
              "name" => "Candidate"
            }
          ],
          "owned_by_id" => nil,
          "created_at" => "2024-07-15T16:28:19.935Z",
          "updated_at" => "2024-07-16T14:18:21.985Z",
          "created_by_id" => nil,
          "updated_by_id" => nil,
          "emails" => [
            %{
              "id" => 150_242_154,
              "value" => "tyler.adams@kihn.name",
              "email_type_id" => 118_853
            }
          ],
          "phones" => [
            %{
              "id" => 134_031_228,
              "value" => "+18165333338",
              "phone_type_id" => 144_403
            }
          ],
          "blocked" => false,
          "blocked_until" => nil,
          "list_ids" => [],
          "candidate_jobs" => [],
          "linkedin_url" => "https://www.linkedin.com/search/results/people/?keywords=Adriana+Weber",
          "person_global_status" => nil,
          "all_raw_tags" => "",
          "skillsets" => nil,
          "source_type" => %{
            "id" => 1_392_041,
            "name" => "API"
          }
        }
      ]
    }

    {:ok,
     %HTTPoison.Response{
       body: Jason.encode!(body),
       status_code: 200
     }}
  end

  def create_person_fixture do
    body = %{
      "person" => %{
        "id" => @person_id,
        "name" => "John Doe",
        "profile_picture_thumb_url" => "/profile_pictures/thumb/missing.png",
        "location" => nil,
        "address" => nil,
        "city" => nil,
        "state" => nil,
        "zip" => nil,
        "country" => nil,
        "current_title" => nil,
        "current_company" => nil,
        "current_compensation" => nil,
        "compensation" => nil,
        "compensation_notes" => nil,
        "compensation_currency_id" => nil,
        "salary" => nil,
        "salary_type_id" => nil,
        "bonus_payment_type_id" => nil,
        "bonus_type_id" => nil,
        "bonus" => nil,
        "equity_type_id" => nil,
        "equity" => nil,
        "person_types" => [
          %{
            "id" => 84_391,
            "name" => "Candidate"
          }
        ],
        "owned_by_id" => nil,
        "created_at" => "2024-07-15T16:28:19.935Z",
        "updated_at" => "2024-07-16T14:18:21.985Z",
        "created_by_id" => nil,
        "updated_by_id" => nil,
        "emails" => [
          %{
            "id" => 150_242_155,
            "value" => "john.doe@example.com",
            "email_type_id" => 118_853
          }
        ],
        "phones" => [
          %{
            "id" => 134_031_229,
            "value" => "+18165333339",
            "phone_type_id" => 144_403
          }
        ],
        "blocked" => false,
        "blocked_until" => nil,
        "list_ids" => [],
        "candidate_jobs" => [],
        "linkedin_url" => "https://www.linkedin.com/search/results/people/?keywords=John+Doe",
        "person_global_status" => nil,
        "all_raw_tags" => "",
        "skillsets" => nil,
        "source_type" => %{
          "id" => 1_392_042,
          "name" => "API"
        }
      }
    }

    {:ok,
     %HTTPoison.Response{
       body: Jason.encode!(body),
       status_code: 201
     }}
  end

  def create_person_event_fixture do
    body = %{
      "person_event" => %{
        "id" => 822_112_904,
        "notes" => "Crafting vivid tapestries that reflect the kaleidoscope of human imagination",
        "pinned" => false,
        "person_id" => @person_id,
        "activity_type_id" => 1_676_392,
        "job_id" => nil,
        "company_id" => nil,
        "created_at" => "2024-07-05T10:37:16.137Z",
        "created_by_id" => nil,
        "updated_at" => "2024-07-05T11:00:50.597Z",
        "updated_by_id" => nil,
        "documents" => []
      },
      "errors" => []
    }

    {:ok,
     %HTTPoison.Response{
       body: Jason.encode!(body),
       status_code: 201
     }}
  end
end
