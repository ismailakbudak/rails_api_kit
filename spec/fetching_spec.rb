require 'spec_helper'

RSpec.describe UsersController, type: :request do
  describe 'GET /users' do
    let!(:user) { }
    let(:params) { }

    before do
      get(users_path, params: params, headers: api_headers)
    end

    context 'with users' do
      let(:first_user) { create_user }
      let(:second_user) { create_user }
      let(:third_user) { create_note.user }
      let(:users) { [ first_user, second_user, third_user ] }
      let(:user) { users.last }
      let(:note) { third_user.notes.first }

      context 'returns customers and dasherized first name' do
        let(:params) do
          { upcase: :yes, fields: [ :first_name ] }
        end

        it do
          expect(response).to have_http_status(:ok)
          expect(response_json['data'].size).to eq(users.size)

          response_json['data'].each do |item|
            user = users.detect { |u| u.id == item['id'].to_i }
            expect(item['first_name']).to eql(user.first_name.upcase)
          end
        end
      end

      context 'returns customers and full name' do
        let(:params) do
          { fields:  { user: 'id,full_name' } }
        end

        it do
          expect(response).to have_http_status(:ok)
          expect(response_json['data'].size).to eq(users.size)

          response_json['data'].each do |item|
            user = users.detect { |u| u.id == item['id'].to_i }
            full_name = "#{user.first_name} #{user.last_name}"
            expect(item['full_name']).to eql(full_name)
          end
        end
      end

      context 'returns customers included and sparse fields' do
        let(:params) do
          {
            include: 'notes',
            fields:  { note: 'title,updated_at' }
          }
        end

        it do
          expect(response).to have_http_status(:ok)
          expect(response_json['data'].last['notes'].size).to eql(1)
          expect(response_json['data'].last['notes'][0]).to eql({
            'title' => note.title,
            'updated_at' => note.updated_at.as_json
          })
        end
      end
    end
  end

  describe 'GET /users/:id' do
    let(:note) { create_note }
    let(:user) { note.user }
    let(:params) { }

    before do
      get(user_path(user), params: params, headers: api_headers)
    end

    context 'with users' do
      context 'returns user' do
        it do
          expect(response).to have_http_status(:ok)
          expect(response_json['data']['id']).to eq(user.id)
          expect(response_json['data']['first_name']).to eq(user.first_name)
          expect(response_json['data']['last_name']).to eq(user.last_name)
          expect(response_json['data'].keys).not_to include('notes')
        end
      end

      context 'returns customers first name and notes id' do
        let(:params) do
          {
            include: 'notes',
            fields: { user: 'first_name', note: 'id' }
          }
        end

        it do
          expect(response).to have_http_status(:ok)
          expect(response_json['data']).to eq({ "first_name" => user.first_name, "notes" => [{ "id" => note.id }] })
        end
      end

      context 'returns user attributes with and notes id' do
        let(:params) do
          {
            include: 'notes',
            fields: { note: 'id' }
          }
        end

        it do
          expect(response).to have_http_status(:ok)
          expect(response_json.dig('data', 'id')).to eq(user.id)
          expect(response_json.dig('data', 'first_name')).to eq(user.first_name)
          expect(response_json.dig('data', 'last_name')).to eq(user.last_name)
          expect(response_json.dig('data', 'notes', 0, 'id')).to eq(note.id)
        end
      end

      context 'returns customers first name and notes id' do
        let(:params) do
          { fields: { user: 'first_name' } }
        end

        it do
          expect(response).to have_http_status(:ok)
          expect(response_json['data']).to eq({ "first_name" => user.first_name })
        end
      end

      context 'returns customers included and sparse fields' do
        let(:params) do
          {
            include: 'notes',
            fields:  { note: 'title,updated_at' }
          }
        end

        it 'should render notes with user' do
          expect(response).to have_http_status(:ok)
          expect(response_json['data'].keys.size).to eql(7)
          expect(response_json['data']['notes'].size).to eql(1)
          expect(response_json['data']['notes'][0]).to eql({
            'title' => note.title,
            'updated_at' => note.updated_at.as_json
          })
        end
      end
    end
  end
end