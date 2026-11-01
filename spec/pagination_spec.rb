require 'spec_helper'

RSpec.describe UsersController, type: :request do
  describe 'GET /users' do
    let!(:user) { }
    let(:params) do
      {
        page: { number: 'Nan', size: 'NaN' },
        sort: '-created_at'
      }
    end

    before do
      get(users_path, params: params, headers: api_headers)
    end

    it do
      expect(response_json['data'].size).to eq(0)
      expect(response_json['meta'])
        .to eq(
          'many' => true,
          'pagination' => {
            'current' => 1,
            'total_page' => 1,
            'total_count' => 0
          }
        )
    end

    def query_str(parms, page: nil)
      parms = parms.deep_merge(page: { number: page }) if page

      arg_params = parms.dup
      if page == 1
        arg_params.delete(:page)
      end

      "?#{CGI.unescape(arg_params.to_query)}"
    end

    context 'with users' do
      let(:first_user) { create_user }
      let(:second_user) { create_user }
      let(:third_user) { create_user }
      let(:users) { [ first_user, second_user, third_user ] }
      let(:user) { users.last }

      context 'returns users with pagination links' do
        it do
          expect(response).to have_http_status(:ok)
          expect(response_json['data'].size).to eq(3)
          expect(response_json['data'][0]['id']).to eql(third_user.id)
          expect(response_json['data'][1]['id']).to eql(second_user.id)
          expect(response_json['data'][2]['id']).to eql(first_user.id)

          expect(response_json).to have_link('current')
          expect(response_json).to have_link(:prev)
          expect(response_json).to have_link(:next)
          expect(response_json).to have_link(:first)
          expect(response_json).to have_link(:last)

          query = CGI.unescape(params.except(:page).to_query)
          expect(URI.parse(response_json['links']['current']).query).to eq(query)
        end

        context 'on page 2 out of 3' do
          let(:as_list) { }
          let(:params) do
            {
              page: { number: 2, size: 1 },
              sort: '-created_at',
              as_list: as_list
            }.reject { |_k, _v| _v.blank? }
          end

          context 'on an array of resources' do
            let(:as_list) { true }

            it 'should exclude' do
              expect(response).to have_http_status(:ok)
              expect(response_json['data'].size).to eq(1)
              expect(response_json['data'][0]['id']).to eql(second_user.id)

              expect(response_json['meta']['pagination']).to eq(
                'current' => 2,
                'total_count' => 3,
                'total_page' => 3
              )
              expect(response_json['links']).to eq(
                'current' => query_str(params),
                'first' => query_str(params, page: 1),
                'prev' => query_str(params, page: 1),
                'next' => query_str(params, page: 3),
                'last' => query_str(params, page: 3),
              )
            end
          end

          it do
            expect(response).to have_http_status(:ok)
            expect(response_json['data'].size).to eq(1)
            expect(response_json['data'][0]['id']).to eql(second_user.id)

            expect(response_json['meta']['pagination']).to eq(
              'current' => 2,
              'total_count' => 3,
              'total_page' => 3
            )
            expect(response_json['links']).to eq(
              'current' => query_str(params),
              'first' => query_str(params, page: 1),
              'prev' => query_str(params, page: 1),
              'next' => query_str(params, page: 3),
              'last' => query_str(params, page: 3),
            )

            expect(response_json).to have_link(:current)
            expect(response_json).to have_link(:prev)
            expect(response_json).to have_link(:first)
            expect(response_json).to have_link(:next)
            expect(response_json).to have_link(:last)

            qry = CGI.unescape(params.to_query)
            expect(URI.parse(response_json['links']['current']).query)
              .to eq(qry)

            qry = CGI.unescape(params.deep_merge(page: { number: 2 }).to_query)
            expect(URI.parse(response_json['links']['current']).query)
              .to eq(qry)

            qry = CGI.unescape(params.except(:page).to_query)
            expect(URI.parse(response_json['links']['prev']).query).to eq(qry)
            expect(URI.parse(response_json['links']['first']).query).to eq(qry)

            qry = CGI.unescape(params.deep_merge(page: { number: 3 }).to_query)
            expect(URI.parse(response_json['links']['next']).query).to eq(qry)
            expect(URI.parse(response_json['links']['last']).query).to eq(qry)
          end
        end

        context 'on page 3 out of 3' do
          let(:params) do
            {
              page: { number: 3, size: 1 }
            }
          end

          it do
            expect(response).to have_http_status(:ok)
            expect(response_json['data'].size).to eq(1)

            expect(response_json['meta']['pagination']).to eq(
              'current' => 3,
              'total_count' => 3,
              'total_page' => 3
            )
            expect(response_json['links']).to eq(
              'current' => query_str(params),
              'first' => query_str(params, page: 1),
              'prev' => query_str(params, page: 2),
              'next' => nil,
              'last' => query_str(params, page: 3),
            )

            expect(response_json).to have_link(:current)
            expect(response_json).to have_link(:prev)
            expect(response_json).to have_link(:first)
            expect(response_json).to have_link(:next)
            expect(response_json).to have_link(:last)

            expect(URI.parse(response_json['links']['current']).query)
              .to eq(CGI.unescape(params.to_query))

            qry = CGI.unescape(params.deep_merge(page: { number: 2 }).to_query)
            expect(URI.parse(response_json['links']['prev']).query).to eq(qry)

            qry = CGI.unescape(params.except(:page).to_query)
            expect(URI.parse(response_json['links']['first']).query).to eq(qry)
          end
        end


        context 'on page empty' do
          let(:params) do
            {
              page: { number: 3 }
            }
          end

          it do
            expect(response).to have_http_status(:ok)
            expect(response_json['data'].size).to eq(0)
            expect(response_json['data']).to eql([])

            expect(response_json['meta']['pagination']).to eq(
                                                             'current' => 3,
                                                             'total_count' => 3,
                                                             'total_page' => 1
                                                           )
            expect(response_json['links']).to eq(
                                                'current' => query_str(params),
                                                'first' => query_str(params, page: 1),
                                                'prev' => query_str(params, page: 2),
                                                'next' => nil,
                                                'last' => '?',
                                                )

            expect(response_json).to have_link(:current)
            expect(response_json).to have_link(:prev)
            expect(response_json).to have_link(:first)
            expect(response_json).to have_link(:next)
            expect(response_json).to have_link(:last)

            expect(URI.parse(response_json['links']['current']).query)
              .to eq(CGI.unescape(params.to_query))

            qry = CGI.unescape(params.deep_merge(page: { number: 2 }).to_query)
            expect(URI.parse(response_json['links']['prev']).query).to eq(qry)

            qry = CGI.unescape(params.except(:page).to_query)
            expect(URI.parse(response_json['links']['first']).query).to eq(qry)
          end
        end

        context 'on paging beyond the last page' do
          let(:as_list) { }
          let(:params) do
            {
              page: { number: 5, size: 1 },
              as_list: as_list
            }.reject { |_k, _v| _v.blank? }
          end

          context 'on an array of resources' do
            let(:as_list) { true }

            it do
              expect(response).to have_http_status(:ok)
              expect(response_json['data'].size).to eq(0)

              expect(response_json['meta']['pagination']).to eq(
                'current' => 5,
                'total_count' => 3,
                'total_page' => 3
              )
              expect(response_json['links']).to eq(
                'current' => query_str(params),
                'first' => query_str(params, page: 1),
                'prev' => query_str(params, page: 4),
                'next' => nil,
                'last' => query_str(params, page: 3),
              )
            end
          end

          it do
            expect(response).to have_http_status(:ok)
            expect(response_json['data'].size).to eq(0)

            expect(response_json['meta']['pagination']).to eq(
              'current' => 5,
              'total_count' => 3,
              'total_page' => 3
            )
            expect(response_json['links']).to eq(
              'current' => query_str(params),
              'first' => query_str(params, page: 1),
              'prev' => query_str(params, page: 4),
              'next' => nil,
              'last' => query_str(params, page: 3),
            )

            expect(response_json).to have_link(:current)
            expect(response_json).to have_link(:prev)
            expect(response_json).to have_link(:first)
            expect(response_json).to have_link(:next)
            expect(response_json).to have_link(:last)

            expect(URI.parse(response_json['links']['current']).query)
              .to eq(CGI.unescape(params.to_query))

            qry = CGI.unescape(params.deep_merge(page: { number: 4 }).to_query)
            expect(URI.parse(response_json['links']['prev']).query).to eq(qry)

            qry = CGI.unescape(params.except(:page).to_query)
            expect(URI.parse(response_json['links']['first']).query).to eq(qry)
          end
        end

        context 'on page 1 out of 3' do
          let(:params) do
            {
              page: { size: 1, number: 1 },
              sort: '-created_at'
            }
          end

          it do
            expect(response).to have_http_status(:ok)
            expect(response_json['data'].size).to eq(1)
            expect(response_json['data'][0]['id']).to eql(third_user.id)

            expect(response_json['meta']['pagination']).to eq(
              'current' => 1,
              'total_count' => 3,
              'total_page' => 3,
            )
            expect(response_json['links']).to eq(
              'current' => query_str(params, page: 1),
              'first' => query_str(params, page: 1),
              'prev' => nil,
              'next' => query_str(params, page: 2),
              'last' => query_str(params, page: 3),
            )

            expect(response_json).to have_link(:prev)
            expect(response_json).to have_link(:first)
            expect(response_json).to have_link(:next)
            expect(response_json).to have_link(:current)
            expect(response_json).to have_link(:last)

            expect(URI.parse(response_json['links']['current']).query)
              .to eq(CGI.unescape(params.except(:page).to_query))

            qry = CGI.unescape(params.deep_merge(page: { number: 2 }).to_query)
            expect(URI.parse(response_json['links']['next']).query).to eq(qry)

            qry = CGI.unescape(params.deep_merge(page: { number: 3 }).to_query)
            expect(URI.parse(response_json['links']['last']).query).to eq(qry)
          end
        end
      end
    end
  end

  describe 'GET /users with a scalar page' do
    # `page=2` is not `page[number]=2`: ParameterMissing, a client error, not a 500 from
    # String#slice. This controller has no ApiKit::Errors, so Rails answers 400; with it, 422.
    [ 'page=2', 'page[]=2' ].each do |query|
      it "answers #{query} with a client error" do
        get("#{users_path}?#{query}", headers: api_headers)

        expect(response).to have_http_status(:bad_request)
      end
    end
  end

  describe 'GET /users with a blank page' do
    # `page=` names no page: the defaults, like a missing `page`.
    [ 'page=', 'page=%20' ].each do |query|
      it "answers #{query} with the first page" do
        get("#{users_path}?#{query}", headers: api_headers)

        expect(response).to have_http_status(:ok)
        expect(response_json.dig('meta', 'pagination', 'current')).to eq(1)
      end
    end
  end

  describe '#api_pagination_params with a typed non-hash page' do
    # A JSON body reaches it typed: an array or a number is malformed too, never a #slice error.
    let(:controller_class) do
      Class.new do
        include ApiKit::Pagination

        attr_reader :params

        def initialize(params)
          @params = ActionController::Parameters.new(params)
        end
      end
    end

    [ [], 2 ].each do |page|
      it "raises ParameterMissing for #{page.inspect}" do
        expect { controller_class.new(page: page).send(:api_pagination_params) }
          .to raise_error(ActionController::ParameterMissing)
      end
    end
  end
end
