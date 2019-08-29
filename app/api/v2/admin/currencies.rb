# encoding: UTF-8
# frozen_string_literal: true

module API
  module V2
    module Admin
      class Currencies < Grape::API
        helpers ::API::V2::Admin::Helpers
        helpers do
          # Collection of shared params, used to
          # generate required/optional Grape params.
          OPTIONAL_CURRENCY_PARAMS = {
            name: { desc: -> { API::V2::Admin::Entities::Currency.documentation[:name][:desc] } },
            deposit_fee: {
              type: { value: BigDecimal, message: 'admin.currency.non_decimal_deposit_fee' },
              values: { value: -> (p){ p >= 0 }, message: 'admin.currency.invalid_deposit_fee' },
              default: 0.0,
              desc: -> { API::V2::Admin::Entities::Currency.documentation[:deposit_fee][:desc] }
            },
            min_deposit_amount: {
              type: { value: BigDecimal, message: 'admin.currency.min_deposit_amount' },
              values: { value: -> (p){ p >= 0 }, message: 'admin.currency.min_deposit_amount' },
              default: 0.0,
              desc: -> { API::V2::Admin::Entities::Currency.documentation[:min_deposit_amount][:desc] }
            },
            min_collection_amount: {
              type: { value: BigDecimal, message: 'admin.currency.non_decimal_min_collection_amount' },
              values: { value: -> (p){ p >= 0 }, message: 'admin.currency.invalid_min_collection_amount' },
              default: 0.0,
              desc: -> { API::V2::Admin::Entities::Currency.documentation[:min_collection_amount][:desc] }
            },
            withdraw_fee: {
              type: { value: BigDecimal, message: 'admin.currency.non_decimal_withdraw_fee' },
              values: { value: -> (p){ p >= 0  }, message: 'admin.currency.ivalid_withdraw_fee' },
              default: 0.0,
              desc: -> { API::V2::Admin::Entities::Currency.documentation[:withdraw_fee][:desc] }
            },
            min_withdraw_amount: {
              type: { value: BigDecimal, message: 'admin.currency.non_decimal_min_withdraw_amount' },
              values: { value: -> (p){ p >= 0 }, message: 'admin.currency.invalid_min_withdraw_amount' },
              default: 0.0,
              desc: -> { API::V2::Admin::Entities::Currency.documentation[:min_withdraw_amount][:desc] }
            },
            withdraw_limit_24h: {
              type: { value: BigDecimal, message: 'admin.currency.non_decimal_withdraw_limit_24h' },
              values: { value: -> (p){ p >= 0 }, message: 'admin.currency.invalid_withdraw_limit_24h' },
              default: 0.0,
              desc: -> { API::V2::Admin::Entities::Currency.documentation[:withdraw_limit_24h][:desc] }
            },
            withdraw_limit_72h: {
              type: { value: BigDecimal, message: 'admin.currency.non_decimal_withdraw_limit_72h' },
              values: { value: -> (p){ p >= 0 }, message: 'admin.currency.invalid_withdraw_limit_72h' },
              default: 0.0,
              desc: -> { API::V2::Admin::Entities::Currency.documentation[:withdraw_limit_72h][:desc] }
            },
            position: {
              type: { value: Integer, message: 'admin.currency.non_integer_position' },
              default: 0,
              desc: -> { API::V2::Admin::Entities::Currency.documentation[:position][:desc] }
            },
            options: {
              type: { value: JSON, message: 'admin.currency.non_json_options' },
              default: 0.0,
              desc: -> { API::V2::Admin::Entities::Currency.documentation[:options][:desc] }
            },
            enabled: {
              type: { value: Boolean, message: 'admin.currency.non_boolean_enabled' },
              default: true,
              desc: -> { API::V2::Admin::Entities::Currency.documentation[:enabled][:desc] }
            },
            subunits: {
              type: { value: Integer, message: 'admin.currency.non_integer_subunits' },
              values: { value: (0..18), message: 'admin.currency.invalid_subunits' },
              default: 0,
              desc: 'Fraction of the basic monetary unit.'
            },
            precision: {
              type: { value: Integer, message: 'admin.currency.non_integer_base_precision' },
              default: 8,
              desc: -> { API::V2::Admin::Entities::Currency.documentation[:precision][:desc] }
            },
            icon_url: { desc: -> { API::V2::Admin::Entities::Currency.documentation[:icon_url][:desc] } }
          }

          params :create_currency_params do
            OPTIONAL_CURRENCY_PARAMS.each do |key, params|
              optional key, params
            end
          end

          params :update_currency_params do
            OPTIONAL_CURRENCY_PARAMS.each do |key, params|
              optional key, params.except(:default)
            end
          end
        end

        desc 'Get list of currencies',
          is_array: true,
          success: API::V2::Admin::Entities::Currency
        params do
          use :currency_type
          use :pagination
          use :ordering
        end
        get '/currencies' do
          authorize! :read, Currency

          search = Currency.ransack(type_eq: params[:type])
          search.sorts = "#{params[:order_by]} #{params[:ordering]}"

          present paginate(search.result), with: API::V2::Admin::Entities::Currency
        end

        desc 'Get a currency.' do
          success API::V2::Admin::Entities::Currency
        end
        params do
          requires :code,
                   type: String,
                   values: { value: -> { Currency.codes(bothcase: true) }, message: 'admin.currency.doesnt_exist'},
                   desc: -> { API::V2::Admin::Entities::Currency.documentation[:code][:desc] }
        end
        get '/currencies/:code' do
          authorize! :read, Currency

          present Currency.find(params[:code]), with: API::V2::Admin::Entities::Currency
        end

        desc 'Create new currency.' do
          success API::V2::Admin::Entities::Currency
        end
        params do
          use :create_currency_params
          requires :code,
                   desc: -> { API::V2::Admin::Entities::Currency.documentation[:code][:desc] }
          requires :symbol,
                   desc: -> { API::V2::Admin::Entities::Currency.documentation[:symbol][:desc] }
          optional :type,
                   values: { value: ::Currency.types.map(&:to_s), message: 'admin.currency.invalid_type' },
                   default: 'coin',
                   desc: -> { API::V2::Admin::Entities::Currency.documentation[:type][:desc] }
          given type: ->(val) { val == 'coin' } do
            requires :blockchain_key,
                     values: { value: -> { ::Blockchain.pluck(:key) }, message: 'admin.currency.blockchain_key_doesnt_exist' },
                     desc: -> { API::V2::Admin::Entities::Currency.documentation[:blockchain_key][:desc] }
          end
        end
        post '/currencies/new' do
          authorize! :create, Currency

          currency = Currency.new(declared(params).except(:subunits))
          currency.subunits = params[:subunits]
          if currency.save
            present currency, with: API::V2::Admin::Entities::Currency
            status 201
          else
            body errors: currency.errors.full_messages
            status 422
          end
        end

        desc 'Update currency.' do
          success API::V2::Admin::Entities::Currency
        end
        params do
          use :update_currency_params
          requires :code,
                   values: { value: -> { ::Currency.codes }, message: 'admin.currency.doesnt_exist' },
                   desc: -> { API::V2::Admin::Entities::Currency.documentation[:code][:desc] }
          optional :symbol,
                   desc: -> { API::V2::Admin::Entities::Currency.documentation[:symbol][:desc] }
          optional :blockchain_key,
                   values: { value: -> { ::Blockchain.pluck(:key) }, message: 'admin.currency.blockchain_key_doesnt_exist' },
                   desc: -> { API::V2::Admin::Entities::Currency.documentation[:blockchain_key][:desc] }
        end
        post '/currencies/update' do
          authorize! :write, Currency

          currency = Currency.find(params[:code])
          currency.subunits = params[:subunits] if params[:subunits]
          if currency.update(declared(params, include_missing: false).except(:subunits))
            present currency, with: API::V2::Admin::Entities::Currency
          else
            body errors: currency.errors.full_messages
            status 422
          end
        end
      end
    end
  end
end