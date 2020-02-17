# encoding: UTF-8
# frozen_string_literal: true

module Workers
  module AMQP
    class DepositCoinAddress < Base
      def process(payload)
        payload.symbolize_keys!

        acc = Account.find_by_id(payload[:account_id])
        return unless acc
        return unless acc.currency.coin?

        wallet = Wallet.active.deposit.find_by(currency_id: acc.currency_id)
        unless wallet
          Rails.logger.warn do
            "Unable to generate deposit address."\
            "Deposit Wallet for #{acc.currency_id} doesn't exist"
          end
          return
        end

        wallet_service = WalletService.new(wallet)

        acc.payment_address.tap do |pa|
          pa.with_lock do
            next if pa.address.present?

            result = wallet_service.create_address!(acc)

            pa.update!(address: result[:address],
                      secret:  result[:secret],
                      details: result.fetch(:details, {}).merge(pa.details))
          end

          # Enqueue address generation again if address is not provided.
          pa.enqueue_address_generation if pa.address.blank?

          ws_notify(acc, pa) unless pa.address.blank?
        end

      # Don't re-enqueue this job in case of error.
      # The system is designed in such way that when user will
      # request list of accounts system will ask to generate address again (if it is not generated of course).
      rescue StandardError => e
        raise e if is_db_connection_error?(e)

        report_exception(e)
      end

    private

      def ws_notify(acc, payment_address)
        Peatio::Ranger::Events.publish('private',
                                       acc.member.uid,
                                       :deposit_address,
                                       type: :create,
                                       currency: payment_address.currency.code,
                                       address:  payment_address.address)
      end
    end
  end
end
