defmodule Sync.Clients.Hubspot.Parser do
  @moduledoc false
  alias Sync.Utils.Format.StringUtil

  require Logger

  @communication_assoc_id 81
  @communication_company_assoc_id 87
  @email_assoc_id 198
  @email_company_assoc_id 186
  @note_assoc_id 202
  @note_company_assoc_id 190
  @call_assoc_id 194
  @call_company_assoc_id 182

  def parse(:hubspot_owner, owner) do
    %{
      email: Map.get(owner, "email", nil),
      name:
        (Map.get(owner, "firstname", "") ||
           "") <>
          " " <> (Map.get(owner, "lastname", "") || ""),
      external_user: owner,
      external_user_id: owner["id"],
      external_id: owner["id"]
    }
  end

  def parse(:whippy_contact, contact) do
    [first_name, last_name] = StringUtil.parse_contact_name(contact.name)

    %{
      properties: %{
        firstname: first_name,
        lastname: last_name,
        phone: contact.phone,
        email: contact.email
      }
    }
  end

  def parse(:hubspot_contact, contact) do
    %{
      email: Map.get(contact["properties"], "email", nil),
      phone: Map.get(contact["properties"], "phone", nil),
      name:
        (Map.get(contact["properties"], "firstname", "") ||
           "") <>
          " " <> (Map.get(contact["properties"], "lastname", "") || ""),
      external_contact: contact,
      external_organization_entity_type: "contact",
      external_contact_id: contact["id"],
      external_id: contact["id"]
    }
  end

  def parse(:whippy_api_contact, contact) do
    %{
      email: contact.email,
      phone: contact.phone,
      name: contact.name,
      integration_id: contact.integration_id,
      external_id: contact.external_contact_id
    }
  end

  def parse(:sms, message) do
    associations = [
      %{
        "types" => [
          %{
            "associationCategory" => "HUBSPOT_DEFINED",
            "associationTypeId" => @communication_assoc_id
          }
        ],
        "to" => %{
          "id" => message.external_contact_id
        }
      }
    ]

    associations =
      if is_nil(message.company_id) do
        associations
      else
        associations ++
          [
            %{
              "types" => [
                %{
                  "associationCategory" => "HUBSPOT_DEFINED",
                  "associationTypeId" => @communication_company_assoc_id
                }
              ],
              "to" => %{
                "id" => message.company_id
              }
            }
          ]
      end

    %{
      "associations" => associations,
      "properties" => %{
        "hs_communication_channel_type" => "SMS",
        "hs_communication_logged_from" => "CRM",
        "hs_communication_body" => nl2br(message.whippy_activity["body"]),
        "hs_timestamp" => message.whippy_activity["inserted_at"],
        "hubspot_owner_id" => message.external_user_id
      }
    }
  end

  def parse(:whatsapp, message) do
    associations = [
      %{
        "types" => [
          %{
            "associationCategory" => "HUBSPOT_DEFINED",
            "associationTypeId" => @communication_assoc_id
          }
        ],
        "to" => %{
          "id" => message.external_contact_id
        }
      }
    ]

    associations =
      if is_nil(message.company_id) do
        associations
      else
        associations ++
          [
            %{
              "types" => [
                %{
                  "associationCategory" => "HUBSPOT_DEFINED",
                  "associationTypeId" => @communication_company_assoc_id
                }
              ],
              "to" => %{
                "id" => message.company_id
              }
            }
          ]
      end

    %{
      "associations" => associations,
      "properties" => %{
        "hs_communication_channel_type" => "WHATS_APP",
        "hs_communication_logged_from" => "CRM",
        "hs_communication_body" => nl2br(message.whippy_activity["body"]),
        "hs_timestamp" => message.whippy_activity["inserted_at"],
        "hubspot_owner_id" => message.external_user_id
      }
    }
  end

  def parse(:note, message) do
    associations = [
      %{
        "types" => [
          %{
            "associationCategory" => "HUBSPOT_DEFINED",
            "associationTypeId" => @note_assoc_id
          }
        ],
        "to" => %{
          "id" => message.external_contact_id
        }
      }
    ]

    associations =
      if is_nil(message.company_id) do
        associations
      else
        associations ++
          [
            %{
              "types" => [
                %{
                  "associationCategory" => "HUBSPOT_DEFINED",
                  "associationTypeId" => @note_company_assoc_id
                }
              ],
              "to" => %{
                "id" => message.company_id
              }
            }
          ]
      end

    %{
      "associations" => associations,
      "properties" => %{
        "hs_note_body" => nl2br(message.whippy_activity["body"]),
        "hs_timestamp" => message.whippy_activity["inserted_at"],
        "hubspot_owner_id" => message.external_user_id
      }
    }
  end

  def parse(:call, message) do
    recording_attachment =
      Enum.find(Map.get(message.whippy_activity, "attachments", []), fn attachment ->
        attachment["url"] =~ ".wav"
      end)

    recording_url =
      if is_nil(recording_attachment) do
        ""
      else
        recording_attachment["url"]
      end

    direction =
      if message.whippy_activity["direction"] == "INBOUND" do
        "INBOUND"
      else
        "OUTBOUND"
      end

    associations = [
      %{
        "types" => [
          %{
            "associationCategory" => "HUBSPOT_DEFINED",
            "associationTypeId" => @call_assoc_id
          }
        ],
        "to" => %{
          "id" => message.external_contact_id
        }
      }
    ]

    associations =
      if is_nil(message.company_id) do
        associations
      else
        associations ++
          [
            %{
              "types" => [
                %{
                  "associationCategory" => "HUBSPOT_DEFINED",
                  "associationTypeId" => @call_company_assoc_id
                }
              ],
              "to" => %{
                "id" => message.company_id
              }
            }
          ]
      end

    call_type =
      with call_metadata when not is_nil(call_metadata) <-
             message.whippy_activity["metadata"],
           agent_id when not is_nil(agent_id) <- Map.get(call_metadata, "agent_id", nil) do
        """
        [Whippy][AI Agent]

        """
      else
        _ ->
          """
          [Whippy][Call]

          """
      end

    duration =
      with call_metadata when not is_nil(call_metadata) <-
             message.whippy_activity["metadata"],
           duration when not is_nil(duration) <-
             Map.get(call_metadata, "duration", nil) do
        duration
      else
        _ -> nil
      end

    call_summary =
      with call_metadata when not is_nil(call_metadata) <-
             message.whippy_activity["metadata"],
           analysis when not is_nil(analysis) <-
             Map.get(call_metadata, "analysis", nil),
           call_summary when not is_nil(call_summary) <-
             Map.get(analysis, "call_summary", nil) do
        """
        --------- Call Summary ---------

        #{call_summary || ""}

        """
      else
        _ -> ""
      end

    transcript =
      if is_nil(message.external_contact_name) do
        message.whippy_activity["body"] || ""
      else
        String.replace(message.whippy_activity["body"] || "", "Contact:", message.external_contact_name)
      end

    transcript = String.replace(transcript, "User:", "Whippy User:")
    transcript = String.replace(transcript, "Agent:", "Whippy AI Agent:")

    call_info = call_info(message)

    body =
      call_type <>
        call_info <>
        call_summary <>
        """
        --------- Call Transcript ---------

        #{transcript}
        """

    %{
      "associations" => associations,
      "properties" => %{
        "hs_call_body" => nl2br(body),
        "hs_call_recording_url" => recording_url,
        "hs_call_direction" => direction,
        "hs_timestamp" => message.whippy_activity["inserted_at"],
        "hubspot_owner_id" => message.external_user_id,
        "hs_call_duration" => duration
      }
    }
  end

  def parse(:email, message) do
    direction =
      if message.whippy_activity["direction"] == "INBOUND" do
        "INCOMING_EMAIL"
      else
        "EMAIL"
      end

    associations = [
      %{
        "types" => [
          %{
            "associationCategory" => "HUBSPOT_DEFINED",
            "associationTypeId" => @email_assoc_id
          }
        ],
        "to" => %{
          "id" => message.external_contact_id
        }
      }
    ]

    associations =
      if is_nil(message.company_id) do
        associations
      else
        associations ++
          [
            %{
              "types" => [
                %{
                  "associationCategory" => "HUBSPOT_DEFINED",
                  "associationTypeId" => @email_company_assoc_id
                }
              ],
              "to" => %{
                "id" => message.company_id
              }
            }
          ]
      end

    %{
      "associations" => associations,
      "properties" => %{
        "hs_email_subject" => nl2br(message.whippy_activity["email_subject"]),
        "hs_email_html" => message.whippy_activity["email_html_body"],
        "hs_email_text" => message.whippy_activity["body"],
        "hs_email_direction" => direction,
        "hs_timestamp" => message.whippy_activity["inserted_at"],
        "hubspot_owner_id" => message.external_user_id
      }
    }
  end

  defp call_info(message) do
    from =
      if message.whippy_activity["direction"] == "INBOUND" do
        """
        From: #{message.external_contact_name} #{message.whippy_activity["from"]}
        """
      else
        """
        From: #{message.whippy_activity["from"]}
        """
      end

    to =
      if message.whippy_activity["direction"] == "INBOUND" do
        """
        To: #{message.whippy_activity["to"]}
        """
      else
        """
        To: #{message.external_contact_name} #{message.whippy_activity["to"]}
        """
      end

    url =
      """
      Call URL:#{Application.get_env(:sync, :whippy_dashboard)}/organizations/#{message.whippy_organization_id}/all/open/#{message.whippy_activity["conversation_id"]}?message_id=#{message.whippy_activity["id"]}
      """

    from <> to <> url
  end

  defp nl2br(text) when is_binary(text) do
    String.replace(text, "\n", "<br>")
  end

  defp nl2br(text) when is_nil(text) do
    text
  end
end
