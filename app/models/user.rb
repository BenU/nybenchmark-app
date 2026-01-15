# frozen_string_literal: true

class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  # Trigger admin notification on creation
  after_create_commit :send_admin_approval_notification

  # Only allow login when an admin has approved the account.
  def active_for_authentication?
    super && approved?
  end

  # Used by Devise when `active_for_authentication?` returns false.
  # This symbol is used for i18n lookup.
  def inactive_message
    approved? ? super : :not_approved
  end

  private

  def send_admin_approval_notification
    AdminMailer.with(user: self).new_user_waiting_for_approval.deliver_now
  rescue StandardError => e
    Rails.logger.error("Admin mail failed for user #{id}: #{e.message}")
  end
end
