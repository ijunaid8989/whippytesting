defmodule Sync.Fixtures.AqoreClient do
  @moduledoc false

  def list_candidates_fixture do
    body = [
      %{
        "optOutEmail" => false,
        "title" => "Applicant",
        "id" => "1",
        "officeId" => 1,
        "status" => "Deact",
        "middleName" => "",
        "assignmentId" => 0,
        "organizationId" => 10_000,
        "candidateId" => "1000000",
        "city" => "Charlotte",
        "office" => "North Carolina_200001",
        "zenopleLink" => "https://zenoplehub.zenople.com/applicant/directory/1000000/applicant/snapshot",
        "source" => "",
        "dateOfBirth" => "1939-07-31",
        "isActive" => false,
        "onAssignment" => false,
        "phone" => "+923008637777",
        "lastName" => "Clements",
        "recruiterId" => nil,
        "jobId" => 0,
        "firstName" => "Paul",
        "zipCode" => "28211",
        "address2" => "",
        "emailList" => "",
        "skills" => [],
        "country" => "United States of America",
        "company" => "Millar Industries, Inc.",
        "email" => "hhh@h.com",
        "optOutPhone" => false,
        "phoneList" => "",
        "address1" => "819 N Wendover Rd",
        "entity" => "Applicant",
        "stateCode" => "NC",
        "entityListItemId" => 200_031,
        "hireDate" => nil,
        "state" => "North Carolina"
      }
    ]

    {:ok,
     %HTTPoison.Response{
       status_code: 200,
       body: Jason.encode!(body),
       request: %HTTPoison.Request{url: ""}
     }}
  end

  def token_fixture do
    body = %{
      "access_token" =>
        "eyJhbGciOiJSUzI1NiIsImtpZCI6IjY1MTdDM0VBNTYwRDJBOEI5QjkzQ0QzOEU2QjhDNEQwRTYzNkY5QTlSUzI1NiIsInR5cCI6ImF0K2p3dCIsIng1dCI6IlpSZkQ2bFlOS291Yms4MDQ1cmpFME9ZMi1hayJ9.eyJuYmYiOjE3MzQ3MTg2MTAsImV4cCI6MTczNDcyNTgxMCwiaXNzIjoiaHR0cHM6Ly96ZW5vcGxlaHViYXBpLnplbm9wbGUuY29tIiwiY2xpZW50X2lkIjoiV25QU2pvdGFrVUtFbjM4T1ZMQzVvTHFFY2tyZlBvZkgyYkpEVThvNXZBZz0iLCJjbGllbnRfZ3JhbnRUeXBlIjoiY2xpZW50X2NyZWRlbnRpYWxzIiwiY2xpZW50X3BlcnNvbklkIjoiMiIsImNsaWVudF9jbGllbnROYW1lIjoiVGhpcmRQYXJ0eSIsImNsaWVudF9yZXF1ZXN0TGltaXQiOiIyMDAiLCJjbGllbnRfcGVybWlzc2lvbiI6ImNvbW1vbi9kYXRhIiwianRpIjoiQUQ5QTcxNjMzQzA1RDVGN0EzREFDQzUxRkFDRDkzMzYiLCJpYXQiOjE3MzQ3MTg2MTAsInNjb3BlIjpbInplbm9wbGVBcGkiXX0.VCtNPnL2Dj4Unubsiuup03ptag42cFjUGv_Vj6wiMWHOMy6oLwTkJEAHes-A5mpEBKbFO_JV0VoJKH0VLXN9BmlWLEFgFLl1DzsDhTEzbuCyN_iyW75N1UGTOgH1xm-wtDF3_XKjk9fXobEj-Obf8otNgaRRh3KrHevudNlw3XCn2ydhXe1KDMuvFKs7hPG8YMIDo6gwNSQNLPRo_FQ7o7tuYQdv2pB7fCYiK4t49z4fMS3uaKd0VqAYK6tXtfa2Kuuhf23eGOPo_wzhsUkIEUFkXxndfOS0I0GAXDz_Ix25KY1SWgjqJKeK_gPuvVTsRdUTvwbTK0laYG5TyRMVeA",
      "expires_in" => 7200,
      "scope" => "zenopleApi",
      "token_type" => "Bearer"
    }

    {:ok,
     %HTTPoison.Response{
       status_code: 200,
       body: Jason.encode!(body),
       request: %HTTPoison.Request{url: ""}
     }}
  end

  def list_contact_fixture do
    body = [
      %{
        "id" => "1",
        "clientContactId" => "1",
        "firstName" => "Paul",
        "lastName" => "Clements",
        "email" => "hhh@h.com",
        "phone" => "2182349095",
        "title" => "Contact",
        "organizationId" => "1004",
        "status" => "Active",
        "isActive" => true,
        "workPhone" => "9883428165",
        "preferredContactMethod" => "phone",
        "dateAdded" => "1990-04-12T12:00:00Z",
        "role1" => "Others",
        "role2" => "Others",
        "role3" => "Others"
      }
    ]

    {:ok,
     %HTTPoison.Response{
       status_code: 200,
       body: Jason.encode!(body),
       request: %HTTPoison.Request{url: ""}
     }}
  end

  def list_contacts_fixture do
    body = [
      %{
        "id" => "100672",
        "clientContactId" => "100672",
        "firstName" => "David",
        "lastName" => "Jones",
        "email" => "",
        "phone" => "",
        "title" => "Contact",
        "organizationId" => "100162",
        "status" => "Active",
        "isActive" => true,
        "workPhone" => "2182349095",
        "dateAdded" => "2017-02-27T09:49:00Z"
      },
      %{
        "id" => "1",
        "clientContactId" => "1",
        "firstName" => "Paul",
        "lastName" => "Clements",
        "email" => "hhh@h.com",
        "phone" => "2182349095",
        "title" => "Contact",
        "organizationId" => "1004",
        "status" => "Active",
        "isActive" => true,
        "workPhone" => "9883428165",
        "preferredContactMethod" => "phone",
        "dateAdded" => "1990-04-12T12:00:00Z",
        "role1" => "Others",
        "role2" => "Others",
        "role3" => "Others"
      }
    ]

    {:ok,
     %HTTPoison.Response{
       status_code: 200,
       body: Jason.encode!(body),
       request: %HTTPoison.Request{url: ""}
     }}
  end

  def list_organization_data_fixture do
    body = [
      %{
        "id" => "1",
        "organizationId" => "10000",
        "entityListItemId" => 200_048,
        "entity" => "Customer",
        "enteredBy" => "3",
        "address1" => "819 N Wendover Rd",
        "city" => "Charlotte",
        "organization" => "Millar Industries, Inc.",
        "phone" => "",
        "zipcode" => "28211",
        "state" => "North Carolina",
        "department" => "Parent",
        "office" => "North Carolina_200001",
        "status" => "Active",
        "workflow" => "Customer",
        "stage" => "Customer",
        "entityCreatedDate" => "2004-09-29",
        "insertDate" => "2004-09-29T21:09:00Z"
      }
    ]

    {:ok,
     %HTTPoison.Response{
       status_code: 200,
       body: Jason.encode!(body),
       request: %HTTPoison.Request{url: ""}
     }}
  end

  def list_job_candidates_fixture do
    body = [
      %{
        id: "1",
        jobCandidateId: "1",
        personId: 1_000_204_481,
        candidateId: "1000204481",
        jobId: "134472",
        entity: "JobCandidate",
        currentEntity: "Employee",
        currentEntityStage: "Employee",
        currentEntityStatus: "Deact",
        jobCandidateStage: "Candidate",
        jobCandidateStatus: "Assigned",
        source: "ZenopleJobPortal",
        jobCandidateDate: "2022-01-18T13:02:00Z",
        dateAdded: "2022-01-18T13:02:00Z",
        previouslyWorkedForThisOrganization: true,
        previouslyWorkedForThisJobPosition: false,
        personRating: "Any",
        candidateRating: "Any",
        priority: 2,
        name: "MARIE B ELLISON",
        phone: "9114175630",
        email: "fuu.teor@uovnp.com",
        dateOfBirth: "2003-10-21",
        address: %{
          address1: "819 N Wendover Rd",
          address2: nil,
          city: "Charlotte",
          state: "North Carolina",
          stateCode: "NC"
        },
        jobModule: "TempJob",
        skills: [
          %{
            yearOfExperience: 0.0,
            category: "Administrative",
            skill: "Demo - Product",
            isValidated: false
          },
          %{
            yearOfExperience: 0.0,
            category: "Administrative",
            skill: "EF Carrying 0 to 25 lbs",
            isValidated: false
          },
          %{
            yearOfExperience: 0.0,
            category: "Administrative",
            skill: "EF Carrying 25 to 50 lbs",
            isValidated: false
          },
          %{
            yearOfExperience: 0.0,
            category: "Administrative",
            skill: "EF Carrying over 50 lbs",
            isValidated: false
          }
        ],
        educationHistory: [],
        workHistory: [
          %{
            employer: "White duck taco shop",
            title: "Employee",
            startDate: "2021-03-19T00:00:00",
            endDate: "2021-07-13T00:00:00",
            startYear: "2021",
            endYear: "2021",
            startMonth: "March",
            endtMonth: "March",
            lastPay: 13.0
          },
          %{
            employer: "Montford Deli",
            title: "Employee",
            startDate: "2021-08-01T00:00:00",
            endDate: "2021-12-01T00:00:00",
            startYear: "2021",
            endYear: "2021",
            startMonth: "August",
            endtMonth: "August",
            lastPay: 10.0
          }
        ],
        job: %{
          jobId: 134_472,
          jobTitle: "Assembly",
          description:
            "Assemble new and/or replacement parts by operating intermediate machines and equipment.  Must be able to assemble and complete functional units or complex subassemblies from blue prints. Must be able to work at a fast and accurate pace.    \nPHYSICAL RESPONSIBILITIES:\nWill be lifting, moving up to 25lbs frequently, up to 50lbs on occasion and up to 100lbs rarely.                                                    ESSENTIAL DUTIES: \nSet up assembly equipment by adjusting tools and controls, etc. according to procedures and standards. \nQualify run for first piece approval. \nLoad/unload assembly lines safely by using proper handling equipment. \nOperate equipment to highest production and quality standards. \nMake necessary adjustments and replace tools or parts as required. \nUse hand tools and gages appropriate to the work performed. ",
          jobModule: "TempJob",
          organizationId: 18_719,
          organization: "Critical Systems",
          department: "1560-CV Assembly",
          workAddress: %{
            address1: "819 N Wendover Rd",
            address2: nil,
            city: "Charlotte",
            state: "North Carolina",
            stateCode: "NC",
            zipCode: "28211"
          },
          status: "Completed",
          required: 1,
          assigned: 1,
          rtPayRate: 16.5,
          otPayRate: 16.5,
          salary: 0.0,
          startDate: "2021-11-18",
          endDate: "2022-03-23",
          shiftStartTime: "15:00:00",
          shiftEndTime: "23:00:00",
          jobSkills: [
            %{
              category: "Accounting",
              skill: "Accounts Payable & Receivable"
            },
            %{
              category: "Accounting",
              skill: "Accounts Payable"
            }
          ],
          recruiter: "FRANK TODD",
          recruiterPhone: "9115751108",
          recruiterEmail: "tbgj.hzba@ebhdy.net",
          interviewQuestions: [],
          assignmentInfo: [
            %{
              infoId: 202_577,
              assignmentInfo: "SmokingDetails",
              assignmentInfoDescription: "Smoking Details",
              assignmentInfoValue: "no smoking available within the premises"
            }
          ]
        }
      }
    ]

    {:ok,
     %HTTPoison.Response{
       status_code: 200,
       body: Jason.encode!(body),
       request: %HTTPoison.Request{url: ""}
     }}
  end

  def list_jobs_fixture do
    body = [
      %{
        id: "104860",
        jobId: "104860",
        entity: "Job",
        jobType: "Temp Job",
        address1: "819 N Wendover Rd",
        address2: "",
        title: "Finishing Operator",
        organizationId: "17080",
        city: "Charlotte",
        zipcode: "28211",
        state: "North Carolina",
        payRate: 14.0,
        billRate: 19.32,
        skills: [
          "Finishing Operator"
        ],
        salary: 0.0,
        dateStart: "2017-09-06",
        dateEnd: "2019-07-19",
        shift: "",
        status: "Inactive",
        placementRequired: 1,
        officeId: 200_001,
        office: "North Carolina_200001",
        dateAdded: "2017-09-06T10:30:00Z",
        internalUserId: "2",
        description: nil,
        jobPostingDescription: nil
      }
    ]

    {:ok,
     %HTTPoison.Response{
       status_code: 200,
       body: Jason.encode!(body),
       request: %HTTPoison.Request{url: ""}
     }}
  end

  def list_assignment_fixture do
    body = [
      %{
        id: "1",
        assignmentId: "1",
        entityListItemId: 200_047,
        entity: "Assignment",
        candidateId: "999992160",
        organizationId: "20494",
        jobId: "131128",
        overTimePayRate: 18.75,
        overTimeBillRate: 28.13,
        payRate: 12.5,
        billRate: 18.75,
        salary: 0.0,
        shift: "",
        status: "Ended",
        candidateName: "JEANETTE L GALLOWAY",
        organizationName: "Child Support_ACH_TN",
        office: "North Carolina_200001",
        cityState: "Charlotte,North Carolina",
        wcCode: "4829NC",
        assignmentType: "Regular",
        address1: "819 N Wendover Rd",
        address2: "",
        city: "Charlotte",
        state: "North Carolina",
        zipCode: "28211",
        fullAddress: "819 N Wendover Rd Charlotte, NC - 28211",
        startDate: "2020-04-28",
        endDate: "2020-07-26",
        endReason: "RateChange",
        performance: "",
        payPeriod: "Weekly",
        dateAdded: "2020-04-28T00:00:00Z",
        recruiterUserId: "0"
      }
    ]

    {:ok,
     %HTTPoison.Response{
       status_code: 200,
       body: Jason.encode!(body),
       request: %HTTPoison.Request{url: ""}
     }}
  end

  def list_candidates_empty_fixture do
    body = []

    {:ok,
     %HTTPoison.Response{
       status_code: 200,
       body: Jason.encode!(body),
       request: %HTTPoison.Request{url: ""}
     }}
  end

  def list_candidates_error_fixture do
    {:error, %HTTPoison.Error{reason: :timeout}}
  end

  def message_error_fixture do
    body = %{
      "message" => "The sync occured before the interval of 15 minutes"
    }

    {:ok,
     %HTTPoison.Response{
       status_code: 200,
       body: Jason.encode!(body),
       request: %HTTPoison.Request{url: ""}
     }}
  end

  def list_candidates_partial_fixture do
    body = [
      %{
        "id" => "2",
        "firstName" => "Jane",
        "lastName" => "Smith",
        "title" => "Project Manager",
        "status" => "Inactive",
        "isActive" => false,
        "address1" => "456 Elm St",
        "city" => "Gotham",
        "state" => "NJ",
        "country" => "USA",
        "skills" => ["Management", "Communication"]
      },
      %{
        "id" => "3",
        "firstName" => "Alice",
        "lastName" => "Johnson",
        "title" => "Data Scientist",
        "status" => "Active",
        "isActive" => true,
        "address1" => "789 Oak St",
        "city" => "Central City",
        "state" => "IL",
        "country" => "USA",
        "skills" => ["Python", "Machine Learning"]
      }
    ]

    {:ok,
     %HTTPoison.Response{
       status_code: 200,
       body: Jason.encode!(body),
       request: %HTTPoison.Request{url: ""}
     }}
  end

  def create_comment_fixture do
    body = %{
      "commentId" => 3_087_177,
      "success" => true
    }

    {:ok,
     %HTTPoison.Response{
       status_code: 200,
       body: Jason.encode!(body),
       request: %HTTPoison.Request{url: ""}
     }}
  end

  def create_comment_error_fixture do
    body = %{
      "error" => "unprocessable_entity"
    }

    {:error,
     %HTTPoison.Response{
       status_code: 422,
       body: Jason.encode!(body),
       request: %HTTPoison.Request{url: ""}
     }}
  end

  def create_comment_unexpected_format_fixture do
    body = %{
      "unexpected" => "format"
    }

    {:ok,
     %HTTPoison.Response{
       status_code: 200,
       body: Jason.encode!(body),
       request: %HTTPoison.Request{url: ""}
     }}
  end

  def list_users_fixture do
    {:ok,
     %HTTPoison.Response{
       status_code: 200,
       body:
         Jason.encode!([
           %{
             id: "500000",
             userId: "500000",
             firstName: "Paul",
             lastName: "Allen",
             middleName: "Patrick",
             title: "President",
             userName: "paul.allen@example.com",
             entityListItemId: 500_000,
             entity: "OfficeStaff",
             statusListItemId: 500_000,
             status: "Active",
             isActive: true,
             address1: "123 Main St",
             address2: "",
             city: "Metropolis",
             state: "NY",
             stateCode: "NC",
             zipcode: "10001",
             country: "USA",
             dateOfBirth: "2024-08-07",
             email: "paul.allen@example.com",
             emailList: "paul.allen@example.com",
             phone: "5155555555",
             phoneList: "5155555555",
             optOutSms: false,
             optOutEmail: false,
             dateAdded: "2024-08-08T04:30:00Z"
           },
           %{
             id: "500001",
             userId: "500001",
             firstName: "John",
             lastName: "Doe",
             middleName: "Patrick",
             title: "President",
             userName: "john.doe@example.com",
             entityListItemId: 500_001,
             entity: "OfficeStaff",
             statusListItemId: 500_001,
             status: "Active",
             isActive: true,
             address1: "456 Elm St",
             address2: "",
             city: "Gotham",
             state: "NJ",
             stateCode: "NJ",
             zipcode: "10001",
             country: "USA",
             dateOfBirth: "2024-08-07",
             email: "john.doe@example.com",
             emailList: "john.doe@example.com",
             phone: "4145555555",
             phoneList: "4145555555",
             optOutSms: false,
             optOutEmail: false,
             dateAdded: "2024-08-08T04:30:00Z"
           }
         ])
     }}
  end

  def list_users_empty_fixture do
    {:ok, %HTTPoison.Response{status_code: 200, body: Jason.encode!([])}}
  end

  def list_users_error_fixture do
    {:error, %HTTPoison.Error{reason: :timeout}}
  end

  def new_candidates_fixture do
    body =
      %{
        "optOutEmail" => false,
        "title" => "Applicant",
        "id" => "1",
        "officeId" => 1,
        "status" => "Deact",
        "middleName" => "",
        "assignmentId" => 0,
        "organizationId" => 10_000,
        "candidateId" => "1000000",
        "city" => "Charlotte",
        "office" => "North Carolina_200001",
        "zenopleLink" => "https://zenoplehub.zenople.com/applicant/directory/1000000/applicant/snapshot",
        "source" => "",
        "dateOfBirth" => "1939-07-31",
        "isActive" => false,
        "onAssignment" => false,
        "phone" => "+923008637777",
        "lastName" => "Clements",
        "recruiterId" => nil,
        "jobId" => 0,
        "firstName" => "Paul",
        "zipCode" => "28211",
        "address2" => "",
        "emailList" => "",
        "skills" => [],
        "country" => "United States of America",
        "company" => "Millar Industries, Inc.",
        "email" => "hhh@h.com",
        "optOutPhone" => false,
        "phoneList" => "",
        "address1" => "819 N Wendover Rd",
        "entity" => "Applicant",
        "stateCode" => "NC",
        "entityListItemId" => 200_031,
        "hireDate" => nil,
        "state" => "North Carolina"
      }

    {:ok,
     %HTTPoison.Response{
       status_code: 200,
       body: Jason.encode!(body),
       request: %HTTPoison.Request{url: ""}
     }}
  end

  def list_candidates_with_zzz_as_lastname_fixture do
    body = [
      %{
        "id" => "1",
        "status" => "Deact",
        "middleName" => "",
        "candidateId" => "1000000",
        "city" => "Charlotte",
        "office" => "North Carolina_200001",
        "zenopleLink" => "https://zenoplehub.zenople.com/applicant/directory/1000000/applicant/snapshot",
        "dateOfBirth" => "1939-07-31",
        "isActive" => false,
        "onAssignment" => false,
        "phone" => "+923008637777",
        "lastName" => "Clements",
        "recruiterId" => nil,
        "firstName" => "Paul",
        "zipCode" => "28211",
        "address2" => "",
        "emailList" => "",
        "skills" => [],
        "country" => "United States of America",
        "company" => "Millar Industries, Inc.",
        "email" => "hhh@h.com",
        "phoneList" => "",
        "address1" => "819 N Wendover Rd",
        "entity" => "Applicant",
        "stateCode" => "NC",
        "entityListItemId" => 200_031,
        "state" => "North Carolina"
      },
      %{
        "id" => "2",
        "status" => "Deact",
        "middleName" => "",
        "candidateId" => "2000000",
        "city" => "Charlotte",
        "office" => "North Carolina_200001",
        "zenopleLink" => "https://zenoplehub.zenople.com/applicant/directory/1000000/applicant/snapshot",
        "dateOfBirth" => "1939-07-31",
        "isActive" => false,
        "onAssignment" => false,
        "phone" => "+923008637888",
        "lastName" => "zzzAlen",
        "recruiterId" => nil,
        "firstName" => "Polly",
        "zipCode" => "28211",
        "address2" => "",
        "emailList" => "",
        "skills" => [],
        "country" => "United States of America",
        "company" => "Millar Industries, Inc.",
        "email" => "zzz@h.com",
        "phoneList" => "",
        "address1" => "819 N Wendover Rd",
        "entity" => "Applicant",
        "stateCode" => "NC",
        "entityListItemId" => 200_031,
        "state" => "North Carolina"
      },
      %{
        "id" => "3",
        "status" => "Deact",
        "middleName" => "",
        "candidateId" => "3000000",
        "city" => "Charlotte",
        "office" => "North Carolina_200001",
        "zenopleLink" => "https://zenoplehub.zenople.com/applicant/directory/1000000/applicant/snapshot",
        "dateOfBirth" => "1939-07-21",
        "isActive" => false,
        "onAssignment" => false,
        "phone" => "+923008637999",
        "lastName" => "Jhon",
        "recruiterId" => nil,
        "firstName" => "Clara",
        "zipCode" => "28211",
        "address2" => "",
        "emailList" => "",
        "skills" => [],
        "country" => "United States of America",
        "company" => "Millar Industries, Inc.",
        "email" => "hhh@h.com",
        "phoneList" => "",
        "address1" => "819 N Wendover Rd",
        "entity" => "Applicant",
        "stateCode" => "NC",
        "entityListItemId" => 200_031,
        "state" => "North Carolina"
      }
    ]

    {:ok,
     %HTTPoison.Response{
       status_code: 200,
       body: Jason.encode!(body),
       request: %HTTPoison.Request{url: ""}
     }}
  end
end
