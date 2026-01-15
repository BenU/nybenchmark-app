# frozen_string_literal: true

class ApplicationMailer < ActionMailer::Base
  default from: '"NY Benchmark" <notifications@nybenchmark.org>',
          reply_to: "admin@nybenchmark.org"
  layout "mailer"
end
