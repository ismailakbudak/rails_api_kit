require "spec_helper"

RSpec.describe NotesController, type: :request do
  describe "PUT /notes/:id" do
    let(:note) { create_note }
    let(:note_id) { note.id }
    let(:user) { note.user }
    let(:user_id) { user.id }
    let(:note_params) do
      {
        note: {
          title: FFaker::Company.name,
          user_id: user_id
        }
      }
    end
    let(:params) { note_params }

    before do
      put(note_path(note_id), params: params.to_json, headers: api_headers)
    end

    it 'renders single' do
      expect(response).to have_http_status(:ok)
      expect(response_json["data"]["id"]).to eql(note.id)
      expect(response_json["meta"]).to eq("single" => true)
    end

    context "with a missing parameter in the payload" do
      let(:params) { {} }

      it do
        expect(response).to have_http_status(:unprocessable_content)
        expect(response_json["errors"].size).to eq(1)
        expect(response_json["errors"][0]["status"]).to eq("422")
        expect(response_json["errors"][0]["title"]).to eq('Unprocessable Content')
        expect(response_json["errors"][0]["detail"]).to eq("Required parameter missing or invalid")
      end
    end

    context "with an invalid payload" do
      let(:params) do
        payload = note_params.dup
        payload[:note][:user_id] = nil
        payload
      end

      it 'with invalid user id' do
        expect(response).to have_http_status(:unprocessable_content)
        expect(response_json["errors"].size).to eq(1)
        expect(response_json["errors"][0]["status"]).to eq("422")
        expect(response_json["errors"][0]["code"]).to include("blank")
        expect(response_json["errors"][0]["title"]).to eq('Error')
        expect(response_json["errors"][0]["detail"]).to eq("User must exist")
        expect(response_json["errors"][0]["attribute"]).to eq("user")
      end

      context "required by validations" do
        let(:params) do
          payload = note_params.dup
          payload[:note][:title] = "BAD_TITLE"
          payload[:note][:quantity] = 100 + rand(10)
          payload
        end

        it 'multiple errors' do
          expect(response).to have_http_status(:unprocessable_content)
          expect(response_json["errors"].size).to eq(3)

          expect(response_json["errors"][0]["status"]).to eq("422")
          expect(response_json["errors"][0]["code"]).to include("invalid")
          expect(response_json["errors"][0]["title"]).to eq('Error')
          expect(response_json["errors"][0]["detail"]).to eq("Title is invalid")

          expect(response_json["errors"][1]["status"]).to eq("422")
          expect(response_json["errors"][1]["code"]).to eq("less_than")
          expect(response_json["errors"][1]["title"]).to eq('Error')
          expect(response_json["errors"][1]["detail"]).to eq("Quantity must be less than 100")

          expect(response_json["errors"][2]["status"]).to eq("422")
          expect(response_json["errors"][2]["code"]).to eq("invalid")
          expect(response_json["errors"][2]["title"]).to eq('Error')
          expect(response_json["errors"][2]["detail"]).to eq("Title has typos")
        end
      end

      context "as a param attribute" do
        let(:params) do
          payload = note_params.dup
          payload[:note].delete(:title)
          payload
        end

        it do
          expect(response).to have_http_status(:success)
        end
      end
    end

    context "with a bad note ID" do
      let(:user_id) { nil }
      let(:note_id) { rand(10) }

      it do
        expect(response).to have_http_status(:not_found)
        expect(response_json["errors"].size).to eq(1)
        expect(response_json["errors"][0]["status"]).to eq("404")
        expect(response_json["errors"][0]["title"]).to eq(Rack::Utils::HTTP_STATUS_CODES[404])
        expect(response_json["errors"][0]["detail"]).to eq("Resource not found")
      end
    end

    context "with an exception" do
      let(:user_id) { nil }
      let(:note_id) { "tada" }

      it do
        expect(response).to have_http_status(:internal_server_error)
        expect(response_json["errors"].size).to eq(1)
        expect(response_json["errors"][0]["status"]).to eq("500")
        expect(response_json["errors"][0]["title"]).to eq(Rack::Utils::HTTP_STATUS_CODES[500])
        expect(response_json["errors"][0]["detail"]).to eql("tada")
      end
    end
  end
end