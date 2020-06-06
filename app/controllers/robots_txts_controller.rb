class RobotsTxtsController < ApplicationController
  DISALLOW_ROBOTS = 'User-agent: *
Disallow: /
'.freeze
  def show
    render content_type: 'text/plain', plain: DISALLOW_ROBOTS
  end
end
