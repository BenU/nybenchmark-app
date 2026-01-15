# frozen_string_literal: true

class AdminMailer < ApplicationMailer
  default from: "no-reply@nybenchmark.org"

  def new_user_waiting_for_approval
    @user = params.fetch(:user)

    mail(
      to: admin_email,
      subject: "New user pending approval"
    )
  end

  private

  def admin_email
    Rails.application.config.x.admin_email.presence ||
      ENV["ADMIN_EMAIL"].presence ||
      "admin@example.com"
  end
end
