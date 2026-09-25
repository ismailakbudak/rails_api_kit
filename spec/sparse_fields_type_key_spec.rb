require 'spec_helper'

# The sparse-fieldset type key AMS looks a serializer up by is
# `model_name.to_s.underscore`. api_kit has to derive the same string when it
# injects the fallback "everything for the primary type" entry, or AMS falls
# through to the pluralised collection key — whose value is an empty list.
RSpec.describe 'sparse fieldsets', type: :request do
  describe 'GET /inventory_items' do
    let!(:item) { Inventory::Item.create!(name: 'Bolt', quantity: 7) }

    before { get(inventory_items_path, params: params, headers: api_headers) }

    context 'when fields are sent for the primary type' do
      let(:params) { { fields: { 'inventory/item' => 'id,name' } } }

      it 'trims the primary type to the requested attributes' do
        expect(response).to have_http_status(:ok)
        expect(response_json['data'].first.keys).to contain_exactly('id', 'name')
      end
    end

    context 'when fields are sent only for another type' do
      let(:params) { { fields: { user: 'id' } } }

      it 'leaves the namespaced primary type fully populated' do
        expect(response).to have_http_status(:ok)
        expect(response_json['data'].first.keys)
          .to contain_exactly('id', 'name', 'quantity')
      end
    end

    context 'without any fields param' do
      let(:params) { {} }

      it 'returns every attribute' do
        expect(response).to have_http_status(:ok)
        expect(response_json['data'].first.keys)
          .to contain_exactly('id', 'name', 'quantity')
      end
    end
  end

  # `AMS::CollectionSerializer#json_key` infers the root from the first element,
  # or from a collection that answers `#name` (an `ActiveRecord::Relation` does,
  # through its klass). An empty plain Array answers neither, and raises
  # `CannotInferRootKeyError` as soon as a fieldset has to be built.
  describe 'GET /reports' do
    before { get(reports_path, params: params, headers: api_headers) }

    context 'with rows and a fields param' do
      let(:params) { { fields: { report_row: 'label' } } }

      it 'trims the PORO row to the requested attributes' do
        expect(response).to have_http_status(:ok)
        expect(response_json['data'].first.keys).to contain_exactly('label')
      end
    end

    context 'with rows and no fields param' do
      let(:params) { {} }

      it 'returns every attribute' do
        expect(response).to have_http_status(:ok)
        expect(response_json['data'].first.keys)
          .to contain_exactly('label', 'total')
      end
    end

    context 'with no rows and a fields param' do
      let(:params) { { empty: true, fields: { report_row: 'label' } } }

      it 'renders an empty collection instead of failing to infer a root' do
        expect(response).to have_http_status(:ok)
        expect(response_json['data']).to eq([])
      end
    end

    context 'with no rows and no fields param' do
      let(:params) { { empty: true } }

      it 'renders an empty collection' do
        expect(response).to have_http_status(:ok)
        expect(response_json['data']).to eq([])
      end
    end
  end
end
