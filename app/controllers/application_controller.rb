class ApplicationController < ActionController::Base
  include Authentication

  layout 'application'

  before_filter :login_required
  before_filter :adjust_format_for_iphone

  protect_from_forgery

  protected

  def adjust_format_for_iphone
    user_agent = request.env['HTTP_USER_AGENT']

    if user_agent.present? && user_agent =~ /(AppleWebKit.+Mobile)/
      request.format = :iphone
    end
  end
end
