# frozen_string_literal: true

module DocumentsHelper
  def safe_external_link(url, text: nil)
    return if url.blank?

    text ||= truncate(url, length: 50)

    # Strict check: Must start with http:// or https://
    if url.match?(%r{\Ahttps?://})
      link_to text, url, target: "_blank", rel: "noopener noreferrer"
    else
      # Return plain text if the protocol is unsafe
      text
    end
  end
end
