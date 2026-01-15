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
    ENV.fetch("ADMIN_EMAIL", "admin@example.com")
  end
end
